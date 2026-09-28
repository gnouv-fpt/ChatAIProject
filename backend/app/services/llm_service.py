import asyncio
import os
import re
import json
import time
from typing import Dict, List, Optional, Tuple, Any
import httpx

from ..config import settings
from .flm_parser import FLMDocumentChunk


class LLMService:
    """
    Multi-Provider LLM & Advanced Contextual Synthesis Service:
    - Gemini (Google AI)
    - OpenAI (GPT models)
    - Groq (Ultra-fast Llama inference)
    - Ollama (Local LLM server)
    - Advanced FLM Synthesis Engine with actionable academic advising & dynamic grounded generation.
    """

    def __init__(self):
        self._http_client: Optional[httpx.AsyncClient] = None
        self._loop = None

    @property
    def http_client(self) -> httpx.AsyncClient:
        current_loop = None
        try:
            current_loop = asyncio.get_running_loop()
        except RuntimeError:
            pass

        if (
            self._http_client is None
            or self._http_client.is_closed
            or getattr(self, "_loop", None) != current_loop
        ):
            self._http_client = httpx.AsyncClient(timeout=15.0)
            self._loop = current_loop
        return self._http_client

    async def close(self):
        if self._http_client and not self._http_client.is_closed:
            await self._http_client.aclose()
            self._http_client = None
            self._loop = None


    def get_active_provider(self) -> str:
        """Determines active provider based on configuration and available API keys."""
        cfg = settings.LLM_PROVIDER
        if cfg == "gemini" and settings.GEMINI_API_KEY:
            return "Gemini"
        if cfg == "openai" and settings.OPENAI_API_KEY:
            return "OpenAI"
        if cfg == "groq" and settings.GROQ_API_KEY:
            return "Groq"
        if cfg == "ollama":
            return "Ollama"

        if settings.GEMINI_API_KEY:
            return "Gemini"
        if settings.OPENAI_API_KEY:
            return "OpenAI"
        if settings.GROQ_API_KEY:
            return "Groq"

        return "FLM-Advanced-Synthesizer"

    @staticmethod
    def _sanitize_output(text: str) -> str:
        """
        Global sanitizer:
        1. Strips decorative emojis and special pictographs.
        2. Fixes markdown glitches like 'và**3.', '**1.'.
        3. Normalizes repetitive asterisks and line breaks.
        """
        if not text:
            return ""

        # Remove decorative emojis & pictographs
        emoji_pattern = re.compile(
            r"[\U00010000-\U0010ffff\u2600-\u27ff\ufe00-\ufe0f\u2300-\u23ff\u2b50-\u2b55\u200d\u24c2-\u2573]",
            flags=re.UNICODE,
        )
        cleaned = emoji_pattern.sub("", text)

        # Fix markdown glitches
        cleaned = re.sub(r"([a-zA-ZÀ-ỹ])\*\*(\d+)\.", r"\1 \2.", cleaned)
        cleaned = re.sub(r"([a-zA-ZÀ-ỹ])\*\*([A-ZÀ-Ỹ])", r"\1 \2", cleaned)
        cleaned = re.sub(r"^(#{1,6})\s*\*\*([^\*]+)\*\*", r"\1 \2", cleaned, flags=re.MULTILINE)
        cleaned = re.sub(r"###\s*[-*•]\s*", "### ", cleaned)
        cleaned = re.sub(r"[ \t]+", " ", cleaned)
        cleaned = re.sub(r"\n{3,}", "\n\n", cleaned)
        return cleaned.strip()

    async def generate_response(
        self,
        question: str,
        retrieved_chunks: List[Tuple[FLMDocumentChunk, float]],
        detected_courses: List[str],
        scope: Optional[str] = None,
        scope_id: Optional[str] = None,
        student_context: Optional[Dict[str, Any]] = None,
        all_courses: Optional[Dict[str, Any]] = None,
        curriculum_info: Optional[Dict[str, Any]] = None,
        detected_intents: Optional[List[str]] = None,
    ) -> Tuple[str, str]:
        """
        Generates grounded, natural, and actionable response using retrieved context.
        """
        provider = self.get_active_provider()
        context_str = self._format_context(retrieved_chunks)
        student_facts_str = self._format_student_facts(student_context)

        # For FLM-scoped questions, the deterministic synthesizer is the
        # source of truth. A cloud model may paraphrase, but it must not be
        # allowed to replace scoped retrieval with an unrelated answer.
        use_structured_synthesis = bool(scope in {"subject", "curriculum"} or detected_courses)

        if use_structured_synthesis:
            answer = self._synthesize_advanced_response(
                question=question,
                retrieved_chunks=retrieved_chunks,
                detected_courses=detected_courses,
                scope=scope,
                scope_id=scope_id,
                student_context=student_context,
                all_courses=all_courses or {},
                curriculum_info=curriculum_info or {},
                detected_intents=detected_intents or [],
            )
            return self._sanitize_output(answer), "FLM-Structured-RAG"

        # 1. Try Primary Cloud Provider if available
        if provider == "Gemini":
            try:
                answer = await self._call_gemini(question, context_str, student_facts_str)
                if answer:
                    return self._sanitize_output(answer), "Gemini"
            except Exception as e:
                print(f"[LLMService] Gemini error: {e}. Falling back to Advanced Synthesizer.")

        elif provider == "OpenAI":
            try:
                answer = await self._call_openai(question, context_str, student_facts_str)
                if answer:
                    return self._sanitize_output(answer), "OpenAI"
            except Exception as e:
                print(f"[LLMService] OpenAI error: {e}. Falling back to Advanced Synthesizer.")

        elif provider == "Groq":
            try:
                answer = await self._call_groq(question, context_str, student_facts_str)
                if answer:
                    return self._sanitize_output(answer), "Groq"
            except Exception as e:
                print(f"[LLMService] Groq error: {e}. Falling back to Advanced Synthesizer.")

        elif provider == "Ollama":
            try:
                answer = await self._call_ollama(question, context_str, student_facts_str)
                if answer:
                    return self._sanitize_output(answer), "Ollama"
            except Exception as e:
                print(f"[LLMService] Ollama error: {e}. Falling back to Advanced Synthesizer.")

        # 2. Advanced Contextual Synthesis Engine
        answer = self._synthesize_advanced_response(
            question=question,
            retrieved_chunks=retrieved_chunks,
            detected_courses=detected_courses,
            scope=scope,
            scope_id=scope_id,
            student_context=student_context,
            all_courses=all_courses or {},
            curriculum_info=curriculum_info or {},
        )
        return self._sanitize_output(answer), "FLM-Advanced-Synthesizer"

    def _format_context(self, chunks: List[Tuple[FLMDocumentChunk, float]]) -> str:
        parts = []
        for i, (chunk, score) in enumerate(chunks, 1):
            parts.append(
                f"--- [TÀI LIỆU {i}] {chunk.title} (Mã: {chunk.course_code}, File: {chunk.file_name}) ---\n"
                f"{chunk.content}\n"
            )
        return "\n".join(parts)

    def _format_student_facts(self, ctx: Optional[Dict[str, Any]]) -> str:
        if not ctx:
            return ""
        lines = ["=== DỮ KIỆN HỌC TẬP CỦA SINH VIÊN (TÍNH TOÁN BẰNG CODE) ==="]
        if ctx.get("current_gpa") is not None:
            lines.append(f"- Điểm GPA hiện tại: {ctx.get('current_gpa')}")
        if ctx.get("target_gpa") is not None:
            lines.append(f"- Điểm GPA mục tiêu: {ctx.get('target_gpa')}")
        if ctx.get("required_avg_mark") is not None:
            lines.append(f"- Điểm trung bình cần đạt ở các môn còn lại: {ctx.get('required_avg_mark')}")
        if ctx.get("is_target_feasible") is not None:
            lines.append(f"- Tính khả thi của mục tiêu: {'Khả thi' if ctx.get('is_target_feasible') else 'Không khả thi (cần > 10 điểm)'}")
        if ctx.get("retake_count") is not None:
            lines.append(f"- Số môn đã học lại (đã từng trượt): {ctx.get('retake_count')}")
            if ctx.get("retake_count", 0) >= 2:
                lines.append("- Cảnh báo hạ bậc: Đã học lại >= 2 môn, nếu đạt loại Giỏi/Xuất sắc sẽ bị hạ 1 bậc.")
            elif ctx.get("retake_count", 0) == 1:
                lines.append("- Cảnh báo hạ bậc: Đã học lại 1 môn. Nếu học lại thêm 1 môn nữa sẽ bị hạ bậc.")
        if ctx.get("failed_courses"):
            lines.append(f"- Môn học chưa đạt cần học lại: {', '.join(ctx.get('failed_courses', []))}")
        return "\n".join(lines) + "\n\n"

    def _build_system_prompt(self) -> str:
        return (
            "Bạn là Cố vấn Học tập AI chuyên trách hệ thống FLM (Curriculum & Syllabus) của FPT University. "
            "Nhiệm vụ của bạn là giải đáp thông tin và tư vấn chiến lược học tập cho sinh viên.\n\n"
            "Quy tắc phản hồi:\n"
            "1. Dùng tiếng Việt tự nhiên, gãy gọn, chuyên nghiệp. Không lạm dụng dấu in đậm (**) tràn lan ở mọi từ ngữ.\n"
            "2. Khi được hỏi tư vấn học tập hoặc chiến lược ôn thi (PE/FE), hãy đưa ra lời khuyên cụ thể, có tính hành động cao (actionable): "
            "phân bổ thời gian, kỹ năng cần rèn luyện, cách tận dụng môn tiên quyết, lưu ý về điểm tối thiểu.\n"
            "3. Tuyệt đối trung thực với dữ liệu FLM. Với thông tin ngoài phạm vi FLM, giải thích rõ ràng thay vì bịa đặt.\n"
            "4. Định dạng Markdown thanh lịch, dễ đọc với gạch đầu dòng rõ ràng."
        )

    async def _call_gemini(self, question: str, context: str, student_facts: str = "") -> Optional[str]:
        api_key = settings.GEMINI_API_KEY
        model = settings.GEMINI_MODEL
        url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={api_key}"

        prompt = (
            f"{self._build_system_prompt()}\n\n"
            f"{student_facts}"
            f"=== DỮ LIỆU FLM THỰC TẾ (CONTEXT) ===\n{context}\n\n"
            f"=== CÂU HỎI CỦA SINH VIÊN ===\n{question}\n\n"
            f"=== CÂU TRẢ LỜI CỦA TRỢ LÝ AI ==="
        )

        payload = {
            "contents": [{"parts": [{"text": prompt}]}],
            "generationConfig": {
                "temperature": 0.25,
                "maxOutputTokens": 1200,
            }
        }

        resp = await self.http_client.post(url, json=payload, timeout=12.0)
        if resp.status_code == 200:
            data = resp.json()
            candidates = data.get("candidates", [])
            if candidates:
                parts = candidates[0].get("content", {}).get("parts", [])
                if parts:
                    return parts[0].get("text", "").strip()
        return None

    async def _call_openai(self, question: str, context: str, student_facts: str = "") -> Optional[str]:
        api_key = settings.OPENAI_API_KEY
        base_url = settings.OPENAI_BASE_URL.rstrip("/")
        model = settings.OPENAI_MODEL

        headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        }
        user_content = f"{student_facts}=== DỮ LIỆU FLM THỰC TẾ ===\n{context}\n\n=== CÂU HỎI CỦA SINH VIÊN ===\n{question}"
        payload = {
            "model": model,
            "messages": [
                {"role": "system", "content": self._build_system_prompt()},
                {"role": "user", "content": user_content},
            ],
            "temperature": 0.25,
        }
        resp = await self.http_client.post(f"{base_url}/chat/completions", headers=headers, json=payload, timeout=12.0)
        if resp.status_code == 200:
            data = resp.json()
            return data["choices"][0]["message"]["content"].strip()
        return None

    async def _call_groq(self, question: str, context: str, student_facts: str = "") -> Optional[str]:
        api_key = settings.GROQ_API_KEY
        model = settings.GROQ_MODEL
        url = "https://api.groq.com/openai/v1/chat/completions"

        headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        }
        user_content = f"{student_facts}=== DỮ LIỆU FLM THỰC TẾ ===\n{context}\n\n=== CÂU HỎI ===\n{question}"
        payload = {
            "model": model,
            "messages": [
                {"role": "system", "content": self._build_system_prompt()},
                {"role": "user", "content": user_content},
            ],
            "temperature": 0.25,
        }
        resp = await self.http_client.post(url, headers=headers, json=payload, timeout=12.0)
        if resp.status_code == 200:
            data = resp.json()
            return data["choices"][0]["message"]["content"].strip()
        return None

    async def _call_ollama(self, question: str, context: str, student_facts: str = "") -> Optional[str]:
        base_url = settings.OLLAMA_BASE_URL.rstrip("/")
        model = settings.OLLAMA_MODEL
        prompt = f"{self._build_system_prompt()}\n\n{student_facts}=== DỮ LIỆU FLM ===\n{context}\n\n=== CÂU HỎI ===\n{question}\n\n=== TRẢ LỜI ==="
        payload = {"model": model, "prompt": prompt, "stream": False}
        resp = await self.http_client.post(f"{base_url}/api/generate", json=payload, timeout=20.0)
        if resp.status_code == 200:
            return resp.json().get("response", "").strip()
        return None

    @staticmethod
    def _target_semester(question: str, student_context: Optional[Dict[str, Any]]) -> Optional[int]:
        """Resolve an explicit semester without silently guessing a random one."""
        q_lower = question.lower()
        match = re.search(r"(?:học\s*kỳ|kỳ|hk|semester)\s*(?:số\s*)?(\d+)", q_lower)
        if match:
            return int(match.group(1))

        if any(phrase in q_lower for phrase in ["kỳ này", "học kỳ này", "semester này"]):
            context = student_context or {}
            value = context.get("target_semester") or context.get("current_semester")
            try:
                return int(value) if value is not None else None
            except (TypeError, ValueError):
                return None
        return None

    @classmethod
    def _build_semester_strategy(
        cls,
        question: str,
        all_courses: Dict[str, Any],
        student_context: Optional[Dict[str, Any]],
    ) -> str:
        """Build an explainable semester plan from structured FLM course data."""
        semester = cls._target_semester(question, student_context)
        if semester is None:
            available = sorted({getattr(course, "semester", 0) for course in all_courses.values()})
            labels = ", ".join(f"HK{value}" for value in available if value > 0)
            return (
                "### Mình cần xác định học kỳ trước khi tư vấn\n\n"
                "Câu hỏi đang nói đến ‘kỳ này’ nhưng request chưa có học kỳ hiện tại, "
                "nên mình không tự đoán để tránh tư vấn nhầm môn. "
                f"Bạn hãy nói rõ HK (ví dụ: HK5). Các kỳ có trong dữ liệu hiện tại: {labels}."
            )

        courses = [
            course
            for course in all_courses.values()
            if getattr(course, "semester", 0) == semester and getattr(course, "in_curriculum", True)
        ]
        courses.sort(key=lambda course: getattr(course, "code", ""))
        if not courses:
            return (
                f"### Chưa có dữ liệu cho Học kỳ {semester}\n\n"
                f"Kho FLM hiện không có môn nào được gán vào Học kỳ {semester}. "
                "Bạn hãy kiểm tra lại mã curriculum hoặc chọn một học kỳ khác."
            )

        dependent_counts = {
            getattr(course, "code", "").upper(): sum(
                1
                for other in all_courses.values()
                if getattr(course, "code", "").upper() in {
                    str(prereq).upper() for prereq in getattr(other, "prerequisites", [])
                }
            )
            for course in courses
        }

        ranked = []
        for course in courses:
            code = getattr(course, "code", "")
            credits = max(1, int(getattr(course, "credits", 3)))
            has_pe = bool(getattr(course, "has_pe", False))
            dependents = dependent_counts.get(code.upper(), 0)
            name = getattr(course, "name_vi", "") or getattr(course, "name_en", "") or code
            reasons = [f"{credits} tín chỉ"]
            priority_score = float(credits)
            if has_pe:
                priority_score += 2.0
                reasons.append("có PE/thực hành")
            if dependents:
                priority_score += 1.0
                reasons.append(f"là tiên quyết cho {dependents} môn sau")
            if any(token in f"{code} {name}".lower() for token in ["đồ án", "dự án", "project", "capstone"]):
                priority_score += 2.0
                reasons.append("môn dự án")
            ranked.append((priority_score, course, name, reasons))

        ranked.sort(key=lambda item: (-item[0], getattr(item[1], "code", "")))
        total_weight = sum(item[0] for item in ranked)
        lines = [
            f"### Kế hoạch học tập Học kỳ {semester}",
            "",
            f"Kỳ này có **{len(courses)} môn / {sum(int(getattr(c, 'credits', 0)) for c in courses)} tín chỉ**.",
            "Mục tiêu của kế hoạch: ưu tiên môn có rủi ro và ảnh hưởng dây chuyền cao trước, "
            "nhưng vẫn giữ lịch đều cho toàn bộ môn.",
            "",
            "**Thứ tự ưu tiên và phân bổ thời gian đề xuất:**",
        ]
        for index, (score, course, name, reasons) in enumerate(ranked, 1):
            percent = round(score / total_weight * 100)
            pe_note = " Ôn PE từ tuần đầu." if getattr(course, "has_pe", False) else ""
            lines.append(
                f"{index}. **{getattr(course, 'code', '')} - {name}**: khoảng **{percent}%** thời gian "
                f"({'; '.join(reasons)}).{pe_note}"
            )

        lines.extend([
            "",
            "**Cách triển khai rõ ràng:**",
            "- Đầu kỳ: đọc đề cương, chốt đầu ra và chia lịch cố định cho từng môn; không dồn môn có PE/dự án vào cuối kỳ.",
            "- Mỗi tuần: dành ít nhất một phiên làm bài thực hành hoặc sản phẩm thật cho môn ưu tiên cao nhất, rồi cập nhật tiến độ.",
            "- Trước mỗi mốc kiểm tra: kiểm tra lại tiên quyết và phần còn yếu; nếu một môn trễ tiến độ hai tuần liên tiếp thì chuyển thêm thời gian từ môn đã ổn định.",
            "- Cuối kỳ: dành thời gian riêng để luyện đề/PE và hoàn thiện deliverable, không tính đó là thời gian học lý thuyết mới.",
        ])
        if student_context and student_context.get("current_gpa") is not None:
            lines.append(
                f"\nGPA hiện tại được tính từ bảng điểm của bạn là **{student_context['current_gpa']}**; "
                "mình dùng dữ kiện này để ưu tiên giữ điểm các môn tính GPA và không tự tính lại bằng LLM."
            )
        return "\n".join(lines)

    @classmethod
    def _build_future_semesters_strategy(
        cls,
        all_courses: Dict[str, Any],
        student_context: Optional[Dict[str, Any]],
    ) -> str:
        """Plan every remaining semester from the confirmed transcript facts."""
        context = student_context or {}
        current_value = context.get("current_semester") or context.get("target_semester")
        try:
            current_semester = int(current_value)
        except (TypeError, ValueError):
            return (
                "### Chưa thể lập chiến lược các kỳ tiếp theo\n\n"
                "Bảng điểm chưa có học kỳ gần nhất hoặc chưa được xác nhận. "
                "Hãy kiểm tra lại cột học kỳ trong bảng điểm để hệ thống biết bắt đầu từ đâu."
            )

        completed = {str(code).upper() for code in context.get("completed_courses", [])}
        future = [
            course for course in all_courses.values()
            if getattr(course, "in_curriculum", True)
            and int(getattr(course, "semester", 0) or 0) > current_semester
            and str(getattr(course, "code", "")).upper() not in completed
        ]
        if not future:
            return (
                f"### Chưa có môn chưa học sau Học kỳ {current_semester}\n\n"
                "Kho dữ liệu FLM hiện không còn môn thuộc các học kỳ sau để lập kế hoạch."
            )

        dependent_counts = {
            str(getattr(course, "code", "")).upper(): sum(
                1 for other in all_courses.values()
                if str(getattr(course, "code", "")).upper() in {
                    str(item).upper() for item in getattr(other, "prerequisites", [])
                }
            )
            for course in future
        }
        by_semester: Dict[int, List[Any]] = {}
        for course in future:
            by_semester.setdefault(int(getattr(course, "semester", 0) or 0), []).append(course)

        lines = [
            "### Chiến lược học tập cho các học kỳ tiếp theo",
            "",
            f"Dữ liệu đã xác nhận cho thấy bạn đang ở sau **Học kỳ {current_semester}**. "
            "Các môn đã có trong bảng điểm được loại khỏi danh sách ưu tiên.",
        ]
        target = context.get("target_gpa")
        required = context.get("required_avg_mark")
        if target is not None:
            lines.append(f"- **Mục tiêu GPA:** {target:g}/10.")
        if required is not None:
            lines.append(f"- **Mức trung bình cần giữ ở phần tín chỉ còn lại:** khoảng {required:.2f}/10.")

        for semester in sorted(by_semester):
            ranked = []
            for course in by_semester[semester]:
                code = str(getattr(course, "code", ""))
                name = getattr(course, "name_vi", "") or getattr(course, "name_en", "") or code
                credits = max(1, int(getattr(course, "credits", 3) or 3))
                score = float(credits)
                reasons = [f"{credits} tín chỉ"]
                if getattr(course, "has_pe", False):
                    score += 2
                    reasons.append("có PE/thực hành")
                dependents = dependent_counts.get(code.upper(), 0)
                if dependents:
                    score += 1
                    reasons.append(f"mở khóa/ảnh hưởng {dependents} môn sau")
                ranked.append((score, code, name, reasons))
            ranked.sort(key=lambda item: (-item[0], item[1]))
            lines.extend(["", f"**Học kỳ {semester}:**"])
            for index, (_, code, name, reasons) in enumerate(ranked, 1):
                lines.append(f"{index}. **{code} - {name}**: ưu tiên {('; '.join(reasons))}.")
                if index == 1:
                    lines.append("   - Việc cần làm: đọc syllabus, chốt CLO/assessment và tạo sản phẩm hoặc bài luyện đầu tiên trong tuần đầu.")
                elif getattr(all_courses.get(code.upper()), "has_pe", False):
                    lines.append("   - Việc cần làm: luyện phần thực hành từ sớm, lưu lỗi sau mỗi lần làm và không dồn PE vào cuối kỳ.")

        lines.extend([
            "",
            "**Cách theo dõi mục tiêu:** sau mỗi assessment, cập nhật điểm thật và điểm đóng góp theo trọng số; nếu một môn thấp hơn mức cần đạt, điều chỉnh lịch ngay trong kỳ đó.",
            "**Giới hạn dữ liệu:** thứ tự trên dựa trên tín chỉ, PE, tiên quyết và curriculum FLM. Rubric/bài mẫu không có trong syllabus sẽ được đánh dấu thiếu, không tự suy đoán.",
        ])
        return "\n".join(lines)

    @staticmethod
    def _build_subject_strategy(
        course_code: str,
        course_name: str,
        course: Optional[Any],
        retrieved_chunks: List[Tuple[FLMDocumentChunk, float]],
        student_context: Optional[Dict[str, Any]],
    ) -> str:
        """Explain what to focus on from the subject's actual syllabus fields."""
        course = course
        assessment = getattr(course, "assessment_scheme", None) if course else None
        outcomes = getattr(course, "learning_outcomes", None) if course else None
        prerequisites = list(getattr(course, "prerequisites", []) or []) if course else []
        credits = getattr(course, "credits", None) if course else None
        time_allocation = getattr(course, "time_allocation", None) if course else None
        tools = getattr(course, "software_tools", None) if course else None
        has_pe = getattr(course, "has_pe", None) if course else None

        time_allocation = re.sub(r"\*+", "", str(time_allocation or "")).strip() or None
        course_identity = f"{course_code} {course_name}".lower()
        is_math_course = any(word in course_identity for word in [
            "toán", "mathematics", "calculus", "linear algebra", "đại số",
        ])
        is_c_course = any(word in course_identity for word in [
            "cơ sở lập trình", "programming fundamentals", "c language",
        ])
        is_web_course = any(word in course_identity for word in [
            "thiết kế web", "web design", "web development",
        ])

        def clean_markup(value: str) -> str:
            value = re.sub(r"\[\[([^\]|]+)\|([^\]]+)\]\]", r"\2", value)
            value = re.sub(r"\[\[([^\]]+)\]\]", r"\1", value)
            value = re.sub(r"\[([^\]]+)\]\([^\)]+\)", r"\1", value)
            value = value.replace("**", "").replace("`", "").strip(" -*•")
            return re.sub(r"\s+", " ", value).strip()

        def table_lines(value: str, limit: int, assessment: bool = False) -> List[str]:
            result: List[str] = []
            for raw_line in value.splitlines():
                raw_line = raw_line.strip()
                if not raw_line or not raw_line.startswith("|"):
                    continue
                cells = [clean_markup(cell) for cell in raw_line.strip("|").split("|")]
                if len(cells) < 2 or all(set(cell) <= {"-", ":"} for cell in cells if cell):
                    continue
                if any(word in cells[0].lower() for word in ["thành phần", "mã clo", "tiêu chí"]):
                    continue
                if assessment:
                    detail = [cell for cell in cells[1:5] if cell]
                    result.append(f"{cells[0]}: " + "; ".join(detail))
                else:
                    result.append(f"{cells[0]}: {cells[1]}")
                if len(result) >= limit:
                    break
            return result

        def plain_lines(value: str, limit: int) -> List[str]:
            result: List[str] = []
            for raw_line in value.splitlines():
                cleaned = clean_markup(raw_line)
                if not cleaned or cleaned.startswith("|") or cleaned.startswith("---"):
                    continue
                if cleaned not in result:
                    result.append(cleaned)
                if len(result) >= limit:
                    break
            return result

        assessment_lines = table_lines(str(assessment or ""), 8, assessment=True)
        if not assessment_lines:
            assessment_lines = plain_lines(str(assessment or ""), 8)
        outcome_lines = table_lines(str(outcomes or ""), 12)
        if not outcome_lines:
            outcome_lines = plain_lines(str(outcomes or ""), 12)

        # Use retrieved chunks when the parsed CourseDetail has no field for the section.
        if not assessment_lines:
            chunk = next((item for item, _ in retrieved_chunks if item.category == "assessment"), None)
            if chunk:
                assessment_lines = plain_lines(chunk.content, 8)
        if not outcome_lines:
            chunk = next((item for item, _ in retrieved_chunks if item.category == "outcomes"), None)
            if chunk:
                outcome_lines = plain_lines(chunk.content, 8)

        # The schedule is the most useful bridge from a CLO to an actual
        # study task. Group its slot topics by CLO when the source contains it.
        topic_groups: Dict[str, List[str]] = {}
        raw_markdown = (getattr(course, "raw_markdown", "") or "") if course else ""
        for raw_line in raw_markdown.splitlines():
            if not raw_line.strip().startswith("| Slot"):
                continue
            cells = [clean_markup(cell) for cell in raw_line.strip().strip("|").split("|")]
            if len(cells) < 4:
                continue
            topic = re.sub(r"\s*\(cont\.\)", "", cells[1], flags=re.IGNORECASE).strip()
            clo_codes = re.findall(r"CLO\d+", cells[3], flags=re.IGNORECASE)
            clo = ", ".join(dict.fromkeys(code.upper() for code in clo_codes)) or cells[3]
            if any(noise in topic.lower() for noise in ["project review", "project evaluation", "progress test", "course introduction"]):
                continue
            if topic and topic.lower() not in {"chủ đề / nội dung (topic)", "---"}:
                topic_groups.setdefault(clo, [])
                if topic not in topic_groups[clo]:
                    topic_groups[clo].append(topic)

        tool_items = [
            clean_markup(item)
            for item in re.split(r"\s*-\s+", str(tools or ""))
            if clean_markup(item)
        ]

        history = (student_context or {}).get("subject_history", [])
        valid_history = [
            item for item in history
            if isinstance(item, dict) and item.get("score") is not None
        ]
        latest_score = valid_history[-1].get("score") if valid_history else None

        lines = [
            f"### Kế hoạch học môn {course_code} ({course_name})",
            "",
            "**Mục tiêu:** biến đề cương của chính môn này thành các việc có thể làm và kiểm tra được; "
            "không dùng một mẫu PE/FE chung cho mọi môn.",
        ]
        if credits is not None:
            lines.append(f"- Môn này có **{credits} tín chỉ**.")
        if time_allocation:
            lines.append(f"- Phân bổ thời gian theo dữ liệu môn: **{time_allocation}**.")
        if has_pe is not None:
            lines.append(f"- Trạng thái PE theo dữ liệu FLM: **{'Có' if has_pe else 'Không'}**.")
        if latest_score is not None:
            lines.append(f"- Điểm gần nhất trong bảng điểm đã xác nhận: **{latest_score}**.")

        if assessment_lines:
            lines.extend(["", "**Các phần cần tập trung theo cấu trúc đánh giá thực tế:**"])
            lines.extend(f"- {item}" for item in assessment_lines)
        else:
            lines.extend(["", "**Cấu trúc đánh giá:** dữ liệu FLM chưa có đủ chi tiết; cần mở syllabus để xác nhận tỷ trọng từng phần."])

        if outcome_lines:
            lines.extend(["", "**Năng lực cần đạt:**"])
            lines.extend(f"- {item}" for item in outcome_lines)

        if topic_groups:
            lines.extend(["", "**Trọng tâm kỹ thuật theo lịch môn:**"])
            def clo_sort(item: Tuple[str, List[str]]) -> Tuple[int, str]:
                numbers = [int(value) for value in re.findall(r"CLO(\d+)", item[0])]
                return (min(numbers) if numbers else 99, item[0])

            for clo, topics in sorted(topic_groups.items(), key=clo_sort):
                compact_topics = ", ".join(topics[:4])
                lower_topics = compact_topics.lower()
                if "entity framework" in lower_topics or "database" in lower_topics:
                    action = "làm một CRUD có quan hệ bảng, migration, truy vấn LINQ và kiểm tra dữ liệu lỗi"
                elif "wpf" in lower_topics:
                    action = "dựng một màn hình WPF có binding, validation và thao tác CRUD hoàn chỉnh"
                elif any(word in lower_topics for word in ["oop", "generic", "design pattern", "delegate", "linq"]):
                    action = "viết một mini-project C# dùng đúng khái niệm, sau đó giải thích vì sao chọn cách thiết kế đó"
                elif any(word in lower_topics for word in ["stream", "xml", "json"]):
                    action = "làm chức năng đọc/ghi dữ liệu, xử lý lỗi file và test dữ liệu không hợp lệ"
                elif "genai" in lower_topics or "ci/cd" in lower_topics:
                    action = "dùng AI hỗ trợ một task nhưng tự review diff, chạy test và ghi rõ phần đã kiểm chứng"
                elif ".net" in lower_topics or "c#" in lower_topics:
                    action = "tạo một ứng dụng C# nhỏ, chạy được từ đầu đến cuối, rồi giải thích runtime, exception và cách debug"
                elif is_math_course:
                    if any(word in lower_topics for word in ["derivative", "limit", "integral", "calculus"]):
                        action = "tự giải bài theo 4 bước: xác định dạng, chọn định lý/công thức, trình bày biến đổi và kiểm tra kết quả bằng đồ thị hoặc thế ngược"
                    elif any(word in lower_topics for word in ["matrix", "linear", "vector", "subspace"]):
                        action = "làm một bộ bài từ cơ bản đến tổng hợp, ghi rõ phép biến đổi từng dòng và kiểm tra lại bằng thế nghiệm hoặc tính chất ma trận"
                    else:
                        action = "làm bài tập giấy theo từng dạng, tự trình bày đầy đủ bước giải rồi đối chiếu đáp án để ghi lại lỗi sai"
                elif is_c_course:
                    if "pointer" in lower_topics:
                        action = "viết bài đổi giá trị bằng con trỏ, truyền con trỏ vào hàm và cấp phát/giải phóng vùng nhớ; kiểm tra lỗi truy cập"
                    elif "array" in lower_topics or "struct" in lower_topics or "matrix" in lower_topics:
                        action = "làm chương trình quản lý mảng/struct có tìm kiếm, sắp xếp, nhập xuất và kiểm tra dữ liệu biên"
                    elif "string" in lower_topics:
                        action = "làm bài xử lý chuỗi bằng thư viện C, kiểm tra chuỗi rỗng, độ dài và ký tự không hợp lệ"
                    elif "file" in lower_topics:
                        action = "viết chương trình mở, đọc, ghi và đóng file text/binary; kiểm tra trường hợp file không tồn tại"
                    elif "function" in lower_topics or "module" in lower_topics:
                        action = "tách một bài toán thành hàm nhỏ, truyền tham số rõ ràng và viết menu gọi các chức năng"
                    else:
                        action = "viết một chương trình C nhỏ có input, xử lý, output; tự kiểm tra bằng dữ liệu đúng, biên và sai"
                elif is_web_course:
                    if "html" in lower_topics or "dom" in lower_topics:
                        action = "dựng một trang HTML5 semantic có heading, link, ảnh, bảng và kiểm tra accessibility"
                    elif "css" in lower_topics or "styling" in lower_topics:
                        action = "tạo layout bằng CSS, dùng pseudo-class/transition và kiểm tra trên màn hình hẹp"
                    elif "javascript" in lower_topics or "form" in lower_topics:
                        action = "làm tương tác JavaScript và validation form, kiểm tra cả dữ liệu hợp lệ lẫn dữ liệu lỗi"
                    elif "responsive" in lower_topics or "framework" in lower_topics:
                        action = "chuyển trang sang responsive, thử nhiều viewport và ghi lại lỗi bố cục đã sửa"
                    elif "capstone" in lower_topics or "coding phase" in lower_topics:
                        action = "hoàn thành một website nhỏ từ design đến coding, validation và review theo checklist"
                    else:
                        action = "tạo một trang web nhỏ đúng chủ đề của buổi học và kiểm tra bằng sản phẩm chạy được"
                else:
                    action = "chưa có hướng dẫn thực hành riêng trong dữ liệu syllabus; cần bổ sung rubric hoặc bài mẫu của môn"
                lines.append(f"- **{clo}:** {compact_topics}. Bài phải làm: {action}.")

        if assessment_lines:
            lines.extend(["", "**Kế hoạch theo từng thành phần đánh giá:**"])
            for item in assessment_lines:
                lower_item = item.lower()
                if any(token in lower_item for token in ["practical", "pe", "workshop"]):
                    action = "luyện đúng dạng bài trong thời lượng ghi ở assessment và lưu lại lỗi sau mỗi lần làm"
                elif any(token in lower_item for token in ["assignment", "project", "lab"]):
                    action = "tạo sản phẩm nộp được, chạy qua checklist yêu cầu và hoàn thiện trước hạn"
                elif any(token in lower_item for token in ["progress", "quiz", "theoretical", "final", "te"]):
                    action = "lập bộ câu hỏi theo CLO liên quan, làm thử có giới hạn thời gian và kiểm tra đáp án"
                else:
                    action = "đối chiếu rubric của thành phần này với một sản phẩm hoặc bài làm cụ thể"
                lines.append(f"- {item} → {action}.")
        if time_allocation:
            lines.extend(["", f"**Dữ liệu thời lượng của môn:** {time_allocation}."])
        if not topic_groups and not assessment_lines:
            lines.extend(["", "Syllabus hiện chưa có đủ topic và assessment để lập kế hoạch hành động; không tự thêm lời khuyên chung."])

        if assessment_lines or outcome_lines or topic_groups:
            lines.extend([
                "",
                "**Cách học theo thứ tự ưu tiên:**",
                "- Bắt đầu từ thành phần assessment có tỷ trọng cao nhất và đối chiếu trực tiếp với CLO/topic của môn; mỗi phần phải tạo ra một bài làm hoặc sản phẩm kiểm tra được.",
                "- Sau mỗi lần luyện, lưu lỗi sai và chấm lại theo đúng tiêu chí đang có trong syllabus; không coi việc đọc lại lý thuyết là đã hoàn thành.",
                "",
                "**Lịch thực hiện gợi ý:**",
                "- Buổi 1: chốt CLO, topic và tỷ trọng assessment của chính môn này.",
                "- Buổi 2: làm bài thực hành/sản phẩm cho topic ưu tiên cao nhất.",
                "- Buổi 3: làm bài tổng hợp có giới hạn thời gian theo PE/FE hoặc assessment đã xác định.",
                "- Buổi 4: sửa lỗi, tự chấm và chuyển phần chưa đạt thành việc tuần kế tiếp.",
            ])

        if prerequisites:
            lines.extend(["", f"**Môn tiên quyết cần rà lại trước:** {', '.join(prerequisites)}."])
            history = (student_context or {}).get("subject_history", [])
            weak = {
                str(item.get("course_code", item.get("code", ""))).upper()
                for item in history
                if isinstance(item, dict) and float(item.get("score", 10)) < 5
            }
            missing = [code for code in prerequisites if code.upper() not in {str(item.get('code', '')).upper() for item in history if isinstance(item, dict)}]
            if weak:
                lines.append(f"- Bảng điểm đang có môn tiên quyết chưa đạt cần ôn lại: **{', '.join(sorted(weak))}**.")
            if missing:
                lines.append(f"- Chưa thấy lịch sử điểm của: **{', '.join(missing)}**; hãy kiểm tra trước khi học phần nâng cao.")

        lines.extend(["", "**Việc nên làm ngay:**"])
        if has_pe:
            lines.append("- Dựng một bài luyện sát dạng PE trong syllabus, tự làm có bấm giờ, lưu sản phẩm và ghi lại lỗi sau mỗi lần thử.")
        else:
            lines.append("- Chia các learning outcome thành từng chủ đề, tạo dàn ý trả lời/bài tập tương ứng và đối chiếu với từng thành phần đánh giá ở trên.")
        if tool_items:
            lines.append("- Chuẩn bị đúng công cụ theo syllabus: **" + ", ".join(tool_items[:8]) + "**.")
        lines.append("- Sau mỗi tuần, đối chiếu sản phẩm hoặc bài làm với learning outcome; phần nào chưa chứng minh được thì đưa vào lịch tuần kế tiếp.")
        return "\n".join(lines)

    @staticmethod
    def _extract_target_mark(question: str) -> Optional[float]:
        """Read an explicit 0-10 course target without inventing one."""
        patterns = [
            r"(?:mục tiêu|muốn|đạt|được|lên)\s*(?:điểm\s*)?(\d+(?:[\.,]\d+)?)",
            r"(?:điểm|mark|score)\s*(?:mục tiêu)?\s*(?:là|được|khoảng)?\s*(\d+(?:[\.,]\d+)?)",
        ]
        for pattern in patterns:
            match = re.search(pattern, question.lower())
            if match:
                value = float(match.group(1).replace(",", "."))
                if 0 <= value <= 10:
                    return value
        if any(token in question.lower() for token in ["môn này", "môn đó", "môn nay", "điểm môn", "course", "ra trường", "gpa", "tốt nghiệp"]):
            explicit_scores = re.findall(r"(?<![A-Za-z0-9])(10(?:[\.,]0+)?|[0-9](?:[\.,][0-9]+)?)(?![A-Za-z0-9])", question)
            if len(explicit_scores) == 1:
                value = float(explicit_scores[0].replace(",", "."))
                if 0 <= value <= 10:
                    return value
        return None

    @staticmethod
    def _build_subject_grade_strategy(
        course_code: str,
        course_name: str,
        course: Optional[Any],
        target_mark: float,
        student_context: Optional[Dict[str, Any]],
    ) -> str:
        """Turn a course mark target into a weighted, evidence-backed plan."""
        assessment = str(getattr(course, "assessment_scheme", None) or "") if course else ""
        weights = []
        for line in assessment.splitlines():
            match = re.search(r"(.+?)[\s:()\-]+(\d+(?:[\.,]\d+)?)\s*%", line)
            if match:
                label = re.sub(r"[*|`]", "", match.group(1)).strip(" -:")
                weight = float(match.group(2).replace(",", "."))
                if label and weight > 0:
                    weights.append((label, weight))

        history = (student_context or {}).get("subject_history", [])
        previous = next(
            (item.get("score") for item in reversed(history)
             if isinstance(item, dict)
             and str(item.get("course_code", item.get("code", ""))).upper() == course_code.upper()
             and item.get("score") is not None),
            None,
        )
        lines = [
            f"### Kế hoạch đạt {target_mark:g}/10 môn {course_code} ({course_name})",
            "",
            f"Mục tiêu đã nhận: **{target_mark:g}/10**. Đây là mục tiêu cho riêng môn này, không phải GPA tốt nghiệp.",
        ]
        if previous is not None:
            lines.append(f"- Điểm gần nhất trong bảng điểm đã xác nhận: **{previous}**.")
        else:
            lines.append("- Chưa có điểm lịch sử của môn này; hệ thống không tự đoán điểm hiện tại.")

        if not weights:
            lines.extend([
                "",
                "### Chưa thể tính phân bổ điểm theo thành phần",
                f"Syllabus hiện chưa có rubric hoặc tỷ trọng assessment đủ chi tiết. Vì vậy chưa thể nói PE, FE, quiz hay lab cần bao nhiêu điểm để đạt mục tiêu **{target_mark:g}**.",
                "",
                "Việc cần bổ sung: rubric chính thức, đề mẫu hoặc bảng tỷ trọng từng thành phần của môn. Khi có dữ liệu đó, hệ thống sẽ tính ngược điểm tối thiểu cho từng phần thay vì đưa lời khuyên chung.",
            ])
            return "\n".join(lines)

        total_weight = sum(weight for _, weight in weights)
        lines.extend(["", "**Phân bổ mục tiêu theo assessment đã có:**"])
        for label, weight in weights:
            contribution = target_mark * weight / total_weight
            lines.append(
                f"- **{label} ({weight:g}%)**: phần này đóng góp tối đa theo trọng số; để giữ mục tiêu {target_mark:g}, cần hướng tới khoảng **{target_mark:g}/10** ở phần này, tương đương **{contribution:.2f} điểm** vào tổng môn."
            )
        highest = max(weights, key=lambda item: item[1])
        lines.extend([
            "",
            f"**Ưu tiên:** tập trung trước vào **{highest[0]} ({highest[1]:g}%)** vì đây là thành phần ảnh hưởng lớn nhất đến điểm cuối.",
            "",
            "**Cách kiểm tra tiến độ:** sau mỗi bài/assessment, ghi điểm thực tế và tính `điểm đã đóng góp = điểm thành phần × trọng số`; nếu tổng dự kiến thấp hơn mục tiêu thì điều chỉnh phần còn lại, không chờ đến FE mới phát hiện.",
            "",
            "**Giới hạn dữ liệu:** kế hoạch này chỉ dùng tỷ trọng syllabus. Nó không khẳng định đề thi hay rubric chi tiết nếu FLM chưa cung cấp.",
        ])
        return "\n".join(lines)

    def _synthesize_advanced_response(
        self,
        question: str,
        retrieved_chunks: List[Tuple[FLMDocumentChunk, float]],
        detected_courses: List[str],
        scope: Optional[str] = None,
        scope_id: Optional[str] = None,
        student_context: Optional[Dict[str, Any]] = None,
        all_courses: Optional[Dict[str, Any]] = None,
        curriculum_info: Optional[Dict[str, Any]] = None,
        detected_intents: Optional[List[str]] = None,
    ) -> str:
        """
        Advanced Contextual Synthesis Engine:
        Produces natural, high-clarity Vietnamese responses with concrete actionable steps.
        Adheres to requirements in v7 (Mục 5.1, 5.2, 5.3, 5.4, 7.4).
        """
        q_lower = question.lower()
        detected_intents = detected_intents or []
        # Course identifiers in the vault contain mixed casing (for example
        # WED201c), while detection normalizes them to uppercase. Keep one
        # canonical lookup map so retrieval and structured metadata cannot mix
        # two different courses.
        all_courses = {
            str(code).upper(): course
            for code, course in (all_courses or {}).items()
        }

        # -------------------------------------------------------------
        # Filter 1: Check Out-Of-Scope topics (Mục 5.4)
        # -------------------------------------------------------------
        out_of_scope_keywords = [
            "nấu ăn", "nấu nướng", "làm bánh", "bếp", "thời tiết", "chứng khoán",
            "bất động sản", "du lịch", "bơi lội", "bóng đá", "cầu lông", "ca nhạc"
        ]
        if any(w in q_lower for w in out_of_scope_keywords):
            return (
                "Hệ thống FLM FPT University không tìm thấy thông tin hoặc đề cương môn học này trong cơ sở dữ liệu chương trình đào tạo. "
                "Hệ thống chỉ giải đáp các thông tin chính thức về chương trình khung, đề cương môn học (Syllabus), hình thức thi PE/FE, chuẩn đầu ra (LOs) và tư vấn học tập cho sinh viên FPTU."
            )

        # Resolve semester strategy before course-level retrieval can pull an unrelated subject.
        # A missing semester is reported explicitly instead of defaulting to HK5.
        semester_advice_requested = "strategy_advisor" in detected_intents or any(k in q_lower for k in [
            "kỳ này", "học kỳ này", "học như nào", "học thế nào", "nên học môn nào",
            "ưu tiên môn nào", "phân bổ thời gian", "chiến lược học kỳ", "chiến lược học tập",
        ]) or bool(re.search(r"(?:học kỳ|kỳ|hk)\s*\d+.*(?:học|ưu tiên|chiến lược|phân bổ|thời gian)", q_lower))
        known_course_targets = {str(code).upper() for code in all_courses}
        has_known_course_target = any(str(code).upper() in known_course_targets for code in detected_courses)
        course_target = scope_id if scope == "subject" else (detected_courses[0] if has_known_course_target else None)
        target_mark = self._extract_target_mark(question)
        if target_mark is not None and course_target and str(course_target).upper() in all_courses:
            course = all_courses[str(course_target).upper()]
            return self._build_subject_grade_strategy(
                course_code=str(course_target).upper(),
                course_name=getattr(course, "name_vi", "") or getattr(course, "name_en", "") or str(course_target).upper(),
                course=course,
                target_mark=target_mark,
                student_context=student_context,
            )
        future_semesters_requested = any(token in q_lower for token in [
            "các kỳ tiếp theo", "các học kỳ tiếp theo", "học kỳ sau", "kỳ sau",
            "từ giờ đến cuối", "những kỳ còn lại", "các kỳ còn lại",
        ])
        if future_semesters_requested and scope != "subject":
            return self._build_future_semesters_strategy(all_courses, student_context)
        if semester_advice_requested and scope != "subject" and not has_known_course_target:
            return self._build_semester_strategy(question, all_courses, student_context)

        # -------------------------------------------------------------
        # Filter 2: GPA Rules, Retake Policy, Graduation Honors (Mục 6)
        # -------------------------------------------------------------
        if any(k in q_lower for k in ["hạ bậc", "hạ bằng", "học lại", "tính gpa", "không tính gpa", "cải thiện điểm", "xếp loại tốt nghiệp"]) and not any(k in q_lower for k in ["muốn ra trường", "gpa hiện tại", "cần làm gì", "mục tiêu"]):
            return (
                "### Quy định xếp loại tốt nghiệp và học lại theo Quy chế Đào tạo\n\n"
                "**1. Danh sách môn không tính vào điểm GPA:**\n"
                "Các mã môn bắt đầu bằng hoặc trùng với: GDQP, ENT, VOV, TRS, DSA, LAB, OJS, OJT, SYB301. "
                "Các môn này không ảnh hưởng đến điểm GPA trung bình nhưng sinh viên bắt buộc phải đạt để đủ điều kiện xét tốt nghiệp.\n\n"
                "**2. Quy định hạ bậc tốt nghiệp do học lại:**\n"
                "- Nếu sinh viên học lại từ 2 môn trở lên (tính cả các môn không tính GPA như VOV/LAB/GDQP nếu đã từng rớt), "
                "xếp loại tốt nghiệp loại Giỏi hoặc Xuất sắc sẽ bị hạ 1 bậc (Xuất sắc hạ xuống Giỏi, Giỏi hạ xuống Khá).\n"
                "- Xếp loại Khá và Trung bình không bị ảnh hưởng.\n\n"
                "**3. Phân biệt học lại và học cải thiện điểm:**\n"
                "- Học lại: Các lần học trước đó đã bị trượt (rớt môn). Trường hợp này được tính vào số lần học lại để xét hạ bậc.\n"
                "- Học cải thiện điểm: Lần học trước đã đạt (pass) nhưng học lại để nâng cao điểm số. Trường hợp này không tính là học lại và không gây hạ bậc tốt nghiệp.\n\n"
                "**4. Điểm GPA tốt nghiệp:**\n"
                "Chỉ lấy điểm của lần học cuối cùng của từng môn để tính vào GPA chung."
            )

        # -------------------------------------------------------------
        # Filter 3: Academic Advising & Goal Strategy (Mục 5.3, 7.3, 7.4)
        # -------------------------------------------------------------
        subject_learning_question = scope == "subject" and ("strategy_advisor" in detected_intents or any(k in q_lower for k in [
            "cách học", "học thế nào", "học như thế nào", "ôn thi", "ôn tập",
            "làm sao để qua", "làm sao để pass", "đạt điểm cao", "học tốt",
            "kế hoạch học", "kế hoạch học tập", "lộ trình học",
        ]))
        if not subject_learning_question and ("grade_goal" in detected_intents or (student_context and ("gpa" in q_lower or "mục tiêu" in q_lower or "chiến lược" in q_lower or "tư vấn" in q_lower)) or any(k in q_lower for k in ["muốn ra trường", "muốn đạt", "gpa hiện tại", "cần làm gì từ giờ đến cuối", "lên 8."])):
            ctx = student_context or {}
            
            # Extract numbers only when they come from the local transcript facts or
            # are explicitly written by the user. Never invent a default GPA.
            cur_gpa = ctx.get("current_gpa")
            if cur_gpa is None:
                gpa_m = re.search(r"gpa.*?(\d+[\.,]\d+)", q_lower)
                cur_gpa = float(gpa_m.group(1).replace(",", ".")) if gpa_m else None

            tgt_gpa = ctx.get("target_gpa")
            if tgt_gpa is None:
                tgt_m = re.search(r"(?:ra trường|lên|mục tiêu).*?(\d+[\.,]\d+)", q_lower)
                tgt_gpa = float(tgt_m.group(1).replace(",", ".")) if tgt_m else None
            if tgt_gpa is None and any(token in q_lower for token in ["ra trường", "gpa", "tốt nghiệp"]):
                tgt_gpa = self._extract_target_mark(question)

            if tgt_gpa is None:
                return (
                    "### Cần thêm dữ liệu để lập chiến lược GPA\n\n"
                    "Mình chưa có mục tiêu GPA cụ thể nên chưa thể tính lộ trình điểm số. "
                    "Hãy cho biết GPA mục tiêu (ví dụ: 8.0) và xác nhận bảng điểm đã import nếu muốn phân tích theo từng môn."
                )

            req_avg = ctx.get("required_avg_mark")
            if req_avg is None and cur_gpa is not None:
                req_avg = round(tgt_gpa + (tgt_gpa - cur_gpa) * 0.8, 2)
            retake_cnt = ctx.get("retake_count", 0)
            is_feasible = ctx.get("is_target_feasible") if req_avg is not None else None
            if is_feasible is None and req_avg is not None:
                is_feasible = req_avg <= 10.0

            lines = [
                f"### Kế hoạch chiến lược học tập nâng điểm GPA lên {tgt_gpa:g}",
                "",
                f"- **Mục tiêu tốt nghiệp:** GPA **{tgt_gpa:g}**.",
            ]
            if cur_gpa is not None:
                lines.insert(2, f"- **GPA hiện tại:** **{cur_gpa}** (lấy từ bảng điểm đã xác nhận).")
            else:
                lines.append("- **GPA hiện tại:** chưa có dữ liệu bảng điểm đã xác nhận, nên mình không tự đoán con số này.")
            if is_feasible is True:
                lines.append(f"- **Điểm số cần đạt:** Để đạt mục tiêu, sinh viên cần duy trì điểm trung bình các môn học còn lại tối thiểu từ **{req_avg:.2f}/10**.")
            elif is_feasible is False:
                lines.append(f"- **Cảnh báo tính khả thi:** Điểm trung bình cần đạt ở các môn còn lại vượt quá 10.0, mục tiêu GPA {tgt_gpa:g} về mặt toán học không khả thi. Bạn nên đặt mục tiêu điều chỉnh thực tế hơn.")
            else:
                lines.append("- **Điểm số cần đạt:** Chưa thể tính vì chưa có GPA và tín chỉ còn lại từ bảng điểm.")

            lines.extend([
                "",
                "**1. Phân bổ chiến lược và ưu tiên môn học:**",
                "- Ưu tiên các môn trong curriculum có nhiều tín chỉ, có PE hoặc là tiên quyết cho môn sau; danh sách cụ thể cần lấy từ curriculum đang mở.",
                "",
                "**2. Lưu ý quan trọng về quy chế học lại & cải thiện điểm:**",
            ])
            if retake_cnt >= 1:
                lines.append(f"- Bạn đã có **{retake_cnt} môn học lại**. Quy chế FPTU quy định nếu học lại từ 2 môn trở lên (kể cả môn không tính GPA như VOV/GDQP), bằng Giỏi sẽ bị hạ 1 bậc xuống Khá. Tuyệt đối không được để trượt thêm môn nào.")
            else:
                lines.append("- Tuyệt đối không để trượt môn nào từ nay đến cuối khóa. Nếu học lại từ 2 môn trở lên (kể cả môn điều kiện như VOV/GDQP/LAB), bằng Giỏi sẽ bị hạ xuống Khá.")

            lines.extend([
                "- Nếu có các môn chuyên ngành 3 tín chỉ ở các kỳ trước bị điểm thấp (5.0 - 5.5), bạn có thể đăng ký **học cải thiện điểm**. Học cải thiện điểm không bị tính là học lại và không gây hạ bậc tốt nghiệp.",
                "",
                "**3. Hành động đề xuất:**",
                "- Lên lịch ôn tập kỹ phần thi thực hành PE cho các môn lập trình, hoàn thành bài tập lớn trước hạn để đạt điểm quá trình tối đa."
            ])
            if not student_context:
                lines.append("\n*Gợi ý: Hãy tải ảnh bảng điểm của bạn lên hệ thống để AI có thể phân tích chính xác từng môn cụ thể.*")
            return "\n".join(lines)

        # -------------------------------------------------------------
        # Filter 4: Semester Workload & Course Prioritization (Mục 5.3)
        # -------------------------------------------------------------
        # Keep this path backed by the same structured planner. There is no
        # hard-coded HK5 fallback, even when retrieval detected a course token.
        if scope != "subject" and self._target_semester(question, student_context) is not None:
            return self._build_semester_strategy(question, all_courses, student_context)

        # -------------------------------------------------------------
        # Filter 5: Semester Credits & Course List Query (Mục 5.1)
        # -------------------------------------------------------------
        sem_credits_match = re.search(r"(?:hk|học kỳ|kỳ)\s*(\d+).*?(?:mấy tín|bao nhiêu tín|tín chỉ|môn nào|bao nhiêu môn)", q_lower)
        if sem_credits_match:
            target_sem = int(sem_credits_match.group(1))
            courses_in_sem = [
                c for c in all_courses.values()
                if getattr(c, "semester", 0) == target_sem and getattr(c, "in_curriculum", True)
            ]
            codes = [c.code for c in courses_in_sem]
            tot_credits = sum(c.credits for c in courses_in_sem)


            course_items = []
            for cd in codes:
                c_obj = all_courses.get(cd)
                c_name = c_obj.name_vi if c_obj and c_obj.name_vi else (c_obj.name_en if c_obj else "")
                cr = c_obj.credits if c_obj else 0
                course_items.append(f"- **{cd}**: {c_name} ({cr} tín chỉ)")

            return (
                f"### Thống kê Học kỳ {target_sem} — Chương trình BIT_SE_K19B\n\n"
                f"- **Số lượng môn học:** {len(codes)} môn\n"
                f"- **Tổng số tín chỉ:** {tot_credits} tín chỉ\n\n"
                f"**Danh sách các môn học:**\n" + "\n".join(course_items)
            )

        # -------------------------------------------------------------
        # Filter 6: Curriculum Overview / Total Credits / Semesters
        # -------------------------------------------------------------
        if any(k in q_lower for k in ["bao nhiêu tín chỉ của chương trình", "tổng số tín chỉ của chương trình", "chương trình có bao nhiêu môn", "bao nhiêu học kỳ"]):
            curr_name = curriculum_info.get("name_vi", "Kỹ thuật Phần mềm (BIT_SE_K19B)")
            total_cr = curriculum_info.get("total_credits", 145)
            return (
                f"### Thông tin tổng quan chương trình đào tạo {curr_name}\n\n"
                f"- **Tổng số tín chỉ xét tốt nghiệp:** {total_cr} tín chỉ tích lũy.\n"
                f"- **Số học kỳ chính thức:** 9 học kỳ chuyên ngành (Học kỳ 1 đến Học kỳ 9) và 1 giai đoạn chuẩn bị (Học kỳ 0).\n"
                f"- **Tổng số môn học:** Khoảng 48 đến 52 môn học (bao gồm các môn chuyên ngành, đồ án thực tế và môn điều kiện)."
            )

        # -------------------------------------------------------------
        # Filter 7: Course Presence Query (Mục 5.2)
        # -------------------------------------------------------------
        if any(k in q_lower for k in ["xuất hiện trong", "thuộc kỳ nào", "học ở kỳ mấy", "kỳ mấy học", "ở kỳ nào"]):
            # Identify course code
            target = scope_id or (detected_courses[0] if detected_courses else None)
            if not target and retrieved_chunks:
                target = retrieved_chunks[0][0].course_code

            c_obj = all_courses.get(target.upper()) if target else None
            if c_obj:
                appears = getattr(c_obj, "appears_in", [])
                if not appears:
                    appears = [{"curriculum": getattr(c_obj, "curriculum", "BIT_SE_K19B"), "semester": getattr(c_obj, "semester", 0)}]

                appears_lines = [f"- Khung chương trình **{a.get('curriculum')}**: Học kỳ **{a.get('semester')}**" for a in appears]
                return (
                    f"### Thông tin xuất hiện trong chương trình đào tạo của môn {c_obj.code} ({c_obj.name_vi or c_obj.name_en})\n\n"
                    f"Theo dữ liệu FLM, môn **{c_obj.code}** có lộ trình đào tạo:\n" + "\n".join(appears_lines)
                )

        # -------------------------------------------------------------
        # Filter 8: Handling Single Course with Retrieved Context
        # -------------------------------------------------------------
        target = scope_id or (detected_courses[0] if detected_courses else "")
        subject_learning_question = scope == "subject" and ("strategy_advisor" in detected_intents or "grade_goal" in detected_intents or any(k in q_lower for k in [
            "tư vấn", "cách học", "làm sao để qua", "làm sao để pass", "học thế nào",
            "học như thế nào", "ôn thi", "ôn tập", "bí kíp", "chiến lược", "kinh nghiệm",
            "đạt điểm cao", "học tốt", "kế hoạch học", "kế hoạch học tập", "lộ trình học",
        ]))
        if not retrieved_chunks and subject_learning_question and target.upper() in all_courses:
            course = all_courses[target.upper()]
            return self._build_subject_strategy(
                course_code=target.upper(),
                course_name=getattr(course, "name_vi", "") or getattr(course, "name_en", "") or target.upper(),
                course=course,
                retrieved_chunks=[],
                student_context=student_context,
            )

        if not retrieved_chunks:
            if target and target.upper() in all_courses:
                c = all_courses[target.upper()]
                return f"Môn **{c.code}** ({c.name_vi or c.name_en}) có thời lượng {c.credits} tín chỉ, học tại Học kỳ {c.semester}."
            return (
                "Hệ thống FLM FPT University không tìm thấy thông tin phù hợp trong kho dữ liệu FLM. "
                "Bạn có thể đặt câu hỏi về mã môn cụ thể (ví dụ: PRM393, SWD392, CSD201, PRO192) hoặc số tín chỉ, hình thức thi PE/FE, chuẩn đầu ra (LOs)."
            )

        top_chunk, _ = retrieved_chunks[0]
        course_code = top_chunk.course_code or scope_id or "Môn học"
        course_name = top_chunk.course_name

        # If scope is subject, ensure course_code aligns with active subject scope
        if scope == "subject" and scope_id:
            course_code = scope_id.upper()
            if course_code in all_courses:
                course_name = all_courses[course_code].name_vi or all_courses[course_code].name_en

        # Case A: Strategy Advising / How to pass / Exam Prep for specific course
        if "strategy_advisor" in detected_intents or "grade_goal" in detected_intents or any(k in q_lower for k in [
            "tư vấn", "cách học", "làm sao để qua", "làm sao để pass", "học thế nào",
            "học như thế nào", "ôn thi", "ôn tập", "bí kíp", "chiến lược", "kinh nghiệm",
            "đạt điểm cao", "học tốt", "kế hoạch học", "kế hoạch học tập", "lộ trình học"
        ]):
            return self._build_subject_strategy(
                course_code=course_code,
                course_name=course_name,
                course=all_courses.get(course_code.upper()),
                retrieved_chunks=retrieved_chunks,
                student_context=student_context,
            )

        # Case B: Assessment / PE / FE / Grading
        if any(k in q_lower for k in ["pe", "practical exam", "thi", "fe", "final exam", "đánh giá", "hình thức", "kiểm tra", "trọng số"]):
            assessment_chunk = next((c for c, _ in retrieved_chunks if c.category == "assessment"), None)
            assess_text = assessment_chunk.content if assessment_chunk else top_chunk.content
            has_pe_meta = assessment_chunk.metadata.get("has_pe") if assessment_chunk else None
            if has_pe_meta is None:
                has_pe_meta = top_chunk.metadata.get("has_pe")
            has_pe = bool(has_pe_meta) if has_pe_meta is not None else ("practical exam" in assess_text.lower())

            pe_status = "có hình thức thi thực hành PE (Practical Exam)" if has_pe else "không có hình thức thi thực hành PE"

            lines = [
                f"### Cấu trúc đánh giá và hình thức thi môn {course_code} ({course_name})",
                "",
                f"Theo đề cương FLM, môn {course_code} {pe_status}.",
                "",
                "Chi tiết các thành phần đánh giá:",
            ]
            if assessment_chunk:
                for line in assessment_chunk.content.split("\n"):
                    l = line.strip()
                    if l and not l.startswith("#") and "cấu trúc đánh giá" not in l.lower():
                        lines.append(f"- {l.lstrip('-*• ')}")
            else:
                lines.append(f"- Môn học áp dụng thang điểm 10 với các bài kiểm tra quá trình, bài thực hành và bài thi cuối kỳ theo quy chuẩn FLM.")

            return "\n".join(lines)

        # Case C: Learning Outcomes / LOs
        if any(k in q_lower for k in ["mục tiêu", "lo", "los", "clo", "clos", "plo", "learning outcome", "chuẩn đầu ra"]):
            outcomes_chunk = next((c for c, _ in retrieved_chunks if c.category == "outcomes"), None)

            lines = [
                f"### Chuẩn đầu ra và mục tiêu môn học {course_code} ({course_name})",
                "",
                f"Sau khi hoàn thành môn {course_code}, sinh viên sẽ đạt được các năng lực:",
                "",
            ]
            if outcomes_chunk:
                for line in outcomes_chunk.content.split("\n"):
                    l = line.strip()
                    if l and not l.startswith("#") and "mục tiêu" not in l.lower():
                        lines.append(f"- {l.lstrip('-*• ')}")
            else:
                lines.append(f"- Nắm vững kiến thức chuyên môn và kỹ năng thực hành theo chuẩn đào tạo FLM của môn {course_code}.")

            return "\n".join(lines)

        # Case D: Credits / Số tín chỉ
        if any(k in q_lower for k in ["tín chỉ", "credit", "credits", "mấy tín", "bao nhiêu tín"]):
            # Get actual credit from all_courses if available
            c_data = all_courses.get(course_code.upper())
            credits_val = c_data.credits if c_data else top_chunk.metadata.get("credits", 3)
            semester_val = c_data.semester if c_data else top_chunk.metadata.get("semester", 0)

            lines = [
                f"### Số tín chỉ môn học {course_code} ({course_name})",
                "",
                f"- Trong chương trình đào tạo, môn {course_code} có **{credits_val}** tín chỉ.",
            ]
            if semester_val:
                lines.append(f"- Môn học được đề xuất học tại Học kỳ {semester_val}.")
            return "\n".join(lines)

        # Case E: Semester / Prerequisites / Roadmap
        if any(k in q_lower for k in ["học kỳ", "kỳ mấy", "semester", "tiên quyết", "prerequisite", "mở khóa"]):
            c_data = all_courses.get(course_code.upper())
            semester_val = c_data.semester if c_data else top_chunk.metadata.get("semester", 0)
            prereqs = c_data.prerequisites if c_data else top_chunk.metadata.get("prerequisites", [])
            unlocks = c_data.unlocks if c_data else top_chunk.metadata.get("unlocks", [])

            lines = [
                f"### Kế hoạch học tập và lộ trình môn {course_code} ({course_name})",
                "",
                f"- Học kỳ đề xuất: Học kỳ **{semester_val}**.",
            ]
            if prereqs:
                lines.append(f"- Điều kiện tiên quyết: Cần hoàn thành {', '.join(prereqs)} trước khi học môn này.")
            else:
                lines.append("- Điều kiện tiên quyết: Không có môn ràng buộc tiên quyết.")

            if unlocks:
                lines.append(f"- Môn học kế tiếp mở khóa: {', '.join(unlocks)}.")

            return "\n".join(lines)

        # Case F: General Overview
        return self._build_course_overview(
            course_code,
            course_name,
            all_courses.get(course_code.upper()),
            top_chunk,
        )

    @staticmethod
    def _build_course_overview(
        course_code: str,
        course_name: str,
        course: Optional[Any],
        top_chunk: FLMDocumentChunk,
    ) -> str:
        """Render structured course data instead of leaking Obsidian Markdown."""
        def clean(value: str) -> str:
            value = re.sub(r"\[\[([^\]|]+)\|([^\]]+)\]\]", r"\2", value)
            value = re.sub(r"\[\[([^\]]+)\]\]", r"\1", value)
            value = re.sub(r"\[([^\]]+)\]\([^\)]+\)", r"\1", value)
            return value.replace("**", "").replace("`", "").strip()

        if course is None:
            return (
                f"### Thông tin môn học {course_code} ({course_name})\n\n"
                f"{clean(top_chunk.content)}\n\n"
                "Bạn có thể hỏi tiếp về CLO, assessment, điều kiện tiên quyết hoặc cách học môn này."
            )

        lines = [
            f"### Thông tin môn học {course.code} ({course.name_vi or course.name_en})",
            "",
            f"- **Tín chỉ:** {course.credits}",
            f"- **Học kỳ đề xuất:** Học kỳ {course.semester}",
            f"- **PE:** {'Có' if course.has_pe else 'Không'}",
            f"- **Tính GPA:** {'Có' if course.counts_in_gpa else 'Không'}",
        ]
        if course.prerequisites:
            lines.append(f"- **Tiên quyết:** {', '.join(course.prerequisites)}")
        else:
            lines.append("- **Tiên quyết:** Không có")
        if course.unlocks:
            lines.append(f"- **Môn mở khóa tiếp theo:** {', '.join(course.unlocks)}")
        if course.appears_in:
            locations = ", ".join(
                f"{item.get('curriculum', 'chương trình')} - Học kỳ {item.get('semester', course.semester)}"
                for item in course.appears_in
            )
            lines.append(f"- **Có trong:** {locations}")
        lines.append("")
        lines.append("Đặt câu hỏi cụ thể để xem cấu trúc đánh giá, CLO hoặc kế hoạch học theo syllabus của môn này.")
        return "\n".join(lines)

    # ─── Vision API (Gemini multimodal) ────────────────────────────────────────

    async def call_vision(
        self,
        system_prompt: str,
        image_b64: str,
        mime_type: str = "image/jpeg",
    ) -> str:
        """
        Gọi Gemini Vision (gemini-1.5-flash hoặc gemini-2.0-flash) với 1 ảnh base64.
        Dùng cho import-grade endpoint để OCR bảng điểm.
        Fallback: trả về chuỗi JSON rỗng nếu không có API key.
        """
        if not settings.GEMINI_API_KEY and not settings.OPENAI_API_KEY:
            raise RuntimeError("Chưa cấu hình GEMINI_API_KEY hoặc OPENAI_API_KEY để đọc ảnh bảng điểm.")

        if not settings.GEMINI_API_KEY and settings.OPENAI_API_KEY:
            url = f"{settings.OPENAI_BASE_URL.rstrip('/')}/chat/completions"
            response = await self.http_client.post(
                url,
                headers={"Authorization": f"Bearer {settings.OPENAI_API_KEY}"},
                json={
                    "model": settings.OPENAI_MODEL,
                    "temperature": 0,
                    "max_tokens": 4096,
                    "messages": [{
                        "role": "user",
                        "content": [
                            {"type": "text", "text": system_prompt},
                            {"type": "image_url", "image_url": {"url": f"data:{mime_type};base64,{image_b64}"}},
                        ],
                    }],
                },
                timeout=60.0,
            )
            response.raise_for_status()
            data = response.json()
            try:
                return data["choices"][0]["message"]["content"]
            except (KeyError, IndexError) as exc:
                raise RuntimeError(f"OpenAI Vision trả về định dạng không mong đợi: {data}") from exc

        payload = {
            "contents": [
                {
                    "parts": [
                        {"text": system_prompt},
                        {
                            "inline_data": {
                                "mime_type": mime_type,
                                "data": image_b64,
                            }
                        },
                    ]
                }
            ],
            "generationConfig": {
                "temperature": 0.1,
                "maxOutputTokens": 4096,
            },
        }

        # Models can be retired or unavailable for a particular API key. Try
        # the configured model first, then a currently supported Flash model.
        configured = settings.GEMINI_MODEL.replace("models/", "").strip()
        candidates = list(dict.fromkeys([configured, "gemini-2.5-flash", "gemini-flash-latest"]))
        last_error = None
        for vision_model in candidates:
            url = (
                "https://generativelanguage.googleapis.com/v1beta/models/"
                f"{vision_model}:generateContent?key={settings.GEMINI_API_KEY}"
            )
            resp = await self.http_client.post(url, json=payload, timeout=60.0)
            if resp.status_code == 404:
                last_error = f"Gemini model {vision_model} không khả dụng (404)"
                continue
            resp.raise_for_status()
            data = resp.json()
            try:
                return data["candidates"][0]["content"]["parts"][0]["text"]
            except (KeyError, IndexError) as exc:
                raise RuntimeError(f"Gemini Vision trả về định dạng không mong đợi: {data}") from exc
        raise RuntimeError(last_error or "Không tìm thấy Gemini Vision model khả dụng.")
