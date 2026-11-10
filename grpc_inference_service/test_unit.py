import pytest
import grpc
import os
import sys
import json
import io
from pathlib import Path
from urllib.error import HTTPError, URLError
from types import SimpleNamespace
from unittest.mock import Mock
from qdrant_client import QdrantClient

CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
if CURRENT_DIR not in sys.path:
    sys.path.insert(0, CURRENT_DIR)

from moderation.moderation_engine import ModerationEngine
from verification.verification_engine import DataVerificationEngine
from rag.embeddings import EmbeddingEngine
from rag.vector_store import QdrantTrafficStore
from rag.rag_generator import TrafficRagGenerator
from rag.vision_engine import TrafficVisionEngine
from rag.visual_question_matcher import PublishedVisualQuestionMatcher
from server import TrafficRagInferenceServicer, chat_inference_pb2, rpc_errors
from data.seed_traffic_law import get_seed_traffic_law_chunks

@pytest.fixture(autouse=True)
def no_live_provider_calls(monkeypatch):
    for name in ("GROQ_API_KEY", "GROQ_API_KEYS", "GOOGLE_API_KEY", "GEMINI_API_KEY",
                 "EMBEDDING_API_KEY", "GENERATION_PROVIDER", "GROQ_MODEL"):
        monkeypatch.delenv(name, raising=False)


class FixtureEmbedding:
    DIMENSION = 3
    def embed_documents(self, texts):
        return [[1.0, 0.0, 0.0] for _ in texts]
    def embed_query(self, text):
        return self.embed_documents([text])[0]


def test_document_index_parity_detects_metadata_drift_and_extra_points():
    client = QdrantClient(":memory:")
    store = QdrantTrafficStore(embedding_engine=FixtureEmbedding(), client=client)
    chunk = {"chunk_id": "reviewed-1", "document_id": "sql-document", "document_number": "55/VBHN-VPQH",
             "document_title": "Reviewed edition", "document_version": "4", "article": "56", "clause": "1",
             "point": "a", "chapter": "", "content": "Reviewed source content", "source_url": "https://example.test/source",
             "is_verified": True, "is_active": True}
    import hashlib
    chunk["content_hash"] = hashlib.sha256(chunk["content"].encode()).hexdigest()
    store.upsert_chunks([chunk])
    assert store.verify_document_index([chunk])[:2] == (True, 1)
    assert store.verify_document_index([dict(chunk, source_url="https://example.test/wrong")])[0] is False
    assert store.verify_document_index([dict(chunk, is_active=False)])[0] is False
    extra = dict(chunk, chunk_id="reviewed-2")
    store.upsert_chunks([extra])
    assert store.verify_document_index([chunk])[0] is False


def test_effective_date_companion_requires_same_active_document():
    store = QdrantTrafficStore(embedding_engine=FixtureEmbedding(), client=QdrantClient(":memory:"))
    base = {"document_number": "168/2024/NĐ-CP", "document_id": "current-edition",
            "article": "53", "clause": "3", "point": "", "content": "3. Hiệu lực từ 2028",
            "is_verified": True, "is_active": True}
    store.upsert_chunks([dict(base, chunk_id="effective-current"),
                         dict(base, document_id="other-edition", chunk_id="effective-other"),
                         dict(base, clause="4", chunk_id="inactive-clause", is_active=False)])
    result = store.get_verified_chunk("current-edition", "53", "3")
    assert result["chunk_id"] == "effective-current"
    assert store.get_verified_chunk("current-edition", "53", "4") is None


def test_sanction_point_finds_its_own_fine_range_header():
    store = QdrantTrafficStore(embedding_engine=FixtureEmbedding(), client=QdrantClient(':memory:'))
    base = {'document_number': '168/2024/NĐ-CP', 'document_id': 'current-edition',
            'article': '7', 'clause': '7', 'is_verified': True, 'is_active': True}
    store.upsert_chunks([
        dict(base, chunk_id='article-title', clause='', point='', content='Điều 7. Người điều khiển xe mô tô'),
        dict(base, chunk_id='fine-range', point='', content='7. Phạt tiền từ 4.000.000 đến 6.000.000 đồng'),
        dict(base, chunk_id='red-light', point='c', content='c) Không chấp hành hiệu lệnh của đèn tín hiệu giao thông')])
    assert store.get_verified_chunk('current-edition', '7', '', point='')['chunk_id'] == 'article-title'
    assert store.get_verified_chunk('current-edition', '7', '7', point='')['chunk_id'] == 'fine-range'
    assert store.get_verified_chunk('current-edition', '7', '7') is None
    assert {row['chunk_id'] for row in store.get_verified_article_chunks('current-edition', '7')} == \
        {'article-title', 'fine-range', 'red-light'}


def test_sanction_chat_supplies_fine_range_and_license_points_to_generator():
    service = object.__new__(TrafficRagInferenceServicer)
    service.moderation_engine = SimpleNamespace(check=lambda _: (False, [], ''))
    point = {'chunk_id': 'red-light', 'document_number': '168/2024/NĐ-CP', 'document_id': 'law',
             'article': '7', 'clause': '7', 'point': 'c', 'content': 'c) Không chấp hành hiệu lệnh của đèn tín hiệu'}
    title = dict(point, chunk_id='article-title', clause='', point='',
                 content='Điều 7. Xử phạt người điều khiển xe mô tô, xe gắn máy')
    header = dict(point, chunk_id='fine-range', point='', content='7. Phạt tiền từ 4 đến 6 triệu đồng')
    deduction_header = dict(point, chunk_id='deduction-header', clause='13', point='',
                            content='13. Người điều khiển xe còn bị trừ điểm giấy phép lái xe')
    deduction = dict(point, chunk_id='license-points', clause='13', point='b',
                     content='b) Điểm c khoản 7 Điều này bị trừ điểm giấy phép lái xe 04 điểm')
    def matching_header(_, __, clause, **kwargs):
        return title if clause == '' else deduction_header if clause == '13' else header
    service.vector_store = SimpleNamespace(
        search_verified_chunks=lambda *args, **kwargs: [point],
        get_verified_chunk=matching_header,
        get_verified_article_chunks=lambda *args, **kwargs: [deduction])
    generate = Mock(return_value=('fixture', [], 0, False))
    service.rag_generator = SimpleNamespace(NO_MATCH_RESPONSE='No match', generate=generate)
    request = chat_inference_pb2.ChatInferenceRequest(prompt='Vượt đèn đỏ xe máy bị xử phạt thế nào?')
    context = SimpleNamespace(is_active=lambda: True)
    service.ProcessChatMessage(request, context)
    supplied = generate.call_args.args[1]
    assert {row['chunk_id'] for row in supplied} == {
        'red-light', 'article-title', 'fine-range', 'deduction-header', 'license-points'}


def test_sanction_supplement_matches_point_within_the_referenced_clause():
    refers = TrafficRagInferenceServicer._supplement_refers_to_point
    four_points = ('điểm đ khoản 4; điểm a khoản 6; '
                   'điểm c, điểm d, điểm đ khoản 7; điểm a khoản 8 bị trừ 04 điểm')
    two_points = ('điểm b khoản 3; khoản 5; điểm b, điểm c khoản 6; '
                  'điểm a khoản 7 bị trừ 02 điểm')
    assert refers(four_points, '7', 'c')
    assert not refers(two_points, '7', 'c')
    assert refers(two_points, '5', 'c')
    assert not refers(four_points, '7', 'b')


