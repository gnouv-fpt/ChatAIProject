"""Prepare a local import preview; never writes Content SQL or publishes a bank."""
import argparse
import hashlib
import json
import re
import unicodedata
import uuid
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]


def normalized(value):
    return ' '.join(unicodedata.normalize('NFC', value).split())


def prepare(bank, bank_id, version, base_url, source, release):
    if str(uuid.UUID(bank['id'])) != str(uuid.UUID(bank_id)) or bank['version'] != version:
        raise ValueError('Bank ID/version không khớp bản được chỉ định.')
    if not re.fullmatch(r'[1-9][0-9]*', version):
        raise ValueError('Bank version phải là số nguyên dương.')
    parsed = urlsplit(base_url)
    if (parsed.scheme != 'https' or not parsed.hostname or parsed.port not in (None, 443)
            or parsed.username or parsed.password or parsed.query or parsed.fragment
            or not base_url.endswith('/') or parsed.hostname in ('localhost', '127.0.0.1')
            or re.search(r'[\s\\%]', base_url) or any(p in ('.', '..') for p in parsed.path.split('/'))):
        raise ValueError('Cần base URL HTTPS kết thúc bằng /, không dùng localhost/query/fragment.')
    questions = bank['questions']
    ids = [str(uuid.UUID(q['id'])) for q in questions]
    numbers = [q['number'] for q in questions]
    if len(ids) != len(set(ids)) or len(numbers) != len(set(numbers)):
        raise ValueError('ID hoặc số câu bị trùng trong ngân hàng.')
    by_number = {q['number']: q for q in questions}
    links = []
    for original in source['questions']:
        number = original['number']
        question = by_number.get(number)
        if question is None or str(number) not in release['approvedRevisions']:
            raise ValueError(f'Câu {number}: thiếu câu hoặc revision được duyệt.')
        if normalized(question['text']) != normalized(original['prompt']):
            raise ValueError(f'Câu {number}: nội dung khác nguồn mô phỏng.')
        options = question['options']
        if [normalized(o['text']) for o in options] != [normalized(o['text']) for o in original['options']]:
            raise ValueError(f'Câu {number}: phương án hoặc thứ tự khác nguồn mô phỏng.')
        option_ids = [o['id'] for o in options]
        if len(set(option_ids)) != len(option_ids):
            raise ValueError(f'Câu {number}: trùng ID phương án.')
        correct = [options[i]['id'] for i, o in enumerate(original['options']) if o['id'] in original['correctOptionIds']]
        if question['correctOptionIds'] != correct:
            raise ValueError(f'Câu {number}: đáp án khác nguồn mô phỏng.')
        if sorted(a['sha256'].lower() for a in question['assets']) != sorted(a['sha256'].lower() for a in original['images']):
            raise ValueError(f'Câu {number}: SHA-256 ảnh khác nguồn mô phỏng.')
        links.append({'questionId': question['id'], 'explanationAnimationUrl': base_url + f'q{number}.html'})
    # This is a preview for the existing admin import/preflight flow. It does not mutate the input.
    return {'bank': bank, 'animations': links}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bank', type=Path, required=True, help='ContentBank JSON (camelCase), before import')
    parser.add_argument('--bank-id', required=True)
    parser.add_argument('--version', required=True)
    parser.add_argument('--base-url', required=True, help='Actual HTTPS learner hosting root, ending in /')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    folder = ROOT / 'content-animations/bank-review'
    release = json.loads((folder / 'accepted-release.json').read_text(encoding='utf-8'))
    if hashlib.sha256((folder / 'scenes.json').read_bytes()).hexdigest() != release['scenesSha256']:
        raise ValueError('Scenes không khớp bản đã duyệt.')
    source = json.loads((folder / 'bank.json').read_text(encoding='utf-8'))
    bank = json.loads(args.bank.read_text(encoding='utf-8-sig'))
    result = prepare(bank, args.bank_id, args.version, args.base_url, source, release)
    # Exclusive creation prevents overwriting a reviewed bank or manifest by accident.
    with args.output.open('x', encoding='utf-8') as output:
        json.dump(result, output, ensure_ascii=False, indent=2)
    print(f"Prepared {len(result['animations'])} links for bank {args.bank_id}, version {args.version}: {args.output}")


if __name__ == '__main__':
    main()
