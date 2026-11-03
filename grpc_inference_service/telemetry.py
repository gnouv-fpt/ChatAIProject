"""Metadata-only local telemetry; request bodies and exception text stay out of file logs."""
import json
import logging
import os
from datetime import datetime, timedelta, timezone
from pathlib import Path
from time import perf_counter

import grpc
from prometheus_client import Counter, Histogram, start_http_server
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.grpc import GrpcInstrumentorServer
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor


REQUESTS = Counter('grpc_requests_total', 'Completed inference RPCs', ['method', 'status'])
DURATION = Histogram('grpc_request_duration_seconds', 'Inference RPC duration', ['method'])


class SafeJsonFileHandler(logging.Handler):
    def __init__(self, path, max_bytes=10 * 1024 * 1024, retention_days=7):
        super().__init__()
        self.path = Path(path)
        self.max_bytes = max_bytes
        self.retention_days = retention_days
        self.cleaned_day = None

    def emit(self, record):
        try:
            now = datetime.now(timezone.utc)
            span = trace.get_current_span().get_span_context()
            payload = {
                'timestamp': now.isoformat(), 'service': 'grpc-inference',
                'level': record.levelname, 'operation': record.funcName,
                'status': 'error' if record.levelno >= logging.ERROR else 'ok',
                'exceptionType': record.exc_info[0].__name__ if record.exc_info else None,
                'traceId': format(span.trace_id, '032x') if span.is_valid else None,
            }
            line = json.dumps(payload, ensure_ascii=False) + '\n'
            self.path.parent.mkdir(parents=True, exist_ok=True)
            day = now.strftime('%Y%m%d')
            if self.cleaned_day != day:
                self.cleaned_day = day
                for old in self.path.parent.glob(self.path.stem + '-*.jsonl'):
                    if datetime.fromtimestamp(old.stat().st_mtime, timezone.utc) < now - timedelta(days=self.retention_days):
                        old.unlink()
            current = self.path.with_name(f'{self.path.stem}-{day}.jsonl')
            if current.exists() and current.stat().st_size + len(line.encode()) > self.max_bytes:
                slot = 1
                while self.path.with_name(f'{self.path.stem}-{day}-{slot}.jsonl').exists():
                    slot += 1
                if slot > 10:
                    return
                current.rename(self.path.with_name(f'{self.path.stem}-{day}-{slot}.jsonl'))
            with current.open('a', encoding='utf8') as stream:
                stream.write(line)
        except (OSError, ValueError):
            self.handleError(record)


class RpcMetrics(grpc.ServerInterceptor):
    def intercept_service(self, continuation, details):
        handler = continuation(details)
        if handler is None or handler.unary_unary is None:
            return handler
        method = details.method.rsplit('/', 1)[-1]

        def instrumented(request, context):
            started = perf_counter()
            status = 'OK'
            try:
                return handler.unary_unary(request, context)
            except grpc.RpcError:
                status = context.code().name if context.code() else 'UNKNOWN'
                raise
            except Exception:
                status = 'UNKNOWN'
                raise
            finally:
                REQUESTS.labels(method, status).inc()
                DURATION.labels(method).observe(perf_counter() - started)

        return grpc.unary_unary_rpc_method_handler(
            instrumented, handler.request_deserializer, handler.response_serializer)


def configure():
    logging.getLogger().addHandler(SafeJsonFileHandler(os.getenv('LOG_FILE_PATH', 'logs/grpc.jsonl')))
    start_http_server(int(os.getenv('METRICS_PORT', '8000')))
    endpoint = os.getenv('OTEL_EXPORTER_OTLP_ENDPOINT')
    if endpoint:
        provider = TracerProvider(resource=Resource.create({'service.name': 'grpc-inference'}))
        provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter(endpoint=endpoint, insecure=endpoint.startswith('http://'))))
        trace.set_tracer_provider(provider)
        GrpcInstrumentorServer().instrument()
