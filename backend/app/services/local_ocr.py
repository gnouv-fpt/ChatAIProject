"""Fast, local OCR for transcript images with table-aware row clustering.

This intentionally does not call a vision LLM. OCR text is structured into table rows
and normalized by the text model for high accuracy and fast processing.
"""
from typing import List, Optional


class LocalOCR:
    def __init__(self) -> None:
        try:
            from rapidocr_onnxruntime import RapidOCR
        except ImportError as exc:
            raise RuntimeError(
                "Chưa cài RapidOCR. Chạy: pip install rapidocr_onnxruntime"
            ) from exc
        self._engine = RapidOCR()

    def extract_text(self, image_bytes: bytes) -> str:
        import cv2
        import numpy as np

        image = cv2.imdecode(np.frombuffer(image_bytes, dtype=np.uint8), cv2.IMREAD_COLOR)
        if image is None:
            raise ValueError("Ảnh không đọc được hoặc không đúng định dạng.")

        height, width = image.shape[:2]
        max_width = 1800
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
            formatted_rows.append(row_text)

        return "\n".join(formatted_rows)


_ocr: Optional[LocalOCR] = None


def extract_text(image_bytes: bytes) -> str:
    global _ocr
    if _ocr is None:
        _ocr = LocalOCR()
    return _ocr.extract_text(image_bytes)
