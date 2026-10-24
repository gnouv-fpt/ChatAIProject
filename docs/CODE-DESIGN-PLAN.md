# Plan thiết kế code theo C0, C1, C2

**Phân công và mốc code hợp nhất hiện hành: task.md và IMPLEMENTATION-PLAN.md.** Tài liệu này giữ phần giải thích kiến trúc/core; dùng bản hợp nhất khi scope/phân công khác nhau.

Ngày đối chiếu: 24/10/2026. Đây là kế hoạch triển khai dựa trên tài liệu và source hiện tại, chưa phải xác nhận hệ thống chạy đầy đủ.

**Bổ sung sau khi kiểm tra các nhánh remote:** đã fetch origin và build riêng PRN-BAO-dev, PRN-KHOI-dev, PRN-VUONG-dev, PRN-PHUC-dev; cả bốn build .NET thành công, 0 warning/error. Documents API, crawler và cron đã có trong nhánh Phúc, cần tích hợp và hoàn thiện thay vì viết mới. Python/proto của Khôi đã có nguyên trong nhánh Vương. Các dòng “chưa có” ở phần khảo sát checkout bên dưới chỉ mô tả nhánh đang mở, không đại diện toàn bộ repository. Xem `BRANCH-AUDIT-2026-10-24.md` để biết commit, kết quả và kế hoạch ghép nhánh đã điều chỉnh.

## 1. Tài liệu đã đọc và thứ tự áp dụng

- Hai ảnh gốc trong thư mục cha `Assigment`: `Diagram PRN232-C0 -_ C1.drawio.png` và `Diagram PRN232-C2 — Database ERD Diagram.drawio.png`.
- `C4 - Vietnam Traffic Law RAG System.html` trong thư mục cha; `ARCHITECTURE.md` trong repository.
- `docs/design-review`: bản draw.io, mô tả luồng và review SQL/Qdrant.
- `AGENTS.md`, `requirement.md`, source .NET/Python, protobuf và Docker Compose.

Ảnh C0/C1 gốc có API Gateway riêng, REST API, Python gRPC, Worker chứa crawler/cron, Kafka, Redis cache, SQL và Qdrant. Ảnh C2 mô tả cấu trúc SQL và vector DB. Giữ cách gọi C0/C1/C2 của nhóm khi đối chiếu; ERD không thay thế sơ đồ thành phần xử lý.

Ưu tiên ràng buộc mới trong AGENTS.md/requirement.md khi tài liệu mâu thuẫn. ARCHITECTURE.md và HTML còn mô tả Redis broker; ảnh gốc và requirement đã có Kafka. Không lấy các ô “100%” trong tài liệu làm bằng chứng hoàn thành.

## 2. Các quyết định thiết kế đề xuất

1. Kafka là broker. Redis phục vụ cache/rate limit như ảnh C1, không thay Kafka.
2. Giữ Gateway thành process/container riêng theo ảnh gốc. Gateway định tuyến, giới hạn lưu lượng và truyền trace; REST vẫn tự xác thực JWT và kiểm tra quyền sở hữu. Không đưa CRUD/nghiệp vụ vào Gateway.
3. REST giữ cấu trúc Presentation → BusinessLogic → DataAccess → BusinessObject. Worker là host riêng gọi service nghiệp vụ trong BusinessLogic, không gọi controller hoặc tham chiếu Presentation.
4. Crawler/cron chạy trong Worker. REST chỉ tiếp nhận yêu cầu, ghi nhận công việc và trả trạng thái. Python sở hữu embedding, Qdrant, moderation, verification engine và sinh câu trả lời; không để cả .NET lẫn Python tự ghi vector theo hai cách khác nhau.
5. SQL giữ đúng 7 bảng: Users, RefreshTokens, LegalDocuments, DocumentChunks, ChatSessions, ChatMessages, Citations. Các cột bổ sung dưới đây là đề xuất cần migration, chưa có trong model hiện tại.
6. Collection giữ tên `traffic_law_documents`. Chốt model embedding, dimension và version bằng config; query và ingest dùng cùng cấu hình. Không tự đổi provider khi có lỗi.
   Cập nhật yêu cầu: generation dùng Groq API; embedding cũng dùng API provider riêng, không model local. Không fallback Ollama/SentenceTransformers/hash/local synthesis. Nhánh tham khảo akkhanh05-test-groq-api (6e4640b) vẫn còn Ollama fallback; chỉ lấy cách tích hợp API phù hợp. Đây là quyết định thiết kế mới, runtime hiện tại chưa được chuyển đổi.
