# Bàn giao module Phúc — 26/10/2026

> **Tài liệu lịch sử theo plan 24/10.** Từ C2 ngày 27/10, SQL Content/Exam là nguồn bank chính; adapter file không còn đăng ký cho runtime. Trạng thái mới và task IDs: [PHUC-C2-PROGRESS-2026-10-28.md](PHUC-C2-PROGRESS-2026-10-28.md). Không áp dụng mục persistence tạm dưới đây như kiến trúc hiện hành.

Branch: `codex/phuc-content-learning`, từ nền local `PRN-dev` tại `3a50502`.

## Phạm vi đã code và phần phụ thuộc

| Task | Code trong nhánh | Còn cần tích hợp/nghiệm thu |
| --- | --- | --- |
| P01 | Crawler dùng repositories, giới hạn nguồn HTTPS, lấy số hiệu/toàn văn thật; tách Điều/Khoản; lưu một văn bản + chunks mỗi transaction; dedupe source/số hiệu. Crawl job có trạng thái durable, lỗi trả ProblemDetails, restart nhận diện Interrupted. | Chạy selector trên nguồn thật và SQL thật. Job hiện chạy đồng bộ, retry bằng request mới; chưa có hàng đợi/lease liên máy. |
| P02 | Verify/index orchestration, bắt buộc Admin review nguồn/sửa đổi/ngày UTC và RPC Verified; chỉ kích hoạt SQL sau ack đủ chunks; chunk/vector ID ổn định khi retry; SQL expiry vô hiệu hóa chunks. | **Index tắt mặc định.** Cần K03/K04 evidence verifier/version/deactivate, V02 recheck SQL và H01/H02 pending events/relay trước khi bật. Chưa bảo đảm atomic SQL/Qdrant, chưa có reconciliation/outbox. |
| P03 | Manifest bank/profile/options/key/assets; kiểm tra ID/version/source, pool/profile, duplicate, answer key, MIME/hash ảnh, shuffle policy. | Chưa có ngân hàng/profile chính thức được chọn; chưa tải/lưu/kiểm hash bytes ảnh. Admin phải đối chiếu ảnh và nguồn trước publish. |
| P04 | Admin import/list/preview/publish; immutable versions/hash, optimistic publish; published bank/questions filtering/range/paging; exam-template profile listing. Public DTO không chứa đáp án/lời giải. | B02 quyết định persistence cuối; H04/H05 attempt snapshot và engine dùng repository nội bộ lấy key, không thêm key vào public API. Template hiện là profile của từng bank/version, chưa có template chọn pool riêng. |
| P05 | Handler expiry idempotent ở BusinessLogic; REST host tạm chạy khi startup và 00:00 Việt Nam, retry khi lỗi; không xóa chat/pending work. Không cache nội dung nên published reads thấy publication ngay. | Khánh chuyển handler sang Worker. Reverify cần K03; usage report cần B05; cleanup cần retention/pending contracts. Không thực hiện xóa dữ liệu khi thiếu contract này. |
| P06 | React/TS library luật, questions topic/range/N, Admin import/preview/publish, loading/error/empty/paging; callback nối Practice API. | Ghép web shell V04/auth của Bảo; nối callback Practice và Progress/AI explanation khi các API tồn tại. Chưa nghiệm thu UI xuyên luồng học/thi. |

## Quyết định persistence tạm thời

Giữ nguyên 7 bảng core và DbContext, không tạo migration. `QuestionBank`, `CrawlJob` là content-package models, không đăng ký EF. File adapters nằm trong DataAccess; BusinessLogic dùng interfaces. Đây là adapter chạy local/single-instance để kiểm tra import/publish, **không phải quyết định schema B02 hay thay đổi teacher scope**.

- Mặc định lưu private dưới `Presentation/App_Data/question-banks` và `Presentation/App_Data/crawl-jobs`, ngoài wwwroot, đã gitignore.
- Cấu hình `Content__BankStoragePath` bằng đường dẫn tuyệt đối khi triển khai. Mount persistent volume và backup cả packages lẫn markers; không dùng container filesystem tạm.
- Gói immutable được ghi file tạm rồi atomic move không overwrite; marker publication riêng có hash và ngày UTC. Concurrent imports khác nội dung cùng version trả 409; import/publish retry cùng hash idempotent.
- Mỗi lần đọc package kiểm lại content hash. SHA-256 ở API tính từ JSON serialization của typed model, **không phải raw bytes của file upload**; dùng hash trả từ preview khi publish.
- Adapter bank hỗ trợ nhiều writer trên cùng local filesystem có atomic rename. Crawl gate chỉ trong một process; chưa hỗ trợ nhiều REST replicas, distributed leases hay network filesystem semantics.
- Bảo có thể thay `IQuestionBankRepository` / `ICrawlJobRepository` khi thống nhất persistence. Không đưa attempts/answers/attachment vào ChatMessages.

## API

Tất cả bank APIs cần JWT; `/api/admin/*`, crawl và verify/index cần role Admin.

