"""Build a narrow, unchanged 168/2024 sanction scope for source review.

The full 168+238 consolidation stays pending. This selects only provisions
whose exact normalized text also occurs in the original 168 source capture.
"""
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LEGAL = ROOT / 'content-bank/legal'
BASE = LEGAL / '168-2024-source-reviewed.json'
MERGED = LEGAL / '168-238-all-articles-merged-review.json'
AMENDMENT = LEGAL / '238-2026-source-reviewed.json'
OUTPUT = LEGAL / '168-238-targeted-sanctions-reviewed.json'

EXPECTED_BASE_SHA256 = '362a28d09b35a6e35df2b8bdf0bc157bb8ad53f3b48ac0475a78b399b7593120'
EXPECTED_MERGED_SHA256 = 'bedda09377118e1146f8207f75f7e30e7564e076c6ef57b611195a5b914770dc'
SCOPE = {
    6: [('6', ''), ('6', 'c'), ('9', ''), ('9', 'a'), ('11', ''), ('11', 'a'),
        ('11', 'c'), ('15', ''), ('15', 'c')],
    7: [('2', ''), ('2', 'i')],
    12: [('5', ''), ('5', 'b')],
}


def normalized(text):
    return re.sub(r'\s+', ' ', text.replace('\xa0', ' ')).strip()


def split_chunks(content):
    article = clause = point = None
    result = {}
    lines = []

    def flush():
        if lines and article is not None:
            key = (article, clause or '', point or '')
            if key in result:
                raise ValueError(f'Duplicate legal location: {key}')
            result[key] = '\n'.join(lines)
            lines.clear()

    for line in content.splitlines():
        line = line.strip()
        if not line:
            continue
        a = re.match(r'^Điều\s+(\d+)\s*[.:]', line)
        c = re.match(r'^(\d+[a-zđ]?)\.\s', line)
        p = re.match(r'^([a-zđ](?:\d+)?)\)\s', line)
        if a:
            flush()
            article, clause, point = a.group(1), None, None
        elif c and article:
            flush()
            clause, point = c.group(1), None
        elif p and clause:
            flush()
            point = p.group(1)
        lines.append(line)
    flush()
    return result


def main():
    for path, expected in ((BASE, EXPECTED_BASE_SHA256), (MERGED, EXPECTED_MERGED_SHA256)):
        if hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            raise ValueError(f'Source package changed: {path.name}')
    base = json.loads(BASE.read_text(encoding='utf8'))
    merged = json.loads(MERGED.read_text(encoding='utf8'))
    amendment = json.loads(AMENDMENT.read_text(encoding='utf8'))
    if merged['reviewStatus'] != 'FullTextPendingEffectiveDateAndFinalReview' or merged['isActive']:
        raise ValueError('Full consolidation review state changed')
    if merged['amendmentContentSha256'] != amendment['contentSha256']:
        raise ValueError('Amendment source changed')

    content_lines = []
    for number, selected in SCOPE.items():
        original = next(a['content'] for a in base['articles'] if a['number'] == number)
        amended = next(a['content'] for a in merged['articles'] if a['number'] == number)
        chunks = split_chunks(amended)
        title = chunks[(str(number), '', '')]
        for text in [title, *(chunks[(str(number), clause, point)] for clause, point in selected)]:
            if normalized(text) not in normalized(original):
                raise ValueError(f'Selected text changed by 238: Article {number}: {text[:70]}')
            content_lines.append(text)

    content = '\n'.join(content_lines)
    line_set_hash = hashlib.sha256('\n'.join(sorted(line.strip() for line in content.splitlines()
                                                      if line.strip())).encode('utf8')).hexdigest()
    result = {
        'reviewStatus': 'TargetedUnchangedTextReviewed',
        'isActive': False,
        'documentNumber': '168/2024/NĐ-CP',
        'documentTitle': 'Nghị định 168/2024/NĐ-CP, các điểm chưa đổi theo Nghị định 238/2026/NĐ-CP',
        'sourceUrl': base['sourceUrl'],
        'officialSourceUrl': 'https://datafiles.chinhphu.vn/cpp/files/vbpq/2025/01/168-nd-cp.signed.pdf',
        'amendmentSourceUrl': amendment['officialSourceUrl'],
        'effectiveFrom': '2025-01-01',
        'articles': list(SCOPE),
        'scope': {str(k): [f'{clause}{point}' for clause, point in v] for k, v in SCOPE.items()},
        'content': content,
        'contentSha256': hashlib.sha256(content.encode('utf8')).hexdigest(),
        'lineSetSha256': line_set_hash,
        'notes': 'Only these unchanged provisions were checked against the original 168 text. The full 168+238 consolidation remains pending; 2028/2029 exceptions are outside this scope.',
    }
    OUTPUT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf8')
    print(f'{len(content_lines)} source-matched chunks; contentSha256={result["contentSha256"]}; lineSetSha256={line_set_hash}')


if __name__ == '__main__':
    main()
