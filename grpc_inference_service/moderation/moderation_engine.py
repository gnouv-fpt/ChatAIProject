import re
from typing import List, Tuple

class ModerationEngine:
    """
    Moderation & Toxicity Check Engine for Vietnam Traffic Law RAG System.
    Detects toxic speech, profanity, and illegal traffic evasion requests.
    """

    # Prohibited keywords/patterns categorized by violation type
    PROFANITY_KEYWORDS = [
        "địt", "đụ", "lồn", "buồi", "cặc", "đĩ", "mẹ mày", "đm", "đcm", "vcl",
        "con cặc", "đậu má", "clgt", "óc chó", "ngu lồn", "đĩ mẹ"
    ]

    ILLEGAL_ACTION_KEYWORDS = [
        "hối lộ", "đút lót", "chạy chọt", "bôi trơn csgt", "hối lộ công an",
        "biển số giả", "biển giả", "làm giả cavet", "làm giả bằng lái", "mua bằng lái",
        "thông chốt", "trốn chốt", "tông csgt", "chống người thi hành công vụ",
        "đua xe trái phép", "tổ chức đua xe", "khiêu khích csgt",
        "đục số khung", "đục số máy", "độ pô phá làng", "độ xe trái phép",
        "cách lách luật", "mẹo trốn thổi nồng độ cồn", "thuốc giải cồn giả mạo"
    ]

    def __init__(self, custom_keywords: List[str] = None):
        self.prohibited_keywords = set(self.PROFANITY_KEYWORDS + self.ILLEGAL_ACTION_KEYWORDS)
        if custom_keywords:
            self.prohibited_keywords.update([k.lower().strip() for k in custom_keywords])

    def check(self, text: str) -> Tuple[bool, List[str], str]:
        """
        Check if the input text contains prohibited keywords or violations.
        
        Returns:
            is_violation (bool): True if violation found.
            violation_keywords (List[str]): List of detected prohibited terms.
            warning_message (str): Explanatory warning message if violated.
        """
        if not text or not text.strip():
            return False, [], ""

        normalized = text.lower()
        # Remove repeated punctuation/spaces for cleaner pattern matching
        cleaned = re.sub(r'[\s\.\,\!\?\-\_]+', ' ', normalized)

        detected = []
        for kw in self.prohibited_keywords:
            # Word boundary or phrase check
            pattern = r'(?:\b|\s|^)' + re.escape(kw) + r'(?:\b|\s|$)'
            if re.search(pattern, cleaned) or kw in normalized:
                if kw not in detected:
                    detected.append(kw)

        if detected:
            msg = (
                "Hệ thống phát hiện nội dung của bạn vi phạm quy định tiêu chuẩn cộng đồng "
                f"hoặc chứa nội dung không được phép: [{', '.join(detected)}]. "
                "Yêu cầu của bạn đã bị từ chối và ghi nhận vào nhật ký vi phạm an toàn."
            )
            return True, detected, msg

        return False, [], ""
