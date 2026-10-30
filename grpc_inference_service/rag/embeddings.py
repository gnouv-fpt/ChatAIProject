import json
import math
import os
from urllib.request import Request, urlopen


class EmbeddingEngine:
    """OpenAI-compatible embedding HTTP API. Configuration is explicit; no local fallback."""

    def __init__(self, model_name="auto", api_key=None):
        self.url = os.environ.get("EMBEDDING_API_URL", "")
        self.api_key = api_key or os.environ.get("EMBEDDING_API_KEY", "")
        self.model = os.environ.get("EMBEDDING_MODEL", "")
        self.DIMENSION = int(os.environ.get("EMBEDDING_DIMENSION", "0"))
        self.provider = "api"
        if not self.url.startswith("https://") or not self.api_key or not self.model or self.DIMENSION < 1:
            raise RuntimeError("Configure HTTPS EMBEDDING_API_URL, EMBEDDING_API_KEY, EMBEDDING_MODEL and EMBEDDING_DIMENSION")

    def embed_query(self, text):
        return self.embed_documents([text])[0]

    def embed_documents(self, texts):
        if not texts:
            return []
        request = Request(self.url, data=json.dumps({"model": self.model, "input": texts,
            "dimensions": self.DIMENSION}).encode(), headers={"Authorization": "Bearer " + self.api_key,
            "Content-Type": "application/json"})
        with urlopen(request, timeout=15) as response:
            payload = json.load(response)
        data = sorted(payload["data"], key=lambda row: row["index"])
        if [row["index"] for row in data] != list(range(len(texts))):
            raise RuntimeError("Embedding API returned an incomplete batch")
        vectors = [row["embedding"] for row in data]
        if any(len(v) != self.DIMENSION or not all(isinstance(x, (int, float)) and math.isfinite(x) for x in v) for v in vectors):
            raise RuntimeError("Embedding API returned invalid dimensions or non-finite values")
        return vectors
