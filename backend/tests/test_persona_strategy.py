from backend.app.services.llm_service import LLMService
from backend.tests.test_strategy_rag import _courses
import asyncio


def test_same_subject_has_distinct_strategy_for_saved_goal():
    service = LLMService()
    kwargs = dict(
        question="Tư vấn cách học môn ALPHA101",
        retrieved_chunks=[],
        detected_courses=["ALPHA101"],
        scope="subject",
        scope_id="ALPHA101",
        all_courses=_courses(),
        curriculum_info={},
    )
    passing = service._synthesize_advanced_response(
        **kwargs, student_context={"course_goal": "pass", "learning_style": "reading"}
    )
    high = service._synthesize_advanced_response(
        **kwargs, student_context={"course_goal": "high_score", "learning_style": "practice"}
    )
    assert "Cách học để qua môn ALPHA101" in passing
    assert "chưa có ngưỡng đạt" in passing.lower()
    assert "đọc từng CLO" in passing
    assert "Cách học để đạt điểm cao môn ALPHA101" in high
    assert "luyện đủ các CLO" in high
    assert "làm bài hoặc sản phẩm" in high
    assert "3 tín chỉ" in passing and "3 tín chỉ" in high
    assert "dữ liệu đề cương FLM" in passing and "dữ liệu đề cương FLM" in high


def test_model_prompt_has_distinct_grounded_instructions_for_saved_goal():
    service = LLMService()
    passing = service._format_student_facts({"course_goal": "pass"})
    high = service._format_student_facts({"course_goal": "high_score"})
    assert "xác minh điều kiện đạt" in passing
    assert "không tự đặt ngưỡng đạt" in passing
    assert "luyện đầy đủ CLO" in high
    assert "không tự đặt điểm mục tiêu" in high
    assert passing != high


def test_long_term_goal_and_priority_change_strategy_without_invented_eligibility():
    service = LLMService()
    kwargs = dict(
        question="Tư vấn cách học môn ALPHA101",
        retrieved_chunks=[],
        detected_courses=["ALPHA101"],
        scope="subject",
        scope_id="ALPHA101",
        all_courses=_courses(),
        curriculum_info={},
    )
    abroad = service._synthesize_advanced_response(**kwargs, student_context={
        "course_goal": "high_score", "study_priority": "depth",
        "long_term_goal": "study_abroad",
    })
    career = service._synthesize_advanced_response(**kwargs, student_context={
        "course_goal": "high_score", "study_priority": "time",
        "long_term_goal": "career",
    })
    assert "cần tiêu chí của trường/chương trình đích" in abroad
    assert "chọn một topic thật" in abroad
    assert "Ưu tiên thời gian" in career
    assert "chuẩn tuyển dụng" in career


def test_live_generation_path_uses_grounded_subject_advisor():
    answer, provider = asyncio.run(LLMService().generate_response(
        question="Tư vấn cách học môn ALPHA101 theo mục tiêu của tôi",
        retrieved_chunks=[], detected_courses=["ALPHA101"],
        scope="subject", scope_id="ALPHA101", all_courses=_courses(),
        student_context={"course_goal": "pass", "completed_courses": []},
    ))
    assert provider == "FLM-Structured-Advisor"
    assert "Cách học để qua môn ALPHA101" in answer
    assert "Bài tập 40%" in answer
    assert "10-15 giờ" not in answer
    assert "http" not in answer
