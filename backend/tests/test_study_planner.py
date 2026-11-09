import unittest
import asyncio
from types import SimpleNamespace

from backend.app.services.study_planner import build_study_plan_facts, next_semester_answer
from backend.app.services.rag_engine import RAGEngine
from backend.app.schemas.chat import ChatRequest


class StudyPlannerTests(unittest.TestCase):
    def setUp(self):
        self.courses = {
            "BASE": SimpleNamespace(code="BASE", semester=1, name_vi="Nền tảng", name_en="Base", prerequisites=[]),
            "PRM392": SimpleNamespace(code="PRM392", semester=2, name_vi="Lập trình", name_en="Programming", prerequisites=["BASE"]),
            "PRM393": SimpleNamespace(code="PRM393", semester=3, name_vi="Lập trình di động", name_en="Mobile", prerequisites=["PRM392"]),
        }

    def test_plan_uses_verified_prerequisite_chain_and_transcript(self):
        facts = build_study_plan_facts(
            "Tao muốn học PRM393 từ đầu",
            self.courses,
            detected_courses=["PRM393"],
            student_context={"completed_courses": ["BASE"]},
        )
        self.assertIn("BASE → PRM392 → PRM393", facts)
        self.assertIn("PRM392", facts)
        self.assertIn("chưa có trong bảng điểm", facts)

    def test_non_planning_question_does_not_add_planner_facts(self):
        facts = build_study_plan_facts(
            "PRM393 có bao nhiêu tín chỉ?",
            self.courses,
            detected_courses=["PRM393"],
        )
        self.assertEqual(facts, "")

    def test_next_semester_requires_transcript_and_classifies_missing_prerequisites(self):
        question = "Kỳ tới tôi có thể học môn nào?"
        without_transcript = next_semester_answer(question, self.courses, {})
        self.assertIn("Chưa xác định học kỳ", without_transcript)
        blocked = next_semester_answer(question, self.courses, {
            "current_semester": 2, "completed_courses": ["BASE"],
        })
        self.assertIn("Còn thiếu tiên quyết: PRM393 (PRM392)", blocked)
        ready = next_semester_answer(question, self.courses, {
            "current_semester": 2, "completed_courses": ["BASE", "PRM392"],
        })
        self.assertIn("Đủ tiên quyết: PRM393", ready)

    def test_chat_route_answers_next_semester_from_structured_facts(self):
        engine = RAGEngine.__new__(RAGEngine)
        engine.courses = self.courses
        engine.vector_store = SimpleNamespace(
            extract_target_courses=lambda question: [],
            detect_query_intent=lambda question: [],
        )
        response = asyncio.run(engine.answer_query(ChatRequest(
            question="Kỳ tới tôi có thể học môn nào?",
            scope="curriculum",
            id="TEST",
            student_context={"current_semester": 2, "completed_courses": ["BASE", "PRM392"]},
        )))
        self.assertIn("Đủ tiên quyết: PRM393", response.answer)
        self.assertIn("PRM393.md", response.sources[1])
        self.assertEqual(response.provider, "FLM-Structured-Synthesizer")


if __name__ == "__main__":
    unittest.main()
