import asyncio
import json
from io import BytesIO

from fastapi import UploadFile
from starlette.datastructures import Headers

from backend.app.api.v1.endpoints import vision_chat
from backend.app.schemas.course import CourseDetail
from backend.app.services.flm_parser import FLMDocumentChunk
from backend.app.services.rag_engine import rag_engine


def _chunk(code):
    return FLMDocumentChunk(
        chunk_id=code,
        course_code=code,
        course_name=code,
        category="overview",
        title=f"Thông tin {code}",
        content=f"Tài liệu của {code}",
        file_name=f"{code}.md",
    )


class _ScopedStore:
    def __init__(self):
        self.kwargs = None

    def search(self, **kwargs):
        self.kwargs = kwargs
        code = next(iter(kwargs["allowed_course_codes"]), None) if kwargs.get("allowed_course_codes") is not None else kwargs.get("target_course")
        return [(_chunk(code), 0.9)] if code else []


def _upload():
    return UploadFile(
        filename="question.png",
        file=BytesIO(b"image"),
        headers=Headers({"content-type": "image/png"}),
    )


def test_image_question_keeps_semester_scope_and_student_facts(monkeypatch):
    store = _ScopedStore()
    courses = {
        "C1": CourseDetail(code="C1", name_vi="Môn một", semester=1),
        "C2": CourseDetail(code="C2", name_vi="Môn hai", semester=2),
    }
    monkeypatch.setattr(rag_engine, "vector_store", store)
    monkeypatch.setattr(rag_engine, "courses", courses)
    monkeypatch.setattr(vision_chat, "extract_text", lambda _raw: "Văn bản trên ảnh")
    prompts = []

    async def call_direct(prompt):
        prompts.append(prompt)
        return "Câu trả lời"

    monkeypatch.setattr(rag_engine.llm_service, "call_direct", call_direct)

    response = asyncio.run(vision_chat.chat_with_images(
        question="Ngữ cảnh đang xem: Học kỳ 1 trong chương trình TEST. Câu hỏi: tôi nên chuẩn bị gì?",
        images=[_upload()],
        scope="curriculum",
        id="TEST",
        course_code="",
        student_context=json.dumps({"target_semester": 1, "current_gpa": 8.2}),
    ))

    assert store.kwargs["allowed_course_codes"] == {"C1"}
    assert store.kwargs["target_course"] is None
    assert "GPA hiện tại" in prompts[0]
    assert response.sources == ["C1.md (Thông tin C1)"]


def test_image_question_from_subject_card_retrieves_only_that_subject(monkeypatch):
    store = _ScopedStore()
    monkeypatch.setattr(rag_engine, "vector_store", store)
    monkeypatch.setattr(rag_engine, "courses", {
        "C1": CourseDetail(code="C1", name_vi="Môn một", semester=1),
        "C2": CourseDetail(code="C2", name_vi="Môn hai", semester=2),
    })
    monkeypatch.setattr(vision_chat, "extract_text", lambda _raw: "Văn bản trên ảnh")

    async def call_direct(_prompt):
        return "Câu trả lời"

    monkeypatch.setattr(rag_engine.llm_service, "call_direct", call_direct)

    response = asyncio.run(vision_chat.chat_with_images(
        question="Ngữ cảnh đang xem: Môn C2. Câu hỏi: giải thích nội dung trong ảnh",
        images=[_upload()],
        scope="subject",
        id="C2",
        course_code="C2",
        student_context=None,
    ))

    assert store.kwargs["target_course"] == "C2"
    assert store.kwargs["allowed_course_codes"] is None
    assert response.sources == ["C2.md (Thông tin C2)"]
