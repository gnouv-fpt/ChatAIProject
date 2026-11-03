"""Verify the imported real source bank through the local Gateway and SQL database."""
import concurrent.futures
import sys
import hashlib
import importlib.util
import json
import secrets
import subprocess
import uuid
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
HTTPS = '--https' in sys.argv[1:]
WORK = ROOT / ('artifacts/question-bank-https' if HTTPS else 'artifacts/question-bank-600')
runtime = json.loads((ROOT / 'artifacts/local-learning/runtime.json').read_text(encoding='utf-8-sig'))
package = json.loads((ROOT / ('content-bank/csgt-2025-https/package.json' if HTTPS else 'content-bank/csgt-2025/package.json')).read_text(encoding='utf8'))
if runtime['gateway'] != 'http://127.0.0.1:18080' or not package['evidence']['localOnly']:
    raise ValueError('Restricted to the isolated local stack.')


def api(path, token=None, body=None, method=None, expected=200):
    headers = {'Content-Type': 'application/json'}
    if token: headers['Authorization'] = 'Bearer '+token
    request = Request(runtime['gateway']+'/api'+path, headers=headers,
                      data=json.dumps(body).encode() if body is not None else None,
                      method=method or ('POST' if body is not None else 'GET'))
    try:
        with urlopen(request, timeout=45) as response: status, data = response.status, response.read()
    except HTTPError as error:
        status, data = error.code, error.read()
    if status != expected: raise AssertionError(f'{path}: HTTP {status}, expected {expected}')
    return json.loads(data) if data else None