def test_cargo_camera_answer_requires_2028_effectivity_citation():
    service = object.__new__(TrafficRagInferenceServicer)
    service.moderation_engine = SimpleNamespace(check=lambda _: (False, [], ''))
    base = {'document_number': '168/2024/NĐ-CP', 'document_id': 'law',
            'is_verified': True, 'is_active': True}
    driver = dict(base, chunk_id='driver', article='21', clause='3', point='b', content='Camera driver')
    operator = dict(base, chunk_id='operator', article='26', clause='7', point='g', content='Camera operator')
    def evidence(_, article, clause, **kwargs):
        return dict(base, chunk_id=f'{article}-{clause}', article=article, clause=clause,
                    point='', content='Verified legal evidence')
    service.vector_store = SimpleNamespace(search_verified_chunks=lambda *a, **k: [driver, operator],
                                           get_verified_chunk=evidence)
    service.rag_generator = SimpleNamespace(NO_MATCH_RESPONSE='No match',
        generate=lambda *a, **k: ('Only the operator fine.',
            [{'article_number': '26', 'clause_number': '7', 'chunk_id': 'operator'}], 50, True))
    request = chat_inference_pb2.ChatInferenceRequest(
        prompt='Năm 2026, xe ô tô kinh doanh vận tải hàng hóa không lắp thiết bị ghi nhận hình ảnh người lái xe bị phạt bao nhiêu?')
    response = service.ProcessChatMessage(request, SimpleNamespace(is_active=lambda: True))
    assert response.result_status == 'NoMatch' and not response.citations


def test_clause_only_fine_supplies_article_scope_to_generator():
    service = object.__new__(TrafficRagInferenceServicer)
    service.moderation_engine = SimpleNamespace(check=lambda _: (False, [], ''))
    fine = {'chunk_id': 'fine-clause', 'document_number': '168/2024/NĐ-CP',
            'document_id': 'law', 'article': '20', 'clause': '2', 'point': '',
            'content': '2. Phạt tiền trên mỗi người chở vượt quá quy định'}
    title = dict(fine, chunk_id='article-title', clause='', content='Điều 20. Người điều khiển xe chở khách')
    service.vector_store = SimpleNamespace(
        search_verified_chunks=lambda *args, **kwargs: [fine],
        get_verified_chunk=lambda *args, **kwargs: title)
    generate = Mock(return_value=('fixture', [], 0, False))
    service.rag_generator = SimpleNamespace(NO_MATCH_RESPONSE='No match', generate=generate)
    request = chat_inference_pb2.ChatInferenceRequest(prompt='Chở quá số người bị phạt bao nhiêu?')
    service.ProcessChatMessage(request, SimpleNamespace(is_active=lambda: True))
    assert {row['chunk_id'] for row in generate.call_args.args[1]} == {'fine-clause', 'article-title'}


def test_two_points_in_one_clause_keep_their_distinct_license_deductions():
    service = object.__new__(TrafficRagInferenceServicer)
    service.moderation_engine = SimpleNamespace(check=lambda _: (False, [], ''))
    base = {'document_number': '168/2024/NĐ-CP', 'document_id': 'law', 'article': '7'}
    points = [dict(base, chunk_id='behavior-a', clause='7', point='a', content='a) Hành vi thứ nhất'),
              dict(base, chunk_id='behavior-c', clause='7', point='c', content='c) Hành vi thứ hai')]
    title = dict(base, chunk_id='title', clause='', point='', content='Điều 7. Xe máy')
    fine = dict(base, chunk_id='fine', clause='7', point='', content='7. Phạt tiền từ 4 đến 6 triệu đồng')
    deduction_header = dict(base, chunk_id='deduction-header', clause='13', point='',
                            content='13. Ngoài phạt tiền còn trừ điểm')
    deductions = [dict(base, chunk_id='deduction-a', clause='13', point='a',
                       content='a) Điểm a khoản 7 Điều này bị trừ điểm giấy phép lái xe 02 điểm'),
                  dict(base, chunk_id='deduction-c', clause='13', point='b',
                       content='b) Điểm c khoản 7 Điều này bị trừ điểm giấy phép lái xe 04 điểm')]
    service.vector_store = SimpleNamespace(
        search_verified_chunks=lambda *args, **kwargs: points,
        get_verified_chunk=lambda _, __, clause, **kwargs:
            title if clause == '' else deduction_header if clause == '13' else fine,
        get_verified_article_chunks=lambda *args, **kwargs: deductions)
    generate = Mock(return_value=('fixture', [], 0, False))
    service.rag_generator = SimpleNamespace(NO_MATCH_RESPONSE='No match', generate=generate)
    request = chat_inference_pb2.ChatInferenceRequest(prompt='Hai hành vi này bị phạt và trừ điểm thế nào?')
    service.ProcessChatMessage(request, SimpleNamespace(is_active=lambda: True))
    supplied = {row['chunk_id'] for row in generate.call_args.args[1]}
    assert {'behavior-a', 'behavior-c', 'deduction-a', 'deduction-c'} <= supplied


def test_document_embedding_retries_transient_network_failure(monkeypatch):
    embedding = EmbeddingEngine.__new__(EmbeddingEngine)
    embedding._embed = Mock(side_effect=[URLError("temporary network failure"), [[1.0, 0.0, 0.0]]])
    monkeypatch.setattr("rag.embeddings.time.sleep", lambda _: None)
    assert embedding.embed_documents(["sanction text"]) == [[1.0, 0.0, 0.0]]
    assert embedding._embed.call_count == 2


def test_document_embedding_stops_when_daily_quota_is_exhausted(monkeypatch):
    embedding = EmbeddingEngine.__new__(EmbeddingEngine)
    error = HTTPError('https://example.test', 429, 'quota', {},
                      io.BytesIO(b'{"error":{"message":"Requests per day quota exceeded"}}'))
    embedding._embed = Mock(side_effect=error)
    sleep = Mock()
    monkeypatch.setattr('rag.embeddings.time.sleep', sleep)
    with pytest.raises(HTTPError):
        embedding.embed_documents(['sanction text'])
    assert embedding._embed.call_count == 1
    sleep.assert_not_called()


def test_lexical_retrieval_keeps_sanction_chat_available_during_embedding_quota():
    embedding = FixtureEmbedding()
    embedding.embed_query = Mock(side_effect=AssertionError('Strong sanction match should not embed'))
    store = QdrantTrafficStore(embedding_engine=embedding, client=QdrantClient(':memory:'))
    base = {'document_number': '168/2024/NĐ-CP', 'is_verified': True, 'is_active': True}
    store.upsert_chunks([
        dict(base, chunk_id='motor-title', document_id='law', article='7', clause='', point='',
             content='Điều 7. Người điều khiển xe mô tô, xe gắn máy'),
        dict(base, chunk_id='motor-red', document_id='law', article='7', clause='7', point='c',
             content='c) Không chấp hành hiệu lệnh của đèn tín hiệu giao thông;'),
        dict(base, chunk_id='car-title', document_id='law', article='6', clause='', point='',
             content='Điều 6. Người điều khiển xe ô tô'),
        dict(base, chunk_id='car-red', document_id='law', article='6', clause='9', point='b',
             content='b) Không chấp hành hiệu lệnh của đèn tín hiệu giao thông;'),
    ])
    rows = store.search_verified_chunks('Vượt đèn đỏ xe máy bị phạt thế nào?', top_k=4)
    assert rows and rows[0]['chunk_id'] == 'motor-red'
    assert 'car-red' not in {row['chunk_id'] for row in rows}
    car_rows = store.search_verified_chunks('Ô tô vượt đèn đỏ bị phạt thế nào?', top_k=4)
    assert car_rows and car_rows[0]['chunk_id'] == 'car-red'
    assert 'motor-red' not in {row['chunk_id'] for row in car_rows}
    embedding.embed_query.assert_not_called()


def test_lexical_retrieval_ignores_unverified_sanction_points():
    embedding = FixtureEmbedding()
    embedding.embed_query = Mock(side_effect=HTTPError('https://example.test', 429, 'quota', {}, None))
    store = QdrantTrafficStore(embedding_engine=embedding, client=QdrantClient(':memory:'))
    store.upsert_chunks([{'chunk_id': 'pending', 'document_number': '168/2024/NĐ-CP',
                          'document_id': 'law', 'article': '7', 'clause': '7', 'point': 'c',
                          'content': 'c) Không chấp hành hiệu lệnh của đèn tín hiệu giao thông',
                          'is_verified': False, 'is_active': False}])
    assert store.search_verified_chunks('Xe máy vượt đèn đỏ bị phạt bao nhiêu?') == []


