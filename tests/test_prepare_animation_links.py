import copy
import importlib.util
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location('links', Path(__file__).resolve().parents[1] / 'scripts/prepare-animation-links.py')
links = importlib.util.module_from_spec(spec)
spec.loader.exec_module(links)


class AnimationLinksTests(unittest.TestCase):
    def setUp(self):
        self.bank_id = '82c71f2d-ea34-4aa2-a0a1-7554d00567a1'
        self.question_id = 'ab62f670-d5e0-44ca-b143-c825403fdb12'
        self.source = {'questions': [{'number': 544, 'prompt': 'Câu hỏi?',
            'options': [{'id': 1, 'text': 'Một'}, {'id': 2, 'text': 'Hai'}],
            'correctOptionIds': [2], 'images': [{'sha256': 'a' * 64}]}]}
        self.bank = {'id': self.bank_id, 'version': '3', 'questions': [{'id': self.question_id,
            'number': 544, 'text': 'Câu hỏi?', 'options': [{'id': 'first', 'text': 'Một'}, {'id': 'second', 'text': 'Hai'}],
            'correctOptionIds': ['second'], 'assets': [{'sha256': 'a' * 64}]}]}
        self.release = {'approvedRevisions': {'544': 'accepted'}}

    def prepare(self, bank=None, bank_id=None, version='3', url='https://animations.example.org/release/'):
        return links.prepare(bank or self.bank, bank_id or self.bank_id, version, url, self.source, self.release)

    def test_maps_real_question_guid_and_version_without_mutating_bank(self):
        before = copy.deepcopy(self.bank)
        manifest = self.prepare()
        self.assertEqual(manifest['animations'], [{'questionId': self.question_id,
            'explanationAnimationUrl': 'https://animations.example.org/release/q544.html'}])
        self.assertEqual(self.bank, before)

    def test_rejects_other_bank_or_version(self):
        for args in ({'version': '4'}, {'bank_id': self.question_id}):
            with self.assertRaises(ValueError):
                self.prepare(**args)

    def test_rejects_same_number_with_different_content_answer_image_or_option_order(self):
        for field, value in [('text', 'Khác'), ('correctOptionIds', ['first']), ('assets', []),
                             ('options', list(reversed(self.bank['questions'][0]['options'])))]:
            bank = copy.deepcopy(self.bank)
            bank['questions'][0][field] = value
            with self.assertRaises(ValueError, msg=field):
                self.prepare(bank=bank)

    def test_rejects_duplicate_numbers_or_ids(self):
        bank = copy.deepcopy(self.bank)
        bank['questions'].append(copy.deepcopy(bank['questions'][0]))
        with self.assertRaises(ValueError):
            self.prepare(bank=bank)

    def test_rejects_local_or_unsafe_hosting_urls(self):
        for url in ['http://localhost:8765/', 'https://localhost/', 'https://example.org/?key=a',
                    'https://example.org/../release/', 'https://example.org/%2e/', 'https://user@example.org/']:
            with self.assertRaises(ValueError, msg=url):
                self.prepare(url=url)

    def test_requires_approved_revision(self):
        self.release['approvedRevisions'] = {}
        with self.assertRaises(ValueError):
            self.prepare()


if __name__ == '__main__':
    unittest.main()
