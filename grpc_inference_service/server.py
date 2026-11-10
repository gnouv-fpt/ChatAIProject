import base64
import functools
import os
import re
import sys
from concurrent import futures
import logging
import grpc
from telemetry import RpcMetrics, configure

# Add service directory to sys.path so local imports work seamlessly
CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
if CURRENT_DIR not in sys.path:
    sys.path.insert(0, CURRENT_DIR)

from moderation.moderation_engine import ModerationEngine
from verification.verification_engine import DataVerificationEngine
from rag.embeddings import EmbeddingEngine
from rag.vector_store import QdrantTrafficStore
from rag.rag_generator import TrafficRagGenerator
from rag.vision_engine import TrafficVisionEngine
from rag.visual_question_matcher import PublishedVisualQuestionMatcher
from rag.qcvn_sign_matcher import QcvnSignMatcher
from data.seed_traffic_law import get_seed_traffic_law_chunks

# These will be available after compiling protos
try:
    import chat_inference_pb2
    import chat_inference_pb2_grpc
except ImportError:
    from generate_protos import compile_proto
    compile_proto()
    import chat_inference_pb2
    import chat_inference_pb2_grpc

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("TrafficRagGrpcServer")

def rpc_errors(method):
    @functools.wraps(method)
    def wrapped(self, request, context):
        try:
            if not context.is_active():
                context.abort(grpc.StatusCode.CANCELLED, "Request cancelled")
            return method(self, request, context)
        except grpc.RpcError:
            raise
        except Exception as error:
            if isinstance(error, RuntimeError) and 'reserved token budget cannot cover this context' in str(error):
                context.abort(grpc.StatusCode.RESOURCE_EXHAUSTED,
                              'Reserved token budget is insufficient for the verified context')
            logger.exception("Inference RPC failed: %s", method.__name__)
            context.abort(grpc.StatusCode.UNAVAILABLE, "Inference dependency unavailable")
    return wrapped

