"""Import the exact reviewed 168/238 text into the isolated local-learning stack."""
import argparse
import hashlib
import json
import re
import time
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
LEGAL = ROOT / 'content-bank/legal'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--activate', action='store_true')
    parser.add_argument('--trial-activate', action='store_true')
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()
    if args.activate and args.trial_activate:
        parser.error('Choose one activation mode')
    package = json.loads((LEGAL / '168-238-all-articles-merged-review.json').read_text(encoding='utf8'))
    base = json.loads((LEGAL / '168-2024-source-reviewed.json').read_text(encoding='utf8'))
    amendment = json.loads((LEGAL / '238-2026-source-reviewed.json').read_text(encoding='utf8'))
    if package['reviewStatus'] != 'FullTextPendingEffectiveDateAndFinalReview' or package['isActive'] or \
            len(package['articles']) != 55 or len(package['effectiveDateExceptions']) != 7 or \
            [a['number'] for a in package['articles']] != list(range(1, 56)) or \
            package['baseArticleHashes'] != [a['contentSha256'] for a in base['articles']] or \
            package['amendmentContentSha256'] != amendment['contentSha256']:
        raise ValueError('Reviewed corpus or effectivity inventory changed')
    if args.activate or args.trial_activate:
        raise ValueError('The 55-article consolidation is still pending legal/effectivity review. '
                         'Use import-targeted-sanctions.py for the reviewed narrow scope.')
    for article in package['articles']:
        if hashlib.sha256(article['content'].encode()).hexdigest() != article['contentSha256']:
            raise ValueError(f'Article {article["number"]} hash changed')
    content = '\n'.join(a['content'] for a in package['articles'])
    runtime = json.loads((ROOT / 'artifacts/local-learning/runtime.json').read_text(encoding='utf-8-sig'))
    if runtime['gateway'] != 'http://127.0.0.1:18080' or \
            not re.fullmatch(r'TrafficContent_WebLearning_[a-f0-9]{8}', runtime['contentDatabase']) or \
            runtime['userDatabase'] != runtime['contentDatabase'].replace('TrafficContent_', 'TrafficUser_', 1):
        raise ValueError('Only the isolated local-learning database may be modified')
    if args.dry_run:
        print(json.dumps({'localOnly': True, 'articles': 55,
                          'contentSha256': hashlib.sha256(content.encode()).hexdigest(),
                          'effectivityExceptions': len(package['effectiveDateExceptions']),
                          'reviewStatus': package['reviewStatus'], 'active': False}))
        return

    def api(path, body=None, token=None):
        request = Request(runtime['gateway'] + '/api' + path,
                          data=json.dumps(body, ensure_ascii=False).encode('utf8') if body is not None else None,
                          headers={'Content-Type': 'application/json', **({'Authorization': 'Bearer ' + token} if token else {})})
        for attempt in range(8):
            try:
                with urlopen(request, timeout=360) as response:
                    return json.load(response)
            except HTTPError as error:
                if error.code == 429 and attempt < 7:
                    time.sleep(10)
                    continue
                raise RuntimeError(f'Local API {path}: HTTP {error.code}') from None

    token = api('/auth/login', {'email': runtime['adminEmail'], 'password': runtime['adminPassword']})['accessToken']
    payload = {'sourceUrl': base['sourceUrl'], 'officialSourceUrl':
               'https://datafiles.chinhphu.vn/cpp/files/vbpq/2025/01/168-nd-cp.signed.pdf',
               'documentNumber': '168/2024/NĐ-CP',
               'documentTitle': 'Nghị định 168/2024/NĐ-CP, được sửa đổi bởi Nghị định 238/2026/NĐ-CP',
               'content': content, 'contentSha256': hashlib.sha256(content.encode()).hexdigest(),
               'articles': [str(n) for n in range(1, 56)],
               'reviewNotes': 'Nguồn gốc 168 và 238 đã đối chiếu Công báo/TVPL theo hash; '
                              'toàn văn 55 điều hợp nhất. Điều 53 khoản 2, 3, 4 chứa ngoại lệ hiệu lực; '
                              'phải đối chiếu loại xe và ngày vi phạm. Nguồn sửa đổi: ' + amendment['sourceUrl']}
    imported = api('/documents/import-reviewed-capture', payload, token)
    print(json.dumps({'localOnly': True, 'documentId': imported['documentId'],
                      'chunkCount': imported['chunkCount'], 'active': False}))


if __name__ == '__main__':
    main()
