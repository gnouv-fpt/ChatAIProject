"""Replay one real submitted event while local Redis is unavailable; restore Redis in all cases."""
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
REDIS = 'prn-c2-localtest-redis-1'
DLQ = 'local-learning-exam-submitted-dlq-v1'


def alert_firing():
    query = quote('ALERTS{alertname="KafkaProcessingFailures",alertstate="firing"}')
    output = subprocess.run(['docker', 'exec', 'traffic-rag-prometheus-1', 'wget', '-qO-',
                             f'http://localhost:9090/api/v1/query?query={query}'],
                            capture_output=True, text=True, check=True, timeout=10)
    return any(row['value'][1] == '1' for row in json.loads(output.stdout)['data']['result'])


def dlq_contains(event_id):
    output = subprocess.run(['docker', 'exec', 'prn-c2-localtest-kafka-1',
        '/opt/kafka/bin/kafka-console-consumer.sh', '--bootstrap-server', 'localhost:9092',
        '--topic', DLQ, '--from-beginning', '--timeout-ms', '5000'],
        capture_output=True, text=True, timeout=15)
    return any(json.loads(line).get('EventId', '').lower() == event_id.lower()
               for line in output.stdout.splitlines() if line.startswith('{'))


def main():
    state = subprocess.run(['docker', 'inspect', REDIS, '--format', '{{.State.Running}}'],
                           capture_output=True, text=True, check=True)
    if state.stdout.strip() != 'true':
        raise RuntimeError('Local Redis must be running before controlled failure test')
    before_processed = event_check.count('exam_event_processed_total')
    before_retry = event_check.count('exam_event_retry_total')
    before_failed = event_check.count('exam_event_failed_total')
    _, token = event_check.learning.account('dlqalert')
    bank = event_check.learning.package['bank']
    exam = event_check.learning.api('/custom-exams', token, {'categoryId': bank['id'],
        'bankVersion': str(bank['version']), 'questionCount': 1, 'durationMinutes': 5}, expected=201)
    score = event_check.learning.api('/custom-exams/' + exam['examId'] + '/submit', token, method='POST')
    attempt_id = score['attemptId']
    payload = event_check.event_payload(attempt_id)
    event_check.wait_for(lambda: event_check.count('exam_event_processed_total') > before_processed)
    stopped = False
    try:
        subprocess.run(['docker', 'stop', '--time', '10', REDIS], check=True, capture_output=True, text=True)
        stopped = True
        subprocess.run(['docker', 'exec', '-i', 'prn-c2-localtest-kafka-1',
            '/opt/kafka/bin/kafka-console-producer.sh', '--bootstrap-server', 'localhost:9092',
            '--topic', event_check.TOPIC], input=payload + '\n', capture_output=True, text=True, check=True, timeout=15)
        event_check.wait_for(lambda: event_check.count('exam_event_failed_total') > before_failed, seconds=120)
        event_check.wait_for(lambda: dlq_contains(attempt_id), seconds=30)
    finally:
        if stopped:
            subprocess.run(['docker', 'start', REDIS], check=True, capture_output=True, text=True)
    event_check.wait_for(lambda: any(item['eventId'].lower() == attempt_id.lower()
                                     for item in event_check.learning.api('/exam-notifications', token)), seconds=60)
    event_check.wait_for(alert_firing, seconds=420)
    review = event_check.learning.api('/exam-attempts/' + attempt_id + '/review', token)
    assert review['attemptId'].lower() == attempt_id.lower()
    result = {'realSubmittedEventReplayed': True, 'eventId': attempt_id,
              'retryIncrease': event_check.count('exam_event_retry_total') - before_retry,
              'dlqIncrease': event_check.count('exam_event_failed_total') - before_failed,
              'dlqContainsEvent': dlq_contains(attempt_id), 'redisRestarted': True,
              'alertFiring': alert_firing(), 'durableAttemptAfterRedisRestart': True}
    (ROOT / 'artifacts/local-monitoring/dlq-alert-check.json').write_text(
        json.dumps(result, indent=2), encoding='utf8')
    print(json.dumps(result))


if __name__ == '__main__':
    main()
