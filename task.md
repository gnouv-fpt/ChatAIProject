# PHÂN CÔNG NHIỆM VỤ DỰ ÁN (TASK.MD)

## ĐỒ ÁN PRN232: HỆ THỐNG RAG TƯ VẤN PHÁP LUẬT GIAO THÔNG ĐƯỜNG BỘ

---

## 1. PHÂN CÔNG NHIỆM VỤ THEO THÀNH VIÊN (5 THÀNH VIÊN)

### 1. BẢO - DATABASE & AUTH REST API (BACKEND CORE)

- **Database & Architecture:**
  - Khởi tạo Database SQL Server (`ChatAIWebDb`), viết DbContext và Entity Classes (`User`, `LegalDocument`, `DocumentChunk`, `ChatSession`, `ChatMessage`, `Citation`, `ViolationLog`).
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
