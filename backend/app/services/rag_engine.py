import re
import time
from typing import Dict, List, Optional, Tuple, Any
from ..config import settings
from ..schemas.chat import ChatRequest, ChatResponse, SourceChunk
from ..schemas.course import CourseDetail, CourseSummary
from .flm_parser import FLMKnowledgeVaultParser, FLMDocumentChunk
from .vector_store import SemanticVectorStore
from .llm_service import LLMService
from .language import ENGLISH, detect_language
from .curriculum_facts import (
    build_curriculum_facts,
    detect_semester,
    find_unknown_subject,
    semester_courses,
    retake_policy_note,
    unknown_subject_answer,
)
from .study_planner import build_study_plan_facts, next_semester_answer

DEFAULT_CURRICULUM_ID = "BIT_SE_K19B"


def _parse_assessment_items(scheme: Optional[str]) -> List[Dict[str, str]]:
    if not scheme:
        return []
    items = []
    for line in scheme.strip().splitlines():
        line = line.strip()
        if not line.startswith("|") or line.startswith("|---") or "Thành Phần Đánh Giá" in line or "Category" in line:
            continue
        cols = [c.strip().strip("*").strip() for c in line.split("|")]
        if len(cols) >= 3:
            name = cols[1]
            weight = cols[2]
            min_mark = cols[3] if len(cols) > 3 else ""
            duration = cols[4] if len(cols) > 4 else ""
            if name and weight and "%" in weight:
                items.append({
                    "name": name,
                    "weight": weight,
                    "min_mark": min_mark,
                    "duration": duration,
                })
    return items


def _find_pe_item(course: Any) -> Optional[Dict[str, str]]:
    scheme = getattr(course, "assessment_scheme", None)
    items = _parse_assessment_items(scheme)
    for it in items:
        name_lower = it["name"].lower()
        if "practical exam" in name_lower or name_lower == "pe" or "thực hành" in name_lower:
            return it
    return None


def _find_te_item(course: Any) -> Optional[Dict[str, str]]:
    scheme = getattr(course, "assessment_scheme", None)
    items = _parse_assessment_items(scheme)
    for it in items:
        name_lower = it["name"].lower()
        if "theoretical exam" in name_lower or name_lower == "te" or "lý thuyết" in name_lower:
            return it
    return None


def _find_fe_item(course: Any) -> Optional[Dict[str, str]]:
    scheme = getattr(course, "assessment_scheme", None)
    items = _parse_assessment_items(scheme)
    for it in items:
        name_lower = it["name"].lower()
        if "final exam" in name_lower or name_lower == "fe" or "cuối kỳ" in name_lower:
            return it
    return None


