"""Index the reviewed QCVN B.1/B.2 passages in the isolated evaluation stack."""
import hashlib
import json
import re
from pathlib import Path
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]


def main():
    package = json.loads((ROOT / 'content-bank/legal/qcvn41-2024-signs-b1-b2-reviewed.json')
                         .read_text(encoding='utf8'))
    content = package['content']
    pdf_path = ROOT / 'artifacts/local-ai/qcvn41-2024-official.pdf'
    if pdf_path.exists():
        pdf = pdf_path.read_bytes()
    else:
        with urlopen(package['officialSourceUrl'], timeout=90) as response:
            pdf = response.read()
    if package['reviewStatus'] != 'TwoOfficialSignClausesReviewed' or package['isActive'] or \
            hashlib.sha256(pdf).hexdigest() != package['officialPdfSha256'] or \
            hashlib.sha256(content.encode()).hexdigest() != package['contentSha256'] or \
            hashlib.sha256('\n'.join(sorted(line.strip() for line in content.splitlines()
                                              if line.strip())).encode()).hexdigest() != package['lineSetSha256']:
        raise ValueError('Reviewed QCVN source changed')
    runtime = json.loads((ROOT / 'artifacts/local-ai/integration-runtime.json').read_text())
    if not re.fullmatch(r'TrafficContent_ChatEval_[a-f0-9]{8}', runtime['contentDatabase']) or \
            runtime['gatewayPort'] != 18080:
        raise ValueError('Only isolated evaluation databases are permitted')
    base = f"http://127.0.0.1:{runtime['gatewayPort']}/api"

    def api(path, body=None, token=None):
        headers = {'Content-Type': 'application/json'}
        if token:
            headers['Authorization'] = 'Bearer ' + token
        data = json.dumps(body, ensure_ascii=False).encode() if body is not None else None
        with urlopen(Request(base + path, data, headers), timeout=240) as response:
            return json.load(response)

    token = api('/auth/login', {'email': runtime['adminEmail'],
                                'password': runtime['adminPassword']})['accessToken']
    payload = {'sourceUrl': package['sourceUrl'], 'officialSourceUrl': package['officialSourceUrl'],
               'documentNumber': package['documentNumber'], 'documentTitle': package['documentTitle'],
               'content': content, 'contentSha256': package['contentSha256'],
               'articles': package['articles'], 'reviewNotes': package['notes']}
    imported = api('/documents/import-reviewed-capture', payload, token)
    indexed = api('/documents/' + imported['documentId'] + '/verify-and-index',
                  {'evidenceUrl': package['sourceUrl'], 'effectiveDate': '2025-01-01T00:00:00Z',
                   'sourceAndAmendmentsReviewed': True, 'reviewNotes': package['notes']}, token)
    if not indexed['success'] or indexed['indexedCount'] != imported['chunkCount']:
        raise RuntimeError('QCVN SQL/Qdrant chunk count mismatch')
    print(json.dumps({'documentId': imported['documentId'], 'chunks': imported['chunkCount'],
                      'indexed': indexed['indexedCount'], 'localOnly': True}))


if __name__ == '__main__':
    main()
