#!/usr/bin/env python3
"""Convenient startup script for FLM FastAPI RAG Backend."""
import os
import sys
from pathlib import Path

# Add paths
root_dir = Path(__file__).resolve().parent
backend_dir = root_dir / "backend"

sys.path.insert(0, str(root_dir))
sys.path.insert(0, str(backend_dir))

import uvicorn
from backend.app.config import settings

if __name__ == "__main__":
    print(f"===========================================================")
    print(f"  {settings.APP_NAME}")
    print(f"  Version: {settings.APP_VERSION}")
    print(f"  URL:     http://localhost:{settings.PORT}")
    print(f"  Docs:    http://localhost:{settings.PORT}/docs")
    print(f"===========================================================")
    
    uvicorn.run(
        "backend.app.main:app",
        host=settings.HOST,
        port=settings.PORT,
        reload=settings.DEBUG,
    )
