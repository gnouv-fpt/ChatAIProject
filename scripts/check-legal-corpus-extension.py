"""Compare every SQL legal chunk with the local Qdrant collection after extension."""
import hashlib
import json
import re
import subprocess
from pathlib import Path
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / 'artifacts/local-ai'


def main():
    runtime = json.loads((ROOT / 'artifacts/local-learning/runtime.json').read_text(encoding='utf-8-sig'))
    database = runtime['contentDatabase']
    if not re.fullmatch(r'TrafficContent_WebLearning_[a-f0-9]{8}', database) or \
            runtime['userDatabase'] != database.replace('TrafficContent_', 'TrafficUser_', 1):
        raise ValueError('Unexpected isolated local databases')
    collection = 'traffic_law_learning_' + database.rsplit('_', 1)[1] + '_gemini768_v1'
    query = ("SET NOCOUNT ON; SELECT d.Id AS DocumentId,d.DocumentNumber,d.Title,d.Version,d.IsActive,"
             "d.VerificationStatus,d.ContentHash,d.SourceUrl,c.Id AS ChunkId,c.Article,c.Clause,c.Point,"
             "c.Content,c.IsVerified,c.VectorId FROM LegalDocuments d JOIN LegalDocumentChunks c ON c.DocumentId=d.Id "
             "WHERE d.DocumentNumber='55/VBHN-VPQH' FOR JSON PATH, INCLUDE_NULL_VALUES;")
    if runtime.get('sqlMode') == 'docker':
        sqlcmd_args = ['docker', 'exec', 'prn-c2-localtest-sqlserver-1', '/opt/mssql-tools18/bin/sqlcmd',
                       '-S', 'localhost', '-U', 'sa', '-P', runtime['sqlPassword'], '-C',
                       '-d', database, '-y', '0', '-w', '65535', '-b', '-Q', query]
    else:
        sqlcmd_args = ['sqlcmd', '-S', '.\\MSSQLSERVER_VUON', '-E', '-d', database, '-y', '0', '-w', '65535',
                       '-b', '-Q', query]
    process = subprocess.run(sqlcmd_args, capture_output=True, text=True, encoding='utf8')
    if process.returncode:
        raise RuntimeError(f'Content SQL verification unavailable (exit {process.returncode})')
    rows = json.loads(''.join(process.stdout.splitlines()).strip())
    version = rows[0]['Version']
    expected = {2: (49, 536), 3: (55, 596), 4: (89, 975)}
    assert version in expected, f'Unexpected corpus version {version}'
    last_article, count = expected[version]
    staging = version == 3 and len(rows) > 596
    if staging:
        old_rows = [r for r in rows if int(r['Article']) <= 55]
        new_rows = [r for r in rows if int(r['Article']) >= 56]
        assert len(old_rows) == 596 and len(new_rows) > 0
        assert {r['Article'] for r in new_rows} == {str(n) for n in range(56, 90)}
        assert all(not r['IsVerified'] for r in new_rows)
        checked_rows = old_rows
    else:
        assert len(rows) == count
        checked_rows = rows
    assert {r['Article'] for r in checked_rows} == {str(n) for n in range(1, last_article + 1)}
    document_id = rows[0]['DocumentId'].lower()
    assert all(r['DocumentId'].lower() == document_id and
               r['Version'] == version and r['IsActive'] and r['IsVerified'] and
               r['VerificationStatus'] == 'Verified' for r in checked_rows)
    sql = {r['ChunkId'].lower(): r for r in rows}
    assert len(sql) == len(rows)
    points, offset = {}, None
    while True:
        body = {'limit': 256, 'with_payload': True, 'with_vector': False}
        if offset is not None:
            body['offset'] = offset
        request = Request(f'http://127.0.0.1:16333/collections/{collection}/points/scroll',
                          data=json.dumps(body).encode(), headers={'Content-Type': 'application/json'})
        with urlopen(request, timeout=30) as response:
            page = json.load(response)['result']
        for point in page['points']:
            payload = point['payload']
            chunk_id = payload['chunk_id'].lower()
            assert chunk_id not in points
            points[chunk_id] = (point['id'], payload)
        offset = page.get('next_page_offset')
        if offset is None:
            break
    if staging:
        assert set(points).issubset(sql)
        assert all(not points[r['ChunkId'].lower()][1]['is_active'] for r in new_rows if r['ChunkId'].lower() in points)
        assert all(r['ChunkId'].lower() in sql for r in old_rows)
        verify_rows = old_rows
    else:
        assert set(points) == set(sql), f'Qdrant/SQL ID difference: {len(points)} / {len(sql)}'
        verify_rows = rows
    for row in verify_rows:
        chunk_id = row['ChunkId'].lower()
        point_id, payload = points[chunk_id]
        expected_point_id = str(int(hashlib.sha256(chunk_id.encode()).hexdigest()[:16], 16) % (2**63))
        assert str(point_id) == row['VectorId'] == expected_point_id
        assert payload['document_id'].lower() == row['DocumentId'].lower()
        assert payload['document_version'] == str(version)
        assert payload['document_number'] == row['DocumentNumber']
        assert payload['document_title'] == row['Title']
        assert payload['source_url'] == row['SourceUrl']
        assert payload['content'] == row['Content']
        assert payload['content_hash'] == hashlib.sha256(row['Content'].encode()).hexdigest()
        assert payload['article'] == row['Article']
        assert payload['clause'] == (row['Clause'] or '') and payload['point'] == (row['Point'] or '')
        assert payload['is_verified'] and payload['is_active']
    result = {'documentId': rows[0]['DocumentId'].lower(), 'version': version, 'articles': last_article,
              'sqlChunks': len(sql), 'qdrantPoints': len(points), 'allPayloadsMatch': not staging,
              'staging': staging, 'oldActiveChunks': len(verify_rows),
              'contentHash': rows[0]['ContentHash']}
    (WORK / 'extension-check.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf8')
    print(json.dumps(result, ensure_ascii=False))


if __name__ == '__main__':
    main()