7. Không mặc định dữ liệu seed/registry hard-code đã được kiểm chứng pháp lý. Không xác định được hiệu lực thì Pending và không đưa vào tập trả lời.

## 3. Khoảng cách giữa sơ đồ và source hiện tại

| Hạng mục | Quan sát từ source | Việc cần làm |
| --- | --- | --- |
| Auth | Có controller/service, JWT, refresh token, password hasher | Kiểm thử vòng đời token và phân quyền; tái sử dụng |
| Chat | Có CRUD session, gọi gRPC, lưu message/citation | Kiểm tra quota, trạng thái lỗi, trace chunk, xử lý publish bền vững |
| gRPC | Có ProcessChatMessage, VerifyLegalDocument, IndexDocument; proto được lưu ở hai nơi | Một proto nguồn; thêm contract trạng thái, chunk ID, Điểm và cập nhật index |
| Broker | RedisEventPublisher, có nhánh mô phỏng bằng log | Kafka producer thật; chỉ ghi acknowledged sau broker ack |
| Worker | Compose chạy echo placeholder; chưa có project Worker | Consumer, xử lý quota/email, relay và cron thật |
| Documents/reports | Checkout hiện tại chưa có; Documents API/service/repository, crawler và cron đã có ở PRN-PHUC-dev | Tích hợp phần Phúc, bổ sung verification/chunk/index/report còn thiếu |
| Verification | Registry tĩnh và heuristic từ nội dung | Đối chiếu metadata nguồn, ngày hiệu lực, phiên bản và sửa đổi từng phần |
| Qdrant/embedding | Có filter verified/active; có fallback RAM/hash embedding | Chế độ tích hợp dùng Qdrant/model thật; lỗi thể hiện qua health/error |
| Citations | Proto chưa có chunk ID; source lưu FK nullable | Trả chunk ID, map FK, thêm Điểm, giữ snapshot |
| Observability | Chưa có stack đích trong Compose hiện tại | File JSON, metrics, trace, collector và dashboard |
| Gateway | REST hiện đang kiêm điểm vào; chưa có host Gateway riêng | Tạo host định tuyến theo ảnh C1 |

Đã build .NET trên bốn nhánh remote sau khi bổ sung khảo sát nhánh; chưa chạy runtime end-to-end. Các nhận xét chức năng là kiểm tra source, build không xác nhận crawler/AI/broker hoạt động thực tế.

## 4. Cấu trúc code đích

```text
ApiGateway/                         # host mới: proxy/routes/rate limit/trace
Presentation/                       # REST host hiện tại
  Controllers/                      # Auth, Chats, Documents, Reports
BusinessLogic/
  Services/Interfaces/              # giữ IChatbotService, thêm document/report/job services
  Services/Implementations/         # điều phối use case, kiểm tra quyền/quota
  Infrastructure/Events/            # contracts sự kiện, envelope/version
  Infrastructure/Interfaces/        # producer, email, clock, source fetcher
  Infrastructure/Implementations/   # Kafka producer, email, crawler adapters
DataAccess/
  Repositories/                     # queries + thao tác persistence/transaction
  Migrations/
BusinessObject/
  Entities/                         # 7 entities; thêm trạng thái/cột khi cần
  Enums/
WorkerService/                      # host mới
  Consumers/                        # nhận Kafka, tạo scope, gọi BusinessLogic
  HostedServices/                   # relay từ SQL, polling job, scheduling
Protos/chat_inference.proto         # nguồn contract duy nhất
grpc_inference_service/
  moderation/
  verification/
  rag/                              # retriever, generator, embeddings, vector store
  server.py                         # adapter RPC mỏng
monitoring/                         # provisioning, dashboards, collector config
tests/                              # contract/integration/end-to-end quan trọng
```

