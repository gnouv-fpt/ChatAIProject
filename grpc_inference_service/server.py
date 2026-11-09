import base64
import functools
import os
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
        except Exception:
            logger.exception("Inference RPC failed: %s", method.__name__)
            context.abort(grpc.StatusCode.UNAVAILABLE, "Inference dependency unavailable")
    return wrapped

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

        logger.info("All components initialized successfully.")

    @staticmethod
    def _response(text, citations=(), tokens=0, status="NoMatch", images=False):
        response = chat_inference_pb2.ChatInferenceResponse(
            response_text=text, citations=[chat_inference_pb2.CitationDto(**c) for c in citations],
            data_verified=status == "Answered", is_violation=status == "Blocked",
            requires_clarification=status == "NeedsClarification", result_status=status,
            contract_version=2, images_processed=images)
        if tokens is not None and tokens >= 0:
            response.tokens_used = tokens
        return response

    @rpc_errors
    def ProcessChatMessage(self, request, context):
        prompt = request.prompt.strip()
        is_violation, keywords, warning = self.moderation_engine.check(prompt)
        if is_violation:
            response = self._response(warning, status="Blocked", images=bool(request.images))
            response.violation_keywords.extend(keywords)
            return response
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
            observations.append(observation)
            vision_queries.append(query)
        history = "\n".join(f"{h.role}: {h.content}" for h in request.history[-10:])
        query = "\n".join([history, *observations, prompt]).strip()
        # Keep old assistant wording out of retrieval so a changed subject (red -> yellow light)
        # can retrieve new evidence. History remains available to grounded answer generation.
        retrieval_query = "\n".join([*vision_queries, prompt]).strip()
        chunks = self.vector_store.search_verified_chunks(
            retrieval_query, top_k=5, score_threshold=0.20)
        text, citations, tokens, verified = self.rag_generator.generate(
            query, chunks, max(0, budget - vision_tokens), current_question=prompt,
            prefer_gemini=bool(request.images))
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
