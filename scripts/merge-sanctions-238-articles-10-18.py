"""Prepare an auditable, inactive merge of Decree 238 Articles 10–18."""
import hashlib
import json
from pathlib import Path

from importlib.util import module_from_spec, spec_from_file_location

ROOT = Path(__file__).resolve().parents[1]
LEGAL = ROOT / 'content-bank/legal'


def load(name, filename):
    spec = spec_from_file_location(name, ROOT / 'scripts' / filename)
    module = module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def digest(value):
    return hashlib.sha256(value.encode('utf8')).hexdigest()


def main():
    source = load('source168', 'prepare-reviewed-sanctions-168.py')
    core = load('merge_core', 'merge-sanctions-238-first-six.py')
    inserts = load('merge_inserts', 'merge-sanctions-238-articles-7-9.py')
    source.prepare()
    base = json.loads((LEGAL / '168-2024-source-reviewed.json').read_text(encoding='utf8'))
    amendment = json.loads((LEGAL / '238-2026-source-reviewed.json').read_text(encoding='utf8'))
    ledger = json.loads((LEGAL / '168-238-consolidation-review.json').read_text(encoding='utf8'))
    if ledger['baseArticleHashes'] != [a['contentSha256'] for a in base['articles']] or \
            ledger['amendmentContentSha256'] != amendment['contentSha256']:
        raise ValueError('Reviewed source hashes differ from consolidation ledger')
    part1 = source.sections((ROOT / 'artifacts/local-ai/168-congbao-part1.txt').read_text(encoding='utf8'))
    part2 = source.sections((ROOT / 'artifacts/local-ai/168-congbao-part2.txt').read_text(encoding='utf8'))
    numbers = (29, 32, 41, 42, 43, 44, 46, 50, 53)
    articles = {}
    for number in numbers:
        original = (part1 if number in part1 else part2)[number].strip()
        if number == 46:
            marker = 'Các chức danh có thẩm quyền xử phạt vi phạm hành chính'
            if original.count(marker) != 1:
                raise ValueError('Article 46 Word auto-number location changed')
            original = original.replace(marker, '1. ' + marker, 1)
        if source.normalized(original) != source.normalized(base['articles'][number - 1]['content']):
            raise ValueError(f'Official Article {number} differs from reviewed public source')
        articles[number] = original
    audit = []

    def unit(article, number=None):
        group = next(op for op in ledger['operations'] if op['sourceArticle'] == article)
        matches = [row for row in group['sourceUnits'] if row['sourceUnit'] == number]
        if len(matches) != 1:
            raise ValueError(f'Expected one source unit: {article}/{number}')
        return core.quoted(matches[0]['sourceText'])

    def replace(number, clause, point, value, src, src_unit):
        articles[number], old = core.replace_unit(articles[number], clause, point, value)
        audit.append({'sourceArticle': src, 'sourceUnit': src_unit, 'targetArticle': number,
                      'clause': str(clause), 'point': point, 'operation': 'replace',
                      'oldUnitSha256': digest(old), 'newUnitSha256': digest(value)})

    def insert(number, clause, point, value, src, src_unit):
        articles[number] = inserts.insert_after(articles[number], clause, point, value, core)
        audit.append({'sourceArticle': src, 'sourceUnit': src_unit, 'targetArticle': number,
                      'clause': str(clause), 'afterPoint': point, 'operation': 'insert',
                      'newUnitSha256': digest(value)})

    insert(29, 3, None, unit(10, 1), 10, 1)
    replace(29, 4, None, unit(10, 2), 10, 2)
    insert(32, 9, None, unit(11, 1), 11, 1)
    insert(32, 11, 'đ', unit(11, 2), 11, 2)
    insert(32, 13, 'đ', unit(11, 3), 11, 3)
    replace(32, 19, 'l', unit(11, 4), 11, 4)
    replace(32, 21, 'c', unit(11, 5), 11, 5)
    replace(41, 2, 'd', unit(12, 1), 12, 1)
    insert(41, 4, 'k', unit(12, 2), 12, 2)
    replace(41, 5, None, unit(12, 3), 12, 3)
    for src, number in ((13, 42), (14, 43), (15, 44)):
        value = unit(src)
        if not value.startswith(f'Điều {number}.'):
            raise ValueError(f'Whole-article replacement header mismatch: {number}')
        old = articles[number]
        articles[number] = value
        audit.append({'sourceArticle': src, 'sourceUnit': None, 'targetArticle': number,
                      'operation': 'replace_article', 'oldUnitSha256': digest(old),
                      'newUnitSha256': digest(value)})
    replace(46, 2, None, unit(16), 16, None)
    replace(50, 1, 'đ', unit(17, 1), 17, 1)
    value = unit(17, 2)
    lines = articles[50].splitlines()
    begin, end = core.selected_span(lines, 3, 'a')
    if end - begin != 2 or not lines[begin + 1].startswith('Trường hợp Chủ tịch'):
        raise ValueError('Article 50 clause 3 point a second paragraph changed')
    old = lines[begin + 1]
    lines[begin + 1:end] = value.splitlines()
    articles[50] = '\n'.join(lines)
    audit.append({'sourceArticle': 17, 'sourceUnit': 2, 'targetArticle': 50,
                  'clause': '3', 'point': 'a', 'operation': 'replace_second_paragraph',
                  'oldUnitSha256': digest(old), 'newUnitSha256': digest(value)})
    value = unit(18)
    # The two new clauses are separate effective-date rules; retain that boundary.
    import re
    chunks = [p.strip() for p in re.split(r'(?m)(?=^[34]\.\s)', value) if p.strip()]
    if len(chunks) != 2 or not chunks[0].startswith('3.') or not chunks[1].startswith('4.'):
        raise ValueError('Expected two distinct Article 53 effective-date clauses')
    for new_clause in chunks:
        insert(53, 2 if new_clause.startswith('3.') else 3, None, new_clause, 18, None)

    result = {'reviewStatus': 'PartialMergePendingArticle19AndFinalReview', 'isActive': False,
              'baseDocument': base['documentNumber'], 'amendingDocument': amendment['documentNumber'],
              'baseArticleHashes': ledger['baseArticleHashes'],
              'amendmentContentSha256': amendment['contentSha256'], 'appliedOperations': audit,
              'articles': [{'number': n, 'content': articles[n], 'contentSha256': digest(articles[n])}
                           for n in sorted(articles)]}
    target = LEGAL / '168-238-articles-29-53-merged-review.json'
    encoded = (json.dumps(result, ensure_ascii=False, indent=2) + '\n').encode('utf8')
    if target.exists() and target.read_bytes() != encoded:
        raise ValueError('Existing partial merge differs')
    if not target.exists():
        target.write_bytes(encoded)
    print(json.dumps({'articles': sorted(articles), 'unitChanges': len(audit), 'isActive': False}))


if __name__ == '__main__':
    main()
