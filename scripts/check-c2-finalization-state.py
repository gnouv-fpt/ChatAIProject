"""Read-only final preservation, restart persistence, SQL/vector and local health checks."""
import hashlib
import importlib.util
import json
import subprocess
from pathlib import Path
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT/'artifacts/c2-finalization'


def main():
    spec = importlib.util.spec_from_file_location('preservation', ROOT/'scripts/check-https-bank-preservation.py')
    module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    before = json.loads((WORK/'before.json').read_text(encoding='utf8'))
    after = module.snapshot()
    for table, rows in before['sql'].items():
        assert all(after['sql'][table].get(key) == digest for key,digest in rows.items()), table
    assert before['files'] == after['files'], 'Accepted static assets or original bank files changed'
    spec = importlib.util.spec_from_file_location('api_checks', ROOT/'scripts/check-official-b-and-bookmarks.py')
    checks = importlib.util.module_from_spec(spec); spec.loader.exec_module(checks)
    runtime = checks.runtime
    token = checks.api('/auth/login', body={'email':runtime['adminEmail'],'password':runtime['adminPassword']})['accessToken']
    banks = checks.api('/question-banks',token)
    baseline = json.loads((ROOT/'artifacts/official-profile/before-import.json').read_text(encoding='utf-8-sig'))
    for bank in baseline['banks']:
        assert next(row for row in banks if row['id']==bank['id'] and row['version']==bank['version']) == bank
    templates = checks.api('/exam-templates',token)
    for template in baseline['templates']:
        assert next(row for row in templates if row['id']==template['id']) == template
    account = json.loads((WORK/'browser-account.json').read_text(encoding='utf8'))
    owner = checks.api('/auth/login',body=account)['accessToken']
    bookmarks = checks.api('/learning/bookmarks?bankId='+checks.package['bank']['id'],owner)
    assert bookmarks['totalCount'] == 1, 'Bookmark did not survive the real host restart'
    ai_account = json.loads((ROOT/'artifacts/local-ai/browser-account.json').read_text(encoding='utf8'))
    ai_token = checks.api('/auth/login',body=ai_account)['accessToken']
    ai_evidence = json.loads((ROOT/'artifacts/local-ai/live-check.json').read_text(encoding='utf8'))
    saved = checks.api('/chats/'+ai_evidence['sessionId'],ai_token)
    assert all(any(message['id']==answer['id'] for message in saved['messages']) for answer in ai_evidence['messages'].values())
    proc = subprocess.run(['sqlcmd','-S','.\\MSSQLSERVER_VUON','-E','-d',runtime['contentDatabase'],'-y','0','-w','65535','-b','-Q',
        'SET NOCOUNT ON; SELECT c.Id,c.Content,c.Article,c.Clause,c.Point,c.IsVerified,d.IsActive,d.SourceUrl '
        'FROM LegalDocumentChunks c JOIN LegalDocuments d ON c.DocumentId=d.Id FOR JSON PATH,INCLUDE_NULL_VALUES;'],
        capture_output=True,text=True,encoding='utf8',check=True)
    chunks = {row['Id'].lower():row for row in json.loads(''.join(proc.stdout.splitlines()).strip())}
    assert len(chunks) == 333 and all(row['IsVerified'] and row['IsActive'] for row in chunks.values())
    points = []
    offset = None
    while True:
        body = {'limit':100,'with_payload':True,'with_vector':False}
        if offset is not None: body['offset'] = offset
        request = Request('http://127.0.0.1:16333/collections/traffic_law_learning_57e824ae_gemini768_v1/points/scroll',
                          data=json.dumps(body).encode(),headers={'Content-Type':'application/json'})
        with urlopen(request,timeout=10) as response: result=json.load(response)['result']
        points.extend(result['points']); offset=result['next_page_offset']
        if offset is None: break
    assert len(points)==333 and len({p['payload']['chunk_id'] for p in points})==333
    for point in points:
        payload=point['payload']; row=chunks[payload['chunk_id'].lower()]
        assert payload['content_hash']==hashlib.sha256(row['Content'].encode()).hexdigest()
        assert payload['content']==row['Content'] and payload['source_url']==row['SourceUrl']
        assert payload['is_verified'] and payload['is_active']
        for a,b in [('article','Article'),('clause','Clause'),('point','Point')]: assert payload[a]==(row[b] or '')
    health={}
    for url in ['http://127.0.0.1:18080/health/live','http://127.0.0.1:15039/health/ready',
                'http://127.0.0.1:15040/health/ready','http://127.0.0.1:15173/','http://127.0.0.1:16333/readyz']:
        with urlopen(url,timeout=5) as response: health[url]=response.status
    evidence={'preservedBaselineRows':{table:len(rows) for table,rows in before['sql'].items()},
              'unchangedProtectedFiles':len(before['files']),'existingBanksUnchanged':len(baseline['banks']),
              'existingTemplatesUnchanged':len(baseline['templates']),'banks':len(banks),'templates':len(templates),
              'bookmarkPersistedAcrossHostRestart':True,'aiHistoryPersistedAcrossHostRestart':True,
              'sqlAndQdrantChunksMatch':333,'localHealth':health}
    (WORK/'state-check.json').write_text(json.dumps(evidence,indent=2),encoding='utf8')
    print(json.dumps(evidence))


if __name__ == '__main__': main()
