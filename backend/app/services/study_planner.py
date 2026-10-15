"""Deterministic study-planning facts for the FLM assistant.

The LLM is responsible for explaining a plan naturally. It must not invent
prerequisites, semesters, or GPA calculations; those facts are computed here
from the curriculum and the student's uploaded transcript context.
"""

from typing import Any, Dict, Iterable, List, Optional, Set


_GOAL_KEYWORDS = {
    "roadmap": ("lộ trình", "roadmap", "học từ đầu", "từ đầu", "bắt đầu học", "muốn học", "nên học"),
    "exam_strategy": ("ôn thi", "thi pe", "thi fe", "đi thi", "qua môn", "pass môn"),
    "skill_plan": ("kỹ năng", "skill", "làm app", "học mobile", "học flutter", "học lập trình"),
    "gpa_strategy": ("gpa", "điểm", "xếp loại", "tốt nghiệp"),
}


def detect_study_goal(question: str) -> Optional[str]:
    lowered = (question or "").lower()
    for goal, keywords in _GOAL_KEYWORDS.items():
        if any(keyword in lowered for keyword in keywords):
            return goal
    return None


def next_semester_answer(
    question: str,
    courses: Dict[str, Any],
    student_context: Optional[Dict[str, Any]],
    language: str = "vi",
) -> Optional[str]:
    """Answer next-term eligibility from confirmed progress and FLM prerequisites."""
    lowered = (question or "").casefold()
    if not any(term in lowered for term in ("kỳ tới", "kì tới", "kỳ sau", "next semester")):
        return None
    if not any(term in lowered for term in ("môn nào", "học gì", "có thể học", "nên học", "which", "what", "eligible", "take")):
        return None
    context = student_context or {}
    current = context.get("current_semester")
    if not isinstance(current, int) or current < 0:
        return (
            "Chưa xác định học kỳ hiện tại từ bảng điểm đã xác nhận. Hãy nhập hoặc cập nhật kết quả học tập trước khi xem môn kỳ tới."
            if language != "en" else
            "Your current semester is not known from a confirmed transcript. Add or update your results before checking next-semester courses."
        )
    target = current + 1
    by_code = {str(code).upper(): course for code, course in courses.items()}
    completed = {str(code).upper() for code in context.get("completed_courses", [])}
    in_progress = {str(code).upper() for code in context.get("in_progress_courses", [])}
    upcoming = sorted(
        (course for course in courses.values() if getattr(course, "semester", None) == target),
        key=lambda course: _course_code(course),
    )
    if not upcoming:
        return (
            f"Không có môn được ghi cho HK{target} trong khung chương trình hiện tại."
            if language != "en" else
            f"No courses are listed for semester {target} in the current curriculum."
        )
    ready, blocked, unverified = [], [], []
    for course in upcoming:
        code = _course_code(course)
        if code in completed or code in in_progress:
            continue
        prerequisites = [str(item).upper() for item in getattr(course, "prerequisites", [])]
        unknown = [item for item in prerequisites if item not in by_code]
        missing = [item for item in prerequisites if item in by_code and item not in completed]
        if unknown:
            unverified.append(f"{code} ({', '.join(unknown)})")
        elif missing:
            blocked.append(f"{code} ({', '.join(missing)})")
        else:
            ready.append(code)
    if language == "en":
        return "\n".join([
            f"**Semester {target}** based on the confirmed transcript and FLM prerequisites:",
            f"- Prerequisites met: {', '.join(ready) or 'none'}.",
            f"- Still missing prerequisites: {', '.join(blocked) or 'none'}.",
            f"- Prerequisite codes requiring verification: {', '.join(unverified) or 'none'}.",
            "This checks curriculum prerequisites only; course availability and registration rules still need confirmation.",
        ])
    return "\n".join([
        f"**HK{target}** theo bảng điểm đã xác nhận và tiên quyết trong dữ liệu FLM:",
        f"- Đủ tiên quyết: {', '.join(ready) or 'không có'}.",
        f"- Còn thiếu tiên quyết: {', '.join(blocked) or 'không có'}.",
        f"- Cần xác minh mã tiên quyết: {', '.join(unverified) or 'không có'}.",
        "Kết quả chỉ xét tiên quyết trong khung chương trình; lịch mở lớp và quy định đăng ký cần kiểm tra thêm.",
    ])


