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
from data.seed_traffic_law import get_seed_traffic_law_chunks

# These will be available after compiling protos
try:
    import chat_inference_pb2
    import chat_inference_pb2_grpc
except ImportError:
    # Auto-compile proto if not compiled yet
    from generate_protos import compile_proto
    compile_proto()
    import chat_inference_pb2
    import chat_inference_pb2_grpc

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("TrafficRagGrpcServer")

class TrafficRagInferenceServicer(chat_inference_pb2_grpc.TrafficRagInferenceServicer):
    """
    gRPC Servicer implementing Vietnam Traffic Law Moderation & Advanced RAG.
    """

    def __init__(self):
        logger.info("Initializing TrafficRagInferenceServicer components...")
        self.moderation_engine = ModerationEngine()
        self.verification_engine = DataVerificationEngine()
        self.embedding_engine = EmbeddingEngine()
        self.vector_store = QdrantTrafficStore(self.embedding_engine)
        self.rag_generator = TrafficRagGenerator()

        # Seed initial authentic traffic law data if needed
        self._seed_initial_data()
        logger.info("All components initialized successfully.")

    def _seed_initial_data(self):
        # Skip seeding if collection already has data (e.g. Qdrant Docker with persistent volume).
        # For in-memory Qdrant, count will always be 0 on startup, so seeding proceeds normally.
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
                data_verified=False
            )

        # 2. Advanced RAG Retrieval with Strict Verification Filter
        # Only retrieves chunks where is_verified == True and is_active == True
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
                excerpt=c.get("excerpt", "")
            )
            citation_dtos.append(dto)

        logger.info(f"[Response Generated] Tokens used: {tokens_used}, Citations: {len(citation_dtos)}, Data Verified: {data_verified}")

        return chat_inference_pb2.ChatInferenceResponse(
            response_text=response_text,
            tokens_used=tokens_used,
            is_violation=False,
            violation_keywords=[],
            citations=citation_dtos,
            data_verified=data_verified
        )

    def VerifyLegalDocument(self, request, context):
        doc_title = request.document_title
        doc_number = request.document_number
        content = request.content

        logger.info(f"[VerifyLegalDocument] Title: '{doc_title}', Number: '{doc_number}'")
        res = self.verification_engine.verify_document(doc_title, doc_number, content)

        return chat_inference_pb2.VerificationResponse(
            is_valid=res["is_valid"],
            status=res["status"],
            notes=res["notes"]
        )

    def IndexDocument(self, request, context):
        logger.info(f"[IndexDocument] Received {len(request.chunks)} chunks to index.")
        chunks_to_index = []
        for ch in request.chunks:
            # Check verification before indexing
            chunk_dict = {
                "chunk_id": ch.chunk_id,
                "document_title": ch.document_title,
                "document_number": ch.document_number,
                "chapter": ch.chapter,
                "article": ch.article,
                "clause": ch.clause,
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
