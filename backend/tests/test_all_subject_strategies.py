from pathlib import Path

from backend.app.services.flm_parser import FLMKnowledgeVaultParser
from backend.app.services.llm_service import LLMService
from backend.app.services.vector_store import SemanticVectorStore


def test_every_subject_strategy_is_domain_safe():
    vault = Path(__file__).parents[2] / "flm_knowledge_vault"
    courses, _ = FLMKnowledgeVaultParser(vault).load_all()

    assert len(courses) >= 50
    for code, course in courses.items():
        answer = LLMService._build_subject_strategy(
            code,
            course.name_vi or course.name_en or code,
            course,
            [],
            {"subject_history": []},
        )
        lowered = answer.lower()

        assert "[[_" not in answer, code
        assert "tóm tắt khái niệm bằng ví dụ c#" not in lowered, code
        assert "** **" not in answer, code

        is_math = any(
            token in f"{code} {course.name_vi} {course.name_en}".lower()
            for token in ["toán", "mathematics", "calculus", "đại số"]
        )
        if is_math:
            assert "wpf" not in lowered, code
            assert "entity framework" not in lowered, code
            assert "mini-project c#" not in lowered, code


def test_course_overview_does_not_leak_obsidian_links_or_raw_guidance():
    vault = Path(__file__).parents[2] / "flm_knowledge_vault"
    courses, chunks = FLMKnowledgeVaultParser(vault).load_all()
    course = courses["PRF192"]
    source = next(chunk for chunk in chunks if chunk.course_code == "PRF192" and chunk.category == "prerequisites")

    answer = LLMService._build_course_overview(
        "PRF192",
        course.name_vi,
        course,
        source,
    )

    assert "[[" not in answer
    assert "Không (Môn cơ sở" not in answer
    assert "PRO192" in answer


def test_mixed_case_course_code_cannot_retrieve_another_subject():
    vault = Path(__file__).parents[2] / "flm_knowledge_vault"
    courses, chunks = FLMKnowledgeVaultParser(vault).load_all()
    store = SemanticVectorStore()
    store.index_chunks(chunks)
    retrieved = store.search("kế hoạch học WED201C", target_course="WED201C", top_k=10)

    assert retrieved
    assert all(chunk.course_code.upper() == "WED201C" for chunk, _ in retrieved)

    answer = LLMService()._synthesize_advanced_response(
        "kế hoạch học WED201C",
        retrieved,
        ["WED201C"],
        scope="subject",
        scope_id="WED201C",
        all_courses=courses,
        curriculum_info={},
    )
    assert "HTML5" in answer
    assert "CSS3" in answer
    assert "Vovinam" not in answer


def test_scoped_retrieval_fails_closed_instead_of_using_unrelated_chunks():
    vault = Path(__file__).parents[2] / "flm_knowledge_vault"
    _, chunks = FLMKnowledgeVaultParser(vault).load_all()
    store = SemanticVectorStore()
    store.index_chunks(chunks)
    assert store.search("kế hoạch học ZZZ999", target_course="ZZZ999") == []
