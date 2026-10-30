# Bản ghép C2 local — 30/10/2026

Nhánh: `codex/prn-c2-integration-local`. Bản ghép phục vụ kiểm thử và nối C2 theo `task.md`/`IMPLEMENTATION-PLAN.md` ngày 27/10. Không push, mở PR, merge remote hoặc deploy. Những báo cáo cũ trên các nhánh vẫn được giữ như bằng chứng lịch sử, không thay thế trạng thái trong tài liệu này.

## Source đã ghép

| Người | Nguồn | Commit đầu nhánh lúc ghép |
| --- | --- | --- |
| Vương | Local `PRN-VUONG-dev`, gồm schema/host C2 chưa push | `4da20f4` |
| Bảo | `origin/PRN-BAO-dev` | `4575385` |
| Phúc | `origin/PRN_Phúc_ASM` | `3992c2c` |
| Khánh | `origin/prn-khanh-dev` | `289acd4` |
| Khôi | `origin/PRN-KHOI-dev` | `74c4b04` |

Merge commits riêng: `d08b885` (Bảo), `70cacfc` (Phúc), `72b4605` (Khánh), `dba0c23` (Khôi). Lịch sử source và migrations được giữ. Các nhánh gốc không bị reset/rewrite.

## Phần tích hợp đã bổ sung

- Hai host User/Content tiếp tục dùng hai SQL DB độc lập; controller nội dung chỉ xuất hiện trên Content. Không đăng ký runtime `ChatAIWebDbContext` hoặc join xuyên DB.
- Tách tên package import `ContentBank`/`ContentQuestionOption`/`IContentBankRepository` khỏi model/repository legacy của Bảo. Các type legacy được giữ cho migration/test chuyển tiếp.
- Adapter `SqlContentBankRepository` lưu draft/published question bank vào Content SQL, transaction và kiểm hash; không dùng file bank làm runtime source. Metadata import/profile/nguồn nằm trong JSON hiện có, không tạo thêm bảng bank song song.
- Manifest C2 dùng revision nội bộ nguyên dương; mỗi câu có một đáp án, `CategoryType` là `SIGN` hoặc `SCENARIO`, option IDs tối đa 30 ký tự. ID câu hỏi là ID của row version bất biến; nhập revision khác cần row IDs chưa bị dùng. Không tự ép source version dạng chuỗi thành số hoặc âm thầm bỏ đáp án.
- Pool chứa key chỉ trả qua `GET /internal/content/exam-questions`, cần service JWT `content.read`. `categoryId` có dạng bank GUID hoặc `bankGuid:categoryGuid`; client làm bài chỉ nhận projection không có key/lời giải/animation.
- Kết quả lưu qua `ExamResultService` vào `ExamAttempts`: hash submission, snapshot câu/options/ảnh/đáp án/lựa chọn/profile và thời gian. Retry cùng AttemptId/content thành công; payload khác trả 409. SQL khóa/transaction bảo vệ concurrent retry.
- `POST /internal/user/exam-results` cần service JWT `exams.write`; Worker dùng JWT ngắn hạn thay internal API key. Public Gateway chặn `/internal`.
- `GET /api/exam-attempts/{id}` kiểm owner và xem lại snapshot sau khi Redis mất/hết TTL. Progress/history đọc snapshot User SQL; danh mục từ Content HTTP, không dùng adapter đọc Content tables trong User process. Account quota/report dùng User DB.
- Auth giữ expiry refresh tuyệt đối của nền C2, đồng thời nhận security stamp từ Bảo: đổi password hash làm refresh cũ không hợp lệ. Logout vẫn là client-side; không có token table hoặc per-device revocation.
- Proto được hợp nhất theo cách giữ field numbers của chat v2, thêm RPC/field Khôi ở số mới. Python trả contract version/status/images/hash/Điểm/version đúng phía .NET, xử lý ảnh và lịch sử. Unknown provider usage không bị biến thành usage ước lượng thành công.
- Embedding bắt buộc API cấu hình rõ, kiểm batch/dimension. Runtime Qdrant không fallback RAM; generation/vision lỗi không tổng hợp hoặc giả quan sát local. Seed luật không tự chạy khi khởi động. Unit tests chủ động inject fake providers/client in-memory.
- Index gửi document/chunk/hash/Điểm/version. Expiry thu hồi SQL trước rồi gọi deactivate Qdrant; lần chạy sau thử lại tập hết hạn nếu RPC lỗi. Scheduler ở Worker gọi Content API với scope riêng `content.maintain`, có startup catch-up và lịch nửa đêm Việt Nam.
- Compose nối User/Content/Redis/Kafka/Worker và topics exam thực tế; sửa overlay cũ trỏ nhầm service/network. Worker vẫn bật bằng profile `worker`.
- Web shell nối thư viện, văn bản, Admin preflight/import/publish, progress/account và trang thi. Trang thi dùng request bridge cùng origin qua API client của shell để dùng auth/refresh chung, không yêu cầu nhập JWT. Gateway cho phép frame cùng origin; static default document `/exams/` được đăng ký.
- `ExplanationAnimationUrl` có thể nhập vào câu và lưu Content SQL sau kiểm exact-host HTTPS; chỉ nằm trong snapshot review, không trả qua active-exam projection. Chưa có animation thật được deploy trong lượt này.

