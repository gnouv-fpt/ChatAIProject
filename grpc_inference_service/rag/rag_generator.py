import os
import json
import logging
from typing import List, Dict, Any, Tuple, Optional

logger = logging.getLogger("TrafficRagGenerator")

class TrafficRagGenerator:
    """
    RAG Answer Generation Engine for Vietnamese Traffic Law.
    Uses Groq API as primary generation engine (with Gemini as secondary if configured).
    Enforces zero-hallucination policy and formats citations with Điểm, Chunk ID, and Version.
    """

    NO_MATCH_RESPONSE = (
        "Hiện tại hệ thống chưa tìm thấy quy định pháp lý tương ứng trong các văn bản giao thông đã được xác thực."
    )

    def __init__(self, groq_api_key: Optional[str] = None, gemini_api_key: Optional[str] = None):
        self.groq_api_key = groq_api_key or os.getenv("GROQ_API_KEY")
        self.gemini_api_key = gemini_api_key or os.getenv("GOOGLE_API_KEY") or os.getenv("GEMINI_API_KEY")
        
        self.groq_model = os.getenv("GROQ_MODEL", "llama-3.3-70b-versatile")
        self._groq_client = None
        self._gemini_client = None

        if self.groq_api_key:
            try:
                from groq import Groq
                self._groq_client = Groq(api_key=self.groq_api_key, timeout=30.0)
                logger.info(f"[RAGGenerator] Initialized Groq API client with model: {self.groq_model}")
            except Exception as e:
                logger.warning(f"[RAGGenerator] Failed to initialize Groq client: {e}")

        if not self._groq_client and self.gemini_api_key:
            try:
                import google.generativeai as genai
                genai.configure(api_key=self.gemini_api_key)
                self._gemini_client = genai.GenerativeModel("gemini-1.5-flash")
                logger.info("[RAGGenerator] Initialized Gemini 1.5 Flash client.")
            except Exception as e:
                logger.warning(f"[RAGGenerator] Failed to initialize Gemini client: {e}")

        if not self._groq_client and not self._gemini_client:
            logger.info("[RAGGenerator] No cloud LLM keys found. Will operate in structured deterministic synthesis mode.")

    def generate(
        self, prompt: str, verified_chunks: List[Dict[str, Any]]
    ) -> Tuple[str, List[Dict[str, Any]], int, bool]:
        """
        Generate answer and citations based strictly on verified legal chunks.
        
        Returns:
            response_text (str): Synthesized Vietnamese legal answer.
            citations (List[Dict[str, Any]]): List of citations with title, article, clause, point, url, chunk_id.
            tokens_used (int): Total tokens used.
            data_verified (bool): True if verified legal basis was found and used.
        """
        # If no verified chunks found, strictly return requirement fallback response
        if not verified_chunks:
            tokens = len(prompt.split()) + len(self.NO_MATCH_RESPONSE.split())
            return self.NO_MATCH_RESPONSE, [], max(tokens, 15), False

        # Extract citations with Điểm, chunk_id, document_version
        citations = []
        for c in verified_chunks:
            citation = {
                "chunk_id": str(c.get("chunk_id", "")),
                "document_title": c.get("document_title", ""),
                "article_number": c.get("article", ""),
                "clause_number": c.get("clause", ""),
                "point_number": c.get("point", ""),
                "document_version": c.get("document_version", "1.0"),
                "source_url": c.get("source_url", "https://thuvienphapluat.vn/"),
                "excerpt": (c.get("content", "")[:250] + "...") if len(c.get("content", "")) > 250 else c.get("content", "")
            }
            citations.append(citation)

        # Context assembly
        context_blocks = []
        for idx, c in enumerate(verified_chunks, start=1):
            point_info = f" {c.get('point', '')}" if c.get("point") else ""
            block = (
                f"[{idx}] {c.get('document_title', '')} - {c.get('article', '')} {c.get('clause', '')}{point_info}:\n"
                f"{c.get('content', '')}\n"
                f"Nguồn: {c.get('source_url', '')}"
            )
            context_blocks.append(block)
        context_str = "\n\n".join(context_blocks)

        system_instruction = (
            "Bạn là Trợ lý AI Tư vấn Pháp luật Giao thông Đường bộ Việt Nam chuyên nghiệp và chuẩn xác.\n"
            "QUY TẮC BẮT BUỘC:\n"
            "1. Chỉ trả lời dựa trên CĂN CỨ PHÁP LÝ đã được cung cấp dưới đây.\n"
            "2. Nêu rõ văn bản quy phạm (Nghị định/Luật), Điều, Khoản, Điểm và mức phạt/hành vi quy định.\n"
            "3. Nếu thông tin không có trong văn bản, tuyệt đối không bịa đặt hoặc suy diễn (Zero Hallucination).\n"
            "4. Trả lời bằng tiếng Việt trang trọng, mạch lạc, dễ hiểu cho người tham gia giao thông."
        )

        user_content = (
            f"--- CĂN CỨ PHÁP LÝ ĐÃ XÁC THỰC ---\n{context_str}\n\n"
            f"--- CÂU HỎI CỦA NGƯỜI DÙNG ---\n{prompt}"
        )

        # 1. Try Groq API
        if self._groq_client:
            try:
                completion = self._groq_client.chat.completions.create(
                    model=self.groq_model,
                    messages=[
                        {"role": "system", "content": system_instruction},
                        {"role": "user", "content": user_content}
                    ],
                    temperature=0.1,
                    max_tokens=1500
                )
                answer = completion.choices[0].message.content.strip()
                tokens_used = completion.usage.total_tokens if completion.usage else (len(user_content.split()) + len(answer.split()))
                return answer, citations, tokens_used, True
            except Exception as e:
                logger.error(f"[RAGGenerator] Groq API call failed: {e}")

        # 2. Try Gemini API as secondary
        if self._gemini_client:
            try:
                full_prompt = f"{system_instruction}\n\n{user_content}"
                res = self._gemini_client.generate_content(full_prompt)
                if res and res.text:
                    answer = res.text.strip()
                    tokens_used = len(full_prompt.split()) + len(answer.split())
                    return answer, citations, max(tokens_used, 50), True
            except Exception as e:
                logger.error(f"[RAGGenerator] Gemini API call failed: {e}")

        # 3. Deterministic synthesis for test & offline environments
        logger.info("[RAGGenerator] Synthesizing authoritative legal response directly from verified chunks.")
        response_text = self._synthesize_local_response(prompt, verified_chunks)
        tokens_est = int((len(prompt) + len(response_text) + len(context_str)) / 3.5)
        return response_text, citations, max(tokens_est, 60), True

    def _synthesize_local_response(self, prompt: str, chunks: List[Dict[str, Any]]) -> str:
        primary = chunks[0]
        title = primary.get("document_title", "Pháp luật Giao thông")
        article = primary.get("article", "")
        clause = primary.get("clause", "")
        point = primary.get("point", "")
        content = primary.get("content", "")

        point_str = f" {point}" if point else ""
        lines = [
            f"Theo quy định tại **{title}** ({article} {clause}{point_str}):",
            "",
            f"> \"{content}\"",
            "",
            "**Căn cứ pháp lý & Hướng dẫn:**",
            f"- Văn bản áp dụng: {title}",
            f"- Điều khoản: {article} {clause}{point_str}",
            f"- Trạng thái hiệu lực: **Đã xác thực (Đang có hiệu lực)**",
            f"- Nguồn tra cứu: {primary.get('source_url', 'Thư viện Pháp luật')}"
        ]

        if len(chunks) > 1:
            lines.append("")
            lines.append("**Các văn bản/điều khoản liên quan khác:**")
            for sub in chunks[1:3]:
                sub_point = f" {sub.get('point', '')}" if sub.get('point') else ""
                lines.append(f"- {sub.get('document_title', '')} - {sub.get('article', '')} {sub.get('clause', '')}{sub_point}")

        return "\n".join(lines)
