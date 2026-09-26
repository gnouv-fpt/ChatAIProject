import re
from typing import Dict, Any, Optional

class DataVerificationEngine:
    """
    Data Verification Engine for Vietnam Traffic Law RAG System.
    Validates legal status, expiration, and amendment relationships between documents
    (e.g., Decree 100/2019/ND-CP vs Decree 123/2021/ND-CP, obsolete decrees 46/2016, 171/2013).
    """

    # Knowledge registry of traffic law documents and their status
    LEGAL_REGISTRY: Dict[str, Dict[str, Any]] = {
        "123/2021/ND-CP": {
            "title": "Nghị định 123/2021/NĐ-CP",
            "effective_date": "2022-01-01",
            "status": "Verified",
            "is_active": True,
            "amends": ["100/2019/ND-CP"],
            "notes": "Sửa đổi, bổ sung một số điều của các Nghị định quy định xử phạt vi phạm hành chính trong lĩnh vực hàng hải, giao thông đường bộ, đường sắt; hàng không dân dụng."
        },
        "100/2019/ND-CP": {
            "title": "Nghị định 100/2019/NĐ-CP",
            "effective_date": "2020-01-01",
            "status": "Verified",
            "is_active": True,
            "amended_by": ["123/2021/ND-CP"],
            "replaces": ["46/2016/ND-CP", "171/2013/ND-CP", "107/2014/ND-CP"],
            "notes": "Quy định xử phạt vi phạm hành chính trong lĩnh vực giao thông đường bộ và đường sắt. Một số điều khoản đã được sửa đổi bổ sung bởi Nghị định 123/2021/NĐ-CP."
        },
        "46/2016/ND-CP": {
            "title": "Nghị định 46/2016/NĐ-CP",
            "effective_date": "2016-08-01",
            "expiration_date": "2020-01-01",
            "status": "Outdated",
            "is_active": False,
            "replaced_by": "100/2019/ND-CP",
            "notes": "Đã hết hiệu lực toàn bộ từ ngày 01/01/2020, bị thay thế bởi Nghị định 100/2019/NĐ-CP."
        },
        "171/2013/ND-CP": {
            "title": "Nghị định 171/2013/NĐ-CP",
            "effective_date": "2014-01-01",
            "expiration_date": "2016-08-01",
            "status": "Outdated",
            "is_active": False,
            "replaced_by": "46/2016/ND-CP",
            "notes": "Đã hết hiệu lực từ ngày 01/08/2016, bị thay thế bởi Nghị định 46/2016/NĐ-CP."
        },
        "23/2008/QH12": {
            "title": "Luật Giao thông đường bộ 2008",
            "effective_date": "2009-07-01",
            "status": "Verified",
            "is_active": True,
            "notes": "Văn bản luật nền tảng. Quốc hội đã thông qua Luật TTATGTĐB 36/2024/QH15 và Luật Đường bộ 35/2024/QH15 hiệu lực từ 01/01/2025."
        },
        "36/2024/QH15": {
            "title": "Luật Trật tự, an toàn giao thông đường bộ 2024",
            "effective_date": "2025-01-01",
            "status": "Verified",
            "is_active": True,
            "notes": "Quy định toàn diện về trật tự an toàn giao thông đường bộ từ 01/01/2025."
        }
    }

    def normalize_doc_number(self, doc_number: str) -> str:
        """Normalize document number string for registry lookup."""
        if not doc_number:
            return ""
        norm = doc_number.upper().strip()
        norm = norm.replace("NĐ-CP", "ND-CP").replace("NĐ/CP", "ND-CP")
        norm = re.sub(r'\s+', '', norm)
        return norm

    def verify_document(self, document_title: str, document_number: str, content: str = "") -> Dict[str, Any]:
        """
        Verify if a legal document is valid, active, or superseded.
        
        Returns:
            is_valid (bool)
            status (str): "Verified" | "Outdated" | "Pending"
            notes (str)
        """
        norm_number = self.normalize_doc_number(document_number)
        
        # 1. Check known registry
        matched_info = None
        for key, info in self.LEGAL_REGISTRY.items():
            if key in norm_number or norm_number in key:
                matched_info = info
                break

        if not matched_info and document_title:
            title_upper = document_title.upper()
            for key, info in self.LEGAL_REGISTRY.items():
                if info["title"].upper() in title_upper or key in title_upper:
                    matched_info = info
                    break

        if matched_info:
            return {
                "is_valid": matched_info["is_active"],
                "status": matched_info["status"],
                "notes": matched_info["notes"]
            }

        # 2. Heuristic check on content if not in static registry
        content_lower = (content or "").lower()
        if "hết hiệu lực" in content_lower or "bị bãi bỏ" in content_lower or "bị thay thế" in content_lower:
            return {
                "is_valid": False,
                "status": "Outdated",
                "notes": "Văn bản phát hiện dấu hiệu đã hết hiệu lực hoặc bị thay thế từ nội dung trích xuất."
            }

        if "còn hiệu lực" in content_lower or "đang có hiệu lực" in content_lower:
            return {
                "is_valid": True,
                "status": "Verified",
                "notes": "Văn bản được ghi nhận đang có hiệu lực thi hành."
            }

        # Default fallback if unknown
        return {
            "is_valid": False,
            "status": "Pending",
            "notes": "Văn bản chưa có trong cơ sở dữ liệu xác thực hoặc đang chờ kiểm tra tính pháp lý."
        }

    def verify_chunk(self, chunk: Dict[str, Any]) -> bool:
        """
        Verify if an individual legal chunk is eligible for RAG retrieval.
        Must be active and verified.
        """
        is_verified = chunk.get("is_verified", False)
        is_active = chunk.get("is_active", True)
        
        # Extra check: if document_number belongs to an outdated decree
        doc_num = self.normalize_doc_number(chunk.get("document_number", ""))
        for key, info in self.LEGAL_REGISTRY.items():
            if key in doc_num:
                if not info["is_active"] or info["status"] == "Outdated":
                    return False

        return bool(is_verified and is_active)
