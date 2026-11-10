"""Evaluate official CSGT questions through Gateway, both SQL stores and live AI.

Requires the task-local integration stack in artifacts/local-ai/integration-runtime.json.
The report deliberately excludes authentication data.
"""
import argparse
import json
import re
import time
import uuid
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
REQUIRED_LOCATIONS = {
    23: {('6', '11', ''), ('6', '11', 'c'), ('6', '15', 'c')},
    25: {('6', '6', ''), ('6', '6', 'c'), ('6', '11', ''), ('6', '11', 'a'), ('6', '15', 'c')},
    75: {('7', '2', ''), ('7', '2', 'i'), ('12', '5', ''), ('12', '5', 'b')},
    56: {('15', '2', '')},
    118: {('57', '1', 'đ'), ('59', '1', 'b')},
    119: {('57', '1', 'a'), ('57', '1', 'd'), ('59', '1', 'b')},
    140: {('58', '2', '')},
    141: {('58', '3', '')},
}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('numbers', nargs='+', type=int)
    parser.add_argument('--output', type=Path,
                        default=ROOT / 'artifacts/local-ai/gateway-bank-eval.json')
    parser.add_argument('--pause', type=float, default=0,
                        help='Seconds between live provider calls')
    args = parser.parse_args()
    runtime = json.loads((ROOT / 'artifacts/local-ai/integration-runtime.json').read_text())
    questions = {row['number']: row for row in json.loads(
        (ROOT / 'content-bank/csgt-2025/source-extraction.json').read_text())['questions']}
    base = f"http://127.0.0.1:{runtime['gatewayPort']}/api"

    def post(path, payload, token=None):
        headers = {'Content-Type': 'application/json'}
        if token:
            headers['Authorization'] = 'Bearer ' + token
        request = Request(base + path, json.dumps(payload, ensure_ascii=False).encode(), headers)
        with urlopen(request, timeout=180) as response:
            return json.load(response)

    token = post('/auth/login', {'email': runtime['adminEmail'],
                                 'password': runtime['adminPassword']})['accessToken']
    report = []
    for number in args.numbers:
        question = questions[number]
        if question['images']:
            raise ValueError(f'Question {number} has images; use the visual evaluator')
        session = post('/chats', {'title': f'Evaluation question {number}'}, token)
        prompt = question['prompt'] + '\n' + '\n'.join(
            f"{option['id']}. {option['text']}" for option in question['options'])
        try:
            response = post(f"/chats/{session['id']}/messages",
                            {'requestId': str(uuid.uuid4()), 'prompt': prompt}, token)
        except HTTPError as error:
            item = {'number': number, 'expectedOptionIds': question['correctOptionIds'],
                    'status': 'HttpError', 'httpCode': error.code, 'correctWithEvidence': False}
            report.append(item)
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf8')
            print(f'{number}: HTTP {error.code}', flush=True)
            time.sleep(args.pause)
            continue
        answer = response.get('content', '')
        selected = re.match(r'^\s*(?:Phương\s+án|Đáp\s+án)?\s*(\d{1,2})\s*[.):\-]',
                            answer, re.IGNORECASE)
        citations = [{
            'article': c.get('articleNumber'), 'clause': c.get('clauseNumber'),
            'point': c.get('pointNumber'), 'chunkId': c.get('documentChunkId'),
            'url': c.get('sourceUrl'), 'excerpt': c.get('excerpt')
        } for c in response.get('citations', [])]
        item = {'number': number, 'expectedOptionIds': question['correctOptionIds'],
                'status': response.get('status'), 'selectedOptionId': int(selected.group(1)) if selected else None,
                'answer': answer, 'citations': citations, 'tokensUsed': response.get('tokensUsed')}
        locations = {(str(c['article'] or ''), str(c['clause'] or ''), str(c['point'] or ''))
                     for c in citations}
        item['requiredLocationsPresent'] = REQUIRED_LOCATIONS.get(number, set()) <= locations
        item['correctWithEvidence'] = (item['status'] == 'Answered' and
                                       item['selectedOptionId'] in item['expectedOptionIds'] and
                                       item['requiredLocationsPresent'] and
                                       all(c['chunkId'] and c['url'] for c in citations))
        report.append(item)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf8')
        print(f"{number}: {item['status']} option={item['selectedOptionId']} "
              f"expected={item['expectedOptionIds']} citations={len(citations)} "
              f"evidence={item['requiredLocationsPresent']} pass={item['correctWithEvidence']}", flush=True)
        time.sleep(args.pause)


if __name__ == '__main__':
    main()
