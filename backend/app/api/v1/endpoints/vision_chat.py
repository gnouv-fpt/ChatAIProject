"""Chat with temporary images. Images are processed in memory and not stored."""
import base64
import logging
from typing import List, Optional

from fastapi import APIRouter, File, Form, HTTPException, UploadFile, status

from ....schemas.chat import ChatResponse
from ....services.local_ocr import extract_text
from ....services.rag_engine import rag_engine

logger = logging.getLogger(__name__)
router = APIRouter()


@router.post(
    "/chat/images",
    response_model=ChatResponse,
    status_code=status.HTTP_200_OK,
    summary="Chat với ảnh tạm thời",
    description="Nhận prompt tự viết và ảnh trong bộ nhớ tạm; không lưu ảnh trên server.",
)
async def chat_with_images(
    question: str = Form(...),
    images: List[UploadFile] = File(...),
    scope: Optional[str] = Form(None),
    id: Optional[str] = Form(None),
    course_code: Optional[str] = Form(None),
) -> ChatResponse:
    if not question.strip():
        raise HTTPException(status_code=400, detail="Prompt không được để trống.")
    if not images:
        raise HTTPException(status_code=400, detail="Cần ít nhất một ảnh.")
    if len(images) > 10:
        raise HTTPException(status_code=400, detail="Tối đa 10 ảnh mỗi lần gửi.")

    answers = []
    ocr_blocks = []
    vision_images = []
    for index, image in enumerate(images, start=1):
        try:
            raw = await image.read()
            if not raw:
                continue
            ocr_text = extract_text(raw)
            if ocr_text.strip():
                ocr_blocks.append(f"[Ảnh {index} - {image.filename}]\n{ocr_text}")
            else:
                vision_images.append((index, image.filename, raw, image.content_type or "image/jpeg"))
        except Exception as exc:
            logger.exception("Image preprocessing failed for %s", image.filename)
            raise HTTPException(status_code=503, detail=str(exc)) from exc

    # Screenshots/documents use the faster OCR -> text-model path.
    if ocr_blocks:
        try:
            ocr_content = "\n\n".join(ocr_blocks)
            answer = await rag_engine.llm_service.call_text_extraction(
                "Trả lời prompt bằng tiếng Việt dựa CHỈ trên OCR dưới đây. "
                "Không bịa dữ liệu; nếu thiếu thông tin thì nói rõ.\n\n"
                f"PROMPT NGƯỜI DÙNG:\n{question.strip()}\n\n"
                f"NỘI DUNG OCR:\n{ocr_content}"
            )
            if answer:
                answers.append(answer.strip())
        except Exception as exc:
            logger.exception("OCR text chat failed")
            raise HTTPException(status_code=503, detail=str(exc)) from exc

    # Only images with no readable text use the slower multimodal model.
    for index, filename, raw, content_type in vision_images:
        try:
            vision_prompt = (
                "Trả lời trực tiếp prompt của người dùng dựa trên ảnh đính kèm. "
                "Không bịa dữ liệu không nhìn thấy. Nếu ảnh không đủ rõ, nói rõ phần nào không đọc được.\n\n"
                f"Prompt người dùng: {question.strip()}"
            )
            answer = await rag_engine.llm_service.call_vision(
                system_prompt=vision_prompt,
                image_b64=base64.b64encode(raw).decode("utf-8"),
                mime_type=content_type,
            )
            if answer:
                answers.append(f"Ảnh {index}:\n{answer.strip()}")
        except Exception as exc:
            logger.exception("Vision chat failed for image %s", filename)
            detail = str(exc) or f"{type(exc).__name__}: Vision model không phản hồi."
            raise HTTPException(status_code=503, detail=detail) from exc

    if not answers:
        raise HTTPException(status_code=422, detail="Không nhận được nội dung từ ảnh.")

    return ChatResponse(
        answer="\n\n".join(answers),
        sources=["Ảnh người dùng gửi (xử lý tạm thời)"],
        question=question,
        matched_courses=[course_code] if course_code else [],
        provider="Ollama-OCR+Text" if ocr_blocks else "Vision-LLM",
        latency_ms=0.0,
        detailed_sources=[],
    )
