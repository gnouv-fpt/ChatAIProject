# Contract schema và cách chạy C2 — 27/10/2026

Owner: **Vương**. Đây là contract P0 đã có code trên PRN-VUONG-dev; không suy ra PRN-dev hoặc nhánh cá nhân khác đã có schema này trước khi merge. Plan và ownership vẫn ở [task.md](../task.md).

**Bổ sung local 02/11/2026:** người dùng đã cho phép thực hiện phần User schema của Vương để hoàn thiện bookmark. Có migration tăng thêm `20261102035546_UserQuestionBookmarks`; không thay migration cũ hoặc Content schema. Bằng chứng và phạm vi: [C2 finalization local](C2-FINALIZATION-LOCAL-2026-11-02.md).

## 1. Hai SQL DB độc lập

| Kho | Context / connection | Bảng vật lý |
| --- | --- | --- |
| TrafficUserDb | UserDbContext / UserConnection | Users, UserChatSessions, UserChatMessages, ExamAttempts, QuestionBookmarks |
| TrafficContentDb | ContentDbContext / ContentConnection | LegalDocuments, LegalDocumentChunks, TrafficQuestionCategories, TrafficQuestions, ExamTemplates, ExamTemplateItems |
| Qdrant | AI service Khôi | Vectors, IDs và metadata theo proto/index contract |
| Redis | Module đề custom Khánh | User-owned exam snapshots/state/deadline/TTL; SQL bank là nguồn chính |

Tất cả entity IDs tiếp tục dùng Guid để giữ IDs từ source đã có; không đổi hàng loạt sang int trong hình. Enums lưu string. Timestamps lưu UTC, UI hiển thị Việt Nam. SQL có thể cùng instance nhưng là hai databases, không FK/navigation/transaction/join EF xuyên DB.

UserDbContext/ContentDbContext là contexts runtime. ChatAIWebDbContext và migrations cũ được giữ để đọc lịch sử; không đăng ký runtime hoặc apply bộ cũ lên DB mới. CLR RefreshToken/navigation còn lại chỉ phục vụ legacy context; UserDbContext ignore chúng và không có bảng RefreshTokens.

## 2. Field và constraints

### User DB

- Users giữ auth/profile/quota fields sẵn có; unique Username/Email.
- UserChatSessions giữ UserId FK nội bộ, title, timestamps và soft delete.
- UserChatMessages giữ turn/request/lease fields cho idempotency; unique (SessionId, RequestId) khi RequestId khác null; index lịch sử theo session/time.
- CitationsJson là collection snapshot: citation ID, logical DocumentChunkId, hash, title, Điều/Khoản/Điểm, excerpt, source URL. Không có bảng Citations/FK tới Content DB. JSON comparer phát hiện thay đổi collection và lưu cùng message.
- ExamAttempts: Id (stable attempt/idempotency key), UserId, ExamCode, ExamVersion, Score, IsPassed, TimeSpentSeconds, UserAnswersJson, ExamSnapshotJson, SubmissionHash, SubmittedAt.
- Attempt chỉ FK UserId; ExamCode/version tham chiếu logic tới đề mẫu/custom. Score/time không âm; version dương; hai JSON fields phải hợp lệ. Cùng attempt ID không được insert lần hai.
- Attempt JSON phải giữ đủ câu/options/permutation/answer/profile/version cần xem lại sau Redis expiry. Bảo/Khánh định nghĩa DTO sinh viên; không trả server answer snapshot qua API làm bài.
- QuestionBookmarks: Id, UserId, QuestionId, CreatedAt (UTC); unique (UserId, QuestionId), index (UserId, CreatedAt). Chỉ FK UserId → Users; QuestionId là ID logic của Content, không navigation/FK xuyên DB. PUT/DELETE idempotent, truy vấn theo user; chỉ hiển thị câu thuộc catalog đang xuất bản.
- Token quota source đang được quyết toán cùng transaction hoàn tất chat trong User DB, không cần Kafka/Worker. Replay không trừ lại. Legacy event columns được giữ để review dữ liệu cũ; chat mới không phát ChatCompletedEvent trừ quota.

### Content/Exam DB

