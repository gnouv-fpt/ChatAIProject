import unittest
from backend.app.services.flm_parser import FLMKnowledgeVaultParser
from backend.app.services.vector_store import HybridVectorStore
from backend.app.config import settings


class TestVectorStore(unittest.TestCase):
    def setUp(self):
        vault_path = settings.get_vault_path()
        json_path = settings.get_courses_data_path()
        self.parser = FLMKnowledgeVaultParser(vault_path, json_path)
        _, self.chunks = self.parser.load_all()
        self.vector_store = HybridVectorStore()
        self.vector_store.index_chunks(self.chunks)

    def test_extract_target_courses(self):
        codes = self.vector_store.extract_target_courses("Môn PRM392 có thi PE không?")
        self.assertTrue("PRM393" in codes or "PRM392" in codes)

        codes2 = self.vector_store.extract_target_courses("Học kỳ mấy thì học SWD392 và PRN212?")
        self.assertIn("SWD392", codes2)
        self.assertIn("PRN212", codes2)

    def test_intent_detection(self):
        intents_pe = self.vector_store.detect_query_intent("Hình thức thi PE của môn PRM393")
        self.assertIn("assessment", intents_pe)

        intents_lo = self.vector_store.detect_query_intent("Mục tiêu môn học Learning outcomes")
        self.assertIn("outcomes", intents_lo)

        intents_credit = self.vector_store.detect_query_intent("Môn này có mấy tín chỉ?")
        self.assertIn("overview", intents_credit)

    def test_search_relevance(self):
        results = self.vector_store.search("Môn PRM393 có thi PE hay không?", top_k=3)
        self.assertGreater(len(results), 0)
        top_chunk, score = results[0]
        self.assertEqual(top_chunk.course_code, "PRM393")
        self.assertIn(top_chunk.category, ["assessment", "overview"])


if __name__ == "__main__":
    unittest.main()
