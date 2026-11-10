"""Join every Decree 168 article with its reviewed Decree 238 amendments."""
import hashlib
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LEGAL = ROOT / 'content-bank/legal'


def sha(value):
    return hashlib.sha256(value.encode('utf8')).hexdigest()


def main():
    spec = importlib.util.spec_from_file_location('source168', ROOT / 'scripts/prepare-reviewed-sanctions-168.py')
    source = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(source)
    source.prepare()
    base = json.loads((LEGAL / '168-2024-source-reviewed.json').read_text(encoding='utf8'))
    amendment = json.loads((LEGAL / '238-2026-source-reviewed.json').read_text(encoding='utf8'))
    untouched = json.loads((LEGAL / '168-2024-unaffected-under-238.json').read_text(encoding='utf8'))
    changed = json.loads((LEGAL / '168-238-article-19-rest-merged-review.json').read_text(encoding='utf8'))
    if any(package['isActive'] for package in (untouched, changed)) or \
            changed['baseArticleHashes'] != [article['contentSha256'] for article in base['articles']] or \
            changed['amendmentContentSha256'] != amendment['contentSha256'] or \
            sha(untouched['content']) != untouched['contentSha256']:
        raise ValueError('Source package hash or review state changed')
    clean = source.sections(untouched['content'])
    if sorted(clean) != sorted(int(number) for number in untouched['articles']):
        raise ValueError('Unchanged article list does not match source text')
    merged = {article['number']: article['content'] for article in changed['articles']}
    if len(merged) != len(changed['articles']) or set(clean) & set(merged) or \
            set(clean) | set(merged) != set(range(1, 56)):
        raise ValueError('Expected exactly 55 disjoint Decree 168 articles')
    for article in changed['articles']:
        if sha(article['content']) != article['contentSha256']:
            raise ValueError(f'Changed article hash mismatch: {article["number"]}')
    articles = [{'number': number, 'content': (merged if number in merged else clean)[number].strip(),
                 'contentSha256': sha((merged if number in merged else clean)[number].strip()),
                 'amendedUnder238': number in merged}
                for number in range(1, 56)]
    article53 = articles[52]['content']
    clause3 = article53.split('\n3. ', 1)[1].split('\n4. ', 1)[0]
    clause4 = article53.split('\n4. ', 1)[1]
    if '01 tháng 01 năm 2028' not in clause3 or '01 tháng 01 năm 2029' not in clause4:
        raise ValueError('Article 53 delayed-effect clauses changed')
    exceptions = [
        {'article': n, 'clause': c, 'point': p, 'effectiveFrom': '2028-01-01',
         'scope': 'vehicle-specific', 'evidenceArticle': 53, 'evidenceClause': 3}
        for n, c, p in ((20, '5', 'l'), (21, '3', 'b'), (32, '9a', 'b'))
    ] + [
        {'article': n, 'clause': c, 'point': p, 'effectiveFrom': '2029-01-01',
         'scope': 'device-specific-and-external-rule', 'evidenceArticle': 53, 'evidenceClause': 4}
        for n, c, p in ((20, '5', 'n'), (26, '7', 'k'), (26, '7', 'l'))
    ] + [
        {'article': 32, 'clause': '1', 'point': 'b', 'effectiveFrom': None,
         'scope': 'dependent-on-emissions-inspection-law', 'evidenceArticle': 53, 'evidenceClause': 2}
    ]
    result = {'reviewStatus': 'FullTextPendingEffectiveDateAndFinalReview', 'isActive': False,
              'baseDocument': base['documentNumber'], 'amendingDocument': amendment['documentNumber'],
              'baseArticleHashes': changed['baseArticleHashes'],
              'amendmentContentSha256': amendment['contentSha256'],
              'effectiveDateExceptions': exceptions,
              'reviewNotes': ['Article 53 contains future effective-date exceptions; do not activate this package wholesale.',
                              'The amendment transitional rule must be applied for violations before 2026-08-15.',
                              'Every article requires a final legal and citation review before SQL/Qdrant indexing.'],
              'articles': articles}
    target = LEGAL / '168-238-all-articles-merged-review.json'
    encoded = (json.dumps(result, ensure_ascii=False, indent=2) + '\n').encode('utf8')
    if target.exists() and target.read_bytes() != encoded:
        raise ValueError('Existing full-text review package differs')
    if not target.exists():
        target.write_bytes(encoded)
    print(json.dumps({'articles': len(articles), 'amended': len(merged),
                      'unchanged': len(clean), 'isActive': False}))


if __name__ == '__main__':
    main()