def test_speed_range_does_not_trigger_red_light_boost():
    embedding = FixtureEmbedding()
    embedding.embed_query = Mock(side_effect=AssertionError('Strong sanction match should not embed'))
    store = QdrantTrafficStore(embedding_engine=embedding, client=QdrantClient(':memory:'))
    base = {'document_number': '168/2024/NĐ-CP', 'document_id': 'law', 'article': '7',
            'is_verified': True, 'is_active': True}
    store.upsert_chunks([
        dict(base, chunk_id='title', clause='', point='', content='Điều 7. Người điều khiển xe mô tô'),
        dict(base, chunk_id='red', clause='7', point='c',
             content='c) Không chấp hành hiệu lệnh của đèn tín hiệu giao thông;'),
        dict(base, chunk_id='speed', clause='4', point='a',
             content='a) Điều khiển xe chạy quá tốc độ quy định từ 10 km/h đến 20 km/h;'),
    ])
    rows = store.search_verified_chunks('Xe máy chạy quá tốc độ từ 10 đến 20 km/h bị phạt bao nhiêu?')
    assert rows[0]['chunk_id'] == 'speed'


def test_sanction_retrieval_prefers_direct_fine_over_supplementary_clause():
    embedding = FixtureEmbedding()
    embedding.embed_query = Mock(side_effect=AssertionError('Lexical evidence should be sufficient'))
    store = QdrantTrafficStore(embedding_engine=embedding, client=QdrantClient(':memory:'))
    base = {'document_number': '168/2024/NĐ-CP', 'document_id': 'law', 'article': '7',
            'is_verified': True, 'is_active': True}
    behavior = 'Không chấp hành hiệu lệnh của đèn tín hiệu giao thông'
    store.upsert_chunks([
        dict(base, chunk_id='title', clause='', point='', content='Điều 7. Xe mô tô, xe gắn máy'),
        dict(base, chunk_id='fine-header', clause='7', point='', content='7. Phạt tiền từ 4 đến 6 triệu đồng'),
        dict(base, chunk_id='fine-point', clause='7', point='c', content='c) ' + behavior),
        dict(base, chunk_id='extra-header', clause='13', point='',
             content='13. Ngoài việc bị phạt tiền, người lái xe còn bị trừ điểm'),
        dict(base, chunk_id='extra-point', clause='13', point='b', content='b) ' + behavior),
    ])
    rows = store.search_verified_chunks('Xe máy vượt đèn đỏ bị phạt bao nhiêu?')
    assert rows[0]['chunk_id'] == 'fine-point'


# ==============================================================================
# 1. TEST MODERATION ENGINE
# ==============================================================================
def test_moderation_toxic_and_bribery():
    engine = ModerationEngine()
    
    # Negative / Toxic test
    is_vio, kws, msg = engine.check("Cách để đút lót csgt khi bị thổi nồng độ cồn?")
    assert is_vio is True
    assert any("đút lót" in k or "nồng độ cồn" in k for k in kws)
    assert len(msg) > 0

    # Clean prompt
    is_vio_clean, kws_clean, _ = engine.check("Mức phạt khi không đội mũ bảo hiểm xe máy là bao nhiêu?")
    assert is_vio_clean is False
    assert len(kws_clean) == 0

# ==============================================================================
# 2. TEST VERIFICATION ENGINE
# ==============================================================================
def test_verification_valid_and_outdated_documents():
    engine = DataVerificationEngine()

    # Active valid document
    res1 = engine.verify_document("Luật Trật tự, an toàn giao thông đường bộ · VBHN 55/2026", "55/VBHN-VPQH")
    assert res1["is_valid"] is True
    assert res1["status"] == "Verified"

    # Outdated superseded document
    res2 = engine.verify_document("Nghị định 46/2016/NĐ-CP", "46/2016/NĐ-CP")
    assert res2["is_valid"] is False
    assert res2["status"] == "Outdated"

    # Unknown document must default to Pending
    res3 = engine.verify_document("Quy định nội bộ công ty ABC", "999/2024/ABC")
    assert res3["is_valid"] is False
    assert res3["status"] == "Pending"
    for number in ["100/2019/NĐ-CP", "123/2021/NĐ-CP", "23/2008/QH12", "36/2024/QH15"]:
        assert engine.verify_document("Legacy source", number)["status"] == "Pending"


def test_sanction_verification_only_accepts_exact_reviewed_targeted_scope():
    root = Path(__file__).resolve().parents[1] / "content-bank/legal"
    package = json.loads((root / "168-238-targeted-sanctions-reviewed.json").read_text(encoding="utf8"))
    content = package["content"]
    verifier = DataVerificationEngine()
    assert verifier.verify_document("168 amended by 238", "168/2024/NĐ-CP", content)["status"] == "Verified"
    assert verifier.verify_document("168 amended by 238", "168/2024/NĐ-CP", content.replace(
        "30.000.000 đồng", "29.000.000 đồng", 1))["status"] == "Pending"
    full = json.loads((root / "168-238-all-articles-merged-review.json").read_text(encoding="utf8"))
    assert verifier.verify_document("168 amended by 238", "168/2024/NĐ-CP",
        "\n".join(article["content"] for article in full["articles"]))["status"] == "Pending"


def test_compound_sanction_questions_require_each_distinct_legal_fact():
    requirements = TrafficRagGenerator.required_sanction_locations
    assert requirements('Người lái xe ô tô có chất ma túy bị áp dụng hình thức xử phạt nào?') == (
        ('6', '11', ''), ('6', '11', 'c'), ('6', '15', 'c'))
    assert requirements('Người lái xe ô tô có nồng độ cồn bị xử phạt hình thức nào?') == (
        ('6', '6', ''), ('6', '6', 'c'), ('6', '11', ''), ('6', '11', 'a'), ('6', '15', 'c'))
    assert requirements('Người được chở không đội mũ bảo hiểm, người điều khiển có bị phạt?') == (
        ('7', '2', ''), ('7', '2', 'i'), ('12', '5', ''), ('12', '5', 'b'))
    assert not requirements('Người đi bộ không đội mũ bảo hiểm có bị phạt không?')


def test_compound_sanction_answer_abstains_without_passenger_provision():
    chunks = [{'chunk_id': str(i), 'document_number': '168/2024/NĐ-CP',
               'article': article, 'clause': clause, 'point': point, 'content': 'Verified text'}
              for i, (article, clause, point) in enumerate((
                  ('7', '2', ''), ('7', '2', 'i'), ('12', '5', '')), start=1)]
    answer, citations, tokens, grounded = TrafficRagGenerator().generate(
        'Người được chở không đội mũ bảo hiểm và người điều khiển bị phạt không?', chunks)
    assert answer == TrafficRagGenerator.NO_MATCH_RESPONSE
    assert not citations and tokens == 0 and not grounded


def test_insufficient_context_budget_has_distinct_rpc_status():
    class Broken:
        @rpc_errors
        def ProcessChatMessage(self, request, context):
            raise RuntimeError('The reserved token budget cannot cover this context')

    def abort(code, detail):
        assert code == grpc.StatusCode.RESOURCE_EXHAUSTED
        raise grpc.RpcError(detail)

    with pytest.raises(grpc.RpcError):
        Broken().ProcessChatMessage(None, SimpleNamespace(is_active=lambda: True, abort=abort))


