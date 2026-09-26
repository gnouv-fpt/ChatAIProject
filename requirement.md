# YÊU CẦU KỸ THUẬT VÀ NGHIỆP VỤ (REQUIREMENT.MD)

## ĐỒ ÁN MÔN HỌC PRN232 - HỆ THỐNG RAG TƯ VẤN PHÁP LUẬT GIAO THÔNG ĐƯỜNG BỘ

---

## 1. TỔNG QUAN DỰ ÁN (PROJECT OVERVIEW)

- **Tên dự án:** Vietnam Traffic Law Advanced RAG System (Hệ thống Trợ lý AI Tư vấn Pháp luật Giao thông Đường bộ Việt Nam).
- **Lĩnh vực ứng dụng:** Pháp luật & Giao thông đường bộ Việt Nam (Dữ liệu từ [Thư viện Pháp luật](https://thuvienphapluat.vn/)).
- **Mục tiêu kỹ thuật:** Xây dựng hệ thống phân tán đa dịch vụ (Microservices/Distributed Architecture) đáp ứng đầy đủ yêu cầu đồ án môn **PRN232**, bao gồm các thành phần:
  1. **REST API Service** (.NET 8 Core RESTful API, Layered Architecture, JWT Authentication, Swagger).
  2. **gRPC Inference & Verification Service** (Dịch vụ AI kiểm duyệt độc hại & sinh câu trả lời RAG kèm xác thực hiệu lực văn bản).
  3. **Message Broker** (Redis Pub/Sub / Kafka cho truyền nhận sự kiện bất đồng bộ).
  4. **Background / Worker Service** (Consumer xử lý event trừ token, cảnh báo vi phạm qua Email & Cron Job định kỳ).
  5. **Docker Containerization** (Đóng gói toàn bộ hệ thống bằng Docker Compose).

- **Điểm đột phá - "Advent / Advanced RAG" (RAG Nâng cao & Xác thực dữ liệu):**
  - Tự động cào (crawl) và cập nhật dữ liệu các văn bản quy phạm pháp luật giao thông (Luật Giao thông đường bộ, Nghị định 100/2019/NĐ-CP, Nghị định 123/2021/NĐ-CP, Các Thông tư hướng dẫn,...).
  - **Dịch vụ xác thực dữ liệu (Data Verification Engine):** Kiểm tra trạng thái văn bản (Còn hiệu lực, Hết hiệu lực, Bị sửa đổi/bổ sung) trước khi đưa vào lưu trữ Vector và trả lời người dùng.
  - Trợ lý AI chỉ trả lời khi dữ liệu đã được xác thực chính xác 100%, kèm trích dẫn chi tiết (Điều, Khoản, Điểm, Tên văn bản, Trích dẫn gốc).

---

## 2. KIẾN TRÚC TỔNG THỂ VÀ LUỒNG DỮ LIỆU (SYSTEM ARCHITECTURE)

### 2.1. Sơ đồ các thành phần hệ thống

```text
[ React / Razor / Mobile / Postman Client ]
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
│ gRPC AI & Verification Svc   │    │ Message Broker  │ (Redis / Kafka)
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
- Đồng thời, REST API publish sự kiện `ChatCompletedEvent` lên **Message Broker** (Redis/Kafka) chứa payload:
  `{ UserId, SessionId, Prompt, Response, TokensUsed, IsViolation, ViolationKeywords, CreatedAt }`.

#### 4. Background Job & Cron Processing Flow (Luồng xử lý ngầm)

- **Worker Service (Consumer)** đăng ký lắng nghe `ChatCompletedEvent` từ Message Broker:
  - **Trừ Quota/Số dư Token:** Cập nhật số dư token / hạn ngạch khả dụng của `UserId` trong SQL Server.
  - **Cảnh báo vi phạm (Violation Alert):** Nếu `IsViolation == true` (user hỏi nội dung độc hại/nhạy cảm), ghi log vi phạm và kích hoạt dịch vụ gửi Email thông báo/cảnh báo tới User/Admin.
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
  - `GET /api/reports/usage`: Thống kê số lượng truy vấn và token tiêu thụ.

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

### 3.3. Message Broker (Redis Pub/Sub hoặc Apache Kafka)

- **Channel / Topic:** `chat-completed-events`, `document-updated-events`.
- **Payload của `ChatCompletedEvent`:**
  - `UserId` (Guid)
  - `SessionId` (Guid)
  - `Prompt` (string)
  - `Response` (string)
  - `TokensUsed` (int)
  - `IsViolation` (bool)
  - `ViolationKeywords` (List<string>)
  - `Timestamp` (DateTime)

### 3.4. Background / Worker Service

- **Consumer Component:**
  - Lắng nghe sự kiện `ChatCompletedEvent`.
  - Thực hiện giao dịch DB: Trừ số dư token trong bảng `Users` / `UserQuotas`.
  - Nếu `IsViolation == true`: Tạo bản ghi log trong `ViolationLogs` và gửi Email thông báo qua MailKit/SMTP.
- **Cron Job Component (Scheduled Tasks):**
  - **Cron Expression:** `0 0 * * *` (Mỗi đêm lúc 00:00).
  - Xóa các phiên chat nháp không có tin nhắn.
  - Tổng hợp dữ liệu tiêu thụ token theo ngày vào bảng `UsageReports`.
  - Quét danh sách văn bản luật đến ngày hết hiệu lực.

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
7. **`ViolationLogs`**: `Id`, `UserId`, `ChatMessageId`, `ViolationKeywords`, `NotifiedViaEmail`, `CreatedAt`.
8. **`UsageReports`**: `Id`, `ReportDate`, `TotalQueries`, `TotalTokensUsed`, `TotalViolations`, `CreatedAt`.

---

## 6. YÊU CẦU ĐÓNG GÓI VÀ TRIỂN KHAI (DOCKER DEPLOYMENT)

Hệ thống phải triển khai mượt mà bằng **Docker Compose** với file `docker-compose.yml` gồm các container:

1. `sqlserver`: SQL Server 2022 DB.
2. `qdrant`: Qdrant Vector Database cho lưu trữ Embedding.
3. `redis`: Redis server (Message Broker & Cache).
4. `grpc-inference-service`: Dịch vụ gRPC AI RAG & Verification (Python / .NET).
5. `rest-api-service`: ASP.NET Core REST API Gateway.
6. `worker-service`: .NET Background Worker Service Consumer.

---

## 7. MA TRẬN ĐÁP ỨNG TIÊU CHÍ ĐÁNH GIÁ PRN232 (PRN232 EVALUATION MATRIX)

| Tiêu chí đồ án PRN232 | Trọng số | Hạng mục đáp ứng trong hệ thống |
| :--- | :---: | :--- |
| **System Architecture & Design** | **20%** | Kiến trúc 3-Layer + Microservices (REST, gRPC, Worker, Broker), thiết kế Clean Architecture, tách biệt rõ trách nhiệm theo `AGENTS.md`. |
| **REST API Implementation** | **20%** | ASP.NET Core .NET 8 REST API đầy đủ CRUD cho Chat, User, Legal Documents, JWT Authentication, Swagger API Docs, Async/Await. |
| **Background Job** | **10%** | .NET Worker Service xử lý trừ token, gửi Email cảnh báo vi phạm qua SMTP và Cron Job định kỳ dọn dẹp data lúc 00:00. |
| **Message Broker Integration** | **15%** | Tích hợp Redis Pub/Sub / Kafka gửi nhận sự kiện bất đồng bộ `ChatCompletedEvent` giữa REST API và Worker Service. |
| **gRPC Service** | **15%** | Dịch vụ gRPC độc lập kết nối với REST API để xử lý Moderation Check & Advanced RAG Inference xác thực dữ liệu giao thông. |
| **Docker / Cloud Deployment** | **10%** | File `docker-compose.yml` đóng gói hoàn chỉnh 6 services (REST API, gRPC, Worker, SQL Server, Qdrant, Redis). |
| **Documentation & Presentation** | **10%** | File `requirement.md`, `README.md`, sơ đồ kiến trúc, tài liệu OpenAPI/Swagger và quy trình demo chi tiết. |

---