- LegalDocuments/LegalDocumentChunks giữ field crawler/RAG sẵn có, thêm document Version (mặc định CLR 1), ContentHash. DocumentNumber unique, version dương. Chunk.VectorId là ID tương ứng Qdrant.
- TrafficQuestionCategories: Id, Type (RULES/CULTURE/DRIVING/MECHANICS/SIGN/SCENARIO theo sáu chương nguồn CSGT 2025), SubCategoryCode unique, Name. Type vẫn là string trong schema; whitelist sáu giá trị nằm ở nghiệp vụ import. TotalQuestions derive bằng COUNT, không lưu số đếm dễ lệch.
- TrafficQuestions: Id, CategoryId, nullable LegalDocumentChunkId (hai FK nội bộ), BankCode, BankVersion, QuestionCode, IsParalysisQuestion, AllowOptionShuffle, QuestionPayloadJson, CorrectAnswerKey, ExplanationText, ExplanationAnimationUrl, SourceUrl, IsPublished, CreatedAt.
- Unique (BankCode, BankVersion, QuestionCode); BankVersion > 0; payload là JSON hợp lệ. Animation là URL HTTPS tới HTML được host riêng. Business service Phúc validate URL/key/assets trước publish; có column chưa có nghĩa đã deploy.
- Payload đề xuất: content, options [{key,text}], img_url hoặc assets và metadata nguồn. Key phương án ổn định, không dùng vị trí hiển thị để chấm.
- CorrectAnswerKey theo C2 hiện là một key. Import bank cũ có nhiều CorrectOptionIds phải báo không tương thích hoặc đề xuất schema mới; không tự bỏ bớt key.
- ExamTemplates: Id, ExamCode, Version, Title, DurationMinutes > 0, PassingScore >= 0, IsPublished, CreatedAt. Unique (ExamCode, Version).
- ExamTemplateItems: Id, ExamTemplateId, QuestionId, OrderIndex > 0. Unique (template, question) và (template, order); không xóa question đang được tham chiếu.
- Profile/critical policy phải đi cùng snapshot mà Phúc/Khánh thống nhất; không dùng điểm/thời gian hard-code để thay profile có nguồn. Published version không sửa âm thầm.

## 3. Map code các nhánh đang có

| Source cũ | Chuyển theo contract |
| --- | --- |
| Bảo LearningAttempt/AttemptAnswer | In-progress custom state ở Redis; submitted result/answers/snapshot ở ExamAttempts; bỏ navigation Bank/Template xuyên DB |
| Bảo Question/QuestionBank | Map vào Content TrafficQuestions/categories/templates; giữ IDs và source version mapping |
| Phúc file QuestionBankPackage/BankQuestion | Giữ parser/import/validation/DTO/UI; SQL Content là nguồn ghi chính, file là input/fixture |
| Phúc Version dạng string | BankVersion là revision nội bộ int dương; lưu mapping source version rõ trong manifest/payload, không int.Parse mù |
| IsCritical, AllowOptionShuffle | IsParalysisQuestion, AllowOptionShuffle; giữ policy và stable option keys |
| Chat citations entity | CitationsJson snapshot trong UserChatMessages; không Include Citations như navigation |
| Legacy DefaultConnection | UserConnection hoặc ContentConnection theo host |

Không merge nguyên hai QuestionBank/IQuestionBankRepository cạnh nhau. Repo contracts có sẵn: IExamAttemptRepository (owned/history), IQuestionCatalogRepository (published pool/template), IContentChunkRepository. Nghiệp vụ idempotent submit/DTO/errors do Bảo/Khánh nối; duplicate PK phải được xử lý đúng contract, không coi generic repository là exam service hoàn chỉnh.

## 4. Host và API ownership

Dùng chung binary Presentation nhưng chạy hai process/container độc lập:

~~~powershell
dotnet run --project Presentation --launch-profile http
dotnet run --project Presentation --launch-profile content
dotnet run --project ApiGateway --urls http://localhost:8080
~~~

User API mặc định port 5039; Content port 5040. Service:Module chỉ nhận User/Content. Host chỉ đăng ký DbContext và repositories của DB nó sở hữu. Content controller phải thêm [ServiceModule("Content")]; controller không gắn module mặc định thuộc User. Mỗi module bàn giao DI extension cho Vương nối vào nhánh host tương ứng; API chưa bàn giao không tự xuất hiện nhờ route Gateway.

Gateway routes documents/question-banks/questions/exam-templates/crawl-jobs/document-index và admin/question-banks sang Content; phần API khác sang User. /health/ready kiểm tra SQL User, /health/content/ready kiểm tra SQL Content. Readiness này chưa chứng minh AI/Kafka/Redis hoạt động.

Chat kiểm tra citation qua POST /internal/content/chunks với body Guid[], tối đa 50 IDs. Content trả snapshot nội dung/metadata/version. HTTP client gửi JWT service ngắn hạn với audience riêng và scope content.read; user access/refresh token không được gọi endpoint này. Gateway chặn /internal.

Kiểm tra Content diễn ra ngoài transaction User DB. Không có atomic commit xuyên service: snapshot phản ánh lần kiểm tra trước commit; việc invalidation/version events tiếp theo do contract Kafka của Khánh/Phúc nối. Không tuyên bố loại bỏ mọi race thay đổi luật giữa hai service.

