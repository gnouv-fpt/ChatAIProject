"""Convert the accepted 115 source questions to a repeatable ContentBank package."""
import argparse
import hashlib
import json
import math
import uuid
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]
NAMESPACE = uuid.uuid5(uuid.NAMESPACE_URL, 'chataiweb/local-sa-hinh-learning')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def sha_review_feedback(path):
    # Git may check this text file out with CRLF on Windows; the approved digest
    # was recorded from the same JSON with LF line endings.
    return hashlib.sha256(path.read_bytes().replace(b'\r\n', b'\n')).hexdigest()


def build(asset_root, version='1'):
    parsed = urlsplit(asset_root)
    if (parsed.scheme != 'http' or parsed.hostname not in ('localhost', '127.0.0.1') or
            parsed.path not in ('', '/') or parsed.query or parsed.fragment or parsed.username or parsed.password):
        raise ValueError('Bản local cần origin HTTP loopback, không có path/query/credentials.')
    asset_root = asset_root.rstrip('/') + '/'
    folder = ROOT / 'content-animations' / 'bank-review'
    source = json.loads((folder / 'bank.json').read_text(encoding='utf-8'))
    scenes = json.loads((folder / 'scenes.json').read_text(encoding='utf-8'))['scenes']
    accepted = json.loads((folder / 'accepted-release.json').read_text(encoding='utf-8'))
    if sha(folder / 'scenes.json') != accepted['scenesSha256'] or sha_review_feedback(folder / 'review-feedback-accepted-2026-11-01.json') != accepted['sourceFeedbackSha256']:
        raise ValueError('Dữ liệu không khớp bản mô phỏng đã duyệt.')
    if [q['number'] for q in source['questions']] != list(range(486, 601)):
        raise ValueError('Nguồn phải có đúng 115 câu 486–600 theo thứ tự, không trùng/thiếu.')
    # A change to source, release, URLs, version or the practice policy creates a new package identity.
    identity = '|'.join([sha(folder / 'bank.json'), accepted['scenesSha256'], asset_root, version, 'practice-20-20-80pct-v1'])
    bank_id = uuid.uuid5(NAMESPACE, identity)
    questions = []
    for q in source['questions']:
        number = q['number']
        recipe = scenes[str(number)]
        if recipe['revision'] != accepted['approvedRevisions'].get(str(number)):
            raise ValueError(f'Câu {number}: revision chưa được duyệt.')
        if len(q['correctOptionIds']) != 1 or q['correctOptionIds'][0] not in [o['id'] for o in q['options']]:
            raise ValueError(f'Câu {number}: đáp án nguồn không hợp lệ.')
        assets = []
        for i, a in enumerate(q['images'], 1):
            path = ROOT / 'content-animations' / a['url']
            if not path.resolve().is_relative_to((ROOT / 'content-animations').resolve()) or sha(path) != a['sha256']:
                raise ValueError(f'Câu {number}: ảnh nguồn không khớp SHA-256.')
            assets.append({'id': f'original-{i}', 'url': asset_root + a['url'], 'sha256': a['sha256'],
                           'mimeType': 'image/jpeg' if path.suffix.lower() in ('.jpg', '.jpeg') else 'image/png',
                           'altText': f'Ảnh sa hình gốc câu {number}, hình {i}'})
        if not assets:
            raise ValueError(f'Câu {number}: thiếu ảnh gốc.')
        correct = next(o for o in q['options'] if o['id'] == q['correctOptionIds'][0])
        explanation = f"Đáp án theo PDF nguồn: {correct['id']}. {correct['text']}\n\nDiễn giải mô phỏng đã duyệt:\n"
        explanation += '\n'.join(f"{i}. {s['text']}" for i, s in enumerate(recipe['steps'], 1))
        question_id = uuid.uuid5(bank_id, json.dumps(q, sort_keys=True, ensure_ascii=False))
        questions.append({'id': str(question_id), 'number': number, 'topic': 'Sa hình', 'categoryType': 'SCENARIO',
            'text': q['prompt'], 'explanation': explanation, 'sourceUrl': q['sourceUrl'],
            'isCritical': False, 'allowOptionShuffle': False,
            'options': [{'id': str(o['id']), 'text': o['text']} for o in q['options']],
            'correctOptionIds': [str(q['correctOptionIds'][0])], 'assets': assets,
            'explanationAnimationUrl': asset_root + f'q{number}.html'})
    bank = {'id': str(bank_id), 'version': version, 'title': 'Sa hình 486–600 · 115 câu luyện tập local',
        'sourceUrl': source['sourceUrl'],
        'sourceDescription': 'Trích 115 câu từ PDF nguồn, đáp án theo phương án gạch chân; mô phỏng đã duyệt. '
            'Bộ luyện tập local, không phải đề thi chuẩn GPLX. Mục tiêu tự luyện 80%, mặc định 20 câu/20 phút. '
            'Chưa phân loại câu điểm liệt. SHA-256 PDF: ' + source['sourceSha256'],
        'profile': {'id': 'local-sa-hinh-practice', 'version': '1', 'sourceUrl': source['sourceUrl'],
                    'questionCount': 20, 'durationSeconds': 1200, 'passCount': 16, 'failOnCriticalWrong': False},
        'questions': questions}
    templates = []
    for start in range(0, len(questions), 20):
        group = questions[start:start + 20]
        templates.append({'examCode': f'local-sahinh-{str(bank_id)[:8]}-{start // 20 + 1:02}', 'version': 1,
            'title': f"Luyện sa hình {group[0]['number']}–{group[-1]['number']} · mục tiêu 80%",
            'durationMinutes': len(group), 'passingScore': math.ceil(len(group) * .8),
            'questionIds': [q['id'] for q in group]})
    return {'bank': bank, 'templates': templates, 'evidence': {'sourceBankSha256': sha(folder / 'bank.json'),
        'scenesSha256': accepted['scenesSha256'], 'sourcePdfSha256': source['sourceSha256'],
        'questionCount': len(questions), 'localOnly': True}}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--asset-origin', default='http://localhost:8765')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    result = build(args.asset_origin)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    content = json.dumps(result, ensure_ascii=False, indent=2) + '\n'
    if args.output.exists() and args.output.read_text(encoding='utf-8') != content:
        raise ValueError('Không ghi đè package đã khác nội dung. Chọn file đầu ra mới.')
    args.output.write_text(content, encoding='utf-8')
    print(f"Prepared {len(result['bank']['questions'])} questions, {len(result['templates'])} practice templates; bank {result['bank']['id']}")