Giữ tên IChatbotService đang có để tránh đổi tên không cần thiết. Repository không quyết định luật tính quota/hiệu lực; chỉ thực thi query/transaction được use case yêu cầu. Worker host đăng ký DI riêng, không phụ thuộc REST host.

## 5. Contract cần chốt trước khi chia việc

### gRPC

- Giữ ba RPC đang có; bổ sung RPC cập nhật/vô hiệu hóa index theo document ID và version.
- Citation trả `document_id`, `chunk_id`, tên/số văn bản, Điều, Khoản, Điểm, source URL, excerpt và version.
- Chat response phân biệt Answered, NoMatch, ModerationBlocked; lỗi hạ tầng dùng gRPC status, không giả thành câu trả lời thành công.
- Request mang request ID, giới hạn token và trace metadata; cấu hình deadline/cancellation.
- Verify request có URL nguồn, metadata hiệu lực, ngày kiểm tra, content hash. Response có trạng thái, lý do và bằng chứng nguồn; không chỉ true/false.
- Chỉ thêm protobuf field bằng số mới, không tái sử dụng field number. Sinh C#/Python từ cùng proto trong build.

### Kafka

- `ChatCompletedEvent`: EventId, SchemaVersion, ChatMessageId, UserId, SessionId, TokensUsed, IsViolation, ViolationKeywords, CreatedAt, TraceParent; giữ Prompt/Response nếu cần tương thích requirement và giới hạn kích thước.
- `DocumentUpdatedEvent`: EventId, DocumentId, DocumentVersion, ChangeType, VerificationStatus, IsActive, CreatedAt, TraceParent.
- Topic chính: `chat-completed-events`, `document-updated-events`. Dùng topic retry/DLQ tương ứng; replay giữ nguyên EventId.
- Phân biệt `document-updated-events` trong requirement với `document-indexed-events` trong ảnh: dùng topic chuẩn `document-updated-events`, ChangeType thể hiện Indexed/Deactivated/Updated; không tạo hai tên cho cùng luồng.
- Key chat theo UserId; key document theo DocumentId. Consumer group riêng cho quota và cache invalidation để mỗi chức năng nhận được event cần thiết.

## 6. Luồng chat và độ bền dữ liệu trong phạm vi 7 bảng

1. Gateway chuyển request tới REST. REST kiểm tra JWT, quyền sở hữu session và idempotency key.
2. BusinessLogic tạo request/message trạng thái Processing, giữ chỗ ngân sách token trong transaction ngắn, rồi commit trước khi gọi AI.
3. gRPC moderation → embedding → tìm chunk verified/active/đúng ngày và version → kiểm tra căn cứ → sinh câu trả lời có citation.
4. REST đối chiếu chunk/version với SQL trước khi chấp nhận câu trả lời, chặn kết quả đã mất hiệu lực trong lúc inference. Lưu kết quả, citations, token usage và trạng thái event Pending trong cùng transaction.
5. Trả kết quả sau khi SQL commit. Relay trong Worker đọc event Pending trên message, publish Kafka và chỉ ghi Published sau ack. Lỗi relay giữ Pending để retry.
6. Consumer cập nhật Users.TokenBalance và ChatMessages.QuotaProcessedAt trong cùng transaction. Nếu đã có marker thì bỏ qua trừ token. Commit DB trước khi commit Kafka offset.
7. Email cảnh báo có trạng thái retry riêng; SMTP thất bại không làm chạy lại phần trừ quota.

### Dữ liệu đề xuất trên ChatMessages

