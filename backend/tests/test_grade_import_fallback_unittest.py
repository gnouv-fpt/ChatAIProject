import io
import unittest
from unittest.mock import AsyncMock, patch

from fastapi import UploadFile

from backend.app.api.v1.endpoints.grade_import import import_grade_images, _merge_and_normalize
from backend.app.services.rag_engine import rag_engine


class GradeImportFallbackTests(unittest.IsolatedAsyncioTestCase):
    async def test_missing_credits_is_flagged_for_confirmation(self):
        rows = _merge_and_normalize([
            {"course_code": "CEA201", "score": 8, "semester": 1, "confidence": 0.99},
        ])
        self.assertEqual(rows[0].credits, 0)
        self.assertLess(rows[0].confidence, 0.8)

    async def test_groq_normalizes_supplied_ocr_text_without_vision(self):
        llm = rag_engine.llm_service
        prompt = "OCR rows: CEA201 | 3 | 8.0"
        output = '[{"course_code":"CEA201","credits":3,"score":8.0}]'
        with patch.object(llm, "get_active_provider", return_value="Groq"), patch.object(
            llm, "_call_groq", AsyncMock(return_value=output)
        ) as groq:
            self.assertEqual(await llm.call_text_extraction(prompt), output)
        groq.assert_awaited_once_with("", "", extraction_prompt=prompt)

    async def test_vision_is_used_even_when_ocr_can_read_some_text(self):
        image = UploadFile(file=io.BytesIO(b"image bytes"), filename="grade.jpg")
        vision = AsyncMock(return_value='[{"course_code":"PRM393","score":8.5,"semester":8,"credits":3,"status":"passed","confidence":0.9}]')

        with patch("backend.app.api.v1.endpoints.grade_import.extract_text") as ocr, patch.object(
            rag_engine.llm_service, "call_vision", vision
        ):
            result = await import_grade_images([image])

        self.assertEqual(result.total_rows, 1)
        vision.assert_awaited_once()
        ocr.assert_not_called()

    async def test_out_of_range_score_is_not_silently_clamped(self):
        rows = _merge_and_normalize([
            {"course_code": "PRM393", "score": 87, "semester": 8},
        ])
        self.assertEqual(rows, [])

    async def test_vision_reads_image_when_ocr_has_no_text(self):
        image = UploadFile(file=io.BytesIO(b"image bytes"), filename="grade.jpg")
        image.headers = {"content-type": "image/jpeg"}
        vision = AsyncMock(return_value='[{"course_code":"PRM393","score":8.5,"semester":8,"credits":3,"status":"passed","confidence":0.9}]')

        with patch(
            "backend.app.api.v1.endpoints.grade_import.extract_text",
            return_value="",
        ), patch.object(rag_engine.llm_service, "call_vision", vision):
            result = await import_grade_images([image])

        self.assertEqual(len(result.entries), 1)
        self.assertEqual(result.entries[0].course_code, "PRM393")
        self.assertEqual(result.entries[0].score, 8.5)
        vision.assert_awaited_once()


if __name__ == "__main__":
    unittest.main()
