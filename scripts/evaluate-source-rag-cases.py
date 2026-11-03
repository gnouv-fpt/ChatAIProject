"""Evaluate exact published CSGT questions against the reviewed local law corpus.

Candidate legal mappings are recorded separately; every failed request remains in output.
"""
import hashlib
import importlib.util
import json
import os
import re
import subprocess
import sys
import uuid
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'grpc_inference_service'))
from rag.embeddings import EmbeddingEngine
from rag.vector_store import QdrantTrafficStore

spec = importlib.util.spec_from_file_location('checks', ROOT / 'scripts/check-official-b-and-bookmarks.py')
checks = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checks)
WORK = ROOT / 'artifacts/local-ai'


def embedding_key():
    key = os.environ.get('EMBEDDING_API_KEY') or os.environ.get('GEMINI_API_KEY')
    if key:
        return key
    project = ET.parse(ROOT / 'Presentation/Presentation.csproj').getroot()
    secret_id = project.findtext('.//UserSecretsId')
    if not secret_id or '/' in secret_id or '\\' in secret_id:
        raise RuntimeError('Unexpected local user-secrets configuration')
    path = Path(os.environ['APPDATA']) / 'Microsoft/UserSecrets' / secret_id / 'secrets.json'
    return json.loads(path.read_text(encoding='utf-8-sig'))['Llm:Gemini:ApiKey']


def sql_chunks():
    database = checks.runtime['contentDatabase']
    if not re.fullmatch(r'TrafficContent_WebLearning_[a-f0-9]{8}', database) or \
            checks.runtime['userDatabase'] != database.replace('TrafficContent_', 'TrafficUser_', 1):
        raise ValueError('Unexpected isolated local databases')
    result = subprocess.run(['sqlcmd', '-S', '.\\MSSQLSERVER_VUON', '-E', '-d',
        database, '-y', '0', '-w', '65535', '-b', '-Q',
        'SET NOCOUNT ON; SELECT c.Id,c.Content,c.Article,c.Clause,c.Point,d.SourceUrl,d.IsActive,c.IsVerified '
        'FROM LegalDocumentChunks c JOIN LegalDocuments d ON d.Id=c.DocumentId '
        "WHERE d.DocumentNumber='55/VBHN-VPQH' FOR JSON PATH, INCLUDE_NULL_VALUES;"],
        capture_output=True, text=True, encoding='utf8', check=True)
    return {row['Id'].lower(): row for row in json.loads(''.join(result.stdout.splitlines()).strip())}


def location(row):
    return (str(row.get('article') or row.get('Article') or ''),
            str(row.get('clause') or row.get('Clause') or ''),
            str(row.get('point') or row.get('Point') or ''))


