import hashlib
import os
from qdrant_client import QdrantClient, models


class QdrantTrafficStore:
    COLLECTION_NAME = "traffic_law_documents"

    def __init__(self, embedding_engine, host=None, port=None, *, client=None):
        self.COLLECTION_NAME = os.getenv("QDRANT_COLLECTION", self.COLLECTION_NAME)
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

    def upsert_chunks(self, chunks, is_active=lambda: True):
        if not chunks:
            return 0
        payloads = []
        for chunk in chunks:
            if not chunk.get("chunk_id"):
                raise ValueError("SQL chunk ID is required")
            payload = dict(chunk)
            payload["content_hash"] = hashlib.sha256(chunk["content"].encode()).hexdigest()
            payloads.append(payload)
        for offset in range(0, len(payloads), 8):
            if not is_active():
                raise RuntimeError("Indexing request cancelled")
            batch = payloads[offset:offset+8]
            prior = {point.id: point for point in self._client.retrieve(self.COLLECTION_NAME,
                ids=[self.chunk_id_to_point_id(c['chunk_id']) for c in batch], with_payload=True, with_vectors=True)}
            pending = [c for c in batch if not (point := prior.get(self.chunk_id_to_point_id(c['chunk_id'])))
                       or point.payload != c]
            if not pending:
                continue
            reusable = {}
            needs_embedding = []
            for chunk in pending:
                point = prior.get(self.chunk_id_to_point_id(chunk['chunk_id']))
                if point and point.payload.get('chunk_id') == chunk['chunk_id'] and \
                        point.payload.get('content_hash') == chunk['content_hash'] and \
                        isinstance(point.vector, list) and len(point.vector) == self.vector_size:
                    reusable[chunk['chunk_id']] = point.vector
                else:
                    needs_embedding.append(chunk)
            embedded = self.embedding_engine.embed_documents([c['content'] for c in needs_embedding])
            vectors = {**reusable, **dict(zip((c['chunk_id'] for c in needs_embedding), embedded))}
            points = [models.PointStruct(id=self.chunk_id_to_point_id(c['chunk_id']),
                                         vector=vectors[c['chunk_id']], payload=c) for c in pending]
            result = self._client.upsert(self.COLLECTION_NAME, points=points, wait=True)
            if result.status != models.UpdateStatus.COMPLETED:
                raise RuntimeError("Qdrant did not acknowledge indexing")
        return len(chunks)

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

    def verify_document_index(self, chunks):
        if not chunks or len({c['chunk_id'] for c in chunks}) != len(chunks):
            return False, 0, "Missing or duplicate expected chunk IDs"
        document_ids = {c['document_id'] for c in chunks}
        document_numbers = {c['document_number'] for c in chunks}
        if len(document_ids) != 1 or len(document_numbers) != 1:
            return False, 0, "Expected chunks span multiple documents"
        expected = {}
        for chunk in chunks:
            point_id = self.chunk_id_to_point_id(chunk['chunk_id'])
            if point_id in expected:
                return False, 0, "Point ID collision in expected chunks"
            payload = dict(chunk)
            content_hash = hashlib.sha256(payload['content'].encode()).hexdigest()
            if payload['content_hash'].lower() != content_hash:
                return False, 0, "Expected content hash mismatch"
            payload['content_hash'] = content_hash
            expected[point_id] = payload
        selector = models.Filter(must=[models.FieldCondition(key="document_id",
            match=models.MatchValue(value=next(iter(document_ids))))])
        actual_count = self._client.count(self.COLLECTION_NAME, count_filter=selector, exact=True).count
        if actual_count != len(expected):
            return False, 0, "Document point count mismatch"
        matched = 0
        for offset in range(0, len(expected), 64):
            ids = list(expected)[offset:offset + 64]
            points = self._client.retrieve(self.COLLECTION_NAME, ids=ids, with_payload=True)
            if len(points) != len(ids):
                return False, matched, "Missing expected point"
            for point in points:
                if point.payload != expected[point.id]:
                    return False, matched, "Point payload mismatch"
                matched += 1
        return True, matched, "All point IDs and payload fields match"

    def search_verified_chunks(self, query, top_k=5, score_threshold=0.20):
        result = self._client.query_points(self.COLLECTION_NAME, query=self.embedding_engine.embed_query(query),
            query_filter=models.Filter(must=[models.FieldCondition(key=key, match=models.MatchValue(value=True))
                for key in ("is_verified", "is_active")]), limit=top_k, score_threshold=score_threshold,
            with_payload=True)
        return [dict(point.payload, score=point.score) for point in result.points]
