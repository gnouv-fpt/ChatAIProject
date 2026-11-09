from fastapi import Request, status
from fastapi.responses import JSONResponse


class FLMBaseException(Exception):
    """Base exception for FLM RAG application."""
    def __init__(self, message: str, status_code: int = status.HTTP_500_INTERNAL_SERVER_ERROR):
        self.message = message
        self.status_code = status_code
        super().__init__(message)


class CourseNotFoundException(FLMBaseException):
    def __init__(self, course_code: str):
        super().__init__(
            message=f"Không tìm thấy thông tin môn học '{course_code}' trong hệ thống FLM.",
            status_code=status.HTTP_404_NOT_FOUND,
        )


class RAGProcessingException(FLMBaseException):
    def __init__(self, detail: str):
        super().__init__(
            message=f"Lỗi trong quá trình xử lý RAG: {detail}",
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )


async def flm_exception_handler(request: Request, exc: FLMBaseException):
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "error": True,
            "message": exc.message,
            "status_code": exc.status_code,
        },
    )
