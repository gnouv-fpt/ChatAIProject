"""Live checks against this task's isolated local stack; uses real API/SQL/Redis/Kafka."""
import argparse
import concurrent.futures
import hashlib
import json
import secrets
import subprocess
import uuid
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / 'artifacts/local-learning'
runtime = json.loads((WORK / 'runtime.json').read_text(encoding='utf-8-sig'))
package = json.loads((WORK / 'package.json').read_text(encoding='utf-8-sig'))
BASE = runtime['gateway']
if BASE != 'http://127.0.0.1:18080' or not package['evidence']['localOnly']:
    raise ValueError('Live check is restricted to the isolated local-learning stack.')


def api(path, token=None, body=None, method=None, expected=200):
    path = path if path.startswith('/api/') else '/api' + path
    headers = {'Content-Type': 'application/json'}
    if token:
        headers['Authorization'] = 'Bearer ' + token
    req = Request(BASE + path, data=None if body is None else json.dumps(body).encode(),
                  headers=headers, method=method or ('GET' if body is None else 'POST'))
    try:
        with urlopen(req, timeout=35) as response:
            status, data = response.status, response.read()
    except HTTPError as error:
        status, data = error.code, error.read()
    if status != expected:
        raise AssertionError(f'{path}: expected HTTP {expected}, got {status}')
    return json.loads(data) if data else None


def account(prefix):
    name = prefix + uuid.uuid4().hex[:10]
    details = {'username': name, 'email': name + '@local-learning.test', 'password': 'Local@' + secrets.token_hex(16)}
    auth = api('/api/auth/register', body=details, expected=201)
    return details, auth['accessToken']


def finish_timeout():
    state = json.loads((WORK / 'live-check-private.json').read_text(encoding='utf-8'))
    token = api('/api/auth/login', body=state['account'])['accessToken']
    exam = api('/api/custom-exams/' + state['timeoutExamId'], token)
    assert exam['status'] == 'Submitted', 'The real Worker has not submitted the expired exam yet.'
    review = api('/api/exam-attempts/' + exam['attemptId'] + '/review', token)
    assert review['correct'] == 0 and review['total'] == 1 and review['questions'][0]['selectedOptionId'] is None
    evidence = json.loads((WORK / 'live-check.json').read_text(encoding='utf-8'))
    evidence['workerDeadlineSubmission'] = {'passed': True, 'attemptId': exam['attemptId']}
    (WORK / 'live-check.json').write_text(json.dumps(evidence, indent=2), encoding='utf-8')
    print('Real one-minute deadline: Worker submitted the unanswered exam; durable review passed.')


