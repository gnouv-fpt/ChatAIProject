# Plan code hợp nhất và phân công 5 người

Ngày: 24/10/2026. Bản hiện hành cùng task.md, thay các bảng phân công rời trước đây. Scope đích gồm tư vấn luật, chat ảnh và học/luyện thi. Đây là plan code, chưa triển khai các module mới.

**Trạng thái nền:** đã tạo PRN-dev local, ghép source hiện có từ các branch PRN và giữ scope 7 bảng/tài liệu. Build 0 warning/error; EF không pending model changes. Chưa push, chưa chạy API/Compose/apply migration. Task V01 đã hoàn thành phần ghép source ban đầu; các tính năng mới trong plan vẫn chưa code. Quy trình nhánh tại TEAM-GIT-WORKFLOW.md.

## 1. Nền source và quyết định chung

- Dùng nền PRN-VUONG-dev đã có auth Bảo và snapshot Python/proto Khôi. Ghép Documents/crawler/cron của PRN-PHUC-dev, xử lý Program.cs và giữ các thay đổi scope 7 bảng đang chưa commit.
- Không merge mù PRN-KHOI-dev: các .NET gRPC files được thêm độc lập và xung đột. Không ghép FLM FastAPI từ FastAPI-RAG-Backend-Khanh.
- Tham khảo adapter Groq ở akkhanh05-test-groq-api; không sao chép fallback Ollama, logic môn học, API keys hay config nhạy cảm.
- Generation dùng Groq API; embedding và vision/OCR dùng API phù hợp. Không fallback AI local. Model/provider cụ thể chốt theo tài khoản và năng lực API thực; không mặc định Groq text model nhận ảnh.
- Chấm thi bằng code và đáp án/profile chuẩn, không gọi AI quyết định pass/fail. Số câu/thời gian/điểm đạt/điểm liệt lấy từ profile có nguồn/version.
- Backend theo Presentation → BusinessLogic → DataAccess → BusinessObject. Worker là host riêng, không tham chiếu Presentation. Frontend đề xuất React/TypeScript trong web/, không Razor Pages.
- Mỗi người test/instrument module mình. File chung có một owner; các bên khác bàn giao DI extension/config, không cùng sửa Program.cs.

## 2. Luồng đích

1. **Chat chữ:** auth/ownership → reserve quota → gRPC moderation/retrieval → Groq answer → recheck SQL chunk/version → commit result/citations/event pending → Kafka relay → Worker settle.
2. **Chat ảnh:** upload private → attachment IDs → vision/OCR API → observations/câu hỏi → bank context nếu có ID → legal retrieval + generation → answer/citations/follow-up context → quota/events. Thiếu dữ kiện thì hỏi lại.
3. **Học:** bank/version/profile → lọc/range/N/topic/wrong/unseen → attempt snapshot → chọn đáp án → so key chuẩn → phản hồi/giải thích → progress/bookmark/history.
4. **Thi:** template/profile → random/shuffle → snapshot/permutation/deadline server → autosave → submit/hết giờ → chấm một lần → kết quả/lịch sử/ôn sai. Không lộ answer key trước khi kết thúc bài thi.
5. **Nội dung:** crawl/import → validate source/metadata/key/assets/version → verify/publish → index hoặc bank available → event/invalidate cache. OCR/LLM không tự tạo đáp án chính thức.

## 3. Contracts ở P0

| Contract | Trường/quy tắc cần chốt | Chủ trì |
| --- | --- | --- |
| Chat | request key, session/user, attachments, question/bank version, result status, usage/citations/context | Vương + Khôi |
| Proto | text/image/verify/index/deactivate; chunk ID/Điểm/version; deadline/trace; field numbers tương thích | Khôi |
| Events | EventId, SchemaVersion, entity ID/version, CreatedAt, TraceParent; topic/key/group/retry/DLQ | Khánh |
| Quota | Reserve/Release/Settle, concurrency, usage unknown, recovery, transaction markers | Bảo |
| Question bank | ID/version/hash/source/profile/topic, option IDs/key/explanation/assets/shuffle policy | Phúc |
| Practice/exam | mode/pool/template/profile/N/range/filters/seed/permutation/deadline/snapshot/submit | Khánh + Bảo |
| HTTP/permissions | ProblemDetails, ownership, Admin, missing pool/AI errors, answer visibility | Vương + Bảo |

## 4. Persistence và giới hạn 7 bảng

Core RAG giữ 7 bảng theo AGENTS.md. Bảo sở hữu migrations; không phục hồi ViolationLogs/UsageReports. Pending event gắn vào ChatMessages/LegalDocuments; quota marker và balance commit cùng transaction; cleanup không xóa pending work.

