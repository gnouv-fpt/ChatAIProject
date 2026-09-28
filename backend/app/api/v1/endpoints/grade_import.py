"""
Endpoint: POST /api/v1/import-grade
Nhận 1 hoặc nhiều ảnh bảng điểm, dùng vision LLM trích xuất JSON
theo schema { course_code, score, semester, status, confidence }.
Ảnh chỉ gửi lên để xử lý, không lưu trên server (Mục 8.2).
"""
import base64
import logging
import re
from typing import List

from fastapi import APIRouter, File, UploadFile, HTTPException, status
from pydantic import BaseModel, Field

from ....services.rag_engine import rag_engine

logger = logging.getLogger(__name__)
router = APIRouter()


class TranscriptRow(BaseModel):
    course_code: str = Field(..., description="Mã môn học (đã chuẩn hóa: hoa, bỏ khoảng trắng)")
    score: float = Field(..., description="Điểm tổng kết thang 10")
    credits: int = Field(3, description="Số tín chỉ (mặc định 3 nếu không đọc được)")
    semester: int = Field(1, description="Học kỳ (mặc định 1 nếu không đọc được)")
    status: str = Field("unknown", description="passed | failed | in_progress | unknown")
    confidence: float = Field(1.0, ge=0.0, le=1.0, description="Độ tin cậy của dòng (0..1)")


class ImportGradeResponse(BaseModel):
    entries: List[TranscriptRow]
    total_images: int
    total_rows: int
    low_confidence_count: int
    warning: str = ""


_VISION_SYSTEM_PROMPT = """
You are an OCR assistant extracting transcript data from Vietnamese university grade sheets.
Given one or more images of a grade transcript, extract ALL visible course rows.

Return ONLY a valid JSON array with this exact schema per row:
[
  {
    "course_code": "PRM393",
    "score": 8.5,
    "credits": 3,
    "semester": 6,
    "status": "passed",
    "confidence": 0.95
  },
  ...
]

Rules:
- This is a wide transcript table. Map the numeric column headed "KỲ" to semester.
  Do NOT use the adjacent date/term column headed "Học kỳ" as the semester number.
- Read rows left-to-right using the headers: STT, KỲ, Học kỳ, MÃ MÔN,
  TIÊN QUYẾT, MÔN THAY THẾ, TÊN MÔN, TÍN CHỈ, ĐIỂM, TRẠNG THÁI.
- course_code: uppercase, no spaces, use ASCII D instead of Vietnamese Đ.
- score: float 0-10. If written as comma-separated (e.g. "8,5") convert to 8.5.
- credits: integer. If the table visibly says 0, preserve 0. If not visible, use 0
  and lower confidence; never invent 3 credits.
- semester: integer from the numeric "KỲ" column. If not visible, use 0 and lower confidence.
- status: "passed" for Vietnamese "Đạt" or equivalent, "failed" for "Không đạt",
  "in_progress" if no final score yet.
- confidence: float 0-1. Lower for blurry, rotated, or ambiguous rows.
- Skip header rows, total rows, and non-course rows.
- If a course appears multiple times (retake), include ALL rows — do not deduplicate.
- Output ONLY the JSON array, no markdown fences, no explanations.
"""

_VISION_RETRY_PROMPT = _VISION_SYSTEM_PROMPT + """

The first pass may miss wide screenshots. Perform a second careful pass:
read every visible row even when the table is horizontally wide, and return
the JSON array with no commentary. The column KỲ is the numeric semester.
"""


def _normalize_code(raw: str) -> str:
    """Chuẩn hóa mã môn: hoa, bỏ khoảng trắng, Ð→D (ASCII cho tiền xử lý backend)."""
    return raw.strip().upper().replace(" ", "").replace("Đ", "D").replace("Ð", "D")


def _parse_vision_response(raw_text: str) -> List[dict]:
    """Trích JSON array từ phản hồi LLM (có thể có text thừa hoặc markdown fence)."""
    text = raw_text.strip()
    # Bỏ markdown fences nếu có
    text = re.sub(r"```(?:json)?", "", text).strip()
    # Tìm JSON array đầu tiên
    start = text.find("[")
    end = text.rfind("]")
    if start == -1 or end == -1 or end < start:
        return []
    import json
    try:
        parsed = json.loads(text[start : end + 1])
        if isinstance(parsed, dict):
            return parsed.get("entries") or parsed.get("rows") or []
        return parsed if isinstance(parsed, list) else []
    except Exception:
        return []


