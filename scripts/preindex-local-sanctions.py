"""Stage inactive sanction vectors in resumable batches before local activation."""
import hashlib
import importlib.util
import json
import sys
from pathlib import Path

import grpc

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'grpc_inference_service'))
import chat_inference_pb2 as pb  # noqa: E402
import chat_inference_pb2_grpc as rpc  # noqa: E402


def main():
    spec = importlib.util.spec_from_file_location('staging', ROOT / 'scripts/check-local-sanction-staging.py')
    staging = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(staging)
    staging.main()  # Full SQL/source parity before any vectors are written.
    rows = staging.load_rows()
    document_ids = {row['DocumentId'] for row in rows}
    if len(document_ids) != 1 or any(row['IsActive'] or row['IsVerified'] for row in rows):
        raise ValueError('Expected one inactive, unverified SQL sanction document')
    rows.sort(key=lambda row: (int(row['Article']), row['Clause'] or '', row['Point'] or '', row['ChunkId']))
    channel = grpc.insecure_channel('127.0.0.1:15051')
    client = rpc.TrafficRagInferenceStub(channel)
    for offset in range(0, len(rows), 32):
        items = []
        for row in rows[offset:offset + 32]:
            items.append(pb.DocumentChunkItem(
                chunk_id=row['ChunkId'].lower(), document_id=row['DocumentId'].lower(),
                document_version=str(row['Version']), document_title=row['Title'],
                document_number=row['DocumentNumber'], chapter='', article=row['Article'] or '',
                clause=row['Clause'] or '', point=row['Point'] or '', content=row['Content'],
                content_hash=hashlib.sha256(row['Content'].encode()).hexdigest(),
                source_url=row['SourceUrl'], is_verified=False, is_active=False))
        response = client.IndexDocument(pb.IndexDocumentRequest(chunks=items), timeout=600)
        if not response.success or response.indexed_count != len(items):
            raise RuntimeError(f'Incomplete inactive vector batch at offset {offset}')
        print(json.dumps({'staged': min(offset + len(items), len(rows)),
                          'total': len(rows), 'active': False}), flush=True)


if __name__ == '__main__':
    main()
