"""Fast, local OCR for transcript images.

This intentionally does not call a vision LLM.  OCR text is later normalized
by the configured text model, so the expensive multimodal model is not needed
for the grade-import path.
"""

from typing import List


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

        # Smaller input is considerably faster on CPU while retaining enough
        # detail for transcript text and table cells.
        height, width = image.shape[:2]
        max_width = 1800
        if width > max_width:
            scale = max_width / width
            image = cv2.resize(image, (max_width, max(1, int(height * scale))), interpolation=cv2.INTER_AREA)

        result, _ = self._engine(image)
        if not result:
            return ""

        lines = []
        for item in result:
            box, text, score = item
            if float(score) < 0.35 or not str(text).strip():
                continue
            top = min(point[1] for point in box)
            left = min(point[0] for point in box)
            lines.append((top, left, str(text).strip()))

        # Preserve the visual reading order for the text model.
        lines.sort(key=lambda value: (value[0], value[1]))
        return "\n".join(text for _, _, text in lines)


_ocr: LocalOCR | None = None


def extract_text(image_bytes: bytes) -> str:
    global _ocr
    if _ocr is None:
        _ocr = LocalOCR()
    return _ocr.extract_text(image_bytes)