class TrafficRagInferenceServicer(chat_inference_pb2_grpc.TrafficRagInferenceServicer):
    """
    gRPC Servicer implementing Vietnam Traffic Law Moderation & Advanced RAG.
    Maintained by Khoi: Groq Generation, Qdrant Vector Store, Vision Analysis,
    Document Verification, and Question Explanation.
    """
    SIGN_SOURCE_MISSING = (
        'Ảnh này chưa khớp duy nhất với câu hỏi trong bộ đề đã kiểm chứng. '
        'Hệ thống chưa đối chiếu được ảnh với mục QCVN 41:2024/BGTVT tương ứng đã xác thực, '
        'nên chưa thể kết luận ý nghĩa biển hoặc vạch cụ thể.'
    )
    REVIEWED_SCENARIO_LAW = {
        494: ((('27', '2', 'a'), ('27', '2', 'c'), ('27', '5', '')),
              'Điều 27 khoản 2 điểm a xếp xe chữa cháy đang làm nhiệm vụ trước điểm c '
              'là xe cứu thương đang làm nhiệm vụ; khoản 5 buộc xe con nhường đường cho xe ưu tiên. '
              'Với ba xe và hướng đi thể hiện trong ảnh, xe chữa cháy đi trước, rồi xe cứu thương, rồi xe con.'),
        498: ((('27', '2', 'a'), ('27', '2', 'b')),
              'Điều 27 khoản 2 điểm a xếp xe chữa cháy đang làm nhiệm vụ trước điểm b '
              'là xe công an đang làm nhiệm vụ khẩn cấp. Hai xe trong ảnh thuộc hai nhóm này; '
              'vì vậy xe chữa cháy đi trước.'),
    }

    def __init__(self):
        logger.info("Initializing TrafficRagInferenceServicer components...")
        self.moderation_engine = ModerationEngine()
        self.verification_engine = DataVerificationEngine()
        self.embedding_engine = EmbeddingEngine()
        self.vector_store = QdrantTrafficStore(self.embedding_engine)
        self.rag_generator = TrafficRagGenerator()
        self.vision_engine = TrafficVisionEngine()
        self.visual_question_matcher = PublishedVisualQuestionMatcher()
        self.qcvn_sign_matcher = QcvnSignMatcher()

        logger.info("All components initialized successfully.")

    @staticmethod
    def _response(text, citations=(), tokens=0, status="NoMatch", images=False):
        response = chat_inference_pb2.ChatInferenceResponse(
            response_text=text, citations=[chat_inference_pb2.CitationDto(**c) for c in citations],
            data_verified=status == "Answered" or status == "PracticeAnswered" and bool(citations),
            is_violation=status == "Blocked",
            requires_clarification=status == "NeedsClarification", result_status=status,
            contract_version=2, images_processed=images)
        if tokens is not None and tokens >= 0:
            response.tokens_used = tokens
        return response

    @staticmethod
    def _supplement_refers_to_point(content, clause, point):
        for segment in content.lower().split(';'):
            previous_end = 0
            for match in re.finditer(r'khoản\s+(\d+[a-z]?)', segment):
                prefix = segment[previous_end:match.start()]
                points = re.findall(r'điểm\s+([a-zđ]\d*)', prefix)
                if match.group(1) == clause and (not points or point in points):
                    return True
                previous_end = match.end()
        return False

    @staticmethod
    def _requires_sign_standard(prompt):
        if re.search(r'thứ tự|đi trước|nhường đường', prompt, re.IGNORECASE):
            return False
        return bool(re.search(r'biển(?:\s+báo)?\s+(?:nào|này|số)|'
                              r'biển.*(?:ý nghĩa|tác dụng|cấm|báo hiệu)|'
                              r'vạch.*(?:tác dụng|ý nghĩa|phân chia)|vạch\s+nào',
                              prompt, re.IGNORECASE))

    def _reviewed_sign_answer(self, code, clause, images=False):
        source = self.vector_store.get_verified_standard_clause('QCVN 41:2024/BGTVT', clause)
        if not source or code not in source.get('content', '') or \
                source.get('article') != 'Phụ lục B' or source.get('source_url') != \
                'https://datafiles.chinhphu.vn/cpp/files/vbpq/2024/11/51-bgtvt-kem.pdf':
            return None
        citation = {'chunk_id': source['chunk_id'], 'content_hash': source['content_hash'],
                    'document_title': source['document_title'],
                    'article_number': source['article'], 'clause_number': source['clause'],
                    'point_number': source['point'], 'document_version': source['document_version'],
                    'source_url': source['source_url'], 'excerpt': source['content'][:250]}
        answer = (f"Biển {code} — {QcvnSignMatcher.MEANINGS[code]}\n\n"
                  f"Căn cứ: QCVN 41:2024/BGTVT, Phụ lục B mục {clause} "
                  f"điểm a ({source['source_url']}).")
        return self._response(answer, citations=[citation], status='Answered', images=images)

    @rpc_errors
    def ProcessChatMessage(self, request, context):
        prompt = request.prompt.strip()
        is_violation, keywords, warning = self.moderation_engine.check(prompt)
        if is_violation:
            response = self._response(warning, status="Blocked", images=bool(request.images))
            response.violation_keywords.extend(keywords)
            return response
        if not request.images and self._requires_sign_standard(prompt):
            mentioned_codes = {'P.' + number for number in re.findall(
                r'\bP\.?\s*(\d{3})\b', prompt, re.IGNORECASE)}
            if len(mentioned_codes) == 1:
                code = next(iter(mentioned_codes))
                if code in QcvnSignMatcher.MEANINGS:
                    clause = 'B.1' if code == 'P.101' else 'B.2'
                    answer = self._reviewed_sign_answer(code, clause)
                    if answer:
                        return answer
                return self._response(
                    'Chưa có mục QCVN 41:2024/BGTVT tương ứng đã xác thực để trả lời chắc chắn về mã biển này.')
        matcher = getattr(self, "visual_question_matcher", None)
        if matcher is not None and len(request.images) == 1 and not QdrantTrafficStore._is_sanction_query(prompt):
            published = matcher.match(prompt, request.images[0].content)
            if published:
                number_match = re.match(r'Câu\s+(\d{3})\s+', published)
                number = int(number_match.group(1)) if number_match else None
                if number in self.REVIEWED_SCENARIO_LAW:
                    locations, reasoning = self.REVIEWED_SCENARIO_LAW[number]
                    points = [self.vector_store.get_verified_location('55/VBHN-VPQH', article, clause, point)
                              for article, clause, point in locations]
                    if all(points):
                        citations = [{'chunk_id': row['chunk_id'], 'content_hash': row['content_hash'],
                                      'document_title': row['document_title'],
                                      'article_number': row['article'], 'clause_number': row['clause'],
                                      'point_number': row['point'], 'document_version': row['document_version'],
                                      'source_url': row['source_url'], 'excerpt': row['content'][:250]}
                                     for row in points]
                        explanation = ('\n\nCăn cứ luật cho tình huống này: ' + reasoning +
                                       '\nNguồn luật: ' + points[0]['source_url'])
                        published = published.replace(
                            'Lưu ý: nguồn đáp án bộ đề chưa phải trích dẫn điều luật hoặc quy chuẩn cho lời giải.',
                            'Đáp án PDF và căn cứ luật dưới đây là hai nguồn độc lập.')
                        return self._response(published + explanation, citations=citations,
                                              status='PracticeAnswered', images=True)
                return self._response(published, status="PracticeAnswered", images=True)
        if len(request.images) == 1 and self._requires_sign_standard(prompt):
            official_matcher = getattr(self, 'qcvn_sign_matcher', None)
            official_sign = official_matcher.match(request.images[0].content) if official_matcher else None
            if official_sign:
                mentioned_codes = {'P.' + number for number in re.findall(
                    r'\bP\.?\s*(\d{3})\b', prompt, re.IGNORECASE)}
                if mentioned_codes and mentioned_codes != {official_sign['code']}:
                    return self._response(
                        'Mã biển nêu trong câu hỏi không khớp ảnh đã nhận diện. Vui lòng kiểm tra lại ảnh hoặc mã biển.',
                        status='NeedsClarification', images=True)
                answer = self._reviewed_sign_answer(official_sign['code'], official_sign['clause'], images=True)
                if answer:
                    return answer
            return self._response(self.SIGN_SOURCE_MISSING, status='NoMatch', images=True)
        if re.search(r'\b(?:đèn|den)\s+(?:đỏ|do)\b', prompt, re.IGNORECASE) and \
                QdrantTrafficStore._is_sanction_query(prompt) and not re.search(
                    r'xe\s+(?:máy|mô\s*tô|gắn\s*máy|đạp|tải|ô\s*tô|chuyên\s*dùng)|\bô\s*tô\b',
                    prompt, re.IGNORECASE):
            return self._response('Vui lòng nêu loại phương tiện để xác định đúng mức phạt vượt đèn đỏ.',
                                  status='NeedsClarification', images=bool(request.images))
        vision_tokens = 0
        budget = request.max_tokens or 8192
        observations = []
        vision_queries = []
        for image in request.images:
            if not context.is_active():
                context.abort(grpc.StatusCode.CANCELLED, "Request cancelled")
            observation, clarify, query = self.vision_engine.analyze_traffic_image(
                base64.b64encode(image.content).decode(), image.mime_type, prompt, max(0, budget - vision_tokens))
            usage = getattr(self.vision_engine, "last_tokens", None)
            vision_tokens = -1 if usage is None or vision_tokens < 0 else vision_tokens + usage
            if clarify:
                return self._response(observation, tokens=vision_tokens, status="NeedsClarification", images=True)
            # A still image often cannot establish whether a vehicle has
            # already entered the junction. That fact can reverse the order
            # even when an emergency vehicle is present, so do not guess.
            asks_order = re.search(r"thứ tự|đi trước|đi đầu tiên|nhường đường", prompt, re.IGNORECASE)
            uncertain_entry = re.search(r"chưa xác định|không xác định|không rõ|chưa rõ", observation, re.IGNORECASE)
            emergency_vehicle = re.search(r"xe cứu thương|xe ưu tiên|xe chữa cháy|xe công an", observation, re.IGNORECASE)
            if asks_order and (uncertain_entry or emergency_vehicle):
                return self._response(
                    "Ảnh chưa đủ tin cậy để xác định thứ tự xe qua giao lộ, đặc biệt là vị trí xe đã vào nơi giao nhau "
                    "và tín hiệu của xe ưu tiên. Vui lòng cung cấp số câu trong bộ đề hoặc mô tả rõ vị trí từng xe.",
                    tokens=vision_tokens, status="NeedsClarification", images=True)
            observations.append(observation)
            vision_queries.append(query)
        history = "\n".join(f"{h.role}: {h.content}" for h in request.history[-10:])
        query = "\n".join([history, *observations, prompt]).strip()
        # Keep old assistant wording out of retrieval so a changed subject (red -> yellow light)
        # can retrieve new evidence. History remains available to grounded answer generation.
        retrieval_query = "\n".join([*vision_queries, prompt]).strip()
        chunks = self.vector_store.search_verified_chunks(
            retrieval_query, top_k=5, score_threshold=0.20)
        if not chunks and request.images and vision_queries:
            # A visual description can dominate the embedding and hide a relevant rule.
            # Retry retrieval using the user's legal question; generation still needs citations.
            chunks = self.vector_store.search_verified_chunks(
                prompt, top_k=5, score_threshold=0.20)
        # A compound age question can need both A1 and B classification
        # clauses. Vector top-5 often contains the age clause but only one
        # classification clause; fetch the exact verified siblings before
        # generation and keep the generator's all-citations check.
        age_classes = TrafficRagGenerator.required_age_classes(prompt)
        if age_classes:
            document_ids = {c.get('document_id') for c in chunks
                            if c.get('document_number') == '55/VBHN-VPQH' and c.get('document_id')}
            present_ids = {c['chunk_id'] for c in chunks}
            for document_id in document_ids:
                for article in ('57', '59'):
                    for row in self.vector_store.get_verified_article_chunks(document_id, article):
                        content = row.get('content', '')
                        if article == '57':
                            relevant = any(re.search(r'\bhạng\s+' + re.escape(licence_class) + r'\s+cấp\b',
                                                      content, re.IGNORECASE) for licence_class in age_classes)
                        else:
                            relevant = any(re.search(r'\b' + re.escape(licence_class) + r'\b',
                                                      content, re.IGNORECASE) for licence_class in age_classes)
                        if relevant and row['chunk_id'] not in present_ids:
                            chunks.append(row)
                            present_ids.add(row['chunk_id'])
        sanction_locations = TrafficRagGenerator.required_sanction_locations(prompt)
        if sanction_locations:
            sanction_docs = {c.get('document_id') for c in chunks
                             if c.get('document_number') == '168/2024/NĐ-CP' and c.get('document_id')}
            if not sanction_docs:
                return self._response(self.rag_generator.NO_MATCH_RESPONSE, status='NoMatch',
                                      images=bool(request.images))
            present_ids = {c['chunk_id'] for c in chunks}
            for document_id in sanction_docs:
                for article, clause, point in sanction_locations:
                    row = self.vector_store.get_verified_chunk(document_id, article, clause, point=point)
                    if row is None:
                        return self._response(self.rag_generator.NO_MATCH_RESPONSE, status='NoMatch',
                                              images=bool(request.images))
                    if row['chunk_id'] not in present_ids:
                        chunks.append(row)
                        present_ids.add(row['chunk_id'])
        # Article 11 defines broad classes of signs, but does not identify
        # a pictured sign or marking. A visually specific answer needs the
        # verified QCVN 41 sign/marking provision, not that generic article.
        prompt_lower = prompt.lower()
        if QdrantTrafficStore._is_sanction_query(prompt) and any(
                c.get('document_number') == '168/2024/NĐ-CP' for c in chunks):
            chunks = [c for c in chunks if c.get('document_number') == '168/2024/NĐ-CP']
        camera_question = 'ghi nhận hình ảnh' in prompt_lower or 'camera' in prompt_lower
        if camera_question and 'vận tải hàng hóa' in prompt_lower:
            # Article 21 covers cargo drivers; Article 26 covers transport operators.
            # Passenger and school-transport articles describe different vehicle classes.
            chunks = [c for c in chunks if c.get('document_number') != '168/2024/NĐ-CP'
                      or str(c.get('article')) in {'21', '26'}]
        delayed = {(20, '5', 'l'): '3', (21, '3', 'b'): '3', (32, '9a', 'b'): '3',
                   (20, '5', 'n'): '4', (26, '7', 'k'): '4', (26, '7', 'l'): '4',
                   (32, '1', 'b'): '2'}
        companions = {}
        parents = {}
        for chunk in chunks:
            if chunk.get('document_number') != '168/2024/NĐ-CP':
                continue
            article = str(chunk.get('article', ''))
            if not article.isdigit():
                continue
            clause = delayed.get((int(article), chunk.get('clause'), chunk.get('point')))
            if clause:
                companions[(chunk['document_id'], clause)] = chunk
            if chunk.get('point') and chunk.get('clause'):
                parents[(chunk['document_id'], article, chunk['clause'], chunk['point'])] = chunk
        sanction_documents = {chunk['document_id'] for chunk in chunks
                              if chunk.get('document_number') == '168/2024/NĐ-CP'
                              and chunk.get('document_id')}
        if camera_question:
            for document_id in sanction_documents:
                companions[(document_id, '3')] = None
                if 'vận tải hàng hóa' not in prompt_lower:
                    companions[(document_id, '4')] = None
        if 'khí thải' in prompt_lower:
            for document_id in sanction_documents:
                companions[(document_id, '2')] = None
        for (document_id, clause), _ in companions.items():
            evidence = self.vector_store.get_verified_chunk(document_id, '53', clause)
            if evidence is None:
                return self._response(self.rag_generator.NO_MATCH_RESPONSE, status='NoMatch', images=bool(request.images))
            if evidence['chunk_id'] not in {c['chunk_id'] for c in chunks}:
                chunks.append(evidence)
        wants_additional_sanctions = bool(re.search(
            r'xử phạt thế nào|trừ điểm|tước|tịch thu|khắc phục|hình phạt bổ sung',
            prompt, re.IGNORECASE))
        if QdrantTrafficStore._is_sanction_query(prompt):
            supplements = []
            article_rows = {}
            titled_articles = {(chunk['document_id'], str(chunk['article'])) for chunk in chunks
                              if chunk.get('document_number') == '168/2024/NĐ-CP'
                              and chunk.get('document_id') and chunk.get('clause')
                              and str(chunk.get('article', '')).isdigit()}
            for document_id, article in titled_articles:
                title = self.vector_store.get_verified_chunk(document_id, article, '', point='')
                if title is None:
                    return self._response(self.rag_generator.NO_MATCH_RESPONSE, status='NoMatch',
                                          images=bool(request.images))
                if title['chunk_id'] not in {c['chunk_id'] for c in chunks}:
                    chunks.append(title)
            for document_id, article, clause, point in parents:
                article_key = (document_id, article)
                header = self.vector_store.get_verified_chunk(document_id, article, clause, point='')
                if header is None:
                    return self._response(self.rag_generator.NO_MATCH_RESPONSE, status='NoMatch', images=bool(request.images))
                if header['chunk_id'] not in {c['chunk_id'] for c in chunks}:
                    chunks.append(header)
                if wants_additional_sanctions:
                    if article_key not in article_rows:
                        article_rows[article_key] = self.vector_store.get_verified_article_chunks(document_id, article)
                    for row in article_rows[article_key]:
                        content = row.get('content', '').lower()
                        if self._supplement_refers_to_point(content, clause, point) and any(term in content for term in
                                ('trừ điểm', 'tước quyền', 'tịch thu', 'buộc')):
                            supplements.append(row)
            for row in supplements[:8]:
                if row.get('point') and row.get('clause'):
                    related_header = self.vector_store.get_verified_chunk(
                        row['document_id'], row['article'], row['clause'], point='')
                    if related_header is None:
                        return self._response(self.rag_generator.NO_MATCH_RESPONSE, status='NoMatch',
                                              images=bool(request.images))
                    if related_header['chunk_id'] not in {c['chunk_id'] for c in chunks}:
                        chunks.append(related_header)
                if row['chunk_id'] not in {c['chunk_id'] for c in chunks}:
                    chunks.append(row)
        if QdrantTrafficStore._is_sanction_query(prompt):
            logger.info("Sanction evidence locations: %s", [(c.get('article'), c.get('clause'),
                c.get('point')) for c in chunks])
        text, citations, tokens, verified = self.rag_generator.generate(
            query, chunks, max(0, budget - vision_tokens), current_question=prompt,
            prefer_gemini=bool(request.images))
        if verified and camera_question and 'vận tải hàng hóa' in prompt_lower and \
                not (any(c.get('article_number') == '53' and c.get('clause_number') == '3'
                         for c in citations) and '2028' in text):
            text, citations, verified = self.rag_generator.NO_MATCH_RESPONSE, [], False
        if not context.is_active():
            context.abort(grpc.StatusCode.CANCELLED, "Request cancelled")
        allowed = {"document_title", "article_number", "clause_number", "source_url", "excerpt",
            "chunk_id", "content_hash", "point_number", "document_version"}
        citations = [{k: str(v) for k, v in c.items() if k in allowed} for c in citations]
        total = tokens + vision_tokens if tokens >= 0 and vision_tokens >= 0 else -1
        return self._response(text, citations, total, "Answered" if verified else "NoMatch", bool(request.images))

    @rpc_errors
    def ProcessImageChatMessage(self, request, context):
        image = chat_inference_pb2.ChatImage(mime_type=request.mime_type,
            content=base64.b64decode(request.image_base64, validate=True))
        return self.ProcessChatMessage(chat_inference_pb2.ChatInferenceRequest(user_id=request.user_id,
            session_id=request.session_id, prompt=request.prompt, images=[image]), context)

    @rpc_errors
    def VerifyLegalDocument(self, request, context):
        doc_title = request.document_title
        doc_number = request.document_number
        content = request.content
        eff_date = request.effective_date
        exp_date = request.expiration_date

        logger.info(f"[VerifyLegalDocument] Title: '{doc_title}', Number: '{doc_number}', Exp: '{exp_date}'")
        res = self.verification_engine.verify_document(
            doc_title, doc_number, content, eff_date, exp_date
        )

        return chat_inference_pb2.VerificationResponse(
            is_valid=res["is_valid"],
            status=res["status"],
            notes=res["notes"]
        )

    @rpc_errors
    def IndexDocument(self, request, context):
        logger.info(f"[IndexDocument] Received {len(request.chunks)} chunks to index.")
        chunks_to_index = [self._chunk_payload(ch) for ch in request.chunks]

        count = self.vector_store.upsert_chunks(chunks_to_index, is_active=context.is_active)
        return chat_inference_pb2.IndexDocumentResponse(
            success=True,
            indexed_count=count,
            message=f"Successfully indexed {count} chunks into Qdrant."
        )

    @staticmethod
    def _chunk_payload(ch):
        return {
                "chunk_id": ch.chunk_id,
                "document_title": ch.document_title,
                "document_number": ch.document_number,
                "chapter": ch.chapter,
                "article": ch.article,
                "clause": ch.clause,
                "point": ch.point,
                "document_version": ch.document_version or "1.0",
                "content": ch.content,
                "content_hash": ch.content_hash,
                "document_id": ch.document_id,
                "source_url": ch.source_url,
                "is_verified": ch.is_verified,
                "is_active": ch.is_active
            }

    @rpc_errors
    def VerifyDocumentIndex(self, request, context):
        matches, matched_count, message = self.vector_store.verify_document_index(
            [self._chunk_payload(ch) for ch in request.chunks])
        return chat_inference_pb2.VerifyDocumentIndexResponse(
            matches=matches, matched_count=matched_count, message=message)

    @rpc_errors
    def DeactivateDocument(self, request, context):
        doc_number = request.document_number
        chunk_ids = list(request.chunk_ids)
        logger.info(f"[DeactivateDocument] Deactivating doc: {doc_number}, chunks: {len(chunk_ids)}")

        count = self.vector_store.deactivate_document(doc_number, chunk_ids)
        return chat_inference_pb2.DeactivateDocumentResponse(
            success=True,
            updated_count=count,
            message=f"Deactivated document/chunks from active RAG retrieval."
        )

    @rpc_errors
    def ExplainQuestion(self, request, context):
        """
        Explains practice/exam questions combining official answer key with verified legal grounds.
        Does NOT score or decide correctness (scoring is strictly done by server engine in .NET).
        """
        content = request.question_content
        options = list(request.options)
        key = request.correct_answer_key
        official_exp = request.official_explanation

        logger.info("ExplainQuestion requested")

        # 1. Retrieve legal backing
        query = f"{content} {key} {official_exp}".strip()
        matched_chunks = self.vector_store.search_verified_chunks(query, top_k=2, score_threshold=0.20)

        # 2. Build synthesis prompt
        prompt = (
            f"Giải thích chi tiết cho câu hỏi trắc nghiệm luật giao thông sau:\n"
            f"Câu hỏi: {content}\n"
            f"Các lựa chọn: {', '.join(options)}\n"
            f"Đáp án đúng chính thức: {key}\n"
            f"Giải thích có sẵn: {official_exp}\n"
            f"Hãy đưa ra phân tích pháp lý vì sao đáp án này là chính xác theo luật hiện hành."
        )

        response_text, citations_data, tokens_used, data_verified = self.rag_generator.generate(
            prompt, matched_chunks
        )

        citation_dtos = [
            chat_inference_pb2.CitationDto(
                document_title=c.get("document_title", ""),
                article_number=c.get("article_number", ""),
                clause_number=c.get("clause_number", ""),
                source_url=c.get("source_url", ""),
                excerpt=c.get("excerpt", ""),
                chunk_id=c.get("chunk_id", ""),
                point_number=c.get("point_number", ""),
                document_version=c.get("document_version", "1.0")
            )
            for c in citations_data
        ]

        return chat_inference_pb2.ExplainQuestionResponse(
            explanation_text=response_text,
            citations=citation_dtos,
            tokens_used=tokens_used,
            data_verified=data_verified
        )

def serve():
    port = os.getenv("GRPC_PORT", "50051")
    configure()
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10), interceptors=[RpcMetrics()])
    chat_inference_pb2_grpc.add_TrafficRagInferenceServicer_to_server(
        TrafficRagInferenceServicer(), server
    )
    bind_addr = f"{os.getenv('GRPC_BIND_HOST', '0.0.0.0')}:{port}"
    if not server.add_insecure_port(bind_addr):
        raise RuntimeError("Could not bind the configured gRPC endpoint")
    server.start()
    logger.info(f"Traffic Law RAG gRPC Inference Service started on {bind_addr}")
    try:
        server.wait_for_termination()
    except KeyboardInterrupt:
        logger.info("Stopping gRPC server...")
        server.stop(0)

if __name__ == "__main__":
    serve()