def main():
    details, token = account('live')
    _, other = account('other')
    bank = package['bank']
    banks = api('/api/question-banks', token)
    assert any(b['id'] == bank['id'] and b['version'] == bank['version'] and b['questionCount'] == 115 for b in banks)
    timeout = api('/api/custom-exams', token, {'categoryId': bank['id'], 'bankVersion': bank['version'],
        'questionCount': 1, 'durationMinutes': 1}, expected=201)
    (WORK / 'live-check-private.json').write_text(json.dumps({'account': details, 'timeoutExamId': timeout['examId']}), encoding='utf-8')
    browser, _ = account('browser')
    (WORK / 'browser-account.json').write_text(json.dumps(browser), encoding='utf-8')
    public = []
    for page in range(1, 7):
        response = api(f"/question-banks/{bank['id']}/versions/{bank['version']}/questions?page={page}&pageSize=20", token)
        public.extend(response['items'])
    assert len(public) == 115 and [q['number'] for q in public] == list(range(486, 601))
    assert 'correctOption' not in json.dumps(public) and 'explanation' not in json.dumps(public)
    sources = {q['id']: q for q in bank['questions']}
    def check_assets(q):
        for a in q['assets']:
            with urlopen(a['url'], timeout=15) as response:
                assert hashlib.sha256(response.read()).hexdigest() == a['sha256']
        with urlopen(q['explanationAnimationUrl'], timeout=15) as response:
            assert f'data-question="{q["number"]}"' in response.read().decode()
        return True
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        assert all(pool.map(check_assets, bank['questions']))
    template_codes = {t['examCode'] for t in package['templates']}
    templates = [t for t in api('/exam-templates', token) if t['examCode'] in template_codes]
    assert len(templates) == 6 and sum(len(t['questionIds']) for t in templates) == 115
    exam = api('/custom-exams', token, {'categoryId': bank['id'], 'bankVersion': '1', 'questionCount': 5, 'durationMinutes': 5}, expected=201)
    assert exam['passingScore'] == 4, 'Changing N must keep the 80% practice target.'
    assert not exam['attemptId'] and 'correctOption' not in json.dumps(exam) and 'explanation' not in json.dumps(exam)
    api('/custom-exams/' + exam['examId'], other, expected=403)
    for index, q in enumerate(exam['questions'][:2]):
        original = sources[q['id']]
        key = original['correctOptionIds'][0]
        option = key if index == 0 else next(o['id'] for o in original['options'] if o['id'] != key)
        exam = api(f"/custom-exams/{exam['examId']}/answers/{q['id']}", token,
                   {'optionId': option, 'revision': exam['revision']}, method='PUT')
    score = api('/custom-exams/' + exam['examId'] + '/submit', token, method='POST')
    assert score['correct'] == 1 and score['total'] == 5
    retry = api('/custom-exams/' + exam['examId'] + '/submit', token, method='POST')
    assert retry['attemptId'] == score['attemptId']
    review_path = '/exam-attempts/' + score['attemptId'] + '/review'
    review = api(review_path, token)
    assert review['bankId'] == bank['id'] and review['bankVersion'] == '1'
    assert sum(q['selectedOptionId'] is None for q in review['questions']) == 3
    for q in review['questions']:
        assert q['explanationAnimationUrl'] == sources[q['questionId']]['explanationAnimationUrl']
    api(review_path, other, expected=404)
    api(review_path, expected=401)
    # Remove only the submitted test exam's key from the dedicated Redis database (3).
    result = subprocess.run(['docker', 'exec', 'prn-c2-localtest-redis-1', 'redis-cli', '-n', '3',
        'DEL', 'custom-exam:v1:' + exam['examId'].replace('-', '')], check=True, capture_output=True, text=True)
    assert result.stdout.strip() == '1'
    api('/custom-exams/' + exam['examId'], token, expected=404)
    assert api(review_path, token)['attemptId'] == score['attemptId']
    template = templates[0]
    sample = api('/custom-exams/from-template', token, {'examCode': template['examCode'], 'version': template['version']}, expected=201)
    assert [q['id'] for q in sample['questions']] == template['questionIds']
    api('/custom-exams/' + sample['examId'] + '/submit', token, method='POST')
    history = api('/learning/history?bankId=' + bank['id'], token)
    assert any(item['attemptId'] == score['attemptId'] for item in history['items'])
    notifications = api('/exam-notifications', token)
    assert any(item['eventId'] == score['attemptId'] for item in notifications)
    evidence = {'realLocalInfrastructure': True, 'bankId': bank['id'], 'questions': 115, 'templates': 6,
        'sourceImagesAndLearnerUrlsChecked': 115, 'activeAnswersHidden': True, 'autosaveAndScore': True,
        'customTargetForFiveQuestions': 4, 'idempotentSubmit': True, 'otherOwnerBlocked': True,
        'reviewAfterRedisDeletion': True, 'historyAndNotifications': True, 'templateOrder': True,
        'workerDeadlineSubmission': 'pending one real minute'}
    (WORK / 'live-check.json').write_text(json.dumps(evidence, indent=2), encoding='utf-8')
    print(json.dumps(evidence, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--finish-timeout', action='store_true')
    args = parser.parse_args()
    finish_timeout() if args.finish_timeout else main()
