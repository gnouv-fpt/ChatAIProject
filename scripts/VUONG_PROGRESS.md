# Tiến độ & Nghiệm thu - Vương (Chat REST API, gRPC Client & Docker DevOps)

Nhánh: `PRN-VUONG-dev` (dựa trên `origin/PRN-BAO-dev`)

---

## 1. Khối công việc đã hoàn thành

### 1.1. DataAccess Layer (Repositories cho Chat)
- [x] Tạo `IChatSessionRepository` ([DataAccess/Repositories/Interfaces/IChatSessionRepository.cs](../DataAccess/Repositories/Interfaces/IChatSessionRepository.cs)) & `ChatSessionRepository` ([DataAccess/Repositories/Implementations/ChatSessionRepository.cs](../DataAccess/Repositories/Implementations/ChatSessionRepository.cs)):
  - `GetSessionWithMessagesAsync`: Eager loading `Messages` và `Citations` của từng tin nhắn theo thời gian tăng dần (`OrderBy(m => m.CreatedAt)`), lọc `!s.IsDeleted`.
  - `GetUserSessionsPagedAsync`: Phân trang, tìm kiếm tiêu đề, sắp xếp `LastUpdatedAt` giảm dần, tối ưu truy vấn với `AsNoTracking()`.
  - `SoftDeleteSessionAsync`: Xóa mềm phiên chat (`IsDeleted = true`), ghi nhận `LastUpdatedAt`.
- [x] Tạo `IChatMessageRepository` ([DataAccess/Repositories/Interfaces/IChatMessageRepository.cs](../DataAccess/Repositories/Interfaces/IChatMessageRepository.cs)) & `ChatMessageRepository` ([DataAccess/Repositories/Implementations/ChatMessageRepository.cs](../DataAccess/Repositories/Implementations/ChatMessageRepository.cs)):
  - Thêm mới tin nhắn người dùng và tin nhắn AI kèm danh sách `Citation`.
  - Lấy danh sách tin nhắn kèm trích dẫn pháp lý theo session.

