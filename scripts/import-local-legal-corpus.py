"""Import/activate the reviewed TVPL corpus only in the existing isolated LOCAL stack."""
import importlib.util
import json
import re
import subprocess
import time
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / 'artifacts/local-ai'


def main():
    spec = importlib.util.spec_from_file_location('corpus', ROOT / 'scripts/prepare-reviewed-legal-corpus.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.prepare()
    source = json.loads((ROOT / 'content-bank/legal/55-2026-articles-1-33.json').read_text(encoding='utf8'))
    runtime = json.loads((ROOT / 'artifacts/local-learning/runtime.json').read_text(encoding='utf-8-sig'))
    if runtime['gateway'] != 'http://127.0.0.1:18080' or runtime['content'] != 'http://127.0.0.1:15040' or \
            not re.fullmatch(r'TrafficContent_WebLearning_[a-f0-9]{8}', runtime['contentDatabase']) or \
            runtime['userDatabase'] != runtime['contentDatabase'].replace('TrafficContent_', 'TrafficUser_', 1):
        raise ValueError('This importer is restricted to the recorded local-learning database.')
    def api(path, body=None, token=None):
        request = Request(runtime['gateway']+'/api'+path, data=json.dumps(body).encode() if body is not None else None,
                          headers={'Content-Type': 'application/json', **({'Authorization': 'Bearer '+token} if token else {})})
        for attempt in range(12):
            try:
                with urlopen(request, timeout=360) as response: return json.load(response)
            except HTTPError as error:
                if error.code == 429 and attempt < 11:
                    time.sleep(10)
                    continue
                raise RuntimeError(f'Local API {path}: HTTP {error.code}') from None
    token = api('/auth/login', {'email': runtime['adminEmail'], 'password': runtime['adminPassword']})['accessToken']
    payload = {key: source[key] for key in ('sourceUrl','documentNumber','documentTitle','content','contentSha256','articles','officialSourceUrl','reviewNotes')}
    imported = api('/documents/import-reviewed-capture', payload, token)
    document = api('/documents/'+imported['documentId'], token=token)
    indexed = None
    if not document['isActive']:
        indexed = api('/documents/'+imported['documentId']+'/verify-and-index', {
            'evidenceUrl': source['sourceUrl'], 'effectiveDate': source['effectiveFromUtc'],
            'sourceAndAmendmentsReviewed': True, 'reviewNotes': source['reviewNotes']}, token)
        assert indexed['success'] and indexed['indexedCount'] == imported['chunkCount']
    retry = api('/documents/import-reviewed-capture', payload, token)
    assert retry == imported, 'Corpus import must be idempotent without changing chunk IDs'
    result = {'localOnly': True, 'captureMethod': source['captureMethod'], **imported,
              'articlesCompared': 33, 'indexed': indexed, 'idempotentImport': True,
              'officialPdfSha256': source['evidence']['officialPdfSha256']}
    (WORK / 'import-result.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf8')
    print(json.dumps(result, ensure_ascii=False))


if __name__ == '__main__': main()