Học/thi cần dữ liệu mới. Phương án review: module Learning gồm QuestionBanks, Questions (options/assets có cấu trúc), ExamTemplates, LearningAttempts, AttemptAnswers, QuestionBookmarks. Gói bank/assets/version bất biến có manifest/hash. Attempt giữ snapshot câu/option/profile; không chấm bài cũ bằng key “latest”. Progress/report derive từ attempts/answers.

Attachment lưu private storage, metadata ownership/hash/MIME/retention có persistence riêng do Bảo thiết kế; chat chỉ tham chiếu ID, không lưu base64. Đây là đề xuất dữ liệu mở rộng, chưa coi teacher scope đã thay đổi, chưa tạo migration. P0 phải ghi lại quyết định lưu trữ phù hợp giới hạn 7 bảng trước khi code migration; API contracts/parser/adapters/UI vẫn có thể làm song song. Không nhét bài thi vào ChatMessages chỉ để tránh thiết kế schema.

## 5. Bảo — auth, persistence, quota, progress/report

Tái sử dụng auth/entities/repos. Sở hữu BusinessObject/*, DataAccess/*; quota/report/progress services/controllers; web/src/features/account và web/src/features/progress. Không quyết định random/scoring; Khánh sở hữu nghiệp vụ đó qua repository contracts Bảo cung cấp.

| ID | Task code | Đầu ra/điều kiện đạt |
| --- | --- | --- |
| B01 | Hợp nhất core 7 bảng; state/request/event/version constraints, transaction repos | Migration đúng; không pending model changes; không mất dirty changes |
| B02 | Thiết kế learning/attachment persistence, snapshot/ownership và repo interfaces | ERD/decision log trước migration; interfaces cho Phúc/Khánh/Vương |
| B03 | QuotaService reserve/release/settle và recovery | Không lock DB xuyên AI; cùng event settle một lần; concurrency/timeout không kẹt ngân sách |
| B04 | Progress/history/bookmark/wrong/unseen queries/API | Theo user + bank/version; không nhân đôi lượt submit |
| B05 | Usage/report aggregation/API cho UI và cron | Không đếm đôi user/assistant; User xem mình, Admin theo quyền |
| B06 | Auth/refresh/logout/ownership tests; UI account/profile/progress | Login/logout/profile/progress chạy qua API thật |

Bàn giao code + schema/state documentation + DI extension + test transaction/ownership. Không viết lại auth từ đầu chỉ vì phân công mới.

## 6. Khôi — AI API, vision, gRPC, verification/Qdrant

Sở hữu Protos/*, grpc_inference_service/*, tests Python/RPC. Tái sử dụng moderation/RAG/index; sửa registry/heuristic và local fallback chưa đáp ứng scope.

| ID | Task code | Đầu ra/điều kiện đạt |
| --- | --- | --- |
| K01 | Groq generation adapter/config/usage/deadline/retry | API thật; không local fallback; usage thiếu ghi unknown |
| K02 | Embedding API/model/version/dimension validation | Query/index cùng embedding space; đổi model có reindex plan |
| K03 | Verification từ evidence/ngày/sửa đổi từng phần, retrieval eligibility | Unknown = Pending; không dùng luật/chunk không đủ điều kiện |
| K04 | Proto/citation chunk ID/Điểm/version, index/deactivate RPC | Một proto nguồn; retry index không nhân đôi; map point ID về SQL |
| K05 | Vision/OCR API và context ảnh/follow-up | Ảnh mờ/cắt thiếu biển thì hỏi lại; observations không phải evidence pháp lý |
| K06 | Giải thích bank answer key + legal RAG; error/telemetry tests | Không chấm bằng LLM; no-match/blocked/provider failure riêng biệt |

Phúc cung cấp nguồn/bank/evidence; Vương giữ .NET gRPC adapter. Khôi bàn giao proto, API config không secret, request/response/error examples và test text/ảnh/no-match/expiry. Model vision chọn theo API thực, không sao chép model cũ theo tên.

## 7. Khánh — Kafka/Worker và engine luyện/thi

Sở hữu WorkerService/*, events, Kafka/email adapters, PracticeService/ExamService/ExamRuleEngine, Practice/Exam controllers và web/src/features/exams. Worker PRN là phần cần làm mới; không lấy backend FLM thay thế.

| ID | Task code | Đầu ra/điều kiện đạt |
| --- | --- | --- |
| H01 | Worker host/DI; Kafka producer; event/topic/key/group contracts | Broker ack thật; host không tham chiếu REST host |
| H02 | Relay pending, consumer gọi quota, retry/DLQ/replay | Broker outage/crash/replay không mất pending và không trừ trùng |
| H03 | Email retry riêng, scheduler host, expiry/recovery jobs | SMTP lỗi không lặp quota; nhận cron handlers từ Phúc |
| H04 | Practice selection N/range/topic/wrong/unseen; template/profile engine | Không trùng; pool thiếu báo rõ; snapshot/seed ổn định |
| H05 | Option permutation, server deadline, autosave, submit/scoring | Tôn trọng câu không thể trộn; reload không reset timer; submit idempotent |
| H06 | UI làm bài/thi/timer/review/nộp/kết quả | Không lộ key trước submit; kết quả đúng server/profile |

Ưu tiên H01–H03 cho core; H04–H06 có thể dựng từ contracts/fixtures test ngay sau P0. Không trộn phương án tham chiếu “A và B”, “tất cả trên” hoặc nhãn ảnh nếu chưa có cách remap đúng. Timer server là nguồn chuẩn; Worker hỗ trợ expiry/recovery. SMTP không hứa exactly-once.

## 8. Vương — tích hợp, Chat/ảnh, web shell và hạ tầng

Sở hữu Chat controllers/services/DTOs và .NET gRPC adapter; REST Program.cs, project/solution registration chung; ApiGateway/*, Compose/monitoring; web shell/router/API client và web/src/features/chat.

| ID | Task code | Đầu ra/điều kiện đạt |
| --- | --- | --- |
| V01 | Ghép nền Vương + Phúc + sửa core 7 bảng, hợp nhất contracts | Build bản ghép; không mất code/dirty changes |
| V02 | Chat idempotency/quota/citation mapping/error handling | Result/citation/pending event commit; recheck SQL version; API failure không thành success |
| V03 | Attachment private API, chat ảnh/question context/follow-up | Size/MIME/owner/retention; log không chứa ảnh/base64/signed URL |
| V04 | React shell/API client/router, chat text/ảnh UI | Các feature UI khác ghép qua routes; có loading/error/no-match states |
| V05 | Gateway/rate limit, Compose/secrets/volumes/readiness | REST vẫn validate JWT/ownership; AI keys chỉ ở server |
| V06 | Provisioning/dashboard, integration/demo scripts | File logs/trace/lag/usage thật; frontend/backend chạy xuyên luồng |

Mỗi thành viên cung cấp telemetry/test của module mình; Vương không phải viết thay mọi UI/instrumentation. Dùng Dockerfile Worker Khánh bàn giao, parser/bank Phúc, migrations Bảo, AI config Khôi.

## 9. Phúc — dữ liệu luật, question bank và UI học

Sở hữu Documents/crawler/chunker; bank/template/import/publish services/controllers; cron nghiệp vụ; web/src/features/questions và web/src/features/admin-content.

| ID | Task code | Đầu ra/điều kiện đạt |
| --- | --- | --- |
| P01 | Crawler lấy nội dung/số hiệu/evidence thật; repo thay direct EF | Durable job/status; selector sai có lỗi/số lượng rõ |
| P02 | Verify → chunk SQL → index; expiry/reconciliation/event pending | SQL/Qdrant version đồng bộ; không dùng căn cứ lỗi thời |
| P03 | Bank/ảnh/answer/profile import/validation | ID/options/key/assets/source/version hợp lệ; không giả nguồn official |
| P04 | Admin draft/preview/publish, questions/templates list/detail/filter | Version bất biến; API không leak key cho bài thi đang chạy |
| P05 | Cron cleanup/reverify/report, cache invalidation handlers | 00:00 Việt Nam, catch-up, bảo vệ pending; host Khánh đăng ký |
| P06 | UI thư viện/học theo topic/N/range và Admin import | Dùng Practice API Khánh, Progress API Bảo và chat explanation của Khôi/Vương |

Phúc sở hữu dữ liệu answer/profile; Khánh áp dụng profile để chọn đề/chấm. Tổng số câu lấy từ bank đã import; đề ôn N câu khác đề mô phỏng thi. Cập nhật bank không sửa lịch sử attempt cũ.

## 10. API ownership và file dùng chung

| API/tài sản | Owner | Bên sử dụng |
| --- | --- | --- |
| /api/auth/*, /api/reports/usage, /api/learning/progress/history/bookmarks | Bảo | UI account/progress, Phúc/Khánh hiển thị |
| /api/chats/*, attachment upload/access, messages có ảnh/question context | Vương | Khôi RPC, Bảo quota, Khánh events |
| /api/documents/*, /api/question-banks/*, /api/questions/*, /api/exam-templates | Phúc | UI học, Khánh engine |
| /api/admin/question-banks/import/preview/publish | Phúc | Bảo storage/repos, Vương upload infrastructure |
| /api/practice-attempts/*, /api/exam-attempts/*/answers/submit/results | Khánh | Bảo persistence, Phúc UI học |
| Protobuf/Python AI | Khôi | Vương adapter, Phúc index |
| Entities/DbContext/migrations/repo contracts | Bảo | Cả nhóm |
| Event contracts/Worker Program.cs | Khánh | Vương/Phúc event writers, Bảo transaction |
| REST Program.cs/.slnx/.csproj dùng chung/web router/Compose | Vương | Các bên bàn giao DI extension/config |
| Bank manifest/source/profile/parser | Phúc | Khôi evidence, Khánh selection/scoring |

