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
    - Advanced FLM Synthesis Engine with actionable academic advising & natural language generation.
    """

    def __init__(self):
        self.http_client = httpx.AsyncClient(timeout=15.0)

    async def close(self):
        await self.http_client.aclose()

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
        1. Strips all decorative emojis and special pictographs.
        2. Fixes awkward markdown glitches like 'và**3.', '**1.', '### 🗓️'.
        3. Cleans repetitive asterisks and normalizes line breaks.
        """
        if not text:
            return ""

        # Remove emojis, pictographs, symbols and variation selectors
        emoji_pattern = re.compile(
            r"[\U00010000-\U0010ffff\u2600-\u27ff\ufe00-\ufe0f\u2300-\u23ff\u2b50-\u2b55\u200d\u24c2-\u2573]",
            flags=re.UNICODE,
        )
        cleaned = emoji_pattern.sub("", text)

        # Fix markdown glitches like `và**3.` -> `và 3.`
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
    ) -> Tuple[str, str]:
        """
        Generates grounded, natural, and actionable response using retrieved context.
        """
        provider = self.get_active_provider()
        context_str = self._format_context(retrieved_chunks)

        # 1. Try Primary Cloud Provider if available
        if provider == "Gemini":
            try:
                answer = await self._call_gemini(question, context_str)
                if answer:
                    return self._sanitize_output(answer), "Gemini"
            except Exception as e:
                print(f"[LLMService] Gemini error: {e}. Falling back to Advanced Synthesizer.")

        elif provider == "OpenAI":
            try:
                answer = await self._call_openai(question, context_str)
                if answer:
                    return self._sanitize_output(answer), "OpenAI"
            except Exception as e:
                print(f"[LLMService] OpenAI error: {e}. Falling back to Advanced Synthesizer.")

        elif provider == "Groq":
            try:
                answer = await self._call_groq(question, context_str)
                if answer:
                    return self._sanitize_output(answer), "Groq"
            except Exception as e:
                print(f"[LLMService] Groq error: {e}. Falling back to Advanced Synthesizer.")

        elif provider == "Ollama":
            try:
                answer = await self._call_ollama(question, context_str)
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

    async def _call_gemini(self, question: str, context: str) -> Optional[str]:
        api_key = settings.GEMINI_API_KEY
        model = settings.GEMINI_MODEL
        url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={api_key}"

        prompt = (
            f"{self._build_system_prompt()}\n\n"
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

    async def _call_openai(self, question: str, context: str) -> Optional[str]:
        api_key = settings.OPENAI_API_KEY
        base_url = settings.OPENAI_BASE_URL.rstrip("/")
        model = settings.OPENAI_MODEL

        headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        }
        user_content = f"=== DỮ LIỆU FLM THỰC TẾ ===\n{context}\n\n=== CÂU HỎI CỦA SINH VIÊN ===\n{question}"
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

    async def _call_groq(self, question: str, context: str) -> Optional[str]:
        api_key = settings.GROQ_API_KEY
        model = settings.GROQ_MODEL
        url = "https://api.groq.com/openai/v1/chat/completions"

        headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        }
        user_content = f"=== DỮ LIỆU FLM THỰC TẾ ===\n{context}\n\n=== CÂU HỎI ===\n{question}"
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

    async def _call_ollama(self, question: str, context: str) -> Optional[str]:
        base_url = settings.OLLAMA_BASE_URL.rstrip("/")
        model = settings.OLLAMA_MODEL
        prompt = f"{self._build_system_prompt()}\n\n=== DỮ LIỆU FLM ===\n{context}\n\n=== CÂU HỎI ===\n{question}\n\n=== TRẢ LỜI ==="
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
    ) -> str:
        """
        Advanced Contextual Synthesis Engine:
        Produces natural, high-clarity Vietnamese responses with concrete actionable steps.
        """
        q_lower = question.lower()

        # Handle GPA Policy / Retake Rules
        if any(k in q_lower for k in ["hạ bậc", "hạ bằng", "học lại", "tính gpa", "không tính gpa", "cải thiện điểm", "xếp loại tốt nghiệp"]):
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

        if not retrieved_chunks:
            target = scope_id or (detected_courses[0] if detected_courses else "")
            if target:
                return f"Hiện tại dữ liệu FLM chưa có thông tin chi tiết về câu hỏi này cho môn/khung {target}. Bạn có thể hỏi về số tín chỉ, chuẩn đầu ra, hình thức thi PE/FE hoặc môn tiên quyết."
            return (
                "Tôi chưa tìm thấy thông tin phù hợp trong kho dữ liệu FLM. "
                "Bạn có thể đặt câu hỏi về mã môn cụ thể (ví dụ: PRM393, SWD392, CSD201, PRO192) hoặc nội dung chương trình đào tạo."
            )

        top_chunk, _ = retrieved_chunks[0]
        course_code = top_chunk.course_code or scope_id or "Môn học"
        course_name = top_chunk.course_name

        # Case 1: Strategy Advising / How to learn / Exam Preparation
        if any(k in q_lower for k in [
            "tư vấn", "cách học", "làm sao để qua", "làm sao để pass", "học thế nào",
            "học như thế nào", "ôn thi", "ôn tập", "bí kíp", "chiến lược", "kinh nghiệm",
            "ưu tiên môn nào", "phân bổ", "đạt điểm cao", "học tốt"
        ]):
            assessment_chunk = next((c for c, _ in retrieved_chunks if c.category == "assessment"), None)
            syllabus_chunk = next((c for c, _ in retrieved_chunks if c.category == "syllabus"), None)
            
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

        # Case 2: Assessment / PE / FE
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

        # Case 3: Learning Outcomes / LOs
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

        # Case 4: Credits / Số tín chỉ
        if any(k in q_lower for k in ["tín chỉ", "credit", "credits", "mấy tín", "bao nhiêu tín"]):
            credits_val = top_chunk.metadata.get("credits", 3)
            semester_val = top_chunk.metadata.get("semester", 0)

            lines = [
                f"### Số tín chỉ môn học {course_code} ({course_name})",
                "",
                f"- Trong chương trình đào tạo, môn {course_code} có {credits_val} tín chỉ.",
            ]
            if semester_val:
                lines.append(f"- Môn học được đề xuất học tại Học kỳ {semester_val}.")
            return "\n".join(lines)

        # Case 5: Semester / Prerequisites / Roadmap
        if any(k in q_lower for k in ["học kỳ", "kỳ mấy", "semester", "tiên quyết", "prerequisite", "mở khóa"]):
            semester_val = top_chunk.metadata.get("semester", 0)
            prereqs = top_chunk.metadata.get("prerequisites", [])
            unlocks = top_chunk.metadata.get("unlocks", [])

            lines = [
                f"### Kế hoạch học tập và lộ trình môn {course_code} ({course_name})",
                "",
                f"- Học kỳ đề xuất: Học kỳ {semester_val}.",
            ]
            if prereqs:
                lines.append(f"- Điều kiện tiên quyết: Cần hoàn thành {', '.join(prereqs)} trước khi học môn này.")
            else:
                lines.append("- Điều kiện tiên quyết: Không có môn ràng buộc tiên quyết.")

            if unlocks:
                lines.append(f"- Môn học kế tiếp mở khóa: {', '.join(unlocks)}.")

            return "\n".join(lines)

        # Case 6: General Overview
        return (
            f"### Thông tin môn học {course_code} ({course_name})\n\n"
            f"{top_chunk.content}\n\n"
            f"Gợi ý: Bạn có thể hỏi về hình thức thi PE/FE, chuẩn đầu ra (LOs), số tín chỉ, kế hoạch học tập hoặc tư vấn phương pháp học môn này."
        )
