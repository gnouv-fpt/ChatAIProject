# Vương — implementation và bàn giao, 24/10/2026

Nhánh làm việc: `PRN-VUONG-dev`, lấy nền tích hợp `3a50502` của `PRN-dev`. Bản triển khai được phát hành trên nhánh cá nhân; chưa merge về PRN-dev, chờ các module liên quan đủ contract để tích hợp. Đây là trạng thái thực hiện thay cho các checkbox Redis/fallback cũ trong `scripts/VUONG_PROGRESS.md`.

## Trạng thái V01–V06

| Task | Đã code/kiểm tra | Còn phụ thuộc |
| --- | --- | --- |
| V01 | Nền ghép, DI, Gateway và tests đăng ký trong solution; build .NET sạch | Review shared contracts với owners trước merge |
| V02 | Request identity + payload hash, SQL user lock, reservation/lease/fencing/recovery; lưu user/assistant/citation/outbox cùng transaction; replay trả cùng message; kiểm tra citation SQL/hash/nguồn/hiệu lực cả completion và replay; lỗi RPC thành ProblemDetails | AI v2 của Khôi; relay/settlement của Khánh/Bảo; đối soát usage không biết sau timeout/crash |
| V03 | Upload/read/delete private theo user/session; quota dung lượng, giới hạn stream, MIME/signature/hash; retention, follow-up ảnh; ánh xạ ảnh/history sang gRPC | Vision API thực và `images_processed` của Khôi; đây chưa phải bằng chứng AI hiểu ảnh |
| V04 | React/TypeScript shell/router/API client; login/register/logout/refresh; lịch sử/tìm/phân trang/xóa; chat/ảnh/citation/loading/error/retry; responsive/mobile drawer | Routes học/thi/progress/admin của owners; AI thực để nghiệm thu câu trả lời trên UI |
| V05 | YARP Gateway/rate limit; Dockerfiles API/Gateway/web; Compose SQL/Qdrant/Kafka/init/optional Redis/Worker profile; env/secrets/volumes/readiness | Worker image thật; AI provider/index hợp lệ; profile gRPC hiện còn code nền cũ |
| V06 | Prometheus/Loki/Alloy/Tempo/Grafana provisioning + dashboard; script HTTP thực; kiểm tra được trace Gateway→REST và file logs | Kafka→Worker settle/email, trace phía Python/Worker và kiểm tra lag drain sau restart |

## Chạy và kiểm tra

Local: cấu hình user-secrets bằng `scripts/setup.ps1`, trỏ SQL riêng phù hợp. Mở ba terminal:

```powershell
pwsh -File scripts/start-vuong-local.ps1 api
pwsh -File scripts/start-vuong-local.ps1 gateway
cd web
npm ci
npm run dev
```

Mở `http://127.0.0.1:5080`. API trực tiếp `http://localhost:5039/swagger`. Các token frontend nằm trong memory; reload tab yêu cầu đăng nhập lại. Refresh tự động trong phiên hiện tại, không lưu token vào localStorage. Proxy dev của Vite tới Gateway; Gateway tới REST, không tạo vòng lặp `/api`.

Docker: copy `.env.example` sang `.env`, tạo mật khẩu SQL/JWT/Grafana riêng, điền provider keys qua environment. REST và DB không publish ra host; Gateway/Grafana bind loopback. Mặc định `MIGRATE_ON_STARTUP=false`. Chỉ bật với DB mới hoặc sau khi review/backup: migration nền `RemoveUnnecessaryReportingTables` vẫn có thao tác xóa hai bảng cũ. Không áp migration lên DB đang dùng trong lần làm này.

```powershell
docker compose config -q
docker compose --profile monitoring up -d --build
# Khi Khánh đã bàn giao Worker image tương thích:
docker compose --profile worker --profile monitoring up -d
```

`worker-service` dùng image bàn giao qua `WORKER_IMAGE`, không có echo placeholder. Redis ở profile `cache`; REST không còn đăng ký RedisEventPublisher hay publish giả. Kafka topics được init idempotently; pending event còn trong SQL nếu broker/relay chưa chạy.

```powershell
dotnet build ChatAIWeb.slnx
dotnet test tests/ChatAIWeb.Tests
dotnet ef migrations has-pending-model-changes --project DataAccess --startup-project Presentation
cd web
npm run build
npm audit
```

Tests mặc định dùng SQLite và fake inference **chỉ trong tests**. Đặt `VUONG_TEST_SQL` thành connection string **SQL riêng dành cho tests** để chạy migrations và cả hai bài kiểm tra đồng thời qua các DbContext độc lập. Tests có tạo dữ liệu fixture, không dùng DB production. Connection string không được đưa vào command output.

