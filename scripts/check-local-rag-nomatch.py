"""Repeat the existing sanctions-outside-corpus diagnostic after edition 4 activation."""
import importlib.util
import json
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('checks', ROOT / 'scripts/check-official-b-and-bookmarks.py')
checks = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checks)


def main():
    _, token = checks.account()
    api = lambda path, body=None, expected=200: checks.api(path, token, body, expected=expected)
    session = api('/chats', {'title': 'Chẩn đoán NoMatch edition 4'}, expected=201)
    prompt = 'Mức phạt bằng tiền chính xác cho ô tô vượt đèn đỏ là bao nhiêu?'
    answer = api('/chats/' + session['id'] + '/messages',
                 {'requestId': str(uuid.uuid4()), 'prompt': prompt,
                  'attachmentIds': [], 'usePreviousAttachments': False})
    result = {'source': 'existing check-local-ai.py diagnostic', 'status': answer['status'],
              'citationCount': len(answer.get('citations') or []),
              'expectedNoMatch': answer['status'] == 'NoMatch' and not answer.get('citations')}
    (ROOT / 'artifacts/local-ai/edition-4-nomatch.json').write_text(json.dumps(result, indent=2), encoding='utf8')
    print(json.dumps(result))


if __name__ == '__main__':
    main()
