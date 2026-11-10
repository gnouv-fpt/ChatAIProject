import re
import datetime
import hashlib
from typing import Dict, Any, Optional

class DataVerificationEngine:
    """
    Data Verification Engine for Vietnam Traffic Law RAG System.
    Validates legal status, expiration dates, and amendment relationships between documents
    (e.g., Decree 100/2019/ND-CP vs Decree 123/2021/ND-CP, obsolete decrees 46/2016, 171/2013).
    Enforces that unknown documents default strictly to 'Pending' (not eligible for active retrieval).
    """

    # Knowledge registry of traffic law documents and their status
    LEGAL_REGISTRY: Dict[str, Dict[str, Any]] = {
        "55/VBHN-VPQH": {
            "title": "Luật Trật tự, an toàn giao thông đường bộ · VBHN 55/2026",
            "effective_date": "2026-07-01", "expiration_date": None,
            "status": "Verified", "is_active": True,
            "notes": "Đối chiếu bản hợp nhất Chính phủ ngày 23/03/2026 và nguồn TVPL; "
                     "chỉ kích hoạt những điều đã duyệt trong Content SQL, gồm sửa đổi Luật 118/2025."
        },
        "123/2021/ND-CP": {
            "title": "Nghị định 123/2021/NĐ-CP",
            "effective_date": "2022-01-01",
            "expiration_date": None,
            "status": "Verified",
            "is_active": True,
            "amends": ["100/2019/ND-CP"],
            "notes": "Sửa đổi, bổ sung một số điều của các Nghị định quy định xử phạt vi phạm hành chính trong lĩnh vực hàng hải, giao thông đường bộ, đường sắt; hàng không dân dụng."
        },
        "100/2019/ND-CP": {
            "title": "Nghị định 100/2019/NĐ-CP",
            "effective_date": "2020-01-01",
            "expiration_date": None,
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
            "expiration_date": None,
            "status": "Verified",
            "is_active": True,
            "notes": "Văn bản luật nền tảng. Quốc hội đã thông qua Luật TTATGTĐB 36/2024/QH15 và Luật Đường bộ 35/2024/QH15 hiệu lực từ 01/01/2025."
        },
        "36/2024/QH15": {
            "title": "Luật Trật tự, an toàn giao thông đường bộ 2024",
            "effective_date": "2025-01-01",
            "expiration_date": None,
            "status": "Verified",
            "is_active": True,
            "notes": "Quy định toàn diện về trật tự an toàn giao thông đường bộ từ 01/01/2025."
        }
    }

    # Only the explicitly checked, unchanged points of Articles 6, 7 and 12.
    # The 55-article consolidation still carries a pending legal review and
    # must never become active merely because its text has a known hash.
    TARGETED_168_238_LINES_SHA256 = "0dce3b8559d0730ce587bf0767fac822b6c27d78d2c3bb69fc326f56ba4d1de7"

    @staticmethod
    def _line_set_hash(content: str) -> str:
        lines = sorted(line.strip() for line in content.splitlines() if line.strip())
        return hashlib.sha256("\n".join(lines).encode("utf8")).hexdigest()

    def normalize_doc_number(self, doc_number: str) -> str:
        """Normalize document number string for registry lookup."""
        if not doc_number:
            return ""
        norm = doc_number.upper().strip()
        norm = norm.replace("NĐ-CP", "ND-CP").replace("NĐ/CP", "ND-CP")
        norm = re.sub(r'\s+', '', norm)
        return norm

    def verify_document(
        self,
        document_title: str,
        document_number: str,
        content: str = "",
        effective_date_str: Optional[str] = None,
        expiration_date_str: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Verify if a legal document is valid, active, or superseded.
        
        Returns:
            is_valid (bool)
            status (str): "Verified" | "Outdated" | "Pending"
            notes (str)
        """
        # 1. Date check if expiration_date is explicitly passed
        if expiration_date_str:
            try:
                exp_date = datetime.datetime.fromisoformat(expiration_date_str.replace("Z", "+00:00")).date()
                if exp_date <= datetime.date.today():
                    return {
                        "is_valid": False,
                        "status": "Outdated",
                        "notes": f"Văn bản đã hết hiệu lực từ ngày {expiration_date_str}."
                    }
            except Exception:
                pass

        norm_number = self.normalize_doc_number(document_number)
        if norm_number == "168/2024/ND-CP":
            if datetime.date.today() < datetime.date(2025, 1, 1) or \
                    self._line_set_hash(content) != self.TARGETED_168_238_LINES_SHA256:
                return {"is_valid": False, "status": "Pending",
                        "notes": "Chỉ phạm vi điểm 6/7/12 đã rà soát mới được kích hoạt; bản hợp nhất toàn văn còn chờ duyệt."}
            return {"is_valid": True, "status": "Verified",
                    "notes": "Chỉ các điểm 6/7/12 không đổi theo 238/2026, khớp nguồn đã rà soát; không xác minh toàn văn."}
        
        # 2. Check known registry
        matched_info = None
        for key, info in self.LEGAL_REGISTRY.items():
            if norm_number and key == norm_number:
                matched_info = info
                break

        if matched_info:
            # These old, partly amended texts are not a blanket current-law certificate.
            if norm_number in {"100/2019/ND-CP", "123/2021/ND-CP", "23/2008/QH12", "36/2024/QH15"}:
                return {"is_valid": False, "status": "Pending",
                        "notes": "Cần bản hợp nhất và đối chiếu sửa đổi theo từng phạm vi; không kích hoạt toàn văn cũ."}
            if matched_info.get("effective_date") and datetime.date.fromisoformat(matched_info["effective_date"]) > datetime.date.today():
                return {"is_valid": False, "status": "Pending", "notes": "Văn bản chưa đến ngày hiệu lực."}
            return {
                "is_valid": matched_info["is_active"],
                "status": matched_info["status"],
                "notes": matched_info["notes"]
            }

        # 3. Heuristic check on content if not in static registry
        content_lower = (content or "").lower()
        if "hết hiệu lực" in content_lower or "bị bãi bỏ" in content_lower or "bị thay thế" in content_lower:
            return {
                "is_valid": False,
                "status": "Outdated",
                "notes": "Văn bản phát hiện dấu hiệu đã hết hiệu lực hoặc bị thay thế từ nội dung trích xuất."
            }

        # 4. Strict requirement: Unknown status must default to Pending (cannot assume Verified)
        return {
            "is_valid": False,
            "status": "Pending",
            "notes": "Văn bản chưa có trong cơ sở dữ liệu xác thực hoặc đang chờ kiểm tra tính pháp lý."
        }

    def verify_chunk(self, chunk: Dict[str, Any]) -> bool:
        """
        Verify if an individual legal chunk is eligible for RAG retrieval.
        Must be active and verified. Outdated documents are strictly disqualified.
        """
        is_verified = chunk.get("is_verified", False)
        is_active = chunk.get("is_active", True)
        
        # Extra check: if document_number belongs to an outdated decree
        doc_num = self.normalize_doc_number(chunk.get("document_number", ""))
        if doc_num in {"100/2019/ND-CP", "123/2021/ND-CP", "23/2008/QH12", "36/2024/QH15"}:
            return False
        for key, info in self.LEGAL_REGISTRY.items():
            if key in doc_num:
                if not info["is_active"] or info["status"] == "Outdated":
                    return False

        return bool(is_verified and is_active)