def main():
    manifest = json.loads((ROOT / 'content-bank/legal/rag-eval-source-cases.json').read_text(encoding='utf8'))
    package = json.loads((ROOT / 'content-bank/csgt-2025-https/package.json').read_text(encoding='utf8'))
    if manifest['questionSourcePdfSha256'] != package['evidence']['sourcePdfSha256'] or \
            manifest['legalSourceDocument'] != '55/VBHN-VPQH' or \
            manifest['status'] != 'SourceAuthenticatedLegalMappingCandidate':
        raise ValueError('Source identity or review status differs')
    questions = {q['number']: q for q in package['bank']['questions']}
    if len(manifest['cases']) != len({case['questionNumber'] for case in manifest['cases']}):
        raise ValueError('Duplicate evaluation question number')
    selected_numbers = {int(value) for value in sys.argv[1:]} if len(sys.argv) > 1 else None
    selected_cases = [case for case in manifest['cases'] if selected_numbers is None or
                      case['questionNumber'] in selected_numbers]
    if selected_numbers is not None and {case['questionNumber'] for case in selected_cases} != selected_numbers:
        raise ValueError('Selected question number is absent from source manifest')
    rows = sql_chunks()
    for case in selected_cases:
        if case['questionNumber'] not in questions or (not case['expected'] and case.get('expectedStatus') != 'NoMatch'):
            raise ValueError('Unresolved evaluation source or legal location')
        if any(not any(location(row) == (ref['article'], ref['clause'], ref.get('point', ''))
                       for row in rows.values()) for ref in case['expected']):
            raise ValueError(f"Expected SQL location missing for question {case['questionNumber']}")

    os.environ.update({'EMBEDDING_PROVIDER': 'gemini', 'EMBEDDING_MODEL': 'gemini-embedding-001',
        'EMBEDDING_DIMENSION': '768', 'EMBEDDING_API_KEY': embedding_key(),
        'QDRANT_COLLECTION': 'traffic_law_learning_' + checks.runtime['contentDatabase'].rsplit('_', 1)[1]
                             + '_gemini768_v1'})
    store = QdrantTrafficStore(EmbeddingEngine(), host='127.0.0.1', port=16333)
    _, token = checks.account()
    api = lambda path, body=None, expected=200: checks.api(path, token, body, expected=expected)
    session = api('/chats', {'title': 'Đánh giá RAG từ câu hỏi nguồn CSGT'}, expected=201)
    results = []
    try:
        for case in selected_cases:
            q = questions[case['questionNumber']]
            # Exact question and option text from the published PDF-derived package.
            prompt = q['text'] + '\n' + '\n'.join(option['text'] for option in q['options'])
            expected = {(r['article'], r['clause'], r.get('point', '')) for r in case['expected']}
            result = {'questionNumber': q['number'], 'topic': case['topic'], 'kind': case['kind'],
                      'expectedStatus': case.get('expectedStatus', 'Answered'),
                      'sourceUrl': q['sourceUrl'], 'expected': case['expected']}
            try:
                retrieved = store.search_verified_chunks(prompt, top_k=5, score_threshold=0.20)
                locations = {location(row) for row in retrieved}
                result['retrieval'] = {'count': len(retrieved), 'locations': sorted(locations),
                                       'allExpectedLocationsInTop5': expected.issubset(locations) if expected else None,
                                       'anyExpectedArticleInTop5': bool({r[0] for r in expected} &
                                                                       {r[0] for r in locations}) if expected else None,
                                       'outOfCorpusRetrievedChunks': len(retrieved) if not expected else None}
            except Exception as error:
                result['retrieval'] = {'errorType': type(error).__name__, 'error': str(error)[:160]}
            try:
                answer = api('/chats/' + session['id'] + '/messages',
                    {'requestId': str(uuid.uuid4()), 'prompt': prompt, 'attachmentIds': [],
                     'usePreviousAttachments': False})
                citations = answer.get('citations') or []
                citation_locations = {(str(c.get('articleNumber') or ''),
                                       str(c.get('clauseNumber') or ''), str(c.get('pointNumber') or ''))
                                      for c in citations}
                integrity = all((row := rows.get((c.get('documentChunkId') or '').lower())) and
                    row['IsActive'] and row['IsVerified'] and c['sourceUrl'] == row['SourceUrl'] and
                    c['contentHash'] == hashlib.sha256(row['Content'].encode()).hexdigest() and
                    c['excerpt'] in row['Content'] and
                    (c['articleNumber'], c['clauseNumber'], c.get('pointNumber') or '') == location(row)
                    for c in citations)
                result['generation'] = {'status': answer['status'], 'citationCount': len(citations),
                    'citationLocations': sorted(citation_locations), 'citationIntegrity': bool(citations) and integrity,
                    'allExpectedLocationsCited': expected.issubset(citation_locations) if expected else None,
                    'expectedNoMatch': answer['status'] == 'NoMatch' and not citations if not expected else None,
                    'urlAccuracy': bool(citations) and all(c['sourceUrl'] == manifest['legalSourceUrl'] for c in citations),
                    'groundingSemanticCorrectness': 'not independently graded'}
            except Exception as error:
                result['generation'] = {'status': 'Error', 'errorType': type(error).__name__,
                                        'error': str(error)[:160]}
            results.append(result)
    finally:
        os.environ.pop('EMBEDDING_API_KEY', None)
    report = {'status': manifest['status'], 'asOfDate': manifest['asOfDate'],
              'questionSourcePdfSha256': manifest['questionSourcePdfSha256'],
              'legalEdition': 4, 'cases': results,
              'missingCategories': ['historical-rule', 'future-rule'],
              'note': 'Original 2025 questions with manually checked law-location candidates; no invented prompts or formal human-approved gold labels.'}
    output = 'source-rag-evaluation.json' if selected_numbers is None else \
        'source-rag-evaluation-' + '-'.join(str(n) for n in sorted(selected_numbers)) + '.json'
    (WORK / output).write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf8')
    print(json.dumps({'cases': len(results),
        'retrievalAllLocations': sum(bool(r.get('retrieval', {}).get('allExpectedLocationsInTop5')) for r in results),
        'generationAnswered': sum(r.get('generation', {}).get('status') == 'Answered' for r in results),
        'generationErrors': sum(r.get('generation', {}).get('status') == 'Error' for r in results)}, ensure_ascii=False))


if __name__ == '__main__':
    main()
