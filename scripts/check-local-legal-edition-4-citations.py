"""Diagnostic retrieval probes using exact headings from the reviewed source, never invented questions."""
import hashlib
import importlib.util
import json
import re
import subprocess
import sys
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / 'artifacts/local-ai'
spec = importlib.util.spec_from_file_location('checks', ROOT / 'scripts/check-official-b-and-bookmarks.py')
checks = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checks)


def main():
    source = json.loads((ROOT / 'content-bank/legal/55-2026-articles-56-89-review.json').read_text(encoding='utf8'))
    headings = {int(number): re.search(rf'(?m)^Điều {number}\. [^\n]+', source['content']).group()
                for number in source['articles']}
    rows = subprocess.run(['sqlcmd', '-S', '.\\MSSQLSERVER_VUON', '-E', '-d',
        'TrafficContent_WebLearning_57e824ae', '-y', '0', '-w', '65535', '-b', '-Q',
        'SET NOCOUNT ON; SELECT c.Id,c.Content,c.Article,d.SourceUrl,d.IsActive,c.IsVerified '
        'FROM LegalDocumentChunks c JOIN LegalDocuments d ON d.Id=c.DocumentId '
        "WHERE d.DocumentNumber='55/VBHN-VPQH' FOR JSON PATH, INCLUDE_NULL_VALUES;"],
        capture_output=True, text=True, encoding='utf8', check=True)
    chunks = {row['Id'].lower(): row for row in json.loads(''.join(rows.stdout.splitlines()).strip())}
    _, token = checks.account()
    api = lambda path, body=None, expected=200: checks.api(path, token, body, expected=expected)
    session = api('/chats', {'title': 'Chẩn đoán citation edition 4'}, expected=201)
    results = []
    articles = tuple(int(value) for value in sys.argv[1:]) if len(sys.argv) > 1 else (56, 57, 64, 65, 79, 80, 87, 88, 89)
    for article in articles:
        case = {'article': article, 'sourceHeading': headings[article], 'sourceUrl': source['sourceUrl']}
        try:
            answer = api('/chats/' + session['id'] + '/messages',
                          {'requestId': str(uuid.uuid4()), 'prompt': headings[article],
                           'attachmentIds': [], 'usePreviousAttachments': False})
            citations = answer.get('citations') or []
            checked = []
            for citation in citations:
                chunk = chunks.get((citation.get('documentChunkId') or '').lower())
                checked.append(bool(chunk and chunk['IsActive'] and chunk['IsVerified'] and
                    citation['sourceUrl'] == source['sourceUrl'] == chunk['SourceUrl'] and
                    citation['contentHash'] == hashlib.sha256(chunk['Content'].encode()).hexdigest() and
                    citation['excerpt'] in chunk['Content'] and citation['articleNumber'] == chunk['Article']))
            case.update({'status': answer['status'], 'citationCount': len(citations),
                         'citedArticles': sorted({c['articleNumber'] for c in citations}),
                         'citationFieldsMatchSql': bool(checked) and all(checked),
                         'expectedArticleCited': str(article) in {c['articleNumber'] for c in citations}})
        except Exception as error:
            case.update({'status': 'Error', 'errorType': type(error).__name__, 'error': str(error)[:300]})
        results.append(case)
    report = {'kind': 'source-heading diagnostic, not approved question benchmark',
              'edition': 4, 'cases': results,
              'passed': sum(c.get('status') == 'Answered' and c.get('citationFieldsMatchSql') and
                            c.get('expectedArticleCited') for c in results)}
    output = 'heading-probe-56-89.json' if len(sys.argv) == 1 else 'heading-probe-' + '-'.join(sys.argv[1:]) + '-retry.json'
    (WORK / output).write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf8')
    print(json.dumps({'passed': report['passed'], 'total': len(results),
                      'failures': [c['article'] for c in results if c.get('status') != 'Answered' or
                                   not c.get('citationFieldsMatchSql') or not c.get('expectedArticleCited')]},
                     ensure_ascii=False))


if __name__ == '__main__':
    main()
