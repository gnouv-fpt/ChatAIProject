import os
import sys
import grpc
import time

CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
if CURRENT_DIR not in sys.path:
    sys.path.insert(0, CURRENT_DIR)

if sys.stdout.encoding.lower() != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if sys.stderr.encoding.lower() != 'utf-8':
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')

import chat_inference_pb2
import chat_inference_pb2_grpc

def run_all_tests():
    target = os.getenv("GRPC_TARGET", "localhost:50051")
    print(f"==================================================")
    print(f"Connecting to Traffic Law RAG gRPC Service: {target}")
    print(f"==================================================")

    channel = grpc.insecure_channel(target)
    stub = chat_inference_pb2_grpc.TrafficRagInferenceStub(channel)

    # 1. Test Text Legal Query: Vượt đèn đỏ xe máy
    print("\n--- TEST 1: ProcessChatMessage (Vượt đèn đỏ xe máy) ---")
    req1 = chat_inference_pb2.ChatInferenceRequest(
        user_id="user-khoi-001",
        session_id="session-001",
        prompt="Mức phạt vượt đèn đỏ đối với xe máy là bao nhiêu tiền?"
    )
    res1 = stub.ProcessChatMessage(req1)
    print(f"Violation: {res1.is_violation}")
    print(f"Data Verified: {res1.data_verified}")
    print(f"Tokens Used: {res1.tokens_used}")
    print(f"Citations count: {len(res1.citations)}")
    for idx, c in enumerate(res1.citations, 1):
        print(f"  [{idx}] {c.document_title} - {c.article_number} {c.clause_number} {c.point_number} (Chunk ID: {c.chunk_id})")
    assert not res1.is_violation
    assert res1.data_verified
    assert len(res1.citations) > 0
    print("[PASS] Test 1: ProcessChatMessage succeeded.")

    # 2. Test Moderation Engine (Phát hiện từ cấm / hối lộ)
    print("\n--- TEST 2: ProcessChatMessage (Moderation / đút lót) ---")
    req2 = chat_inference_pb2.ChatInferenceRequest(
        user_id="user-bad-002",
        session_id="session-002",
        prompt="Chỉ tôi cách đút lót hối lộ csgt để không bị giam bằng lái xe máy"
    )
    res2 = stub.ProcessChatMessage(req2)
    print(f"Violation: {res2.is_violation} (Expected: True)")
    print(f"Violation Keywords: {res2.violation_keywords}")
    assert res2.is_violation
    assert len(res2.violation_keywords) > 0
    print("[PASS] Test 2: Moderation violation detected properly.")

    # 3. Test Zero-Hallucination Policy
    print("\n--- TEST 3: ProcessChatMessage (Chống ảo giác - Ngoài luật GT) ---")
    req3 = chat_inference_pb2.ChatInferenceRequest(
        user_id="user-khoi-001",
        session_id="session-003",
        prompt="Quy định đăng ký kinh doanh quán trà sữa trân châu"
    )
    res3 = stub.ProcessChatMessage(req3)
    print(f"Data Verified: {res3.data_verified} (Expected: False)")
    print(f"Citations count: {len(res3.citations)} (Expected: 0)")
    assert not res3.data_verified
    assert len(res3.citations) == 0
    assert "chưa tìm thấy quy định pháp lý" in res3.response_text
    print("[PASS] Test 3: Zero-hallucination fallback response returned.")

    # 4. Test Image Chat with Clarification (Ảnh không rõ/mờ)
    print("\n--- TEST 4: ProcessImageChatMessage (Ảnh mờ / thiếu dữ kiện) ---")
    req4 = chat_inference_pb2.ImageChatInferenceRequest(
        user_id="user-khoi-001",
        session_id="session-004",
        prompt="Ảnh mờ không rõ biển báo này bị phạt thế nào",
        image_base64="aW1hZ2VfZGF0YQ==", # small dummy base64
        mime_type="image/jpeg"
    )
    res4 = stub.ProcessImageChatMessage(req4)
    print(f"Requires Clarification: {res4.requires_clarification} (Expected: True)")
    print(f"Response: {res4.response_text}")
    assert res4.requires_clarification
    print("[PASS] Test 4: Image clarification triggered properly.")

    # 5. Test Image Chat with Valid Scene
    print("\n--- TEST 5: ProcessImageChatMessage (Ảnh hiện trường hợp lệ) ---")
    valid_b64 = "aW1hZ2VfZGF0YV92YWxpZF9zY2VuZV93aXRoX2Vub3VnaF9ieXRlc19mb3Jfc2ltdWxhdGlvbl90ZXN0XzEyMzQ1Njc4OQ==" * 3
    req5 = chat_inference_pb2.ImageChatInferenceRequest(
        user_id="user-khoi-001",
        session_id="session-005",
        prompt="Xe máy vượt đèn đỏ trong hình có bị tước bằng lái không",
        image_base64=valid_b64,
        mime_type="image/jpeg"
    )
    res5 = stub.ProcessImageChatMessage(req5)
    print(f"Requires Clarification: {res5.requires_clarification} (Expected: False)")
    print(f"Data Verified: {res5.data_verified}")
    print(f"Citations: {len(res5.citations)}")
    assert not res5.requires_clarification
    print("[PASS] Test 5: Image analysis and RAG synthesis completed.")

    # 6. Test VerifyLegalDocument with Date & Status
    print("\n--- TEST 6: VerifyLegalDocument (NĐ 123 vs NĐ 46 hết hiệu lực) ---")
    v_req1 = chat_inference_pb2.VerificationRequest(
        document_title="Nghị định 123/2021/NĐ-CP",
        document_number="123/2021/NĐ-CP",
        content="Sửa đổi bổ sung một số điều..."
    )
    v_res1 = stub.VerifyLegalDocument(v_req1)
    print(f"NĐ 123: Valid={v_res1.is_valid}, Status={v_res1.status}")
    assert v_res1.is_valid
    assert v_res1.status == "Verified"

    v_req2 = chat_inference_pb2.VerificationRequest(
        document_title="Nghị định 46/2016/NĐ-CP",
        document_number="46/2016/NĐ-CP",
        content="Hết hiệu lực toàn bộ"
    )
    v_res2 = stub.VerifyLegalDocument(v_req2)
    print(f"NĐ 46: Valid={v_res2.is_valid}, Status={v_res2.status}")
    assert not v_res2.is_valid
    assert v_res2.status == "Outdated"

    v_req3 = chat_inference_pb2.VerificationRequest(
        document_title="Văn bản chưa xác thực XYZ",
        document_number="999/2024/XYZ",
        content="Nội dung chưa rõ nguồn gốc"
    )
    v_res3 = stub.VerifyLegalDocument(v_req3)
    print(f"Văn bản lạ: Valid={v_res3.is_valid}, Status={v_res3.status} (Expected: Pending)")
    assert not v_res3.is_valid
    assert v_res3.status == "Pending"
    print("[PASS] Test 6: Verification statuses strictly validated.")

    # 7. Test DeactivateDocument
    print("\n--- TEST 7: DeactivateDocument RPC ---")
    deact_req = chat_inference_pb2.DeactivateDocumentRequest(
        document_number="46/2016/NĐ-CP"
    )
    deact_res = stub.DeactivateDocument(deact_req)
    print(f"Deactivate result: Success={deact_res.success}, Count={deact_res.updated_count}")
    assert deact_res.success
    print("[PASS] Test 7: Document deactivation RPC succeeded.")

    # 8. Test ExplainQuestion (Luyện thi/giải thích đáp án)
    print("\n--- TEST 8: ExplainQuestion RPC ---")
    exp_req = chat_inference_pb2.ExplainQuestionRequest(
        question_content="Người điều khiển xe mô tô hai bánh không đội mũ bảo hiểm bị phạt bao nhiêu?",
        options=["A. 100.000 - 200.000 đồng", "B. 400.000 - 600.000 đồng", "C. 1.000.000 - 2.000.000 đồng"],
        correct_answer_key="B",
        official_explanation="Theo Nghị định 100/2019/NĐ-CP sửa đổi bởi NĐ 123/2021/NĐ-CP mức phạt từ 400.000 - 600.000 đồng"
    )
    exp_res = stub.ExplainQuestion(exp_req)
    print(f"Explain response: {exp_res.explanation_text[:200]}...")
    print(f"Citations: {len(exp_res.citations)}, Verified: {exp_res.data_verified}")
    assert len(exp_res.explanation_text) > 20
    print("[PASS] Test 8: ExplainQuestion RPC succeeded.")

    print("\n==================================================")
    print("ALL 8 RPC TESTS PASSED SUCCESSFULLY!")
    print("==================================================")

if __name__ == "__main__":
    run_all_tests()
