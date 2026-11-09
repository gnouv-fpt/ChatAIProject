import asyncio

from backend.app.schemas.chat import ChatRequest
from backend.app.schemas.course import CourseDetail
from backend.app.services.curriculum_facts import detect_semester
from backend.app.services.flm_parser import FLMDocumentChunk
from backend.app.services.rag_engine import RAGEngine
from backend.app.services.vector_store import SemanticVectorStore


class _Embedder:
    def embed(self, texts):
        for _ in texts:
            yield [1.0, 0.0]


def _chunk(code):
    return FLMDocumentChunk(
        chunk_id=code,
        course_code=code,
        course_name=code,
        category="overview",
        title="Thông tin môn học",
        content=f"Nội dung của {code}",
        file_name=f"{code}.md",
    )


def test_selected_semester_filters_candidates_before_ranking():
    store = SemanticVectorStore(embedder=_Embedder())
    store.index_chunks([_chunk("HK1A"), _chunk("HK2A"), _chunk("CURRICULUM")])

    matches = store.search(
        "Tôi nên chuẩn bị gì?",
        top_k=3,
        similarity_threshold=0,
        allowed_course_codes={"HK1A", "CURRICULUM"},
    )

    assert {chunk.course_code for chunk, _ in matches} == {"HK1A", "CURRICULUM"}
    assert detect_semester("Tôi nên chuẩn bị gì?", {"target_semester": 1}) == 1
    assert detect_semester("Học kỳ 2 có gì?", {"target_semester": 1}) == 2


def test_rag_uses_selected_semester_as_retrieval_scope():
    engine = RAGEngine()
    store = SemanticVectorStore(embedder=_Embedder())
    store.index_chunks([_chunk("HK1A"), _chunk("HK2A"), _chunk("CURRICULUM")])
    engine.vector_store = store
    engine.courses = {
        "HK1A": CourseDetail(code="HK1A", name_vi="Môn kỳ 1", semester=1),
        "HK2A": CourseDetail(code="HK2A", name_vi="Môn kỳ 2", semester=2),
    }

    class _Llm:
        async def generate_response(self, **kwargs):
            assert {chunk.course_code for chunk, _ in kwargs["retrieved_chunks"]} == {"HK1A"}
            return "Trả lời từ tài liệu kỳ 1", "test"

    engine.llm_service = _Llm()
    response = asyncio.run(engine.answer_query(ChatRequest(
        question="Tôi nên chuẩn bị gì?",
        scope="curriculum",
        id="BIT_SE_K19B",
        student_context={"target_semester": 1},
    )))

    assert "HK2A.md" not in response.sources
    assert "HK1A.md" in " ".join(response.sources)

    outside = asyncio.run(engine.answer_query(ChatRequest(
        question="Môn HK2A có khó không?",
        scope="curriculum",
        id="BIT_SE_K19B",
        student_context={"target_semester": 1},
    )))
    assert "thuộc Học kỳ 2" in outside.answer
    assert "HK1A.md" not in outside.sources


def test_subject_stays_on_its_course_when_semester_is_present():
    engine = RAGEngine()
    store = SemanticVectorStore(embedder=_Embedder())
    store.index_chunks([_chunk("HK1A"), _chunk("HK2A")])
    engine.vector_store = store
    engine.courses = {
        "HK1A": CourseDetail(code="HK1A", name_vi="Môn kỳ 1", semester=1),
        "HK2A": CourseDetail(code="HK2A", name_vi="Môn kỳ 2", semester=2),
    }

    class _Llm:
        async def generate_response(self, **kwargs):
            assert {chunk.course_code for chunk, _ in kwargs["retrieved_chunks"]} == {"HK1A"}
            return "Trả lời về HK1A", "test"

    engine.llm_service = _Llm()
    response = asyncio.run(engine.answer_query(ChatRequest(
        question="Tôi nên chuẩn bị gì?",
        scope="subject",
        id="HK1A",
        student_context={"target_semester": 1},
    )))

    assert "HK1A.md" in " ".join(response.sources)
    assert "HK2A.md" not in " ".join(response.sources)
