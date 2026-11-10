"""Import and optionally activate the reviewed narrow sanction scope in the isolated stack."""
import argparse
import hashlib
import json
import re
import time
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = ROOT / 'content-bank/legal/168-238-targeted-sanctions-reviewed.json'
RUNTIME = ROOT / 'artifacts/local-ai/integration-runtime.json'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--trial-activate', action='store_true')
    args = parser.parse_args()
    package = json.loads(PACKAGE.read_text(encoding='utf8'))
    content = package['content']
    if package['reviewStatus'] != 'TargetedUnchangedTextReviewed' or package['isActive'] or \
            package['articles'] != [6, 7, 12] or \
            hashlib.sha256(content.encode()).hexdigest() != package['contentSha256'] or \
            hashlib.sha256('\n'.join(sorted(line.strip() for line in content.splitlines()
                                              if line.strip())).encode()).hexdigest() != package['lineSetSha256']:
        raise ValueError('Targeted source package changed')
    runtime = json.loads(RUNTIME.read_text(encoding='utf8'))
    if not re.fullmatch(r'TrafficContent_ChatEval_[a-f0-9]{8}', runtime['contentDatabase']) or \
            runtime['gatewayPort'] != 18080:
        raise ValueError('Only the isolated chat evaluation stack is permitted')
    base = f"http://127.0.0.1:{runtime['gatewayPort']}/api"

    def api(path, body=None, token=None):
        data = json.dumps(body, ensure_ascii=False).encode() if body is not None else None
        headers = {'Content-Type': 'application/json'}
        if token:
            headers['Authorization'] = 'Bearer ' + token
        for attempt in range(5):
            try:
                with urlopen(Request(base + path, data, headers), timeout=240) as response:
                    return json.load(response)
            except HTTPError as error:
                if error.code == 429 and attempt < 4:
                    time.sleep(10)
                    continue
                raise RuntimeError(f'{path}: HTTP {error.code}') from None

    token = api('/auth/login', {'email': runtime['adminEmail'],
                                'password': runtime['adminPassword']})['accessToken']
    payload = {'sourceUrl': package['sourceUrl'], 'officialSourceUrl': package['officialSourceUrl'],
               'documentNumber': package['documentNumber'], 'documentTitle': package['documentTitle'],
               'content': content, 'contentSha256': package['contentSha256'],
               'articles': [str(n) for n in package['articles']],
               'reviewNotes': package['notes'] + ' Source amendment: ' + package['amendmentSourceUrl']}
    imported = api('/documents/import-reviewed-capture', payload, token)
    if args.trial_activate:
        result = api('/documents/' + imported['documentId'] + '/verify-and-index',
                     {'evidenceUrl': package['sourceUrl'],
                      'effectiveDate': '2025-01-01T00:00:00Z',
                      'sourceAndAmendmentsReviewed': True,
                      'reviewNotes': payload['reviewNotes']}, token)
        if not result['success'] or result['indexedCount'] != imported['chunkCount']:
            raise RuntimeError('SQL and Qdrant chunk counts differ')
    document = api('/documents/' + imported['documentId'], token=token)
    print(json.dumps({'localOnly': True, 'documentId': imported['documentId'],
                      'chunkCount': imported['chunkCount'], 'active': document['isActive'],
                      'scope': package['scope']}, ensure_ascii=False))


if __name__ == '__main__':
    main()
