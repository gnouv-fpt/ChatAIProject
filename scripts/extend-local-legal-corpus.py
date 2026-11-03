"""Activate the reviewed Article 34–49 extension in the recorded local stack."""
import importlib.util
import json
import re
import uuid
import time
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / 'artifacts/local-ai'


def main():
    spec = importlib.util.spec_from_file_location('review', ROOT / 'scripts/prepare-reviewed-legal-extension.py')
    review = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(review)
    review.prepare()
    source = json.loads((ROOT / 'content-bank/legal/55-2026-articles-34-49-review.json').read_text(encoding='utf8'))
    original = json.loads((WORK / 'import-result.json').read_text(encoding='utf8'))
    runtime = json.loads((ROOT / 'artifacts/local-learning/runtime.json').read_text(encoding='utf-8-sig'))
    if runtime['gateway'] != 'http://127.0.0.1:18080' or runtime['content'] != 'http://127.0.0.1:15040' or \
            not re.fullmatch(r'TrafficContent_WebLearning_[a-f0-9]{8}', runtime['contentDatabase']) or \
            runtime['userDatabase'] != runtime['contentDatabase'].replace('TrafficContent_', 'TrafficUser_', 1):
        raise ValueError('Unexpected local stack; refusing to modify it.')
    if not uuid.UUID(original['documentId']) or original['chunkCount'] != 333:
        raise ValueError('The original corpus does not match the recorded local baseline.')

    def api(path, body=None, token=None, direct=False):
        request = Request((runtime['content'] if direct else runtime['gateway']) + '/api' + path,
                          data=json.dumps(body, ensure_ascii=False).encode() if body is not None else None,
                          headers={'Content-Type': 'application/json', **({'Authorization': 'Bearer ' + token} if token else {})})
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
    request = {'capture': capture, 'expectedCurrentHash': original['contentHash'], 'expectedCurrentVersion': 1}
    result = api('/documents/extend-reviewed-capture', request, token, direct=True)
    if result['documentId'] != original['documentId'] or result['version'] != 2 or result['addedChunkCount'] < 16 or \
            result['chunkCount'] != original['chunkCount'] + result['addedChunkCount'] or not result['isActive']:
        raise AssertionError('The expanded edition was not activated as expected.')
    repeated = api('/documents/extend-reviewed-capture', request, token, direct=True)
    if repeated != result:
        raise AssertionError('The extension is not idempotent.')
    (WORK / 'extension-import-result.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf8')
    print(json.dumps(result, ensure_ascii=False))


if __name__ == '__main__':
    main()
