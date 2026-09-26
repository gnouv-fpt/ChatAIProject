# Vietnam Traffic Law gRPC Inference & Verification Service

Dịch vụ AI kiểm duyệt độc hại & sinh câu trả lời RAG kèm xác thực hiệu lực văn bản pháp luật giao thông đường bộ Việt Nam.

Phụ trách: **Khôi (PRN232)**

---

## 1. Tính năng cốt lõi (Core Features)

1. **Protobuf Contract (`protos/chat_inference.proto`):**
   - RPC `ProcessChatMessage(ChatInferenceRequest) returns (ChatInferenceResponse)`
   - RPC `VerifyLegalDocument(VerificationRequest) returns (VerificationResponse)`
   - RPC `IndexDocument(IndexDocumentRequest) returns (IndexDocumentResponse)`

2. **Moderation Engine (`moderation/moderation_engine.py`):**
   - Phát hiện ngôn từ xúc phạm, tiêu cực.
   - Phát hiện các yêu cầu vi phạm pháp luật / né tránh chế tài (hối lộ CSGT, biển số giả, thông chốt, đua xe trái phép...).
   - Trả về cờ `is_violation = True` và danh sách `violation_keywords` để hệ thống trừ token và gửi email cảnh báo.

3. **Data Verification Engine (`verification/verification_engine.py`):**
   - Kiểm tra xác thực hiệu lực của văn bản quy phạm pháp luật (NĐ 100/2019/NĐ-CP, NĐ 123/2021/NĐ-CP, Luật GTĐB).
   - Nhận diện văn bản hết hiệu lực hoặc bị thay thế (NĐ 46/2016/NĐ-CP, NĐ 171/2013/NĐ-CP).
   - Đảm bảo cơ chế lọc vector chỉ truy xuất các chunk có `is_verified == True` và `is_active == True`.

4. **Vector Store & Qdrant Integration (`rag/vector_store.py`):**
   - Kết nối Qdrant Server (Docker hoặc local).
   - Tự động fallback sang embedded Qdrant/in-memory nếu Qdrant server chưa khởi chạy, giúp test được ngay lập tức.
   - Lưu trữ metadata chi tiết: Điều, Khoản, Điểm, Văn bản, Trích dẫn gốc, Source URL.

5. **AI RAG Generator & Citations (`rag/rag_generator.py`):**
   - Chống ảo giác (No Hallucination): Trả lời chính xác câu tiêu chuẩn nếu không tìm thấy căn cứ pháp lý:
     *"Hiện tại hệ thống chưa tìm thấy quy định pháp lý tương ứng trong các văn bản giao thông đã được xác thực."*
   - Tích hợp Gemini 1.5 Flash (khi có `GOOGLE_API_KEY`) hoặc bộ tổng hợp pháp lý thông minh offline.
   - Trích xuất đầy đủ nguồn tham khảo (Citations) Thư viện pháp luật.

---

## 2. Hướng dẫn chạy và kiểm thử

### Cài đặt thư viện:
```bash
pip install -r requirements.txt
```

### Biên dịch Protobuf (nếu sửa file proto):
```bash
python generate_protos.py
```

### Khởi chạy gRPC Server:
```bash
python server.py
```
Server sẽ chạy mặc định tại cổng `50051` và tự động index dữ liệu luật giao thông mẫu.

### Chạy kiểm thử tự động (Client Test):
Mở một terminal khác và chạy:
```bash
python client_test.py
```

---

## 3. Biến môi trường (Environment Variables)

- `GRPC_PORT`: Cổng chạy gRPC server (mặc định: `50051`).
- `QDRANT_HOST`: Host Qdrant (mặc định: `localhost`, trong Docker Compose: `qdrant`).
- `QDRANT_PORT`: Cổng Qdrant (mặc định: `6333`).
- `GOOGLE_API_KEY`: API Key Gemini (tuỳ chọn, dùng cho mô hình sinh ngôn ngữ tự nhiên nâng cao).
