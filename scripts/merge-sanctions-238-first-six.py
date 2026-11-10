"""Apply the first six amendment articles to their exact 168/2024 units, for review."""
import hashlib
import importlib.util
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LEGAL = ROOT / 'content-bank/legal'


def source_module():
    spec = importlib.util.spec_from_file_location('source168', ROOT / 'scripts/prepare-reviewed-sanctions-168.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def selected_span(lines, clause, point=None):
    header = re.compile(rf'^{re.escape(str(clause))}\.\s')
    starts = [i for i, line in enumerate(lines) if header.match(line)]
    if len(starts) != 1:
        raise ValueError(f'Expected one clause {clause}, got {len(starts)}')
    begin = starts[0]
    end = next((i for i in range(begin + 1, len(lines)) if re.match(r'^\d+[a-zđ]?\.\s', lines[i])), len(lines))
    if point is None:
        return begin, end
    header = re.compile(rf'^{re.escape(point)}\)\s')
    starts = [i for i in range(begin + 1, end) if header.match(lines[i])]
    if len(starts) != 1:
        raise ValueError(f'Expected one point {point} in clause {clause}, got {len(starts)}')
    begin = starts[0]
    end = next((i for i in range(begin + 1, end) if re.match(r'^[a-zđ](?:\d+)?\)\s', lines[i])), end)
    return begin, end


def replace_unit(article, clause, point, new_text):
    lines = article.splitlines()
    begin, end = selected_span(lines, clause, point)
    old_text = '\n'.join(lines[begin:end]).strip()
    expected_prefix = f'{point})' if point else f'{clause}.'
    if not old_text.startswith(expected_prefix) or not new_text.startswith(expected_prefix):
        raise ValueError(f'Replacement unit mismatch at {clause}/{point}')
    lines[begin:end] = new_text.splitlines()
    return '\n'.join(lines), old_text


def quoted(text):
    blocks = re.findall(r'"(.*?)"', text, re.S)
    if len(blocks) != 1:
        raise ValueError(f'Expected one quoted amendment block, got {len(blocks)}')
    return blocks[0].strip()


def main():
    source = source_module()
    source.prepare()
    base = json.loads((LEGAL / '168-2024-source-reviewed.json').read_text(encoding='utf8'))
    amendment = json.loads((LEGAL / '238-2026-source-reviewed.json').read_text(encoding='utf8'))
    ledger = json.loads((LEGAL / '168-238-consolidation-review.json').read_text(encoding='utf8'))
    if ledger['baseArticleHashes'] != [a['contentSha256'] for a in base['articles']] or \
            ledger['amendmentContentSha256'] != amendment['contentSha256']:
        raise ValueError('Source hashes no longer match ledger')
    official = source.sections((ROOT / 'artifacts/local-ai/168-congbao-part1.txt').read_text(encoding='utf8'))
    # (source Article, source unit, target Article, target clause, target point, operation)
    operations = [(1, 1, 3, 3, 'i', 'replace'), (1, 2, 3, 3, 'l', 'replace'),
                  (2, 1, 6, '1a', None, 'insert_before_1'), (2, 2, 6, 3, 'm', 'replace'),
                  (3, None, 13, 8, 'b', 'replace'), (4, None, 14, 3, 'b', 'replace'),
                  (5, None, 17, 2, 'a', 'replace'), (6, None, 18, 4, 'a', 'replace')]
    output = {}
    audit = []
    for number in {op[2] for op in operations}:
        original = official[number].strip()
        if source.normalized(original) != source.normalized(base['articles'][number - 1]['content']):
            raise ValueError(f'Official Article {number} differs from reviewed public source')
        output[number] = original
    for source_article, source_unit, target, clause, point, action in operations:
        group = next(op for op in ledger['operations'] if op['sourceArticle'] == source_article)
        unit = next(u for u in group['sourceUnits'] if u['sourceUnit'] == source_unit)
        new_text = quoted(unit['sourceText'])
        if action == 'insert_before_1':
            lines = output[target].splitlines()
            anchor, _ = selected_span(lines, 1)
            if not new_text.startswith('1a.') or any(re.match(r'^1a\.\s', line) for line in lines):
                raise ValueError('Unexpected clause 1a insertion')
            lines[anchor:anchor] = new_text.splitlines()
            output[target] = '\n'.join(lines)
            old_hash = None
        else:
            output[target], old_text = replace_unit(output[target], clause, point, new_text)
            old_hash = hashlib.sha256(old_text.encode('utf8')).hexdigest()
        audit.append({'sourceArticle': source_article, 'sourceUnit': source_unit,
                      'targetArticle': target, 'clause': str(clause), 'point': point,
                      'operation': action, 'oldUnitSha256': old_hash,
                      'newUnitSha256': hashlib.sha256(new_text.encode('utf8')).hexdigest()})
    result = {'reviewStatus': 'PartialMergePendingArticle19AndFinalReview', 'isActive': False,
              'baseDocument': base['documentNumber'], 'amendingDocument': amendment['documentNumber'],
              'baseArticleHashes': ledger['baseArticleHashes'],
              'amendmentContentSha256': amendment['contentSha256'],
              'appliedOperations': audit,
              'articles': [{'number': n, 'content': output[n],
                            'contentSha256': hashlib.sha256(output[n].encode('utf8')).hexdigest()}
                           for n in sorted(output)]}
    target = LEGAL / '168-238-first-six-merged-review.json'
    encoded = (json.dumps(result, ensure_ascii=False, indent=2) + '\n').encode('utf8')
    if target.exists() and target.read_bytes() != encoded:
        raise ValueError('Existing partial merge differs')
    if not target.exists():
        target.write_bytes(encoded)
    print(json.dumps({'appliedOperations': len(audit), 'articles': sorted(output), 'isActive': False}))


if __name__ == '__main__':
    main()