def test_mc_option_label_uses_only_explicit_or_unique_answer_text():
    label = TrafficRagGenerator._label_mc_answer
    question = 'Tối thiểu bao nhiêu tuổi?\n1. 16 tuổi.\n2. 17 tuổi.\n3. 18 tuổi.'
    assert label(question, '18 tuổi. Theo Điều 59...').startswith('3. 18 tuổi.')
    assert label(question, 'Theo luật, đáp án đúng là 3.').startswith('3. Theo luật')
    assert label(question, 'Theo luật, 18 tuổi là tối thiểu.').startswith('3. Theo luật')
    assert label('Hỏi gì?\n1. Phạt tiền.\n2. Tước GPLX.\n3. Cả hai ý trên.',
                 'Hành vi bị xử phạt cả hai hình thức: phạt tiền và tước GPLX.').startswith('3. ')
    assert label('Hỏi gì?\n1. A.\n2. B.\n3. C.\n4. Cả ba ý trên.',
                 'Câu trả lời đúng là 4.').startswith('4. ')

# ==============================================================================
# 3. TEST EMBEDDINGS & VECTOR STORE (QDRANT IN-MEMORY)
# ==============================================================================
def test_vector_store_indexing_and_search():
    embedding = FixtureEmbedding()
    store = QdrantTrafficStore(embedding_engine=embedding, client=QdrantClient(":memory:"))
    
    # Test deterministic point_id hashing
    chunk_id = "chunk-test-123"
    pid1 = store.chunk_id_to_point_id(chunk_id)
    pid2 = store.chunk_id_to_point_id(chunk_id)
    assert pid1 == pid2
    assert isinstance(pid1, int)

    # Test indexing
    chunks = get_seed_traffic_law_chunks()
    count = store.upsert_chunks(chunks)
    assert count == len(chunks)

    # Test search verified chunks
    results = store.search_verified_chunks("vượt đèn đỏ xe máy", top_k=2)
    assert len(results) > 0
    assert results[0]["is_verified"] is True
    assert results[0]["is_active"] is True

    # Test deactivation
    store.deactivate_document("100/2019/NĐ-CP")
    # Search should no longer return deactivated chunks
    results_after = store.search_verified_chunks("vượt đèn đỏ xe máy", top_k=2)
    for r in results_after:
        assert r.get("document_number") != "100/2019/NĐ-CP"


def test_staged_edition_vectors_do_not_hide_active_prior_corpus():
    store = QdrantTrafficStore(embedding_engine=FixtureEmbedding(), client=QdrantClient(":memory:"))
    old = {"chunk_id": "edition3-old", "document_number": "55/VBHN-VPQH", "document_version": "3",
           "content": "Existing reviewed article", "is_verified": True, "is_active": True}
    staged = {"chunk_id": "edition4-staged", "document_number": "55/VBHN-VPQH", "document_version": "4",
              "content": "New staged article", "is_verified": True, "is_active": False}
    assert store.upsert_chunks([old, staged]) == 2
    assert [row["chunk_id"] for row in store.search_verified_chunks("existing", top_k=10)] == ["edition3-old"]

# ==============================================================================
# 4. TEST RAG GENERATOR & ZERO HALLUCINATION
# ==============================================================================
def test_rag_generator_zero_hallucination():
    generator = TrafficRagGenerator()
    completion = SimpleNamespace(choices=[SimpleNamespace(message=SimpleNamespace(content=json.dumps(
        {"status": "Answered", "answer": "Fixture answer: Điều 6", "chunk_ids": ["chunk-01"]})))],
        usage=SimpleNamespace(total_tokens=42))
    generator._groq_clients = [SimpleNamespace(chat=SimpleNamespace(
        completions=SimpleNamespace(create=Mock(return_value=completion))))]

    # Empty verified chunks -> strictly return NO_MATCH_RESPONSE
    ans, citations, tokens, verified = generator.generate("Kinh doanh trà sữa", [])
    assert verified is False
    assert len(citations) == 0
    assert ans == generator.NO_MATCH_RESPONSE

    # With verified chunks -> return synthesized answer with citations
    mock_chunks = [{
        "chunk_id": "chunk-01",
        "document_title": "Nghị định 100/2019/NĐ-CP",
        "document_number": "100/2019/NĐ-CP",
        "article": "Điều 6",
        "clause": "Khoản 4",
        "point": "Điểm e",
        "document_version": "1.0",
        "source_url": "https://thuvienphapluat.vn",
        "content": "Phạt tiền từ 800.000 đồng đến 1.000.000 đồng đối với người điều khiển xe mô tô vượt đèn đỏ."
    }]
    ans2, citations2, tokens2, verified2 = generator.generate("Vượt đèn đỏ xe máy", mock_chunks)
    assert verified2 is True
    assert len(citations2) == 1
    assert citations2[0]["chunk_id"] == "chunk-01"
    assert citations2[0]["point_number"] == "Điểm e"
    assert "Điều 6" in ans2

# ==============================================================================
# 5. TEST VISION ENGINE
# ==============================================================================
def test_vision_engine_clarification():
    vision = TrafficVisionEngine()
    vision._gemini_model = SimpleNamespace(generate_content=Mock(side_effect=[
        SimpleNamespace(text=json.dumps({"is_clear": False}), usage_metadata=SimpleNamespace(total_token_count=7)),
        SimpleNamespace(text=json.dumps({"is_clear": True, "observations": "Synthetic scene", "search_query": "fixture"}),
            usage_metadata=SimpleNamespace(total_token_count=9))]))
    
    # Blurry / unclear prompt -> requires_clarification = True
    obs, req_clar, _ = vision.analyze_traffic_image(
        image_base64="aW1hZ2U=",
        mime_type="image/jpeg",
        user_prompt="Ảnh mờ không rõ biển báo"
    )
    assert req_clar is True
    assert "chưa đủ rõ ràng" in obs

    # Clear valid prompt -> requires_clarification = False
    valid_b64 = "aW1hZ2VfZGF0YV92YWxpZF9zY2VuZV93aXRoX2Vub3VnaF9ieXRlc19mb3Jfc2ltdWxhdGlvbl90ZXN0XzEyMzQ1Njc4OQ==" * 3
    obs2, req_clar2, _ = vision.analyze_traffic_image(
        image_base64=valid_b64,
        mime_type="image/jpeg",
        user_prompt="Xe máy vượt đèn đỏ ngã tư"
    )
    assert req_clar2 is False
    assert len(obs2) > 0


def test_vision_retries_fallback_model_after_transient_quota_error():
    vision = TrafficVisionEngine()
    primary = Mock(side_effect=HTTPError('https://provider.example', 429, 'quota', {}, io.BytesIO(b'{}')))
    fallback = Mock(return_value=SimpleNamespace(text=json.dumps({
        "is_clear": True, "observations": "Xe A ở ngã tư.",
        "search_query": "nhường đường tại nơi giao nhau"}),
        usage_metadata=SimpleNamespace(total_token_count=120)))
    vision._gemini_model = SimpleNamespace(generate_content=primary)
    vision._gemini_fallback_model = SimpleNamespace(generate_content=fallback)
    observation, clarify, query = vision.analyze_traffic_image('aW1hZ2U=', 'image/jpeg', 'Xe nào đi trước?')
    assert not clarify and observation == 'Xe A ở ngã tư.' and 'nhường đường' in query
    assert vision.last_tokens == 120
    primary.assert_called_once()
    fallback.assert_called_once()


