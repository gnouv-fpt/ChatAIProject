import copy
import importlib.util
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('bank600', ROOT / 'scripts/build-question-bank-600.py')
bank600 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bank600)


class QuestionBank600Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = json.loads((ROOT / 'content-bank/csgt-2025/source-extraction.json').read_text(encoding='utf8'))
        cls.package = bank600.build_package(cls.source)

    def test_missing_answer_image_or_duplicate_source_is_rejected(self):
        for mutation in ('answer', 'image', 'number', 'duplicate'):
            source = copy.deepcopy(self.source)
            if mutation == 'answer': source['questions'][0]['correctOptionIds'] = []
            if mutation == 'image': source['questions'][300]['images'] = []
            if mutation == 'number': source['questions'][1]['number'] = 1
            if mutation == 'duplicate':
                for key in ('prompt', 'options', 'correctOptionIds', 'images'):
                    source['questions'][1][key] = source['questions'][0][key]
            with self.assertRaises(ValueError): bank600.validate_source(source)

    def test_wrong_animation_link_is_rejected(self):
        for index, url in [(0, 'http://localhost:8765/q486.html'), (485, 'http://localhost:8765/q487.html')]:
            package = copy.deepcopy(self.package)
            package['bank']['questions'][index]['explanationAnimationUrl'] = url
            with self.assertRaises(ValueError): bank600.validate_package(package)

    def test_column_options_and_underline_keys_are_kept_separate(self):
        for n, count, key in [(301, 4, 1), (302, 4, 4), (352, 3, 1)]:
            q = self.source['questions'][n-1]
            self.assertEqual([o['id'] for o in q['options']], list(range(1, count+1)))
            self.assertEqual(q['correctOptionIds'], [key])

    def test_source_counts_identity_and_practice_scoring(self):
        self.assertEqual(self.package, bank600.build_package(self.source))
        self.assertEqual([sum(lo <= q['number'] <= hi for q in self.source['questions']) for lo, hi, *_ in bank600.CHAPTERS],
                         [180, 25, 58, 37, 185, 115])
        self.assertEqual(sum(q['isCritical'] for q in self.package['bank']['questions']), 60)
        self.assertFalse(self.package['bank']['profile']['failOnCriticalWrong'])
        self.assertEqual(len(self.package['templates']), 6)
        self.assertTrue(all(t['passingScore'] == 24 for t in self.package['templates']))
        changed = copy.deepcopy(self.source)
        changed['questions'][0]['prompt'] += ' (changed source)'
        self.assertNotEqual(self.package['bank']['id'], bank600.build_package(changed)['bank']['id'])


if __name__ == '__main__':
    unittest.main()