def _direct_course_fact_answer(question: str, course: CourseDetail, language: str) -> Optional[str]:
    """Answer short factual questions from parsed FLM fields, without LLM additions."""
    normalized = question.casefold()
    wants_credits = any(term in normalized for term in ("tín chỉ", "credit"))
    wants_prerequisites = any(term in normalized for term in ("tiên quyết", "prerequisite"))
    wants_pe = bool(re.search(r"\bpe\b", normalized)) or any(term in normalized for term in ("thi pe", "có pe", "practical exam", "thi thực hành", "thực hành"))
    wants_te = bool(re.search(r"\bte\b", normalized)) or any(term in normalized for term in ("thi te", "có te", "theoretical exam", "thi lý thuyết", "lý thuyết"))
    wants_fe = (bool(re.search(r"\bfe\b", normalized)) or any(term in normalized for term in ("thi fe", "có fe", "final exam", "thi cuối kỳ", "cuối kỳ"))) and not wants_pe and not wants_te
    wants_outcomes = any(term in normalized for term in ("mục tiêu môn", "mục tiêu của môn",
        "learning outcome", "chuẩn đầu ra", "clo"))
    wants_presence = "xuất hiện" in normalized or "appear in" in normalized
    wants_semester = any(term in normalized for term in ("học kỳ mấy", "học kỳ nào", "kỳ mấy",
        "which semester", "what semester"))
    wants_grading_scheme = any(term in normalized for term in (
        "cấu trúc điểm", "thành phần điểm", "bảng điểm", "tỷ trọng điểm", "tỷ lệ điểm",
        "các đầu điểm", "đầu điểm", "grading scheme", "assessment scheme"
    ))

    if not any((wants_credits, wants_prerequisites, wants_pe, wants_te, wants_fe, wants_outcomes,
                wants_presence, wants_semester, wants_grading_scheme)):
        return None
    if len(question) > 160 or any(
        term in normalized
        for term in ("tư vấn", "chiến lược", "cách học", "strategy",
                     "study plan", "nên học", "ôn thi", "ôn tập", "để qua", "phân bổ")
    ):
        return None
    if language == ENGLISH:
        parts = []
        if wants_credits:
            parts.append(f"{course.code} has {course.credits} credits.")
        if wants_prerequisites:
            prerequisites = ", ".join(course.prerequisites or [])
            parts.append(
                f"The prerequisite for {course.code} is {prerequisites}."
                if prerequisites else f"{course.code} has no listed prerequisite."
            )
        if wants_pe:
            pe_item = _find_pe_item(course)
            if course.has_pe:
                weight_desc = f" accounting for {pe_item['weight']} of the total grade" if pe_item else ""
                meta_parts = []
                if pe_item:
                    if pe_item.get("duration"):
                        meta_parts.append(f"duration: {pe_item['duration']}")
                    if pe_item.get("min_mark"):
                        meta_parts.append(f"passing threshold: {pe_item['min_mark']}")
                meta_desc = f" ({', '.join(meta_parts)})" if meta_parts else ""
                parts.append(f"{course.code} has a practical exam (PE){weight_desc}{meta_desc} according to FLM.")
            else:
                parts.append(f"{course.code} does not have a practical exam (PE) according to FLM.")
        if wants_te:
            te_item = _find_te_item(course)
            if te_item:
                parts.append(f"The theoretical exam (TE) for {course.code} accounts for {te_item['weight']} of the total grade.")
        if wants_fe:
            fe_item = _find_fe_item(course)
            if fe_item:
                parts.append(f"The final exam (FE) for {course.code} accounts for {fe_item['weight']} of the total grade.")
        if wants_grading_scheme:
            items = _parse_assessment_items(course.assessment_scheme)
            if items:
                lines = [f"Assessment scheme for {course.code}:"]
                for it in items:
                    lines.append(f"- {it['name']}: {it['weight']}")
                parts.append("\n".join(lines))
        if wants_outcomes:
            parts.append(f"Learning outcomes for {course.code}: {course.learning_outcomes or 'not available in FLM'}")
        if wants_presence:
            places = ", ".join(
                f"{item.get('curriculum', course.curriculum)}, semester {item.get('semester', course.semester)}"
                for item in course.appears_in
            )
            parts.append(f"{course.code} appears in {places or f'{course.curriculum}, semester {course.semester}'}.")
        elif wants_semester:
            parts.append(f"{course.code} is in semester {course.semester} of {course.curriculum}.")
        return " ".join(parts)
    parts = []
    if wants_credits:
        parts.append(f"{course.code} có {course.credits} tín chỉ.")
    if wants_prerequisites:
        prerequisites = ", ".join(course.prerequisites or [])
        parts.append(
            f"Môn tiên quyết của {course.code} là {prerequisites}."
            if prerequisites else f"{course.code} không có môn tiên quyết được ghi trong dữ liệu FLM."
        )
    if wants_pe:
        pe_item = _find_pe_item(course)
        if getattr(course, "has_pe", False):
            weight_desc = f" và bài thi PE chiếm {pe_item['weight']} tổng điểm môn học" if pe_item else ""
            meta_parts = []
            if pe_item:
                if pe_item.get("duration"):
                    meta_parts.append(f"thời lượng {pe_item['duration']}")
                if pe_item.get("min_mark"):
                    meta_parts.append(f"điểm liệt {pe_item['min_mark']}")
            meta_desc = f" ({', '.join(meta_parts)})" if meta_parts else ""
            parts.append(
                f"Theo dữ liệu FLM, {course.code} có thi PE (thực hành){weight_desc}{meta_desc}."
            )
        else:
            parts.append(
                f"Theo dữ liệu FLM, {course.code} không có thi PE (thực hành)."
            )
    if wants_te:
        te_item = _find_te_item(course)
        if te_item:
            meta_parts = []
            if te_item.get("duration"):
                meta_parts.append(f"thời lượng {te_item['duration']}")
            if te_item.get("min_mark"):
                meta_parts.append(f"điểm liệt {te_item['min_mark']}")
            meta_desc = f" ({', '.join(meta_parts)})" if meta_parts else ""
            parts.append(
                f"Theo dữ liệu FLM, bài thi lý thuyết (Theoretical Exam/TE) của môn {course.code} chiếm {te_item['weight']} tổng điểm{meta_desc}."
            )
    if wants_fe:
        fe_item = _find_fe_item(course)
        if fe_item:
            parts.append(
                f"Theo dữ liệu FLM, bài thi cuối kỳ (Final Exam/FE) của môn {course.code} chiếm {fe_item['weight']} tổng điểm."
            )
    if wants_grading_scheme:
        items = _parse_assessment_items(course.assessment_scheme)
        if items:
            lines = [f"Cấu trúc đánh giá (Assessment Scheme) của môn {course.code} theo FLM:"]
            for it in items:
                line_text = f"- {it['name']}: {it['weight']}"
                if it.get("min_mark"):
                    line_text += f" (điểm liệt {it['min_mark']})"
                if it.get("duration"):
                    line_text += f", thời lượng {it['duration']}"
                lines.append(line_text)
            if course.min_pass_mark:
                lines.append(f"Điểm đạt tối thiểu: {course.min_pass_mark}/10.")
            parts.append("\n".join(lines))
    if wants_outcomes:
        parts.append(
            f"Chuẩn đầu ra (Learning Outcomes) của {course.code}: "
            f"{course.learning_outcomes or 'chưa có dữ liệu trong FLM'}"
        )
    if wants_presence:
        places = ", ".join(
            f"{item.get('curriculum', course.curriculum)}, HK{item.get('semester', course.semester)}"
            for item in course.appears_in
        )
        parts.append(
            f"{course.code} xuất hiện trong {places or f'{course.curriculum}, HK{course.semester}'}."
        )
    elif wants_semester:
        parts.append(f"{course.code} học ở học kỳ {course.semester} trong {course.curriculum}.")
    return " ".join(parts)


