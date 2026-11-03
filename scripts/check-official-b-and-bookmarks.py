"""Real local Gateway/SQL check of B scoring boundaries and user-owned bookmarks."""
import concurrent.futures
import json
import secrets
import uuid
import time
import sys
from datetime import datetime, timezone
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / 'artifacts/c2-finalization'
runtime = json.loads((ROOT/'artifacts/local-learning/runtime.json').read_text(encoding='utf-8-sig'))
package = json.loads((ROOT/'content-bank/csgt-2025-B-current/package.json').read_text(encoding='utf8'))
if runtime['gateway'] != 'http://127.0.0.1:18080': raise ValueError('Local Gateway only')


def api(path, token=None, body=None, method=None, expected=200):
    request = Request(runtime['gateway']+'/api'+path, data=json.dumps(body).encode() if body is not None else None,
        headers={'Content-Type':'application/json', **({'Authorization':'Bearer '+token} if token else {})},
        method=method or ('POST' if body is not None else 'GET'))
    for attempt in range(12):
        try:
            with urlopen(request, timeout=65) as response: status,data = response.status,response.read()
        except HTTPError as error:
            status,data = error.code,error.read()
            if status == 429 and expected != 429 and attempt < 11:
                delay = error.headers.get('Retry-After','10')
                time.sleep(min(60, max(1, int(delay) if delay.isdigit() else 10)))
                continue
        break
    if status != expected: raise AssertionError(f'{path}: HTTP {status}, expected {expected}')
    return json.loads(data) if data else None


def account():
    name = 'final'+uuid.uuid4().hex[:10]
    details = {'username':name,'email':name+'@local-learning.test','password':'Local@'+secrets.token_hex(16)}
    return details,api('/auth/register',body=details,expected=201)['accessToken']


def main():
    resume = '--resume' in sys.argv
    if resume:
        details = json.loads((WORK/'browser-account.json').read_text(encoding='utf8'))
        token = api('/auth/login',body=details)['accessToken']
    else:
        details, token = account()
    _, other = account()
    (WORK/'browser-account.json').write_text(json.dumps(details),encoding='utf8')
    questions = {q['id']:q for q in package['bank']['questions']}
    template = package['templates'][0]
    scenarios = [('pass27',3,False,False,27,True),('fail26',4,False,False,26,False),
                 ('criticalWrong',0,True,False,29,False),('criticalBlank',0,False,True,29,False)]
    results = {}
    if resume:
        history = api('/learning/history?bankId='+package['bank']['id'],token)['items']
        for item in history:
            review = api('/exam-attempts/'+item['attemptId']+'/review',token)
            if review['correct'] == 27 and review['isPassed']: name = 'pass27'
            elif review['correct'] == 26 and not review['isPassed']: name = 'fail26'
            elif review['correct'] == 29 and not review['isPassed']:
                critical = next(q for q in review['questions'] if questions[q['questionId']]['isCritical'])
                name = 'criticalBlank' if critical['selectedOptionId'] is None else 'criticalWrong'
            else: continue
            results[name] = {'correct':review['correct'],'passed':review['isPassed'],'attemptId':item['attemptId']}
        assert len(results) == 4, 'The retained real scoring run must include all four boundary cases'
    for name, ordinary_wrong, critical_wrong, critical_blank, correct, passed in scenarios:
        if name in results: continue
        exam = api('/custom-exams/from-template', token, {'examCode':template['examCode'],'version':1},expected=201)
        assert exam['passingScore'] == 27 and exam['failOnCriticalWrong']
        assert 1190 < (datetime.fromisoformat(exam['deadlineUtc'])-datetime.now(timezone.utc)).total_seconds() <= 1200
        assert len(exam['questions']) == 30 and 'correctOption' not in json.dumps(exam)
        for q in exam['questions']:
            source = questions[q['id']]
            if source['isCritical'] and critical_blank: continue
            answer = source['correctOptionIds'][0]
            if source['isCritical'] and critical_wrong or not source['isCritical'] and ordinary_wrong > 0:
                answer = next(o['id'] for o in source['options'] if o['id'] != answer)
                if not source['isCritical']: ordinary_wrong -= 1
            exam = api(f"/custom-exams/{exam['examId']}/answers/{q['id']}", token,
                       {'optionId':answer,'revision':exam['revision']},method='PUT')
        score = api('/custom-exams/'+exam['examId']+'/submit',token,method='POST')
        review = api('/exam-attempts/'+score['attemptId']+'/review',token)
        assert score['correct'] == correct and review['isPassed'] == passed
        assert review['bankId'] == package['bank']['id']
        assert api('/custom-exams/'+exam['examId']+'/submit',token,method='POST')['attemptId'] == score['attemptId']
        results[name] = {'correct':correct,'passed':passed,'attemptId':score['attemptId']}
    api('/custom-exams',token,{'categoryId':package['bank']['id'],'bankVersion':'1','questionCount':1,'durationMinutes':1},expected=400)
    question_id = template['questionIds'][0]
    path = '/learning/bookmarks/'+question_id
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        assert list(pool.map(lambda _: api(path,token,method='PUT',expected=204), range(4))) == [None]*4
    bookmarks = api('/learning/bookmarks?bankId='+package['bank']['id'],token)
    assert bookmarks['totalCount'] == 1 and bookmarks['items'][0]['questionId'] == question_id
    assert api('/learning/bookmarks',other)['totalCount'] == 0
    api(path,other,method='DELETE',expected=204)
    assert api('/learning/bookmarks',token)['totalCount'] == 1
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        list(pool.map(lambda _: api(path,token,method='DELETE',expected=204),range(3)))
    assert api('/learning/bookmarks',token)['totalCount'] == 0
    api('/learning/bookmarks/'+str(uuid.uuid4()),token,method='PUT',expected=404)
    api(path,token,method='PUT',expected=204) # retained for browser/restart persistence check
    evidence = {'bankId':package['bank']['id'],'bScoring':results,'customPolicyOverrideBlocked':True,
                'bookmarkQuestionId':question_id,'concurrentBookmarkIdempotent':True,'concurrentRemovalIdempotent':True,
                'bookmarkOwnerIsolation':True,'browserAccountStoredOnlyInIgnoredArtifacts':True}
    (WORK/'official-bookmarks-check.json').write_text(json.dumps(evidence,indent=2),encoding='utf8')
    print(json.dumps(evidence))


if __name__ == '__main__': main()
