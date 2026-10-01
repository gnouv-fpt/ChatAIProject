import unittest
import asyncio
from backend.app.schemas.chat import ChatRequest
from backend.app.services.rag_engine import rag_engine


class TestRAGPipeline(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        rag_engine.initialize()

    def run_async(self, coro):
        return asyncio.run(coro)

    def test_sample_q1_pe_exam(self):
        """Kịch bản mẫu 1: Hình thức thi/đánh giá: Môn PRM392/PRM393 có thi PE hay không?"""
        req = ChatRequest(question="Môn PRM393 có thi PE (Practical Exam) hay không?")
        resp = self.run_async(rag_engine.answer_query(req))

        self.assertIsNotNone(resp.answer)
        self.assertGreater(len(resp.sources), 0)
        self.assertTrue(
            "PE" in resp.answer or "Practical Exam" in resp.answer or "thực hành" in resp.answer.lower(),
            "Response must address Practical Exam",
        )
        self.assertIn("PRM393", resp.matched_courses)

    def test_sample_q2_learning_outcomes(self):
        """Kịch bản mẫu 2: Mục tiêu môn học (Learning Outcomes): Mục tiêu của môn PRM393 là gì?"""
        req = ChatRequest(question="Mục tiêu của môn học PRM393 là gì?")
        resp = self.run_async(rag_engine.answer_query(req))

        self.assertIsNotNone(resp.answer)
        self.assertGreater(len(resp.sources), 0)
        self.assertTrue(
            "mục tiêu" in resp.answer.lower() or "chuẩn đầu ra" in resp.answer.lower() or "learning outcome" in resp.answer.lower() or "clo" in resp.answer.lower(),
            "Response must contain learning outcomes",
        )

    def test_sample_q3_credits(self):
        """Kịch bản mẫu 3: Số tín chỉ: Trong khung chương trình của tôi, môn PRM393 có mấy tín chỉ?"""
        req = ChatRequest(question="Trong khung chương trình của tôi, môn PRM393 có mấy tín chỉ?")
        resp = self.run_async(rag_engine.answer_query(req))

        self.assertIsNotNone(resp.answer)
        self.assertIn("3", resp.answer, "PRM393 should be 3 credits")
        self.assertGreater(len(resp.sources), 0)

    def test_sample_q4_semester_roadmap(self):
        """Kịch bản mẫu 4: Kế hoạch học tập: Môn SWD392 học ở học kỳ mấy?"""
        req = ChatRequest(question="Môn SWD392 học ở học kỳ mấy?")
        resp = self.run_async(rag_engine.answer_query(req))

        self.assertIsNotNone(resp.answer)
        self.assertTrue(
            "7" in resp.answer or "bảy" in resp.answer.lower(),
            "SWD392 is in Semester 7",
        )
        self.assertIn("SWD392", resp.matched_courses)

    def test_semester_question_uses_only_curriculum_courses(self):
        """A vague semester question must not be delegated to free-form LLM text."""
        resp = self.run_async(
            rag_engine.answer_query(ChatRequest(question="Kỳ 7 nên tập trung vào những môn nào?"))
        )

        self.assertEqual(resp.provider, "FLM-Structured-Synthesizer")
        self.assertIn("PMG201c", resp.answer)
        self.assertNotIn("Kinh tế lượng", resp.answer)
        self.assertNotIn("Quản trị doanh nghiệp", resp.answer)
        self.assertNotIn("Tài chính công ty", resp.answer)

    def test_unknown_subject_is_rejected_without_hallucination(self):
        """A subject absent from BIT_SE_K19B must not receive invented advice."""
        resp = self.run_async(
            rag_engine.answer_query(ChatRequest(question="Môn Kinh tế lượng có khó không?"))
        )

        self.assertEqual(resp.provider, "FLM-Structured-Synthesizer")
        self.assertIn("không xác định được môn học", resp.answer.lower())
        self.assertNotIn("Toán đại cương", resp.answer)


if __name__ == "__main__":
    unittest.main()
