"""Facts computed by code from the curriculum data and grading rules.

The LLM writes the answer, but numbers such as the courses of a semester,
their total credits or the graduation rank thresholds are computed here and
given to it as ground truth, because small local models cannot be trusted
to add them up or to find them in long retrieved chunks.
"""
import re
import unicodedata
from functools import lru_cache
from typing import Any, Dict, Iterable, List, Optional

import yaml

from ..config import BASE_DIR
from .language import ENGLISH, Language

_SEMESTER_PATTERN = re.compile(r"(?:học\s*kỳ|học\s*kì|kỳ|kì|hk|semester|term)\s*(?:số\s*)?(\d{1,2})\b")
_ORDINAL_SEMESTER_PATTERN = re.compile(r"\b(\d{1,2})(?:st|nd|rd|th)\s+(?:semester|term)\b")
_GPA_NUMBER_PATTERN = re.compile(r"\b(\d{1,2}(?:[.,]\d{1,2})?)\b")

# "môn <tên>" / "course <name>" followed by the rest of the question.
_VI_SUBJECT_PATTERN = re.compile(
    r"\bmôn(?:\s+học)?\s+(.+?)(?=\s+(?:có|học|là|thi|bao|được|nên|cần|ở|thuộc|khó|dễ|gồm|dạy|kỳ|kì|thế|như|ra)\b|[?.,!]|$)"
)
_EN_SUBJECT_PATTERN = re.compile(
    r"\b(?:course|subject)\s+(?:called\s+|named\s+)?(.+?)(?=\s+(?:in|about|have|has|is|are|taught|difficult|hard|for)\b|[?.,!]|$)"
)
# First words that mean the phrase is not a subject name ("môn này", "môn tiên quyết").
_GENERIC_SUBJECT_WORDS = {
    "này", "nào", "gì", "các", "đó", "kia", "nay", "tiên", "chuyên", "chính", "phụ", "thi",
    "trước", "sau", "khác", "mình", "em", "tôi", "đã", "đang", "sắp", "học", "trong", "ở",
    "this", "that", "which", "what", "the", "a", "an", "my", "these", "those", "prerequisite",
    "about", "is", "are", "for", "in", "of", "content", "outline",
}

_GRADE_LABELS_EN = {"Excellent": "Excellent", "Good": "Very good", "Fair": "Good", "Pass": "Average"}


@lru_cache(maxsize=1)
def _load_grading_rules() -> Dict[str, Any]:
    path = BASE_DIR / "grading_rules.yaml"
    if not path.exists():
        return {}
    with path.open(encoding="utf-8") as file:
        return yaml.safe_load(file) or {}


def _strip_accents(text: str) -> str:
    normalized = unicodedata.normalize("NFD", text.replace("đ", "d").replace("Đ", "D"))
    return "".join(ch for ch in normalized if unicodedata.category(ch) != "Mn")


def detect_semester(question: str, student_context: Optional[Dict[str, Any]] = None) -> Optional[int]:
    """Return the semester the question is about, or None when it does not name one."""
    q_lower = (question or "").lower()
    matches = _SEMESTER_PATTERN.findall(q_lower) or _ORDINAL_SEMESTER_PATTERN.findall(q_lower)
    if matches:
        # "điểm kỳ 1, kỳ 2... chiến lược kỳ 3": the last mentioned is the target.
        return int(matches[-1])
    if any(p in q_lower for p in ["kỳ này", "học kỳ này", "kỳ tới", "kỳ sau", "this semester", "next semester"]):
        context = student_context or {}
        value = context.get("target_semester") or context.get("current_semester")
        try:
            return int(value) if value is not None else None
        except (TypeError, ValueError):
            return None
    return None


def asks_about_gpa(question: str, intents: Iterable[str]) -> bool:
    q_lower = (question or "").lower()
    return (
        bool({"gpa_rules", "grade_goal"} & set(intents or []))
        or "gpa" in q_lower
        or "xếp loại" in q_lower
        or "tốt nghiệp" in q_lower
        or "graduat" in q_lower
    )


