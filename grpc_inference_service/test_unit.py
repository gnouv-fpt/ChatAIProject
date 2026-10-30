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
    for name in ("GROQ_API_KEY", "GOOGLE_API_KEY", "GEMINI_API_KEY", "EMBEDDING_API_KEY"):
        monkeypatch.delenv(name, raising=False)


class FixtureEmbedding:
    DIMENSION = 3
    def embed_documents(self, texts):
        return [[1.0, 0.0, 0.0] for _ in texts]
    def embed_query(self, text):
        return self.embed_documents([text])[0]


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
    res1 = engine.verify_document("Nghị định 123/2021/NĐ-CP", "123/2021/NĐ-CP")
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

# ==============================================================================
# 4. TEST RAG GENERATOR & ZERO HALLUCINATION
# ==============================================================================
def test_rag_generator_zero_hallucination():
    generator = TrafficRagGenerator()
    completion = SimpleNamespace(choices=[SimpleNamespace(message=SimpleNamespace(content="Fixture answer: Điều 6"))],
        usage=SimpleNamespace(total_tokens=42))
    generator._groq_client = SimpleNamespace(chat=SimpleNamespace(completions=SimpleNamespace(create=Mock(return_value=completion))))

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


def test_no_synthetic_provider_or_vector_fallback(monkeypatch):
    import rag.vector_store as module
    monkeypatch.setattr(module, "QdrantClient", Mock(side_effect=ConnectionError("Qdrant down")))
    with pytest.raises(ConnectionError):
        QdrantTrafficStore(FixtureEmbedding())
    with pytest.raises(RuntimeError, match="Generation API unavailable"):
        TrafficRagGenerator().generate("question", [{"chunk_id": "fixture", "content": "fixture"}])
    with pytest.raises(RuntimeError, match="Vision API unavailable"):
        TrafficVisionEngine().analyze_traffic_image("aW1hZ2U=", "image/png", "fixture")


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
    service.rag_generator = SimpleNamespace(generate=lambda *args: ("Fixture answer", [{"chunk_id": "fixture-id",
        "content_hash": "a" * 64, "point_number": "a"}], 10, True))
    request = proto.ChatInferenceRequest(prompt="fixture", images=[proto.ChatImage(content=b"fixture", mime_type="image/png")],
        history=[proto.HistoryItem(role="user", content="previous")])
    response = service.ProcessChatMessage(request, SimpleNamespace(is_active=lambda: True))
    assert response.contract_version == 2 and response.images_processed
    assert response.tokens_used == 15 and response.citations[0].content_hash == "a" * 64
    assert "previous" in service.vector_store.search_verified_chunks.call_args.args[0]
