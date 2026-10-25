import os
import sys
from concurrent import futures
import logging
import grpc

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

class TrafficRagInferenceServicer(chat_inference_pb2_grpc.TrafficRagInferenceServicer):
    """
    gRPC Servicer implementing Vietnam Traffic Law Moderation & Advanced RAG.
    Maintained by Khoi: Groq Generation, Qdrant Vector Store, Vision Analysis,
    Document Verification, and Question Explanation.
    """

    def __init__(self):
        logger.info("Initializing TrafficRagInferenceServicer components...")
        self.moderation_engine = ModerationEngine()
        self.verification_engine = DataVerificationEngine()
        self.embedding_engine = EmbeddingEngine()
        self.vector_store = QdrantTrafficStore(self.embedding_engine)
        self.rag_generator = TrafficRagGenerator()
        self.vision_engine = TrafficVisionEngine()

        # Seed initial authentic traffic law data if needed
        self._seed_initial_data()
        logger.info("All components initialized successfully.")

    def _seed_initial_data(self):
        try:
            if self.vector_store._client is not None:
                current_count = self.vector_store._client.count(
                    collection_name=self.vector_store.COLLECTION_NAME
                ).count
                if current_count > 0:
                    logger.info(
                        f"Collection '{self.vector_store.COLLECTION_NAME}' already has "
                        f"{current_count} points. Skipping seed to avoid duplicates."
                    )
                    return
        except Exception as e:
            logger.warning(f"Could not check collection count before seeding: {e}. Proceeding with seed.")

        seed_chunks = get_seed_traffic_law_chunks()
        logger.info(f"Seeding {len(seed_chunks)} authentic traffic law chunks (NĐ 100/2019, NĐ 123/2021)...")
        count = self.vector_store.upsert_chunks(seed_chunks)
        logger.info(f"Successfully indexed {count} legal chunks into Vector Store.")

    def ProcessChatMessage(self, request, context):
        user_id = request.user_id
        session_id = request.session_id
        prompt = request.prompt.strip()

        logger.info(f"[ProcessChatMessage] User: {user_id}, Session: {session_id}, Prompt: '{prompt}'")

        # 1. Moderation & Toxicity Check
        is_violation, violation_keywords, warn_msg = self.moderation_engine.check(prompt)
        if is_violation:
            logger.warning(f"[Moderation VIOLATION] Detected keywords: {violation_keywords}")
            return chat_inference_pb2.ChatInferenceResponse(
                response_text=warn_msg,
                tokens_used=15,
                is_violation=True,
                violation_keywords=violation_keywords,
                citations=[],
                data_verified=False,
                requires_clarification=False
            )

        # 2. Advanced RAG Retrieval with Strict Verification Filter
        matched_chunks = self.vector_store.search_verified_chunks(prompt, top_k=3, score_threshold=0.20)
        logger.info(f"Retrieved {len(matched_chunks)} verified legal chunks from Vector Store.")

        # 3. Answer Generation & Citation Extraction
        response_text, citations_data, tokens_used, data_verified = self.rag_generator.generate(
            prompt, matched_chunks
        )

        # 4. Map Citations to Protobuf CitationDto
        citation_dtos = []
        for c in citations_data:
            dto = chat_inference_pb2.CitationDto(
                document_title=c.get("document_title", ""),
                article_number=c.get("article_number", ""),
                clause_number=c.get("clause_number", ""),
                source_url=c.get("source_url", ""),
                excerpt=c.get("excerpt", ""),
                chunk_id=c.get("chunk_id", ""),
                point_number=c.get("point_number", ""),
                document_version=c.get("document_version", "1.0")
            )
            citation_dtos.append(dto)

        logger.info(f"[Response Generated] Tokens used: {tokens_used}, Citations: {len(citation_dtos)}, Data Verified: {data_verified}")

        return chat_inference_pb2.ChatInferenceResponse(
            response_text=response_text,
            tokens_used=tokens_used,
            is_violation=False,
            violation_keywords=[],
            citations=citation_dtos,
            data_verified=data_verified,
            requires_clarification=False
        )

    def ProcessImageChatMessage(self, request, context):
        user_id = request.user_id
        session_id = request.session_id
        prompt = request.prompt.strip()
        img_b64 = request.image_base64
        mime_type = request.mime_type or "image/jpeg"

        logger.info(f"[ProcessImageChatMessage] User: {user_id}, Session: {session_id}, Prompt: '{prompt}'")

        # 1. Moderation Check on text prompt
        if prompt:
            is_violation, violation_keywords, warn_msg = self.moderation_engine.check(prompt)
            if is_violation:
                return chat_inference_pb2.ChatInferenceResponse(
                    response_text=warn_msg,
                    tokens_used=15,
                    is_violation=True,
                    violation_keywords=violation_keywords,
                    citations=[],
                    data_verified=False,
                    requires_clarification=False
                )

        # 2. Vision analysis
        observations, requires_clarification, search_query = self.vision_engine.analyze_traffic_image(
            img_b64, mime_type, prompt
        )

        if requires_clarification:
            logger.info("[ProcessImageChatMessage] Image lacks clarity/evidence. Requesting clarification.")
            return chat_inference_pb2.ChatInferenceResponse(
                response_text=observations,
                tokens_used=20,
                is_violation=False,
                violation_keywords=[],
                citations=[],
                data_verified=False,
                requires_clarification=True
            )

        # 3. Use visual observations + search query to retrieve legal chunks
        effective_query = f"{search_query} {observations}".strip()
        matched_chunks = self.vector_store.search_verified_chunks(effective_query, top_k=3, score_threshold=0.20)

        # 4. Synthesize legal answer based on image observations + verified traffic laws
        prompt_with_obs = f"Quan sát từ hình ảnh: {observations}\nCâu hỏi: {prompt or 'Hành vi hoặc biển báo trong ảnh bị xử lý như thế nào?'}"
        response_text, citations_data, tokens_used, data_verified = self.rag_generator.generate(
            prompt_with_obs, matched_chunks
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

        return chat_inference_pb2.ChatInferenceResponse(
            response_text=response_text,
            tokens_used=tokens_used,
            is_violation=False,
            violation_keywords=[],
            citations=citation_dtos,
            data_verified=data_verified,
            requires_clarification=False
        )

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

    def IndexDocument(self, request, context):
        logger.info(f"[IndexDocument] Received {len(request.chunks)} chunks to index.")
        chunks_to_index = []
        for ch in request.chunks:
            chunk_dict = {
                "chunk_id": ch.chunk_id,
                "document_title": ch.document_title,
                "document_number": ch.document_number,
                "chapter": ch.chapter,
                "article": ch.article,
                "clause": ch.clause,
                "point": ch.point,
                "document_version": ch.document_version or "1.0",
                "content": ch.content,
                "source_url": ch.source_url,
                "is_verified": ch.is_verified,
                "is_active": ch.is_active
            }
            chunks_to_index.append(chunk_dict)

        count = self.vector_store.upsert_chunks(chunks_to_index)
        return chat_inference_pb2.IndexDocumentResponse(
            success=True,
            indexed_count=count,
            message=f"Successfully indexed {count} chunks into Qdrant."
        )

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

    def ExplainQuestion(self, request, context):
        """
        Explains practice/exam questions combining official answer key with verified legal grounds.
        Does NOT score or decide correctness (scoring is strictly done by server engine in .NET).
        """
        content = request.question_content
        options = list(request.options)
        key = request.correct_answer_key
        official_exp = request.official_explanation

        logger.info(f"[ExplainQuestion] Explaining question: '{content[:80]}...', Key: '{key}'")

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
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
    chat_inference_pb2_grpc.add_TrafficRagInferenceServicer_to_server(
        TrafficRagInferenceServicer(), server
    )
    bind_addr = f"0.0.0.0:{port}"
    server.add_insecure_port(bind_addr)
    server.start()
    logger.info(f"Traffic Law RAG gRPC Inference Service started on {bind_addr}")
    try:
        server.wait_for_termination()
    except KeyboardInterrupt:
        logger.info("Stopping gRPC server...")
        server.stop(0)

if __name__ == "__main__":
    serve()