def _merge_and_normalize(rows: List[dict]) -> List[TranscriptRow]:
    """
    Hậu xử lý bằng code (Mục 7.1 bước 3):
    - Chuẩn hóa mã môn
    - Chuẩn hóa số điểm (dấu phẩy → dấu chấm)
    - Loại dòng trùng TRONG CÙNG ẢNH (cùng mã + HK + điểm) nhưng GIỮ các lần học khác nhau
    """
    seen: set = set()
    result: List[TranscriptRow] = []
    for row in rows:
        try:
            code = _normalize_code(str(row.get("course_code", "")))
            if not code:
                continue
            score_raw = str(row.get("score", "0")).replace(",", ".")
            score = max(0.0, min(10.0, float(score_raw)))
            credits = int(row.get("credits", 0) or 0)
            semester = int(row.get("semester", 0) or 0)
            status_val = str(row.get("status", "unknown")).strip().lower()
            if status_val in ("đạt", "dat", "pass", "passed"):
                status_val = "passed"
            elif status_val in ("không đạt", "khong dat", "fail", "failed"):
                status_val = "failed"
            if status_val not in ("passed", "failed", "in_progress", "unknown"):
                status_val = "passed" if score >= 5.0 else "failed"
            confidence = float(row.get("confidence", 1.0))

            # Dedup: cùng mã + HK + điểm → skip (trùng từ nhiều ảnh)
            dedup_key = (code, semester, round(score, 1))
            if dedup_key in seen:
                continue
            seen.add(dedup_key)

            result.append(
                TranscriptRow(
                    course_code=code,
                    score=score,
                    credits=credits,
                    semester=semester,
                    status=status_val,
                    confidence=confidence,
                )
            )
        except Exception as exc:
            logger.warning("Skipping malformed row %s: %s", row, exc)
    return result


@router.post(
    "/import-grade",
    response_model=ImportGradeResponse,
    status_code=status.HTTP_200_OK,
    summary="Import bảng điểm từ ảnh (Vision LLM)",
    description=(
        "Nhận 1 hoặc nhiều ảnh bảng điểm (screenshot, ảnh điện thoại, bảng giấy...). "
        "Gửi cho vision LLM để trích xuất JSON. Ảnh không được lưu trên server. "
        "Kết quả trả về để Flutter hiển thị màn xác nhận/sửa tay (Mục 7.1)."
    ),
)
async def import_grade_images(
    images: List[UploadFile] = File(..., description="Một hoặc nhiều ảnh bảng điểm"),
) -> ImportGradeResponse:
    if not images:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cần ít nhất 1 ảnh.")
    if len(images) > 10:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Tối đa 10 ảnh mỗi lần import.")

    all_rows: List[dict] = []
    errors: List[str] = []
    total_images = len(images)

    for img_file in images:
        try:
            content_type = img_file.content_type or "image/jpeg"
            raw_bytes = await img_file.read()
            # Ảnh không lưu — chỉ đọc bytes để gửi LLM rồi bỏ
            b64 = base64.b64encode(raw_bytes).decode("utf-8")

            # Gọi vision LLM qua llm_service
            vision_response = await rag_engine.llm_service.call_vision(
                system_prompt=_VISION_SYSTEM_PROMPT,
                image_b64=b64,
                mime_type=content_type,
            )
            rows = _parse_vision_response(vision_response)
            if not rows:
                logger.warning("Vision returned no rows for '%s'; retrying wide-table OCR", img_file.filename)
                retry_response = await rag_engine.llm_service.call_vision(
                    system_prompt=_VISION_RETRY_PROMPT,
                    image_b64=b64,
                    mime_type=content_type,
                )
                rows = _parse_vision_response(retry_response)
            all_rows.extend(rows)
            logger.info("Parsed %d rows from image '%s'", len(rows), img_file.filename)
        except Exception as exc:
            logger.error("Error processing image '%s': %s", img_file.filename, exc, exc_info=True)
            errors.append(f"{img_file.filename}: {exc}")
            # Tiếp tục xử lý ảnh khác, không dừng toàn bộ request

    entries = _merge_and_normalize(all_rows)
    low_conf = sum(1 for e in entries if e.confidence < 0.8)
    warning = ""
    if not entries:
        warning = "Không đọc được dòng nào từ ảnh. Hãy thử ảnh rõ hơn hoặc gửi ảnh có độ phân giải lớn hơn trong chat."
        if errors:
            warning += " Chi tiết: " + " | ".join(errors[:2])
    elif low_conf > 0:
        warning = f"{low_conf} dòng có độ tin cậy thấp (được đánh dấu vàng). Vui lòng kiểm tra và sửa tay trước khi lưu."

    return ImportGradeResponse(
        entries=entries,
        total_images=total_images,
        total_rows=len(entries),
        low_confidence_count=low_conf,
        warning=warning,
    )
