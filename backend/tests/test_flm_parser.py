import unittest
from pathlib import Path
from backend.app.services.flm_parser import FLMKnowledgeVaultParser
from backend.app.config import settings


class TestFLMParser(unittest.TestCase):
    def setUp(self):
        self.vault_path = settings.get_vault_path()
        self.json_path = settings.get_courses_data_path()
        self.parser = FLMKnowledgeVaultParser(self.vault_path, self.json_path)

    def test_load_all_courses(self):
        courses, chunks = self.parser.load_all()
        self.assertGreater(len(courses), 40, "Should load at least 40 courses from vault")
        self.assertGreater(len(chunks), 100, "Should generate structured chunks from vault")

    def test_parse_prm393(self):
        courses, _ = self.parser.load_all()
        self.assertIn("PRM393", courses)
        prm = courses["PRM393"]
        self.assertEqual(prm.code, "PRM393")
        self.assertEqual(prm.credits, 3)
        self.assertEqual(prm.semester, 8)
        self.assertIn("PRO192", prm.prerequisites)
        self.assertIsNotNone(prm.assessment_scheme)
        self.assertTrue(len(prm.assessment_scheme) > 0)

    def test_parse_swd392(self):
        courses, _ = self.parser.load_all()
        self.assertIn("SWD392", courses)
        swd = courses["SWD392"]
        self.assertEqual(swd.code, "SWD392")
        self.assertEqual(swd.credits, 3)
        self.assertEqual(swd.semester, 7)
        self.assertIn("PRO192", swd.prerequisites)


if __name__ == "__main__":
    unittest.main()