## Bằng chứng kiểm tra

Các dữ liệu bank/câu hỏi/nguồn trong kiểm thử đều là **synthetic fixtures**, không phải luật hoặc bank chính thức.

| Kiểm tra | Kết quả |
| --- | --- |
| `dotnet build ChatAIWeb.slnx` | 0 lỗi/cảnh báo |
| ChatAIWeb.Tests | 63 pass, 0 skip; gồm SQL concurrency và HTTP auth/account/report |
| Content.Tests | 51 pass |
| BusinessLogic.Tests | 9 pass |
| C2.Integration.Tests | 1 pass với SQL Server, Redis, Kafka thật |
| Python `pytest grpc_inference_service/test_unit.py` | 10 pass; providers được mock, không chứng minh gọi cloud thật |
| `node --test tests/content-animation.test.mjs` | 4 pass |
| `npm --prefix web run build` | TypeScript/Vite build thành công |
| EF pending model, User/Content contexts riêng | Không pending; không chỉnh/sinh migration mới |

Integration test chạy hai SQL databases `C2MergeUser_<GUID>`/`C2MergeContent_<GUID>` mới, apply migrations riêng, và xóa đúng DB test do test tạo khi kết thúc. Luồng: Admin import/publish SQL → Content service-auth pool → Redis create/autosave/deadline → submit/scoring → User SQL → Kafka broker → notification Worker → Redis inbox. Test kiểm owner isolation, không lộ key/lời giải, giữ TTL/deadline, idempotent/concurrent save và conflict, review sau xóa Redis, progress/report, ảnh/animation snapshot và scope maintenance.

Kiểm tra trình duyệt qua Gateway thật: đăng ký/đăng nhập fixture, Admin xem trước/lưu draft/publish, chọn bank, làm/nộp bài **1/1**, desktop và mobile 390×844. Đây là walkthrough nội bộ, không phải user research. Ảnh: `output/playwright/c2-learning-desktop.png`, `c2-learning-mobile.png`, `c2-exam-desktop.png`, `c2-exam-mobile.png`.

TRX/log đầy đủ ở `artifacts/test-results/`, `artifacts/c2-final-checks.log`, `artifacts/c2-final-module-check.log`; generated files/venv không commit. SQL test lâu dài `TrafficUser_C2_MergedVerify_20261030`, `TrafficContent_C2_MergedVerify_20261030` và `TrafficUser_C2Tests_<GUID>` được giữ để review; không apply lên DB legacy hoặc DB dùng chung.

## Chạy lại

Docker Desktop cần đang chạy. Dựng riêng hạ tầng local test, bind loopback Redis 16379 và Kafka 19092:

