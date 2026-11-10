"""Apply Article 7–9 of Decree 238 to Articles 20, 21 and 26 of Decree 168."""
import hashlib
import importlib.util
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LEGAL = ROOT / 'content-bank/legal'


def load(name, filename):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'scripts' / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def quote_blocks(value):
    return re.findall(r'"(.*?)"', value, re.S)


def split_points(value, labels):
    parts = re.split(r'(?m)(?=^[a-zđ](?:\d+)?\))', value.strip())
    parts = [part.strip() for part in parts if part.strip()]
    if [re.match(r'^([a-zđ](?:\d+)?)\)', part)[1] for part in parts] != labels:
        raise ValueError(f'Expected point sequence {labels}')
    return parts


def insert_after(article, clause, prior_point, new_text, core):
    lines = article.splitlines()
    _, end = core.selected_span(lines, clause, prior_point) if prior_point else core.selected_span(lines, clause)
    label = re.match(r'^([a-zđ](?:\d+)?\)|\d+[a-zđ]?\.)', new_text.strip())
    clause_begin, clause_end = core.selected_span(lines, clause)
    if not label or any(line.startswith(label[0]) for line in lines[clause_begin:clause_end]):
        raise ValueError(f'Inserted unit already exists or has no label: {clause}/{prior_point}')
    lines[end:end] = new_text.strip().splitlines()
    return '\n'.join(lines)


def main():
    source = load('source168', 'prepare-reviewed-sanctions-168.py')
    core = load('merge_core', 'merge-sanctions-238-first-six.py')
    source.prepare()
    base = json.loads((LEGAL / '168-2024-source-reviewed.json').read_text(encoding='utf8'))
    amendment = json.loads((LEGAL / '238-2026-source-reviewed.json').read_text(encoding='utf8'))
    ledger = json.loads((LEGAL / '168-238-consolidation-review.json').read_text(encoding='utf8'))
    if ledger['baseArticleHashes'] != [a['contentSha256'] for a in base['articles']] or \
            ledger['amendmentContentSha256'] != amendment['contentSha256']:
        raise ValueError('Source hashes no longer match ledger')
    official = source.sections((ROOT / 'artifacts/local-ai/168-congbao-part1.txt').read_text(encoding='utf8'))
    articles = {}
    for number in (20, 21, 26):
        original = official[number].strip()
        if source.normalized(original) != source.normalized(base['articles'][number - 1]['content']):
            raise ValueError(f'Official Article {number} differs from reviewed public source')
        articles[number] = original
    audit = []

    def replace(number, clause, point, text, source_article, unit):
        articles[number], old = core.replace_unit(articles[number], clause, point, text)
        audit.append({'sourceArticle': source_article, 'sourceUnit': unit, 'article': number,
                      'clause': str(clause), 'point': point, 'operation': 'replace',
                      'oldUnitSha256': hashlib.sha256(old.encode('utf8')).hexdigest()})

    def insert(number, clause, prior_point, text, source_article, unit):
        articles[number] = insert_after(articles[number], clause, prior_point, text, core)
        audit.append({'sourceArticle': source_article, 'sourceUnit': unit, 'article': number,
                      'clause': str(clause), 'priorPoint': prior_point, 'operation': 'insert'})

    def unit(article, number):
        group = next(op for op in ledger['operations'] if op['sourceArticle'] == article)
        return next(row['sourceText'] for row in group['sourceUnits'] if row['sourceUnit'] == number)

    q = quote_blocks(unit(7, 1))
    if len(q) != 4:
        raise ValueError('Article 7 unit 1 quotations changed')
    replace(20, 5, 'đ', q[0], 7, 1)
    replace(20, 5, 'g', q[1], 7, 1)
    point_l, point_m = split_points(q[2], ['l', 'm'])
    replace(20, 5, 'l', point_l, 7, 1)
    replace(20, 5, 'm', point_m, 7, 1)
    insert(20, 5, 'm', q[3], 7, 1)
    replace(20, 6, 'đ', quote_blocks(unit(7, 2))[0], 7, 2)
    insert(20, 8, None, quote_blocks(unit(7, 3))[0], 7, 3)
    replace(20, 10, 'c', quote_blocks(unit(7, 4))[0], 7, 4)

    replace(21, 2, 'b', quote_blocks(unit(8, 1))[0], 8, 1)
    replace(21, 3, 'b', quote_blocks(unit(8, 2))[0], 8, 2)
    malformed = unit(8, 3).splitlines()
    if len(quote_blocks(unit(8, 3))) != 0 or not malformed[1].startswith('c)') or not malformed[-1].endswith('".'):
        raise ValueError('Unexpected Article 8 unit 3 source formatting')
    replace(21, 5, 'c', '\n'.join(malformed[1:])[:-2], 8, 3)
    q = quote_blocks(unit(8, 4))
    if len(q) != 2:
        raise ValueError('Article 8 unit 4 quotations changed')
    point_d, point_dd = split_points(q[0], ['d', 'đ'])
    replace(21, 8, 'd', point_d, 8, 4)
    replace(21, 8, 'đ', point_dd, 8, 4)
    insert(21, 8, 'đ', q[1], 8, 4)

    q = quote_blocks(unit(9, 1))
    if len(q) != 2:
        raise ValueError('Article 9 unit 1 quotations changed')
    replace(26, 7, 'e', q[0], 9, 1)
    point_k, point_l = split_points(q[1], ['k', 'l'])
    insert(26, 7, 'i', point_k, 9, 1)
    insert(26, 7, 'k', point_l, 9, 1)
    insert(26, 8, 'c', quote_blocks(unit(9, 2))[0], 9, 2)
    q = quote_blocks(unit(9, 3))
    if len(q) != 1:
        raise ValueError('Article 9 unit 3 quotations changed')
    point_c, point_d = split_points(q[0], ['c', 'd'])
    replace(26, 13, 'c', point_c, 9, 3)
    replace(26, 13, 'd', point_d, 9, 3)

    result = {'reviewStatus': 'PartialMergePendingArticle19AndFinalReview', 'isActive': False,
              'baseDocument': base['documentNumber'], 'amendingDocument': amendment['documentNumber'],
              'baseArticleHashes': ledger['baseArticleHashes'],
              'amendmentContentSha256': amendment['contentSha256'],
              'appliedUnits': audit,
              'articles': [{'number': n, 'content': articles[n],
                            'contentSha256': hashlib.sha256(articles[n].encode('utf8')).hexdigest()}
                           for n in sorted(articles)]}
    target = LEGAL / '168-238-articles-20-21-26-merged-review.json'
    encoded = (json.dumps(result, ensure_ascii=False, indent=2) + '\n').encode('utf8')
    if target.exists() and target.read_bytes() != encoded:
        raise ValueError('Existing partial merge differs')
    if not target.exists():
        target.write_bytes(encoded)
    print(json.dumps({'articles': sorted(articles), 'unitChanges': len(audit), 'isActive': False}))


if __name__ == '__main__':
    main()
