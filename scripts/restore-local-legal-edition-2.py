"""Restore the exact local edition 2 after an incomplete edition 3 index.

Only rows and vectors introduced by the failed 50–55 import are removed.
The reviewed source package remains available for a later retry.
"""
import json
import subprocess
from pathlib import Path

from qdrant_client import QdrantClient
from qdrant_client import models

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / 'artifacts/local-ai'
DB = 'TrafficContent_WebLearning_57e824ae'
COLLECTION = 'traffic_law_learning_57e824ae_gemini768_v1'
DOCUMENT = '047c3bb3-8f5e-401f-b151-029b60d62dab'
TITLE = 'Luật Trật tự, an toàn giao thông đường bộ · VBHN 55/2026 · trích Điều 1–49'


def sql(query):
    return subprocess.run(['sqlcmd', '-S', '.\\MSSQLSERVER_VUON', '-E', '-d', DB,
        '-y', '0', '-w', '65535', '-b', '-Q', 'SET NOCOUNT ON; ' + query],
        capture_output=True, text=True, encoding='utf8', check=True).stdout.strip()


def main():
    runtime = json.loads((ROOT / 'artifacts/local-learning/runtime.json').read_text(encoding='utf-8-sig'))
    baseline = json.loads((WORK / 'extension-import-result.json').read_text(encoding='utf8'))
    if runtime['contentDatabase'] != DB or baseline['documentId'] != DOCUMENT or baseline['version'] != 2 or baseline['chunkCount'] != 536:
        raise ValueError('Unexpected local edition baseline')
    rows = json.loads(''.join(sql("SELECT d.Version,d.IsActive,d.VerificationStatus,d.SourceUrl,c.Id,c.Article,c.IsVerified "
        f"FROM LegalDocuments d JOIN LegalDocumentChunks c ON c.DocumentId=d.Id WHERE d.Id='{DOCUMENT}' "
        'FOR JSON PATH, INCLUDE_NULL_VALUES;').splitlines()))
    old = [r for r in rows if r['Article'].isdigit() and 1 <= int(r['Article']) <= 49]
    added = [r for r in rows if r['Article'].isdigit() and 50 <= int(r['Article']) <= 55]
    if len(rows) != 596 or len(old) != 536 or len(added) != 60 or \
            any(r['Version'] != 3 or r['IsActive'] or r['IsVerified'] or r['VerificationStatus'] != 'Pending' for r in rows):
        raise ValueError('The staged edition differs from the expected local recovery state')

    client = QdrantClient(host='127.0.0.1', port=16333, timeout=30)
    points, offset = {}, None
    while True:
        page, offset = client.scroll(COLLECTION, limit=256, offset=offset, with_payload=True, with_vectors=False)
        points.update({p.payload['chunk_id'].lower(): p.id for p in page})
        if offset is None:
            break
    old_ids = [points[r['Id'].lower()] for r in old]
    new_ids = [points[r['Id'].lower()] for r in added if r['Id'].lower() in points]
    if len(set(old_ids)) != 536 or len(new_ids) > 60 or set(points) - {r['Id'].lower() for r in rows}:
        raise ValueError('Unexpected Qdrant point set; refusing recovery')

    # Repair vectors first. SQL remains Pending if any Qdrant call fails.
    for start in range(0, len(old_ids), 64):
        result = client.set_payload(COLLECTION, payload={'document_version': '2', 'document_title': TITLE,
            'is_verified': True, 'is_active': True}, points=old_ids[start:start + 64], wait=True)
        if result.status != models.UpdateStatus.COMPLETED:
            raise RuntimeError('Qdrant did not acknowledge old-vector restoration')
    if new_ids:
        result = client.delete(COLLECTION, points_selector=new_ids, wait=True)
        if result.status != models.UpdateStatus.COMPLETED:
            raise RuntimeError('Qdrant did not acknowledge removal of new vectors')

    escaped_title = TITLE.replace("'", "''")
    edition_hash = baseline['contentHash']
    statement = f"""
SET XACT_ABORT ON;
BEGIN TRAN;
IF (SELECT COUNT(*) FROM LegalDocuments WHERE Id='{DOCUMENT}' AND Version=3 AND IsActive=0 AND VerificationStatus='Pending') <> 1
    THROW 50001, 'Edition state changed during recovery', 1;
IF (SELECT COUNT(*) FROM LegalDocumentChunks WHERE DocumentId='{DOCUMENT}' AND TRY_CONVERT(int,Article) BETWEEN 50 AND 55 AND IsVerified=0) <> 60
    THROW 50002, 'New chunk set changed during recovery', 1;
DELETE FROM LegalDocumentChunks WHERE DocumentId='{DOCUMENT}' AND TRY_CONVERT(int,Article) BETWEEN 50 AND 55 AND IsVerified=0;
UPDATE LegalDocumentChunks SET IsVerified=1 WHERE DocumentId='{DOCUMENT}' AND TRY_CONVERT(int,Article) BETWEEN 1 AND 49;
IF @@ROWCOUNT <> 536 THROW 50003, 'Original chunk set changed during recovery', 1;
UPDATE LegalDocuments SET Version=2, IsActive=1, VerificationStatus='Verified', Title=N'{escaped_title}',
    ContentHash='{edition_hash}' WHERE Id='{DOCUMENT}';
COMMIT TRAN;
"""
    sql(statement)
    print(json.dumps({'restoredVersion': 2, 'activeChunks': 536, 'removedPendingChunks': 60,
                      'removedPartialVectors': len(new_ids)}))


if __name__ == '__main__':
    main()
