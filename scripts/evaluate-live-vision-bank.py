"""Probe held-out CSGT sign images through the real gRPC image/RAG path.

These images are outside the 115-image scenario fingerprint lookup. The report
keeps every response, including abstentions, for source-answer review.
"""
import argparse
import json
import mimetypes
import re
import sys
from pathlib import Path

import grpc

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'grpc_inference_service'))
import chat_inference_pb2 as pb  # noqa: E402
import chat_inference_pb2_grpc as rpc  # noqa: E402

DEFAULT_NUMBERS = (310, 315, 320, 325, 335, 350, 367, 400, 450, 480)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--target', default='127.0.0.1:15051')
    parser.add_argument('--number', type=int, action='append')
    parser.add_argument('--all-published', action='store_true',
                        help='Probe every one-image question in the published 600-question bank')
    parser.add_argument('--output', type=Path,
                        default=ROOT / 'artifacts/local-ai/held-out-vision-bank.json')
    args = parser.parse_args()
    package = json.loads((ROOT / 'content-bank/csgt-2025-B-current/package.json').read_text(encoding='utf8'))
    bank = package['bank']
    questions = {q['number']: q for q in bank['questions']}
    if args.all_published and args.number:
        parser.error('Choose --all-published or --number')
    numbers = ([q['number'] for q in bank['questions'] if len(q['assets']) == 1]
               if args.all_published else args.number or DEFAULT_NUMBERS)
    rows = []
    with grpc.insecure_channel(args.target) as channel:
        stub = rpc.TrafficRagInferenceStub(channel)
        for number in numbers:
            q = questions[number]
            if len(q['assets']) != 1 or not args.all_published and q['categoryType'] != 'SIGN':
                raise ValueError(f'Question {number} is not in the selected one-image scope')
            folder = 'bank-review' if q['categoryType'] == 'SCENARIO' else 'question-bank-600'
            images = list((ROOT / f'content-animations/{folder}/{number}').glob('image-1.*'))
            if len(images) != 1:
                raise ValueError(f'Expected one source image for question {number}')
            image = images[0]
            mime = mimetypes.guess_type(image.name)[0]
            if mime not in ('image/jpeg', 'image/png', 'image/webp'):
                raise ValueError(f'Unsupported image type for {number}')
            prompt = (f"Câu {number}: {q['text']}\n" +
                      '\n'.join(f"{o['id']}. {o['text']}" for o in q['options']))
            request = pb.ChatInferenceRequest(
                prompt=prompt, max_tokens=8192,
                images=[pb.ChatImage(content=image.read_bytes(), mime_type=mime)])
            row = {'number': number, 'sourcePdfSha256': package['evidence']['sourcePdfSha256'],
                   'sourceUrl': q['sourceUrl'], 'expectedOptionIds': q['correctOptionIds'],
                   'question': q['text'], 'image': str(image.relative_to(ROOT))}
            try:
                result = stub.ProcessChatMessage(request, timeout=90)
                row.update({'status': result.result_status, 'answer': result.response_text,
                            'tokensUsed': result.tokens_used,
                            'citations': [{'article': c.article_number, 'clause': c.clause_number,
                                           'point': c.point_number, 'sourceUrl': c.source_url}
                                          for c in result.citations]})
                chosen = re.search(r'(?:đáp án|phương án|chọn)\s*(?:đúng\s*)?[:：]?\s*(\d)\b',
                                   result.response_text, re.IGNORECASE)
                row['parsedOptionId'] = chosen.group(1) if chosen else None
                row['answerMatchesSource'] = row['parsedOptionId'] in q['correctOptionIds']
            except grpc.RpcError as error:
                row.update({'status': 'RpcError', 'code': error.code().name,
                            'detail': (error.details() or '')[:200]})
            rows.append(row)
            print(json.dumps({'number': number, 'status': row['status'],
                              'parsedOptionId': row.get('parsedOptionId'),
                              'expectedOptionIds': row['expectedOptionIds'],
                              'citations': len(row.get('citations', []))}, ensure_ascii=False), flush=True)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps({'target': args.target, 'cases': rows},
                                      ensure_ascii=False, indent=2), encoding='utf8')
    print(json.dumps({'checked': len(rows),
                      'answered': sum(r['status'] in ('Answered', 'PracticeAnswered') for r in rows),
                      'correct': sum(r.get('answerMatchesSource', False) for r in rows),
                      'output': str(args.output)}, ensure_ascii=False))


if __name__ == '__main__':
    main()