def test_published_visual_lookup_accepts_recoded_unique_scenarios_only():
    from PIL import Image
    matcher = PublishedVisualQuestionMatcher()
    root = Path(__file__).resolve().parents[1]
    for number, expected in ((490, '3.'), (493, '1.')):
        original = root / f'content-animations/bank-review/{number}/image-1.jpeg'
        with Image.open(original) as image:
            recoded = io.BytesIO()
            image.resize((300, 170)).save(recoded, 'JPEG', quality=65)
        answer = matcher.match(f'Câu {number}: thứ tự các xe đi thế nào?', recoded.getvalue())
        assert answer and f'Câu {number}' in answer and f'Đáp án: {expected}' in answer
        assert 'Nguồn đáp án bộ đề CSGT' in answer
        assert matcher.match('Mô tả màu sắc trong ảnh này', recoded.getvalue()) is None
        assert matcher.match(f'Câu {number} trong ảnh có mấy xe màu đỏ?', recoded.getvalue()) is None
    duplicated = (root / 'content-animations/bank-review/486/image-1.jpeg').read_bytes()
    assert matcher.match('Đáp án câu này là gì?', duplicated) is None
    assert 'Câu 486' in matcher.match('Câu 486 đáp án gì?', duplicated)
    unrelated = io.BytesIO()
    Image.new('RGB', (496, 280), color=(25, 80, 180)).save(unrelated, 'JPEG')
    assert matcher.match('Câu 490 đáp án gì?', unrelated.getvalue()) is None


def test_published_sign_image_uses_source_key_without_inventing_a_law_citation():
    from PIL import Image
    matcher = PublishedVisualQuestionMatcher()
    root = Path(__file__).resolve().parents[1]
    original = root / 'content-animations/question-bank-600/310/image-1.jpeg'
    with Image.open(original) as image:
        recoded = io.BytesIO()
        image.thumbnail((300, 300))
        image.save(recoded, 'JPEG', quality=65)
    answer = matcher.match('Câu 310: Biển nào cấm xe ô tô tải vượt?', recoded.getvalue())
    assert answer and 'Đáp án: 4. Biển 2 và biển 3.' in answer
    assert 'nguồn đáp án' in answer.lower() and 'chưa phải trích dẫn điều luật' in answer
    assert matcher.match('Câu 310 trong ảnh có mấy màu đỏ?', recoded.getvalue()) is None


def test_unmatched_sign_image_cannot_cite_generic_sign_category_as_specific_meaning():
    from PIL import Image
    service = TrafficRagInferenceServicer.__new__(TrafficRagInferenceServicer)
    service.moderation_engine = ModerationEngine()
    service.visual_question_matcher = SimpleNamespace(match=lambda *_: None)
    service.vision_engine = SimpleNamespace(last_tokens=100, analyze_traffic_image=lambda *a, **k:
                                            ('Ba biển rõ nét.', False, 'biển báo cấm đi ngược chiều'))
    law = {'chunk_id': 'generic', 'document_number': '55/VBHN-VPQH', 'article': '11',
           'clause': '5', 'content': 'Biển báo cấm để biểu thị điều cấm.'}
    service.vector_store = SimpleNamespace(search_verified_chunks=lambda *a, **k: [law])
    service.rag_generator = SimpleNamespace(NO_MATCH_RESPONSE='Không đủ căn cứ.', generate=Mock())
    image = io.BytesIO()
    Image.new('RGB', (64, 64), 'white').save(image, 'PNG')
    result = service.ProcessChatMessage(chat_inference_pb2.ChatInferenceRequest(
        prompt='Biển nào là biển cấm đi ngược chiều?',
        images=[chat_inference_pb2.ChatImage(content=image.getvalue(), mime_type='image/png')]),
        SimpleNamespace(is_active=lambda: True))
    assert result.result_status == 'NoMatch' and not result.citations
    assert 'QCVN 41:2024/BGTVT' in result.response_text
    service.rag_generator.generate.assert_not_called()


def test_recoded_published_image_uses_answer_key_before_vision_or_rag():
    service = TrafficRagInferenceServicer.__new__(TrafficRagInferenceServicer)
    service.moderation_engine = ModerationEngine()
    service.visual_question_matcher = PublishedVisualQuestionMatcher()
    service.vision_engine = SimpleNamespace(analyze_traffic_image=Mock())
    service.vector_store = SimpleNamespace(search_verified_chunks=Mock())
    service.rag_generator = SimpleNamespace(generate=Mock())
    root = Path(__file__).resolve().parents[1]
    from PIL import Image
    with Image.open(root / 'content-animations/bank-review/493/image-1.jpeg') as image:
        recoded = io.BytesIO()
        image.save(recoded, 'JPEG', quality=70)
    request = chat_inference_pb2.ChatInferenceRequest(
        prompt='Câu 493: Thứ tự các xe đi như thế nào?',
        images=[chat_inference_pb2.ChatImage(content=recoded.getvalue(), mime_type='image/jpeg')])
    result = service.ProcessChatMessage(request, SimpleNamespace(is_active=lambda: True))
    assert result.result_status == 'PracticeAnswered' and 'Đáp án: 1.' in result.response_text
    assert result.images_processed and not result.citations and result.tokens_used == 0
    service.vision_engine.analyze_traffic_image.assert_not_called()
    service.vector_store.search_verified_chunks.assert_not_called()
    service.rag_generator.generate.assert_not_called()


def test_embedding_requires_explicit_api_configuration(monkeypatch):
    monkeypatch.delenv("EMBEDDING_API_URL", raising=False)
    with pytest.raises(RuntimeError, match="Configure HTTPS"):
        EmbeddingEngine()


def test_embedding_api_validates_batch_dimensions_and_order(monkeypatch):
    import io
    import rag.embeddings as module
    for key, value in {"EMBEDDING_API_URL": "https://embeddings.example.org/v1/embeddings",
            "EMBEDDING_API_KEY": "fixture", "EMBEDDING_MODEL": "fixture-model", "EMBEDDING_DIMENSION": "3"}.items():
        monkeypatch.setenv(key, value)
    monkeypatch.setattr(module, "urlopen", lambda *args, **kwargs: io.StringIO(json.dumps({"data": [
        {"index": 1, "embedding": [0, 1, 0]}, {"index": 0, "embedding": [1, 0, 0]}]})))
    assert EmbeddingEngine().embed_documents(["first", "second"]) == [[1, 0, 0], [0, 1, 0]]
    monkeypatch.setattr(module, "urlopen", lambda *args, **kwargs: io.StringIO('{"data":[{"index":0,"embedding":[1]}]}'))
    with pytest.raises(RuntimeError, match="dimensions"):
        EmbeddingEngine().embed_query("bad")


def test_embedding_quota_429_fails_without_waiting_past_chat_deadline(monkeypatch):
    import io
    from urllib.error import HTTPError
    import rag.embeddings as module
    for key, value in {"EMBEDDING_PROVIDER": "openai", "EMBEDDING_API_URL": "https://embeddings.example.org/v1",
            "EMBEDDING_API_KEY": "fixture", "EMBEDDING_MODEL": "fixture", "EMBEDDING_DIMENSION": "3"}.items():
        monkeypatch.setenv(key, value)
    attempts = []
    def quota(*args, **kwargs):
        attempts.append(1)
        raise HTTPError('https://embeddings.example.org/v1', 429, 'quota', {}, io.BytesIO(b'{}'))
    monkeypatch.setattr(module, 'urlopen', quota)
    monkeypatch.setattr(module.time, 'sleep', lambda *_: pytest.fail('Quota 429 must not sleep'))
    with pytest.raises(HTTPError) as error:
        EmbeddingEngine().embed_query('fixture')
    assert error.value.code == 429 and len(attempts) == 1


def test_document_embedding_retries_429_without_changing_chat_behavior(monkeypatch):
    import io
    from urllib.error import HTTPError
    import rag.embeddings as module
    for key, value in {"EMBEDDING_PROVIDER": "openai", "EMBEDDING_API_URL": "https://embeddings.example.org/v1",
            "EMBEDDING_API_KEY": "fixture", "EMBEDDING_MODEL": "fixture", "EMBEDDING_DIMENSION": "3"}.items():
        monkeypatch.setenv(key, value)
    calls, delays = [], []
    def respond(*args, **kwargs):
        calls.append(1)
        if len(calls) == 1:
            raise HTTPError('https://embeddings.example.org/v1', 429, 'quota', {'Retry-After': '2'}, io.BytesIO(b'{}'))
        return io.StringIO('{"data":[{"index":0,"embedding":[1,0,0]}]}')
    monkeypatch.setattr(module, 'urlopen', respond)
    monkeypatch.setattr(module.time, 'sleep', delays.append)
    assert EmbeddingEngine().embed_documents(['fixture']) == [[1, 0, 0]]
    assert len(calls) == 2 and delays == [2]


