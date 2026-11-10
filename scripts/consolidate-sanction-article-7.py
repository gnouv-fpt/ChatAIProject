"""Apply the two Article 19/238 phrase additions to Article 7/168 for review."""
import hashlib
import importlib.util
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LEGAL = ROOT / 'content-bank/legal'


def load_script(path, name):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'scripts' / path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def replace_in_point(content, clause, point, anchor, addition):
    lines = content.splitlines()
    clause_start = next(i for i, line in enumerate(lines) if re.match(rf'^{clause}\.\s', line))
    clause_end = next((i for i in range(clause_start + 1, len(lines)) if re.match(r'^\d+[a-z]?\.\s', lines[i])), len(lines))
    point_start = next(i for i in range(clause_start + 1, clause_end) if re.match(rf'^{point}\)\s', lines[i]))
    point_end = next((i for i in range(point_start + 1, clause_end) if re.match(r'^[a-zđ]\)\s', lines[i])), clause_end)
    passage = '\n'.join(lines[point_start:point_end])
    if passage.count(anchor) != 1 or addition in passage:
        raise ValueError(f'Article 7 clause {clause} point {point} does not match amendment anchor exactly')
    lines[point_start:point_end] = passage.replace(anchor, anchor + ' ' + addition, 1).splitlines()
    return '\n'.join(lines)


def main():
    source = load_script('prepare-reviewed-sanctions-168.py', 'source168')
    source.prepare()
    base = json.loads((LEGAL / '168-2024-source-reviewed.json').read_text(encoding='utf8'))
    amendment = json.loads((LEGAL / '238-2026-source-reviewed.json').read_text(encoding='utf8'))
    ledger = json.loads((LEGAL / '168-238-consolidation-review.json').read_text(encoding='utf8'))
    if ledger['baseArticleHashes'][6] != base['articles'][6]['contentSha256'] or \
            ledger['amendmentContentSha256'] != amendment['contentSha256']:
        raise ValueError('Source hash drift')
    touching = [op for op in ledger['operations'] if op.get('targetArticle') == 7 or 7 in op.get('mentionedBaseArticles', [])]
    if [(op['sourceArticle'], op.get('sourceClause')) for op in touching] != [(19, 2), (19, 3)]:
        raise ValueError('Unexpected Article 7 amendment scope')
    part1 = (ROOT / 'artifacts/local-ai/168-congbao-part1.txt').read_text(encoding='utf8')
    original = source.sections(part1)[7].strip()
    if source.normalized(original) != source.normalized(base['articles'][6]['content']):
        raise ValueError('Official and public Article 7 differ')
    merged = original
    for operation, clause, point in [(touching[0], 1, 'e'), (touching[1], 6, 'b')]:
        quoted = re.findall(r'"([^"]+)"', operation['sourceText'])
        if len(quoted) != 2:
            raise ValueError('Expected exactly addition and anchor in Article 19 instruction')
        addition, anchor = quoted
        merged = replace_in_point(merged, clause, point, anchor, addition)
    result = {'reviewStatus': 'MergedArticlePendingFinalReview', 'isActive': False,
              'documentNumber': base['documentNumber'], 'article': '7',
              'sourceUrl': base['sourceUrl'], 'amendingSourceUrl': amendment['sourceUrl'],
              'officialSourceUrl': 'https://datafiles.chinhphu.vn/cpp/files/vbpq/2025/01/168-nd-cp.signed.pdf',
              'sourceArticleSha256': base['articles'][6]['contentSha256'],
              'amendmentContentSha256': amendment['contentSha256'],
              'appliedSourceClauses': [2, 3], 'content': merged,
              'contentSha256': hashlib.sha256(merged.encode('utf8')).hexdigest()}
    target = LEGAL / '168-2024-article-7-merged-238-review.json'
    encoded = (json.dumps(result, ensure_ascii=False, indent=2) + '\n').encode('utf8')
    if target.exists() and target.read_bytes() != encoded:
        raise ValueError('Merged Article 7 differs from previous review package')
    if not target.exists():
        target.write_bytes(encoded)
    print(json.dumps({'article': 7, 'appliedSourceClauses': [2, 3],
                      'contentSha256': result['contentSha256'], 'isActive': False}))


if __name__ == '__main__':
    main()