def find_unknown_subject(question: str, courses: Dict[str, Any]) -> Optional[str]:
    """Return the subject name asked about when it matches no course of the curriculum."""
    q_lower = (question or "").lower().strip()
    match = _VI_SUBJECT_PATTERN.search(q_lower) or _EN_SUBJECT_PATTERN.search(q_lower)
    if not match:
        return None
    name = match.group(1).strip(" \"'“”")
    words = name.split()
    if not words or words[0] in _GENERIC_SUBJECT_WORDS or len(name) < 3:
        return None
    if re.fullmatch(r"[a-z]{2,5}\s*\d{2,4}[a-z]?", name):
        # Looks like a course code; code detection handles those.
        return None

    plain_name = _strip_accents(name)
    for course in courses.values():
        code = str(getattr(course, "code", "")).lower()
        names = [str(getattr(course, "name_vi", "") or ""), str(getattr(course, "name_en", "") or "")]
        if name == code:
            return None
        for course_name in names:
            plain_course = _strip_accents(course_name.lower())
            if plain_course and (plain_name in plain_course or plain_course in plain_name):
                return None
    return name


def unknown_subject_answer(name: str, curriculum_id: str, language: Language) -> str:
    if language == ENGLISH:
        return (
            f'Could not identify the course "{name}" in the {curriculum_id} curriculum, '
            "so there is no FLM data to answer this question. "
            "Please check the course name or code (for example: PRM393)."
        )
    return (
        f'Không xác định được môn học "{name}" trong chương trình đào tạo {curriculum_id}, '
        "nên mình không có dữ liệu FLM để trả lời câu hỏi này. "
        "Bạn kiểm tra lại tên hoặc mã môn giúp mình nhé (ví dụ: PRM393)."
    )


def semester_courses(courses: Dict[str, Any], semester: int) -> List[Any]:
    return sorted(
        (c for c in courses.values() if getattr(c, "semester", None) == semester and getattr(c, "in_curriculum", True)),
        key=lambda c: getattr(c, "code", ""),
    )


def _semester_facts(courses: Dict[str, Any], semester: int, curriculum_id: str, language: Language) -> List[str]:
    items = semester_courses(courses, semester)
    english = language == ENGLISH
    if not items:
        return [
            f"- Semester {semester} has no courses in {curriculum_id}."
            if english
            else f"- Học kỳ {semester} không có môn nào trong chương trình {curriculum_id}."
        ]

    total = sum(int(getattr(c, "credits", 0) or 0) for c in items)
    lines = [
        f"- Semester {semester} of {curriculum_id} has {len(items)} courses, {total} credits in total:"
        if english
        else f"- Học kỳ {semester} của chương trình {curriculum_id} có {len(items)} môn, tổng {total} tín chỉ:"
    ]
    for c in items:
        name = (getattr(c, "name_en", "") if english else getattr(c, "name_vi", "")) or getattr(c, "name_vi", "") or getattr(c, "name_en", "")
        prerequisites = ", ".join(getattr(c, "prerequisites", []) or []) or ("none" if english else "không có")
        if english:
            pe = "has a practical exam (PE)" if getattr(c, "has_pe", False) else "no PE"
            lines.append(f"  - {c.code} ({name}): {c.credits} credits, prerequisites: {prerequisites}, {pe}")
        else:
            pe = "có thi thực hành PE" if getattr(c, "has_pe", False) else "không thi PE"
            lines.append(f"  - {c.code} ({name}): {c.credits} tín chỉ, tiên quyết: {prerequisites}, {pe}")
    return lines


