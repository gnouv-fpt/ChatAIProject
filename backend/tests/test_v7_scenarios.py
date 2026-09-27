import unittest
import asyncio
from backend.app.schemas.chat import ChatRequest
from backend.app.services.rag_engine import rag_engine


class TestV7RequirementsKhoi(unittest.TestCase):
    """
    Comprehensive Test Suite validating all Requirements in requirement_flm_obsidian_chat_v7.md
    specifically assigned to Khôi (Khối D - Backend & Chat AI RAG):
    - Mục 5.1: Hai cấp chat (Curriculum scope & Subject scope)
    - Mục 5.2: Bộ câu hỏi mẫu chuẩn (PE, LOs, Tín chỉ, Học kỳ, Xuất hiện trong)
    - Mục 5.3: Tư vấn chiến lược học tập (Ôn PE, Phân bổ kỳ 5, Nâng GPA 7.4 lên 8.0)
    - Mục 5.4: Câu trả lời động, không kịch bản cứng, từ chối câu hỏi ngoài phạm vi
    - Mục 7.4: Nhận diện và tích hợp dữ kiện bảng điểm (student_context từ Khối E)
    - Mục 2.2 & 11: Module thống kê dùng chung (Curriculum stats, Course presence, Prerequisites check)
    """

    @classmethod
    def setUpClass(cls):
        rag_engine.initialize()

    def run_async(self, coro):
        return asyncio.run(coro)

    # -------------------------------------------------------------
    # 1. Mục 5.2: Bộ câu hỏi mẫu chuẩn
    # -------------------------------------------------------------
    def test_sample_q1_pe_exam_assessment(self):
        """Mục 5.2: Hình thức thi/đánh giá: Môn PRM393 có thi PE không?"""
        req = ChatRequest(
            question="Môn PRM393 có thi PE không?",
            scope="subject",
            id="PRM393",
        )
        resp = self.run_async(rag_engine.answer_query(req))
        self.assertIsNotNone(resp.answer)
        self.assertGreater(len(resp.sources), 0)
        self.assertTrue(
            "pe" in resp.answer.lower() or "thực hành" in resp.answer.lower(),
            "Answer must address Practical Exam",
        )
        self.assertTrue(
            "có" in resp.answer.lower() or "practical exam" in resp.answer.lower(),
            "PRM393 has PE exam",
        )

    def test_sample_q2_learning_outcomes(self):
        """Mục 5.2: Mục tiêu môn học (Learning Outcomes): Mục tiêu của môn PRM393 là gì?"""
        req = ChatRequest(
            question="Mục tiêu của môn học PRM393 là gì?",
            scope="subject",
            id="PRM393",
        )
        resp = self.run_async(rag_engine.answer_query(req))
        self.assertIsNotNone(resp.answer)
        self.assertTrue(
            any(w in resp.answer.lower() for w in ["mục tiêu", "chuẩn đầu ra", "learning outcome", "clo"]),
            "Answer must contain learning outcomes",
        )

    def test_sample_q3_credits(self):
        """Mục 5.2: Số tín chỉ: Trong khung chương trình của tôi, PRM393 có mấy tín chỉ?"""
        req = ChatRequest(
            question="Trong khung chương trình của tôi, PRM393 có mấy tín chỉ?",
            scope="subject",
            id="PRM393",
        )
        resp = self.run_async(rag_engine.answer_query(req))
        self.assertIsNotNone(resp.answer)
        self.assertIn("3", resp.answer, "PRM393 must have 3 credits")

    def test_sample_q4_semester_roadmap(self):
        """Mục 5.2: Kế hoạch học tập: Môn SWD392 học ở học kỳ mấy trong khung này?"""
        req = ChatRequest(
            question="Môn SWD392 học ở học kỳ mấy trong khung này?",
            scope="curriculum",
            id="BIT_SE_K19B",
        )
        resp = self.run_async(rag_engine.answer_query(req))
        self.assertIsNotNone(resp.answer)
        self.assertTrue(
            "7" in resp.answer or "bảy" in resp.answer.lower(),
            "SWD392 is in Semester 7",
        )

    def test_sample_q5_course_presence(self):
        """Mục 5.2: Môn này xuất hiện trong curriculum nào, học kỳ nào?"""
        req = ChatRequest(
            question="Môn PRM393 xuất hiện trong curriculum nào, học kỳ nào?",
            scope="subject",
            id="PRM393",
        )
        resp = self.run_async(rag_engine.answer_query(req))
        self.assertIsNotNone(resp.answer)
        self.assertTrue(
            "BIT_SE_K19B" in resp.answer or "K19B" in resp.answer or "SE" in resp.answer,
            "Must state curriculum code",
        )
        self.assertTrue(
            "8" in resp.answer or "tám" in resp.answer.lower(),
            "Must state semester 8 for PRM393 in BIT_SE_K19B",
        )

    # -------------------------------------------------------------
    # 2. Mục 5.1: Hai cấp chat (Curriculum & Subject)
    # -------------------------------------------------------------
    def test_curriculum_scope_semester_credits(self):
        """Mục 5.1: Chat Curriculum: 'HK5 có bao nhiêu tín chỉ?'"""
        req = ChatRequest(
            question="HK5 có bao nhiêu tín chỉ?",
            scope="curriculum",
            id="BIT_SE_K19B",
        )
        resp = self.run_async(rag_engine.answer_query(req))
        self.assertIsNotNone(resp.answer)
        self.assertIn("15", resp.answer, "HK5 has 5 subjects of 3 credits each = 15 credits")
        self.assertTrue(
            "PRN212" in resp.answer or "SWP391" in resp.answer,
            "Should list HK5 subjects",
        )

    def test_curriculum_scope_total_credits(self):
        """Mục 5.1: Chat Curriculum: 'Chương trình BIT_SE_K19B có bao nhiêu tín chỉ?'"""
        req = ChatRequest(
            question="Tổng số tín chỉ của chương trình là bao nhiêu?",
            scope="curriculum",
            id="BIT_SE_K19B",
        )
        resp = self.run_async(rag_engine.answer_query(req))
        self.assertIsNotNone(resp.answer)
        self.assertIn("145", resp.answer, "BIT_SE_K19B has 145 credits total")

    # -------------------------------------------------------------
    # 3. Mục 5.3: Tư vấn học tập bằng RAG
    # -------------------------------------------------------------
    def test_advising_pe_study_strategy(self):
        """Mục 5.3: 'Môn PRM393 nên học/ôn như thế nào để qua PE?'"""
        req = ChatRequest(
            question="Môn PRM393 nên học ôn như thế nào để qua PE?",
            scope="subject",
            id="PRM393",
        )
        resp = self.run_async(rag_engine.answer_query(req))
        self.assertIsNotNone(resp.answer)
        self.assertTrue(
            any(w in resp.answer.lower() for w in ["chiến lược", "ôn thi", "thực hành", "pe", "code"]),
            "Should offer concrete PE exam advice",
        )

    def test_advising_semester_5_prioritization(self):
        """Mục 5.3: 'Kỳ 5 của tôi có 5 môn, nên ưu tiên và phân bổ thời gian ra sao?'"""
        req = ChatRequest(
            question="Kỳ 5 của tôi có 5 môn, nên ưu tiên và phân bổ thời gian ra sao?",
            scope="curriculum",
            id="BIT_SE_K19B",
        )
        resp = self.run_async(rag_engine.answer_query(req))
        self.assertIsNotNone(resp.answer)
        self.assertIn("SWP391", resp.answer, "Must highlight SWP391 as high priority project")
        self.assertIn("PRN212", resp.answer, "Must include PRN212")

    def test_advising_gpa_improvement_goal(self):
        """Mục 5.3: 'GPA hiện tại của tôi là 7.4, muốn ra trường 8.0 thì cần làm gì từ giờ đến cuối?'"""
        req = ChatRequest(
            question="GPA hiện tại của tôi là 7.4, muốn ra trường 8.0 thì cần làm gì từ giờ đến cuối?",
            scope="curriculum",
            id="BIT_SE_K19B",
        )
        resp = self.run_async(rag_engine.answer_query(req))
        self.assertIsNotNone(resp.answer)
        self.assertTrue(
            "7.4" in resp.answer and "8.0" in resp.answer,
            "Must acknowledge current GPA 7.4 and target 8.0",
        )
        self.assertTrue(
            "hạ bậc" in resp.answer.lower() or "học lại" in resp.answer.lower(),
            "Must mention retake policy regarding honors rank",
        )

    # -------------------------------------------------------------
    # 4. Mục 5.4: Câu trả lời động & từ chối ngoài phạm vi
    # -------------------------------------------------------------
    def test_dynamic_answers_per_subject(self):
        """Mục 5.4: Cùng câu hỏi 'môn này có mấy tín chỉ' ở 2 môn khác nhau phải ra 2 kết quả khác nhau."""
        req_prm = ChatRequest(question="Môn này có mấy tín chỉ?", scope="subject", id="PRM393")
        resp_prm = self.run_async(rag_engine.answer_query(req_prm))

        req_ojt = ChatRequest(question="Môn này có mấy tín chỉ?", scope="subject", id="OJT202")
        resp_ojt = self.run_async(rag_engine.answer_query(req_ojt))

        self.assertIn("3", resp_prm.answer, "PRM393 has 3 credits")
        self.assertIn("10", resp_ojt.answer, "OJT202 has 10 credits")
        self.assertNotEqual(resp_prm.answer, resp_ojt.answer, "Answers must be completely dynamic")

    def test_out_of_scope_rejection(self):
        """Mục 5.4: Với câu hỏi ngoài phạm vi dữ liệu FLM, chat phải nói rõ là không có dữ liệu, không bịa."""
        req = ChatRequest(
            question="Môn nấu ăn học ở kỳ mấy?",
            scope="curriculum",
            id="BIT_SE_K19B",
        )
        resp = self.run_async(rag_engine.answer_query(req))
        self.assertIsNotNone(resp.answer)
        self.assertTrue(
            any(w in resp.answer.lower() for w in ["không tìm thấy", "chưa có", "không có", "ngoài phạm vi"]),
            "Should politely refuse out-of-scope query without hallucinating",
        )

    # -------------------------------------------------------------
    # 5. Mục 7.4: Nhận diện student_context từ Khối E
    # -------------------------------------------------------------
    def test_student_context_integration(self):
        """Mục 7.4: Nhận diện dữ kiện đã tính toán bằng code từ Khối E."""
        context_data = {
            "current_gpa": 7.4,
            "target_gpa": 8.0,
            "retake_count": 1,
            "required_avg_mark": 8.45,
            "is_target_feasible": True,
            "failed_courses": ["PRN212"],
        }
        req = ChatRequest(
            question="Tư vấn chiến lược học tập cho tôi để đạt mục tiêu tốt nghiệp loại Giỏi.",
            scope="curriculum",
            id="BIT_SE_K19B",
            student_context=context_data,
        )
        resp = self.run_async(rag_engine.answer_query(req))
        self.assertIsNotNone(resp.answer)
        self.assertTrue(
            "7.4" in resp.answer or "8.0" in resp.answer or "8.45" in resp.answer,
            "Response should integrate student facts passed from Khối E",
        )

    # -------------------------------------------------------------
    # 6. Mục 2.2 & 11: Module thống kê dùng chung
    # -------------------------------------------------------------
    def test_common_curriculum_stats(self):
        """Mục 2.2 & 11: Thống kê curriculum (số học kỳ, số môn, tổng tín chỉ)."""
        stats = rag_engine.get_curriculum_stats("BIT_SE_K19B")
        self.assertIsNotNone(stats)
        self.assertEqual(stats.curriculum_id, "BIT_SE_K19B")
        self.assertEqual(stats.total_credits, 145)
        self.assertGreaterEqual(stats.total_courses, 40)
        self.assertGreaterEqual(len(stats.semesters), 8)

    def test_common_course_presence(self):
        """Mục 2.2 & 11: Với một môn: xuất hiện trong curriculum nào, ở học kỳ nào."""
        presence = rag_engine.get_course_presence("PRM393")
        self.assertIsInstance(presence, list)
        self.assertGreater(len(presence), 0)
        first = presence[0]
        self.assertEqual(first.get("curriculum"), "BIT_SE_K19B")
        self.assertEqual(first.get("semester"), 8)

    def test_common_prerequisite_check(self):
        """Mục 2.2 & 11: Kiểm tra tiên quyết dựa trên quan hệ prerequisites."""
        # SWD392 requires SWP391 or SWE201c
        swd_detail = rag_engine.get_course_detail("SWD392")
        prereqs = swd_detail.prerequisites if swd_detail else []
        
        # When student has NOT completed prerequisites
        result_fail = rag_engine.check_prerequisites("SWD392", completed_courses=["PRF192", "PRO192"])
        if prereqs:
            self.assertFalse(result_fail.is_satisfied)
            self.assertGreater(len(result_fail.missing_prerequisites), 0)

        # When student HAS completed all prerequisites
        result_pass = rag_engine.check_prerequisites("SWD392", completed_courses=prereqs + ["PRF192"])
        self.assertTrue(result_pass.is_satisfied)
        self.assertEqual(len(result_pass.missing_prerequisites), 0)


if __name__ == "__main__":
    unittest.main()
