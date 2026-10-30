import pytest
import os
import sys

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
    embedding = EmbeddingEngine()
    store = QdrantTrafficStore(embedding_engine=embedding)
    
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