Owner API viết DTO/validation/controller/service/tests, repository owner Bảo phối hợp query; không chuyển nghiệp vụ vào controller hoặc repository. Async/cancellation truyền xuyên layers. Không ghép endpoints trùng của nhiều module.

## 11. Mốc tích hợp: không phải waterfall

| Mốc | Công việc song song | Điều kiện qua mốc |
| --- | --- | --- |
| P0 | V01/web skeleton; B01/B02/contracts; K01/proto; H01/event/exam contracts; P01/P03/manifest | Contract bản đầu + decision log persistence + skeleton build |
| P1 | Core auth/chat/API/Qdrant/SQL/Kafka/quota; bank draft; vision development | Chat thật có citations/trace/settle một lần; API failure rõ; import draft kiểm tra được |
| P2 | Learning persistence + publish bank + practice/exam UI/API + progress | Học/thi end-to-end; timer/submit/answer visibility/snapshot đúng |
| P3 | Chat ảnh/follow-up + cron/expiry/cache/email + Gateway/dashboard | Ba luồng chat chữ/chat ảnh/học thi trên data/API thật, có recovery |

Vision/bank/exam/UI có thể code từ P0 khi interfaces bản đầu thống nhất. Không chờ người khác làm xong cả module. Fixtures/stubs chỉ cho unit/contract test, demo phải dùng data/API thật. Không đưa thời hạn theo ngày khi chưa có lịch từng người.

