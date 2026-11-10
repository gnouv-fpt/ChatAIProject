"""Check the isolated SQL sanction import against every reviewed source line."""
import hashlib
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def line_hash(content):
    lines = sorted(line.strip() for line in content.splitlines() if line.strip())
    return hashlib.sha256('\n'.join(lines).encode('utf8')).hexdigest()


def load_rows():
    runtime = json.loads((ROOT / 'artifacts/local-learning/runtime.json').read_text(encoding='utf-8-sig'))
    database = runtime['contentDatabase']
    if runtime.get('sqlMode') != 'docker' or \
            not re.fullmatch(r'TrafficContent_WebLearning_[a-f0-9]{8}', database) or \
            runtime['userDatabase'] != database.replace('TrafficContent_', 'TrafficUser_', 1):
        raise ValueError('Unexpected isolated database')
    query = ("SET NOCOUNT ON; SELECT d.Id AS DocumentId,d.DocumentNumber,d.Title,d.Version,d.SourceUrl,"
             "d.IsActive,d.VerificationStatus,"
             "c.Id AS ChunkId,c.Article,c.Clause,c.Point,c.Content,c.IsVerified,c.VectorId "
             "FROM LegalDocuments d JOIN LegalDocumentChunks c ON c.DocumentId=d.Id "
             "WHERE d.DocumentNumber=N'168/2024/NĐ-CP' FOR JSON PATH, INCLUDE_NULL_VALUES;")
    args = ['docker', 'exec', 'prn-c2-localtest-sqlserver-1', '/opt/mssql-tools18/bin/sqlcmd',
            '-S', 'localhost', '-U', 'sa', '-P', runtime['sqlPassword'], '-C',
            '-d', database, '-y', '0', '-w', '65535', '-b', '-Q', query]
    result = subprocess.run(args, capture_output=True, text=True, encoding='utf8')
    if result.returncode:
        raise RuntimeError(f'Isolated Content SQL query unavailable (exit {result.returncode}); check Docker SQL')
    return json.loads(''.join(result.stdout.splitlines()).strip())


def main():
    package = json.loads((ROOT / 'content-bank/legal/168-238-all-articles-merged-review.json').read_text(encoding='utf8'))
    expected = '\n'.join(article['content'] for article in package['articles'])
    rows = load_rows()
    if not rows or len({r['DocumentId'] for r in rows}) != 1 or \
            len({r['ChunkId'] for r in rows}) != len(rows) or \
            {r['Article'] for r in rows} != {str(n) for n in range(1, 56)} or \
            any(r['IsActive'] or r['IsVerified'] or r['VectorId'] is not None for r in rows) or \
            line_hash('\n'.join(r['Content'] for r in rows)) != line_hash(expected):
        raise ValueError('Staged SQL chunks differ from the reviewed 55-article source')
    locations = {(r['Article'], r['Clause'], r['Point']) for r in rows}
    for article in range(1, 56):
        if (str(article), None, None) not in locations:
            raise ValueError(f'Missing article title: {article}')
    for row in rows:
        if row['Point'] and (row['Article'], row['Clause'], None) not in locations:
            raise ValueError(f'Missing clause header: {row["Article"]}/{row["Clause"]}')
    for location in (('29', '3a', None), ('32', '9a', 'b'), ('41', '4', 'k1'),
                     ('53', '3', None), ('53', '4', None)):
        if location not in locations:
            raise ValueError(f'Missing amended location: {location}')
    print(json.dumps({'documentId': rows[0]['DocumentId'], 'sqlChunks': len(rows),
                      'sourceLineHash': line_hash(expected), 'active': False}))


if __name__ == '__main__':
    main()
