# Tiến độ - Khôi (gRPC Service & Advanced RAG)

Nhánh: `feature/khoi-grpc-rag` (hoặc tích hợp trên `PRN-BAO-dev`)

## 1. Các hạng mục đã hoàn thành

### 1.1. Thiết kế Protobuf Contract (`Protos/chat_inference.proto`)
- [x] Tạo file proto dùng chung [Protos/chat_inference.proto](file:///c:/AK/HOCKI8/PRN232/Assignment/ChatAIProject/Protos/chat_inference.proto) (và bản sao trong [grpc_inference_service/protos/chat_inference.proto](file:///c:/AK/HOCKI8/PRN232/Assignment/ChatAIProject/grpc_inference_service/protos/chat_inference.proto)).
- [x] RPC `ProcessChatMessage(ChatInferenceRequest) returns (ChatInferenceResponse)`
- [x] RPC `VerifyLegalDocument(VerificationRequest) returns (VerificationResponse)`
- [x] RPC `IndexDocument(IndexDocumentRequest) returns (IndexDocumentResponse)`
- [x] Cấu hình namespace C# `BusinessLogic.Protos` để Vương và Phúc tích hợp gRPC Client vào Web API dễ dàng.

### 1.2. Xây dựng gRPC Inference Service độc lập (`grpc_inference_service/`)
- [x] Cấu trúc module sạch, chuẩn microservices:
  - `server.py`: gRPC server chạy đa luồng (ThreadPoolExecutor), lắng nghe port `50051`.
  - `generate_protos.py`: Script tự động biên dịch protobuf thành `_pb2.py` và `_pb2_grpc.py`.
  - `Dockerfile`: Đóng gói container độc lập sẵn sàng cho Docker Compose (`grpc-inference-service`).
  - `requirements.txt`: Dependencies được pin chuẩn (`grpcio`, `protobuf`, `qdrant-client`, `sentence-transformers>=2.6.0`, `numpy>=1.24.0,<2.0.0`, `google-generativeai`...).
  - `.gitignore`: Loại bỏ các file runtime không commit (`qdrant_storage/`, bytecode, generated pb2 files, `.env`).

### 1.3. Moderation Engine (`moderation/moderation_engine.py`)
- [x] Phát hiện ngôn từ tục tĩu, xúc phạm tiếng Việt.
- [x] Phát hiện yêu cầu vi phạm pháp luật / lách luật / tiêu cực trong giao thông: hối lộ CSGT, làm biển số giả, thông chốt, đua xe trái phép, mẹo trốn đo nồng độ cồn...
- [x] Trả về cờ `is_violation = True` và danh sách `violation_keywords` để REST API và Worker Service (Khánh) kích hoạt trừ quota & gửi email cảnh báo vi phạm.

### 1.4. Tích hợp Qdrant Vector Database (`rag/vector_store.py`)
- [x] Collection `traffic_law_documents` lưu trữ vector các điều khoản luật giao thông.
- [x] Hỗ trợ kết nối Qdrant remote/Docker server và tự động fallback sang in-memory Qdrant khi chạy local độc lập.
- [x] Tương thích cả `qdrant-client` 1.19+ (`query_points`) và các phiên bản cũ (`search`).
- [x] **Cơ chế lọc pháp lý nghiêm ngặt:** Bắt buộc điều kiện `is_verified == True` và `is_active == True` khi tìm kiếm tương đồng.
- [x] **Idempotent Point ID:** Băm SHA-256 `chunk_id` thành 64-bit int để đảm bảo không bị ghi đè/collision khi index lại.

### 1.5. Data Verification Engine (`verification/verification_engine.py`)
- [x] Tra cứu cơ sở dữ liệu pháp luật giao thông: Nghị định 100/2019/NĐ-CP, Nghị định 123/2021/NĐ-CP (sửa đổi NĐ 100), Luật GTĐB 2008, Luật TTATGTĐB 2024.
- [x] Nhận diện văn bản hết hiệu lực: Nghị định 46/2016/NĐ-CP, Nghị định 171/2013/NĐ-CP (đánh dấu `Outdated`, `is_active = False`).
- [x] Xử lý RPC `VerifyLegalDocument` để crawler (Phúc) và Admin kiểm tra tình trạng hiệu lực văn bản.

### 1.6. AI RAG Generator & Trích dẫn nguồn chuẩn xác (`rag/rag_generator.py`)
- [x] **Chính sách Không ảo giác (Zero-Hallucination):** Nếu câu hỏi không tìm thấy căn cứ pháp lý trong dữ liệu đã xác thực, trả lời câu chuẩn theo yêu cầu:
  > *"Hiện tại hệ thống chưa tìm thấy quy định pháp lý tương ứng trong các văn bản giao thông đã được xác thực."*
- [x] Trích dẫn chi tiết (`Citations`): Tên văn bản, Điều, Khoản, Điểm, Link nguồn Thư viện pháp luật (`thuvienphapluat.vn`), Trích dẫn gốc.
- [x] Hỗ trợ sinh câu trả lời bằng Gemini 1.5 Flash (khi có `GOOGLE_API_KEY`) hoặc bộ tổng hợp pháp lý thông minh offline.
- [x] Ước tính số token sử dụng (`tokens_used`) để truyền về hệ thống tính phí.

### 1.7. Bộ dữ liệu mẫu chuẩn Luật Giao thông (`data/seed_traffic_law.py`)
- [x] Tự động nạp 14 điều khoản quy định quan trọng:
  - Nồng độ cồn ô tô (3 mức: < 50mg, 50-80mg, > 80mg kịch khung).
  - Nồng độ cồn xe máy.
  - Vượt đèn đỏ/đèn vàng xe máy & ô tô (theo mức phạt mới của NĐ 123/2021).
  - Không đội mũ bảo hiểm (NĐ 123/2021 phạt 400k - 600k).
  - Sử dụng điện thoại di động khi lái xe ô tô & xe máy.
  - Chạy quá tốc độ quy định.
  - Đi ngược chiều / đường cao tốc.
  - Không có Giấy phép lái xe (GPLX).
  - 01 điều khoản hết hiệu lực mẫu từ Nghị định 46/2016 để kiểm thử bộ lọc Verification Engine.
- [x] **Idempotent Seeding (`server.py`):** Kiểm tra số lượng point hiện tại (`count > 0`), bỏ qua seed nếu database đã có sẵn data (hỗ trợ Docker persistent volume).

### 1.8. Xây dựng .NET gRPC Client hoàn chỉnh trong BusinessLogic (Hỗ trợ nhóm)
- [x] Cấu hình gRPC Client vào `BusinessLogic.csproj` (`Grpc.Net.Client`, `Grpc.Tools`, proto compilation).
- [x] Định nghĩa đầy đủ DTOs trung gian tại [BusinessLogic/DTOs/GrpcDtos.cs](file:///c:/AK/HOCKI8/PRN232/Assignment/ChatAIProject/BusinessLogic/DTOs/GrpcDtos.cs):
  - `ChatInferenceResultDto`, `CitationResultDto`
  - `VerificationResultDto`, `DocumentChunkInputDto`, `IndexDocumentResultDto`
- [x] Interface [IGrpcInferenceService](file:///c:/AK/HOCKI8/PRN232/Assignment/ChatAIProject/BusinessLogic/Services/Interfaces/IGrpcInferenceService.cs) bao phủ đủ **3 RPCs**:
  - `ProcessChatMessageAsync(...)`
  - `VerifyLegalDocumentAsync(...)`
  - `IndexDocumentAsync(...)`
- [x] Implementation [GrpcInferenceService](file:///c:/AK/HOCKI8/PRN232/Assignment/ChatAIProject/BusinessLogic/Services/Implementations/GrpcInferenceService.cs) gọi service Python và map sang DTOs sạch sẽ.
- [x] Đăng ký DI trong [Presentation/Program.cs](file:///c:/AK/HOCKI8/PRN232/Assignment/ChatAIProject/Presentation/Program.cs) và config endpoint tại [Presentation/appsettings.json](file:///c:/AK/HOCKI8/PRN232/Assignment/ChatAIProject/Presentation/appsettings.json).
- [x] Solution .NET biên dịch thành công: **0 Errors, 0 Warnings**.

---

## 2. Kết quả kiểm thử tự động (`client_test.py`)

Tất cả 5 test cases đã chạy và vượt qua 100%:
1. **Test 1 (Hỏi đáp hợp lệ - Vượt đèn đỏ xe máy):**
   - `Violation: False`, `Data Verified: True`, `Citations count: 3`.
   - Trích dẫn đúng: *Nghị định 100/2019/NĐ-CP (sửa đổi bởi Nghị định 123/2021/NĐ-CP) - Điều 6 Khoản 4 Điểm e*. Mức phạt: 800.000đ - 1.000.000đ.
2. **Test 2 (Hỏi đáp hợp lệ - Nồng độ cồn ô tô):**
   - `Violation: False`, `Data Verified: True`, `Citations count: 3`.
   - Trích dẫn đúng: *Nghị định 100/2019/NĐ-CP - Điều 5*.
3. **Test 3 (Moderation vi phạm - Hối lộ CSGT):**
   - `Violation: True`, `Violation Keywords: ['hối lộ', 'đút lót']`.
   - Phản hồi từ chối và cảnh báo ghi nhận nhật ký vi phạm an toàn.
4. **Test 4 (Chống ảo giác - Câu hỏi ngoài phạm vi luật giao thông):**
   - `Data Verified: False`, `Citations: 0`.
   - Trả về đúng câu yêu cầu: *"Hiện tại hệ thống chưa tìm thấy quy định pháp lý tương ứng trong các văn bản giao thông đã được xác thực."*
5. **Test 5 (RPC VerifyLegalDocument):**
   - NĐ 123/2021/NĐ-CP: `Valid: True`, `Status: Verified`.
   - NĐ 46/2016/NĐ-CP: `Valid: False`, `Status: Outdated`.

---

## 3. Hướng dẫn tích hợp cho các thành viên

### Cho Vương (Chat REST API):
- Đã đăng ký `IGrpcInferenceService` dạng scoped trong DI container.
- Vương chỉ cần inject `IGrpcInferenceService` vào `ChatService` hoặc `ChatsController`:
  ```csharp
  public class ChatService(IGrpcInferenceService grpcInferenceService) : IChatService
  {
      public async Task<ChatInferenceResultDto> SendMessageAsync(string userId, string sessionId, string prompt, CancellationToken ct)
      {
          return await grpcInferenceService.ProcessChatMessageAsync(userId, sessionId, prompt, ct);
      }
  }
  ```

### Cho Phúc (Legal Document REST API, Crawler & Cron Jobs):
- Khi crawler cào văn bản mới từ *thuvienphapluat.vn* hoặc chạy cron job kiểm tra hiệu lực hằng đêm:
  ```csharp
  // 1. Kiểm tra văn bản hết hiệu lực hay còn hiệu lực
  var verifyResult = await grpcInferenceService.VerifyLegalDocumentAsync(docTitle, docNumber, content, ct);
  if (verifyResult.IsValid) { ... }

  // 2. Index batch chunks văn bản mới vào Qdrant Vector DB
  var indexResult = await grpcInferenceService.IndexDocumentAsync(chunkDtos, ct);
  ```

### Cho Khánh (Message Broker & Worker Service):
- Payload sự kiện `ChatCompletedEvent` lấy trực tiếp từ kết quả `ChatInferenceResultDto`:
  - `res.IsViolation`: cờ vi phạm moderation
  - `res.ViolationKeywords`: danh sách từ khóa cấm phát hiện
  - `res.TokensUsed`: số lượng token tiêu thụ để trừ quota
- Worker service dựa vào các giá trị này để trừ token và gửi email cảnh báo vi phạm khi `IsViolation == true`.
