"""Probe one Gemini embedding request and report only non-sensitive quota metadata."""
import json
import os
import argparse
import xml.etree.ElementTree as ET
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--batch', type=int, choices=(1, 8, 32), default=1)
    parser.add_argument('--batch-endpoint', action='store_true')
    options = parser.parse_args()
    key = os.environ.get('GEMINI_API_KEY')
    if not key:
        project = ET.parse(ROOT / 'Presentation/Presentation.csproj').getroot()
        secret_id = project.findtext('.//UserSecretsId')
        if not secret_id or '/' in secret_id or '\\' in secret_id:
            raise ValueError('Unexpected user-secrets ID')
        path = Path(os.environ['APPDATA']) / 'Microsoft/UserSecrets' / secret_id / 'secrets.json'
        key = json.loads(path.read_text(encoding='utf-8-sig')).get('Llm:Gemini:ApiKey')
    if not key:
        raise ValueError('No configured Gemini API key')
    item = {'model': 'models/gemini-embedding-001', 'content': {'parts': [{'text': 'traffic law probe'}]},
            'outputDimensionality': 768, 'taskType': 'RETRIEVAL_DOCUMENT'}
    single = options.batch == 1 and not options.batch_endpoint
    body = item if single else {'requests': [item] * options.batch}
    method = 'embedContent' if single else 'batchEmbedContents'
    request = Request('https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:' + method,
                      data=json.dumps(body).encode(), headers={'x-goog-api-key': key,
                                                               'Content-Type': 'application/json'})
    try:
        with urlopen(request, timeout=20) as response:
            result = json.load(response)
        vectors = [result['embedding']] if single else result['embeddings']
        print(json.dumps({'httpStatus': 200, 'vectors': len(vectors),
                          'dimension': len(vectors[0]['values'])}))
    except HTTPError as error:
        data = json.loads(error.read().decode('utf8'))
        details = data.get('error', {}).get('details', [])
        quota = [d.get('metadata', {}) for d in details if isinstance(d, dict)]
        message = data.get('error', {}).get('message', '').lower()
        print(json.dumps({'httpStatus': error.code, 'status': data.get('error', {}).get('status'),
                          'reasons': [d.get('reason') for d in details if isinstance(d, dict) and d.get('reason')],
                          'quotaMetrics': [m.get('quota_metric') for m in quota if m.get('quota_metric')],
                          'mentionsDaily': any(x in message for x in ('per day', 'daily', 'rpd', 'ngày')),
                          'mentionsMinute': any(x in message for x in ('per minute', 'rpm', 'tpm', 'minute')),
                          'retryAfter': error.headers.get('Retry-After')}))
    except URLError as error:
        print(json.dumps({'networkError': type(error.reason).__name__}))


if __name__ == '__main__':
    main()
