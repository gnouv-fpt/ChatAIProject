# PHÂN CÔNG CODE HIỆN HÀNH — CẬP NHẬT 24/10/2026

**Bản phân công chính bên dưới thay thế phân công lịch sử ở cuối file.** Scope gồm tư vấn luật, chat chữ/ảnh, học ngân hàng câu hỏi, chọn N câu, trộn đề, thi thử và tiến độ. Chi tiết task IDs/API/file ownership ở [IMPLEMENTATION-PLAN.md](docs/IMPLEMENTATION-PLAN.md).

## Phân công mới cho 5 người

| Người | Module | Công việc còn phải code | Đầu ra |
| --- | --- | --- | --- |
| **Bảo** | Auth, dữ liệu, quota, progress/report | Hợp nhất 7 bảng core; thiết kế persistence học/thi/ảnh; migrations/repos/transaction; quota reserve/settle; report/progress/bookmark/history; kiểm thử auth; UI tài khoản/tiến độ | Schema/state contracts, persistence, quota service, API/UI tài khoản và tiến độ |
| **Khôi** | AI API/gRPC/vision/Qdrant | Groq generation, embedding API, vision/OCR API; bỏ local fallback; proto; citation chunk/Điểm/version; verification; index/deactivate; hiểu ảnh/follow-up | Python gRPC/API adapters, contract, test text/ảnh/RAG/lỗi |
| **Khánh** | Kafka/Worker + engine luyện/thi | Producer/relay/consumer, retry/DLQ/email; Worker host/scheduler; chọn N/trộn câu/template/timer/chấm server; UI làm bài/kết quả | Worker thật, events, Practice/Exam services/API/UI |
| **Vương** | Tích hợp, Chat/ảnh, web shell, hạ tầng | Ghép source; ChatbotService/gRPC adapter/idempotency; attachment API; UI chat; web shell/API client; Gateway/Compose/monitoring | Bản tích hợp và demo xuyên dịch vụ, Chat API/UI, deployment |
| **Phúc** | Luật, ngân hàng đề và nội dung học | Hoàn thiện crawler/verify/chunk/index; Documents; import bank/ảnh/đáp án/profile/version; Admin preview/publish; questions/templates; cron nghiệp vụ; UI thư viện/học/admin | Dữ liệu thật, pipeline import/crawl, API/UI nội dung học |

Tái sử dụng các nhánh PRN đã có, không viết lại auth/chat/documents từ đầu. Nhánh FastAPI FLM của Khánh không thay thế Worker PRN. AI inference dùng API; chấm thi bằng code theo đáp án chuẩn/profile, không bằng LLM.

## Cách triển khai song song

| Mốc tích hợp | Cả nhóm làm | Điều kiện ghép |
| --- | --- | --- |
| **P0: nền + contracts** | Ghép source; schema/repo interfaces; proto; event/exam interfaces; bank format; web skeleton | Chốt IDs/version/errors/ownership; skeleton build |
| **P1: core chạy thật** | Auth/chat chữ/RAG/SQL/Kafka/Worker/quota; import bank draft; phát triển vision API | Chat có citation, replay không trừ trùng, provider lỗi trả đúng trạng thái |
| **P2: học và thi** | Published bank, học N/chủ đề/range, đề sẵn/ngẫu nhiên, timer/chấm, progress/ôn sai | UI → API → persistence; snapshot/version và answer hiding đúng |
| **P3: ảnh + vận hành** | Chat ảnh/follow-up, cron/expiry/cache/email, dashboards/demo | Ba luồng chat chữ/chat ảnh/học thi chạy thật, restart phục hồi |

**Đây là thứ tự nghiệm thu, không phải năm người chờ nhau.** Vision/bank/exam/UI có thể code song song từ khi contract bản đầu thống nhất. Fixtures dùng unit/contract test được gắn nhãn; demo dùng API/data thật.

## Quyền sở hữu file chung

- **Bảo:** BusinessObject, DataAccess, DbContext/migrations/repository contracts.
- **Khôi:** protobuf nguồn và Python AI.
- **Khánh:** events, Worker host/consumers/relay, Practice/Exam engine.
- **Vương:** REST Program.cs, projects/solution dùng chung, web shell/router, Gateway/Compose/monitoring.
- **Phúc:** source/bank manifest/profile/import, crawler/chunker, Documents và question-bank APIs.

Mỗi người sửa controller/service/UI module mình, bàn giao DI extension cho người giữ host. Mỗi người instrument/test module mình; Vương tích hợp dashboard, không viết thay mọi telemetry/UI.

Giữ 7 bảng core theo AGENTS.md; persistence học/thi/attachment là đề xuất mở rộng cần chốt trước migration, không nhét vào ChatMessages. Frontend đề xuất React/TypeScript tại web/, không đưa Razor Pages trở lại. Không tạo nhánh/merge/push/apply migration trong lần lập plan này.

Tài liệu chính: [IMPLEMENTATION-PLAN.md](docs/IMPLEMENTATION-PLAN.md), [APP-FEATURES.md](docs/APP-FEATURES.md), [BRANCH-AUDIT-2026-10-24.md](docs/BRANCH-AUDIT-2026-10-24.md). Plan chưa có deadline vì chưa có thời gian rảnh của từng người.

---

# PHÂN CÔNG LỊCH SỬ — CHỈ THAM KHẢO, KHÔNG PHẢI TASK HIỆN HÀNH

