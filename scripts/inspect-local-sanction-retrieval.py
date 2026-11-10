"""Print local verified top-five sanction locations without spending embedding quota."""
import json
import os
import sys
from pathlib import Path
from urllib.error import HTTPError

from qdrant_client import QdrantClient

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'grpc_inference_service'))
from rag.vector_store import QdrantTrafficStore  # noqa: E402


class OfflineEmbedding:
    DIMENSION = 768

    def embed_query(self, _):
        raise HTTPError('https://example.test', 429, 'offline audit', {}, None)


def main():
    runtime = json.loads((ROOT / 'artifacts/local-learning/runtime.json').read_text(encoding='utf-8-sig'))
    suffix = runtime['contentDatabase'].rsplit('_', 1)[1]
    os.environ['QDRANT_COLLECTION'] = f'traffic_law_learning_{suffix}_gemini768_v1'
    store = QdrantTrafficStore(OfflineEmbedding(), client=QdrantClient(host='127.0.0.1', port=16333))
    cases = {
        'helmet': 'Người điều khiển xe máy không đội mũ bảo hiểm bị phạt bao nhiêu?',
        'bicycle_red': 'Xe đạp vượt đèn đỏ bị phạt bao nhiêu?',
        'car_red': 'Ô tô vượt đèn đỏ bị phạt bao nhiêu?',
        'motorcycle_speed': 'Xe máy chạy quá tốc độ quy định từ 10 đến 20 km/h bị phạt bao nhiêu?',
        'delayed_camera': 'Năm 2026, xe ô tô kinh doanh vận tải hàng hóa không lắp thiết bị ghi nhận hình ảnh người lái xe bị phạt bao nhiêu?',
    }
    for name, question in cases.items():
        rows = store.search_verified_chunks(question, top_k=5)
        print(json.dumps({'case': name, 'results': [
            {'article': row.get('article'), 'clause': row.get('clause'), 'point': row.get('point'),
             'score': round(row.get('score', 0), 2), 'content': row['content'][:110]}
            for row in rows]}, ensure_ascii=True))


if __name__ == '__main__':
    main()
