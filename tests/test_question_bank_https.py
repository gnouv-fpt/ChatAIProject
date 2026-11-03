import copy
import importlib.util
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('https_bank', ROOT / 'scripts/prepare-question-bank-https.py')
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


class HttpsEditionTests(unittest.TestCase):
    def test_identity_mapping_and_source_preservation(self):
        source = json.loads((ROOT / 'content-bank/csgt-2025/package.json').read_text(encoding='utf8'))
        original = copy.deepcopy(source)
        result = builder.derive(source)
        self.assertEqual(source, original)
        self.assertEqual(result, builder.derive(source))
        self.assertNotEqual(result['bank']['id'], source['bank']['id'])
        self.assertEqual(result['bank']['version'], '1')
        self.assertEqual(result['bank']['profile'], source['bank']['profile'])
        mapping = {}
        for old, new in zip(source['bank']['questions'], result['bank']['questions']):
            mapping[old['id']] = new['id']
            self.assertNotEqual(old['id'], new['id'])
            normalized = copy.deepcopy(new)
            normalized['id'] = old['id']
            for asset in normalized['assets']:
                self.assertTrue(asset['url'].startswith(builder.ORIGIN + '/'))
                asset['url'] = asset['url'].replace(builder.ORIGIN, builder.LOCAL, 1)
            if old['number'] < 486:
                self.assertIsNone(new['explanationAnimationUrl'])
            else:
                self.assertEqual(new['explanationAnimationUrl'], f"{builder.ORIGIN}/q{old['number']}.html")
                normalized['explanationAnimationUrl'] = old['explanationAnimationUrl']
            self.assertEqual(normalized, old)
        for old, new in zip(source['templates'], result['templates']):
            self.assertNotEqual(new['examCode'], old['examCode'])
            self.assertEqual(new['questionIds'], [mapping[qid] for qid in old['questionIds']])
            self.assertEqual(new['passingScore'], old['passingScore'])
            self.assertEqual(new['durationMinutes'], old['durationMinutes'])
        changed = copy.deepcopy(source)
        changed['bank']['questions'][0]['text'] += ' changed'
        self.assertNotEqual(builder.derive(changed)['bank']['id'], result['bank']['id'])
        changed = copy.deepcopy(source)
        changed['bank']['questions'][485]['explanationAnimationUrl'] = 'https://other.example/q486.html'
        with self.assertRaises(ValueError):
            builder.derive(changed)


if __name__ == '__main__':
    unittest.main()
