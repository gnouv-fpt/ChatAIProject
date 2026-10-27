"""Fast, local OCR for transcript images with table-aware row clustering.

This intentionally does not call a vision LLM. OCR text is structured into table rows
and normalized by the text model for high accuracy and fast processing.
"""
import re
from typing import List, Optional


class LocalOCR:
    def __init__(self) -> None:
        try:
            from rapidocr_onnxruntime import RapidOCR
        except ImportError as exc:
            raise RuntimeError(
                "Chưa cài RapidOCR. Chạy: pip install rapidocr_onnxruntime"
            ) from exc
        self._engine = RapidOCR(
            det_model_path=None, det_limit_side_len=2200, det_limit_type="max"
        )
        self._digit_engine = RapidOCR(use_text_det=False, text_score=0)

    def _read_cell_number(self, image, center_x: float, center_y: float) -> Optional[int]:
        """Read an isolated small digit that the table text detector may omit."""
        import cv2
        import numpy as np

        x, y = round(center_x), round(center_y)
        crop = image[max(0, y - 15): y + 18, max(0, x - 13): x + 13]
        if crop.size == 0:
            return None
        enlarged = cv2.resize(crop, None, fx=4, fy=4, interpolation=cv2.INTER_CUBIC)
        result, _ = self._digit_engine(enlarged)
        if result:
            raw = str(result[0][1]).strip().translate(str.maketrans("０１２３４５６７８９", "0123456789"))
            confidence = float(result[0][2])
            if raw.lower() in ("o", "〇") and confidence >= 0.3:
                return 0
            if re.fullmatch(r"\d{1,2}", raw) and confidence >= 0.3:
                return int(raw)
        # Thin '1' glyphs often return an empty recognizer result. Accept one
        # narrow, tall connected component only inside the known numeric cell.
        gray = cv2.cvtColor(crop, cv2.COLOR_BGR2GRAY)
        _, binary = cv2.threshold(gray, 180, 255, cv2.THRESH_BINARY_INV)
        count, _, stats, _ = cv2.connectedComponentsWithStats(binary)
        glyphs = [s for s in stats[1:count] if s[4] >= 8 and s[3] >= 12]
        if len(glyphs) == 1 and glyphs[0][2] <= 7:
            return 1
        return None

    def _read_cell_score(self, image, center_x: float, center_y: float) -> Optional[float]:
        import cv2

        x, y = round(center_x), round(center_y)
        crop = image[max(0, y - 16): y + 19, max(0, x - 24): x + 24]
        if crop.size == 0:
            return None
        enlarged = cv2.resize(crop, None, fx=3, fy=3, interpolation=cv2.INTER_CUBIC)
        result, _ = self._digit_engine(enlarged)
        if not result or float(result[0][2]) < 0.5:
            return None
        raw = str(result[0][1]).strip().replace(",", ".")
        if re.fullmatch(r"\d{2}", raw):
            raw = f"{raw[0]}.{raw[1]}"
        if not re.fullmatch(r"\d{1,2}(?:\.\d)?", raw):
            return None
        score = float(raw)
        return score if 0 <= score <= 10 else None

    def extract_text(self, image_bytes: bytes) -> str:
        import cv2
        import numpy as np

        image = cv2.imdecode(np.frombuffer(image_bytes, dtype=np.uint8), cv2.IMREAD_COLOR)
        if image is None:
            raise ValueError("Ảnh không đọc được hoặc không đúng định dạng.")

        height, width = image.shape[:2]
        max_width = 2200
        if width > max_width:
            scale = max_width / width
            image = cv2.resize(image, (max_width, max(1, int(height * scale))), interpolation=cv2.INTER_AREA)

        result, _ = self._engine(image)
        if not result:
            return ""

        raw_items = []
        for item in result:
            box, text, score = item
            if float(score) < 0.35 or not str(text).strip():
                continue
            top = min(point[1] for point in box)
            bottom = max(point[1] for point in box)
            left = min(point[0] for point in box)
            right = max(point[0] for point in box)
            center_y = (top + bottom) / 2.0
            h = max(1.0, float(bottom - top))
            raw_items.append({
                "top": top,
                "bottom": bottom,
                "left": left,
                "right": right,
                "center_y": center_y,
                "height": h,
                "text": str(text).strip(),
            })

        if not raw_items:
            return ""

        header = {item["text"].upper(): item for item in raw_items if item["center_y"] < height * 0.12}
        ky_header = next((v for k, v in header.items() if k in ("KY", "KỲ")), None)
        credit_header = next((v for k, v in header.items() if "TIN CHI" in k or "TÍN CHỈ" in k), None)
        code_header = next((v for k, v in header.items() if "MA MON" in k or "MÃ MÔN" in k), None)
        score_header = next((v for k, v in header.items() if "DIEM" in k or "ĐIỂM" in k), None)
        numeric_cells = {}
        if ky_header and credit_header and code_header:
            for item in raw_items:
                if not re.fullmatch(r"[A-Za-z]{2,6}\d{3}[A-Za-z]?", item["text"]):
                    continue
                row_y = item["center_y"]
                semester = self._read_cell_number(image, (ky_header["left"] + ky_header["right"]) / 2 - 1.5, row_y)
                credits = self._read_cell_number(image, (credit_header["left"] + credit_header["right"]) / 2 + 2, row_y)
                score = None
                if score_header:
                    score = self._read_cell_score(image, (score_header["left"] + score_header["right"]) / 2, row_y)
                numeric_cells[id(item)] = (semester, credits, score)

        # Estimate typical line height
        median_height = float(np.median([item["height"] for item in raw_items]))
        y_tolerance = max(8.0, median_height * 0.6)

        # Sort all items by vertical position first
        raw_items.sort(key=lambda x: x["center_y"])

        # Group items into table rows based on vertical overlap tolerance
        rows = []
        for item in raw_items:
            placed = False
            for row in rows:
                row_avg_y = sum(x["center_y"] for x in row) / len(row)
                if abs(item["center_y"] - row_avg_y) <= y_tolerance:
                    row.append(item)
                    placed = True
                    break
            if not placed:
                rows.append([item])

        # Sort each row horizontally (left to right)
        formatted_rows = []
        for row in rows:
            row.sort(key=lambda x: x["left"])
            row_text = "  |  ".join(x["text"] for x in row)
            for item in row:
                if id(item) in numeric_cells:
                    semester, credits, score = numeric_cells[id(item)]
                    if semester is not None:
                        row_text += f"  |  KỲ={semester}"
                    if credits is not None:
                        row_text += f"  |  TÍN CHỈ={credits}"
                    if score is not None:
                        row_text += f"  |  ĐIỂM={score}"
            formatted_rows.append(row_text)

        return "\n".join(formatted_rows)


_ocr: Optional[LocalOCR] = None


def extract_text(image_bytes: bytes) -> str:
    global _ocr
    if _ocr is None:
        _ocr = LocalOCR()
    return _ocr.extract_text(image_bytes)
