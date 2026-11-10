"""Build source-bound visual lookup for published one-image CSGT questions."""
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]
BANK = ROOT / 'content-bank/csgt-2025-B-current/package.json'
OUTPUT = ROOT / 'grpc_inference_service/visual_question_fingerprints.json'


def fingerprint(image):
    values = ImageOps.grayscale(image).resize((32, 32)).tobytes()
    mean = sum(values) / len(values)
    return format(sum(1 << index for index, value in enumerate(values) if value >= mean), '0256x')


def main():
    source = json.loads(BANK.read_text(encoding='utf8'))
    bank_questions = source['bank']['questions']
    if len(bank_questions) != 600 or [q['number'] for q in bank_questions] != list(range(1, 601)):
        raise ValueError('Published CSGT bank is incomplete')
    questions = [q for q in bank_questions if len(q['assets']) == 1]
    if len(questions) != 317 or sum(q['categoryType'] == 'SCENARIO' for q in questions) != 115:
        raise ValueError('Published one-image question inventory changed')
    rows = []
    for question in questions:
        if len(question['correctOptionIds']) != 1:
            raise ValueError(f"Unexpected source shape at question {question['number']}")
        asset = question['assets'][0]
        folder = 'bank-review' if question['categoryType'] == 'SCENARIO' else 'question-bank-600'
        image_path = ROOT / f"content-animations/{folder}/{question['number']}"
        matches = list(image_path.glob('image-1.*'))
        if len(matches) != 1:
            raise ValueError(f"Missing unique source image at question {question['number']}")
        image_path = matches[0]
        image_bytes = image_path.read_bytes()
        if hashlib.sha256(image_bytes).hexdigest() != asset['sha256']:
            raise ValueError(f"Source image hash differs at question {question['number']}")
        with Image.open(image_path) as image:
            visual_hash = fingerprint(image)
        selected = [option for option in question['options'] if option['id'] in question['correctOptionIds']]
        if len(selected) != 1:
            raise ValueError(f"Source answer differs at question {question['number']}")
        rows.append({'number': question['number'], 'category': question['categoryType'],
                     'question': question['text'],
                     'answer': f"{selected[0]['id']}. {selected[0]['text']}",
                     'source_url': question['sourceUrl'], 'image_sha256': asset['sha256'],
                     'visual_hash': visual_hash})
    payload = {'source_pdf_sha256': source['evidence']['sourcePdfSha256'], 'questions': rows}
    OUTPUT.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + '\n', encoding='utf8')
    print(f'Wrote {len(rows)} source-bound visual fingerprints')


if __name__ == '__main__':
    main()
