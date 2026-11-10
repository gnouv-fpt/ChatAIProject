"""Derive only 168/2024 articles untouched by every reviewed 238/2026 operation."""
import hashlib
import importlib.util
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LEGAL = ROOT / 'content-bank/legal'


def main():
    spec = importlib.util.spec_from_file_location('source168', ROOT / 'scripts/prepare-reviewed-sanctions-168.py')
    source168 = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(source168)
    source168.prepare()  # Pins both Gazette files and the public reader against reviewed hashes.
    base = json.loads((LEGAL / '168-2024-source-reviewed.json').read_text(encoding='utf8'))
    amendment = json.loads((LEGAL / '238-2026-source-reviewed.json').read_text(encoding='utf8'))
    ledger = json.loads((LEGAL / '168-238-consolidation-review.json').read_text(encoding='utf8'))
    if base['isActive'] or amendment['isActive'] or ledger['isActive'] or len(ledger['operations']) != 35:
        raise ValueError('Unexpected source or amendment state')
    if ledger['baseArticleHashes'] != [row['contentSha256'] for row in base['articles']] or \
            ledger['amendmentContentSha256'] != amendment['contentSha256']:
        raise ValueError('Ledger is not bound to the reviewed source packages')
    affected = set()
    for operation in ledger['operations']:
        if 'targetArticle' in operation:
            affected.add(operation['targetArticle'])
        else:
            affected.update(operation['mentionedBaseArticles'])
    safe = sorted(set(range(1, 56)) - affected)
    part1 = (ROOT / 'artifacts/local-ai/168-congbao-part1.txt').read_text(encoding='utf8')
    part2 = (ROOT / 'artifacts/local-ai/168-congbao-part2.txt').read_text(encoding='utf8')
    official = source168.sections(part1)
    continuation = part2.split('(Tiếp theo Công báo số 75 + 76)', 1)[1].split('Điều 40.', 1)[0]
    official[39] = official[39].split('(Xem tiếp Công báo', 1)[0] + continuation
    official.update(source168.sections(part2))
    official[55] = official[55].split('TM. CHÍNH PHỦ', 1)[0]
    content = []
    for number in safe:
        article = official[number].strip()
        if source168.normalized(article) != source168.normalized(base['articles'][number - 1]['content']):
            raise ValueError(f'Unchanged Article {number} differs from reviewed public text')
        content.append(article)
    capture = '\n'.join(content)
    result = {
        'reviewStatus': 'UnchangedUnder238Only', 'isActive': False,
        'documentNumber': '168/2024/NĐ-CP',
        'documentTitle': 'Nghị định 168/2024/NĐ-CP · các điều không bị Nghị định 238/2026 sửa đổi',
        'sourceUrl': base['sourceUrl'],
        'officialSourceUrl': 'https://datafiles.chinhphu.vn/cpp/files/vbpq/2025/01/168-nd-cp.signed.pdf',
        'articles': [str(n) for n in safe], 'content': capture,
        'contentSha256': hashlib.sha256(capture.encode('utf8')).hexdigest(),
        'reviewNotes': 'Chỉ các điều không bị Điều 1–19 Nghị định 238/2026 tác động theo ledger đã ghim hash; cần kiểm tra thêm văn bản khác và thời điểm hành vi trước khi kích hoạt.'
    }
    target = LEGAL / '168-2024-unaffected-under-238.json'
    encoded = (json.dumps(result, ensure_ascii=False, indent=2) + '\n').encode('utf8')
    if target.exists() and target.read_bytes() != encoded:
        raise ValueError('Derived review package changed; inspect before replacing')
    if not target.exists():
        target.write_bytes(encoded)
    print(json.dumps({'unaffectedArticles': safe, 'affectedArticles': sorted(affected),
                      'contentSha256': result['contentSha256'], 'isActive': False}))


if __name__ == '__main__':
    main()
