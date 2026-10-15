import unittest
from types import SimpleNamespace

from backend.app.services.rag_engine import _direct_course_fact_answer


class DirectCourseFactTests(unittest.TestCase):
    def setUp(self):
        self.course = SimpleNamespace(
            code="PRM393", credits=3, prerequisites=["PRO192"], has_pe=True,
            learning_outcomes="CLO1: Build mobile apps", semester=8,
            curriculum="BIT_SE_K19B",
            appears_in=[{"curriculum": "BIT_SE_K19B", "semester": 8}],
        )

    def test_credits_answer_does_not_add_prerequisites(self):
        self.assertEqual(
            _direct_course_fact_answer("PRM393 có bao nhiêu tín chỉ?", self.course, "vi"),
            "PRM393 có 3 tín chỉ.",
        )

    def test_prerequisite_comes_from_structured_course(self):
        self.assertEqual(
            _direct_course_fact_answer("PRM393 có môn tiên quyết nào?", self.course, "vi"),
            "Môn tiên quyết của PRM393 là PRO192.",
        )

    def test_advice_query_still_uses_rag(self):
        self.assertIsNone(
            _direct_course_fact_answer("Tư vấn cách học môn tiên quyết PRM393", self.course, "vi")
        )

    def test_pe_outcomes_and_presence_use_course_fields(self):
        self.assertIn("có thi PE", _direct_course_fact_answer(
            "PRM393 có thi PE không?", self.course, "vi"))
        self.assertIn("CLO1: Build mobile apps", _direct_course_fact_answer(
            "Mục tiêu của môn PRM393 là gì?", self.course, "vi"))
        self.assertIn("HK8", _direct_course_fact_answer(
            "PRM393 xuất hiện trong curriculum nào?", self.course, "vi"))


if __name__ == "__main__":
    unittest.main()
