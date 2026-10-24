# Phân công phần PRN còn thiếu cho 5 thành viên

**Phân công hiện hành nằm ở task.md và IMPLEMENTATION-PLAN.md**, đã gộp core, chat ảnh, học/thi và UI. Tài liệu này giữ làm tham khảo chi tiết khảo sát trước đó; khi khác nhau, dùng bản hợp nhất mới.

Ngày lập: 24/10/2026. Cơ sở: source trên các nhánh remote đã fetch, khảo sát C0/C1/C2 và requirement mới. Đây là đề xuất phân công để nhóm sử dụng; chưa giao việc qua tài khoản/dịch vụ bên ngoài và chưa tạo nhánh hay merge code.

**Scope bổ sung từ người dùng:** chatbot hiểu/giải thích ảnh giao thông và học/luyện thi theo ngân hàng/bộ đề, chọn N câu, random, timer/chấm bài và tiến độ. Xem LEARNING-AND-IMAGE-CHAT-PLAN.md cho task mở rộng của cả 5 người. Task core bên dưới vẫn còn hiệu lực; không coi persistence học/thi đã nằm sẵn trong 7 bảng hoặc phần vision/quiz đã được code.

## 1. Kết luận về nhánh Khánh

`origin/FastAPI-RAG-Backend-Khanh` tại commit `cc003f6` đúng là code của Khánh, nhưng thuộc ứng dụng FLM/Curriculum & Syllabus:

- `backend/README.md` xác định dự án FLM, dữ liệu từ flm_knowledge_vault/courses_data.json.
- `backend/app/services/rag_engine.py` dùng FLMKnowledgeVaultParser, course_code và nguồn trích dẫn file môn học.
- `backend/app/api/v1/endpoints/chat.py` phục vụ POST /api/v1/chat; còn có API courses/health.
- Vector store ở backend là bộ truy xuất FLM trong bộ nhớ; không phải pipeline Qdrant luật giao thông của bài PRN.
- Tìm source không thấy ChatCompletedEvent, Kafka consumer, MailKit/SMTP, TrafficRagInference hoặc pipeline thuvienphapluat. BackgroundService có ở ứng dụng .NET cũ là RagasEvaluationBackgroundService, không phải Worker quota/cảnh báo PRN.

Vì vậy không dùng nhánh này làm phần hoàn thành Broker/Worker của PRN. Không cần chuyển backend FastAPI FLM vào hệ thống hiện tại. Chưa chạy test của nhánh FLM vì không xác minh chức năng PRN mà nhóm đang cần.

## 2. Những gì tái sử dụng

| Người | Source nền | Phần đã có, không viết lại |
| --- | --- | --- |
| Bảo | PRN-BAO-dev / 6d79f16 | Entities, DbContext, repositories, JWT/auth/refresh-token |
| Khôi | PRN-KHOI-dev / 7084b1f | Python gRPC, moderation, RAG/Qdrant, verification ban đầu, proto |
| Vương | PRN-VUONG-dev / 0796c1f | Chat API/service/repos, .NET gRPC adapter, Docker/Compose; đã có Python/proto của Khôi |
| Phúc | PRN-PHUC-dev / 1ab5e75 | Documents API/service/repository, crawler metadata, midnight cleanup |
| Khánh | FastAPI-RAG-Backend-Khanh / cc003f6 | Là code FLM khác scope; phần Kafka/Worker PRN chưa tìm thấy trên remote đã kiểm tra |

Bốn nhánh PRN ở bảng trên đã build .NET thành công trong lần kiểm tra trước cùng ngày, mỗi nhánh 0 warning/error. Đó là build độc lập, chưa phải xác nhận bản tích hợp hay runtime SQL/Kafka/Qdrant/SMTP.

## 3. Quy ước chung trước khi chia code