Trình tự ghép: nền tích hợp → contract/schema changes → từng lát cắt feature. Mỗi PR nhỏ, chỉ stage named paths; build/test bản ghép. Nền PRN-dev đã được ghép/commit local sau bước lập plan; chưa push. Các nhánh cá nhân cần đồng bộ nền đã phát hành trước khi code tiếp. Không mặc định branch cá nhân đã chứa thay đổi mới.

## 12. Checklist nghiệm thu

- Auth refresh/logout/role/ownership; DTO validation và ProblemDetails.
- Citation thực có chunk FK/Điểm/version; no-match/blocked/API error rõ; không AI local.
- Ảnh rõ/mờ/cắt thiếu dữ kiện; đúng question/bank context; follow-up không đổi ảnh ngầm.
- Usage ảnh/text thực hoặc unknown; quota concurrent/release/recovery không kẹt reservation. Timeout không chứng minh provider chưa tính phí.
- Broker outage sau DB commit; relay chết sau ack; consumer chết sau settle; replay không trừ trùng.
- Import key/options/assets/duplicate/profile/source lỗi bị chặn publish; AI không tự tạo key chuẩn.
- Random không trùng/không đủ pool; shuffle giữ option IDs và tôn trọng câu không thể trộn.
- Không lộ key qua question/attempt/AI explanation API trong thi; ownership mọi attempt.
- Server timer, reload/reconnect, submit đồng thời/retry/expiry đúng policy; kết quả một lần.
- Bank version mới không đổi bài cũ; progress/ôn sai/bookmark/history khớp lượt trả lời thật.
- Document expiry/reconciliation/cache và cron catch-up; cleanup không xóa pending.
- File logs/metrics/trace/Grafana thật; lag tăng/giảm khi dừng/chạy Worker; SMTP test không lặp quota.
- Build .NET/frontend, Python RPC checks, EF pending model check và integration SQL/Kafka/Qdrant/API thật. Chỉ claim các đường đã chạy.

Mỗi module bàn giao code + config mẫu không secret + README + contract changes + test evidence + giới hạn còn lại. Điểm cần chốt P0: persistence mở rộng phù hợp teacher scope, nguồn bank/profile, API provider/model/budget và cấu hình client. Những phần này là thiết kế cần quyết định, không phải bằng chứng đã triển khai.