- RequestKey (unique trong phạm vi user/session theo thiết kế), ProcessingStatus, FailureCode, TokensReserved.
- EventId (unique), EventPayloadJson hoặc đủ dữ liệu bền vững để dựng lại payload, EventPublishedAt, PublishAttempts/NextPublishAt.
- QuotaProcessedAt; EmailStatus, EmailAttempts/NextEmailAt; lease phục vụ claim relay nếu chạy nhiều instance.
- Event gắn với assistant/result message; prompt được liên kết bằng request key, không tạo hai event cho hai message của cùng lượt hỏi.

Đây là outbox gắn trên bảng message hiện có, không thêm bảng OutboxMessages/ProcessedEvents. Sơ đồ C2 nháp có relay đọc bảng OutboxMessages, nên cần sửa lại chi tiết này khi cập nhật sơ đồ. Cách gắn trạng thái chỉ phục vụ các sự kiện nghiệp vụ cụ thể, không phải event bus tổng quát.

Admission quota: đọc balance hiện tại từ SQL, trừ tổng ngân sách đã giữ chỗ nhưng chưa quyết toán. Khóa/cập nhật đồng thời theo user trong transaction ngắn; Worker cũng tuân thủ quy tắc này. Không giữ DB lock xuyên gRPC. Giới hạn đầu vào/output để reservation có chặn trên; chỉ Worker quyết toán TokenBalance. Lỗi/hủy/timeout phải giải phóng reservation bằng luồng recovery. Không dùng claim quota trong JWT làm nguồn số dư hiện tại.

Nếu provider không cung cấp usage chính xác, tách rõ token ước lượng và token dùng tính quota; không hiển thị ước lượng thành số đo thật. Kiểm thử trường hợp usage vượt reservation và consumer xử lý trễ trước khi coi quota hoàn tất.

SMTP có cửa sổ lỗi sau khi gửi nhưng trước khi lưu marker: retry có thể gửi email lặp. Dùng Message-Id ổn định và trạng thái gửi, nhưng chỉ tuyên bố chống trừ quota trùng bằng transaction; không hứa email exactly-once.

Không xóa message/session còn pending publish/quota/email; cleanup cần kiểm tra trạng thái. Retry vô hạn không được giữ reservation vĩnh viễn: có timeout/recovery và cảnh báo.

## 7. Luồng crawl, verification, indexing và cache

1. Admin gửi URL nguồn qua DocumentsController. BusinessLogic kiểm tra allowlist host, redirect và phạm vi URL; tạo/cập nhật LegalDocuments ở trạng thái crawl Pending. Trả 202 và document ID để theo dõi bằng GET document detail.
2. Worker claim công việc từ SQL, tải nguồn và trích xuất metadata/nội dung. Dùng trạng thái/lease bền vững trong LegalDocuments, không Task.Run trong controller.
3. Verification engine kiểm tra nguồn, thời điểm hiệu lực và quan hệ sửa đổi. Chỉ một phần văn bản hợp lệ thì chỉ các chunk đủ điều kiện được xác thực; không gán Verified toàn văn chỉ vì có từ “còn hiệu lực”.
4. Worker ghi metadata và chunk IDs ổn định vào SQL. Chunking theo Chương/Điều/Khoản/Điểm; giữ content hash, version và bằng chứng nguồn.
5. Gọi gRPC IndexDocument để embedding/upsert Qdrant. Chỉ ghi IndexStatus=Indexed sau xác nhận; retry dùng cùng IDs/version. Khi version thay đổi, vô hiệu hóa điểm cũ, không để chunk đã xóa còn được truy xuất.
6. Lưu DocumentUpdatedEvent pending trên LegalDocuments cùng version; relay publish Kafka. Consumer riêng vô hiệu hóa cache liên quan. Cache chat chỉ được bật sau khi có cơ chế kiểm tra lại source/version trên cache hit; ở mốc đầu có thể chỉ cache danh sách/detail văn bản.
7. Cron 00:00 Asia/Ho_Chi_Minh kiểm tra hiệu lực, cleanup, xuất thống kê. Timestamp trong DB/log vẫn UTC. Quét bù job bỏ lỡ khi Worker restart; mỗi job có quy tắc chạy lại an toàn.

