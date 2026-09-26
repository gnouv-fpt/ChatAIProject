import os
import hashlib
import numpy as np
from typing import List, Union

class EmbeddingEngine:
    """
    Embedding Engine for Vietnamese Traffic Law RAG.
    Supports:
    1. Google Gemini Embeddings (if GOOGLE_API_KEY is present)
    2. SentenceTransformers (if installed)
    3. Built-in Deterministic Hashing Vectorizer (fast, zero dependency, always works offline)
    """

    DIMENSION = 384

    def __init__(self, model_name: str = "auto", api_key: str = None):
        self.DIMENSION = 384  # Default; overridden to 768 if Gemini is successfully initialized
        self.api_key = api_key or os.getenv("GOOGLE_API_KEY") or os.getenv("GEMINI_API_KEY")
        self.provider = "builtin"
        self._gemini_client = None
        self._st_model = None

        if self.api_key:
            try:
                import google.generativeai as genai
                genai.configure(api_key=self.api_key)
                self._gemini_client = genai
                self.provider = "gemini"
                self.DIMENSION = 768
                print(f"[EmbeddingEngine] Using Google Gemini Embedding ({self.DIMENSION}d)")
                return
            except Exception as e:
                print(f"[EmbeddingEngine] Gemini embedding init failed: {e}. Falling back.")

        try:
            from sentence_transformers import SentenceTransformer
            self._st_model = SentenceTransformer("paraphrase-multilingual-MiniLM-L12-v2")
            self.provider = "sentence-transformers"
            self.DIMENSION = 384
            print(f"[EmbeddingEngine] Using SentenceTransformers ({self.DIMENSION}d)")
            return
        except Exception:
            pass

        print(f"[EmbeddingEngine] Using Built-in Semantic Hashing Embedding ({self.DIMENSION}d)")
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
                print(f"[EmbeddingEngine] Gemini embed failed: {e}, falling back to builtin.")

        if self.provider == "sentence-transformers" and self._st_model:
            try:
                vecs = self._st_model.encode(texts, normalize_embeddings=True)
                return vecs.tolist()
            except Exception as e:
                print(f"[EmbeddingEngine] ST embed failed: {e}, falling back to builtin.")

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
        # Add word tokens and bigrams
        terms = list(tokens)
        for i in range(len(tokens) - 1):
            terms.append(f"{tokens[i]}_{tokens[i+1]}")
        # Add 3-char ngrams for subword matching
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
