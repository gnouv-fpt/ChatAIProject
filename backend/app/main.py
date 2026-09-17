from contextlib import asynccontextmanager
import logging
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse

from .config import settings
from .api.v1.router import api_v1_router
from .core.exceptions import FLMBaseException, flm_exception_handler
from .services.rag_engine import rag_engine

# Configure logging
logging.basicConfig(
    level=logging.INFO if not settings.DEBUG else logging.DEBUG,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("FLM-API")


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: Load knowledge vault and initialize RAG index
    logger.info("Initializing FLM RAG Engine and Knowledge Vault...")
    rag_engine.initialize()
    logger.info(f"System ready! Active LLM provider: {rag_engine.llm_service.get_active_provider()}")
    yield
    # Shutdown
    logger.info("Shutting down FLM RAG API service...")
    await rag_engine.llm_service.close()


app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description=settings.APP_DESCRIPTION,
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json",
    lifespan=lifespan,
)

# CORS Middleware (Allows Flutter Mobile, Web, Desktop and tools)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register Custom Exception Handlers
app.add_exception_handler(FLMBaseException, flm_exception_handler)

# Include API Routers
app.include_router(api_v1_router, prefix="/api/v1")


@app.get("/", include_in_schema=False)
async def root():
    """Redirect root endpoint to Swagger UI documentation."""
    return RedirectResponse(url="/docs")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "app.main:app",
        host=settings.HOST,
        port=settings.PORT,
        reload=settings.DEBUG,
    )