LegalDocuments đề xuất thêm CrawlStatus/IndexStatus, ContentHash, DocumentVersion, SourceCheckedAt, VerificationEvidenceJson, LastJobError, trạng thái/lease và event pending. Chunk có Điểm, version và cờ xác thực riêng. Lịch sử xác thực nhiều lần lưu evidence có version ra file bền vững kèm đường dẫn/hash; API chỉ tuyên bố đọc được lịch sử trong retention đã cấu hình. LastVerifiedAt một mình không phải lịch sử.

Qdrant payload đích: chunk_id, document_id, document_version, document_number/title, chapter/article/clause/point, content, source_url, effective/expiration dates, is_verified, is_active, embedding_model/version. Giữ numeric point-ID hiện tại và lưu chính xác vào VectorId dạng string; luôn so chunk_id để phát hiện xung đột hash. Không coi hash là đảm bảo không va chạm. VectorId là liên kết logic, không phải FK xuyên database.

SQL/Qdrant không chung transaction. Thiết kế trạng thái index, retry/reconciliation và kiểm tra lại ở REST để chặn cửa sổ dữ liệu cũ. Khi không xác minh được trạng thái mới nhất thì từ chối trả lời có căn cứ, không tự dùng cache/seed thay thế.

## 8. API, lỗi và quan sát hệ thống

- Giữ các endpoint auth/chat hiện có. Bổ sung document list/detail/filter/paging, crawl-trigger Admin và usage report theo requirement.
- Usage report lấy từ assistant/result messages, tránh đếm cả prompt lẫn answer thành hai lượt hỏi. User chỉ xem dữ liệu của mình; Admin xem tổng hợp theo quyền.
- Thêm exception nghiệp vụ cho service unavailable/deadline nếu cần; GlobalExceptionHandler ánh xạ ProblemDetails. Không lưu chuỗi “AI đang bận” thành câu trả lời thành công có event tính phí.
- Health/readiness cho từng service; thiếu broker/Qdrant/model không được báo hệ thống đã tích hợp thành công. NoMatch là kết quả nghiệp vụ, khác hạ tầng lỗi.
- Log JSON thật ra file có rotation/volume; trace xuyên Gateway → REST → gRPC → Kafka → Worker; không ghi credential hoặc token xác thực.
- Prometheus thu service/Kafka metrics; Loki đọc log qua Alloy; Tempo lưu trace; Grafana provisioning/dashboard nằm trong repo.
- Dashboard tách publish ack, receive attempts, unique processed, duplicate skipped, retries, failures, consumer lag và request latency/error. Không lấy tổng dòng log làm số event.

## 9. Thứ tự triển khai và điều kiện hoàn thành

| Mốc | Phần code | Điều kiện hoàn thành |
| --- | --- | --- |
| M0 | Đồng bộ decision/contract; danh sách cột mới; cập nhật sơ đồ lệch | Chốt một broker, topic, proto, embedding config, gateway boundary và state machine |
| M1 | Entities/DbContext/migration, repositories và transaction | Đúng 7 bảng; constraints/idempotency queries có kiểm thử; không pending model changes |
| M2 | gRPC contract + Qdrant/model thật + trích dẫn | Citation trace về chunk SQL; NoMatch/blocked/infrastructure error phân biệt được; không fallback ngầm |
| M3 | ChatbotService + Kafka producer/relay + Worker quota | Một lượt chat chạy xuyên hệ thống; crash/replay không mất pending event và không trừ quota hai lần |
| M4 | Documents API, crawler/verification/indexing, document events | URL thật → SQL → Qdrant → tìm kiếm; inactive/version cũ bị loại; retry/restart phục hồi |
| M5 | Email, cleanup, daily usage/report và cache/rate limit | SMTP lỗi không lặp quota; job chạy đúng múi giờ; báo cáo không đếm đôi; cache invalidation chạy |
| M6 | Gateway, Docker Compose, telemetry và demo | Đi qua Gateway; services có readiness; dashboard/log/trace dùng dữ liệu thật; demo lỗi và backlog |

