from backend.app.schemas.course import CourseDetail
from backend.app.services.llm_service import LLMService


def _courses():
    return {
        "ALPHA101": CourseDetail(
            code="ALPHA101",
            name_vi="Lập trình cơ sở",
            credits=3,
            semester=5,
            has_pe=True,
            assessment_scheme="Bài tập 40%\nPractical Exam 60%",
            learning_outcomes="Viết chương trình theo yêu cầu\nDebug và kiểm thử",
            time_allocation="Lý thuyết 40%, thực hành 60%",
            software_tools="IDE và Git",
        ),
        "BETA201": CourseDetail(
            code="BETA201",
            name_vi="Đồ án phần mềm",
            credits=3,
            semester=5,
            prerequisites=["ALPHA101"],
        ),
        "GAMMA301": CourseDetail(
            code="GAMMA301",
            name_vi="Kỹ năng học thuật",
            credits=2,
            semester=6,
        ),
    }


def test_semester_strategy_uses_structured_courses_and_explains_priorities():
    answer = LLMService()._synthesize_advanced_response(
        "HK5 nên học như nào?",
        [],
        ["HK5"],
        scope="curriculum",
        scope_id="BIT_SE_K19B",
        all_courses=_courses(),
        curriculum_info={},
    )

    assert "Học kỳ 5" in answer
    assert "ALPHA101" in answer
    assert "BETA201" in answer
    assert "ưu tiên" in answer.lower()
    assert "random" not in answer.lower()


def test_current_semester_without_context_does_not_guess():
    answer = LLMService._build_semester_strategy("Kỳ này học như nào?", _courses(), None)

    assert "cần xác định học kỳ" in answer.lower()
    assert "HK5" in answer
    assert "HK6" in answer


def test_current_semester_uses_context_when_available():
    answer = LLMService._build_semester_strategy(
        "Kỳ này học như nào?",
        _courses(),
        {"target_semester": 6},
    )

    assert "Học kỳ 6" in answer
    assert "GAMMA301" in answer
    assert "ALPHA101" not in answer


def test_subject_learning_question_returns_actions_not_only_metadata():
    answer = LLMService()._synthesize_advanced_response(
        "Cách học ALPHA101 để đạt điểm cao?",
        [],
        ["ALPHA101"],
        scope="subject",
        scope_id="ALPHA101",
        all_courses=_courses(),
        curriculum_info={},
        student_context={"subject_history": []},
    )

    assert "Cách học theo thứ tự ưu tiên" in answer
    assert "Lịch thực hiện gợi ý" in answer
    assert "bấm giờ" in answer
    assert "IDE và Git" in answer


def test_subject_learning_question_is_not_routed_to_gpa_strategy():
    answer = LLMService()._synthesize_advanced_response(
        "Tư vấn cách học ALPHA101",
        [],
        ["ALPHA101"],
        scope="subject",
        scope_id="ALPHA101",
        all_courses=_courses(),
        curriculum_info={},
        student_context={"current_gpa": 7.4, "target_gpa": 8.0},
    )

    assert "Kế hoạch học môn ALPHA101" in answer
    assert "Kế hoạch chiến lược học tập nâng điểm GPA" not in answer


def test_subject_high_score_advice_stays_focused_and_does_not_invent_hours():
    answer = LLMService()._build_subject_strategy(
        "Cách học ALPHA101 để đạt điểm cao?",
        "Lập trình cơ sở",
        _courses()["ALPHA101"],
        [],
        {},
        goal_focused=True,
    )

    assert "Cách học để đạt điểm cao" in answer
    assert "Bài tập 40%" in answer
    assert "Lịch thực hiện gợi ý" not in answer
    assert "3-4 giờ" not in answer


def test_subject_mark_goal_uses_assessment_weights():
    answer = LLMService()._synthesize_advanced_response(
        "Tao muốn môn này được 9",
        [],
        ["ALPHA101"],
        scope="subject",
        scope_id="ALPHA101",
        all_courses=_courses(),
        curriculum_info={},
    )

    assert "đạt 9/10 môn ALPHA101" in answer
    assert "60%" in answer
    assert "trọng số" in answer.lower()


def test_subject_mark_goal_reports_missing_rubric_instead_of_inventing_plan():
    answer = LLMService()._synthesize_advanced_response(
        "Môn này tao muốn được 9",
        [],
        ["BETA201"],
        scope="subject",
        scope_id="BETA201",
        all_courses=_courses(),
        curriculum_info={},
    )

    assert "đạt 9/10 môn BETA201" in answer
    assert "chưa thể tính" in answer.lower()
    assert "rubric" in answer.lower()


def test_graduation_gpa_goal_accepts_integer_target():
    answer = LLMService()._synthesize_advanced_response(
        "Tao muốn ra trường GPA 9",
        [],
        [],
        scope="curriculum",
        scope_id="BIT_SE_K19B",
        all_courses=_courses(),
        curriculum_info={},
    )

    assert "GPA **9**" in answer
