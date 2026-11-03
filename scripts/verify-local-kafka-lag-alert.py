"""Prove KafkaConsumerLag fires and recovers using replays of one real API event."""
import importlib.util
import json
import subprocess
import time
from pathlib import Path
from urllib.parse import quote

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('event_check', ROOT / 'scripts/verify-local-monitoring-event.py')
event_check = importlib.util.module_from_spec(spec)
spec.loader.exec_module(event_check)


def alert_firing():
    query = quote('ALERTS{alertname="KafkaConsumerLag",alertstate="firing"}')
    output = subprocess.run(['docker', 'exec', 'traffic-rag-prometheus-1', 'wget', '-qO-',
                             f'http://localhost:9090/api/v1/query?query={query}'],
                            capture_output=True, text=True, check=True, timeout=10)
    data = json.loads(output.stdout)
    return any(row['value'][1] == '1' for row in data['data']['result'])


def main():
    event_check.worker(stop=True)
    try:
        _, token = event_check.learning.account('lagalert')
        bank = event_check.learning.package['bank']
        exam = event_check.learning.api('/custom-exams', token, {'categoryId': bank['id'],
            'bankVersion': str(bank['version']), 'questionCount': 1, 'durationMinutes': 5}, expected=201)
        score = event_check.learning.api('/custom-exams/' + exam['examId'] + '/submit', token, method='POST')
        attempt_id = score['attemptId']
        payload = event_check.event_payload(attempt_id)
        # The first message comes from the API. Replays only increase broker lag;
        # EventId deduplication keeps the business side effect at one.
        replay = subprocess.run(['docker', 'exec', '-i', 'prn-c2-localtest-kafka-1',
            '/opt/kafka/bin/kafka-console-producer.sh', '--bootstrap-server', 'localhost:9092',
            '--topic', event_check.TOPIC], input=(payload + '\n') * 11,
            capture_output=True, text=True, check=True, timeout=30)
        assert replay.returncode == 0
        backlog = event_check.wait_for(lambda: event_check.lag() if event_check.lag() > 10 else None)
        firing = event_check.wait_for(alert_firing, seconds=420)
        assert firing
    finally:
        event_check.worker()
    event_check.wait_for(lambda: event_check.lag() == 0, seconds=90)
    # One minute rule evaluation can observe the pre-restart scrape; allow
    # the following evaluation to clear the alert after broker lag reaches 0.
    event_check.wait_for(lambda: not alert_firing(), seconds=150)
    review = event_check.learning.api('/exam-attempts/' + attempt_id + '/review', token)
    assert review['attemptId'].lower() == attempt_id.lower()
    result = {'apiEvent': True, 'replays': 11, 'backlog': backlog,
              'lagAlertFired': True, 'lagAfterRestart': event_check.lag(),
              'lagAlertResolved': True, 'attemptRetained': True}
    (ROOT / 'artifacts/local-monitoring/lag-alert-check.json').write_text(
        json.dumps(result, indent=2), encoding='utf8')
    print(json.dumps(result))


if __name__ == '__main__':
    main()
