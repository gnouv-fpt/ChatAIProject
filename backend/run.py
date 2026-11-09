import os
import sys
from pathlib import Path

# Ensure root directory and backend directory are in sys.path
backend_dir = Path(__file__).resolve().parent
repo_root = backend_dir.parent
if str(repo_root) not in sys.path:
    sys.path.insert(0, str(repo_root))
if str(backend_dir) not in sys.path:
    sys.path.insert(0, str(backend_dir))

import uvicorn
from app.config import settings

if __name__ == "__main__":
    print(f"Starting {settings.APP_NAME} v{settings.APP_VERSION}")
    print(f"Listening on http://{settings.HOST}:{settings.PORT}")
    print(f"Swagger Documentation available at: http://localhost:{settings.PORT}/docs")
    
    uvicorn.run(
        "app.main:app",
        host=settings.HOST,
        port=settings.PORT,
        reload=settings.DEBUG,
        app_dir=str(backend_dir),
    )
