"""Check all 115 published CSGT scenario keys through the isolated Gateway chat."""
import importlib.util
import json
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('checks', ROOT / 'scripts/check-official-b-and-bookmarks.py')
checks = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checks)


def main():
    bank = json.loads((ROOT / 'content-bank/csgt-2025-B-current/package.json').read_text(encoding='utf8'))['bank']
    questions = [q for q in bank['questions'] if 486 <= q['number'] <= 600]
    if len(questions) != 115 or [q['number'] for q in questions] != list(range(486, 601)):
        raise ValueError('Published source package does not have the complete scenario set')
    _, token = checks.account()
    session = checks.api('/chats', token, {'title': 'Đánh giá 115 câu sa hình'}, expected=201)
    rows = []
    for question in questions:
        number = question['number']
        try:
            answer = checks.api('/chats/' + session['id'] + '/messages', token, {
                'requestId': str(uuid.uuid4()), 'prompt': f'Câu {number} trong bộ CSGT 2025 đáp án gì?',
                'attachmentIds': [], 'usePreviousAttachments': False})
            expected_options = [option for option in question['options']
                                if option['id'] in question['correctOptionIds']]
            result = {'number': number, 'status': answer['status'],
                      'sourcePresent': question['sourceUrl'] in answer['content'],
                      'answerKeyPresent': all(f"{option['id']}. {option['text']}" in answer['content']
                                              for option in expected_options),
                      'noLegalCitations': not answer['citations'], 'zeroProviderTokens': answer['tokensUsed'] == 0}
            result['passed'] = (result['status'] == 'PracticeAnswered' and result['sourcePresent']
                                and result['answerKeyPresent'] and result['noLegalCitations']
                                and result['zeroProviderTokens'])
        except Exception as error:
            result = {'number': number, 'passed': False, 'errorType': type(error).__name__,
                      'error': str(error)[:200]}
        rows.append(result)
        if number % 25 == 0:
            print(json.dumps({'checked': len(rows), 'passed': sum(row['passed'] for row in rows)}), flush=True)
    report = {'sourceBankId': bank['id'], 'scope': 'published-answer-key-integration',
              'checked': len(rows), 'passed': sum(row['passed'] for row in rows), 'results': rows}
    target = ROOT / 'artifacts/local-ai/scenario-chat-evaluation.json'
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf8')
    print(json.dumps({'checked': report['checked'], 'passed': report['passed'], 'artifact': str(target)}))
    if report['passed'] != 115:
        raise AssertionError('Scenario chat did not pass all 115 published source questions')


if __name__ == '__main__':
    main()
