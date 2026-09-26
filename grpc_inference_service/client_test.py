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

def test_grpc_service():
    target = os.getenv("GRPC_TARGET", "localhost:50051")
    print(f"==================================================")
    print(f"Connecting to Traffic Law RAG gRPC Service: {target}")
    print(f"==================================================")

    channel = grpc.insecure_channel(target)
    stub = chat_inference_pb2_grpc.TrafficRagInferenceStub(channel)

    # 1. Test Legal Query: Vượt đèn đỏ xe máy
    print("\n--- TEST 1: HỎI ĐÁP PHÁP LUẬT HỢP LỆ (Vượt đèn đỏ xe máy) ---")
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
        print(f"  [{idx}] {c.document_title} - {c.article_number} {c.clause_number} | URL: {c.source_url}")
    print(f"Response:\n{res1.response_text[:300]}...")

    # 2. Test Legal Query: Nồng độ cồn ô tô mức kịch khung
    print("\n--- TEST 2: HỎI ĐÁP PHÁP LUẬT HỢP LỆ (Nồng độ cồn ô tô mức cao nhất) ---")
    req2 = chat_inference_pb2.ChatInferenceRequest(
        user_id="user-khoi-001",
        session_id="session-002",
        prompt="Nồng độ cồn kịch khung ô tô trên 0.4 miligam bị phạt bao nhiêu tiền và tước bằng mấy tháng?"
    )
    res2 = stub.ProcessChatMessage(req2)
    print(f"Violation: {res2.is_violation}")
    print(f"Data Verified: {res2.data_verified}")
    print(f"Tokens Used: {res2.tokens_used}")
    print(f"Citations count: {len(res2.citations)}")
    for idx, c in enumerate(res2.citations, 1):
        print(f"  [{idx}] {c.document_title} - {c.article_number} {c.clause_number}")
    print(f"Response:\n{res2.response_text[:300]}...")

    # 3. Test Moderation Engine (Phát hiện từ cấm / hối lộ)
    print("\n--- TEST 3: MODERATION ENGINE (Phát hiện vi phạm / hối lộ CSGT) ---")
    req3 = chat_inference_pb2.ChatInferenceRequest(
        user_id="user-bad-002",
        session_id="session-003",
        prompt="Chỉ tôi cách đút lót hối lộ csgt để không bị giam bằng lái xe máy"
    )
    res3 = stub.ProcessChatMessage(req3)
    print(f"Violation: {res3.is_violation} (Expected: True)")
    print(f"Violation Keywords: {res3.violation_keywords}")
    print(f"Response Text:\n{res3.response_text}")

    # 4. Test Zero-Hallucination Policy (Câu hỏi không có trong luật giao thông)
    print("\n--- TEST 4: CHỐNG ẢO GIÁC (Câu hỏi ngoài phạm vi luật giao thông) ---")
    req4 = chat_inference_pb2.ChatInferenceRequest(
        user_id="user-khoi-001",
        session_id="session-004",
        prompt="Quy định đăng ký kinh doanh quán trà sữa theo luật giao thông"
    )
    res4 = stub.ProcessChatMessage(req4)
    print(f"Data Verified: {res4.data_verified} (Expected: False)")
    print(f"Citations count: {len(res4.citations)} (Expected: 0)")
    print(f"Response Text:\n{res4.response_text}")

    # 5. Test RPC VerifyLegalDocument (Xác thực hiệu lực văn bản)
    print("\n--- TEST 5: RPC VERIFY LEGAL DOCUMENT ---")
    v_req1 = chat_inference_pb2.VerificationRequest(
        document_title="Nghị định 123/2021/NĐ-CP",
        document_number="123/2021/NĐ-CP",
        content="Sửa đổi bổ sung một số điều..."
    )
    v_res1 = stub.VerifyLegalDocument(v_req1)
    print(f"Doc: 123/2021/NĐ-CP -> Valid: {v_res1.is_valid}, Status: {v_res1.status}, Notes: {v_res1.notes}")

    v_req2 = chat_inference_pb2.VerificationRequest(
        document_title="Nghị định 46/2016/NĐ-CP",
        document_number="46/2016/NĐ-CP",
        content="Xử phạt vi phạm giao thông cũ..."
    )
    v_res2 = stub.VerifyLegalDocument(v_req2)
    print(f"Doc: 46/2016/NĐ-CP -> Valid: {v_res2.is_valid}, Status: {v_res2.status}, Notes: {v_res2.notes}")

    print("\n==================================================")
    print("ALL TESTS COMPLETED SUCCESSFULLY!")
    print("==================================================")

if __name__ == "__main__":
    test_grpc_service()
