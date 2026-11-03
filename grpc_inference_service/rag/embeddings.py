import json
import math
import os
import time
from urllib.error import HTTPError
from urllib.request import Request, urlopen


class EmbeddingEngine:
    """OpenAI-compatible embedding HTTP API. Configuration is explicit; no local fallback."""

    def __init__(self, model_name="auto", api_key=None):
        self.url = os.environ.get("EMBEDDING_API_URL", "")
        self.api_key = api_key or os.environ.get("EMBEDDING_API_KEY", "")
        self.model = os.environ.get("EMBEDDING_MODEL", "")
        self.DIMENSION = int(os.environ.get("EMBEDDING_DIMENSION", "0"))
        self.provider = os.environ.get("EMBEDDING_PROVIDER", "openai")
        if self.provider == "gemini":
            self.url = "https://generativelanguage.googleapis.com/v1beta/models/" + self.model + ":batchEmbedContents"
        elif self.provider != "openai":
            raise RuntimeError("Unsupported embedding provider")
        if not self.url.startswith("https://") or not self.api_key or not self.model or self.DIMENSION < 1:
            raise RuntimeError("Configure HTTPS EMBEDDING_API_URL, EMBEDDING_API_KEY, EMBEDDING_MODEL and EMBEDDING_DIMENSION")

    def embed_query(self, text):
        return self._embed([text], "RETRIEVAL_QUERY")[0]

    def embed_documents(self, texts):
        # Import jobs are resumable and have a longer deadline than chat turns.
        # Respect provider throttling here without delaying interactive retrieval.
        for attempt in range(8):
            try:
                return self._embed(texts, "RETRIEVAL_DOCUMENT")
            except HTTPError as error:
                if error.code != 429 or attempt == 7:
                    raise
                retry_after = error.headers.get("Retry-After") if error.headers else None
                try:
                    delay = int(retry_after)
                except (TypeError, ValueError):
                    delay = min(15 * (attempt + 1), 60)
                time.sleep(max(1, min(delay, 120)))

    def _embed(self, texts, task_type):
        if not texts:
            return []
        if len(texts) > 32:
            return [vector for index in range(0, len(texts), 32)
                    for vector in self._embed(texts[index:index+32], task_type)]
        if self.provider == "gemini":
            body = {"requests": [{"model": "models/" + self.model, "content": {"parts": [{"text": text}]},
                                  "outputDimensionality": self.DIMENSION, "taskType": task_type} for text in texts]}
            headers = {"x-goog-api-key": self.api_key, "Content-Type": "application/json"}
        else:
            body = {"model": self.model, "input": texts, "dimensions": self.DIMENSION}
            headers = {"Authorization": "Bearer " + self.api_key, "Content-Type": "application/json"}
        request = Request(self.url, data=json.dumps(body).encode(), headers=headers)
        for attempt in range(4):
            try:
                with urlopen(request, timeout=20) as response:
                    payload = json.load(response)
                break
            except HTTPError as error:
                # A quota 429 cannot recover within the chat deadline; preserve it as provider failure.
                if error.code != 503 or attempt == 3:
                    raise
                time.sleep(2 * (attempt + 1))
        if self.provider == "gemini":
            vectors = [row["values"] for row in payload["embeddings"]]
        else:
            data = sorted(payload["data"], key=lambda row: row["index"])
            if [row["index"] for row in data] != list(range(len(texts))):
                raise RuntimeError("Embedding API returned an incomplete batch")
            vectors = [row["embedding"] for row in data]
        if len(vectors) != len(texts):
            raise RuntimeError("Embedding API returned an incomplete batch")
        if any(len(v) != self.DIMENSION or not all(isinstance(x, (int, float)) and math.isfinite(x) for x in v) for v in vectors):
            raise RuntimeError("Embedding API returned invalid dimensions or non-finite values")
        if any(sum(x*x for x in vector) == 0 for vector in vectors):
            raise RuntimeError("Embedding API returned a zero vector")
        return vectors
