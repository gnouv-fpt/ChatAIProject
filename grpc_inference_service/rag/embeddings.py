import os
import hashlib
import logging
import numpy as np
from typing import List

logger = logging.getLogger("EmbeddingEngine")

class EmbeddingEngine:
    """
    Embedding Engine for Vietnamese Traffic Law RAG.
    Ensures uniform vector dimension across query and indexing.
    Default dimension is 384 for fast, deterministic performance and compatibility with Qdrant.
    """

    DIMENSION = 384

    def __init__(self, model_name: str = "auto", api_key: str = None):
        self.api_key = api_key or os.getenv("GOOGLE_API_KEY") or os.getenv("GEMINI_API_KEY")
        self.provider = "builtin"
        self._gemini_client = None
        self._st_model = None

        configured_dim = os.getenv("EMBEDDING_DIMENSION")
        if configured_dim:
            self.DIMENSION = int(configured_dim)

        # Check for sentence-transformers
        try:
            from sentence_transformers import SentenceTransformer
            self._st_model = SentenceTransformer("paraphrase-multilingual-MiniLM-L12-v2")
            self.provider = "sentence-transformers"
            self.DIMENSION = 384
            logger.info(f"[EmbeddingEngine] Using SentenceTransformers paraphrase-multilingual-MiniLM-L12-v2 ({self.DIMENSION}d)")
            return
        except Exception:
            pass

        # Check for Gemini if explicitly configured with 768d
        if self.api_key and os.getenv("USE_GEMINI_EMBEDDING", "false").lower() == "true":
            try:
                import google.generativeai as genai
                genai.configure(api_key=self.api_key)
                self._gemini_client = genai
                self.provider = "gemini"
                self.DIMENSION = 768
                logger.info(f"[EmbeddingEngine] Using Google Gemini Embedding ({self.DIMENSION}d)")
                return
            except Exception as e:
                logger.warning(f"[EmbeddingEngine] Gemini embedding init failed: {e}. Falling back.")

        logger.info(f"[EmbeddingEngine] Using Built-in Semantic Hashing Embedding ({self.DIMENSION}d)")
        self.provider = "builtin"

    def embed_query(self, text: str) -> List[float]:
        return self.embed_documents([text])[0]

    def embed_documents(self, texts: List[str]) -> List[List[float]]:
        if self.provider == "gemini" and self._gemini_client:
            try:
                embeddings = []
                for t in texts:
                    res = self._gemini_client.embed_content(
                        model="models/text-embedding-004",
                        content=t,
                        task_type="retrieval_document"
                    )
                    embeddings.append(res['embedding'])
                return embeddings
            except Exception as e:
                logger.warning(f"[EmbeddingEngine] Gemini embed failed: {e}, falling back to builtin.")

        if self.provider == "sentence-transformers" and self._st_model:
            try:
                vecs = self._st_model.encode(texts, normalize_embeddings=True)
                return vecs.tolist()
            except Exception as e:
                logger.warning(f"[EmbeddingEngine] ST embed failed: {e}, falling back to builtin.")

        # Built-in deterministic semantic hashing vectorizer
        return [self._builtin_embed(t) for t in texts]

    def _builtin_embed(self, text: str) -> List[float]:
        """
        Generates a normalized 384-dimensional vector using bag-of-ngrams
        and feature hashing with Vietnamese tokenization support.
        """
        vec = np.zeros(self.DIMENSION, dtype=np.float32)
        if not text:
            return vec.tolist()

        tokens = text.lower().split()
        terms = list(tokens)
        for i in range(len(tokens) - 1):
            terms.append(f"{tokens[i]}_{tokens[i+1]}")
        cleaned = text.lower().replace(" ", "")
        for i in range(len(cleaned) - 2):
            terms.append(cleaned[i:i+3])

        for term in terms:
            h = int(hashlib.md5(term.encode('utf-8')).hexdigest(), 16)
            idx = h % self.DIMENSION
            sign = 1.0 if ((h >> 8) & 1) else -1.0
            vec[idx] += sign

        norm = np.linalg.norm(vec)
        if norm > 0:
            vec = vec / norm

        return vec.tolist()
