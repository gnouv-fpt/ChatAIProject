from .chat import router as chat_router
from .health import router as health_router
from .courses import router as courses_router

__all__ = ["chat_router", "health_router", "courses_router"]
