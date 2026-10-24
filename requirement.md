# YÊU CẦU KỸ THUẬT VÀ NGHIỆP VỤ (REQUIREMENT.MD)

## ĐỒ ÁN MÔN HỌC PRN232 - HỆ THỐNG RAG TƯ VẤN PHÁP LUẬT GIAO THÔNG ĐƯỜNG BỘ

---

## 1. TỔNG QUAN DỰ ÁN (PROJECT OVERVIEW)

- **Tên dự án:** Vietnam Traffic Law Advanced RAG System (Hệ thống Trợ lý AI Tư vấn Pháp luật Giao thông Đường bộ Việt Nam).
- **Lĩnh vực ứng dụng:** Pháp luật & Giao thông đường bộ Việt Nam (Dữ liệu từ [Thư viện Pháp luật](https://thuvienphapluat.vn/)).
- **Mục tiêu kỹ thuật:** Xây dựng hệ thống phân tán đa dịch vụ (Microservices/Distributed Architecture) đáp ứng đầy đủ yêu cầu đồ án môn **PRN232**, bao gồm các thành phần:
  1. **REST API Service** (.NET 8 Core RESTful API, Layered Architecture, JWT Authentication, Swagger).
  2. **gRPC Inference & Verification Service** (Dịch vụ AI kiểm duyệt độc hại & sinh câu trả lời RAG kèm xác thực hiệu lực văn bản).
  3. **Message Broker** (Apache Kafka cho truyền nhận sự kiện bất đồng bộ; Redis chỉ dùng cho cache/rate limit nếu triển khai).
  4. **Background / Worker Service** (Consumer xử lý event trừ token, cảnh báo vi phạm qua Email & Cron Job định kỳ).
  5. **Docker Containerization** (Đóng gói toàn bộ hệ thống bằng Docker Compose).
  6. **Logging & Observability** (Ghi log file thật, đếm message Kafka, theo dõi dịch vụ và request/response trên Grafana).

- **Điểm đột phá - "Advent / Advanced RAG" (RAG Nâng cao & Xác thực dữ liệu):**
  - Tự động cào (crawl) và cập nhật dữ liệu các văn bản quy phạm pháp luật giao thông (Luật Giao thông đường bộ, Nghị định 100/2019/NĐ-CP, Nghị định 123/2021/NĐ-CP, Các Thông tư hướng dẫn,...).
  - **Dịch vụ xác thực dữ liệu (Data Verification Engine):** Kiểm tra trạng thái văn bản (Còn hiệu lực, Hết hiệu lực, Bị sửa đổi/bổ sung) trước khi đưa vào lưu trữ Vector và trả lời người dùng.
  - Trợ lý AI chỉ trả lời khi dữ liệu đã được xác thực chính xác 100%, kèm trích dẫn chi tiết (Điều, Khoản, Điểm, Tên văn bản, Trích dẫn gốc).

---

## 2. KIẾN TRÚC TỔNG THỂ VÀ LUỒNG DỮ LIỆU (SYSTEM ARCHITECTURE)

### 2.1. Sơ đồ các thành phần hệ thống

```text
[ React / Mobile / Postman Client ]
                  │
                  ▼ (HTTP/REST + JWT)
       ┌──────────────────────┐
       │   REST API Service   │ (ASP.NET Core REST API)
       └──────────┬───────────┘
                  │
       ┌──────────┴──────────────────────────┐
       │ (gRPC Channel)                      │ (Publish Event)
       ▼                                     ▼
┌──────────────────────────────┐    ┌─────────────────┐
│ gRPC AI & Verification Svc   │    │ Message Broker  │ (Apache Kafka)
│ (Moderation & Advanced RAG)  │    └────────┬────────┘
└──────────────┬───────────────┘             │
               │                             ▼
               │                    ┌─────────────────┐
               │                    │ Worker Service  │ (Background Consumer & Cron)
               │                    └────────┬────────┘
               ▼                             │
    ┌──────────────────────┐                 │
    │  Vector DB (Qdrant)  │                 │
    └──────────────────────┘                 ▼
                                    ┌─────────────────┐
                                    │ SQL Server DB   │
                                    └─────────────────┘
```

### 2.2. Chi tiết Luồng Nghiệp vụ End-to-End (End-to-End Business Flow)

#### 1. User Authentication (Xác thực người dùng)

- Client gửi thông tin đăng nhập tới `POST /api/auth/login`.
- REST API kiểm tra thông tin, tạo và trả về **JWT Token** (chứa `UserId`, `Role`, `Email`, `Quota`).
- Client gắn JWT Token vào Header `Authorization: Bearer <token>` trong mọi yêu cầu tiếp theo.

#### 2. Crawling, Verification & Indexing Flow (Luồng cào & xác thực dữ liệu giao thông)

- Hệ thống định kỳ hoặc qua trigger thủ công gọi dịch vụ Crawler để lấy văn bản pháp luật mới từ `thuvienphapluat.vn`.
- **Dịch vụ Verification Engine** kiểm tra dữ liệu:
  - Kiểm tra xem điều khoản/nghị định có còn hiệu lực thi hành hay không.
  - So sánh phiên bản cũ/mới (ví dụ: Nghị định 123/2021 sửa đổi Nghị định 100/2019).
- Dữ liệu đạt trạng thái `Verified` (Đã xác thực) sẽ được tách đoạn (chunking), tạo Vector Embedding và lưu vào **Qdrant Vector DB** & **SQL Server**.

#### 3. Chat Message & Advanced RAG Flow (Luồng hỏi đáp AI)

- User gửi câu hỏi: `POST /api/chats/{sessionId}/messages` kèm JWT Token.
- REST API xác thực Token và quyền hạn của người dùng.
- REST API đóng gói yêu cầu và gọi tới **gRPC Inference Service** qua gRPC Channel:
  1. **Kiểm tra vi phạm (Moderation & Toxicity Check):** Kiểm tra từ khóa cấm, ngôn từ thù hận, nội dung nhạy cảm.
  2. **Advanced RAG Retrieval:** Tìm kiếm các chunk văn bản luật giao thông có độ tương đồng cao trong Qdrant DB. Chỉ lọc ra các văn bản có trạng thái `Verified = true` (còn hiệu lực).
  3. **LLM Inference:** Tổng hợp câu trả lời dựa chính xác trên các điều khoản đã lọc, trích xuất danh sách nguồn (Citations).
- REST API nhận kết quả gRPC và phản hồi HTTP Response (JSON) ngay lập tức cho User.
- Đồng thời, REST API publish sự kiện `ChatCompletedEvent` lên **Apache Kafka** chứa payload:
  `{ UserId, SessionId, Prompt, Response, TokensUsed, IsViolation, ViolationKeywords, CreatedAt }`.

#### 4. Background Job & Cron Processing Flow (Luồng xử lý ngầm)

- **Worker Service (Consumer)** đăng ký lắng nghe `ChatCompletedEvent` từ Message Broker:
  - **Trừ Quota/Số dư Token:** Cập nhật số dư token / hạn ngạch khả dụng của `UserId` trong SQL Server.
  - **Cảnh báo vi phạm (Violation Alert):** Nếu `IsViolation == true` (user hỏi nội dung độc hại/nhạy cảm), ghi log có cấu trúc ra file và kích hoạt dịch vụ gửi Email thông báo/cảnh báo tới User/Admin.
- **Scheduled Cron Job (Định kỳ chạy mỗi 00:00 AM):**
  - Clear rác: Dọn dẹp các Chat Sessions quá hạn hoặc trống.
  - Auto Re-Verification: Kiểm tra xem có văn bản luật giao thông nào mới hết hiệu lực từ ngày hôm nay không để cập nhật flag `IsActive = false`.
  - Xuất báo cáo (Usage Report): Tổng hợp số lượng câu hỏi, số token tiêu thụ theo ngày gửi cho Quản trị viên.

---

## 3. YÊU CẦU CHỨC NĂNG CHI TIẾT (FUNCTIONAL REQUIREMENTS)

### 3.1. REST API Service (ASP.NET Core .NET 8)

- **Authentication & Authorization Controller (`/api/auth`):**
  - `POST /api/auth/register`: Đăng ký tài khoản người dùng/sinh viên.
  - `POST /api/auth/login`: Đăng nhập, cấp phát JWT Access Token và Refresh Token.
  - `POST /api/auth/refresh-token`: Xoay vòng refresh token một lần dùng, cấp access token mới.
  - `POST /api/auth/logout`: Thu hồi refresh token.
  - `GET /api/auth/profile`: Lấy thông tin cá nhân và hạn ngạch token hiện tại.
- **Chat Management Controller (`/api/chats`):**
  - `POST /api/chats`: Tạo phiên hỏi đáp mới.
  - `GET /api/chats`: Lấy danh sách các phiên chat của User (hỗ trợ Pagination, Search).
  - `GET /api/chats/{sessionId}`: Xem chi tiết tin nhắn trong phiên chat.
  - `POST /api/chats/{sessionId}/messages`: Gửi câu hỏi, nhận câu trả lời RAG real-time.
  - `DELETE /api/chats/{sessionId}`: Xóa phiên chat.
- **Legal Document Management Controller (`/api/documents`):**
  - `GET /api/documents`: Tra cứu văn bản luật giao thông (Filtering theo loại văn bản, hiệu lực, Pagination).
  - `GET /api/documents/{id}`: Xem chi tiết điều khoản, lịch sử xác thực.
  - `POST /api/documents/crawl-trigger` (Admin): Kích hoạt tiến trình cào và xác thực dữ liệu từ Thư viện pháp luật.
- **Usage & Report Controller (`/api/reports`):**
  - `GET /api/reports/usage`: Tổng hợp số truy vấn/token trực tiếp từ `ChatMessages` và `ChatSessions` theo người dùng/khoảng ngày; không dùng bảng báo cáo riêng.

### 3.2. gRPC Inference Service (Python / .NET gRPC)

- Định nghĩa Protobuf (`chat_inference.proto`):

  ```protobuf
  syntax = "proto3";
  package traffic_rag;

  service TrafficRagInference {
    rpc ProcessChatMessage (ChatInferenceRequest) returns (ChatInferenceResponse);
    rpc VerifyLegalDocument (VerificationRequest) returns (VerificationResponse);
  }

  message ChatInferenceRequest {
    string user_id = 1;
    string session_id = 2;
    string prompt = 3;
  }

  message CitationDto {
    string document_title = 1;
    string article_number = 2;
    string clause_number = 3;
    string source_url = 4;
    string excerpt = 5;
  }

  message ChatInferenceResponse {
    string response_text = 1;
    int32 tokens_used = 2;
    bool is_violation = 3;
    repeated string violation_keywords = 4;
    repeated CitationDto citations = 5;
    bool data_verified = 6;
  }
  ```

- Thực hiện 2 nhiệm vụ cốt lõi:
  1. Moderation Engine: Đánh giá độ an toàn của prompt.
  2. RAG Generator: Tìm kiếm vector chính xác các điều khoản giao thông còn hiệu lực, sinh câu trả lời tiếng Việt chuẩn xác kèm link tham khảo `thuvienphapluat.vn`.

### 3.3. Message Broker (Apache Kafka)

- **Công nghệ chốt cho nhóm:** Apache Kafka. Redis Pub/Sub không thay thế Kafka trong phần demo theo yêu cầu bổ sung.
- **Topic:** `chat-completed-events`, `document-updated-events`.
- Có producer và consumer chạy thực tế; log mô phỏng publish không được tính là gửi message thành công.
- Phải phân biệt gửi được broker xác nhận, consumer nhận message, xử lý nghiệp vụ thành công, retry và thất bại.
- Gắn `EventId` duy nhất và thông tin correlation/trace xuyên REST → gRPC → Kafka → Worker; ghi nhận topic, partition, offset và consumer group khi có.
- Xử lý lại cùng sự kiện không được trừ token hoặc tạo vi phạm trùng. Có chính sách retry giới hạn và nơi lưu message lỗi để kiểm tra/replay.
- **Payload của `ChatCompletedEvent`:**
  - `UserId` (Guid)
  - `SessionId` (Guid)
  - `Prompt` (string)
  - `Response` (string)
  - `TokensUsed` (int)
  - `IsViolation` (bool)
  - `ViolationKeywords` (List<string>)
  - `CreatedAt` (DateTime UTC; thống nhất tên với event hiện tại)
  - `EventId` (Guid, bổ sung để theo dõi và chống xử lý trùng)
  - `ChatMessageId` (Guid, bổ sung để liên kết tin nhắn với kết quả xử lý)
  - `TraceParent` (string, bổ sung để truyền trace context)

### 3.4. Background / Worker Service

- **Consumer Component:**
  - Lắng nghe sự kiện `ChatCompletedEvent`.
  - Thực hiện giao dịch DB: Trừ số dư token trong bảng `Users`; thiết kế xử lý đồng thời và chống trừ trùng khi retry.
  - Nếu `IsViolation == true`: Giữ `ChatMessages.IsViolation`, ghi chi tiết kiểm duyệt vào log file và gửi Email thông báo qua MailKit/SMTP; không tạo bảng vi phạm riêng.
- **Cron Job Component (Scheduled Tasks):**
  - **Cron Expression:** `0 0 * * *` (Mỗi đêm lúc 00:00).
  - Xóa các phiên chat nháp không có tin nhắn.
  - Tổng hợp dữ liệu tiêu thụ token theo ngày từ `ChatMessages` theo `CreatedAt`; xuất file/log hoặc gửi báo cáo, không lưu bảng báo cáo riêng.
  - Quét danh sách văn bản luật đến ngày hết hiệu lực.

### 3.5. Log file và giám sát bằng Grafana (yêu cầu bổ sung)

- **Log file thật:** REST API, gRPC và Worker ghi log có cấu trúc JSON ra file được lưu qua Docker volume; có rotation và thời gian lưu cấu hình được. Console log có thể dùng kèm nhưng không thay thế file log.
- **Trường log:** thời gian UTC, service, level, thao tác, trạng thái, duration, TraceId/CorrelationId; các bước Kafka thêm EventId, topic, consumer group, partition, offset và lỗi khi có. Chỉ ghi thành công sau bước xác nhận tương ứng.
- **Đếm message:** hiển thị riêng số publish được xác nhận, số nhận/lần thử xử lý, số xử lý thành công duy nhất, số bỏ qua do trùng, số retry và số thất bại. Không dùng tổng số dòng log làm số lượng sự kiện duy nhất.
- **Trạng thái hoạt động:** hiển thị service up/down, broker và consumer đang hoạt động, heartbeat/lần xử lý gần nhất, consumer lag theo topic/group/partition. Phân biệt không có message mới với consumer bị dừng/lỗi.
- **Request/response:** xem được HTTP method/route, HTTP hoặc gRPC status, thời gian xử lý, kích thước request/response, tỷ lệ lỗi và throughput; tìm log chi tiết bằng TraceId. Trong demo cần xem nội dung thì ghi body đã che thông tin nhạy cảm, có giới hạn kích thước; không log password, JWT, refresh token hay API key.
- **Data sources:** Prometheus thu metrics, Loki lưu/tìm log file qua collector như Grafana Alloy; dùng Tempo/OpenTelemetry để theo dấu request xuyên dịch vụ. Grafana kết nối các data source bằng cấu hình provisioning và dashboard lưu trong source.
- **Dashboard tối thiểu:** service health, request rate, error rate, latency p95, message counts theo trạng thái, consumer lag và truy vấn log producer/consumer; có cảnh báo service down, lag tồn đọng và lỗi xử lý kéo dài với ngưỡng cấu hình được.
- **Bằng chứng demo:** tạo N sự kiện có EventId khác nhau và đối chiếu gửi/nhận/xử lý; dừng Worker để thấy lag tăng rồi khởi động lại để thấy backlog giảm; replay cùng EventId để kiểm tra không trừ quota trùng; tìm được log file và request/response tương ứng trên Grafana. Chỉ báo cáo số đo/log thực tế, không dùng dữ liệu giả làm bằng chứng.

---

## 4. YÊU CẦU PHI CHỨC NĂNG (NON-FUNCTIONAL REQUIREMENTS)

1. **Độ chính xác dữ liệu (Data Accuracy & Legal Compliance):**
   - Không được xảy ra hiện tượng "hallucination" (bốc phét dữ liệu). Nếu không tìm thấy điều khoản tương ứng trong Thư viện pháp luật giao thông đã xác thực, hệ thống phải trả lời rõ: *"Hiện tại hệ thống chưa tìm thấy quy định pháp lý tương ứng trong các văn bản giao thông đã được xác thực."*
2. **Hiệu năng (Performance):**
   - Phản hồi từ REST API qua gRPC Inference < 3 giây đối với câu hỏi thông thường.
   - Thời gian tiêu thụ sự kiện qua Message Broker đến Worker Service < 1 giây.
3. **Bảo mật (Security):**
   - Mã hóa mật khẩu người dùng bằng BCrypt / PBKDF2.
   - Toàn bộ endpoint nhạy cảm đều yêu cầu Header JWT Bearer.
   - Không lưu trữ lộ API Key (OpenAI / Gemini / Qdrant) trong mã nguồn (dùng User Secrets / Environment Variables).
4. **Kiến trúc mã nguồn (Code Architecture):**
   - Tuân thủ nghiêm ngặt **3-Layer Architecture** (Presentation - BusinessLogic - DataAccess - BusinessObject) theo quy định trong `AGENTS.md`.
   - Các async method phải dùng `await`, không dùng `.Result` hay `.Wait()`.

---

## 5. THIẾT KẾ CƠ SỞ DỮ LIỆU (DATABASE SCHEMA - SQL SERVER)

Các bảng chính trong hệ thống `ChatAIWebDb`:

1. **`Users`**: `Id`, `Username`, `Email`, `PasswordHash`, `Role`, `TokenQuota`, `TokenBalance`, `CreatedAt`.
2. **`LegalDocuments`**: `Id`, `DocumentNumber` (e.g. 100/2019/NĐ-CP), `Title`, `IssuingAuthority`, `EffectiveDate`, `ExpirationDate`, `IsActive`, `VerificationStatus` (Pending, Verified, Outdated), `SourceUrl`, `CreatedAt`.
3. **`DocumentChunks`**: `Id`, `DocumentId`, `Chapter`, `Article`, `Clause`, `Content`, `TokenCount`, `VectorId`, `IsVerified`.
4. **`ChatSessions`**: `Id`, `UserId`, `Title`, `CreatedAt`, `LastUpdatedAt`, `IsDeleted`.
5. **`ChatMessages`**: `Id`, `SessionId`, `SenderRole` (User/Assistant), `Content`, `TokensUsed`, `IsViolation`, `CreatedAt`.
6. **`Citations`**: `Id`, `ChatMessageId`, `DocumentChunkId`, `Excerpt`, `SourceUrl`.
7. **`RefreshTokens`**: `Id`, `UserId`, `TokenHash`, `ExpiresAt`, `CreatedAt`, `RevokedAt` (nullable); lưu hash SHA-256, xoay vòng một lần dùng, thu hồi khi logout.

Theo yêu cầu giảng viên, **không sử dụng hai bảng `ViolationLogs` và `UsageReports`**. Phạm vi SQL còn 7 bảng ở trên. Dữ liệu vi phạm dùng `ChatMessages.IsViolation` và log file; thống kê tổng hợp từ tin nhắn và metrics, không cần thêm bảng lưu báo cáo.

### 5.1. Sơ đồ và thiết kế để giảng viên review

- Làm theo thứ tự: xác định entity/quan hệ → vẽ ERD → thiết kế database diagram với đầy đủ cột và ràng buộc → review/chỉnh sửa với giảng viên.
- ERD thể hiện đủ các entity nghiệp vụ, PK/FK, cardinality và quan hệ optional/bắt buộc. Database diagram có SQL type cụ thể, độ dài, nullable, unique/index và quy tắc xóa.
- SQL Server là nơi lưu dữ liệu nghiệp vụ; Qdrant lưu vector/payload và được thể hiện bằng sơ đồ riêng. `DocumentChunks.VectorId` là liên kết logic tới point trong Qdrant, không phải SQL FK xuyên hai database.
- Đối chiếu sơ đồ với entities, DbContext và migrations; ghi rõ phần đang có và phần đề xuất. Bổ sung `DocumentType`, `LastVerifiedAt` trong LegalDocuments và các trường snapshot `DocumentTitle`, `ArticleNumber`, `ClauseNumber` trong Citations theo model hiện tại.
- Thiết kế đáp ứng trích dẫn Điều/Khoản/Điểm; cần trường Điểm riêng hoặc cấu trúc tách được rõ các thành phần này. Muốn có lịch sử xác thực phải có thiết kế lưu nhiều lần xác thực, không chỉ thời điểm gần nhất.
- Tài liệu kiến trúc C2 (Container) là hạng mục riêng, nhóm bổ sung sau; không coi ERD là sơ đồ C2 Container. Việc review database không cần chờ hoàn thành C2.
- Các bảng bổ sung phục vụ outbox, chống xử lý trùng hoặc lịch sử xác thực là thiết kế đề xuất cho đến khi được chốt và triển khai migration; không mặc định đã tồn tại trong 7 bảng trong phạm vi hiện tại.

---

## 6. YÊU CẦU ĐÓNG GÓI VÀ TRIỂN KHAI (DOCKER DEPLOYMENT)

Hệ thống phải triển khai mượt mà bằng **Docker Compose** với file `docker-compose.yml` gồm các container:

1. `sqlserver`: SQL Server 2022 DB.
2. `qdrant`: Qdrant Vector Database cho lưu trữ Embedding.
3. `kafka`: Apache Kafka, message broker cho producer/consumer.
4. `grpc-inference-service`: Dịch vụ gRPC AI RAG & Verification (Python / .NET).
5. `rest-api-service`: ASP.NET Core REST API Gateway.
6. `worker-service`: .NET Background Worker Service Consumer.
7. `grafana`: Dashboard và cấu hình data sources/alerts.
8. `prometheus`: Thu và lưu metrics của dịch vụ/Kafka exporters.
9. `loki`: Lưu và truy vấn log.
10. `alloy` (hoặc collector tương đương): Đọc log file trên volume và chuyển telemetry tới backend.
11. `tempo`: Lưu distributed traces từ OpenTelemetry.

- Thêm exporter cho broker metrics và consumer lag phù hợp với Kafka; bảo đảm Prometheus scrape được các target.
- `redis` là tùy chọn nếu dùng cache/rate limit, không còn là broker thay Kafka.
- Lưu cấu hình monitoring, dashboard và provisioning trong repository; không hard-code secrets. Log file và dữ liệu backend cần volume/retention phù hợp.
- Danh sách trên là yêu cầu triển khai đích; `docker-compose.yml` hiện tại cần được cập nhật và kiểm chứng riêng, không coi tài liệu này là bằng chứng đã chạy đủ services.

---

## 7. MA TRẬN ĐÁP ỨNG TIÊU CHÍ ĐÁNH GIÁ PRN232 (PRN232 EVALUATION MATRIX)

| Tiêu chí đồ án PRN232 | Trọng số | Hạng mục đáp ứng trong hệ thống |
| :--- | :---: | :--- |
| **System Architecture & Design** | **20%** | Kiến trúc 3-Layer + Microservices (REST, gRPC, Worker, Broker), thiết kế Clean Architecture, tách biệt rõ trách nhiệm theo `AGENTS.md`. |
| **REST API Implementation** | **20%** | ASP.NET Core .NET 8 REST API đầy đủ CRUD cho Chat, User, Legal Documents, JWT Authentication, Swagger API Docs, Async/Await. |
| **Background Job** | **10%** | .NET Worker Service xử lý trừ token, gửi Email cảnh báo vi phạm qua SMTP và Cron Job định kỳ dọn dẹp data lúc 00:00. |
| **Message Broker Integration** | **15%** | Apache Kafka gửi nhận sự kiện bất đồng bộ giữa REST API và Worker, có log file, đếm publish/consume/process, retry và chống tác động trùng. |
| **gRPC Service** | **15%** | Dịch vụ gRPC độc lập kết nối với REST API để xử lý Moderation Check & Advanced RAG Inference xác thực dữ liệu giao thông. |
| **Docker / Cloud Deployment** | **10%** | Docker Compose triển khai các dịch vụ nghiệp vụ, Kafka và stack monitoring; kiểm chứng liên lạc giữa các thành phần. |
| **Documentation & Presentation** | **10%** | `requirement.md`, `README.md`, ERD, database diagram, C2 bổ sung sau, Swagger và demo log/metrics/request-response qua Grafana. |

Trọng số trên giữ nguyên đề bài gốc. Yêu cầu bổ sung của nhóm/giảng viên về Kafka, log file, Grafana và sơ đồ review được tích hợp vào các hạng mục liên quan, không tự đặt thêm trọng số chấm điểm.

---