```powershell
# Smoke trên môi trường riêng; script tạo tài khoản thử, session và ảnh thử.
python scripts/verify-vuong.py --base http://127.0.0.1:8080 --expect-ai-unavailable
# Chỉ dùng mode này khi có AI + chunks SQL/Qdrant nguồn thật:
python scripts/verify-vuong.py --base http://127.0.0.1:8080
```

Mode AI-unavailable yêu cầu 503 và kiểm tra lịch sử không có câu trả lời giả. Mode RAG yêu cầu `Answered` + citation, replay cùng ID và 409 khi đổi prompt. Script chưa kiểm tra Kafka/Worker/balance; phải đối chiếu EventId, SQL, broker ack và consumer lag sau khi module đó được bàn giao.

## Shared contract cần owners review

Giữ đúng bảy bảng core; không tạo bảng learning/attachment/violation/report. Hai migration mới là additive: `ChatTurnDurability`, `ChunkPointMetadata`. Metadata ảnh lưu JSON riêng cùng bytes trong private volume, không có URL public/base64 trong SQL. Shared changes tối thiểu cần thiết để V02 chạy được; Bảo cần hợp nhất vào schema/state cuối của nhóm, không tạo thêm migration trùng các cột.

- `ChatMessages.RequestId`: UUID phía client, unique cùng SessionId (filtered non-null). User message có RequestId null; assistant turn là record điều phối. Cùng ID khác prompt/ảnh/chính sách kế thừa ảnh → 409. Đổi prompt có chủ đích phải dùng ID mới.
- `RequestHash`: SHA256 của normalized prompt, IDs ảnh sort/distinct và `UsePreviousAttachments`. `RequestContext`: IDs ảnh thực tế, bao gồm ảnh được kế thừa. Không lưu image bytes.
- `TurnState`: null = message cũ, Processing / Failed / Completed. `LeaseId` fencing; TTL inference timeout + 30s. Failed hoặc lease hết hạn có thể retry cùng ID. Inference chạy ngoài transaction; completion kiểm tra lease và quyền/hiệu lực lần nữa.
- User lock: SQL `UPDLOCK,HOLDLOCK` trên Users trong transaction Serializable ngắn, dùng cùng lock order cho reserve và settle. Reservation khả dụng tính từ **TokenBalance trong SQL**, trừ các lease còn hiệu lực và Completed chưa settle; không đọc số dư trong JWT. Completed giữ actual usage tới khi Worker settle. Provider overrun vẫn giữ actual usage, có thể vượt balance: Bảo cần chính sách debt/reconciliation; không âm thầm clamp/bỏ usage.
- Timeout/cancel/provider error release reservation, lease expiry phục hồi trường hợp process chết. **Chưa đối soát được provider đã tính phí nhưng response bị mất, usage âm/unknown hoặc DB không commit sau AI.** Cần Bảo/Khôi cung cấp usage lookup/idempotency theo RequestId trước khi coi quota hoàn tất nghiệp vụ. Replay SQL ngăn trả/lưu trùng; không hứa AI provider gọi exactly-once qua crash.
- Result/user message/citations/`EventPayload` commit cùng transaction. `EventId = MessageId = assistant.Id`; `RequestId`, SchemaVersion 1, TraceParent được lưu. Payload đang PascalCase qua System.Text.Json; consumer phải đọc đúng hoặc case-insensitive. Event không được ghi vào logs.
- Khánh relay đọc EventPayload chưa EventPublishedAt, publish topic `chat-completed-events`, key UserId; chỉ đánh dấu published sau broker ack. Crash sau ack có thể publish lại cùng EventId. Worker lock user rồi kiểm tra QuotaSettledAt; balance deduction + marker trong **cùng** transaction; broker offset sau commit. Email retry độc lập, không lặp quota. Không purge/cleanup message còn pending.
- Proto nguồn `Protos/chat_inference.proto`; bản copy trong Python phải giống. Field numbers cũ giữ nguyên. Python v2 cần trả `contract_version=2`, result_status hợp lệ, usage thực, images_processed đúng; citation bắt buộc SQL chunk UUID + SHA256 UTF-8 content + metadata Điều/Khoản/Điểm/nguồn. Index payload bổ sung Point/ContentHash/DocumentId. Hash là content version cho lần snapshot này, chưa thay thế version workflow của Phúc/Bảo.
- .NET từ chối AI server cũ thay vì nhận kết quả thiếu evidence. Python server nền **chưa triển khai** fields v2/vision; không đổi thuật toán/provider của Khôi trong task Vương. Khi triển khai ảnh cần gRPC server max receive ít nhất 20 MiB; .NET client đã cấu hình. Không trả `images_processed=true` nếu chưa thực sự dùng ảnh. Không log prompt, ảnh/base64, key hay signed URL phía Python.
- Citation chỉ chấp nhận chunk/document verified, active, đang hiệu lực, HTTPS thuộc thuvienphapluat.vn; title/source/Điều/Khoản/Điểm/hash/excerpt khớp SQL. Replay không gọi AI hay phát event mới; nếu căn cứ thay đổi thì 409 và cần câu hỏi mới. History là snapshot đã lưu, không phải một lần xác thực pháp luật mới.
- AttachmentRoot phải là thư mục private ngoài webroot; giới hạn mặc định 3 ảnh, 5 MiB/ảnh, 50 MiB/user, TTL 24h, sweep 15 phút. Không dùng tên file client làm đường dẫn. Signature/MIME/hash checks không phải antivirus hay full image decoder. Một shared volume giữa các REST replica; chuyển S3/object storage phải thay IAttachmentService và lock/quota tương ứng.
- Legacy cron Phúc vẫn giữ dưới `Jobs:EnableLegacyMidnight` (mặc định true) để không làm mất chức năng đang có; đặt false khi Khánh/Phúc chuyển cron sang Worker. Hạn chế timezone/EF của job nền cũ vẫn thuộc phần bàn giao của hai bạn đó.

