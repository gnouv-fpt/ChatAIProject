"""Apply Article 19 clauses 1–4 and 10 to their exact Article 6–8 points."""
import hashlib
import importlib.util
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LEGAL = ROOT / 'content-bank/legal'


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'scripts' / path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def edit_point(article, clause, point, old, new):
    merge = load('merge_core', 'merge-sanctions-238-first-six.py')
    lines = article.splitlines()
    begin, end = merge.selected_span(lines, clause, point)
    passage = '\n'.join(lines[begin:end])
    if passage.count(old) != 1 or new in passage:
        raise ValueError(f'Expected one unmodified anchor at Article/clause/point {clause}/{point}')
    lines[begin:end] = passage.replace(old, new, 1).splitlines()
    return '\n'.join(lines)


def main():
    source = load('source168', 'prepare-reviewed-sanctions-168.py')
    source.prepare()
    base = json.loads((LEGAL / '168-2024-source-reviewed.json').read_text(encoding='utf8'))
    amendment = json.loads((LEGAL / '238-2026-source-reviewed.json').read_text(encoding='utf8'))
    ledger = json.loads((LEGAL / '168-238-consolidation-review.json').read_text(encoding='utf8'))
    first = json.loads((LEGAL / '168-238-first-six-merged-review.json').read_text(encoding='utf8'))
    seventh = json.loads((LEGAL / '168-2024-article-7-merged-238-review.json').read_text(encoding='utf8'))
    if ledger['baseArticleHashes'] != [a['contentSha256'] for a in base['articles']] or \
            ledger['amendmentContentSha256'] != amendment['contentSha256'] or \
            first['amendmentContentSha256'] != amendment['contentSha256'] or \
            seventh['amendmentContentSha256'] != amendment['contentSha256']:
        raise ValueError('Source or partial merge hash drift')
    official = source.sections((ROOT / 'artifacts/local-ai/168-congbao-part1.txt').read_text(encoding='utf8'))
    article8 = official[8].strip()
    if source.normalized(article8) != source.normalized(base['articles'][7]['content']):
        raise ValueError('Official Article 8 differs from public source')
    merged = {6: next(a['content'] for a in first['articles'] if a['number'] == 6),
              7: seventh['content'], 8: article8}
    # Clause 19, target Article, clause, point. Multi-target instructions are applied to every listed point.
    targets = {1: [(6, 3, 'h')],
               2: [(6, 2, 'a'), (6, 5, 'g'), (7, 1, 'e'), (8, 6, 'h')],
               3: [(6, 5, 'i'), (7, 6, 'b'), (8, 6, 'd')],
               4: [(6, 7, 'c'), (8, 6, 'b')],
               10: [(6, 5, 'p')]}
    audit = []
    for source_clause, paths in targets.items():
        operation = next(o for o in ledger['operations'] if o['sourceArticle'] == 19 and o['sourceClause'] == source_clause)
        quoted = re.findall(r'"([^"]+)"', operation['sourceText'])
        if len(quoted) != 2:
            raise ValueError(f'Unexpected Article 19 clause {source_clause} quotation count')
        if source_clause == 10:
            old, new = quoted
        else:
            addition, anchor = quoted
            old, new = anchor, anchor + ' ' + addition
        if {article for article, _, _ in paths} != set(operation['mentionedBaseArticles']) - (
                {29} if source_clause == 1 else set()):
            raise ValueError(f'Article 19 clause {source_clause} target mismatch')
        for article, clause, point in paths:
            if article == 7:
                # The reviewed Article 7 package has already applied both additions.
                core = load('merge_core', 'merge-sanctions-238-first-six.py')
                lines = merged[7].splitlines()
                begin, end = core.selected_span(lines, clause, point)
                if '\n'.join(lines[begin:end]).count(new) != 1:
                    raise ValueError('Prior Article 7 merge does not match source operation')
                continue
            merged[article] = edit_point(merged[article], clause, point, old, new)
            audit.append({'sourceClause': source_clause, 'targetArticle': article,
                          'clause': str(clause), 'point': point,
                          'oldPhraseSha256': hashlib.sha256(old.encode('utf8')).hexdigest(),
                          'newPhraseSha256': hashlib.sha256(new.encode('utf8')).hexdigest()})
    result = {'reviewStatus': 'PartialMergePendingRemainingOperationsAndFinalReview', 'isActive': False,
              'baseDocument': base['documentNumber'], 'amendingDocument': amendment['documentNumber'],
              'baseArticleHashes': ledger['baseArticleHashes'],
              'amendmentContentSha256': amendment['contentSha256'],
              'appliedArticle19': audit,
              'articles': [{'number': n, 'content': merged[n],
                            'contentSha256': hashlib.sha256(merged[n].encode('utf8')).hexdigest()}
                           for n in sorted(merged)]}
    target = LEGAL / '168-238-articles-6-8-merged-review.json'
    encoded = (json.dumps(result, ensure_ascii=False, indent=2) + '\n').encode('utf8')
    if target.exists() and target.read_bytes() != encoded:
        raise ValueError('Existing partial merge differs')
    if not target.exists():
        target.write_bytes(encoded)
    print(json.dumps({'articles': sorted(merged), 'appliedPointChanges': len(audit), 'isActive': False}))


if __name__ == '__main__':
    main()
