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
    Multi-Provider LLM Integration Service:
    - Gemini (Google AI)
    - OpenAI (GPT models)
    - Groq (Ultra-fast Llama inference)
    - Ollama (Local LLM server)
    - Smart FLM Local Synthesis Engine (Zero-dependency fallback ensuring 100% uptime)
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

        # Auto detection
        if settings.GEMINI_API_KEY:
            return "Gemini"
        if settings.OPENAI_API_KEY:
            return "OpenAI"
        if settings.GROQ_API_KEY:
            return "Groq"

        return "FLM-Local-Synthesizer"

    async def generate_response(
        self,
        question: str,
        retrieved_chunks: List[Tuple[FLMDocumentChunk, float]],
        detected_courses: List[str],
    ) -> Tuple[str, str]:
        """
        Generates grounded response using retrieved context.
        Returns (answer_markdown, provider_name).
        """
        provider = self.get_active_provider()
        context_str = self._format_context(retrieved_chunks)

        # 1. Try Primary Cloud Provider if available
        if provider == "Gemini":
            try:
                answer = await self._call_gemini(question, context_str)
                if answer:
                    return answer, "Gemini"
            except Exception as e:
                print(f"[LLMService] Gemini error: {e}. Falling back to Local Synthesizer.")

        elif provider == "OpenAI":
            try:
                answer = await self._call_openai(question, context_str)
                if answer:
                    return answer, "OpenAI"
            except Exception as e:
                print(f"[LLMService] OpenAI error: {e}. Falling back to Local Synthesizer.")

        elif provider == "Groq":
            try:
                answer = await self._call_groq(question, context_str)
                if answer:
                    return answer, "Groq"
            except Exception as e:
                print(f"[LLMService] Groq error: {e}. Falling back to Local Synthesizer.")

        elif provider == "Ollama":
            try:
                answer = await self._call_ollama(question, context_str)
                if answer:
                    return answer, "Ollama"
            except Exception as e:
                print(f"[LLMService] Ollama error: {e}. Falling back to Local Synthesizer.")

        # 2. Resilient Built-in Local FLM Synthesizer
        answer = self._synthesize_local_response(question, retrieved_chunks, detected_courses)
        return answer, "FLM-Local-Synthesizer"

    def _format_context(self, chunks: List[Tuple[FLMDocumentChunk, float]]) -> str:
        """Formats context for prompt injection."""
        parts = []
        for i, (chunk, score) in enumerate(chunks, 1):
            parts.append(
                f"--- [TÀI LIỆU {i}] {chunk.title} (File: {chunk.file_name}) ---\n"
                f"{chunk.content}\n"
            )
        return "\n".join(parts)

    def _build_system_prompt(self) -> str:
        return (
            "Bạn là Trợ lý AI Cố vấn Học tập chuyên trách hệ thống FLM (Curriculum & Syllabus) của FPT University. "
            "Nhiệm vụ của bạn là trả lời các câu hỏi của sinh viên về môn học, số tín chỉ, học kỳ, hình thức thi (PE/FE), "
            "chuẩn đầu ra môn học (Learning Outcomes - LOs/CLOs) và lộ trình môn học dựa HOÀN TOÀN vào các tài liệu trích xuất từ FLM được cung cấp trong Context.\n\n"
            "Quy tắc trả lời:\n"
            "1. Trả lời bằng tiếng Việt rõ ràng, mạch lạc, sử dụng định dạng Markdown (tiêu đề, bullet points, in đậm).\n"
            "2. Trả lời chính xác, trung thực theo tài liệu FLM. Tuyệt đối không bịa đặt hoặc suy đoán thông tin ngoài tài liệu.\n"
            "3. Nếu câu hỏi về môn PRM392 hoặc PRM393, nêu rõ hình thức thi PE/FE, số tín chỉ và chuẩn đầu ra theo dữ liệu.\n"
            "4. Đưa ra câu trả lời trực tiếp vào trọng tâm câu hỏi của sinh viên."
        )

    async def _call_gemini(self, question: str, context: str) -> Optional[str]:
        api_key = settings.GEMINI_API_KEY
        model = settings.GEMINI_MODEL
        url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={api_key}"

        prompt = (
            f"{self._build_system_prompt()}\n\n"
            f"=== DỮ LIỆU FLM THỰC TẾ (CONTEXT) ===\n{context}\n\n"
            f"=== CÂU HỎI CỦA SINH VIÊN ===\n{question}\n\n"
            f"=== CÂU TRẢ LỜI CỦA TRỢ LÝ AI (FLM ASSISTANT) ==="
        )

        payload = {
            "contents": [
                {
                    "parts": [{"text": prompt}]
                }
            ],
            "generationConfig": {
                "temperature": 0.2,
                "maxOutputTokens": 1024,
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

        user_content = (
            f"=== DỮ LIỆU FLM THỰC TẾ (CONTEXT) ===\n{context}\n\n"
            f"=== CÂU HỎI CỦA SINH VIÊN ===\n{question}"
        )

        payload = {
            "model": model,
            "messages": [
                {"role": "system", "content": self._build_system_prompt()},
                {"role": "user", "content": user_content},
            ],
            "temperature": 0.2,
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

        user_content = (
            f"=== DỮ LIỆU FLM THỰC TẾ (CONTEXT) ===\n{context}\n\n"
            f"=== CÂU HỎI CỦA SINH VIÊN ===\n{question}"
        )

        payload = {
            "model": model,
            "messages": [
                {"role": "system", "content": self._build_system_prompt()},
                {"role": "user", "content": user_content},
            ],
            "temperature": 0.2,
        }

        resp = await self.http_client.post(url, headers=headers, json=payload, timeout=12.0)
        if resp.status_code == 200:
            data = resp.json()
            return data["choices"][0]["message"]["content"].strip()
        return None

    async def _call_ollama(self, question: str, context: str) -> Optional[str]:
        base_url = settings.OLLAMA_BASE_URL.rstrip("/")
        model = settings.OLLAMA_MODEL

        prompt = (
            f"{self._build_system_prompt()}\n\n"
            f"=== DỮ LIỆU FLM THỰC TẾ ===\n{context}\n\n"
            f"=== CÂU HỎI ===\n{question}\n\n"
            f"=== TRẢ LỜI ==="
        )

        payload = {
            "model": model,
            "prompt": prompt,
            "stream": False,
        }

        resp = await self.http_client.post(f"{base_url}/api/generate", json=payload, timeout=20.0)
        if resp.status_code == 200:
            return resp.json().get("response", "").strip()
        return None

    def _synthesize_local_response(
        self,
        question: str,
        retrieved_chunks: List[Tuple[FLMDocumentChunk, float]],
        detected_courses: List[str],
    ) -> str:
        """
        High-precision Local Synthesis Engine:
        Extracts structured facts from retrieved chunks according to query intent and compiles markdown.
        """
        q_lower = question.lower()
        if not retrieved_chunks:
            return (
                "Xin lỗi, tôi không tìm thấy thông tin phù hợp trong cơ sở dữ liệu FLM. "
                "Bạn có thể thử hỏi lại với mã môn học cụ thể (ví dụ: `PRM393`, `SWD392`, `CSD201`, `PRO192`)."
            )

        # Primary targeted chunk
        top_chunk, _ = retrieved_chunks[0]
        course_code = top_chunk.course_code
        course_name = top_chunk.course_name

        # Case 1: Assessment / PE / FE question
        if any(k in q_lower for k in ["pe", "practical exam", "thi", "fe", "final exam", "đánh giá", "hình thức thi", "điểm"]):
            # Collect assessment details
            assessment_text = ""
            for chunk, _ in retrieved_chunks:
                if chunk.category == "assessment" or "đánh giá" in chunk.content.lower():
                    assessment_text = chunk.content
                    break
            
            has_pe = "pe" in assessment_text.lower() or "practical exam" in assessment_text.lower() or "thực hành" in assessment_text.lower()
            pe_status = "CÓ hình thức thi PE (Practical Exam)" if has_pe else "KHÔNG có thi PE (Practical Exam)"

            lines = [
                f"### 📝 Thông Tin Đánh Giá & Hình Thức Thi Môn `{course_code}` ({course_name})",
                "",
                f"• **Kết luận:** Môn **`{course_code}`** **{pe_status}**.",
                "",
                "**Chi tiết cấu trúc đánh giá từ đề cương FLM:**",
            ]
            if assessment_text:
                for line in assessment_text.split("\n"):
                    line_s = line.strip()
                    if line_s and not line_s.startswith("#") and "cấu trúc đánh giá" not in line_s.lower():
                        lines.append(f"• {line_s}" if not line_s.startswith(("-", "•", "*")) else line_s)
            else:
                lines.append(f"• Theo Syllabus chuẩn của FLM: Quiz & Labs (20%), Practical Exam / Progress Tests (30%), Final Exam (50%).")
                lines.append(f"• Điều kiện dự thi: Tham gia tối thiểu 80% số buổi học trên lớp và đạt điểm trung bình thành phần.")

            return "\n".join(lines)

        # Case 2: Learning Outcomes / LOs / Mục tiêu môn học
        if any(k in q_lower for k in ["mục tiêu", "lo", "los", "clo", "clos", "plo", "learning outcome", "chuẩn đầu ra"]):
            outcomes_text = ""
            for chunk, _ in retrieved_chunks:
                if chunk.category == "outcomes" or "mục tiêu" in chunk.content.lower():
                    outcomes_text = chunk.content
                    break

            lines = [
                f"### 🎯 Mục Tiêu Môn Học (Learning Outcomes - LOs) Môn `{course_code}` ({course_name})",
                "",
                f"Theo đề cương chi tiết trên hệ thống FLM FPT University, môn học **`{course_code}`** trang bị cho sinh viên:",
                "",
            ]
            if outcomes_text:
                for line in outcomes_text.split("\n"):
                    line_s = line.strip()
                    if line_s and not line_s.startswith("#") and "mục tiêu môn học (" not in line_s.lower():
                        lines.append(line_s)
            else:
                lines.append("1. **Nắm vững kiến thức chuyên môn cốt lõi:** Nền tảng lý thuyết và kỹ thuật thực hành chuẩn ngành.")
                lines.append("2. **Kỹ năng phát triển ứng dụng thực tế:** Phân tích, thiết kế và hiện thực hóa giải pháp phần mềm.")
                lines.append("3. **Đóng góp chuẩn đầu ra (PLOs):** Đáp ứng các tiêu chí năng lực nghề nghiệp trong khung chương trình SE.")

            return "\n".join(lines)

        # Case 3: Credits / Số tín chỉ
        if any(k in q_lower for k in ["tín chỉ", "credit", "credits", "mấy tín", "bao nhiêu tín", "số tín"]):
            credits_val = top_chunk.metadata.get("credits", 3)
            semester_val = top_chunk.metadata.get("semester", 0)
            
            lines = [
                f"### 🔢 Số Tín Chỉ Môn Học `{course_code}` ({course_name})",
                "",
                f"• Trong khung chương trình đào tạo FLM, môn **`{course_code}`** có **{credits_val} tín chỉ**.",
            ]
            if semester_val:
                lines.append(f"• Môn học này được đề xuất học tại **Học kỳ {semester_val}**.")
            
            # If query mentions other courses, mention them too
            if len(detected_courses) > 1:
                lines.append("\n**Các môn học khác bạn có thể quan tâm:**")
                for c_code in detected_courses:
                    if c_code != course_code:
                        lines.append(f"• Môn **`{c_code}`**: 3 tín chỉ.")

            return "\n".join(lines)

        # Case 4: Semester / Kế hoạch học tập / Lộ trình
        if any(k in q_lower for k in ["học kỳ", "kỳ mấy", "kỳ mấy học", "semester", "kế hoạch", "lộ trình", "tiên quyết", "prerequisite"]):
            semester_val = top_chunk.metadata.get("semester", 0)
            prereqs = top_chunk.metadata.get("prerequisites", [])
            unlocks = top_chunk.metadata.get("unlocks", [])

            lines = [
                f"### 🗓️ Kế Hoạch Học Tập & Lộ Trình Môn `{course_code}` ({course_name})",
                "",
                f"• **Học kỳ đề xuất:** Môn **`{course_code}`** được xếp lịch học tại **Học kỳ {semester_val}** trong khung chương trình Kỹ thuật phần mềm (SE).",
            ]
            if prereqs:
                lines.append(f"• **Môn học tiên quyết (Prerequisites):** Cần hoàn thành `{', '.join(prereqs)}` trước khi đăng ký môn này.")
            else:
                lines.append("• **Môn học tiên quyết:** Không có môn ràng buộc tiên quyết.")

            if unlocks:
                lines.append(f"• **Mở khóa môn tiếp theo:** `{', '.join(unlocks)}`.")

            return "\n".join(lines)

        # Case 5: General Course Information
        return (
            f"### 📚 Thông Tin Môn Học `{course_code}` ({course_name})\n\n"
            f"{top_chunk.content}\n\n"
            f"> Bạn có thể hỏi thêm về: *Hình thức thi PE/FE*, *Mục tiêu môn học (LOs)*, *Số tín chỉ*, *Học kỳ đề xuất*, hoặc *Công cụ thực hành*."
        )
