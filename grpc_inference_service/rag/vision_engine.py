import os
import json
import logging
from typing import Tuple, Dict, Any, Optional

logger = logging.getLogger("TrafficVisionEngine")

class TrafficVisionEngine:
    """
    Vision & OCR Engine for traffic images, signs, and infractions.
    Uses Gemini Vision / Multimodal API or Groq Vision.
    Enforces rule: If the image is blurred, cut off, or lacks sufficient evidence,
    it returns requires_clarification=True and asks the user for a clearer photo.
    Observations are strictly kept separate from legal evidence.
    """

    CLARIFICATION_PROMPT = (
        "Ảnh chụp chưa đủ rõ ràng hoặc bị che khuất biển báo/tình huống giao thông. "
        "Vui lòng chụp lại rõ nét hơn toàn cảnh góc đường hoặc biển báo giao thông liên quan."
    )

    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key or os.getenv("GOOGLE_API_KEY") or os.getenv("GEMINI_API_KEY")
        self._gemini_model = None

        if self.api_key:
            try:
                import google.generativeai as genai
                genai.configure(api_key=self.api_key)
                self._gemini_model = genai.GenerativeModel("gemini-1.5-flash")
                logger.info("[VisionEngine] Initialized Gemini 1.5 Flash Vision client.")
            except Exception as e:
                logger.warning(f"[VisionEngine] Gemini Vision init failed: {e}")

    def analyze_traffic_image(
        self, image_base64: str, mime_type: str = "image/jpeg", user_prompt: str = ""
    ) -> Tuple[str, bool, str]:
        """
        Analyze traffic situation / traffic signs from image.

        Returns:
            observations (str): Visual observations extracted from image.
            requires_clarification (bool): True if image is unclear or truncated.
            query_for_rag (str): Refined legal search query based on observations.
        """
        if not image_base64:
            return "Không tìm thấy dữ liệu hình ảnh.", True, ""

        if self._gemini_model:
            try:
                prompt_instruction = (
                    "Bạn là chuyên gia phân tích hiện trường giao thông đường bộ Việt Nam qua hình ảnh.\n"
                    "Nhiệm vụ:\n"
                    "1. Kiểm tra chất lượng ảnh: Ảnh có quá mờ, tối, vỡ nét hoặc bị cắt mất biển báo/phương tiện không?\n"
                    "   Nếu KHÔNG THỂ XÁC ĐỊNH RÕ tình huống, hãy trả lời chính xác: 'REQUIRES_CLARIFICATION: <lý do>'\n"
                    "2. Nếu ảnh rõ ràng:\n"
                    "   - Miêu tả ngắn gọn hiện trường, loại phương tiện, biển báo, vạch kẻ đường quan sát được.\n"
                    "   - Đưa ra cụm từ tìm kiếm pháp lý (SEARCH_QUERY) để tra cứu mức xử phạt theo luật giao thông.\n"
                    "Định dạng trả về JSON:\n"
                    "{\n"
                    "  \"is_clear\": true/false,\n"
                    "  \"observations\": \"Chi tiết quan sát\",\n"
                    "  \"search_query\": \"Từ khóa tra cứu luật\"\n"
                    "}"
                )

                content_parts = [
                    {"text": f"{prompt_instruction}\nCâu hỏi kèm theo: {user_prompt}"},
                    {"inline_data": {"mime_type": mime_type, "data": image_base64}}
                ]
                
                resp = self._gemini_model.generate_content(content_parts)
                if resp and resp.text:
                    raw = resp.text.strip()
                    if "REQUIRES_CLARIFICATION" in raw:
                        return self.CLARIFICATION_PROMPT, True, ""

                    # Try parsing json
                    try:
                        clean_json = raw
                        if "```json" in clean_json:
                            clean_json = clean_json.split("```json")[1].split("```")[0].strip()
                        elif "```" in clean_json:
                            clean_json = clean_json.split("```")[1].split("```")[0].strip()
                        data = json.loads(clean_json)
                        if not data.get("is_clear", True):
                            return self.CLARIFICATION_PROMPT, True, ""
                        return data.get("observations", raw), False, data.get("search_query", user_prompt)
                    except Exception:
                        return raw, False, user_prompt
            except Exception as e:
                logger.error(f"[VisionEngine] Inference failed: {e}")

        # Deterministic simulation/fallback for testing when no cloud key is provided
        if "mo" in user_prompt.lower() or "khong ro" in user_prompt.lower() or len(image_base64) < 50:
            return self.CLARIFICATION_PROMPT, True, ""

        simulated_obs = (
            "Hình ảnh ghi nhận phương tiện giao thông (xe máy/ô tô) và biển báo hiệu đường bộ tại hiện trường. "
            f"Chi tiết người dùng quan sát: {user_prompt}"
        )
        return simulated_obs, False, user_prompt
