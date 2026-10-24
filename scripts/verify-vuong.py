"""Real HTTP smoke checks. Creates disposable test accounts; never prints tokens/secrets.

Run against a disposable environment:
python scripts/verify-vuong.py --base http://127.0.0.1:5080 --expect-ai-unavailable
Omit --expect-ai-unavailable for the real integrated RAG demo (requires an answer with citations).
"""
import argparse
import base64
import json
import secrets
import urllib.error
import urllib.request
import uuid


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--base', default='http://127.0.0.1:5080')
    parser.add_argument('--expect-ai-unavailable', action='store_true')
    args = parser.parse_args()
    checks = []

    def call(path, method='GET', data=None, token=None, expected=200, content_type='application/json'):
        body = json.dumps(data).encode() if isinstance(data, dict) else data
        headers = {'Content-Type': content_type}
        if token:
            headers['Authorization'] = 'Bearer ' + token
        request = urllib.request.Request(args.base.rstrip('/') + path, body, headers, method=method)
        try:
            response = urllib.request.urlopen(request, timeout=90)
        except urllib.error.HTTPError as error:
            response = error
        payload = response.read()
        if response.status != expected:
            # Do not include bodies, which could contain credentials or private user content.
            raise AssertionError(f'{method} {path}: expected {expected}, received {response.status}')
        checks.append(f'{method} {path}: {expected}')
        if 'application/json' in response.headers.get('Content-Type', '') or 'application/problem+json' in response.headers.get('Content-Type', ''):
            return json.loads(payload)
        return payload

    call('/api/chats', expected=401)
    def register():
        name = 'smoke_' + uuid.uuid4().hex[:12]
        result = call('/api/auth/register', 'POST', {'username': name, 'email': name + '@example.test', 'password': secrets.token_urlsafe(20) + 'aA1!'}, expected=201)
        return result['accessToken'], result['refreshToken']
    token, refresh = register()
    other, _ = register()
    call('/api/auth/profile', token=token)
    session = call('/api/chats', 'POST', {'title': 'Vương · HTTP smoke test'}, token, 201)['id']
    call('/api/chats/' + session, token=other, expected=404)
    call('/api/chats/' + session + '/messages', 'POST', {'prompt': 'Test'}, token, 400)
    png = base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+j4XcAAAAASUVORK5CYII=')
    boundary = 'smoke-' + uuid.uuid4().hex
    def upload(content, mime, expected):
        body = (f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="test.png"\r\nContent-Type: {mime}\r\n\r\n'.encode() + content + f'\r\n--{boundary}--\r\n'.encode())
        return call(f'/api/chats/{session}/attachments', 'POST', body, token, expected, f'multipart/form-data; boundary={boundary}')
    upload(b'not an image', 'image/png', 400)
    image = upload(png, 'image/png', 201)['id']
    call(f'/api/chats/{session}/attachments/{image}', token=token)
    call(f'/api/chats/{session}/attachments/{image}', token=other, expected=404)
    request = {'requestId': str(uuid.uuid4()), 'prompt': 'Xe máy vượt đèn đỏ bị xử phạt thế nào?', 'attachmentIds': []}
    endpoint = f'/api/chats/{session}/messages'
    if args.expect_ai_unavailable:
        call(endpoint, 'POST', request, token, 503)
        detail = call('/api/chats/' + session, token=token)
        assert not detail['messages'], 'Provider failure was saved as a successful message'
    else:
        first = call(endpoint, 'POST', request, token)
        assert first['status'] == 'Answered' and first['citations'], 'No verified legal answer'
        replay = call(endpoint, 'POST', request, token)
        assert first['id'] == replay['id'], 'Replay created another answer'
        call(endpoint, 'POST', dict(request, prompt='Nội dung khác'), token, 409)
    renewed = call('/api/auth/refresh-token', 'POST', {'refreshToken': refresh})
    call('/api/auth/refresh-token', 'POST', {'refreshToken': refresh}, expected=401)
    token = renewed['accessToken']
    call(f'/api/chats/{session}/attachments/{image}', 'DELETE', token=token, expected=204)
    call('/api/chats/' + session, 'DELETE', token=token, expected=204)
    call('/api/chats/' + session, token=token, expected=404)
    call('/api/auth/logout', 'POST', {'refreshToken': renewed['refreshToken']}, expected=204)
    print(json.dumps({'passed': len(checks), 'mode': 'AI unavailable; no RAG success claimed' if args.expect_ai_unavailable else 'verified RAG HTTP', 'checks': checks}, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
