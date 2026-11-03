import importlib.util
import unittest
import uuid
from pathlib import Path

spec = importlib.util.spec_from_file_location('local_bank', Path(__file__).resolve().parents[1] / 'scripts/build-local-learning-bank.py')
local_bank = importlib.util.module_from_spec(spec)
spec.loader.exec_module(local_bank)


class LocalLearningBankTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.package = local_bank.build('http://localhost:8765')

    def test_all_source_questions_have_stable_unique_guids_correct_assets_and_review_urls(self):
        questions = self.package['bank']['questions']
        self.assertEqual([q['number'] for q in questions], list(range(486, 601)))
        self.assertEqual(len(set(q['id'] for q in questions)), 115)
        for q in questions:
            uuid.UUID(q['id'])
            self.assertFalse(q['allowOptionShuffle'])
            self.assertEqual(len(q['correctOptionIds']), 1)
            self.assertIn(q['correctOptionIds'][0], [o['id'] for o in q['options']])
            self.assertTrue(q['assets'])
            self.assertEqual(q['explanationAnimationUrl'], f"http://localhost:8765/q{q['number']}.html")
        self.assertEqual(self.package, local_bank.build('http://localhost:8765/'))

    def test_templates_cover_every_question_exactly_once_with_valid_targets(self):
        templates = self.package['templates']
        self.assertEqual(len(templates), 6)
        ids = [q for t in templates for q in t['questionIds']]
        self.assertEqual(ids, [q['id'] for q in self.package['bank']['questions']])
        self.assertEqual([len(t['questionIds']) for t in templates], [20, 20, 20, 20, 20, 15])
        self.assertEqual([t['passingScore'] for t in templates], [16, 16, 16, 16, 16, 12])

    def test_changing_asset_origin_changes_identity_instead_of_overwriting_imported_bank(self):
        other = local_bank.build('http://localhost:8877')
        self.assertNotEqual(self.package['bank']['id'], other['bank']['id'])
        self.assertFalse(set(q['id'] for q in self.package['bank']['questions']) & set(q['id'] for q in other['bank']['questions']))

    def test_refuses_nonlocal_asset_origins(self):
        for value in ['https://example.org', 'http://example.org', 'http://localhost:8765/path/', 'http://user@localhost:8765']:
            with self.assertRaises(ValueError):
                local_bank.build(value)


if __name__ == '__main__':
    unittest.main()
