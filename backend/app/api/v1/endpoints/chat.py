import logging
from fastapi import APIRouter, HTTPException, status
from ....schemas.chat import ChatRequest, ChatResponse
from ....services.rag_engine import rag_engine

logger = logging.getLogger(__name__)
router = APIRouter()


@router.post(
    "/chat",
    response_model=ChatResponse,
    status_code=status.HTTP_200_OK,
    summary="Query FLM Curriculum & Syllabus Chatbot",
    description="Sends a student question to the RAG AI Assistant. Retrieves factual context from FLM markdown documents and generates precise answers with citations.",
    response_description="Grounded AI response with source document citations",
)
async def chat_endpoint(request: ChatRequest) -> ChatResponse:
    if not request.query_text:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Trường 'question' hoặc 'prompt' không được để trống.",
        )

    try:
        response = await rag_engine.answer_query(request)
        return response
    except Exception as e:
        logger.error(f"Error processing chat request: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Lỗi xử lý AI RAG: {str(e)}",
        )
