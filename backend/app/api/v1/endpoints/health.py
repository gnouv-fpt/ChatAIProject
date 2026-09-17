from fastapi import APIRouter, status
from ....config import settings
from ....schemas.health import HealthResponse
from ....services.rag_engine import rag_engine

router = APIRouter()


@router.get(
    "/health",
    response_model=HealthResponse,
    status_code=status.HTTP_200_OK,
    summary="Server Health & Diagnostics",
    description="Returns backend server health status, indexed courses count, chunk statistics, and active LLM provider.",
)
async def health_check() -> HealthResponse:
    total_courses = len(rag_engine.courses)
    total_chunks = len(rag_engine.vector_store.chunks) if rag_engine.vector_store else 0
    active_provider = rag_engine.llm_service.get_active_provider()

    return HealthResponse(
        status="ok" if rag_engine.is_initialized else "initializing",
        app_name=settings.APP_NAME,
        version=settings.APP_VERSION,
        total_courses=total_courses,
        total_chunks=total_chunks,
        active_llm_provider=active_provider,
        vault_loaded=rag_engine.is_initialized,
    )
