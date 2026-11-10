"""Ask representative sanction questions through the real isolated Gateway."""
import argparse
import importlib.util
import json
import uuid
from pathlib import Path
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('checks', ROOT / 'scripts/check-official-b-and-bookmarks.py')
checks = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checks)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--case', action='append', help='Run only the named case; repeatable')
    args = parser.parse_args()
    _, token = checks.account()
    cases = {
        'motorcycle_red_light': 'Vượt đèn đỏ xe máy bị xử phạt thế nào?',
        'car_red_light': 'Ô tô vượt đèn đỏ năm 2026 bị phạt tiền và trừ điểm thế nào?',
        'motorcycle_helmet': 'Người điều khiển xe máy không đội mũ bảo hiểm bị phạt bao nhiêu?',
        'motorcycle_speed': 'Xe máy chạy quá tốc độ quy định từ 10 đến 20 km/h bị phạt bao nhiêu?',
        'car_speed': 'Ô tô chạy quá tốc độ quy định trên 35 km/h bị xử phạt thế nào?',
        'motorcycle_low_alcohol': 'Xe máy có nồng độ cồn trong hơi thở nhưng chưa vượt quá 0,25 miligam/lít bị xử phạt thế nào?',
        'bicycle_red_light': 'Xe đạp vượt đèn đỏ bị phạt bao nhiêu?',
        'hazardous_cargo_marking': 'Vận chuyển hàng nguy hiểm xong mà không bóc biểu trưng nguy hiểm trên xe bị phạt bao nhiêu?',
        'delayed_camera': 'Năm 2026, xe ô tô kinh doanh vận tải hàng hóa không lắp thiết bị ghi nhận hình ảnh người lái xe bị phạt bao nhiêu?',
        'unspecified_vehicle': 'Vượt đèn đỏ bị phạt bao nhiêu?',
    }
    expected_points = {
        'motorcycle_red_light': ('7', '7', 'c'),
        'car_red_light': ('6', '9', 'b'),
        'motorcycle_helmet': ('7', '2', 'h'),
        'motorcycle_speed': ('7', '4', 'a'),
        'car_speed': ('6', '7', 'a'),
        'motorcycle_low_alcohol': ('7', '6', 'a'),
        'bicycle_red_light': ('9', '2', 'đ'),
        'hazardous_cargo_marking': ('23', '1', ''),
    }
    if args.case:
        unknown = set(args.case) - set(cases)
        if unknown:
            parser.error('Unknown case: ' + ', '.join(sorted(unknown)))
        cases = {name: prompt for name, prompt in cases.items() if name in args.case}
    results = {}
    failures = []
    for name, prompt in cases.items():
        try:
            session = checks.api('/chats', token, {'title': 'Đối chiếu mức phạt ' + name}, expected=201)
            body = {'requestId': str(uuid.uuid4()), 'prompt': prompt,
                    'attachmentIds': [], 'usePreviousAttachments': False}
            request = Request(checks.runtime['gateway'] + '/api/chats/' + session['id'] + '/messages',
                              data=json.dumps(body, ensure_ascii=False).encode('utf8'),
                              headers={'Content-Type': 'application/json', 'Authorization': 'Bearer ' + token})
            with urlopen(request, timeout=120) as response:
                answer = json.load(response)
        except Exception as error:
            results[name] = {'status': 'Error', 'errorType': type(error).__name__,
                             'error': str(error)[:160]}
            failures.append(f'{name}: {type(error).__name__}')
            print(json.dumps({'case': name, **results[name]}, ensure_ascii=True), flush=True)
            continue
        citations = answer.get('citations') or []
        if answer['status'] == 'Answered' and not citations:
            failures.append(f'{name}: answered without citation')
        cited_points = {(c['articleNumber'], c['clauseNumber'], c.get('pointNumber') or '')
                        for c in citations}
        if name in expected_points:
            if answer['status'] != 'Answered':
                failures.append(f'{name}: {answer["status"]}, expected Answered')
            elif expected_points[name] not in cited_points:
                failures.append(f'{name}: missing expected sanction point')
        if name == 'delayed_camera' and (answer['status'] != 'Answered' or
                                          not any(a == '53' and c == '3' for a, c, _ in cited_points) or
                                          '2028' not in (answer.get('content') or answer.get('responseText') or '')):
            failures.append('delayed_camera: missing Article 53 clause 3 or 2028 effective date')
        results[name] = {'status': answer['status'], 'answer': answer.get('content') or answer.get('responseText'),
                         'citations': [{'article': c['articleNumber'], 'clause': c['clauseNumber'],
                                        'point': c.get('pointNumber')} for c in citations]}
        print(json.dumps({'case': name, 'status': results[name]['status'],
                          'answer': (results[name]['answer'] or '')[:500],
                          'citations': results[name]['citations']}, ensure_ascii=True), flush=True)
    suffix = '-' + '-'.join(args.case) if args.case else ''
    target = ROOT / f'artifacts/local-ai/sanction-chat-probe{suffix}.json'
    target.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding='utf8')
    if failures:
        raise AssertionError('; '.join(failures))


if __name__ == '__main__':
    main()