def test_no_synthetic_provider_or_vector_fallback(monkeypatch):
    import rag.vector_store as module
    monkeypatch.setattr(module, "QdrantClient", Mock(side_effect=ConnectionError("Qdrant down")))
    with pytest.raises(ConnectionError):
        QdrantTrafficStore(FixtureEmbedding())
    with pytest.raises(RuntimeError, match="Generation API unavailable"):
        TrafficRagGenerator().generate("question", [{"chunk_id": "fixture", "content": "fixture"}])
    with pytest.raises(RuntimeError, match="Vision API unavailable"):
        TrafficVisionEngine().analyze_traffic_image("aW1hZ2U=", "image/png", "fixture")


def test_grounding_rejects_invented_ids_and_allows_explicit_no_match():
    generator = TrafficRagGenerator()
    citations = [{"chunk_id": "known", "excerpt": "x" * 250}]
    result = generator._grounded_result(json.dumps({"status": "NoMatch", "answer": "ignored", "chunk_ids": []}), citations, 12)
    assert result == (generator.NO_MATCH_RESPONSE, [], 12, False)
    with pytest.raises(ValueError, match="unknown evidence"):
        generator._grounded_result(json.dumps({"status": "Answered", "answer": "invented", "chunk_ids": ["other"]}), citations, 12)
    with pytest.raises(ValueError, match="evidence decision"):
        generator._grounded_result(json.dumps({"status": "Answered", "answer": "unbacked", "chunk_ids": []}), citations, 12)


def test_sanction_question_abstains_when_only_traffic_law_is_retrieved():
    generator = TrafficRagGenerator()
    law = [{"chunk_id": "law-rule", "document_number": "55/VBHN-VPQH",
            "content": "Quy tắc tham gia giao thông đường bộ."}]
    response = SimpleNamespace(text=json.dumps({"status": "Answered", "answer": "Quy tắc hiện tại.",
        "chunk_ids": ["law-rule"]}), usage_metadata=SimpleNamespace(total_token_count=12))
    provider = Mock(return_value=response)
    generator._gemini_client = SimpleNamespace(generate_content=provider)
    assert generator.generate("Hình thức xử phạt vi phạm hành chính là gì?", law) == (
        generator.NO_MATCH_RESPONSE, [], 0, False)
    provider.assert_not_called()
    # A previous sanction question must not block a changed current subject.
    answer = generator.generate("lịch sử: mức phạt?\nQuy tắc hiện tại?", law,
                                current_question="Quy tắc hiện tại?")
    assert answer[0] == "Quy tắc hiện tại." and answer[3]
    provider.assert_called_once()


@pytest.mark.parametrize("question", [
    "Người chưa bị trừ hết 12 điểm được phục hồi điểm giấy phép lái xe khi nào?",
    "Đã bị trừ hết điểm phải làm gì để phục hồi điểm giấy phép lái xe?",
    "Bị trừ điểm thì khi nào được phục hồi điểm giấy phép lái xe?",
])
def test_licence_point_restoration_uses_traffic_law_evidence(question):
    assert not QdrantTrafficStore._is_sanction_query(question)
    generator = TrafficRagGenerator()
    law = [{"chunk_id": "article-58", "document_number": "55/VBHN-VPQH",
            "article": "58", "clause": "2", "content": "Điều 58. Phục hồi điểm giấy phép lái xe."}]
    provider = Mock(return_value=SimpleNamespace(text=json.dumps({
        "status": "Answered", "answer": "Theo Điều 58 về phục hồi điểm.",
        "chunk_ids": ["article-58"]}),
        usage_metadata=SimpleNamespace(total_token_count=20)))
    generator._gemini_client = SimpleNamespace(generate_content=provider)
    answer, citations, _, verified = generator.generate(question, law)
    assert verified and citations[0]["article_number"] == "58"
    assert "phục hồi" in answer and provider.called


def test_driving_age_answer_requires_class_and_age_evidence():
    generator = TrafficRagGenerator()
    chunks = [
        {"chunk_id": "class-c1", "article": "57", "clause": "1",
         "content": "Điều 57. Hạng C1 cấp cho người lái xe ô tô tải trên 3.500 kg đến 7.500 kg."},
        {"chunk_id": "age-c1", "article": "59", "clause": "1",
         "content": "Điều 59. Người đủ 18 tuổi được cấp giấy phép lái xe hạng A1, A, B1, B, C1."},
    ]
    incomplete = Mock(return_value=SimpleNamespace(text=json.dumps({
        "status": "Answered", "answer": "18 tuổi, hạng C1 theo Điều 59.",
        "chunk_ids": ["age-c1"]}), usage_metadata=SimpleNamespace(total_token_count=40)))
    complete = Mock(return_value=SimpleNamespace(text=json.dumps({
        "status": "Answered", "answer": "18 tuổi, hạng C1 theo Điều 57 và 59.",
        "chunk_ids": ["class-c1", "age-c1"]}), usage_metadata=SimpleNamespace(total_token_count=41)))
    generator._gemini_client = SimpleNamespace(generate_content=incomplete)
    generator._gemini_fallback_client = SimpleNamespace(generate_content=complete)
    question = "Đủ bao nhiêu tuổi để được cấp giấy phép lái xe hạng C1?"
    result = generator.generate(question, chunks)
    assert {citation["chunk_id"] for citation in result[1]} == {"class-c1", "age-c1"}
    assert result[3]
    incomplete.assert_called_once()
    complete.assert_called_once()


def test_driving_age_abstains_when_vehicle_class_rule_is_missing():
    generator = TrafficRagGenerator()
    provider = Mock()
    generator._gemini_client = SimpleNamespace(generate_content=provider)
    result = generator.generate("Bao nhiêu tuổi được cấp giấy phép lái xe hạng C1?", [
        {"chunk_id": "age-c1", "article": "59", "clause": "1",
         "content": "Người đủ 18 tuổi được cấp giấy phép lái xe hạng C1."}])
    assert result == (generator.NO_MATCH_RESPONSE, [], 0, False)
    provider.assert_not_called()


def test_driving_age_infers_a1_and_b_evidence_from_vehicle_descriptions():
    generator = TrafficRagGenerator()
    chunks = [
        {"chunk_id": "classes", "article": "57", "clause": "1", "content":
         "Điều 57. Hạng A1 cấp cho người lái xe mô tô hai bánh đến 125 cm3; "
         "Hạng B cấp cho người lái ô tô chở người đến 8 chỗ, ô tô tải đến 3.500 kg."},
        {"chunk_id": "ages", "article": "59", "clause": "1", "content":
         "Điều 59. Người đủ 18 tuổi được cấp giấy phép lái xe hạng A1, A, B1, B, C1."},
    ]
    provider = Mock(return_value=SimpleNamespace(text=json.dumps({
        "status": "Answered", "answer": "18 tuổi theo Điều 57 và Điều 59.",
        "chunk_ids": ["classes", "ages"]}), usage_metadata=SimpleNamespace(total_token_count=40)))
    generator._gemini_client = SimpleNamespace(generate_content=provider)
    question = ("Bao nhiêu tuổi được cấp giấy phép lái xe mô tô hai bánh đến 125 cm3 "
                "và ô tô chở người đến 8 chỗ, ô tô tải đến 3.500 kg?")
    answer, citations, _, verified = generator.generate(question, chunks)
    assert verified and "18 tuổi" in answer
    assert {citation["article_number"] for citation in citations} == {"57", "59"}
    provider.assert_called_once()