### 1.2. gRPC Client & Protocol Buffers (`chat_inference.proto`)
- [x] Thêm file hợp đồng protobuf: [Protos/chat_inference.proto](../Protos/chat_inference.proto) (gói `traffic_rag`, C# namespace `BusinessLogic.Protos`).
- [x] Cấu hình `BusinessLogic.csproj`:
  - Thêm các package gRPC: `Grpc.Net.Client`, `Grpc.Net.ClientFactory`, `Google.Protobuf`, `Grpc.Tools`.
  - Tự động biên dịch `chat_inference.proto` sang C# Client stub khi build.
- [x] Định nghĩa DTOs trung gian tại [BusinessLogic/DTOs/GrpcDtos.cs](../BusinessLogic/DTOs/GrpcDtos.cs):
  - `ChatInferenceResultDto`, `CitationResultDto`, `VerificationResultDto`, `DocumentChunkInputDto`, `IndexDocumentResultDto`.
- [x] Triển khai interface [IGrpcInferenceService](../BusinessLogic/Services/Interfaces/IGrpcInferenceService.cs) và service [GrpcInferenceService](../BusinessLogic/Services/Implementations/GrpcInferenceService.cs):
  - `ProcessChatMessageAsync`: Gọi RPC `ProcessChatMessage` sang gRPC server (của Khôi).
  - Bổ sung cơ chế **Robust Exception Handling & Graceful Fallback**: Bắt lỗi `RpcException` (khi server AI chưa bật hoặc timeout), ghi log cảnh báo và trả về thông báo lỗi thân thiện thay vì làm sập luồng của ứng dụng.

### 1.3. Message Broker Integration (Redis Pub/Sub Event Publisher)
- [x] Thêm package `StackExchange.Redis` vào `BusinessLogic.csproj`.
- [x] Định nghĩa model sự kiện [ChatCompletedEvent](../BusinessLogic/Infrastructure/Events/ChatCompletedEvent.cs):
  - `UserId`, `SessionId`, `Prompt`, `Response`, `TokensUsed`, `IsViolation`, `ViolationKeywords`, `CreatedAt`.
- [x] Interface [IEventPublisher](../BusinessLogic/Infrastructure/Interfaces/IEventPublisher.cs) và triển khai [RedisEventPublisher](../BusinessLogic/Infrastructure/Implementations/RedisEventPublisher.cs):
  - Kết nối Redis bất đồng bộ qua `ConnectionMultiplexer` (Lazy evaluation).
  - Tự động fallback sang logging nếu môi trường dev chưa cấu hình Redis, đảm bảo hệ thống không bị exception.
  - Publish tin nhắn JSON vào channel `chat-completed-events` cho Worker Service của Khánh tiêu thụ.

### 1.4. BusinessLogic Service & DTOs
- [x] DTOs Request & Response chuẩn:
  - [BusinessLogic/DTOs/Requests/ChatRequests.cs](../BusinessLogic/DTOs/Requests/ChatRequests.cs): `CreateChatSessionRequest`, `SendMessageRequest` (DataAnnotations validation tiếng Việt).
  - [BusinessLogic/DTOs/Responses/ChatResponses.cs](../BusinessLogic/DTOs/Responses/ChatResponses.cs): `ChatSessionResponseDto`, `ChatSessionDetailResponseDto`, `ChatMessageResponseDto`, `CitationResponseDto`, `PagedResultDto<T>`.
- [x] Triển khai [IChatbotService](../BusinessLogic/Services/Interfaces/IChatbotService.cs) & [ChatbotService](../BusinessLogic/Services/Implementations/ChatbotService.cs):
  - `CreateSessionAsync`: Khởi tạo session, tự động gán tiêu đề mặc định nếu người dùng để trống.
  - `GetSessionsAsync`: Lấy danh sách session của user hiện tại có phân trang và tìm kiếm.
  - `GetSessionDetailAsync`: Xem chi tiết toàn bộ tin nhắn và trích dẫn pháp lý.
  - `SendMessageAsync`: Điều phối quy trình: Lưu tin nhắn User -> Gọi gRPC RAG Inference -> Lưu tin nhắn Assistant & Citations -> Cập nhật Session `LastUpdatedAt` -> Bắn `ChatCompletedEvent` vào Redis -> Trả response.
  - `DeleteSessionAsync`: Xóa mềm session.

### 1.5. Presentation Web API Controller & DI Registration
- [x] Xây dựng [Presentation/Controllers/ChatsController.cs](../Presentation/Controllers/ChatsController.cs):
  - `POST /api/chats`: Tạo phiên chat mới (201 Created).
  - `GET /api/chats`: Lấy danh sách phiên chat phân trang (200 OK).
  - `GET /api/chats/{sessionId}`: Lấy chi tiết lịch sử phiên chat (200 OK).
  - `POST /api/chats/{sessionId}/messages`: Gửi câu hỏi, nhận kết quả RAG real-time (200 OK).
  - `DELETE /api/chats/{sessionId}`: Xóa phiên chat (204 NoContent).
  - Mọi endpoint đều bảo vệ bởi `[Authorize]`, lấy `UserId` từ `User.GetUserId()`.
- [x] Đăng ký DI hoàn chỉnh trong [Presentation/Program.cs](../Presentation/Program.cs):
  - `IChatSessionRepository`, `ChatSessionRepository` (Scoped).
  - `IChatMessageRepository`, `ChatMessageRepository` (Scoped).
  - `IChatbotService`, `ChatbotService` (Scoped).
  - `IEventPublisher`, `RedisEventPublisher` (Singleton).
  - `AddGrpcClient<TrafficRagInference.TrafficRagInferenceClient>` và `IGrpcInferenceService` (Scoped).
- [x] Cấu hình cấu trúc endpoints trong [Presentation/appsettings.json](../Presentation/appsettings.json):
  - `GrpcService:Address`: `http://localhost:50051`.
  - `ConnectionStrings:Redis`: `localhost:6379`.

### 1.6. Docker & DevOps Containerization
- [x] Viết [Presentation/Dockerfile](../Presentation/Dockerfile):
  - Multi-stage build .NET 8 SDK -> ASP.NET Core Runtime (tối ưu dung lượng và cache layer).
- [x] Viết file điều phối phân tán [docker-compose.yml](../docker-compose.yml):
  - Kết nối đầy đủ **6 dịch vụ**:
    1. `sqlserver`: SQL Server 2022 (Port 1433, volume `sql_data`, healthcheck tự động).
    2. `qdrant`: Qdrant Vector DB (Port 6333, 6334, volume `qdrant_data`).
    3. `redis`: Redis 7 Alpine (Port 6379, volume `redis_data`).
    4. `grpc-inference-service`: AI & Verification gRPC Engine (Port 50051, build từ `./grpc_inference_service`).
    5. `rest-api-service`: ASP.NET Core REST API Gateway (Port 8080, phụ thuộc healthcheck của SQL Server, Redis và gRPC Service).
    6. `worker-service`: Worker Service Consumer (sẵn sàng cho phần của Khánh).
  - Thiết lập Docker bridge network `traffic-rag-net`.
- [x] Tạo file mẫu cấu hình môi trường [.env.example](../.env.example).

---

## 2. Kiểm thử và Xác minh

- [x] `dotnet build`: Build toàn bộ Solution thành công: **0 Warnings, 0 Errors**.
- [x] `dotnet ef migrations has-pending-model-changes`: Kiểm tra tính toàn vẹn mô hình cơ sở dữ liệu -> **Không có thay đổi model nào chưa migrate** (đồng bộ 100% với database của Bảo).
- [x] Cấu hình user-secrets tự động qua `pwsh -File scripts/setup.ps1` -> Hoạt động chính xác.

---

## 3. Hướng dẫn chạy và kiểm thử

### Cách 1: Chạy trực tiếp trên máy cục bộ (Local Development)

1. Thiết lập môi trường và secrets (chỉ cần chạy 1 lần):
   ```powershell
   pwsh -File scripts/setup.ps1
   ```
2. Chạy REST API Service:
   ```powershell
   dotnet run --project Presentation --launch-profile http
   ```
3. Truy cập Swagger UI:
   `http://localhost:5039/swagger`
4. Quy trình test trên Swagger:
   - Đăng nhập tại `POST /api/auth/login` (admin@chataiweb.local / Admin@123456).
   - Copy token vào nút **Authorize** ở góc trên Swagger (`Bearer <token>`).
   - Gọi `POST /api/chats` tạo session mới -> nhận `sessionId`.
   - Gọi `POST /api/chats/{sessionId}/messages` gửi câu hỏi (ví dụ: *"Vượt đèn đỏ xe máy phạt bao nhiêu tiền?"*).
   - Gọi `GET /api/chats/{sessionId}` xem lại toàn bộ tin nhắn và trích dẫn nguồn.

### Cách 2: Chạy toàn bộ 6 dịch vụ qua Docker Compose

```bash
docker compose up -d --build
```
Truy cập REST API qua: `http://localhost:8080/swagger`

---

## 4. Bàn giao và Gợi ý tích hợp cho các thành viên

- **Cho Khánh (Worker Service & Message Broker):**
  - REST API đã publish sự kiện `ChatCompletedEvent` vào Redis topic `chat-completed-events`.
  - Khánh chỉ cần viết Worker Service subscribe vào topic này để trừ quota người dùng trong bảng `Users` và gửi email khi `IsViolation == true`.
- **Cho Phúc (Crawler & Document Management):**
  - Phúc có thể sử dụng `IGrpcInferenceService` đã đăng ký sẵn trong DI để gọi `VerifyLegalDocumentAsync` và `IndexDocumentAsync` khi cào dữ liệu từ *thuvienphapluat.vn*.
