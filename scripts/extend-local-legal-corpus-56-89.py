"""Retry-safe edition 4 import on the recorded isolated local stack."""
import importlib.util
import json
import re
import uuid
import subprocess
import time
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / 'artifacts/local-ai'


def main():
    spec = importlib.util.spec_from_file_location('review', ROOT / 'scripts/prepare-reviewed-legal-extension-56-89.py')
    review = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(review)
    review.prepare()
    source = json.loads((ROOT / 'content-bank/legal/55-2026-articles-56-89-review.json').read_text(encoding='utf8'))
    previous = json.loads((WORK / 'extension-50-55-import-result.json').read_text(encoding='utf8'))
    runtime = json.loads((ROOT / 'artifacts/local-learning/runtime.json').read_text(encoding='utf-8-sig'))
    if runtime['gateway'] != 'http://127.0.0.1:18080' or runtime['content'] != 'http://127.0.0.1:15040' or \
            not re.fullmatch(r'TrafficContent_WebLearning_[a-f0-9]{8}', runtime['contentDatabase']) or \
            runtime['userDatabase'] != runtime['contentDatabase'].replace('TrafficContent_', 'TrafficUser_', 1) or \
            not uuid.UUID(previous['documentId']) or \
            previous['version'] != 3 or previous['chunkCount'] != 596:
        raise ValueError('Unexpected isolated local stack or edition 3 baseline')

    def api(path, body, token=None, direct=False):
        request = Request((runtime['content'] if direct else runtime['gateway']) + '/api' + path,
                          data=json.dumps(body, ensure_ascii=False).encode(),
                          headers={'Content-Type': 'application/json',
                                   **({'Authorization': 'Bearer ' + token} if token else {})})
        for attempt in range(12):
            try:
                with urlopen(request, timeout=1200) as response:
                    return json.load(response)
            except HTTPError as error:
                if error.code == 429 and attempt < 11:
                    time.sleep(int(error.headers.get('Retry-After', '10')))
                    continue
                raise RuntimeError(f'Local API {path}: HTTP {error.code}') from None

    token = api('/auth/login', {'email': runtime['adminEmail'], 'password': runtime['adminPassword']})['accessToken']
    capture = {key: source[key] for key in ('sourceUrl', 'documentNumber', 'documentTitle', 'content',
                                             'contentSha256', 'articles', 'officialSourceUrl', 'reviewNotes')}
    request = {'capture': capture, 'expectedCurrentHash': previous['contentHash'], 'expectedCurrentVersion': 3}
    result = api('/documents/extend-reviewed-capture', request, token, direct=True)
    if result['documentId'] != previous['documentId'] or result['version'] != 4 or \
            result['chunkCount'] != 596 + result['addedChunkCount'] or \
            result['addedChunkCount'] != 379 or not result['isActive']:
        raise AssertionError('Edition 4 response does not match reviewed scope')
    if api('/documents/extend-reviewed-capture', request, token, direct=True) != result:
        raise AssertionError('Edition 4 retry is not idempotent')
    checked = subprocess.run(['python', '-X', 'utf8', str(ROOT / 'scripts/check-legal-corpus-extension.py')],
                             cwd=ROOT, capture_output=True, text=True, check=True)
    verification = json.loads(checked.stdout.strip())
    if verification['version'] != 4 or verification['sqlChunks'] != result['chunkCount'] or \
            verification['qdrantPoints'] != result['chunkCount'] or not verification['allPayloadsMatch']:
        raise AssertionError('Full SQL–Qdrant comparison did not pass')
    (WORK / 'extension-56-89-import-result.json').write_text(
        json.dumps({'import': result, 'comparison': verification}, ensure_ascii=False, indent=2), encoding='utf8')
    print(json.dumps({'import': result, 'comparison': verification}, ensure_ascii=False))


if __name__ == '__main__':
    main()