- Cập nhật theo yêu cầu dùng AI API: sinh câu trả lời qua Groq API; embedding qua API provider riêng được cấu hình, không chạy model embedding local. Không fallback Ollama/SentenceTransformers/hash embedding/local synthesizer. Thiếu key/model hoặc API lỗi phải có trạng thái lỗi thật. Model name/dimension chốt khi kiểm tra tài khoản provider; không sao chép model cũ từ nhánh FLM.
- Đã đọc akkhanh05-test-groq-api tại 6e4640b: có Groq chat-completions, nhưng vẫn gọi Ollama khi GroqAllKeysExhaustedError và còn local fallback trong call_direct. Chỉ tham khảo adapter HTTP/config/error handling; không sao chép fallback hoặc nghiệp vụ môn học vào PRN. Lần này mới cập nhật thiết kế, chưa đổi code runtime sang Groq.
- SQL đúng 7 bảng theo AGENTS.md. Không phục hồi UsageReports/ViolationLogs từ các remote cũ. Bổ sung cột/trạng thái vào bảng hiện có khi cần, migration do Bảo quản lý.
- Broker chốt Kafka; Redis chỉ cache/rate limit. Topic chuẩn: chat-completed-events, document-updated-events; thêm retry/DLQ theo contract. Tên document-indexed-events trong ảnh được thể hiện bằng ChangeType=Indexed trên document-updated-events.
- Một proto nguồn tại Protos/chat_inference.proto; C#/Python cùng sinh từ đó. Collection traffic_law_documents; model/dimension/version cấu hình cố định.
- Gateway giữ riêng như ảnh C1; controller REST mỏng, nghiệp vụ trong BusinessLogic, truy vấn/persistence trong DataAccess. Worker không tham chiếu Presentation.
- Các trạng thái schema bên dưới là thiết kế đề xuất, phải được chốt ở mốc đầu; chưa tồn tại đầy đủ trong source.
- Mỗi người tự bổ sung log/metrics/trace và test cho module mình. Vương gom dashboard, không phải viết instrumentation thay toàn nhóm.
- Các kịch bản SMTP dùng hộp thư test được nhóm cấu hình; triển khai code không đồng nghĩa được phép gửi email thật cho người dùng/Admin.

## 4. Bảo — dữ liệu, transaction/quota và Usage API

**Mục tiêu:** cung cấp nền persistence và thao tác quota an toàn để REST/Worker cùng sử dụng; tiếp tục dùng auth đang có.

### Công việc còn thiếu

1. Hợp nhất model 7 bảng với các thay đổi chưa commit hiện tại. Kiểm tra migration xóa hai bảng cũ; không apply tự động lên DB có dữ liệu khi chưa rà soát/backup.
2. Cùng Khánh/Vương chốt trạng thái trên ChatMessages: request key/idempotency, ProcessingStatus, reservation token, event ID/payload/publish status, quota marker, email retry status, claim lease nếu chạy nhiều relay.
3. Cùng Phúc/Khôi chốt metadata trên LegalDocuments/DocumentChunks: crawl/index status, source evidence, content hash/version, Điểm, dữ liệu event document pending; bổ sung snapshot Điểm trên Citations.
4. Viết repository/transaction cho claim pending work, unique request/event, reservation theo user và quyết toán quota có điều kiện. BusinessLogic giữ luật tính quota; DataAccess chỉ thực thi persistence.
5. Cung cấp IQuotaService: reserve trước inference, release khi lỗi/hủy, settle từ Worker. Reserve không trừ TokenBalance; số khả dụng tính từ balance trừ phần đã giữ chỗ/chưa quyết toán. Transaction ngắn theo user; không khóa DB xuyên gRPC.
6. Bổ sung UsageReportService + ReportsController GET /api/reports/usage: thống kê từ result messages theo user/khoảng ngày, không đếm đôi prompt/answer; user xem mình, Admin theo quyền.
7. Kiểm thử auth đang có, nhất là refresh rotation/logout/role; sửa nếu kiểm thử phát hiện lỗi. Không viết lại module auth từ đầu.

