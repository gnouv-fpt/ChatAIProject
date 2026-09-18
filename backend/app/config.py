import os
from pathlib import Path
from typing import List, Optional
from pydantic import BaseModel
from dotenv import load_dotenv

# Search and load .env from current directory, parent directory or repo root
BASE_DIR = Path(__file__).resolve().parent.parent.parent
env_paths = [
    Path.cwd() / ".env",
    Path(__file__).resolve().parent.parent / ".env",
    BASE_DIR / ".env",
]
for env_path in env_paths:
    if env_path.exists():
        load_dotenv(dotenv_path=env_path)
        break
else:
    load_dotenv()


class Settings(BaseModel):
    # Application Info
    APP_NAME: str = "FLM Course Knowledge & AI RAG Assistant API"
    APP_VERSION: str = "1.0.0"
    APP_DESCRIPTION: str = (
        "Backend FastAPI server providing RESTful RAG API for FPT University FLM Curriculum & Syllabi. "
        "Supports query retrieval on Course Learning Outcomes (LOs), Assessments (PE/FE), Credits, Roadmaps, and Prerequisites."
    )
    
    # Server Settings
    HOST: str = os.getenv("HOST", "0.0.0.0")
    PORT: int = int(os.getenv("PORT", "8000"))
    DEBUG: bool = os.getenv("DEBUG", "false").lower() in ("1", "true", "yes")

    # CORS Settings
    CORS_ORIGINS_RAW: str = os.getenv("CORS_ORIGINS", "*")
    
    @property
    def cors_origins(self) -> List[str]:
        if self.CORS_ORIGINS_RAW == "*":
            return ["*"]
        return [origin.strip() for origin in self.CORS_ORIGINS_RAW.split(",") if origin.strip()]

    # Knowledge Paths
    KNOWLEDGE_VAULT_DIR: str = os.getenv("KNOWLEDGE_VAULT_DIR", "flm_knowledge_vault")
    COURSES_DATA_PATH: str = os.getenv("COURSES_DATA_PATH", "flm_flutter_data/courses_data.json")

    # LLM Settings
    LLM_PROVIDER: str = os.getenv("LLM_PROVIDER", "auto").lower()
    
    GEMINI_API_KEY: Optional[str] = os.getenv("GEMINI_API_KEY")
    GEMINI_MODEL: str = os.getenv("GEMINI_MODEL", "gemini-1.5-flash")
    
    OPENAI_API_KEY: Optional[str] = os.getenv("OPENAI_API_KEY")
    OPENAI_BASE_URL: str = os.getenv("OPENAI_BASE_URL", "https://api.openai.com/v1")
    OPENAI_MODEL: str = os.getenv("OPENAI_MODEL", "gpt-4o-mini")
    
    GROQ_API_KEY: Optional[str] = os.getenv("GROQ_API_KEY")
    GROQ_MODEL: str = os.getenv("GROQ_MODEL", "llama-3.3-70b-versatile")
    
    OLLAMA_BASE_URL: str = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")
    OLLAMA_MODEL: str = os.getenv("OLLAMA_MODEL", "llama3.2")
    
    # RAG Settings
    TOP_K_CHUNKS: int = int(os.getenv("TOP_K_CHUNKS", "4"))
    SIMILARITY_THRESHOLD: float = float(os.getenv("SIMILARITY_THRESHOLD", "0.10"))
    ENABLE_EXACT_CODE_BOOST: bool = os.getenv("ENABLE_EXACT_CODE_BOOST", "true").lower() in ("1", "true", "yes")

    def get_vault_path(self) -> Path:
        """Resolve knowledge vault directory path."""
        p = Path(self.KNOWLEDGE_VAULT_DIR)
        if not p.is_absolute():
            # Try repo root relative
            candidate = BASE_DIR / self.KNOWLEDGE_VAULT_DIR
            if candidate.exists():
                return candidate
            # Try cwd relative
            candidate_cwd = Path.cwd() / self.KNOWLEDGE_VAULT_DIR
            if candidate_cwd.exists():
                return candidate_cwd
        return p

    def get_courses_data_path(self) -> Path:
        """Resolve courses_data.json file path."""
        p = Path(self.COURSES_DATA_PATH)
        if not p.is_absolute():
            candidate = BASE_DIR / self.COURSES_DATA_PATH
            if candidate.exists():
                return candidate
            candidate_cwd = Path.cwd() / self.COURSES_DATA_PATH
            if candidate_cwd.exists():
                return candidate_cwd
        return p


settings = Settings()
