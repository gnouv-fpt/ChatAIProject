# Phúc → Vương: nhu cầu Content/Exam P0 (bản 27/10, cập nhật 28/10/2026)

Đây là đề xuất field/query/API để owner schema chốt; **không phải migration hay schema đã được phê duyệt**. Không gửi thông điệp ra dịch vụ ngoài. Các model bank trong nhánh Phúc ngày 26/10 là legacy transport/fixture; không merge thêm một bộ entity trùng của Bảo.

## Phạm vi dữ liệu

Chỉ Content/Exam DB: luật/chunks, categories/questions, templates/items. Phúc không truy vấn User DB để lấy attempt/role/progress; UserId trong audit là logical reference, không FK/navigation xuyên DB. User/Exam engine lấy snapshots qua API/event. Giữ GUID/UTC hiện tại cho tới khi Vương phát hành ID mapping.

## Field cần cho luật và chunks

- Legal document: ID, số hiệu, tiêu đề, loại, cơ quan ban hành, URL nguồn, effective/expiration UTC, verification state, nguồn/evidence được review, thời điểm lấy và xác minh, content version/hash, published/active state, concurrency marker.
- Chunk: ID ổn định, DocumentId nội bộ Content DB, version/content hash, **Sequence** để tái lập toàn văn đúng thứ tự, Chapter/Article/Clause/**Point**, Content, eligibility/verification state, vector ID/index generation nếu contract AI dùng.
- Evidence tối thiểu: canonical source URL, RetrievedAtUtc, HTML SHA-256, normalized content SHA-256, reviewer logical ID + review evidence/notes. Không suy ra Verified chỉ từ số hiệu hoặc selector thành công.
- Unique constraints/idempotency cần chốt: document identity theo số hiệu/version; chunk identity theo document/version/sequence hoặc stable ID; không ghi đè version đã được dùng làm citation.
- Query cần có: list/filter loại/hiệu lực/verification/paging; get detail + ordered chunks; source/số hiệu/version dedupe; find pending indexing/expiry; resolve citation eligibility theo chunk/document IDs + exact version.
- Transaction chỉ trong Content DB: persist document + chunks/evidence; transition publish/eligibility + pending notification/index work theo contract Khánh/Khôi. Không transaction Qdrant hoặc User DB.

Parser preview hiện trả Sequence, Article, Clause, Point và hashes trong DTO; entity cũ thiếu Sequence/Point/version/evidence nên **chưa thể persist đủ bằng schema cũ**. Phúc chưa sửa entity/context/migration.

## Field cần cho bank và đề mẫu

Target tables vẫn theo C2: TRAFFIC_QUESTION_CATEGORIES, TRAFFIC_QUESTIONS, EXAM_TEMPLATES, EXAM_TEMPLATE_ITEMS. Vương chốt cách biểu diễn bank/version/profile/import batch/hash (JSON/envelope/field cụ thể), không tự thêm QuestionBanks song song.

- Question: ID, category ID, source question number, bank/version/hash identity, text, stable option IDs/text, **server-only answer key**, explanation, source URL/evidence, critical/shuffle policy, immutable asset metadata và **ExplanationAnimationUrl nullable** (HTTPS, tối đa 2048 ký tự theo validator hiện tại).
- Category: ID/key/title và scope bank/version. Topic trong legacy import là text; cần mapping có lỗi rõ khi category không tồn tại.
- Profile/template: ID/code, version/hash, source, count/duration/pass/critical rules, published state; template items giữ question/version và sequence. Cần snapshot/profile version để sửa nội dung không thay kết quả bài cũ.
- Import audit/state: draft/preview/publish, imported/reviewed/published UTC + actor logical ID, content hash và concurrency token. Vương chốt vị trí audit storage phù hợp schema đích.
- Constraints: version nội dung đã publish bất biến; không trùng question ID/source number trong bank/version; template item không trùng câu; key phải thuộc stable option IDs; publish chặn thiếu source/assets/profile.
- Query: bank/version summaries; category list; question detail/filter/range/paging; published template detail + ordered items; **server-only pool snapshot** có keys cho engine Khánh qua authenticated service contract; Admin full preview; read DTO public luôn loại key/explanation/animation khi đang làm bài.

## Contracts cần bàn giao

1. **Vương**: tên contexts/connections/hosts, entity/ID mapping, repositories/query signatures, mapping JSON/sequence/version, transaction/concurrency guarantees, migration/data transition. Phúc triển khai SQL queries theo interfaces đã chốt, không tự sinh migration.
2. **Khánh**: identity của service caller + auth policy cho pool có key; N/filter/seed/snapshot shape, template selection; envelopes notification khi publish/deactivate. Role Admin của người dùng không được dùng làm service credential mặc định.
3. **Khôi/Vương**: stable chunk IDs/version/Point, index ack semantics/retry/deactivate và lỗi; User service resolve citations qua Content API; không đọc Content DbContext trực tiếp.
4. **Bảo**: answer/animation visibility sau durable result save và review ownership. Không phát animation URL trong active attempt/pool public vì trang animation có thể chứa lời giải.

Không tự mở endpoint có keys cho role User. UI flag chỉ ẩn liên kết, không thay authorization backend.

## Chuyển từ file sang SQL

Giữ file legacy nguyên vẹn để review/import; **không dual-write**. Production DI hiện không đăng ký FileQuestionBankRepository, API bank trả 503 cho đến khi SQL adapter được tích hợp. Test host đăng ký file adapter tường minh để kiểm thử contract cũ.

Sau P0: đọc file → validate manifest/assets/source → map IDs/category/version theo contract → import draft vào Content SQL transaction → review/publish → index/notification theo contracts. Không sao chép publication marker thành SQL Verified mà không revalidate. Hash legacy typed bank và hash manifest có animations là hai giá trị khác nhau; cần chiến lược migration rõ.
