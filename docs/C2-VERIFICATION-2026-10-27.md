# Bằng chứng C2 — Vương — 27/10/2026

Nhánh làm việc: PRN-VUONG-dev. Chỉ dùng databases test mới, không apply migrations mới lên ChatAIWebDb hoặc DB dùng chung.

## Đã chạy

- dotnet build ChatAIWeb.slnx: 0 warning/error.
- 42 tests pass, 0 skip khi VUONG_TEST_SQL chỉ tới User DB test SQL Server local. Có hai tests concurrency dùng contexts SQL độc lập và test seed admin độc lập với migration-on-startup.
- EF pending-model checks riêng UserDbContext/ContentDbContext: không pending.
- Apply UserInitialCreate lên TrafficUser_C2_Verify_20261027; ContentInitialCreate/ContentVersionMetadata lên TrafficContent_C2_Verify_20261027, SQL Server local instance MSSQLSERVER_VUON.
- Query sys.tables: User gồm Users/UserChatSessions/UserChatMessages/ExamAttempts; Content gồm LegalDocuments/LegalDocumentChunks/TrafficQuestionCategories/TrafficQuestions/ExamTemplates/ExamTemplateItems (ngoài bảng migration history). Không RefreshTokens hoặc FK chéo.
- Upgrade test: apply ContentInitialCreate vào TrafficContent_C2_Upgrade_Verify_20261027, insert document fixture, apply ContentVersionMetadata. Row giữ được và Version=1; default migration được đặt 1 trước CHECK version > 0.
- Hai host User/Content và Gateway chạy process thật trên SQL Server test: 14 HTTP checks pass. Xem [checks.json](evidence/vuong-c2-2026-10-27/checks.json).
- HTTP integration tests qua TestServer kiểm tra internal service JWT/scope, controller isolation và content snapshot serialization. Đã sửa string-enum deserialization giữa hai service.
- Migration helper mặc định sinh hai SQL idempotent scripts; không apply. Scripts nằm trong artifacts/c2-migrations và được ignore.
- Migration helper -Apply đã chạy lại trên hai DB test và xác nhận up-to-date; guard từ chối hai targets trùng nhau hoặc DB legacy trước khi gọi EF. Đã sửa cách truy cập DbConnectionStringBuilder qua CLR để tránh IDictionary adapter của PowerShell.
- Docker Compose config parse thành công bằng giá trị config kiểm tra; Redis hiện là service mặc định, hai SQL DB connections và hai host độc lập.
- Token tests: wrong audience/type/signature/expiry bị từ chối, refresh không dùng làm access; refresh giữ hạn tuyệt đối; logout không giả vờ revoke token phía server.

## Giới hạn

- Docker engine không chạy trong lần kiểm tra; chưa build/chạy Compose hoặc monitoring stack mới.
- Test inference dùng fixtures, chưa gọi provider AI/vision hoặc Qdrant thật trong lần này.
- Redis custom-exam engine, Kafka producer/consumer notification, nội dung bank/import/UI của các nhánh khác chưa được ghép/kiểm chứng toàn luồng. Các contracts này do owners nối tiếp.
- Chưa deploy animation HTML (Phúc sở hữu assets/URL).
- Chưa chuyển dữ liệu legacy hoặc xóa RefreshTokens trên DB legacy; contexts/migrations legacy chỉ được giữ làm lịch sử. New User DB không có bảng này.
- Chưa có transaction hay đảm bảo snapshot atomic xuyên hai service; kiểm tra citation phản ánh thời điểm gọi Content API.
- Test databases được giữ để review. Smoke script dừng các process nó khởi tạo.
