"""Measure verbatim source-point retrieval across staged fines without provider calls."""
import argparse
import importlib.util
import json
import re
import sys
from pathlib import Path
from urllib.error import HTTPError

from qdrant_client import QdrantClient

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'grpc_inference_service'))
from rag.vector_store import QdrantTrafficStore  # noqa: E402


class OfflineEmbedding:
    DIMENSION = 3

    def embed_documents(self, texts):
        return [[1.0, 0.0, 0.0] for _ in texts]

    def embed_query(self, _):
        raise HTTPError('https://example.test', 429, 'offline audit', {}, None)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--limit', type=int)
    args = parser.parse_args()
    spec = importlib.util.spec_from_file_location('staging', ROOT / 'scripts/check-local-sanction-staging.py')
    staging = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(staging)
    rows = staging.load_rows()
    package = json.loads((ROOT / 'content-bank/legal/168-238-all-articles-merged-review.json').read_text(encoding='utf8'))
    expected = '\n'.join(article['content'] for article in package['articles'])
    if len(rows) != 1308 or len({row['ChunkId'] for row in rows}) != len(rows) or \
            staging.line_hash('\n'.join(row['Content'] for row in rows)) != staging.line_hash(expected):
        raise ValueError('SQL sanction text differs from the reviewed 55-article source')
    titles = {r['Article']: r['Content'] for r in rows if r['Clause'] is None and r['Point'] is None}
    headers = {(r['Article'], r['Clause']): r['Content'] for r in rows
               if r['Clause'] and r['Point'] is None}
    cases = [r for r in rows if r['Point'] and re.match(
        r'^\s*\d+[a-z]?\.\s*Phạt tiền', headers[(r['Article'], r['Clause'])], re.IGNORECASE)]
    cases.sort(key=lambda r: (int(r['Article']), r['Clause'], r['Point']))
    if args.limit is not None:
        cases = cases[:args.limit]

    store = QdrantTrafficStore(OfflineEmbedding(), client=QdrantClient(':memory:'))
    store.upsert_chunks([{
        'chunk_id': r['ChunkId'], 'document_id': r['DocumentId'],
        'document_number': r['DocumentNumber'], 'article': r['Article'] or '',
        'clause': r['Clause'] or '', 'point': r['Point'] or '', 'content': r['Content'],
        'is_verified': True, 'is_active': True} for r in rows])
    misses = []
    for index, row in enumerate(cases, 1):
        behavior = re.sub(r'^[a-zđ]\d*\)\s*', '', row['Content'])
        title = re.sub(r'^Điều\s+\d+\.\s*', '', titles[row['Article']])
        question = f'Mức phạt tiền hành vi {behavior} đối với {title}?'
        results = store.search_verified_chunks(question, top_k=5)
        if row['ChunkId'] not in {result['chunk_id'] for result in results}:
            misses.append({'article': row['Article'], 'clause': row['Clause'],
                           'point': row['Point'], 'top': [(result['article'], result['clause'],
                                                         result['point']) for result in results[:3]]})
        if index % 100 == 0:
            print(json.dumps({'checked': index, 'total': len(cases), 'misses': len(misses)}), flush=True)
    result = {'checked': len(cases), 'matchedAt5': len(cases) - len(misses),
              'misses': misses}
    target = ROOT / 'artifacts/local-ai/sanction-retrieval-audit.json'
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf8')
    print(json.dumps({'checked': result['checked'], 'matchedAt5': result['matchedAt5'],
                      'misses': len(misses), 'artifact': str(target)}), flush=True)


if __name__ == '__main__':
    main()
