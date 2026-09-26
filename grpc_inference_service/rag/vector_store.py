import os
import uuid
import hashlib
from typing import List, Dict, Any, Optional
import numpy as np

class QdrantTrafficStore:
    """
    Qdrant Vector Database Integration for Vietnam Traffic Law.
    Provides collection management, embedding storage, and filtered retrieval
    enforcing is_verified == True and is_active == True.
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
                # Test connectivity
                client.get_collections()
                self._client = client
                print(f"[QdrantStore] Connected to remote Qdrant at {self.host}:{self.port}")
            except Exception:
                # If remote server not running, use fast in-memory Qdrant instance
                self._client = QdrantClient(":memory:")
                print("[QdrantStore] Remote Qdrant server unavailable. Using in-memory Qdrant instance.")

            # Ensure collection exists
            collections = [c.name for c in self._client.get_collections().collections]
            if self.COLLECTION_NAME not in collections:
                self._client.create_collection(
                    collection_name=self.COLLECTION_NAME,
                    vectors_config=VectorParams(size=self.vector_size, distance=Distance.COSINE)
                )
                print(f"[QdrantStore] Created collection '{self.COLLECTION_NAME}' (size={self.vector_size})")

        except Exception as e:
            print(f"[QdrantStore] Warning: Could not initialize Qdrant client ({e}). Using in-memory fallback store.")
            self._is_local_fallback = True

    def upsert_chunks(self, chunks: List[Dict[str, Any]]) -> int:
        """
        Upsert a list of document chunks into Qdrant.
        Each chunk must have:
            content, document_title, document_number, article, clause, source_url, is_verified, is_active
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
                    chunk_id = chunk.get("chunk_id") or str(uuid.uuid4())
                    # Use SHA-256 hash of chunk_id for deterministic, collision-free point IDs.
                    # This ensures idempotency: same chunk_id → same Qdrant point ID on re-seed.
                    point_id = int(hashlib.sha256(chunk_id.encode()).hexdigest()[:16], 16) % (2**63)

                    payload = {
                        "chunk_id": chunk_id,
                        "document_title": chunk.get("document_title", ""),
                        "document_number": chunk.get("document_number", ""),
                        "chapter": chunk.get("chapter", ""),
                        "article": chunk.get("article", ""),
                        "clause": chunk.get("clause", ""),
                        "content": chunk.get("content", ""),
                        "source_url": chunk.get("source_url", ""),
                        "is_verified": bool(chunk.get("is_verified", True)),
                        "is_active": bool(chunk.get("is_active", True))
                    }

                    points.append(PointStruct(id=point_id, vector=vector, payload=payload))

                self._client.upsert(collection_name=self.COLLECTION_NAME, points=points)
                return len(points)
            except Exception as e:
                print(f"[QdrantStore] Upsert to Qdrant failed: {e}. Storing in memory fallback.")

        # Fallback in-memory
        for chunk, vector in zip(chunks, embeddings):
            self._fallback_store.append({
                "payload": chunk,
                "vector": np.array(vector, dtype=np.float32)
            })
        return len(chunks)

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
                print(f"[QdrantStore] Search in Qdrant failed: {e}. Trying memory fallback.")

        # Memory fallback search with cosine similarity
        q_vec = np.array(query_vector, dtype=np.float32)
        norm_q = np.linalg.norm(q_vec)
        if norm_q == 0:
            return []

        results = []
        for item in self._fallback_store:
            payload = item["payload"]
            # Strict verification filter
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