def _gpa_facts(question: str, language: Language) -> List[str]:
    rules = _load_grading_rules()
    if not rules:
        return []
    english = language == ENGLISH
    grades: Dict[str, float] = rules.get("graduation_grades", {})
    labels_vi: Dict[str, str] = rules.get("grade_labels_vi", {})
    retake: Dict[str, Any] = rules.get("retake", {})
    order = sorted(grades.items(), key=lambda item: item[1], reverse=True)

    def label(key: str) -> str:
        return _GRADE_LABELS_EN.get(key, key) if english else labels_vi.get(key, key)

    def rank_key(gpa: float) -> str:
        for key, threshold in order:
            if gpa >= threshold:
                return key
        return "Fail"

    def rank_of(gpa: float) -> str:
        key = rank_key(gpa)
        if key == "Fail":
            return "Fail" if english else labels_vi.get("Fail", "Không đạt")
        return label(key)

    thresholds = ", ".join(f"{label(k)} >= {v}" for k, v in order)
    applies = ", ".join(label(k) for k in retake.get("applies_to", []))
    threshold_count = retake.get("penalty_threshold", 2)
    levels = retake.get("penalty_levels", 1)
    excluded = ", ".join(rules.get("excluded_from_gpa", []))

    if english:
        lines = [
            f"- Graduation rank by GPA (10-point scale, credit-weighted): {thresholds}.",
            f"- Retake rule: retaken courses still count in GPA using the last attempt; a student who has retaken "
            f"{threshold_count} or more failed courses is downgraded {levels} rank if the rank is {applies}. "
            "Retaking a passed course only to improve the mark does not count as a retake.",
            f"- Courses not counted in GPA (still required for graduation credits): {excluded}.",
        ]
    else:
        lines = [
            f"- Xếp loại tốt nghiệp theo GPA (thang 10, có trọng số tín chỉ): {thresholds}.",
            f"- Quy chế học lại: môn học lại vẫn tính vào GPA theo điểm lần học cuối; nếu đã học lại từ "
            f"{threshold_count} môn trượt trở lên thì bị hạ {levels} bậc khi xếp loại là {applies}. "
            "Học cải thiện điểm (lần trước đã đạt) không tính là học lại.",
            f"- Các môn không tính vào GPA (vẫn phải đạt để đủ tín chỉ tốt nghiệp): {excluded}.",
        ]

    values = []
    for raw in _GPA_NUMBER_PATTERN.findall(question or ""):
        value = float(raw.replace(",", "."))
        if 0 < value <= 10 and ("." in raw or "," in raw):
            values.append(raw)
    penalized_ranks = set(retake.get("applies_to", []))
    mentions_penalized_rank = False
    for raw in dict.fromkeys(values):
        gpa = float(raw.replace(",", "."))
        mentions_penalized_rank = mentions_penalized_rank or rank_key(gpa) in penalized_ranks
        lines.append(
            f"- GPA {raw} corresponds to the rank: {rank_of(gpa)}."
            if english
            else f"- GPA {raw} tương ứng xếp loại: {rank_of(gpa)}."
        )
    if mentions_penalized_rank:
        lines.append(
            f"- Important for this goal: the {applies} ranks are subject to the retake downgrade rule above, "
            "so the answer must warn the student to avoid failing and retaking courses."
            if english
            else f"- Lưu ý quan trọng cho mục tiêu này: xếp loại {applies} chịu quy chế hạ bậc khi học lại ở trên, "
            "nên câu trả lời phải nhắc sinh viên tránh trượt môn và phải học lại."
        )
    return lines


def build_curriculum_facts(
    question: str,
    courses: Dict[str, Any],
    language: Language,
    curriculum_id: str,
    intents: Iterable[str] = (),
    student_context: Optional[Dict[str, Any]] = None,
    detected_courses: Iterable[str] = (),
) -> str:
    """Return a facts block for the prompt, or an empty string when nothing applies."""
    lines: List[str] = []
    semester = detect_semester(question, student_context)
    if semester is not None and not list(detected_courses):
        lines.extend(_semester_facts(courses, semester, curriculum_id, language))
    if asks_about_gpa(question, intents):
        lines.extend(_gpa_facts(question, language))
    if not lines:
        return ""

    header = (
        "=== CURRICULUM FACTS (COMPUTED BY CODE, AUTHORITATIVE) ==="
        if language == ENGLISH
        else "=== DỮ KIỆN CHƯƠNG TRÌNH (TÍNH BẰNG CODE, CHÍNH XÁC) ==="
    )
    return header + "\n" + "\n".join(lines) + "\n\n"
