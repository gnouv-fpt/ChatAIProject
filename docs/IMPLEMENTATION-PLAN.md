# Kế hoạch tích hợp theo C2 mới — 27/10/2026

Bản này cùng [task.md](../task.md) thay plan 24/10. Đây là kiến trúc đích; source các nhánh cá nhân chưa chuyển đổi/tích hợp đầy đủ. Build/test cũ không chứng minh kiến trúc mới đã chạy.

## 1. Ranh giới dữ liệu và service

| Kho | Dữ liệu theo C2 | Owner nghiệp vụ |
| --- | --- | --- |
| SQL User | USERS, USER_CHAT_SESSIONS, USER_CHAT_MESSAGES, EXAM_ATTEMPTS | Bảo; Vương phối hợp chat |
| SQL Content/Exam | LEGAL_DOCUMENTS, LEGAL_DOCUMENT_CHUNKS, TRAFFIC_QUESTION_CATEGORIES, TRAFFIC_QUESTIONS, EXAM_TEMPLATES, EXAM_TEMPLATE_ITEMS | Phúc |
| Qdrant | Vectors và payload tham chiếu document/chunk/version | Khôi |
| Redis | Đề custom theo user; snapshot câu/options/đáp án phía server, permutation, deadline/status/TTL | Khánh |

Hai SQL database độc lập, DbContext/connection strings/migrations riêng do Vương sở hữu. Có thể cùng SQL Server instance khi dev, không gom thành một context/schema. Tên vật lý/context/config do Vương phát hành ở P0, chưa là code đã có.

Client → Gateway → User service hoặc Content/Exam service; AI service dùng Qdrant. Gateway định tuyến API/auth/trace, không truy vấn DB. Host giữ Presentation → BusinessLogic → DataAccess → BusinessObject; từng service vẫn kiểm tra auth/ownership.

Không EF navigation/FK/join/transaction trực tiếp xuyên hai SQL DB. ExamCode/question IDs/chunk IDs/version là tham chiếu logic qua API/event. User DB giữ citation snapshots theo C2, không FK sang Content DB. Vương chốt physical mapping/JSON/index; không tự đổi GUID sang int hay UTC sang UTC+7 chỉ để khớp nhãn ảnh. Chốt ID mapping ở P0; lưu UTC, hiển thị giờ Việt Nam.

## 2. Quyết định thay plan cũ

- Bỏ giới hạn một SQL DB/7 bảng; không thêm ViolationLogs/UsageReports chỉ để ghi log/báo cáo.
- Bỏ bảng RefreshTokens; client giữ token. Bảo/Vương ghi rõ refresh còn hay bỏ, expiry/validation/logout và khả năng revoke trước khi sửa endpoint. Không chỉ xóa entity rồi giữ nguyên contract rotation/revocation dùng DB.
- Kafka chỉ notification/event giữa hai service. Không yêu cầu consumer quyết toán quota theo plan cũ. Rà code quota hiện có riêng; không tự xóa hoặc đưa lại thành dependency notification.
- SQL Content/Exam là nguồn bank/đề mẫu chính. File chỉ là import/fixture, không nguồn ghi song song. Redis giữ đề custom/cache.
- Animation HTML deploy riêng, URL HTTPS tại TRAFFIC_QUESTIONS.ExplanationAnimationUrl. Field URL không đồng nghĩa đã deploy.
- AI generation/embedding/vision qua API, không local fallback. Đáp án/profile chuẩn dùng chấm thi bằng code.

## 3. Luồng đề custom

1. User auth chọn N/chủ đề/bank version; lấy pool qua Content API. Không trùng câu; pool thiếu trả lỗi rõ.
2. Tạo mã custom gắn UserId, snapshot/version, thứ tự câu/options, server-only keys, CreatedAt/deadline/status/TTL trong Redis. Không trả key chuẩn trong response làm bài.
3. Autosave/resume kiểm tra owner; reload không reset deadline. Shuffle giữ option IDs và xử lý câu tham chiếu phương án theo policy.
4. Submit/hết giờ chấm phía server. Attempt ID/idempotency key ổn định và persistence constraint chống retry/concurrent submit tạo hai kết quả.
5. Lưu kết quả/câu trả lời/snapshot cần xem lại vào User DB qua contract Bảo/Vương. Chỉ trả thành công sau durable save; Redis expiry không làm mất lịch sử đã nộp.
6. P0 chốt TTL/resume/restart/eviction và submit khi Redis mất. Không mặc định đề chưa nộp bền vững như SQL.

Đề mẫu ở Content DB; đổi bank/đề mẫu không đổi kết quả/key của lượt thi cũ. Progress/history derive từ dữ liệu người dùng đã lưu.

## 4. Nội dung, AI và notification

- Phúc crawl/import → validate nguồn/key/assets → version/publish Content DB → Khôi index Qdrant bằng IDs/version ổn định.
- Chat lưu User DB; kiểm tra citation metadata qua service nội dung thay vì User service truy vấn Content DbContext. Phân biệt no-match/blocked/provider error.
- Phúc cung cấp HTML animation/hosting URL tại câu hỏi; API/UI validate và mở URL. Nghiệm thu bằng URL hoạt động thật.
- Kafka event phát khi trạng thái nghiệp vụ cần thông báo cho service kia thay đổi. Khánh chốt event types tối thiểu theo consumer thực tế; không gắn mặc định quota.
- Envelope: EventId, SchemaVersion, EntityId/EntityVersion, OccurredAtUtc, TraceParent. Ghi rõ topic/key/group, producer/consumer, broker ack/retry/DLQ/phục hồi.
- Consumer xử lý duplicate/reorder bằng EventId/version; không hứa exactly-once. Cache invalidation là handler nếu cần. Notification tới UI cần API/realtime delivery riêng; DB không tự nhận notification.

