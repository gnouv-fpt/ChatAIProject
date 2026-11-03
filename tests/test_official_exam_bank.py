import copy
import importlib.util
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('official_b', ROOT/'scripts/prepare-official-b-bank.py')
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


class OfficialBankTests(unittest.TestCase):
    def test_official_edition_preserves_practice_and_remaps_every_template(self):
        original = json.loads((ROOT/'content-bank/csgt-2025-https/package.json').read_text(encoding='utf8'))
        before = copy.deepcopy(original)
        result = builder.derive(original)
        self.assertEqual(before, original)
        self.assertEqual(result, builder.derive(original))
        self.assertNotEqual(result['bank']['id'], original['bank']['id'])
        self.assertEqual(result['bank']['profile']['passCount'], 27)
        self.assertEqual(result['bank']['profile']['durationSeconds'], 1200)
        self.assertTrue(result['bank']['profile']['failOnCriticalWrong'])
        self.assertFalse(original['bank']['profile']['failOnCriticalWrong'])
        self.assertEqual(original['bank']['profile']['passCount'], 24)
        mapping = {}
        for old, new in zip(original['bank']['questions'], result['bank']['questions']):
            mapping[old['id']] = new['id']
            self.assertNotEqual(old['id'], new['id'])
            self.assertEqual({k:v for k,v in old.items() if k!='id'}, {k:v for k,v in new.items() if k!='id'})
        for old, new in zip(original['templates'], result['templates']):
            self.assertEqual(new['questionIds'], [mapping[qid] for qid in old['questionIds']])
            self.assertEqual((new['durationMinutes'],new['passingScore']), (20,27))
        self.assertEqual(result['evidence']['effectiveUntilExclusive'], '2027-03-01T00:00:00+07:00')


if __name__ == '__main__': unittest.main()
