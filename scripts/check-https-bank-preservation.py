"""Snapshot/compare hashes of existing local SQL rows and all static source files.

Read-only: stores only IDs and row hashes, not account data or answer snapshots.
New rows are permitted; no baseline row may change or disappear.
"""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / 'artifacts/question-bank-https'


def snapshot():
    result = {'sql': {}, 'files': {}}
    for database, tables in {
        'TrafficContent_WebLearning_57e824ae': ['TrafficQuestions', 'TrafficQuestionCategories', 'ExamTemplates', 'ExamTemplateItems'],
        'TrafficUser_WebLearning_57e824ae': ['ExamAttempts'],
    }.items():
        for table in tables:
            query = ("SET NOCOUNT ON; SELECT t.Id, CONVERT(varchar(64), HASHBYTES('SHA2_256', "
                     f"(SELECT t.* FOR JSON PATH, INCLUDE_NULL_VALUES, WITHOUT_ARRAY_WRAPPER)), 2) AS digest "
                     f"FROM [{table}] t ORDER BY t.Id FOR JSON PATH;")
            proc = subprocess.run(['sqlcmd', '-S', '.\\MSSQLSERVER_VUON', '-E', '-d', database,
                                   '-y', '0', '-w', '65535', '-b', '-Q', query],
                                  capture_output=True, text=True, check=True)
            rows = json.loads(''.join(proc.stdout.splitlines()).strip())
            result['sql'][database + '/' + table] = {row['Id']: row['digest'] for row in rows}
    for directory in ('content-animations', 'content-bank/csgt-2025'):
        for path in (ROOT / directory).rglob('*'):
            if path.is_file() and '.vercel' not in path.parts:
                result['files'][path.relative_to(ROOT).as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture', action='store_true')
    parser.add_argument('--rerun-import', action='store_true')
    args = parser.parse_args()
    WORK.mkdir(parents=True, exist_ok=True)
    path = WORK / 'preservation-before.json'
    current = snapshot()
    if args.rerun_import:
        if args.capture:
            raise ValueError('Capture the baseline separately before import.')
        proc = subprocess.run(['pwsh', '-NoProfile', '-File', str(ROOT / 'scripts/import-question-bank-600.ps1'), '-Https'],
                              capture_output=True, text=True, cwd=ROOT, encoding='utf8')
        (WORK / 'rerun-import.log').write_text(proc.stdout + proc.stderr, encoding='utf8')
        proc.check_returncode()
        after = snapshot()
        for table, rows in current['sql'].items():
            if table.startswith('TrafficContent_'):
                assert after['sql'][table] == rows, f'Rerun changed existing rows or created duplicates: {table}'
        assert current['files'] == after['files']
        (WORK / 'rerun-check.json').write_text(json.dumps({
            'identicalContentRowsBeforeAndAfter': True,
            'contentRowCounts': {key: len(rows) for key, rows in current['sql'].items() if key.startswith('TrafficContent_')},
            'staticFilesUnchanged': True,
        }, indent=2), encoding='utf8')
        current = after
    if args.capture:
        if path.exists():
            raise ValueError('Baseline already exists; refusing to replace it.')
        path.write_text(json.dumps(current, indent=2), encoding='utf8')
        print('Captured SQL row hashes and static source hashes before import.')
    else:
        before = json.loads(path.read_text(encoding='utf8'))
        for table, rows in before['sql'].items():
            assert all(current['sql'][table].get(key) == digest for key, digest in rows.items()), table
        assert current['files'] == before['files'], 'Static assets or original source packages changed'
        evidence = {'preservedSqlRows': {key: len(rows) for key, rows in before['sql'].items()},
                    'unchangedSourceFiles': len(before['files']), 'allBaselineRowsUnchanged': True}
        (WORK / 'preservation-check.json').write_text(json.dumps(evidence, indent=2), encoding='utf8')
        print(json.dumps(evidence))
