# Vietnam Traffic Law gRPC Inference & Verification Service

Dịch vụ AI kiểm duyệt độc hại, Advanced RAG, Vision OCR, và xác thực hiệu lực văn bản pháp luật giao thông đường bộ Việt Nam.

Phụ trách: **Khôi (PRN232)** — Scope Tasks: **K01 → K06** ([IMPLEMENTATION-PLAN.md](../docs/IMPLEMENTATION-PLAN.md)).

---

## 1. Tính năng cốt lõi (Core Features)

1. **Protobuf Contract (`Protos/chat_inference.proto`):**
   - RPC `ProcessChatMessage(ChatInferenceRequest) returns (ChatInferenceResponse)`
   - RPC `ProcessImageChatMessage(ImageChatInferenceRequest) returns (ChatInferenceResponse)`
   - RPC `VerifyLegalDocument(VerificationRequest) returns (VerificationResponse)`
   - RPC `IndexDocument(IndexDocumentRequest) returns (IndexDocumentResponse)`
   - RPC `DeactivateDocument(DeactivateDocumentRequest) returns (DeactivateDocumentResponse)`
   - RPC `ExplainQuestion(ExplainQuestionRequest) returns (ExplainQuestionResponse)`

2. **Groq RAG Generator (`rag/rag_generator.py`) — K01:**
   - Tích hợp Groq API (`llama-3.3-70b-versatile`) làm engine sinh câu trả lời pháp lý chuẩn xác.
   - Cơ chế Retry và Deadline tự động.
   - Quản lý token usage chính xác (ghi nhận `-1` nếu unknown).
   - Zero-Hallucination: Khi không có căn cứ pháp lý đã xác thực, trả lời câu chuẩn theo `requirement.md`:
     *"Hiện tại hệ thống chưa tìm thấy quy định pháp lý tương ứng trong các văn bản giao thông đã được xác thực."*

3. **Embedding API & Vector Store (`rag/embeddings.py`, `rag/vector_store.py`) — K02 & K04:**
   - Đảm bảo đồng nhất không gian vector (dimension 384d mặc định hoặc 768d cấu hình) giữa Indexing và Querying.
   - Lưu trữ và truy vấn trên **Qdrant Vector Database**.
   - Hỗ trợ map point ID từ `chunk_id` một cách xác định (deterministic hashing) để tránh nhân đôi point khi reindex.
   - RPC `DeactivateDocument` hỗ trợ thu hồi tức thì quyền tham gia RAG của văn bản/chunk mà không xóa vĩnh viễn dữ liệu.

4. **Data Verification Engine (`verification/verification_engine.py`) — K03:**
   - Xác thực văn bản quy phạm pháp luật dựa trên ngày hết hiệu lực và quan hệ sửa đổi/bổ sung (NĐ 123/2021 sửa đổi NĐ 100/2019, NĐ 46/2016 hết hiệu lực toàn bộ).
   - Trạng thái chưa rõ mặc định rơi vào `Pending` (không đủ điều kiện tham gia RAG retrieval).

5. **Traffic Vision & OCR Engine (`rag/vision_engine.py`) — K05:**
   - Phân tích ảnh vi phạm giao thông / biển báo đường bộ qua Multimodal API.
   - Nhận diện ảnh mờ, tối, hoặc bị cắt mất dữ kiện quan trọng -> trả về `requires_clarification = True` và yêu cầu người dùng cung cấp ảnh rõ ràng hơn; tách biệt quan sát hiện trường khỏi căn cứ pháp lý.

6. **Giải thích câu hỏi ôn thi / ngân hàng đề (`server.py`) — K06:**
   - RPC `ExplainQuestion`: Kết hợp đáp án chuẩn (Answer Key do Phúc/Khánh cung cấp) với căn cứ luật từ Qdrant để giải thích chi tiết lý do. Không chấm điểm bằng LLM.

---

## 2. Hướng dẫn chạy và kiểm thử

### Cài đặt thư viện:
```bash
pip install -r requirements.txt
```

### Biên dịch Protobuf:
```bash
python generate_protos.py
```

### Khởi chạy gRPC Server:
```bash
python server.py
```
Server chạy mặc định tại cổng `50051`.

### Chạy kiểm thử tự động (Client Test Suite):
```bash
python client_test.py
```
Test suite kiểm thử đầy đủ 8 trường hợp:
1. Hỏi đáp pháp luật hợp lệ (vượt đèn đỏ).
2. Kiểm duyệt vi phạm / ngôn từ hối lộ.
3. Chống ảo giác (câu hỏi ngoài luật giao thông).
4. Xử lý ảnh mờ / thiếu dữ kiện.
5. Phân tích ảnh hiện trường hợp lệ & tra cứu luật.
6. Xác thực hiệu lực văn bản (NĐ 123 vs NĐ 46 vs văn bản lạ).
7. Thu hồi/deactivate văn bản khỏi retrieval.
8. Giải thích đáp án câu hỏi thi trắc nghiệm.

---

## 3. Biến môi trường (Environment Variables)

- `GRPC_PORT`: Cổng chạy gRPC server (mặc định: `50051`).
- `GROQ_API_KEY`: API Key Groq cho LLM Generation.
- `GROQ_MODEL`: Mô hình Groq (mặc định: `llama-3.3-70b-versatile`).
- `GOOGLE_API_KEY`: API Key Gemini (cho Vision và Fallback).
- `QDRANT_HOST`: Host Qdrant (mặc định: `localhost`, Docker: `qdrant`).
- `QDRANT_PORT`: Cổng Qdrant (mặc định: `6333`).
- `EMBEDDING_DIMENSION`: Chiều vector embedding (mặc định: `384`).