**Sở hữu file:** BusinessObject/*, DataAccess/ChatAIWebDbContext.cs, DataAccess/Migrations/*, quota/persistence repositories; quota/report services, ReportsController và report DTOs.

**Bàn giao:** migration + bảng mô tả trạng thái/constraint; interface quota/repository; request/response Usage API; truy vấn phục hồi pending; hướng dẫn kiểm thử.

**Nghiệm thu:** 7 bảng, không pending model changes; cùng event xử lý lại không trừ tiền lần hai; request đồng thời không dùng vượt ngân sách đã chốt; report không đếm đôi; kiểm thử auth/ownership quan trọng pass.

## 5. Khôi — gRPC, verification và RAG/citations

**Mục tiêu:** hoàn thiện Python hiện có để dùng dữ liệu nguồn đã xác minh và trả citation truy vết được.

### Công việc còn thiếu

1. Hợp nhất proto nguồn, bổ sung document_id/chunk_id/version/Điểm trong citations; thêm request ID/budget và contract cập nhật/vô hiệu hóa index. Field mới dùng số mới.
2. Phân biệt Answered, NoMatch, ModerationBlocked; lỗi Qdrant/provider dùng gRPC error/deadline, không biến thành answer thành công. Truyền cancellation/trace metadata.
3. Thay quyết định Verified từ registry/keyword bằng kiểm tra metadata/bằng chứng nguồn do Phúc thu thập, thời điểm hiệu lực và sửa đổi từng phần. Không đủ bằng chứng thì Pending. Sửa trường hợp document number rỗng có thể khớp registry do so chuỗi con.
4. Viết Groq API adapter cho generation, cấu hình key/model/deadline/retry giới hạn; đọc token usage thực từ response, tách usage chưa biết khi timeout. Viết embedding API adapter riêng, chốt provider/model/dimension/version; kiểm tra collection khi startup, reindex nếu đổi embedding space. Không tải/chạy Ollama, SentenceTransformers hoặc hash/local synthesis; không tự fallback RAM/model khác. Seed chỉ là fixture development, không tự làm bằng chứng dữ liệu thật.
5. Hoàn thiện IndexDocument và deactivate/update payload theo document/version; retry dùng chunk IDs ổn định, xử lý chunk cũ bị xóa/thay thế. Trả chính xác point ID cho phía SQL lưu VectorId.
6. Retrieval lọc verified/active/ngày/version; đầu ra citation phải tham chiếu chunk thực và nội dung có trong nguồn. Không coi đặt prompt “không bịa” là bằng chứng độ chính xác.
7. Log JSON file, gRPC/RAG/model latency/error metrics, trace spans; health/readiness thể hiện Qdrant/model thật.

**Sở hữu file:** Protos/chat_inference.proto, grpc_inference_service/* và script generate/build protobuf; không sửa độc lập .NET GrpcInferenceService do Vương phụ trách.

**Bàn giao:** proto, generated-code instructions, Groq/embedding API adapters, env example không chứa key, ví dụ request/response/error, tài liệu payload Qdrant, bộ test Python/RPC. Hợp đồng verification cần nêu trường bằng chứng Phúc phải cung cấp. Vương cấu hình secrets qua môi trường; Bảo/Khánh thống nhất token accounting khi provider timeout, không coi timeout là bằng chứng không phát sinh phí provider.

**Nghiệm thu:** citation có chunk ID và Điều/Khoản/Điểm; NoMatch/blocked/lỗi phân biệt được; inactive/outdated/version cũ bị loại; mất Qdrant/provider không fallback ngầm; upsert lại không nhân đôi point.

## 6. Khánh — Kafka, Worker host, relay và email

**Mục tiêu:** triển khai phần PRN Broker/Worker còn thiếu; không ghép backend FLM vào đây.

### Công việc còn thiếu

1. Tạo WorkerService .NET host/Dockerfile, đăng ký DI riêng; host gọi BusinessLogic/DataAccess theo dependency rules.
2. Sở hữu contract events cùng các bên sử dụng: ChatCompletedEvent có EventId, SchemaVersion, ChatMessageId, UserId, SessionId, usage/moderation, CreatedAt, TraceParent; DocumentUpdatedEvent có DocumentId/version/ChangeType.
3. Viết KafkaEventPublisher thay RedisEventPublisher tại điểm DI do Vương tích hợp; có broker ack, key, timeout và lỗi thật. Không mô phỏng publish bằng log.
4. Viết relay quét pending ChatMessages/LegalDocuments qua repository Bảo cung cấp; broker ack mới mark published. Retry giữ nguyên EventId; xử lý lease/claim và cửa sổ crash sau ack.
5. Consumer chat gọi IQuotaService.SettleAsync và đánh dấu xử lý trong cùng transaction; commit offset sau DB commit. Không tự trừ số dư ở consumer bằng câu query ngoài transaction dùng chung.
6. Retry giới hạn, DLQ, replay cùng EventId, duplicate skip. Email chạy trạng thái riêng sau quota; SMTP lỗi không kích hoạt trừ quota lại.
7. Viết email adapter/template/cấu hình retry; stable Message-Id. Ghi rõ SMTP có thể lặp email nếu chết sau send trước marker; không hứa exactly-once.
8. Worker host nhận các cron/crawl handlers từ Phúc. Xuất file JSON, event counters, lag/heartbeat và trace; cung cấp exporter requirements/ports/config cho Vương.

**Sở hữu file:** WorkerService/* (host/consumer/relay), BusinessLogic/Infrastructure/Events/*, Kafka producer/email adapters và interfaces. Phúc sở hữu nghiệp vụ job, không cùng sửa host registration trực tiếp.

**Bàn giao:** topic/group/key schema, consumer/relay config, retry/DLQ/replay guide, Dockerfile và DI extension cho Worker; cấu hình SMTP mẫu không có secret.

**Nghiệm thu:** publish được broker ack; Worker restart/replay không trừ quota trùng; SQL commit rồi broker chết vẫn phục hồi event; email lỗi không lặp quota; log phân biệt receive/processed/retry/duplicate/DLQ.

## 7. Vương — tích hợp, Chat API, Gateway/Compose và monitoring

**Mục tiêu:** nối code các nhánh thành hệ thống chạy được; tái sử dụng Chat API đã có.

### Công việc còn thiếu

1. Chuẩn bị nền tích hợp từ PRN-VUONG-dev, giữ thay đổi scope 7 bảng hiện tại. Ghép phần Phúc, giải quyết Program.cs; Python/proto Khôi đã giống nhánh Vương nên không merge mù cả branch.
2. Hợp nhất .NET gRPC DTO/interface/adapter theo proto Khôi: map chunk IDs/Điểm/version, deadline/cancellation, exception → ProblemDetails phù hợp; không trả fallback hạ tầng như answer thành công.
3. Nối ChatbotService với quota reservation của Bảo; lưu result/citations và pending event trong cùng transaction, idempotency theo request. Không publish kiểu catch-and-swallow rồi bỏ mất event.
4. Kiểm tra lại trạng thái/version chunk SQL trước khi nhận câu trả lời hoặc trả cache hit. Giải phóng reservation khi lỗi; phối hợp handler recovery với Bảo/Khánh.
5. Tạo ApiGateway host/container định tuyến/rate limit/trace theo C1. REST vẫn kiểm tra JWT, ownership và role; không tin quota trong JWT là số dư hiện tại.
6. Cập nhật Compose: API/Gateway/gRPC/Worker/SQL/Qdrant/Kafka, Redis khi bật cache; readiness, volumes, env/secrets, ports. Dùng Dockerfile Worker Khánh bàn giao.
7. Gom monitoring/provisioning: Prometheus/Loki/Alloy/Tempo/Grafana và Kafka exporters; dashboard service health, latency/error, event stages và lag. Mỗi thành viên cung cấp telemetry của phần mình.
8. Viết script/kịch bản demo end-to-end và tài liệu chạy. Kiểm tra merged build và API qua Gateway, không chỉ build từng nhánh.

**Sở hữu file:** Presentation/Program.cs, Chat controllers/services/DTOs, .NET gRPC adapter, ApiGateway/*, docker-compose.yml, monitoring/* và scripts kiểm tra tích hợp. Giữ changes của người khác khi hợp nhất.

**Bàn giao:** bản tích hợp build được, Compose/env example, dashboard provisioning, kịch bản demo và bằng chứng runtime.

**Nghiệm thu:** một câu hỏi qua Gateway → REST → gRPC → SQL → Kafka → Worker; citation FK đúng; balance cập nhật một lần; trace tìm được xuyên service; dừng Worker thấy lag tăng rồi giảm sau restart.

## 8. Phúc — hoàn thiện crawler, document workflow và cron

**Mục tiêu:** nối Documents/crawler/cron đã có với verification/indexing, thay vì viết lại API.

### Công việc còn thiếu

1. Crawler lấy nội dung văn bản và metadata/số hiệu thật từ URL nguồn, xử lý allowlist/redirect/timeout/rate/retry. Selector không khớp phải có kết quả/lỗi rõ, không im lặng trả thành công.
2. Đưa truy vấn DbContext trong CrawlerService qua repository; phối hợp Bảo thêm queries. Crawl-trigger ghi durable pending job rồi trả 202 + document ID; GET detail thể hiện status, không await crawl xong mới nói “đã kích hoạt”.
3. Thu thập metadata/bằng chứng theo contract Khôi; gọi verify. Phân đoạn Chương/Điều/Khoản/Điểm và giữ chunk IDs/version ổn định; lưu SQL rồi gọi index RPC.
4. Chỉ mark Indexed sau ack; lỗi giữ pending/failed để retry. Lưu document event pending sau thay đổi phù hợp để relay Khánh phát; không báo index thành công trước xác nhận.
5. Hoàn thiện DocumentType/status filters, detail, trạng thái xử lý và lịch sử xác thực theo retention; dùng AppException/ProblemDetails thống nhất.
6. Tách MidnightCleanupJob khỏi Presentation: nghiệp vụ nằm trong BusinessLogic, persistence qua repositories, scheduler host Worker do Khánh đăng ký. Chốt 00:00 Asia/Ho_Chi_Minh, timestamps UTC và catch-up sau restart.
7. Khi văn bản hết hiệu lực: cập nhật SQL, gọi deactivate/update Qdrant và phát document event; reconciliation xử lý lệch trạng thái. Không xóa session/message còn pending event/quota/email.
8. Xuất báo cáo ngày bằng UsageReportService Bảo cung cấp; file/log và cấu hình gửi nếu được bật, không thêm UsageReports table. Viết consumer cache invalidation theo document event ở host REST nếu cache được bật; Vương tích hợp DI/config.

**Sở hữu file:** Documents controller/DTO/service, CrawlerService/parser/chunker, document workflow/cron handlers, cache invalidation handler. Khánh sở hữu scheduler host, Bảo sở hữu migrations và queries chung, Khôi sở hữu vector writes qua gRPC.

**Bàn giao:** ví dụ crawl từ URL thật và kết quả trạng thái, mapping metadata/chunk, DI extension cho jobs, retry/recovery guide, test document expiry và cache invalidation.

**Nghiệm thu:** nguồn thật → metadata/nội dung → verify → chunks SQL → Qdrant → chat có citation; unknown không bị gắn Verified; cron chạy đúng giờ và vô hiệu hóa dữ liệu cũ; job restart chạy lại an toàn.

## 9. Quyền sở hữu file và giao diện giữa các phần

| Tài sản dùng chung | Người chốt/sửa chính | Người cung cấp yêu cầu |
| --- | --- | --- |
| Entities/DbContext/migrations | Bảo | Cả nhóm |
| Protobuf | Khôi | Vương, Phúc |
| Event contracts | Khánh | Vương, Phúc, Bảo |
| REST Program.cs/Compose/Gateway | Vương | Cả nhóm qua DI/config hướng dẫn |
| Worker Program.cs/scheduler/consumers | Khánh | Phúc bàn giao job handlers, Bảo quota service |
| Qdrant payload/embedding config | Khôi | Phúc chunk metadata, Bảo SQL mapping |
| Usage aggregation API | Bảo | Phúc dùng cho cron |
| Crawl/chunk/job nghiệp vụ | Phúc | Khôi verification, Bảo persistence |
| Dashboard/provisioning | Vương | Mỗi người instrument module mình |

Các thành viên bàn giao DI extension/hướng dẫn cấu hình thay vì cùng sửa Program.cs. PR schema/contract phải được cập nhật trước PR consumer sử dụng; không sửa tên trường/topic/model riêng lẻ.

## 10. Thứ tự làm và mốc ghép

**Đây là thứ tự nghiệm thu/tích hợp, không phải 5 người chờ nhau code.** Sau khi chốt phiên bản đầu của schema/proto/events, cả 5 làm song song. Có thể dựng host, config, parser và telemetry ngay trong lúc chốt contract. Dùng fixture/stub chỉ cho unit/contract test được đánh dấu; demo tích hợp phải dùng API, DB và broker thật.

| Người | Có thể làm song song ngay | Phụ thuộc khi nối luồng thật |
| --- | --- | --- |
| Bảo | State/schema, repositories, quota service và Usage API | Event/request identity chốt với Khánh/Vương |
| Khôi | Groq + embedding API adapters, verification/RAG/proto | Metadata/evidence từ Phúc; SQL ID/version từ Bảo |
| Khánh | Worker host, Kafka/relay/retry/email adapters | Repository/quota interface Bảo; event pending từ Vương/Phúc |
| Vương | Ghép code, Gateway, Compose, chat error/trace | Proto Khôi, quota Bảo, Kafka contract Khánh |
| Phúc | Parser/crawler, chunking, document API và job handlers | Schema Bảo; verify/index RPC Khôi; host/relay Khánh |

### Mốc A — nền tích hợp và contract

Vương chuẩn bị bản ghép Bảo/Khôi/Vương/Phúc, giữ working tree scope 7 bảng. Bảo chốt state/transaction schema; Khôi chốt proto; Khánh chốt events/topic/retry; Phúc chốt crawl input/evidence. Các chữ ký interface phải có trước khi các implementation tích hợp. Chưa bắt đầu bằng việc viết lại module đã có.

### Mốc B — chat xuyên hệ thống

- Bảo: persistence + quota reserve/settle.
- Khôi: RPC/result/citation có ID và profile Qdrant thật.
- Khánh: Kafka/relay/consumer gọi quota service.
- Vương: ChatbotService + gRPC adapter + Compose tối thiểu.
- Phúc: chuẩn bị tập văn bản/chunks nguồn có evidence để chạy đường chat và hoàn thiện document ingestion.

Điều kiện qua mốc: một request thật có citation → SQL commit → broker ack → quota settle; replay không trừ trùng. Test lỗi broker/consumer ngay ở mốc này.

### Mốc C — crawl và hiệu lực

Phúc + Khôi nối crawl/verify/chunk/index/deactivate; Bảo cung cấp status/recovery queries; Khánh relay document event; Vương tích hợp cache invalidation/config. Kiểm tra văn bản hết hiệu lực trong lúc đang chat và khi cache tồn tại.

### Mốc D — hoàn thiện vận hành và nghiệm thu

Bảo hoàn thiện reports/auth checks; Khánh email/retry/DLQ; Phúc cron/report export; Vương Gateway/monitoring/demo; Khôi test no-match/blocked/AI errors và instrument. Mỗi phần bàn giao code, config và kết quả chạy thực tế; không dùng checkbox tài liệu thay bằng chứng.

## 11. Checklist chung trước khi nói hoàn thành

- Bản tích hợp build, đúng dependency direction, async/cancellation và không pending EF model changes.
- API thực chạy qua Gateway, auth/ownership/Admin được kiểm tra.
- Citation có chunk FK và Điều/Khoản/Điểm, nội dung/nguồn/version khớp.
- NoMatch, moderation và lỗi hạ tầng phân biệt; profile tích hợp không tự dùng seed/RAM/hash fallback.
- Broker tắt sau SQL commit không mất event; relay/consumer crash/replay không trừ quota trùng.
- Quota đồng thời, usage vượt reservation, timeout/cancellation và recovery có test; không giữ ngân sách vĩnh viễn.
- SMTP retry không lặp quota; không tuyên bố email exactly-once.
- Document expiry/update đồng bộ SQL/Qdrant/cache, cron catch-up có kiểm tra.
- Log file thật + metrics/trace hiển thị Grafana; đối chiếu EventId, balance và lag thực.
- README/plan thể hiện rõ implemented, tested và pending; không ghi “100%” chỉ vì build pass.

Chi tiết thiết kế state/luồng tham khảo CODE-DESIGN-PLAN.md; bằng chứng khảo sát các branch ở BRANCH-AUDIT-2026-10-24.md. Không có hành động merge/push/apply migration trong lần lập phân công này.