def test_compound_age_question_fetches_both_verified_class_rules_beyond_vector_top_five():
    service = TrafficRagInferenceServicer.__new__(TrafficRagInferenceServicer)
    service.moderation_engine = SimpleNamespace(check=lambda _: (False, [], ''))
    base = {'document_id': 'law', 'document_number': '55/VBHN-VPQH', 'is_verified': True,
            'is_active': True}
    age = dict(base, chunk_id='age', article='59', clause='1', point='b',
               content='Người đủ 18 tuổi được cấp giấy phép lái xe hạng A1 và hạng B.')
    car = dict(base, chunk_id='class-b', article='57', clause='1', point='d',
               content='Hạng B cấp cho người lái ô tô chở người đến 8 chỗ, xe tải đến 3.500 kg.')
    motor = dict(base, chunk_id='class-a1', article='57', clause='1', point='a',
                 content='Hạng A1 cấp cho người lái xe mô tô hai bánh đến 125 cm3.')
    service.vector_store = SimpleNamespace(search_verified_chunks=lambda *a, **k: [age, car],
                                           get_verified_article_chunks=lambda _, article:
                                           [motor, car] if article == '57' else [age])
    generate = Mock(return_value=('Không đủ căn cứ.', [], 0, False))
    service.rag_generator = SimpleNamespace(NO_MATCH_RESPONSE='Không đủ căn cứ.', generate=generate)
    question = ('Người đủ bao nhiêu tuổi được cấp giấy phép lái xe mô tô hai bánh đến 125 cm3 '
                'và xe ô tô chở người đến 8 chỗ, xe tải đến 3.500 kg?')
    service.ProcessChatMessage(chat_inference_pb2.ChatInferenceRequest(prompt=question),
                               SimpleNamespace(is_active=lambda: True))
    assert {row['chunk_id'] for row in generate.call_args.args[1]} == {'age', 'class-b', 'class-a1'}


def test_gemini_fallback_uses_same_grounded_ids_after_transient_provider_error():
    import io
    from urllib.error import HTTPError
    generator = TrafficRagGenerator()
    primary = Mock(side_effect=HTTPError('https://provider.example', 503, 'unavailable', {}, io.BytesIO()))
    fallback = Mock(return_value=SimpleNamespace(text=json.dumps({"status": "Answered",
        "answer": "Theo Điều 11.", "chunk_ids": ["reviewed"]}),
        usage_metadata=SimpleNamespace(total_token_count=42)))
    generator._gemini_client = SimpleNamespace(generate_content=primary)
    generator._gemini_fallback_client = SimpleNamespace(generate_content=fallback)
    result = generator.generate("Quy tắc?", [{"chunk_id": "reviewed", "content": "Quy tắc đã xác thực."}])
    assert result[0] == "Theo Điều 11." and result[1][0]["chunk_id"] == "reviewed"
    assert result[2:] == (42, True)
    primary.assert_called_once()
    fallback.assert_called_once()
    assert primary.call_args.kwargs["response_schema"] == fallback.call_args.kwargs["response_schema"]


def test_groq_key_rotation_on_rate_limit_preserves_grounding():
    class RateLimited(Exception):
        status_code = 429
    generator = TrafficRagGenerator()
    first = Mock(side_effect=RateLimited())
    second = Mock(return_value=SimpleNamespace(choices=[SimpleNamespace(message=SimpleNamespace(
        content=json.dumps({"status": "Answered", "answer": "Theo Điều 10.",
                            "chunk_ids": ["reviewed"]})))], usage=SimpleNamespace(total_tokens=48)))
    generator._groq_clients = [SimpleNamespace(chat=SimpleNamespace(completions=SimpleNamespace(create=first))),
                               SimpleNamespace(chat=SimpleNamespace(completions=SimpleNamespace(create=second)))]
    chunks = [{"chunk_id": "reviewed", "content": "Quy tắc tại Điều 10."}]
    result = generator.generate("Quy tắc?", chunks)
    assert result[0] == "Theo Điều 10." and result[1][0]["chunk_id"] == "reviewed"
    assert result[2:] == (48, True)
    generator.generate("Quy tắc?", chunks)
    assert first.call_count == 1 and second.call_count == 2


def test_groq_exhaustion_falls_back_to_grounded_gemini():
    class RateLimited(Exception):
        status_code = 429
    generator = TrafficRagGenerator()
    failed = [Mock(side_effect=RateLimited()) for _ in range(3)]
    generator._groq_clients = [SimpleNamespace(chat=SimpleNamespace(
        completions=SimpleNamespace(create=call))) for call in failed]
    fallback = Mock(return_value=SimpleNamespace(text=json.dumps({"status": "Answered",
        "answer": "Theo Điều 10.", "chunk_ids": ["reviewed"]}),
        usage_metadata=SimpleNamespace(total_token_count=62)))
    generator._gemini_client = SimpleNamespace(generate_content=fallback)
    result = generator.generate("Quy tắc?", [{"chunk_id": "reviewed", "content": "Quy tắc tại Điều 10."}])
    assert result[0] == "Theo Điều 10." and result[1][0]["chunk_id"] == "reviewed"
    assert result[2:] == (62, True)
    assert all(call.call_count == 1 for call in failed)
    fallback.assert_called_once()


def test_gemini_embeddings_use_query_document_tasks_and_validate_batch(monkeypatch):
    import io
    import rag.embeddings as module
    for key, value in {"EMBEDDING_PROVIDER": "gemini", "EMBEDDING_API_KEY": "fixture",
                       "EMBEDDING_MODEL": "gemini-embedding-001", "EMBEDDING_DIMENSION": "3"}.items():
        monkeypatch.setenv(key, value)
    tasks = []
    def respond(request, **kwargs):
        body = json.loads(request.data)
        assert 'fixture' not in request.full_url
        assert len(body['requests']) <= 100
        tasks.extend(row['taskType'] for row in body['requests'])
        return io.StringIO(json.dumps({'embeddings': [{'values': [1, 0, 0]} for _ in body['requests']]}))
    monkeypatch.setattr(module, 'urlopen', respond)
    engine = EmbeddingEngine()
    assert len(engine.embed_documents(['document'] * 101)) == 101
    assert engine.embed_query('query') == [1, 0, 0]
    assert tasks == ['RETRIEVAL_DOCUMENT'] * 101 + ['RETRIEVAL_QUERY']
    monkeypatch.setattr(module, 'urlopen', lambda *a, **kw: io.StringIO('{"embeddings":[]}'))
    with pytest.raises(RuntimeError, match="incomplete batch"):
        engine.embed_query('query')


def test_long_citation_excerpt_is_an_exact_source_substring():
    generator = TrafficRagGenerator()
    generator._gemini_client = SimpleNamespace(generate_content=lambda *a, **kw: SimpleNamespace(
        text=json.dumps({'status': 'Answered', 'answer': 'Fixture', 'chunk_ids': ['long']}),
        usage_metadata=SimpleNamespace(total_token_count=10)))
    content = 'Current legal source words. ' * 30
    _, citations, _, _ = generator.generate('fixture', [{'chunk_id': 'long', 'content': content}])
    assert len(citations[0]['excerpt']) == 250
    assert citations[0]['excerpt'] in content


def test_interrupted_index_resumes_without_reembedding_acknowledged_points():
    embedding = FixtureEmbedding()
    calls = []
    def embed(texts):
        calls.append(list(texts))
        if len(calls) == 2:
            raise RuntimeError('provider rate limited')
        return [[1.0, 0.0, 0.0] for _ in texts]
    embedding.embed_documents = embed
    store = QdrantTrafficStore(embedding, client=QdrantClient(':memory:'))
    chunks = [{'chunk_id': f'id-{i}', 'content': f'content-{i}', 'is_verified': True, 'is_active': True} for i in range(65)]
    with pytest.raises(RuntimeError, match='rate limited'):
        store.upsert_chunks(chunks)
    assert store._client.count(store.COLLECTION_NAME).count == 8
    assert store.upsert_chunks(chunks) == 65
    assert store._client.count(store.COLLECTION_NAME).count == 65
    assert all('content-0' not in batch for batch in calls[1:])


