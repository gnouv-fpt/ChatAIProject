import os
import uuid
import hashlib
import logging
from typing import List, Dict, Any, Optional
import numpy as np

logger = logging.getLogger("QdrantTrafficStore")

class QdrantTrafficStore:
    """
    Qdrant Vector Database Integration for Vietnam Traffic Law.
    Provides collection management, embedding storage, and filtered retrieval
    enforcing is_verified == True and is_active == True.
    Supports deactivation/soft-delete and idempotent point ID mapping.
    """

    COLLECTION_NAME = "traffic_law_documents"

    def __init__(self, embedding_engine, host: str = None, port: int = None):
        self.embedding_engine = embedding_engine
        self.host = host or os.getenv("QDRANT_HOST", "localhost")
        self.port = port or int(os.getenv("QDRANT_PORT", "6333"))
        self.vector_size = self.embedding_engine.DIMENSION

        self._client = None
        self._is_local_fallback = False
        self._fallback_store = [] # Fallback in-memory list if Qdrant server is unreachable

        self._init_client()

    def _init_client(self):
        try:
            from qdrant_client import QdrantClient
            from qdrant_client.http.models import Distance, VectorParams

            # First try connecting to remote/docker Qdrant server
            try:
                client = QdrantClient(host=self.host, port=self.port, timeout=1.5)
                client.get_collections()
                self._client = client
                logger.info(f"[QdrantStore] Connected to remote Qdrant at {self.host}:{self.port}")
            except Exception:
                self._client = QdrantClient(":memory:")
                logger.info("[QdrantStore] Remote Qdrant server unavailable. Using in-memory Qdrant instance.")

            # Ensure collection exists
            collections = [c.name for c in self._client.get_collections().collections]
            if self.COLLECTION_NAME not in collections:
                self._client.create_collection(
                    collection_name=self.COLLECTION_NAME,
                    vectors_config=VectorParams(size=self.vector_size, distance=Distance.COSINE)
                )
                logger.info(f"[QdrantStore] Created collection '{self.COLLECTION_NAME}' (size={self.vector_size})")

        except Exception as e:
            logger.warning(f"[QdrantStore] Warning: Could not initialize Qdrant client ({e}). Using in-memory fallback store.")
            self._is_local_fallback = True

    @staticmethod
    def chunk_id_to_point_id(chunk_id: str) -> int:
        """
        Deterministic, collision-free point ID mapping from SQL Chunk Guid or String ID.
        Ensures idempotency across re-indexing.
        """
        return int(hashlib.sha256(chunk_id.encode("utf-8")).hexdigest()[:16], 16) % (2**63)

    def upsert_chunks(self, chunks: List[Dict[str, Any]]) -> int:
        """
        Upsert a list of document chunks into Qdrant.
        Each chunk contains:
            chunk_id, document_title, document_number, chapter, article, clause, point,
            content, source_url, is_verified, is_active, document_version
        """
        if not chunks:
            return 0

        texts = [c.get("content", "") for c in chunks]
        embeddings = self.embedding_engine.embed_documents(texts)

        if not self._is_local_fallback and self._client:
            try:
                from qdrant_client.http.models import PointStruct

                points = []
                for idx, (chunk, vector) in enumerate(zip(chunks, embeddings)):
                    chunk_id = str(chunk.get("chunk_id") or uuid.uuid4())
                    point_id = self.chunk_id_to_point_id(chunk_id)

                    payload = {
                        "chunk_id": chunk_id,
                        "document_title": chunk.get("document_title", ""),
                        "document_number": chunk.get("document_number", ""),
                        "chapter": chunk.get("chapter", ""),
                        "article": chunk.get("article", ""),
                        "clause": chunk.get("clause", ""),
                        "point": chunk.get("point", ""),
                        "document_version": chunk.get("document_version", "1.0"),
                        "content": chunk.get("content", ""),
                        "source_url": chunk.get("source_url", ""),
                        "is_verified": bool(chunk.get("is_verified", True)),
                        "is_active": bool(chunk.get("is_active", True))
                    }

                    points.append(PointStruct(id=point_id, vector=vector, payload=payload))

                self._client.upsert(collection_name=self.COLLECTION_NAME, points=points)
                return len(points)
            except Exception as e:
                logger.error(f"[QdrantStore] Upsert to Qdrant failed: {e}. Storing in memory fallback.")

        # Fallback in-memory
        for chunk, vector in zip(chunks, embeddings):
            c_copy = dict(chunk)
            c_copy["point_id"] = self.chunk_id_to_point_id(str(chunk.get("chunk_id") or uuid.uuid4()))
            self._fallback_store.append({
                "payload": c_copy,
                "vector": np.array(vector, dtype=np.float32)
            })
        return len(chunks)

    def deactivate_document(self, document_number: str = "", chunk_ids: Optional[List[str]] = None) -> int:
        """
        Deactivate document chunks by setting is_active = False.
        Allows instant revocation from RAG retrieval without deleting points.
        """
        updated_count = 0
        target_point_ids = []

        if chunk_ids:
            target_point_ids = [self.chunk_id_to_point_id(cid) for cid in chunk_ids]

        if not self._is_local_fallback and self._client:
            try:
                from qdrant_client.http.models import Filter, FieldCondition, MatchValue

                if document_number:
                    # Update all chunks of this document
                    filter_criteria = Filter(
                        must=[FieldCondition(key="document_number", match=MatchValue(value=document_number))]
                    )
                    self._client.set_payload(
                        collection_name=self.COLLECTION_NAME,
                        payload={"is_active": False},
                        points=filter_criteria
                    )
                    logger.info(f"[QdrantStore] Deactivated document {document_number} via filter.")
                    return 1

                if target_point_ids:
                    self._client.set_payload(
                        collection_name=self.COLLECTION_NAME,
                        payload={"is_active": False},
                        points=target_point_ids
                    )
                    logger.info(f"[QdrantStore] Deactivated {len(target_point_ids)} points by ID.")
                    return len(target_point_ids)
            except Exception as e:
                logger.warning(f"[QdrantStore] Deactivate in Qdrant failed: {e}")

        # Update fallback store
        for item in self._fallback_store:
            p = item["payload"]
            if (document_number and p.get("document_number") == document_number) or \
               (chunk_ids and p.get("chunk_id") in chunk_ids):
                p["is_active"] = False
                updated_count += 1

        return updated_count

    def search_verified_chunks(self, query: str, top_k: int = 5, score_threshold: float = 0.20) -> List[Dict[str, Any]]:
        """
        Search for traffic law chunks relevant to the query.
        CRITICAL RULE: Enforces filter (is_verified == True and is_active == True)
        to prevent outdated / unverified legal clauses from being retrieved.
        """
        query_vector = self.embedding_engine.embed_query(query)

        if not self._is_local_fallback and self._client:
            try:
                from qdrant_client.http.models import Filter, FieldCondition, MatchValue

                verified_filter = Filter(
                    must=[
                        FieldCondition(key="is_verified", match=MatchValue(value=True)),
                        FieldCondition(key="is_active", match=MatchValue(value=True))
                    ]
                )

                if hasattr(self._client, "query_points"):
                    query_res = self._client.query_points(
                        collection_name=self.COLLECTION_NAME,
                        query=query_vector,
                        query_filter=verified_filter,
                        limit=top_k,
                        score_threshold=score_threshold
                    )
                    hits = query_res.points
                elif hasattr(self._client, "search"):
                    hits = self._client.search(
                        collection_name=self.COLLECTION_NAME,
                        query_vector=query_vector,
                        query_filter=verified_filter,
                        limit=top_k,
                        score_threshold=score_threshold
                    )
                else:
                    hits = []

                results = []
                for hit in hits:
                    payload = dict(hit.payload)
                    payload["score"] = hit.score
                    results.append(payload)

                return results
            except Exception as e:
                logger.error(f"[QdrantStore] Search in Qdrant failed: {e}. Trying memory fallback.")

        # Memory fallback search with cosine similarity
        q_vec = np.array(query_vector, dtype=np.float32)
        norm_q = np.linalg.norm(q_vec)
        if norm_q == 0:
            return []

        results = []
        for item in self._fallback_store:
            payload = item["payload"]
            if not payload.get("is_verified", False) or not payload.get("is_active", True):
                continue

            doc_vec = item["vector"]
            norm_d = np.linalg.norm(doc_vec)
            if norm_d == 0:
                continue

            similarity = float(np.dot(q_vec, doc_vec) / (norm_q * norm_d))
            if similarity >= score_threshold:
                match = dict(payload)
                match["score"] = similarity
                results.append(match)

        results.sort(key=lambda x: x["score"], reverse=True)
        return results[:top_k]
