from fastapi import APIRouter
from .endpoints.chat import router as chat_router
from .endpoints.health import router as health_router
from .endpoints.courses import router as courses_router

api_v1_router = APIRouter()

api_v1_router.include_router(health_router, tags=["Health & Diagnostics"])
api_v1_router.include_router(chat_router, tags=["Chat & RAG Assistant"])
api_v1_router.include_router(courses_router, tags=["Courses & Knowledge Base"])