def test_edition_metadata_reuses_vector_when_content_unchanged():
    embedding = FixtureEmbedding()
    calls = []
    original = embedding.embed_documents
    def record(texts):
        calls.extend(texts)
        return original(texts)
    embedding.embed_documents = record
    store = QdrantTrafficStore(embedding, client=QdrantClient(':memory:'))
    old = [{'chunk_id': 'old', 'document_number': '55/VBHN-VPQH', 'document_version': '2',
            'content': 'unchanged legal text', 'is_verified': True, 'is_active': True}]
    store.upsert_chunks(old)
    store.deactivate_document('55/VBHN-VPQH')
    updated = [{**old[0], 'document_version': '3'},
               {'chunk_id': 'new', 'document_number': '55/VBHN-VPQH', 'document_version': '3',
                'content': 'new legal text', 'is_verified': True, 'is_active': True}]
    store.upsert_chunks(updated)
    assert calls == ['unchanged legal text', 'new legal text']
    points = store._client.retrieve(store.COLLECTION_NAME,
        [store.chunk_id_to_point_id('old'), store.chunk_id_to_point_id('new')], with_payload=True)
    assert all(p.payload['document_version'] == '3' and p.payload['is_active'] for p in points)


def test_gemini_counts_context_before_generation_and_honors_reservation(monkeypatch):
    import io
    import rag.gemini_api as module
    calls = []
    def respond(request, **kwargs):
        calls.append(request)
        if request.full_url.endswith(':countTokens'):
            return io.StringIO('{"totalTokens":100}')
        body = json.loads(request.data)
        assert body['generationConfig']['maxOutputTokens'] == 68
        assert 'thinkingConfig' not in body['generationConfig']
        assert 'fixture-key' not in request.full_url
        return io.StringIO(json.dumps({'candidates':[{'content':{'parts':[{'text':'fixture'}]}}],
                                      'usageMetadata':{'totalTokenCount':130}}))
    monkeypatch.setattr(module, 'urlopen', respond)
    model = module.GeminiModel('fixture-key','gemini-2.5-flash')
    assert model.generate_content('fixture',token_budget=200).usage_metadata.total_token_count == 130
    calls.clear()
    with pytest.raises(RuntimeError,match='reserved token budget'):
        model.generate_content('fixture',token_budget=150)
    assert len(calls) == 1 and calls[0].full_url.endswith(':countTokens')


def test_chat_v2_preserves_wire_tags_and_unknown_usage():
    from server import TrafficRagInferenceServicer
    import chat_inference_pb2 as proto
    assert proto.CitationDto.DESCRIPTOR.fields_by_name["content_hash"].number == 7
    assert proto.CitationDto.DESCRIPTOR.fields_by_name["point_number"].number == 8
    assert proto.ChatInferenceResponse.DESCRIPTOR.fields_by_name["result_status"].number == 7
    assert not TrafficRagInferenceServicer._response("fixture", tokens=-1).HasField("tokens_used")
    response = TrafficRagInferenceServicer._response("fixture", tokens=0, status="Blocked")
    assert response.contract_version == 2 and response.result_status == "Blocked"
    assert response.HasField("tokens_used") and response.tokens_used == 0


def test_chat_v2_processes_history_and_images_with_citation_hash():
    from server import TrafficRagInferenceServicer
    import chat_inference_pb2 as proto
    service = TrafficRagInferenceServicer.__new__(TrafficRagInferenceServicer)
    service.moderation_engine = ModerationEngine()
    service.vision_engine = SimpleNamespace(last_tokens=5, analyze_traffic_image=lambda *args: ("Scene", False, "fixture query"))
    service.vector_store = SimpleNamespace(search_verified_chunks=Mock(return_value=[{"content": "fixture"}]))
    service.rag_generator = SimpleNamespace(generate=Mock(return_value=("Fixture answer", [{"chunk_id": "fixture-id",
        "content_hash": "a" * 64, "point_number": "a"}], 10, True)))
    request = proto.ChatInferenceRequest(prompt="fixture", images=[proto.ChatImage(content=b"fixture", mime_type="image/png")],
        history=[proto.HistoryItem(role="user", content="previous")])
    response = service.ProcessChatMessage(request, SimpleNamespace(is_active=lambda: True))
    assert response.contract_version == 2 and response.images_processed
    assert response.tokens_used == 15 and response.citations[0].content_hash == "a" * 64
    retrieval = service.vector_store.search_verified_chunks.call_args.args[0]
    assert "previous" not in retrieval and "Scene" not in retrieval
    assert "fixture query" in retrieval and "fixture" in retrieval
    assert "previous" in service.rag_generator.generate.call_args.args[0]
    assert "Scene" in service.rag_generator.generate.call_args.args[0]
    assert service.rag_generator.generate.call_args.kwargs["current_question"] == request.prompt
    assert service.rag_generator.generate.call_args.kwargs["prefer_gemini"] is True


@pytest.mark.parametrize("observation", [
    "Xe A trước vạch dừng; chưa xác định chính xác xe nào đã vào nơi giao nhau trong ảnh tĩnh.",
    "Xe cứu thương bật đèn ưu tiên; xe A và B ở gần vạch dừng.",
])
def test_uncertain_junction_entry_does_not_guess_vehicle_order(observation):
    service = TrafficRagInferenceServicer.__new__(TrafficRagInferenceServicer)
    service.moderation_engine = ModerationEngine()
    service.vision_engine = SimpleNamespace(last_tokens=5, analyze_traffic_image=lambda *args: (
        observation, False, "quy tắc nhường đường"))
    service.vector_store = SimpleNamespace(search_verified_chunks=Mock())
    service.rag_generator = SimpleNamespace(generate=Mock())
    request = chat_inference_pb2.ChatInferenceRequest(prompt="Thứ tự các xe đi thế nào?",
        images=[chat_inference_pb2.ChatImage(content=b"fixture", mime_type="image/jpeg")])
    result = service.ProcessChatMessage(request, SimpleNamespace(is_active=lambda: True))
    assert result.result_status == "NeedsClarification" and not result.citations
    service.vector_store.search_verified_chunks.assert_not_called()
    service.rag_generator.generate.assert_not_called()


def test_image_retrieval_retries_with_question_when_visual_query_misses():
    from server import TrafficRagInferenceServicer
    import chat_inference_pb2 as proto
    service = TrafficRagInferenceServicer.__new__(TrafficRagInferenceServicer)
    service.moderation_engine = ModerationEngine()
    service.vision_engine = SimpleNamespace(last_tokens=5, analyze_traffic_image=lambda *args: (
        "Vạch và biển chỉ làn", False, "mô tả ảnh quá dài"))
    search = Mock(side_effect=[[], [{"chunk_id": "law", "content": "Quy tắc báo hiệu"}]])
    service.vector_store = SimpleNamespace(search_verified_chunks=search)
    service.rag_generator = SimpleNamespace(generate=Mock(return_value=(
        "Trả lời có căn cứ", [{"chunk_id": "law"}], 10, True)))
    question = "Phải chấp hành biển báo và vạch kẻ đường thế nào?"
    request = proto.ChatInferenceRequest(prompt=question, images=[proto.ChatImage(
        content=b"fixture", mime_type="image/png")])
    response = service.ProcessChatMessage(request, SimpleNamespace(is_active=lambda: True))
    assert response.result_status == "Answered"
    assert search.call_count == 2
    assert search.call_args_list[0].args[0] != question
    assert search.call_args_list[1].args[0] == question
    assert service.rag_generator.generate.call_args.args[1][0]["chunk_id"] == "law"
