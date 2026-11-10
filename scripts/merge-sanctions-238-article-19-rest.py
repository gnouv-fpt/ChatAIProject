"""Apply the remaining Article 19 edits to inactive, source-checked review text."""
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


def sha(value):
    return hashlib.sha256(value.encode('utf8')).hexdigest()


def main():
    source = load('source168', 'prepare-reviewed-sanctions-168.py')
    core = load('core', 'merge-sanctions-238-first-six.py')
    source.prepare()
    base = json.loads((LEGAL / '168-2024-source-reviewed.json').read_text(encoding='utf8'))
    amendment = json.loads((LEGAL / '238-2026-source-reviewed.json').read_text(encoding='utf8'))
    ledger = json.loads((LEGAL / '168-238-consolidation-review.json').read_text(encoding='utf8'))
    if ledger['baseArticleHashes'] != [a['contentSha256'] for a in base['articles']] or \
            ledger['amendmentContentSha256'] != amendment['contentSha256']:
        raise ValueError('Source hashes differ from operation ledger')
    part1 = source.sections((ROOT / 'artifacts/local-ai/168-congbao-part1.txt').read_text(encoding='utf8'))
    part2 = source.sections((ROOT / 'artifacts/local-ai/168-congbao-part2.txt').read_text(encoding='utf8'))
    original = {**part1, **part2}
    original[55] = original[55].split('TM. CHÍNH PHỦ', 1)[0]
    packages = ('168-238-first-six-merged-review.json',
                '168-238-articles-6-8-merged-review.json',
                '168-238-articles-20-21-26-merged-review.json',
                '168-238-articles-29-53-merged-review.json')
    merged = {}
    for filename in packages:
        package = json.loads((LEGAL / filename).read_text(encoding='utf8'))
        if package['isActive'] or package['amendmentContentSha256'] != amendment['contentSha256']:
            raise ValueError(f'Unexpected review package: {filename}')
        for article in package['articles']:
            number = article['number']
            if sha(article['content']) != article['contentSha256']:
                raise ValueError(f'Changed package content: {filename}/{number}')
            if number in merged and filename == '168-238-articles-6-8-merged-review.json' and number == 6:
                merged[number] = article['content']  # Includes the first-six edits.
            elif number in merged:
                raise ValueError(f'Unexpected duplicate package Article {number}')
            else:
                merged[number] = article['content']
    for number in (40, 47, 48, 55):
        if source.normalized(original[number]) != source.normalized(base['articles'][number - 1]['content']):
            raise ValueError(f'Official Article {number} differs from public source')
        merged[number] = original[number].strip()

    operations = {op['sourceClause']: op for op in ledger['operations'] if op['sourceArticle'] == 19}
    targets = {
        5: [(14, 6, 'a')],
        6: [(20, 6, 'd'), (21, 5, 'b')],
        7: [(26, 11, None)],
        8: [(47, 3, 'h')],
        9: [(53, 1, None)],
        11: [(3, 3, 'q'), (3, 3, 'r'), (13, 3, 'd'), (13, 4, 'b'),
             (18, 3, 'c'),
             *[(21, clause, point) for clause, points in
               ((2, ('a', 'd')), (5, ('a', 'd')), (6, ('a', 'b')),
                (7, ('a', 'b')), (8, ('a', 'b'))) for point in points],
             (26, 1, 'a'), (26, 3, None), (26, 5, None),
             (32, 1, 'b'), (32, 11, 'd'), (32, 14, 'h'),
             (32, 18, 'c'), (32, 18, 'd'), (32, 19, 'đ'),
             (32, 19, 'g'), (32, 20, None), (40, 4, 'a'), (48, 3, None)],
        12: [(32, 7, 'b'), (32, 7, 'd'), (32, 18, 'đ')],
        13: [(47, 5, 'c')],
        14: [(48, 1, 'a')],
        15: [(53, 2, None)],
        16: [(55, None, None)],
        17: [(32, 17, 'd'), (32, 17, 'đ'), (32, 17, 'e'), (32, 17, 'g')],
    }
    expected_mentions = {5: {14}, 6: {20, 21}, 7: {26}, 8: {20, 21, 29, 47},
                         9: {53}, 11: {3, 13, 18, 21, 26, 32, 40, 48},
                         12: {32}, 13: {47}, 14: {48}, 15: {6, 53},
                         16: {55}, 17: {32}}
    audit = []

    def selected(article, clause, point):
        lines = article.splitlines()
        if clause is None:
            return lines, 0, len(lines)
        begin, end = core.selected_span(lines, clause, point)
        return lines, begin, end

    def edit(number, clause, point, old, new, source_clause):
        lines, begin, end = selected(merged[number], clause, point)
        value = '\n'.join(lines[begin:end])
        occurrences = value.count(old)
        if (occurrences < 1 if source_clause == 11 else occurrences != 1) or \
                (new and new not in old and new in value):
            raise ValueError(f'Expected one unchanged anchor: Article {number}/{clause}/{point}, amendment {source_clause}')
        result = value.replace(old, new, occurrences if source_clause == 11 else 1)
        lines[begin:end] = result.splitlines()
        merged[number] = '\n'.join(lines)
        audit.append({'sourceClause': source_clause, 'targetArticle': number,
                      'clause': str(clause) if clause is not None else None,
                      'point': point, 'occurrences': occurrences,
                      'oldUnitSha256': sha(value), 'newUnitSha256': sha(result)})

    for source_clause, paths in targets.items():
        op = operations[source_clause]
        if set(op['mentionedBaseArticles']) != expected_mentions[source_clause]:
            raise ValueError(f'Article 19 clause {source_clause} reference list changed')
        quotes = re.findall(r'"(.*?)"', op['sourceText'], re.S)
        if source_clause == 17:
            if quotes:
                raise ValueError('Unexpected repeal quotation')
            for number, clause, point in paths:
                lines, begin, end = selected(merged[number], clause, point)
                old = '\n'.join(lines[begin:end])
                if not old.startswith(f'{point})'):
                    raise ValueError('Unexpected repeal point')
                lines[begin:end] = []
                merged[number] = '\n'.join(lines)
                audit.append({'sourceClause': 17, 'targetArticle': number, 'clause': '17',
                              'point': point, 'oldUnitSha256': sha(old), 'operation': 'repeal'})
            continue
        if source_clause == 8:
            if len(quotes) != 4:
                raise ValueError('Unexpected two phrase additions in Article 19 clause 8')
            number, clause, point = paths[0]
            edit(number, clause, point, quotes[1], quotes[0] + ' ' + quotes[1], source_clause)
            edit(number, clause, point, quotes[3], quotes[3] + quotes[2], source_clause)
            continue
        if source_clause in (12,):
            if len(quotes) != 2:
                raise ValueError('Unexpected Article 19 clause 12 source phrases')
            if quotes[0] != 'giấy chứng nhận kiểm định an toàn kỹ thuật và bảo vệ  môi trường':
                raise ValueError('Article 19 clause 12 removal text changed')
            for number, clause, point in paths:
                # Clause 11 has already replaced the opening term in these same points.
                prior = 'chứng nhận kiểm định an toàn kỹ thuật và bảo vệ môi trường'
                edit(number, clause, point, prior if clause == 7 else quotes[1], '', source_clause)
            continue
        if source_clause in (13, 14, 15, 16):
            if len(quotes) != 1:
                raise ValueError('Unexpected phrase removal instruction')
            for number, clause, point in paths:
                old = quotes[0]
                if source_clause == 16:
                    if old != 'trực thuộc trung ương':
                        raise ValueError('Article 19 clause 16 removal text changed')
                    old = 'trực thuộc Trung ương'
                edit(number, clause, point, old, '', source_clause)
            continue
        if source_clause == 11:
            if len(quotes) != 2:
                raise ValueError('Unexpected term replacement instruction')
            for number, clause, point in paths:
                edit(number, clause, point, quotes[0], quotes[1], source_clause)
            continue
        if len(quotes) != 2:
            raise ValueError(f'Unexpected source phrases in Article 19 clause {source_clause}')
        addition, anchor = quotes
        for number, clause, point in paths:
            if source_clause == 5:
                old, new = anchor, addition + ' ' + anchor
            else:
                old, new = anchor, anchor + addition
            edit(number, clause, point, old, new, source_clause)

    result = {'reviewStatus': 'MergedTextPendingEffectiveDateAndFinalReview', 'isActive': False,
              'baseDocument': base['documentNumber'], 'amendingDocument': amendment['documentNumber'],
              'baseArticleHashes': ledger['baseArticleHashes'],
              'amendmentContentSha256': amendment['contentSha256'],
              'appliedArticle19': audit,
              'articles': [{'number': n, 'content': merged[n], 'contentSha256': sha(merged[n])}
                           for n in sorted(merged)]}
    target = LEGAL / '168-238-article-19-rest-merged-review.json'
    encoded = (json.dumps(result, ensure_ascii=False, indent=2) + '\n').encode('utf8')
    if target.exists() and target.read_bytes() != encoded:
        raise ValueError('Existing merge differs')
    if not target.exists():
        target.write_bytes(encoded)
    print(json.dumps({'articles': sorted(merged), 'unitChanges': len(audit), 'isActive': False}))


if __name__ == '__main__':
    main()