def main():
    name = 'bank600'+uuid.uuid4().hex[:10]
    account = {'username': name, 'email': name+'@local-learning.test', 'password': 'Local@'+secrets.token_hex(16)}
    token = api('/auth/register', body=account, expected=201)['accessToken']
    (WORK / 'browser-account.json').write_text(json.dumps(account), encoding='utf8')
    banks = api('/question-banks', token)
    bank = package['bank']
    summary = next(b for b in banks if b['id'] == bank['id'])
    assert summary['questionCount'] == 600 and summary['isPublished']
    baseline = json.loads((WORK / 'before-import.json').read_text(encoding='utf8'))
    for old in baseline['banks']:
        current = next(b for b in banks if b['id'] == old['id'] and b['version'] == old['version'])
        assert current == old, 'Existing bank summary changed'
    questions = []
    for page in range(1, 7):
        response = api(f"/question-banks/{bank['id']}/versions/1/questions?page={page}&pageSize=100", token)
        questions.extend(response['items'])
    assert [q['number'] for q in questions] == list(range(1, 601))
    assert 'correctOption' not in json.dumps(questions) and 'explanation' not in json.dumps(questions).lower()
    expected = {q['id']: q for q in bank['questions']}
    for q in questions:
        source = expected[q['id']]
        for key in ('number', 'topic', 'text', 'options', 'sourceUrl'):
            assert q[key] == source[key], (q['number'], key)
        for actual, original in zip(q['assets'], source['assets']):
            for key in ('id', 'url', 'altText'): assert actual[key] == original[key]
        assert len(q['assets']) == len(source['assets'])
    def check_assets(q):
        for asset in q['assets']:
            with urlopen(asset['url'], timeout=20) as response:
                assert hashlib.sha256(response.read()).hexdigest() == asset['sha256']
        if q['explanationAnimationUrl']:
            with urlopen(q['explanationAnimationUrl'], timeout=20) as response:
                assert f'data-question="{q["number"]}"' in response.read().decode()
        return True
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        assert all(pool.map(check_assets, bank['questions']))
    templates = api('/exam-templates', token)
    for old in baseline['templates']:
        assert next(t for t in templates if t['id'] == old['id']) == old
    for original in package['templates']:
        t = next(t for t in templates if t['examCode'] == original['examCode'])
        for key in ('questionIds', 'title', 'passingScore', 'durationMinutes', 'version'): assert t[key] == original[key]
    # Real SQL persistence, rather than relying on the source JSON or a file-backed test repository.
    db = runtime['contentDatabase']
    if not __import__('re').fullmatch(r'TrafficContent_WebLearning_[a-f0-9]{8}', db): raise ValueError('Unexpected SQL target')
    sql = subprocess.run(['sqlcmd', '-S', '.\\MSSQLSERVER_VUON', '-E', '-d', db, '-h', '-1', '-W', '-b', '-Q',
        "SET NOCOUNT ON; SELECT COUNT(*), SUM(CONVERT(int,IsParalysisQuestion)), "
        "SUM(CASE WHEN ExplanationAnimationUrl IS NOT NULL THEN 1 ELSE 0 END) FROM TrafficQuestions "
        f"WHERE BankCode='{uuid.UUID(bank['id']).hex}' AND BankVersion=1;"], capture_output=True, text=True, check=True)
    assert sql.stdout.split() == ['600', '60', '115'], sql.stdout
    sample = package['templates'][0]
    exam = api('/custom-exams/from-template', token, {'examCode': sample['examCode'], 'version': 1}, expected=201)
    assert [q['id'] for q in exam['questions']] == sample['questionIds']
    assert exam['passingScore'] == 24 and not exam['failOnCriticalWrong']
    assert 'correctOption' not in json.dumps(exam) and 'explanation' not in json.dumps(exam).lower()
    for q in exam['questions']:
        source = expected[q['id']]
        key = source['correctOptionIds'][0]
        # Wrong source-critical answer must not trigger an official fail in this practice profile.
        if source['isCritical']: key = next(o['id'] for o in source['options'] if o['id'] != key)
        exam = api(f"/custom-exams/{exam['examId']}/answers/{q['id']}", token,
                   {'optionId': key, 'revision': exam['revision']}, method='PUT')
    score = api('/custom-exams/'+exam['examId']+'/submit', token, method='POST')
    assert score['correct'] == 29 and score['total'] == 30
    review = api('/exam-attempts/'+score['attemptId']+'/review', token)
    assert review['bankId'] == bank['id'] and review['bankVersion'] == '1'
    assert review['isPassed'], 'Practice target must not apply official critical-question failure rules.'
    for q in review['questions']:
        source = expected[q['questionId']]
        assert q['explanationAnimationUrl'] == source['explanationAnimationUrl']
        assert q['correctOptionId'] == source['correctOptionIds'][0]
    retry = api('/custom-exams/'+exam['examId']+'/submit', token, method='POST')
    assert retry['attemptId'] == score['attemptId']
    history = api('/learning/history?bankId='+bank['id'], token)
    assert any(item['attemptId'] == score['attemptId'] for item in history['items'])
    before = json.loads((ROOT / 'artifacts/question-bank-600/protected-before.json').read_text(encoding='utf8'))
    for relative, digest in before.items():
        assert hashlib.sha256((ROOT / relative).read_bytes()).hexdigest() == digest, relative
    evidence = {'bankId': bank['id'], 'questionsFromSqlAndGateway': 600, 'sourceCriticalMarkersInSql': 60,
                'originalAssetsChecked': sum(len(q['assets']) for q in bank['questions']),
                'learnerLinksChecked': 115, 'newPracticeTemplates': 6, 'existingBanksPreserved': len(baseline['banks']),
                'existingTemplatesPreserved': len(baseline['templates']), 'protectedFilesUnchanged': len(before),
                'activeAnswersHidden': True, 'autosavedAnswers': 30, 'score': score,
                'durableReviewAndHistory': True, 'idempotentSubmit': True, 'practiceOnly': True}
    (WORK / 'live-check.json').write_text(json.dumps(evidence, indent=2), encoding='utf8')
    print(json.dumps(evidence, ensure_ascii=False))


if __name__ == '__main__': main()
