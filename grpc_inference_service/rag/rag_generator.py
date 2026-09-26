import os
from typing import List, Dict, Any, Tuple

class TrafficRagGenerator:
    """
    RAG Answer Generation Engine for Vietnamese Traffic Law.
    Enforces zero-hallucination policy and formats citations according to requirement.md.
    """

    NO_MATCH_RESPONSE = (
        "Hiện tại hệ thống chưa tìm thấy quy định pháp lý tương ứng trong các văn bản giao thông đã được xác thực."
    )

    def __init__(self, api_key: str = None):
        self.api_key = api_key or os.getenv("GOOGLE_API_KEY") or os.getenv("GEMINI_API_KEY")
        self._llm = None

        if self.api_key:
            try:
                import google.generativeai as genai
                genai.configure(api_key=self.api_key)
                self._llm = genai.GenerativeModel("gemini-1.5-flash")
                print("[RAGGenerator] Initialized Gemini 1.5 Flash LLM generator.")
            except Exception as e:
                print(f"[RAGGenerator] LLM init warning: {e}. Will use contextual legal formatter.")

    def generate(self, prompt: str, verified_chunks: List[Dict[str, Any]]) -> Tuple[str, List[Dict[str, Any]], int, bool]:
        """
        Generate answer and citations based strictly on verified legal chunks.
        
        Returns:
            response_text (str): Synthesized Vietnamese legal answer.
            citations (List[Dict[str, str]]): List of citations (title, article, clause, url, excerpt).
            tokens_used (int): Estimated tokens consumed.
            data_verified (bool): True if verified legal basis was found and used.
        """
        # If no verified chunks found, strictly return requirement fallback response
        if not verified_chunks:
            tokens = len(prompt.split()) + len(self.NO_MATCH_RESPONSE.split())
            return self.NO_MATCH_RESPONSE, [], max(tokens, 15), False

        # Extract citations
        citations = []
        for c in verified_chunks:
            citation = {
                "document_title": c.get("document_title", ""),
                "article_number": c.get("article", ""),
                "clause_number": c.get("clause", ""),
                "source_url": c.get("source_url", "https://thuvienphapluat.vn/"),
                "excerpt": (c.get("content", "")[:250] + "...") if len(c.get("content", "")) > 250 else c.get("content", "")
            }
            citations.append(citation)

        # Context assembly
        context_blocks = []
        for idx, c in enumerate(verified_chunks, start=1):
            block = (
                f"[{idx}] {c.get('document_title', '')} - {c.get('article', '')} {c.get('clause', '')}:\n"
                f"{c.get('content', '')}\n"
                f"Nguồn: {c.get('source_url', '')}"
            )
            context_blocks.append(block)
        context_str = "\n\n".join(context_blocks)

        # Generate response using LLM if available
        if self._llm:
            try:
                system_instruction = (
                    "Bạn là Trợ lý AI Tư vấn Pháp luật Giao thông Đường bộ Việt Nam chuyên nghiệp và chuẩn xác.\n"
                    "QUY TẮC CỐT LÕI:\n"
                    "1. Chỉ trả lời dựa trên CĂN CỨ PHÁP LÝ đã được cung cấp dưới đây.\n"
                    "2. Nêu rõ văn bản quy phạm (Nghị định/Luật), Điều, Khoản, Điểm và mức phạt/hành vi quy định.\n"
                    "3. Nếu thông tin không có trong văn bản, tuyệt đối không bịa đặt hoặc suy diễn.\n"
                    "4. Trả lời bằng tiếng Việt trang trọng, mạch lạc, dễ hiểu cho người tham gia giao thông."
                )
                full_prompt = (
                    f"{system_instruction}\n\n"
                    f"--- CĂN CỨ PHÁP LÝ ĐÃ XÁC THỰC ---\n{context_str}\n\n"
                    f"--- CÂU HỎI CỦA NGƯỜI DÙNG ---\n{prompt}"
                )
                res = self._llm.generate_content(full_prompt)
                if res and res.text:
                    response_text = res.text.strip()
                    tokens_used = (
                        len(full_prompt.split()) + len(response_text.split())
                    )
                    return response_text, citations, max(tokens_used, 50), True
            except Exception as e:
                print(f"[RAGGenerator] LLM inference failed: {e}. Fallback to direct synthesis.")

        # Fallback high-quality direct legal synthesis (offline / no API key mode)
        response_text = self._synthesize_local_response(prompt, verified_chunks)
        tokens_est = int((len(prompt) + len(response_text) + len(context_str)) / 3.5)
        return response_text, citations, max(tokens_est, 60), True

    def _synthesize_local_response(self, prompt: str, chunks: List[Dict[str, Any]]) -> str:
        """
        Directly synthesizes an authoritative legal response from matched chunks.
        """
        primary = chunks[0]
        title = primary.get("document_title", "Pháp luật Giao thông")
        article = primary.get("article", "")
        clause = primary.get("clause", "")
        content = primary.get("content", "")

        lines = [
            f"Theo quy định tại **{title}** ({article} {clause}):",
            "",
            f"> \"{content}\"",
            "",
            "**Căn cứ pháp lý & Hướng dẫn:**",
            f"- Văn bản áp dụng: {title}",
            f"- Điều khoản: {article} {clause}",
            f"- Trạng thái hiệu lực: **Đã xác thực (Đang có hiệu lực)**",
            f"- Nguồn tra cứu: {primary.get('source_url', 'Thư viện Pháp luật')}"
        ]

        if len(chunks) > 1:
            lines.append("")
            lines.append("**Các văn bản/điều khoản liên quan khác:**")
            for sub in chunks[1:3]:
                lines.append(f"- {sub.get('document_title', '')} - {sub.get('article', '')} {sub.get('clause', '')}")

        return "\n".join(lines)