Gateway có thể dựng skeleton từ M0; instrumentation thêm từ M2/M3, không đợi M6 mới gắn trace. Có thể ghép M2/M3 thành lát cắt đầu tiên trên một bộ văn bản nguồn đã xác minh, rồi mở rộng crawler ở M4. Không cần làm web/mobile mới để kiểm chứng API; dùng Swagger/Postman theo scope hiện tại.

Theo phân công hiện có: Bảo phụ trách M1/auth; Khôi M2 và verification/index RPC; Khánh Kafka/Worker/quota/email; Vương chat orchestration/Gateway/Compose/telemetry; Phúc Documents/crawler/cron/report. Contract/schema là đầu vào chung trước khi các phần tích hợp. Đây là đề xuất tổ chức công việc, chưa giao việc hay gửi thông báo cho thành viên.

## 10. Kịch bản nghiệm thu cần giữ

1. JWT/refresh rotation/logout; user khác không đọc/xóa session; non-admin không trigger crawl.
2. Câu hỏi có căn cứ trả đúng chunk IDs, Điều/Khoản/Điểm và URL nguồn; thiếu căn cứ trả NoMatch.
3. Prompt vi phạm dừng trước retrieval/generation, ghi đúng trạng thái và phát event cảnh báo.
4. Dừng gRPC/Qdrant/provider: lỗi rõ ràng, không seed/RAM/hash fallback trong profile tích hợp.
5. Broker chết sau SQL commit: message Pending còn; khởi động broker/relay thì publish tiếp.
6. Relay chết sau broker ack trước SQL mark: có thể phát lại nhưng quota chỉ bị trừ một lần.
7. Consumer chết sau DB commit trước offset commit: nhận lại event, bỏ qua quota đã xử lý.
8. Gửi đồng thời khi số dư thấp: tổng reservation/charge tuân thủ budget; request retry không tạo lượt hỏi mới.
9. Thay đổi/expire văn bản khi đang chat: SQL kiểm tra version chặn citation cũ; Qdrant/cache được đồng bộ lại.
10. Dừng Worker để lag tăng, chạy lại để backlog giảm; đối chiếu N EventId khác nhau với unique processed và balance thực tế.
11. SMTP lỗi/retry, job restart và cleanup: không xóa dữ liệu còn pending; không chạy trùng tác động quota.
12. Build .NET, Python contract/import checks, EF pending-model check; integration trên SQL/Kafka/Qdrant thật. Runtime mới là bằng chứng tích hợp.

## 11. Bước code đầu tiên

Tích hợp code đã có trước: dùng nền nhánh Vương (đã chứa auth của Bảo và Python/proto của Khôi), đưa phần Documents/crawler/cron từ nhánh Phúc vào, hợp nhất DI trong Program.cs và giữ scope SQL 7 bảng. Không merge mù toàn bộ nhánh Khôi vì các file gRPC .NET được thêm độc lập và đang xung đột với Vương. Sau đó làm M0/M1 trên nền đã ghép và hoàn thiện lát cắt chat ở M2–M3: request có căn cứ → gRPC thật → SQL message/citation → Kafka thật → Worker quyết toán quota → trace/log. Đây là mốc chứng minh các khối trong sơ đồ giao tiếp được; tiếp theo mới hoàn thiện crawl/cron/cache và dashboard đầy đủ.

Plan này không apply migration, không thay đổi runtime/source nghiệp vụ và không gửi email. Migration xóa hai bảng cũ đang có trong workspace cần được rà soát dữ liệu/backup trước khi chạy API bật MigrateOnStartup.
