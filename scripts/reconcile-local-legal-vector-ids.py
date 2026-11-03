"""One-time data correction for the recorded edition-2 local database only.

Verifies every SQL chunk and Qdrant point before changing SQL VectorId. No schema change.
"""
import hashlib
import json
import subprocess
from pathlib import Path
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
DB = 'TrafficContent_WebLearning_57e824ae'
COLLECTION = 'traffic_law_learning_57e824ae_gemini768_v1'


def main():
    runtime = json.loads((ROOT / 'artifacts/local-learning/runtime.json').read_text(encoding='utf-8-sig'))
    if runtime['contentDatabase'] != DB:
        raise ValueError('Unexpected local database')
    query = ("SET NOCOUNT ON; SELECT d.Id AS DocumentId,d.Version,d.IsActive,d.VerificationStatus,"
             "c.Id AS ChunkId,c.VectorId,c.Content,c.Article,c.Clause,c.Point,c.IsVerified,d.SourceUrl "
             "FROM LegalDocuments d JOIN LegalDocumentChunks c ON c.DocumentId=d.Id "
             "WHERE d.DocumentNumber='55/VBHN-VPQH' FOR JSON PATH, INCLUDE_NULL_VALUES;")
    cmd = ['sqlcmd', '-S', '.\\MSSQLSERVER_VUON', '-E', '-d', DB, '-y', '0', '-w', '65535', '-b']
    result = subprocess.run(cmd + ['-Q', query], capture_output=True, text=True, encoding='utf8', check=True)
    rows = json.loads(''.join(result.stdout.splitlines()).strip())
    if len(rows) != 536 or {r['Article'] for r in rows} != {str(n) for n in range(1, 50)}:
        raise ValueError('Not the recorded edition-2 corpus')
    sql = {r['ChunkId'].lower(): r for r in rows}
    points, offset = {}, None
    while True:
        body = {'limit': 256, 'with_payload': True, 'with_vector': False}
        if offset is not None:
            body['offset'] = offset
        request = Request(f'http://127.0.0.1:16333/collections/{COLLECTION}/points/scroll',
                          data=json.dumps(body).encode(), headers={'Content-Type': 'application/json'})
        with urlopen(request, timeout=30) as response:
            page = json.load(response)['result']
        for point in page['points']:
            chunk_id = point['payload']['chunk_id'].lower()
            if chunk_id in points:
                raise ValueError('Duplicate Qdrant chunk ID')
            points[chunk_id] = point
        offset = page.get('next_page_offset')
        if offset is None:
            break
    if set(points) != set(sql):
        raise ValueError('SQL and Qdrant chunk IDs differ')
    updates = []
    for chunk_id, row in sql.items():
        point = points[chunk_id]
        payload = point['payload']
        expected = int(hashlib.sha256(chunk_id.encode()).hexdigest()[:16], 16) % (2**63)
        if (point['id'] != expected or row['DocumentId'].lower() != '047c3bb3-8f5e-401f-b151-029b60d62dab'
                or row['Version'] != 2 or not row['IsActive'] or row['VerificationStatus'] != 'Verified'
                or not row['IsVerified'] or payload['document_id'].lower() != row['DocumentId'].lower()
                or payload['content'] != row['Content'] or payload['article'] != row['Article']
                or payload['clause'] != (row['Clause'] or '') or payload['point'] != (row['Point'] or '')
                or payload['source_url'] != row['SourceUrl'] or payload['document_version'] != '2'
                or payload['content_hash'] != hashlib.sha256(row['Content'].encode()).hexdigest()
                or not payload['is_verified'] or not payload['is_active']):
            raise ValueError('Qdrant/SQL point mismatch; no SQL writes made')
        if row['VectorId'] == str(expected):
            continue
        if row['VectorId'].lower() != chunk_id:
            raise ValueError('Unexpected existing VectorId; no SQL writes made')
        updates.append((chunk_id, str(expected)))
    if not updates:
        print(json.dumps({'checked': len(rows), 'updated': 0}))
        return
    lines = ['SET XACT_ABORT ON;', 'BEGIN TRAN;']
    for chunk_id, point_id in updates:
        lines.append(f"UPDATE LegalDocumentChunks SET VectorId='{point_id}' WHERE Id='{chunk_id}' AND VectorId='{chunk_id}';")
        lines.append("IF @@ROWCOUNT <> 1 THROW 51000, 'VectorId changed during correction', 1;")
    lines.append('COMMIT;')
    sql_file = ROOT / 'artifacts/local-ai/vector-id-correction.sql'
    sql_file.write_text('\n'.join(lines) + '\n', encoding='ascii')
    subprocess.run(cmd + ['-i', str(sql_file)], check=True, capture_output=True, text=True, encoding='utf8')
    print(json.dumps({'checked': len(rows), 'updated': len(updates)}))


if __name__ == '__main__':
    main()
