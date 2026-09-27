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
    ) -> Tuple[str, str]:
        """
        Generates grounded, natural, and actionable response using retrieved context.
        """
        provider = self.get_active_provider()
        context_str = self._format_context(retrieved_chunks)
        student_facts_str = self._format_student_facts(student_context)

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
    ) -> str:
        """
        Advanced Contextual Synthesis Engine:
        Produces natural, high-clarity Vietnamese responses with concrete actionable steps.
        Adheres to requirements in v7 (Mục 5.1, 5.2, 5.3, 5.4, 7.4).
        """
        q_lower = question.lower()
        all_courses = all_courses or {}

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
        if (student_context and ("gpa" in q_lower or "mục tiêu" in q_lower or "chiến lược" in q_lower or "tư vấn" in q_lower)) or any(k in q_lower for k in ["muốn ra trường", "muốn đạt", "gpa hiện tại", "cần làm gì từ giờ đến cuối", "lên 8."]):
            ctx = student_context or {}
            
            # Extract numbers if not passed in context
            cur_gpa = ctx.get("current_gpa")
            if cur_gpa is None:
                gpa_m = re.search(r"gpa.*?(\d+[\.,]\d+)", q_lower)
                cur_gpa = float(gpa_m.group(1).replace(",", ".")) if gpa_m else 7.4

            tgt_gpa = ctx.get("target_gpa")
            if tgt_gpa is None:
                tgt_m = re.search(r"(?:ra trường|lên|mục tiêu).*?(\d+[\.,]\d+)", q_lower)
                tgt_gpa = float(tgt_m.group(1).replace(",", ".")) if tgt_m else 8.0

            req_avg = ctx.get("required_avg_mark") or round(tgt_gpa + (tgt_gpa - cur_gpa) * 0.8, 2)
            retake_cnt = ctx.get("retake_count", 0)
            is_feasible = ctx.get("is_target_feasible", True) if req_avg <= 10.0 else False

            lines = [
                f"### Kế hoạch chiến lược học tập nâng điểm GPA lên {tgt_gpa}",
                "",
                f"- **Tình trạng hiện tại:** GPA tích lũy đang ở mức **{cur_gpa}**. Mục tiêu tốt nghiệp loại Giỏi (**{tgt_gpa}**).",
            ]
            if is_feasible:
                lines.append(f"- **Điểm số cần đạt:** Để đạt mục tiêu, sinh viên cần duy trì điểm trung bình các môn học còn lại tối thiểu từ **{req_avg:.2f}/10**.")
            else:
                lines.append(f"- **Cảnh báo tính khả thi:** Điểm trung bình cần đạt ở các môn còn lại vượt quá 10.0, mục tiêu GPA {tgt_gpa} về mặt toán học không khả thi. Bạn nên đặt mục tiêu điều chỉnh thực tế hơn.")

            lines.extend([
                "",
                "**1. Phân bổ chiến lược và ưu tiên môn học:**",
                "- Tập trung tối đa vào các môn chuyên ngành 3 tín chỉ có tính vào GPA (ví dụ: PRN212, SWD392, PRM393, PRJ301).",
                "- Đặc biệt chú trọng môn Đồ án chuyên ngành (SWP391) và Khóa luận tốt nghiệp (SEP490 - 10 tín chỉ). Điểm số các đồ án này chiếm trọng số rất lớn trong GPA tốt nghiệp.",
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
        sem_advisor_match = re.search(r"(?:kỳ|hk|học kỳ)\s*(\d+).*?(?:ưu tiên|phân bổ|chiến lược|nên học|học sao|thời gian)", q_lower)
        if sem_advisor_match or ("phân bổ thời gian" in q_lower and any(k in q_lower for k in ["kỳ 5", "hk5", "học kỳ 5"])):
            target_sem = int(sem_advisor_match.group(1)) if sem_advisor_match else 5
            
            # Find all courses for this semester from all_courses
            sem_courses = [c for c in all_courses.values() if getattr(c, "semester", 0) == target_sem]
            if not sem_courses and target_sem == 5:
                sem_course_codes = ["PRN212", "SWP391", "SWR302", "SWT301", "WDU203c"]
            else:
                sem_course_codes = [c.code for c in sem_courses]

            lines = [
                f"### Chiến lược phân bổ thời gian và thứ tự ưu tiên Học kỳ {target_sem}",
                "",
                f"Học kỳ {target_sem} bao gồm các môn: {', '.join(sem_course_codes)}.",
                "Để tối ưu hóa kết quả và tránh áp lực dồn vào cuối kỳ, bạn nên phân bổ thời gian và thứ tự ưu tiên như sau:",
                "",
                "**1. Mức độ ưu tiên cao nhất - Đồ án thực chiến:**",
                "- **SWP391 (Đồ án Kỹ thuật Phần mềm):** Chiếm khoảng **40% tổng thời gian**. Đây là môn làm dự án theo nhóm với khối lượng công việc lớn nhất kỳ. Cần lập nhóm vững, chốt đề tài và phân chia backlog/sprint ngay từ tuần 1.",
                "",
                "**2. Mức độ ưu tiên cao - Môn kỹ thuật cốt lõi có thi PE:**",
                "- **PRN212 (Lập trình .NET & C#):** Chiếm khoảng **25% thời gian**. Môn học có thi thực hành PE và là nền tảng trực tiếp để lập trình backend cho dự án SWP391. Cần luyện code thực hành thường xuyên trên Visual Studio.",
                "",
                "**3. Mức độ ưu tiên trung bình - Kiểm thử & Yêu cầu phần mềm:**",
                "- **SWT301 (Kiểm thử phần mềm) & SWR302 (Kỹ nghệ yêu cầu phần mềm):** Mỗi môn chiếm khoảng **15% thời gian**. Nên áp dụng trực tiếp các tài liệu SRS và Test cases của môn này vào chính sản phẩm SWP391 để tiết kiệm thời gian làm đồ án kép.",
                "",
                "**4. Môn hỗ trợ thiết kế giao diện:**",
                "- **WDU203c (UI/UX Design):** Chiếm khoảng **10% thời gian**. Hoàn thành các prototype trên Figma sớm trong nửa đầu kỳ để đội ngũ code SWP391 có giao diện làm việc."
            ]
            return "\n".join(lines)

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
            if not courses_in_sem and target_sem == 5:
                codes = ["PRN212", "SWP391", "SWR302", "SWT301", "WDU203c"]
                tot_credits = 15
            else:
                codes = [c.code for c in courses_in_sem]
                tot_credits = sum(c.credits for c in courses_in_sem)


            course_items = []
            for cd in codes:
                c_obj = all_courses.get(cd)
                c_name = c_obj.name_vi if c_obj and c_obj.name_vi else (c_obj.name_en if c_obj else "")
                cr = c_obj.credits if c_obj else 3
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
        if not retrieved_chunks:
            target = scope_id or (detected_courses[0] if detected_courses else "")
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
        if any(k in q_lower for k in [
            "tư vấn", "cách học", "làm sao để qua", "làm sao để pass", "học thế nào",
            "học như thế nào", "ôn thi", "ôn tập", "bí kíp", "chiến lược", "kinh nghiệm",
            "đạt điểm cao", "học tốt"
        ]):
            assessment_chunk = next((c for c, _ in retrieved_chunks if c.category == "assessment"), None)
            assess_content = assessment_chunk.content if assessment_chunk else top_chunk.content
            has_pe_meta = assessment_chunk.metadata.get("has_pe") if assessment_chunk else None
            if has_pe_meta is None:
                has_pe_meta = top_chunk.metadata.get("has_pe")
            has_pe = bool(has_pe_meta) if has_pe_meta is not None else ("practical exam" in assess_content.lower())

            prereqs = top_chunk.metadata.get("prerequisites", [])
            credits_val = top_chunk.metadata.get("credits", 3)
            time_alloc = top_chunk.metadata.get("time_allocation", "150 giờ (45h học trên lớp + 105h tự học)")

            lines = [
                f"### Chiến lược học tập và kế hoạch ôn thi môn {course_code} ({course_name})",
                "",
                f"Môn {course_code} có thời lượng {credits_val} tín chỉ với tổng thời gian học tập dự kiến là {time_alloc}. "
                f"Để hoàn thành môn học với kết quả cao, sinh viên nên áp dụng lộ trình sau:",
                "",
                "**1. Chuẩn bị kiến thức nền tảng:**",
            ]
            if prereqs:
                lines.append(f"- Cần ôn tập và củng cố vững kiến thức từ môn tiên quyết {', '.join(prereqs)} trước khi bắt đầu các chủ đề nâng cao.")
            else:
                lines.append("- Đây là môn học cơ sở/nhập môn. Cần nắm chắc các khái niệm cốt lõi ngay từ các tuần đầu tiên.")

            lines.append("")
            lines.append("**2. Chiến thuật làm bài thi và thực hành:**")
            if has_pe:
                lines.append(
                    "- Môn học có hình thức thi thực hành PE (Practical Exam). Đây là phần thi trọng tâm quyết định qua môn. "
                    "Sinh viên cần chủ động code trực tiếp trên IDE hàng ngày, tự bấm giờ giải lại toàn bộ bài lab và assignment mà không phụ thuộc vào tài liệu mẫu."
                )
                lines.append("- Lưu ý kiểm tra kỹ cấu hình môi trường, phiên bản SDK và xử lý ngoại lệ (Exception handling) để tránh mất điểm bài thi thực hành.")
            else:
                lines.append(
                    "- Môn học không thi PE thực hành nhưng có các bài thi lý thuyết/FE và báo cáo Assignment. "
                    "Cần tập trung nắm vững bản chất quy trình, kiến trúc thiết kế và các chuẩn đầu ra được quy định trong đề cương."
                )

            lines.append("")
            lines.append("**3. Quản lý điểm số thành phần:**")
            lines.append("- Đảm bảo tham gia tối thiểu 80% số buổi học trên lớp và nộp đầy đủ các bài Quiz/Lab đúng hạn.")
            lines.append("- Điểm các bài kiểm tra tiến độ và bài thi cuối kỳ FE phải đạt tối thiểu từ 4.0 trở lên để đủ điều kiện xét qua môn (điểm tổng kết >= 5.0).")

            return "\n".join(lines)

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
        return (
            f"### Thông tin môn học {course_code} ({course_name})\n\n"
            f"{top_chunk.content}\n\n"
            f"Gợi ý: Bạn có thể hỏi về hình thức thi PE/FE, chuẩn đầu ra (LOs), số tín chỉ, kế hoạch học tập hoặc tư vấn phương pháp học môn này."
        )