## Monitoring

REST `/health/ready` kiểm tra SQL kết nối và migrations; **không** khẳng định AI/index/Worker sẵn sàng. Python Compose health chỉ kiểm tra TCP. `/health/live` dùng liveness. Metrics REST/Gateway chỉ nằm trên network nội bộ trong Compose; không proxy `/metrics` REST ra ngoài.

Dashboard `Traffic RAG · Integration` có service health, HTTP rate/error, chat latency p95, completed usage, durable pending/unsettled và Kafka lag. Không có consumer thì lag có thể chưa có series. Mỗi module phải thêm metrics/trace thật khi bàn giao. Không dùng số liệu mẫu thay dữ liệu thiếu.

SafeFileLogger lưu JSON metadata + allowlist MessageId/RequestId/ResultStatus/TokensUsed/Status/ExceptionType, trace/span; không serialize formatted text/body/exception details/scopes. Daily files trong logs volume; hệ thống vận hành cần cấu hình retention log. Alloy→Loki, OTLP→Tempo; Grafana datasources/provisioning nằm trong `monitoring/`.

Tham chiếu triển khai: [YARP rate limiting](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/servers/yarp/rate-limiting), [OpenTelemetry .NET](https://learn.microsoft.com/en-us/dotnet/core/diagnostics/observability-with-otel).

## Bằng chứng đã chạy

- .NET build: 0 warnings/errors; EF không pending model changes.
- 33 tests pass trên SQL Server riêng, gồm concurrent duplicate/quota; mặc định SQLite: 31 pass, 2 SQL-only skip.
- Frontend TypeScript/Vite build pass; npm audit không có vulnerability tại lần kiểm tra.
- Docker API/Gateway/web build pass; Compose config hợp lệ.
- 19 bước HTTP pass ở local Gateway và Docker Gateway với SQL thật, mode AI unavailable. Không có success RAG/vision thật trong lần này.
- Browser thật: đăng ký, vào chat, gửi câu hỏi → thông báo AI unavailable + retry, desktop/mobile và history drawer. Đây là UI/data thử; không có ảnh AI tạo hay câu trả lời pháp luật giả.
- Readiness 200; endpoint metrics REST/Gateway có samples; rate limit 15 login requests trả 10×400 và 5×429.
- Monitoring Docker: Prometheus REST/Gateway up=1, Grafana dashboard provisioned, Loki có file-log streams; một trace có cả api-gateway và rest-api-service trong Tempo.
- Kafka Docker healthy; init tạo đủ ba topics chat-completed-events/document-updated-events/chat-completed-events-dlq; exporter chạy. Chưa có Worker consumer nên chưa có bằng chứng lag tăng/giảm.
- Kafka/Worker end-to-end và usage reconciliation vẫn cần nghiệm thu sau khi module nhóm sẵn sàng.

Bằng chứng máy đọc được: [HTTP smoke](evidence/vuong-2026-10-24/http-smoke.json), [SQL tests](evidence/vuong-2026-10-24/sql-tests.json), [monitoring](evidence/vuong-2026-10-24/monitoring.json). Kiểm tra lại monitoring: đặt GRAFANA_PASSWORD qua environment rồi chạy `python scripts/verify-monitoring.py`.
