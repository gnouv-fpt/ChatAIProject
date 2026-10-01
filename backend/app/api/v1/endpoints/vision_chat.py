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
    description="Nhận prompt tự viết và ảnh trong bộ nhớ tạm; kết hợp OCR và RAG FLM.",
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

    # Retrieve FLM RAG knowledge context
    flm_context_sections = []

    # 1. Check if the question asks about a specific semester (e.g., HK3)
    target_sem = rag_engine.llm_service._target_semester(question, None)
    if target_sem:
        sem_courses = [
            c for c in rag_engine.courses.values()
            if getattr(c, "semester", 0) == target_sem and getattr(c, "in_curriculum", True)
        ]
        if sem_courses:
            courses_info = []
            for c in sem_courses:
                code = getattr(c, "code", "")
                name = getattr(c, "name_vi", "") or getattr(c, "name_en", "") or code
                credits = getattr(c, "credits", 3)
                prereqs = ", ".join(getattr(c, "prerequisites", [])) or "Không có"
                has_pe = "Có thi thực hành PE" if getattr(c, "has_pe", False) else "Không thi PE"
                courses_info.append(f"- Môn {code} ({name}): {credits} tín chỉ | Tiên quyết: {prereqs} | Đánh giá: {has_pe}")
            flm_context_sections.append(
                f"=== DANH SÁCH CÁC MÔN HỌC FLM TRONG HỌC KỲ {target_sem} (CẦN LẬP KẾ HOẠCH HỌC TẬP) ===\n"
                + "\n".join(courses_info)
            )

    # 2. Search relevant curriculum / syllabus chunks from Vector Store
    try:
        retrieved = rag_engine.vector_store.search(
            query=question,
            top_k=6,
            similarity_threshold=0.3,
        )
        if retrieved:
            chunk_texts = [
                f"--- [TÀI LIỆU FLM: {chunk.course_code}] {chunk.title} ---\n{chunk.content}"
                for chunk, _ in retrieved
            ]
            flm_context_sections.append("=== DỮ LIỆU ĐỀ CƯƠNG / SYLLABUS FLM TRÍCH XUẤT ===\n" + "\n\n".join(chunk_texts))
    except Exception as e:
        logger.warning("Vector store search in vision chat failed: %s", e)

    flm_context_str = "\n\n".join(flm_context_sections)

    # Fast path: Screenshots/documents with OCR text
    if ocr_blocks:
        try:
            ocr_content = "\n\n".join(ocr_blocks)
            prompt = (
                f"{rag_engine.llm_service._build_system_prompt()}\n\n"
                f"=== DỮ LIỆU ĐIỂM TỪ ẢNH (OCR BẢNG ĐIỂM CÁC KỲ ĐÃ HỌC) ===\n"
                f"{ocr_content}\n\n"
            )
            if flm_context_str:
                prompt += f"{flm_context_str}\n\n"

            prompt += (
                f"=== CÂU HỎI CỦA SINH VIÊN ===\n{question.strip()}\n\n"
                "=== NGUYÊN TẮC TƯ VẤN (BẮT BUỘC TUÂN THỦ): ===\n"
                "1. TUYỆT ĐỐI KHÔNG dùng ký hiệu giữ chỗ như [X], [Y], [Z], [A], [Điểm]... Chỉ dùng điểm số thật đọc được từ OCR, nếu không thấy điểm chính xác thì gọi tên môn học.\n"
                "2. TUYỆT ĐỐI KHÔNG lặp lại cùng một checklist 7 bước (như 'Học nhóm', 'Dùng VS Code', 'Phân bổ thời gian'...) cho mọi môn học.\n"
                "3. Phân biệt rõ ràng:\n"
                "   - Môn trong OCR: Là các môn ĐÃ HỌC ở các kỳ trước.\n"
                "   - Môn trong FLM: Là các môn SẮP HỌC ở kỳ được hỏi (ví dụ Học kỳ 3).\n"
                "4. Đi thẳng vào trọng tâm: Với mỗi môn sắp học trong kỳ mới, chỉ nêu 1-2 lời khuyên kỹ thuật trọng tâm: kiến thức cốt lõi cần chuẩn bị, độ khó, lưu ý thi PE thực hành và liên hệ từ môn nền tảng kỳ trước.\n\n"
                "=== CÂU TRẢ LỜI CỦA CỐ VẤN HỌC TẬP AI (BẰNG TIẾNG VIỆT) ==="
            )
            answer = await rag_engine.llm_service.call_direct(prompt)
            if answer:
                answers.append(answer.strip())
        except Exception as exc:
            logger.exception("OCR text chat failed")
            raise HTTPException(status_code=503, detail=str(exc)) from exc

    # Multimodal Vision path for images without clear OCR text
    for index, filename, raw, content_type in vision_images:
        try:
            vision_prompt = (
                f"{rag_engine.llm_service._build_system_prompt()}\n\n"
            )
            if flm_context_str:
                vision_prompt += f"{flm_context_str}\n\n"
            vision_prompt += (
                f"=== CÂU HỎI CỦA SINH VIÊN ===\n{question.strip()}\n\n"
                "Đọc thông tin từ ảnh đính kèm, kết hợp với dữ liệu môn học FLM ở trên để trả lời chi tiết và tư vấn cụ thể bằng Tiếng Việt. Tuyệt đối không dùng ký hiệu giữ chỗ [X], [Y]..."
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
        sources=["Ảnh bảng điểm (OCR)", "Dữ liệu chương trình đào tạo FLM FPTU"],
        question=question,
        matched_courses=[course_code] if course_code else [],
        provider=rag_engine.llm_service.get_active_provider(),
        latency_ms=0.0,
        detailed_sources=[],
    )