```powershell
pwsh -File scripts/start-c2-test-infrastructure.ps1
pwsh -File scripts/test-c2-merged.ps1 -SqlServerConnection 'Server=.\MSSQLSERVER_VUON;Trusted_Connection=True;TrustServerCertificate=True;Encrypt=False'
```

Thay server connection cho máy khác; không truyền Database/Initial Catalog vào verifier. Script tạo User DB test riêng, giữ lại để review. API integration test tự tạo/xóa DB riêng; các SQL tests legacy cũng chỉ dùng tên test ngẫu nhiên. Dừng đúng containers test, giữ volumes:

```powershell
pwsh -File scripts/start-c2-test-infrastructure.ps1 -Stop
```

Chạy ứng dụng bằng các launch profile trong `C2-SCHEMA-CONTRACT.md` với UserConnection/ContentConnection đã chuẩn bị; đặt `Database:MigrateOnStartup=false`. Cấu hình thêm Redis, `Exams:Kafka:BootstrapServers`, `Exams:Kafka:Topic=exam-submitted-events`, ContentService:Address và JWT chung cho các host/Worker qua secrets/env. Worker `Exams:UserBaseUrl` trỏ User host, SaveResultPath mặc định `internal/user/exam-results`. Web dev proxy mặc định Gateway 8080/User 5039, có thể đổi bằng `C2_GATEWAY_URL`/`C2_USER_URL`.

Embedding nhận endpoint HTTPS tương thích `/embeddings` (request model/input/dimensions; response data/index/embedding) qua `EMBEDDING_API_URL`, `EMBEDDING_API_KEY`, `EMBEDDING_MODEL`, `EMBEDDING_DIMENSION`; không tự chọn provider/model. Generation/vision tiếp tục nhận provider config của module Khôi. Không đưa keys vào Git.

## Còn lại trước nghiệm thu toàn bộ C2

- Chưa chứng minh AI generation/vision/embedding API thật hoặc retrieval Qdrant thật với dữ liệu luật đã kiểm chứng. Bộ registry verification cũ cần Khôi/Phúc rà lại hiệu lực/bằng chứng hiện hành; không dùng nó như bằng chứng pháp lý mới. Crawl nguồn từng gặp 403, chưa có bộ luật/bank chính thức được nghiệm thu.
- SQL templates/items đã có schema/repository nền nhưng chưa có đầy đủ authoring/import đề mẫu chuẩn. Custom exam hiện giữ nguyên pass threshold của profile; chưa tự scale threshold khi chọn N khác profile. Bộ lọc topic/range trong thư viện phục vụ xem câu, chưa dùng chọn đề custom; UI yêu cầu bỏ bộ lọc trước khi bắt đầu.
- Chưa deploy/kiểm animation HTTPS thật. Asset snapshot lưu URL/hash/alt, không chứng minh hosting tồn tại hoặc file từ xa giữ nguyên sau này.
- Notification exam đã chạy thật qua Kafka/Worker. Outbox bảo đảm phát event sau khi Redis mất vẫn chưa có; cửa sổ SQL commit → Kafka ack còn phụ thuộc Redis retry/retention như contract Khánh. Chưa chứng minh đủ document-published/invalidation events giữa hai application services hoặc monitoring/dashboard toàn stack.
- C2 không có bookmark table; endpoints legacy trả 501 trong host mới, không đăng ký repository xuyên DB để giả hỗ trợ. Query progress hiện parse snapshots theo user trong bộ nhớ; cần tối ưu nếu dữ liệu lớn.
- Chưa chuyển dữ liệu legacy, migration production, build/chạy toàn bộ Compose/monitoring stack, hoặc deploy. Không đánh dấu mọi task của năm người là done chỉ từ bản ghép này.

App/browser hosts dùng cho walkthrough đã dừng sau kiểm tra. Hạ tầng test có thể khởi động lại bằng script phía trên. Không thay trạng thái remote.