class RAGEngine:
    """
    Central RAG Coordinator for the FLM Knowledge & AI Assistant System.
    """

    def __init__(self):
        self.parser: Optional[FLMKnowledgeVaultParser] = None
        self.vector_store: SemanticVectorStore = SemanticVectorStore(
            model_name=settings.RAG_EMBEDDING_MODEL,
            cache_dir=settings.RAG_EMBEDDING_CACHE,
        )
        self.llm_service: LLMService = LLMService()
        self.courses: Dict[str, CourseDetail] = {}
        self.is_initialized: bool = False

    def initialize(self):
        """Loads and indexes knowledge base on application startup."""
        vault_path = settings.get_vault_path()
        courses_json_path = settings.get_courses_data_path()

        print(f"[RAGEngine] Initializing knowledge base from {vault_path}...")
        self.parser = FLMKnowledgeVaultParser(vault_path, courses_json_path)
        self.courses, chunks = self.parser.load_all()
        # Legacy/equivalent syllabi may exist in the vault, but they are not
        # subjects in the active curriculum and must not enter default RAG.
        active_codes = {
            str(code).upper()
            for code, course in self.courses.items()
            if getattr(course, "in_curriculum", True)
        }
        self.courses = {
            code: course
            for code, course in self.courses.items()
            if getattr(course, "in_curriculum", True)
        }
        chunks = [
            chunk
            for chunk in chunks
            if (chunk.course_code or "").upper() in active_codes
            or (chunk.course_code or "").upper() in {"CURRICULUM", "PLO"}
        ]
        self.vector_store.index_chunks(chunks)
        self.is_initialized = True
        print(f"[RAGEngine] Knowledge base initialized with {len(self.courses)} courses and {len(chunks)} chunks.")

    async def answer_query(self, request: ChatRequest) -> ChatResponse:
        """
        Executes end-to-end RAG retrieval, context formulation, and answer generation.
        """
        start_time = time.time()
        query = request.query_text

        if not query:
            return ChatResponse(
                answer="Vui lòng cung cấp câu hỏi về môn học hoặc chương trình đào tạo FLM.",
                sources=[],
                question=query,
                latency_ms=0.0,
                provider="None",
            )

        # 1. Detect target courses & query intent
        detected_courses = self.vector_store.extract_target_courses(query)
        detected_intents = self.vector_store.detect_query_intent(query)

        has_semester_mention = detect_semester(query, request.student_context) is not None
        if not detected_courses and request.history and not has_semester_mention:
            for past_turn in reversed(request.history):
                past_content = past_turn.content if hasattr(past_turn, "content") else past_turn.get("content", "")
                past_courses = self.vector_store.extract_target_courses(past_content)
                if past_courses:
                    detected_courses = past_courses
                    break

        # A selected semester is authoritative for an implicit question such
        # as "môn nào". Semantic course detection can otherwise pull an
        # unrelated subject into the answer.
        selected_semester = (request.student_context or {}).get("target_semester")
        if request.scope == "curriculum" and selected_semester is not None:
            requested_semester = detect_semester(query, request.student_context)
            in_semester = {
                course.code.upper()
                for course in semester_courses(self.courses, requested_semester)
            }
            explicit_outside = [
                code for code in detected_courses
                if code.upper() in self.courses
                and code.upper() not in in_semester
                and re.search(rf"\b{re.escape(code)}\b", query, re.IGNORECASE)
            ]
            if explicit_outside:
                code = explicit_outside[0].upper()
                actual_semester = self.courses[code].semester
                return ChatResponse(
                    answer=(
                        f"Môn {code} thuộc Học kỳ {actual_semester}, còn bạn đang hỏi "
                        f"trong Học kỳ {requested_semester}. Hãy mở môn hoặc học kỳ đó "
                        "để hỏi chi tiết."
                    ),
                    sources=[f"{code}.md (Dữ liệu môn học FLM)"],
                    question=query,
                    matched_courses=[code],
                    provider="FLM-Structured-Synthesizer",
                    latency_ms=round((time.time() - start_time) * 1000, 2),
                    detailed_sources=[],
                )
            detected_courses = [
                code for code in detected_courses if code.upper() in in_semester
            ]

        target_course = (
            request.course_code
            or (request.id if request.scope == "subject" else None)
            or (detected_courses[0] if detected_courses else None)
        )
        if request.scope == "curriculum" and not target_course:
            target_course = request.id or DEFAULT_CURRICULUM_ID

        language = detect_language(query)
        curriculum_id = (request.id if request.scope == "curriculum" else None) or DEFAULT_CURRICULUM_ID

        if (request.scope == "subject" or request.course_code) and target_course and target_course.upper() not in self.courses:
            return ChatResponse(
                answer=unknown_subject_answer(target_course.upper(), curriculum_id, language),
                sources=[],
                question=query,
                matched_courses=[],
                provider="FLM-Structured-Synthesizer",
                latency_ms=round((time.time() - start_time) * 1000, 2),
                detailed_sources=[],
            )

        # A named subject that is not in the curriculum gets a fixed answer
        # instead of letting the LLM improvise from unrelated chunks.
        if not detected_courses and not request.course_code and request.scope != "subject":
            unknown_subject = find_unknown_subject(query, self.courses)
            if unknown_subject:
                return ChatResponse(
                    answer=unknown_subject_answer(unknown_subject, curriculum_id, language),
                    sources=[],
                    question=query,
                    matched_courses=[],
                    provider="FLM-Structured-Synthesizer",
                    latency_ms=round((time.time() - start_time) * 1000, 2),
                    detailed_sources=[],
                )

        if request.scope == "curriculum" and not detected_courses:
            next_answer = next_semester_answer(
                query, self.courses, request.student_context, language
            )
            if next_answer is not None:
                current_semester = (request.student_context or {}).get("current_semester")
                course_sources = (
                    [f"{course.code}.md (Tiên quyết môn học FLM)"
                     for course in semester_courses(self.courses, current_semester + 1)]
                    if isinstance(current_semester, int) else []
                )
                return ChatResponse(
                    answer=next_answer,
                    sources=[f"{curriculum_id}.md (Dữ liệu curriculum FLM)", *course_sources],
                    question=query,
                    matched_courses=[],
                    provider="FLM-Structured-Synthesizer",
                    latency_ms=round((time.time() - start_time) * 1000, 2),
                    detailed_sources=[],
                )

        if request.scope == "curriculum" and not detected_courses and any(
            term in query.casefold() for term in ("tín chỉ", "credit")
        ):
            stats = self.get_curriculum_stats(curriculum_id)
            if stats and stats.semesters:
                semester = detect_semester(query, request.student_context)
                if semester is not None:
                    group = next((item for item in stats.semesters
                                  if item.semester == semester), None)
                    if group is not None:
                        courses = ", ".join(group.courses)
                        answer = (
                            f"HK{semester} có {group.total_credits} tín chỉ "
                            f"với {group.course_count} môn: {courses}."
                            if language != ENGLISH else
                            f"Semester {semester} has {group.total_credits} credits "
                            f"across {group.course_count} courses: {courses}."
                        )
                    else:
                        answer = (f"Không có dữ liệu HK{semester} trong {curriculum_id}."
                                  if language != ENGLISH else
                                  f"No semester {semester} is listed for {curriculum_id}.")
                else:
                    answer = (
                        f"{curriculum_id} có tổng cộng {stats.total_credits} tín chỉ."
                        if language != ENGLISH else
                        f"{curriculum_id} has {stats.total_credits} total credits."
                    )
                return ChatResponse(
                    answer=answer,
                    sources=[f"{curriculum_id}.md (Dữ liệu curriculum FLM)"],
                    question=query,
                    matched_courses=[],
                    provider="FLM-Structured-Synthesizer",
                    latency_ms=round((time.time() - start_time) * 1000, 2),
                    detailed_sources=[],
                )

        if target_course and target_course.upper() in self.courses:
            direct_answer = _direct_course_fact_answer(
                query, self.courses[target_course.upper()], language
            )
            if direct_answer:
                code = target_course.upper()
                return ChatResponse(
                    answer=direct_answer,
                    sources=[f"{code}.md (Dữ liệu môn học FLM)"],
                    question=query,
                    matched_courses=[code],
                    provider="FLM-Structured-Synthesizer",
                    latency_ms=round((time.time() - start_time) * 1000, 2),
                    detailed_sources=[],
                )

        top_k = request.top_k or settings.TOP_K_CHUNKS

        related_courses = [
            code for code in detected_courses
            if code.upper() != (target_course or "").upper() and code.upper() in self.courses
        ]
        # Reserve evidence slots for an explicitly named related course. Without
        # this, a four-chunk subject scope crowds the comparison evidence out
        # of the prompt before the generator can read it.
        primary_top_k = max(1, top_k - min(2 * len(related_courses), top_k - 1))

        # Select semester evidence before ranking. Filtering a top-k result
        # afterwards can discard every relevant course chunk.
        semester = detect_semester(query, request.student_context)
        semester_scope = (
            request.scope == "curriculum"
            and semester is not None
            and not detected_courses
        )
        allowed_course_codes = None
        if semester_scope:
            allowed_course_codes = {
                c.code.upper() for c in semester_courses(self.courses, semester)
            }

        # 2. Retrieve most relevant context chunks
        retrieved_results = self.vector_store.search(
            query=query,
            top_k=primary_top_k,
            target_course=None if semester_scope else target_course,
            similarity_threshold=settings.SIMILARITY_THRESHOLD,
            allowed_course_codes=allowed_course_codes,
        )

        # A subject-scoped conversation normally searches only the open
        # course. When the student explicitly names another course, that
        # restriction leaves the model unable to verify a comparison or the
        # reason for a prerequisite. Fetch compact evidence for each named
        # related course and retain it as a separately identifiable source.
        if related_courses:
            seen_chunks = {
                (chunk.course_code, chunk.category, chunk.title, chunk.content)
                for chunk, _ in retrieved_results
            }
            for related_course in related_courses:
                related_results = self.vector_store.search(
                    query=f"{query} chuẩn đầu ra CLO kỹ năng nội dung môn học",
                    top_k=min(2, top_k),
                    target_course=related_course,
                    similarity_threshold=settings.SIMILARITY_THRESHOLD,
                )
                for chunk, score in related_results:
                    identity = (chunk.course_code, chunk.category, chunk.title, chunk.content)
                    if identity not in seen_chunks:
                        retrieved_results.append((chunk, score))
                        seen_chunks.add(identity)

        # A semester question without a specific subject must only see that
        # semester's courses; chunks of other semesters mislead the model.
        curriculum_facts = build_curriculum_facts(
            question=query,
            courses=self.courses,
            language=language,
            curriculum_id=curriculum_id,
            intents=detected_intents,
            student_context=request.student_context,
            detected_courses=detected_courses,
        )
        planner_facts = build_study_plan_facts(
            question=query,
            courses=self.courses,
            detected_courses=detected_courses,
            student_context=request.student_context,
            language=language,
        )
        curriculum_facts = curriculum_facts + planner_facts

        # 3. Generate Answer via LLM / Advanced Synthesizer
        answer_text, provider_name = await self.llm_service.generate_response(
            question=query,
            retrieved_chunks=retrieved_results,
            detected_courses=detected_courses or ([target_course] if target_course and target_course not in [DEFAULT_CURRICULUM_ID, "CURRICULUM"] else []),
            detected_intents=detected_intents,
            scope=request.scope,
            scope_id=request.id or target_course,
            student_context=request.student_context,
            all_courses=self.courses,
            curriculum_info=self.parser.curriculum_info if self.parser else {},
            curriculum_facts=curriculum_facts,
            conversation_history=[turn.model_dump() for turn in request.history],
        )

        # A small local model may omit a rank rule even when the structured
        # grading facts were supplied. Keep this critical rule deterministic.
        lower_query = query.casefold()
        lower_answer = answer_text.casefold()
        graduation_goal = any(term in lower_query for term in (
            "ra trường", "tốt nghiệp", "mục tiêu gpa", "target gpa",
            "graduation gpa", "graduate with",
        ))
        mentions_policy = any(term in lower_answer for term in (
            "học lại", "hạ bậc", "retake", "downgrad",
        ))
        if graduation_goal and not mentions_policy and "GPA" in curriculum_facts:
            note = retake_policy_note(language)
            if note:
                answer_text = f"{answer_text.rstrip()}\n\n{note}"


        # 4. Construct human-readable sources list & detailed source chunks
        sources_list: List[str] = []
        detailed_sources: List[SourceChunk] = []

        seen_sources = set()
        for chunk, score in retrieved_results:
            source_label = f"{chunk.file_name} ({chunk.title})"
            if source_label not in seen_sources:
                sources_list.append(source_label)
                seen_sources.add(source_label)

            detailed_sources.append(
                SourceChunk(
                    course_code=chunk.course_code,
                    section=chunk.category,
                    file_name=chunk.file_name,
                    score=round(score, 3),
                    content_snippet=chunk.content[:200] + "..." if len(chunk.content) > 200 else chunk.content,
                )
            )

        if not sources_list:
            sources_list = ["Hệ thống dữ liệu FLM FPT University (Curriculum & Syllabus)"]

        latency_ms = round((time.time() - start_time) * 1000, 2)

        return ChatResponse(
            answer=answer_text,
            sources=sources_list,
            question=query,
            matched_courses=detected_courses,
            provider=provider_name,
            latency_ms=latency_ms,
            detailed_sources=detailed_sources,
        )

    def get_all_courses(self) -> List[CourseSummary]:
        """Returns summary list of all available courses."""
        return [
            CourseSummary(
                code=c.code,
                name_vi=c.name_vi,
                name_en=c.name_en,
                credits=c.credits,
                semester=c.semester,
                prerequisites=c.prerequisites,
                unlocks=c.unlocks,
            )
            for c in self.courses.values()
        ]

    def get_course_detail(self, code: str) -> Optional[CourseDetail]:
        """Retrieves complete course syllabus details by code."""
        code_upper = code.upper()
        if code_upper in self.courses:
            return self.courses[code_upper]
        
        return None

    def get_curriculum_stats(self, curriculum_id: str = "BIT_SE_K19B"):
        """Returns structured stats of a curriculum."""
        if self.parser:
            return self.parser.get_curriculum_stats(curriculum_id)
        return None

    def get_course_presence(self, code: str):
        """Returns list of curricula where course appears."""
        if self.parser:
            return self.parser.get_course_presence(code)
        return []

    def check_prerequisites(self, code: str, completed_courses: List[str]):
        """Checks if prerequisites for course are satisfied."""
        if self.parser:
            return self.parser.check_prerequisites(code, completed_courses)
        return None



# Global singleton instance
rag_engine = RAGEngine()