## 5. Auth không bảng refresh

Để các host chạy được khi bỏ bảng, adapter hiện tại giữ response/API auth cũ nhưng refresh token là JWT ký, audience/type tách access và service token. Client hiện giữ tokens trong bộ nhớ. Refresh kiểm tra chữ ký/issuer/audience/type/expiry và user còn tồn tại; trả access token mới, giữ nguyên refresh token và hạn tuyệt đối.

Logout trả 204, client phải xóa cả hai tokens. Không single-use rotation hoặc per-token revocation phía server; refresh token cũ còn dùng tới expiry. Access/refresh cũ của hệ thống trước chuyển đổi không được coi là tương thích refresh mới. Bảo tiếp tục làm auth/UI theo contract này; nếu đổi semantics phải đổi contract/tests cùng lúc. Shared Jwt signing settings phải thống nhất giữa hai host; không commit key.

## 6. Migrations và cấu hình

ConnectionStrings:UserConnection và ContentConnection cấu hình qua user-secrets/environment. Không dùng lại database ChatAIWebDb để chạy bộ migrations mới. Database:MigrateOnStartup mặc định false.

Sau khi apply schema, nếu cần tài khoản admin đã cấu hình trong user-secrets, chạy User host với --Auth:SeedAdminOnStartup true. Flag này seed độc lập với migrate và mặc định false; không cần bật tự động migration chỉ để seed admin. Compose có SEED_ADMIN_ON_STARTUP tương ứng.

~~~powershell
dotnet user-secrets set "ConnectionStrings:UserConnection" "<connection to TrafficUserDb>" --project Presentation
dotnet user-secrets set "ConnectionStrings:ContentConnection" "<connection to TrafficContentDb>" --project Presentation
pwsh -File scripts/migrate-c2.ps1
~~~

Lệnh script mặc định chỉ kiểm tra model và sinh SQL idempotent vào artifacts/c2-migrations; không apply. EF design factories không cần boot API/JWT để tạo model.

Để apply lên hai DB đích đã chọn, truyền rõ hai connections qua environment rồi:

~~~powershell
pwsh -File scripts/migrate-c2.ps1 -Apply
~~~

Script yêu cầu connection đích rõ ràng, từ chối DB hệ thống/ChatAIWebDb và hai targets trùng nhau. Không có transaction chung hai DB; nếu DB thứ hai lỗi, sửa rồi chạy lại, không tuyên bố rollback cả hai.

Owner Vương tạo migration riêng với --context UserDbContext --output-dir Migrations/User hoặc --context ContentDbContext --output-dir Migrations/Content. Các thành viên khác không tự sinh migration/sửa snapshots.

Bộ mới gồm UserInitialCreate, ContentInitialCreate, ContentVersionMetadata. Migrations cũ giữ nguyên. Chưa có công cụ chuyển dữ liệu từ schema cũ: trước chuyển DB có dữ liệu, rà applied migrations, pending turns/quota/events, map IDs và citation snapshots; backup/copy có kiểm chứng rồi mới đổi connections. Các lệnh trên tạo schema mới, không tự chuyển dữ liệu cũ hay xóa RefreshTokens ở DB legacy.

Compose chạy user-service/content-service, hai database riêng trên sqlserver, Redis bắt buộc, Gateway và AI/Qdrant. Kafka init dùng service-notifications/service-notifications-dlq làm tên handoff; Khánh chốt consumers/payload/retry. Worker vẫn là image bàn giao qua profile worker. Chưa có Worker/Redis exam engine hoàn chỉnh chỉ nhờ cấu hình này.

## 7. Kiểm tra và bằng chứng

~~~powershell
dotnet build ChatAIWeb.slnx
dotnet test tests/ChatAIWeb.Tests
~~~

Để chạy thêm SQL concurrency tests, đặt VUONG_TEST_SQL tới một User DB test riêng đã migrate. Không dùng DB thật của team.

~~~powershell
pwsh -File scripts/verify-c2-gateway.ps1
~~~

Smoke script cần hai test connections đã migrate qua ConnectionStrings__UserConnection/ContentConnection. Nó chạy và dừng ba process riêng, lưu checks.json không chứa tokens trong artifacts/c2-smoke; tạo test account/session trong DB test. Cần build Debug trước khi chạy.

Kết quả thực tế và giới hạn: [C2-VERIFICATION-2026-10-27.md](C2-VERIFICATION-2026-10-27.md). Chưa nghiệm thu engine Redis/Kafka/AI provider thật hoặc Docker runtime của cả nhóm.