def _course_code(course: Any) -> str:
    return str(getattr(course, "code", "")).upper()


def _prerequisite_order(target: str, courses: Dict[str, Any]) -> List[str]:
    """Return prerequisites before target, using a cycle-safe DFS."""
    by_code = {str(code).upper(): course for code, course in courses.items()}
    ordered: List[str] = []
    visiting: Set[str] = set()
    visited: Set[str] = set()

    def visit(code: str) -> None:
        code = code.upper()
        if code in visited or code in visiting:
            return
        visiting.add(code)
        course = by_code.get(code)
        for prerequisite in getattr(course, "prerequisites", []) if course else []:
            visit(str(prerequisite))
        visiting.remove(code)
        visited.add(code)
        if code != target.upper() and course:
            ordered.append(code)

    visit(target)
    return ordered


def build_study_plan_facts(
    question: str,
    courses: Dict[str, Any],
    detected_courses: Iterable[str] = (),
    student_context: Optional[Dict[str, Any]] = None,
    language: str = "vi",
) -> str:
    """Build authoritative planning facts, or return an empty string."""
    goal = detect_study_goal(question)
    if not goal:
        return ""

    english = language == "en"
    target = next(iter(detected_courses), None)
    completed = {
        str(code).upper()
        for code in (student_context or {}).get("completed_courses", [])
    }

    if target:
        target = str(target).upper()
        target_course = courses.get(target)
        if target_course:
            prerequisites = [str(code).upper() for code in getattr(target_course, "prerequisites", [])]
            chain = _prerequisite_order(target, courses)
            missing = [code for code in chain if code not in completed]
            lines = [
                f"- Mục tiêu được nhận diện: {goal}." if not english else f"- Detected goal: {goal}.",
                f"- Môn mục tiêu: {target} ({getattr(target_course, 'name_vi', '') or getattr(target_course, 'name_en', '')})."
                if not english else f"- Target course: {target} ({getattr(target_course, 'name_en', '') or getattr(target_course, 'name_vi', '')}).",
                f"- Tiên quyết trực tiếp: {', '.join(prerequisites) if prerequisites else 'không có'}."
                if not english else f"- Direct prerequisites: {', '.join(prerequisites) if prerequisites else 'none'}.",
                f"- Chuỗi prerequisite theo dữ liệu chương trình: {' → '.join(chain + [target])}."
                if not english else f"- Curriculum prerequisite chain: {' -> '.join(chain + [target])}.",
                f"- Các môn trong chuỗi chưa có trong bảng điểm: {', '.join(missing) if missing else 'không có'}."
                if not english else f"- Courses in the chain missing from the transcript: {', '.join(missing) if missing else 'none'}.",
            ]
        else:
            lines = []
    else:
        lines = [
            f"- Mục tiêu được nhận diện: {goal}." if not english else f"- Detected goal: {goal}.",
            "- Chưa xác định được một môn mục tiêu cụ thể; không được tự bịa một chuỗi môn học."
            if not english else "- No specific target course was identified; do not invent a course sequence.",
        ]

    if not lines:
        return ""

    header = (
        "=== STUDY PLANNER FACTS (COMPUTED BY CODE, AUTHORITATIVE) ==="
        if english
        else "=== DỮ KIỆN LỘ TRÌNH (TÍNH BẰNG CODE, CHÍNH XÁC) ==="
    )
    return header + "\n" + "\n".join(lines) + "\n\n"
