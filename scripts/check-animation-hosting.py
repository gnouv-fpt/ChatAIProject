"""Check the published static release against the exact local approved files."""
import argparse
import concurrent.futures
import hashlib
import json
import time
from pathlib import Path
from urllib.parse import quote, urlsplit
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
SITE = ROOT / 'content-animations'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--origin', default='https://content-animations.vercel.app')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    origin = args.origin.rstrip('/')
    url = urlsplit(origin)
    if url.scheme != 'https' or not url.hostname or url.path or url.query or url.fragment or url.username:
        raise ValueError('Expected a plain HTTPS origin.')
    bank = json.loads((SITE / 'bank-review/bank.json').read_text(encoding='utf8'))
    scenes = json.loads((SITE / 'bank-review/scenes.json').read_text(encoding='utf8'))['scenes']
    accepted = json.loads((SITE / 'bank-review/accepted-release.json').read_text(encoding='utf8'))
    assert sha((SITE / 'bank-review/scenes.json').read_bytes()) == accepted['scenesSha256']
    assert len(bank['questions']) == accepted['approvedCount'] == 115
    assert all(scenes[str(q['number'])]['revision'] == accepted['approvedRevisions'][str(q['number'])] for q in bank['questions'])
    paths = {'bank-review/bank.json', 'bank-review/scenes.json', 'bank-review/accepted-release.json', 'learn.html'}
    paths.update(f'q{n}.html' for n in range(486, 601))
    # All renderer code, styles, vendor dependencies, credits and model bytes.
    paths.update(p.relative_to(SITE).as_posix() for p in SITE.iterdir() if p.suffix in ('.js', '.mjs', '.css', '.svg'))
    for directory in ('models', 'vendor', 'clean-plates', 'question-bank-600'):
        paths.update(p.relative_to(SITE).as_posix() for p in (SITE / directory).rglob('*') if p.is_file())
    for q in bank['questions']:
        paths.add(q['sourceQuestionUrl'])
        paths.update(a['url'] for a in q['images'])
    expected = {path: sha((SITE / path).read_bytes()) for path in paths}

    def check(path):
        for attempt in range(3):
            try:
                request = Request(origin + '/' + quote(path, safe='/'), headers={'Cache-Control': 'no-cache'})
                with urlopen(request, timeout=50) as response:
                    if urlsplit(response.geturl()).hostname != url.hostname:
                        raise ValueError(f'Unexpected redirect: {path}')
                    data = response.read()
                    if response.status != 200 or sha(data) != expected[path]:
                        raise ValueError(f'Published bytes do not match approved local file: {path}')
                    return {'path': path, 'sha256': expected[path], 'bytes': len(data)}
            except Exception:
                if attempt == 2: raise
                time.sleep(.5)
    records = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        for index, result in enumerate(pool.map(check, sorted(paths)), 1):
            records.append(result)
            if index % 100 == 0: print(f'Checked {index}/{len(paths)} published files', flush=True)
    result = {'origin': origin, 'approvedQuestions': 115, 'learnerPages': 115,
              'scenesSha256': accepted['scenesSha256'], 'filesChecked': len(records),
              'bytesChecked': sum(r['bytes'] for r in records), 'allPublishedBytesMatch': True, 'files': records}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2), encoding='utf8')
    print(json.dumps({k: v for k, v in result.items() if k != 'files'}), flush=True)


if __name__ == '__main__': main()
