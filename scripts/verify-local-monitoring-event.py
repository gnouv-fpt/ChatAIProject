"""Exercise a real local exam event, broker backlog and EventId replay without fake messages."""
import importlib.util
import json
import re
import subprocess
import time
from pathlib import Path
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('learning', ROOT / 'scripts/check-local-learning.py')
learning = importlib.util.module_from_spec(spec)
spec.loader.exec_module(learning)
TOPIC = 'local-learning-exam-submitted-v1'
GROUP = 'local-learning-notifications-v1'


def worker(stop=False):
    args = ['pwsh', '-File', str(ROOT / 'scripts/start-local-monitoring-worker.ps1')]
    if stop:
        args.append('-Stop')
    subprocess.run(args, cwd=ROOT, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def metrics():
    return urlopen('http://127.0.0.1:15042/metrics', timeout=5).read().decode()


def count(name):
    values = re.findall(r'^' + name + r'\{[^}]*\} (\d+(?:\.\d+)?)$', metrics(), re.M)
    return sum(float(v) for v in values)


def lag():
    result = subprocess.run(['docker', 'exec', 'traffic-rag-kafka-exporter-1', 'wget', '-qO-',
                             'http://localhost:9308/metrics'], capture_output=True, text=True, check=True)
    values = []
    for line in result.stdout.splitlines():
        if line.startswith('kafka_consumergroup_lag{') and f'consumergroup="{GROUP}"' in line and f'topic="{TOPIC}"' in line:
            values.append(float(line.rsplit(' ', 1)[1]))
    if not values:
        raise RuntimeError('Kafka exporter does not expose the local consumer group')
    return sum(values)


def event_payload(event_id):
    result = subprocess.run(['docker', 'exec', 'prn-c2-localtest-kafka-1',
        '/opt/kafka/bin/kafka-console-consumer.sh', '--bootstrap-server', 'localhost:9092',
        '--topic', TOPIC, '--from-beginning', '--timeout-ms', '5000'],
        capture_output=True, text=True, timeout=15)
    for line in result.stdout.splitlines():
        try:
            payload = json.loads(line)
        except json.JSONDecodeError:
            continue
        if payload.get('EventId', '').lower() == event_id.lower():
            return line
    raise RuntimeError('Submitted event was not found on the real Kafka topic')


def wait_for(predicate, seconds=60):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        value = predicate()
        if value:
            return value
        time.sleep(1)
    raise AssertionError('Expected local monitoring state did not appear')


def main():
    worker(stop=True)
    restarted = False
    try:
        _, token = learning.account('monitor')
        bank = learning.package['bank']
        exam = learning.api('/custom-exams', token, {'categoryId': bank['id'],
            'bankVersion': str(bank['version']), 'questionCount': 1, 'durationMinutes': 5}, expected=201)
        score = learning.api('/custom-exams/' + exam['examId'] + '/submit', token, method='POST')
        attempt_id = score['attemptId']
        payload = event_payload(attempt_id)
        backlog = wait_for(lambda: lag() or None)
        worker()
        restarted = True
        wait_for(lambda: count('exam_event_processed_total') >= 1)
        wait_for(lambda: lag() == 0)
        notifications = learning.api('/exam-notifications', token)
        assert any(item['eventId'].lower() == attempt_id.lower() for item in notifications)
        replay = subprocess.run(['docker', 'exec', '-i', 'prn-c2-localtest-kafka-1',
            '/opt/kafka/bin/kafka-console-producer.sh', '--bootstrap-server', 'localhost:9092',
            '--topic', TOPIC], input=payload + '\n', capture_output=True, text=True, check=True, timeout=15)
        assert replay.returncode == 0
        wait_for(lambda: count('exam_event_duplicate_total') >= 1)
        review = learning.api('/exam-attempts/' + attempt_id + '/review', token)
        assert review['attemptId'].lower() == attempt_id.lower()
        result = {'realSubmittedEvent': True, 'backlogWhileWorkerStopped': backlog,
                  'backlogAfterRestart': lag(), 'uniqueProcessed': count('exam_event_processed_total'),
                  'duplicateReplay': count('exam_event_duplicate_total'),
                  'durableAttemptRetained': True}
        (ROOT / 'artifacts/local-monitoring/event-check.json').write_text(json.dumps(result, indent=2), encoding='utf8')
        print(json.dumps(result))
    finally:
        if not restarted:
            worker()


if __name__ == '__main__':
    main()