## 5. Contracts P0

| Contract | Chủ trì | Đầu ra |
| --- | --- | --- |
| Schema/persistence | Vương | Entity/ID mapping hai DB, JSON snapshots, indexes/constraints, repo interfaces, migration/data transition |
| Auth | Bảo + Vương | Storage/expiry/refresh/logout sau bỏ RefreshTokens; role/ownership |
| Content API | Phúc | Bank/question/template/version, server-only keys, nguồn/publish/animation URL |
| Custom exam | Khánh + Bảo | Redis keys/TTL/status/deadline, snapshot, attempt IDs, save-result API/idempotency |
| AI/proto | Khôi + Vương/Phúc | IDs/version/chunk/Điểm/vision/index/deactivate/errors/cancellation |
| Notification | Khánh + service owners | Event types/topics, producer/consumer, retry/dedup/version và delivery/invalidation |

Vương chốt schema sớm rồi gom migration tích hợp cuối. Bảo/Phúc triển khai repositories/query theo interfaces; gửi thay đổi field/query cho Vương. Không tự sinh migration mới. Mỗi người bàn giao DI extension/tests/config không secret.

## 6. Task IDs bản 27/10

| Owner | Tasks |
| --- | --- |
| Vương | V01 audit/mapping; V02 schema/hai DbContext/repo contracts; V03 migrations riêng từng DB và data transition; V04 chat/attachment/.NET gRPC; V05 Gateway/host/Compose/web shell; V06 integration/demo |
| Bảo | B01 auth không bảng RefreshTokens; B02 User query/repos/services; B03 lưu kết quả/snapshot idempotent; B04 history/progress/report; B05 account/progress UI; B06 auth/ownership tests |
| Phúc | P01 crawler/evidence; P02 SQL content/chunk và index workflow; P03 SQL bank import/publish; P04 questions/templates API; P05 animation URL/hosting; P06 UI học/admin và cron nội dung |
| Khánh | H01 content selection client; H02 Redis custom exam; H03 timer/autosave/scoring/submit; H04 save-result contract; H05 Kafka notification/Worker; H06 exam UI/recovery tests |
| Khôi | K01 generation API; K02 embedding API/dimension; K03 verification/eligibility; K04 proto/index/deactivate/citations; K05 vision/follow-up; K06 errors/tests/telemetry |

Các ID này thay nghĩa trong plan 24/10; PR ghi rõ bản 27/10. Không đánh dấu done chỉ vì code cũ có tên tương tự.

## 7. Giữ source và xử lý xung đột

Remote fetch ngày 27/10: Bảo PRN-BAO-dev 3366119; Khôi PRN-KHOI-dev b7687df; Phúc PRN_Phúc_ASM d40a062; Vương PRN-VUONG-dev c96ae9e. Đây là snapshot source, chưa là bằng chứng chạy chung.

- Bảo có learning entities/repos SQL; Phúc có bank repository lưu file. Chọn SQL Content/Exam làm nguồn chính; giữ parser/API/UI và query/model hợp contract, không merge nguyên hai QuestionBank/IQuestionBankRepository cạnh nhau.
- Giữ durable chat/attachments/Gateway/hạ tầng Vương; chuyển persistence/ownership theo ranh giới mới.
- Review proto field numbers/adapter của Khôi trước tích hợp; một proto nguồn.
- Giữ nhánh/commit đã push và migrations đã tồn tại. Vương rà DB nào đã apply, lập lộ trình cho DB mới và DB có dữ liệu; không rewrite migration để giả lịch sử mới.
- Không dùng backend FLM thay Worker/Exam PRN. Không suy ra Khánh chưa làm gì chỉ từ snapshot nhánh cũ.

## 8. Tích hợp và nghiệm thu

1. Docs lên PRN-dev; mọi người commit việc dở, fetch/merge nền về nhánh cá nhân. Không làm lại từ đầu.
2. P0: schema/contracts đầu tiên. Trong lúc chờ tiếp tục UI/parser/AI/tests độc lập, ngừng migration mới.
3. P1: hai service/DbContext/Gateway skeleton; login, bank SQL, chat/Qdrant đúng ranh giới.
4. P2: import bank → custom exam Redis → autosave/submit → result User DB → history sau Redis expiry. Test owner/no-answer-leak/concurrent submit/version/expiry/restart.
5. P3: Kafka notification có broker ack/retry/dedup; animation URL thật; text/image RAG/errors; monitoring/demo.
6. PR nhỏ về PRN-dev; kiểm tra module và bản ghép. EF pending-model check cho từng --context sau khi context tồn tại. Build không apply migration.

Tài liệu này chưa tạo context/schema/migration, chưa deploy animation, chưa gửi tin nhắn cho đồng đội qua dịch vụ ngoài.