| Method/path | Payload/kết quả |
| --- | --- |
| POST `/api/documents/crawl-jobs` | Chạy đồng bộ; trả job `Completed`; lỗi 502 chứa job ID, trạng thái `Failed` được lưu trước khi trả lỗi. |
| GET `/api/documents/crawl-jobs/{id}` | Running/Completed/Failed/Cancelled/Interrupted. |
| POST `/api/documents/crawl-trigger` | Alias tương thích, dùng cùng durable job service. |
| POST `/api/documents/{id}/verify-and-index` | `evidenceUrl`, `effectiveDate` UTC, `expirationDate` UTC tùy chọn, `reviewNotes`, `sourceAndAmendmentsReviewed=true`. Mặc định 503 do integration gate. |
| POST `/api/admin/question-banks/import` | `{ "bank": <manifest> }`, tối đa 10 MB. |
| GET `/api/admin/question-banks` | Draft + published summaries. |
| GET `/api/admin/question-banks/{id}/versions/{version}/preview` | Full manifest gồm keys, hash và validation errors; chỉ Admin. |
| POST `/api/admin/question-banks/{id}/versions/{version}/publish` | `{ "expectedHash": "<hash từ preview>", "sourceAndAnswersReviewed": true }`. |
| GET `/api/question-banks` | Chỉ published summaries. |
| GET `/api/question-banks/{id}/versions/{version}/questions` | `topic`, `from`, `to`, `page=1`, `pageSize=20` (max 100). Không keys/explanations. |
| GET `/api/exam-templates` | Published bank ID/version/hash + profile. |

Manifest dùng camelCase:

```text
id: GUID, version: [A-Za-z0-9._-]{1,64}, title, sourceUrl: HTTPS, sourceDescription
profile:
  id, version, sourceUrl, questionCount, durationSeconds, passCount, failOnCriticalWrong
questions[]:
  id: GUID, number: positive unique integer, topic, text, explanation, sourceUrl
  isCritical, allowOptionShuffle (mặc định false)
  options[]: { id: stable string, text }
  correctOptionIds[]: option IDs, không phải vị trí/nhãn hiển thị
  assets[]: { id, url: HTTPS, sha256: 64 hex, mimeType, altText }
```

Profile là dữ liệu có nguồn/version do Admin review; không hard-code quy tắc giấy phép. Chặn opt-in shuffle khi câu có ảnh hoặc nhận diện tham chiếu nhãn; heuristic không chứng minh mọi câu còn lại an toàn, nên mặc định false. Không có LLM tự tạo key hay chấm pass/fail.

Fixtures trong `tests/Content.Tests` dùng `example.org`, có nhãn TEST, không tự import vào API/demo. Không đánh dấu dữ liệu tổng hợp là nguồn chính thức.

## Chạy và tích hợp UI

```powershell
dotnet build ChatAIWeb.slnx
dotnet test tests/Content.Tests/Content.Tests.csproj
dotnet ef migrations has-pending-model-changes --project DataAccess --startup-project Presentation
dotnet run --project Presentation --launch-profile http
cd web
npm ci
npm run build
npm run dev
```

API cần JWT secret local theo AGENTS.md. API chạy mặc định migrate SQL; chỉ chạy với DB/config được chuẩn bị. Build/tests/model-check không apply migration. Vite proxy `/api` tới `http://localhost:5039`; không nhúng secret vào frontend.

`web/src/content-main.tsx` là preview host tối thiểu vì nền chưa có web shell. Nhập access token Auth API để xem; token chỉ trong memory. Admin tab vẫn do backend role enforcement. Vương có thể nhập trực tiếp các components sau vào router chính, bỏ preview host:

- `QuestionLibrary({ api, onStartPractice })`: api là authenticated fetch client; callback nhận `{ bankId, bankVersion, count, topic?, from?, to? }`. Chưa giả định request body của Practice API; engine tự snapshot và kiểm đủ pool phía server.
- `LegalLibrary({ api })`: Documents API thật.
- `AdminContent({ api })`: import JSON, preview đầy đủ, hash và review confirmation, publish.

Không có callback thì nút luyện bị disable và giải thích phụ thuộc; không dùng kết quả thi giả. Chưa nối Progress API hay AI explanation API vì nền chưa có các contracts đó.

## Xác minh và giới hạn

Đã chạy build .NET sạch, 21 tests pass (parser/source restriction, SQL workflow qua EF InMemory, expiry idempotence, durable crawl failure, publish/concurrency/restart/hash/key hiding, HTTP User/Admin/ProblemDetails), TypeScript/Vite production build và EF không pending model changes. Test HTTP dùng TestServer/test-only auth, không thay auth production.

Chưa chạy SQL Server/Kafka/Qdrant/gRPC/API providers/SMTP thật, chưa crawl/import dữ liệu chính thức, chưa browser QA. Những kiểm thử này không chứng minh phần tích hợp hoặc demo đã xong. Integration gate `Content:EnableVerifiedIndexing=false` chỉ được bật sau khi nhóm hoàn thành điều kiện P02 ở trên; không bật chỉ để lấy kết quả success.