## ĐỒ ÁN PRN232: HỆ THỐNG RAG TƯ VẤN PHÁP LUẬT GIAO THÔNG ĐƯỜNG BỘ

---

## 1. PHÂN CÔNG NHIỆM VỤ THEO THÀNH VIÊN (5 THÀNH VIÊN)

### 1. BẢO - DATABASE & AUTH REST API (BACKEND CORE)

- **Database & Architecture:**
  - Khởi tạo Database SQL Server (`ChatAIWebDb`), viết DbContext và Entity Classes (`User`, `LegalDocument`, `DocumentChunk`, `ChatSession`, `ChatMessage`, `Citation`).
  - Triển khai Repository Pattern (`DataAccess`) và Business Services (`BusinessLogic`) chuẩn 3-Layer Architecture theo `AGENTS.md`.
- **Auth REST API Module:**
  - Xây dựng `Auth Controller`: Register, Login, Refresh Token, Profile.
  - Cấu hình JWT Bearer Authentication & Authorization Middleware.
  - Cấu hình Swagger/OpenAPI, Dependency Injection và Global Exception Handling.

---

### 2. KHÔI - gRPC SERVICE & ADVANCED RAG (AI & VECTOR DB)

- **gRPC Inference Service:**
  - Thiết kế Protobuf (`chat_inference.proto`) và phát triển Dịch vụ gRPC độc lập (Python / .NET).
  - Triển khai **Moderation Engine** (phát hiện từ khóa vi phạm/độc hại).
- **Advanced RAG & Verification Engine:**
  - Tích hợp Vector Database (**Qdrant**) cho dữ liệu Luật Giao thông (Luật GTĐB, Nghị định 100/2019, Nghị định 123/2021).
  - Triển khai **Data Verification Engine**: Kiểm tra xác thực văn bản luật còn hiệu lực thi hành trước khi đưa vào RAG.
  - Xây dựng AI RAG Generator sinh câu trả lời tiếng Việt chính xác kèm trích dẫn (Citations) Thư viện pháp luật.

---

### 3. KHÁNH - MESSAGE BROKER & WORKER SERVICE (ASYNC EVENT & EMAIL)

- **Message Broker:**
  - Tích hợp Redis Pub/Sub (hoặc Apache Kafka) làm Message Broker truyền nhận tin nhắn bất đồng bộ.
  - Xây dựng Producer đẩy sự kiện `ChatCompletedEvent` từ REST API sang Broker.
- **Worker Service (Consumer):**
  - Phát triển .NET Worker Service tiêu thụ sự kiện `ChatCompletedEvent`.
  - Thực hiện xử lý bất đồng bộ: Trừ số dư Token/Quota người dùng trong SQL Server.
  - **Email Alert Service:** Tích hợp SMTP/MailKit gửi Email tự động cảnh báo vi phạm cho User/Admin khi `IsViolation == true`.

---

### 4. VƯƠNG - CHAT REST API, gRPC CLIENT & DOCKER DEVOPS

- **Chat REST API Module:**
  - Xây dựng `Chat Management Controller`: `/api/chats`, `/api/chats/{sessionId}/messages`, GET history, DELETE session.
  - Tích hợp **gRPC Client** kết nối từ REST API Gateway sang gRPC Inference Service.
  - Quản lý luồng gọi AI real-time và ghi nhận phản hồi vào Chat History.
- **Docker & DevOps Containerization:**
  - Viết Dockerfiles cho các dịch vụ (`rest-api-service`, `grpc-service`, `worker-service`).
  - Viết file `docker-compose.yml` liên kết toàn bộ 6 containers (SQL Server, Qdrant, Redis, REST API, gRPC, Worker).

---

### 5. PHÚC - LEGAL DOCUMENT REST API, CRAWLER ENGINE & CRON JOBS

- **Document REST API Module:**
  - Viết `Document Management Controller`: `/api/documents` (CRUD, Filter loại văn bản, hiệu lực, Pagination).
- **Crawler Engine (Thư viện Pháp luật):**
  - Viết Dịch vụ Cào dữ liệu (Web Crawler) tự động lấy văn bản, nghị định giao thông mới từ `thuvienphapluat.vn`.
- **Scheduled Cron Jobs:**
  - Triển khai Cron Job định kỳ hằng đêm (00:00 AM): Dọn dẹp session rác, quét kiểm tra văn bản luật hết hiệu lực, xuất báo cáo Usage Reports.
- **Hỗ trợ nhóm:** Tổng hợp file `README.md` và Slide thuyết trình báo cáo đồ án.

---

## 2. BẢNG TỔNG HỢP PHÂN CÔNG ĐỒNG ĐỀU

| Thành viên | Khối công việc chính | Sản phẩm bàn giao cụ thể |
| :--- | :--- | :--- |
| **Bảo** | Database & Auth REST API | SQL Database, Repositories, Services, Auth Controller, JWT Auth, Swagger |
| **Khôi** | gRPC Service & Advanced RAG | Service gRPC, Qdrant Vector DB, Verification Engine, Citations RAG |
| **Khánh** | Message Broker & Worker Consumer | Redis Pub/Sub, Worker Consumer, Quota Deduction, Email Alert Service |
| **Vương** | Chat REST API & Docker DevOps | Chat Controller, gRPC Client, Dockerfiles, `docker-compose.yml` |
| **Phúc** | Document API, Crawler & Cron Jobs | Document Controller, Web Crawler (thuvienphapluat), Midnight Cron Job |
