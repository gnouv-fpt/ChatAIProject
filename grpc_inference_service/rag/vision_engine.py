import os
import json
import logging
import threading
from typing import Tuple, Dict, Any, Optional

logger = logging.getLogger("TrafficVisionEngine")

class TrafficVisionEngine:
    """
    Vision & OCR Engine for traffic images, signs, and infractions.
    Uses Gemini Vision / Multimodal API.
    Enforces rule: If the image is blurred, cut off, or lacks sufficient evidence,
    it returns requires_clarification=True and asks the user for a clearer photo.
    Observations are strictly kept separate from legal evidence.
    """

    CLARIFICATION_PROMPT = (
        "Ảnh chụp chưa đủ rõ ràng hoặc bị che khuất biển báo/tình huống giao thông. "
        "Vui lòng chụp lại rõ nét hơn toàn cảnh góc đường hoặc biển báo giao thông liên quan."
    )

    def __init__(self, api_key: Optional[str] = None):
        self._usage = threading.local()
        self.api_key = api_key or os.getenv("GOOGLE_API_KEY") or os.getenv("GEMINI_API_KEY")
        self._gemini_model = None

        if self.api_key:
            try:
                from rag.gemini_api import GeminiModel
                self._gemini_model = GeminiModel(self.api_key, os.getenv("GEMINI_VISION_MODEL", "gemini-3.6-flash"))
                logger.info("[VisionEngine] Initialized configured Gemini REST model.")
            except Exception as e:
                logger.warning(f"[VisionEngine] Gemini Vision init failed: {e}")

    def _parse_observation(self, raw):
        if "REQUIRES_CLARIFICATION" in raw:
            return self.CLARIFICATION_PROMPT, True, ""
        clean_json = raw.strip()
        if "```json" in clean_json:
            clean_json = clean_json.split("```json")[1].split("```")[0].strip()
        elif "```" in clean_json:
            clean_json = clean_json.split("```")[1].split("```")[0].strip()
        data = json.loads(clean_json)
        if data.get("is_clear") is False:
            return self.CLARIFICATION_PROMPT, True, ""
        if data.get("is_clear") is not True or not isinstance(data.get("observations"), str) or not data["observations"].strip() or not isinstance(data.get("search_query"), str) or not data["search_query"].strip():
            raise ValueError("Incomplete vision observation schema")
        return data["observations"], False, data["search_query"]

    def analyze_traffic_image(
        self, image_base64: str, mime_type: str = "image/jpeg", user_prompt: str = "", token_budget=4096
    ) -> Tuple[str, bool, str]:
        """
        Analyze traffic situation / traffic signs from image.

        Returns:
            observations (str): Visual observations extracted from image.
            requires_clarification (bool): True if image is unclear or truncated.
            query_for_rag (str): Refined legal search query based on observations.
        """
        self.last_tokens = None
        if not image_base64:
            return "Không tìm thấy dữ liệu hình ảnh.", True, ""

        prompt_instruction = (
            "Bạn là chuyên gia phân tích hiện trường giao thông đường bộ Việt Nam qua hình ảnh.\n"
            "Nhiệm vụ:\n"
            "1. Kiểm tra chất lượng ảnh: Ảnh có quá mờ, tối, vỡ nét hoặc bị cắt mất biển báo/phương tiện không?\n"
            "   Nếu KHÔNG THỂ XÁC ĐỊNH RÕ tình huống, hãy trả lời chính xác: 'REQUIRES_CLARIFICATION: <lý do>'\n"
            "2. Nếu ảnh rõ ràng:\n"
            "   - Nếu là sa hình, ghi riêng từng xe theo nhãn/số/màu, loại xe, vị trí, hướng mũi tên "
            "và đường xe dự định đi. Ghi rõ đèn tín hiệu, biển ưu tiên, biển đường chính, "
            "biển nhường đường, vạch dừng và người điều khiển giao thông nếu nhìn thấy. "
            "Ghi rõ xe nào đã vượt vạch dừng hoặc đã ở trong nơi giao nhau; "
            "nếu ảnh tĩnh không cho biết điều đó thì nêu là chưa xác định. "
            "Với mỗi mũi tên, lần theo nét vẽ từ đuôi ở gần xe đến đầu mũi tên; "
            "nêu điểm xuất phát và điểm đến, nhất là khi các đường mũi tên giao nhau. "
            "Không suy hướng rẽ chỉ từ vị trí xe hoặc từ đầu mũi tên đứng riêng. "
            "Phân biệt biển báo thật với mũi tên minh họa hướng di chuyển. "
            "Không tự kết luận thứ tự xe đi hay phương án đúng từ hình ảnh.\n"
            "   - Nếu câu hỏi cần xác định thứ tự/đáp án mà nhãn xe, mũi tên hoặc biển báo "
            "quyết định đáp án bị mờ, khuất, cắt mất hoặc không lần theo được do chồng nét, "
            "đặt is_clear=false.\n"
            "   - Đưa ra cụm từ tìm kiếm pháp lý (SEARCH_QUERY) phù hợp câu hỏi kèm theo. "
            "Với sa hình, ưu tiên từ khóa quy tắc nhường đường tại nơi giao nhau, xe ưu tiên, "
            "đường ưu tiên và chuyển hướng theo đúng yếu tố quan sát được. "
            "Chỉ tìm mức xử phạt nếu người dùng thực sự hỏi về xử phạt.\n"
            "Định dạng trả về JSON:\n"
            "{\n"
            "  \"is_clear\": true/false,\n"
            "  \"observations\": \"Chi tiết quan sát\",\n"
            "  \"search_query\": \"Từ khóa tra cứu luật\"\n"
            "}"
        )

        if self._gemini_model:
            try:
                content_parts = [
                    {"text": f"{prompt_instruction}\nCâu hỏi kèm theo: {user_prompt}"},
                    {"inline_data": {"mime_type": mime_type, "data": image_base64}}
                ]
                
                resp = self._gemini_model.generate_content(content_parts, request_options={"timeout": 30}, token_budget=token_budget)
                self.last_tokens = getattr(getattr(resp, "usage_metadata", None), "total_token_count", None)
                if resp and resp.text:
                    return self._parse_observation(resp.text)
            except Exception as e:
                logger.warning("[VisionEngine] Gemini inference failed: %s", type(e).__name__)

        raise RuntimeError("Vision API unavailable; image observations were not produced")

    @property
    def last_tokens(self):
        return getattr(self._usage, 'tokens', None)

    @last_tokens.setter
    def last_tokens(self, value):
        self._usage.tokens = value
