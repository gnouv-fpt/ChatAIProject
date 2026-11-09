import pytest
import os
import sys
import json
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
