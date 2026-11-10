"""Produce a traceable, inactive clause review ledger from the three reviewed inputs."""
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LEGAL = ROOT / 'content-bank/legal'


def read(name):
    return json.loads((LEGAL / name).read_text(encoding='utf8'))


def sections(content):
    found = list(re.finditer(r'(?m)^Điều (\d+)\. ', content))
    return {int(match[1]): content[match.start():(found[index + 1].start() if index + 1 < len(found) else len(content))].strip()
            for index, match in enumerate(found)}


def amendment_units(article_number, article_text):
    lines = article_text.splitlines()
    # Articles 13–15 replace whole base articles; Article 18 inserts future-dated clauses.
    # Numbered lines inside their quoted text are legal content, not instruction numbers.
    if article_number in (13, 14, 15, 18):
        return [{'sourceUnit': None, 'instruction': lines[0], 'sourceText': article_text}]
    positions = [index for index, line in enumerate(lines[1:], 1) if re.match(r'^\d+\. ', line)]
    if not positions:
        return [{'sourceUnit': None, 'instruction': lines[0], 'sourceText': article_text}]
    if [int(lines[index].split('.', 1)[0]) for index in positions] != list(range(1, len(positions) + 1)):
        raise ValueError(f'Non-sequential amendment instructions in Article {article_number}')
    return [{'sourceUnit': unit + 1, 'instruction': lines[start],
             'sourceText': '\n'.join(lines[start:positions[unit + 1] if unit + 1 < len(positions) else len(lines)])}
            for unit, start in enumerate(positions)]


def main():
    base = read('168-2024-source-reviewed.json')
    amendment = read('238-2026-source-reviewed.json')
    candidates = read('238-2026-amendment-candidates.json')
    for package in (base, amendment):
        if package['reviewStatus'] != 'SourceVerifiedPendingEffectiveConsolidation' or package['isActive']:
            raise ValueError('Source packages must remain inactive pending effective consolidation')
    if [row['number'] for row in base['articles']] != list(range(1, 56)) or any(
            hashlib.sha256(row['content'].encode()).hexdigest().lower() != row['contentSha256'].lower()
            for row in base['articles']):
        raise ValueError('Base articles or hashes do not match the reviewed package')
    if hashlib.sha256(amendment['content'].encode()).hexdigest().lower() != amendment['contentSha256'].lower():
        raise ValueError('Amendment content hash mismatch')
    if candidates['reviewStatus'] != 'SourceVerifiedPendingEffectiveConsolidation' or candidates['isActive']:
        raise ValueError('Candidate map must remain inactive')
    amended = sections(amendment['content'])
    if set(amended) != set(range(1, 22)):
        raise ValueError('Amendment articles 1–21 are incomplete')
    operations = []
    mapping = candidates['amendmentArticleToBaseArticle']
    for number in range(1, 19):
        target = mapping[str(number)]
        if not target.isdigit():
            raise ValueError(f'Unresolved target article {number}')
        if int(target) not in {row['number'] for row in base['articles']}:
            raise ValueError(f'Target article {target} is absent from reviewed base')
        operations.append({'sourceArticle': number, 'targetArticle': int(target),
                           'sourceText': amended[number], 'sourceUnits': amendment_units(number, amended[number]),
                           'targetArticleContentSha256': base['articles'][int(target) - 1]['contentSha256'],
                           'reviewStatus': 'ClauseAndPointMergePending',
                           'effectiveFrom': '2026-08-15',
                           'laterClauseDates': candidates['laterClauseEffectiveDates'] if number == 18 else {}})
    article19 = amended[19].splitlines()
    positions = [i for i, line in enumerate(article19) if re.match(r'^\d+\. ', line)]
    if len(positions) != 17 or [int(article19[i].split('.', 1)[0]) for i in positions] != list(range(1, 18)):
        raise ValueError('Article 19 operations are incomplete')
    for index, start in enumerate(positions):
        text = '\n'.join(article19[start:positions[index + 1] if index + 1 < len(positions) else len(article19)])
        mentioned = sorted({int(n) for n in re.findall(r'Điều (\d+)', text) if 1 <= int(n) <= 55})
        quoted = re.findall(r'"([^"]+)"', text)
        anchors = (quoted[1::2] if index + 1 <= 9 else quoted[:1] if index + 1 in (10, 11) else
                   quoted if index + 1 <= 16 else [])
        base_anchor_hits = {anchor: {str(n): ' '.join(base['articles'][n - 1]['content'].split()).casefold().count(
            ' '.join(anchor.split()).casefold()) for n in mentioned} for anchor in anchors}
        operations.append({'sourceArticle': 19, 'sourceClause': index + 1,
                           'sourceText': text,
                           'mentionedBaseArticles': mentioned,
                           'candidateAnchorHitsInUnamendedBase': base_anchor_hits,
                           'reviewStatus': 'ClauseAndPointMergePending',
                           'effectiveFrom': '2026-08-15',
                           'explicitRepeal': index + 1 == 17})
    output = {'reviewStatus': 'ClauseAndPointMergePending', 'isActive': False,
              'baseDocument': base['documentNumber'], 'amendingDocument': amendment['documentNumber'],
              'baseArticleHashes': [row['contentSha256'] for row in base['articles']],
              'amendmentContentSha256': amendment['contentSha256'],
              'operations': operations, 'effectiveRule': amended[20], 'transitionRule': amended[21],
              'note': 'Exact source passages for review only. No merged sanction or current-law verification is asserted.'}
    target = LEGAL / '168-238-consolidation-review.json'
    encoded = (json.dumps(output, ensure_ascii=False, indent=2) + '\n').encode('utf8')
    if target.exists() and target.read_bytes() != encoded:
        raise ValueError('Existing review ledger differs; inspect before replacing')
    if not target.exists():
        target.write_bytes(encoded)
    print(json.dumps({'sourceArticles': len(amended), 'operationGroups': len(operations),
                      'article1To18Units': sum(len(op.get('sourceUnits', [])) for op in operations),
                      'article19Operations': len(positions), 'isActive': False}))


if __name__ == '__main__':
    main()
