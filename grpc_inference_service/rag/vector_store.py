import hashlib
import os
from qdrant_client import QdrantClient, models


class QdrantTrafficStore:
    COLLECTION_NAME = "traffic_law_documents"

    def __init__(self, embedding_engine, host=None, port=None, *, client=None):
        self.embedding_engine = embedding_engine
        self.vector_size = embedding_engine.DIMENSION
        # Tests explicitly inject their isolated client; runtime always connects to Qdrant.
        self._client = client if client is not None else QdrantClient(
            host=host or os.getenv("QDRANT_HOST", "localhost"),
            port=port or int(os.getenv("QDRANT_PORT", "6333")), timeout=10)
        if not self._client.collection_exists(self.COLLECTION_NAME):
            self._client.create_collection(self.COLLECTION_NAME,
                vectors_config=models.VectorParams(size=self.vector_size, distance=models.Distance.COSINE))
        info = self._client.get_collection(self.COLLECTION_NAME)
        if info.config.params.vectors.size != self.vector_size:
            raise RuntimeError("Qdrant collection dimension does not match the embedding API")

    @staticmethod
    def chunk_id_to_point_id(chunk_id):
        return int(hashlib.sha256(chunk_id.encode()).hexdigest()[:16], 16) % (2**63)

    def upsert_chunks(self, chunks):
        if not chunks:
            return 0
        vectors = self.embedding_engine.embed_documents([c["content"] for c in chunks])
        points = []
        for chunk, vector in zip(chunks, vectors):
            if not chunk.get("chunk_id"):
                raise ValueError("SQL chunk ID is required")
            payload = dict(chunk)
            payload["content_hash"] = hashlib.sha256(chunk["content"].encode()).hexdigest()
            points.append(models.PointStruct(id=self.chunk_id_to_point_id(chunk["chunk_id"]),
                vector=vector, payload=payload))
        result = self._client.upsert(self.COLLECTION_NAME, points=points, wait=True)
        if result.status != models.UpdateStatus.COMPLETED:
            raise RuntimeError("Qdrant did not acknowledge indexing")
        return len(points)

    def deactivate_document(self, document_number, chunk_ids=None):
        if document_number:
            selector = models.Filter(must=[models.FieldCondition(key="document_number",
                match=models.MatchValue(value=document_number))])
            count = self._client.count(self.COLLECTION_NAME, count_filter=selector, exact=True).count
        elif chunk_ids:
            selector = [self.chunk_id_to_point_id(cid) for cid in chunk_ids]
            count = len(self._client.retrieve(self.COLLECTION_NAME, ids=selector))
        else:
            raise ValueError("Document number or chunk IDs are required")
        result = self._client.set_payload(self.COLLECTION_NAME, payload={"is_active": False}, points=selector, wait=True)
        if result.status != models.UpdateStatus.COMPLETED:
            raise RuntimeError("Qdrant did not acknowledge deactivation")
        return count

    def search_verified_chunks(self, query, top_k=5, score_threshold=0.20):
        result = self._client.query_points(self.COLLECTION_NAME, query=self.embedding_engine.embed_query(query),
            query_filter=models.Filter(must=[models.FieldCondition(key=key, match=models.MatchValue(value=True))
                for key in ("is_verified", "is_active")]), limit=top_k, score_threshold=score_threshold,
            with_payload=True)
        return [dict(point.payload, score=point.score) for point in result.points]
