"""Check provisioned Grafana/Prometheus/Loki/Tempo using real HTTP data.
Set GRAFANA_PASSWORD in the environment; it is never printed.
"""
import argparse
import base64
import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--grafana', default='http://127.0.0.1:3000')
    parser.add_argument('--gateway', default='http://127.0.0.1:8080')
    args = parser.parse_args()
    password = os.environ.get('GRAFANA_PASSWORD')
    if not password:
        raise SystemExit('GRAFANA_PASSWORD is not configured.')
    authorization = base64.b64encode(('admin:' + password).encode()).decode()

    def get(path):
        request = urllib.request.Request(args.grafana.rstrip('/') + path, headers={'Authorization': 'Basic ' + authorization})
        return json.load(urllib.request.urlopen(request, timeout=10))

    assert get('/api/health')['database'] == 'ok', 'Grafana database is unavailable'
    values = get('/api/datasources/proxy/uid/prometheus/api/v1/query?query=up')['data']['result']
    targets = {entry['metric']['job']: entry['value'][1] for entry in values}
    assert targets.get('rest-api') == targets.get('gateway') == '1', 'REST/Gateway scrape failed'
    assert any(d['uid'] == 'traffic-rag' for d in get('/api/search')), 'Dashboard was not provisioned'
    trace_id = uuid.uuid4().hex
    request = urllib.request.Request(args.gateway.rstrip('/') + '/api/chats',
        headers={'traceparent': f'00-{trace_id}-{uuid.uuid4().hex[:16]}-01'})
    try:
        urllib.request.urlopen(request, timeout=10)
    except urllib.error.HTTPError as error:
        assert error.code == 401
    services = set()
    for _ in range(20):
        try:
            trace = get('/api/datasources/proxy/uid/tempo/api/traces/' + trace_id)
            for batch in trace.get('batches', trace.get('resourceSpans', [])):
                for attribute in batch.get('resource', {}).get('attributes', []):
                    if attribute['key'] == 'service.name':
                        services.add(attribute['value']['stringValue'])
            if {'api-gateway', 'rest-api-service'} <= services:
                break
        except urllib.error.HTTPError:
            pass
        time.sleep(1)
    assert {'api-gateway', 'rest-api-service'} <= services, 'Cross-service trace was not found'
    query = urllib.parse.quote('{job="traffic-rag"}')
    logs = get('/api/datasources/proxy/uid/loki/loki/api/v1/query_range?query=' + query + '&limit=5')
    assert logs['data']['result'], 'Loki has no application file-log streams'
    print(json.dumps({'grafana': 'healthy', 'prometheus_targets': targets, 'trace_services': sorted(services),
                      'loki_streams': len(logs['data']['result']), 'worker_end_to_end': 'not checked'}, indent=2))


if __name__ == '__main__':
    main()
