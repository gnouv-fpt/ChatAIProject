# Tiến độ - Bảo (Database & Auth REST API)

Nhánh: `feature/bao-db-auth` (dựa trên `PRN-dev`)

## 1. Database & Architecture

- [x] Chuyển `Presentation` từ Razor Pages sang ASP.NET Core Web API thuần (bỏ Cookie Auth, Hubs, Pages cũ).
- [x] Thiết kế lại schema `ChatAIWebDb` đúng theo `requirement.md` (thay hoàn toàn domain cũ):
  - `Users`, `RefreshTokens`, `LegalDocuments`, `DocumentChunks`, `ChatSessions`, `ChatMessages`, `Citations`, `ViolationLogs`, `UsageReports`.
- [x] Viết Entity classes (`BusinessObject/Entities`) + Enums (`UserRole`, `VerificationStatus`, `SenderRole`, `LegalDocumentType`).
- [x] Viết `ChatAIWebDbContext` (`DataAccess/ChatAIWebDbContext.cs`) với cấu hình quan hệ, index, cascade delete, lưu enum dạng string, ép `DateTime` về UTC.
- [x] Tạo EF Core migration `InitialCreate`, app tự động `Database.MigrateAsync()` khi khởi động.
- [x] Repository Pattern: `IGenericRepository<T>` dùng chung + `UserRepository`, `RefreshTokenRepository` cho query riêng.
- [x] 3-Layer Architecture đúng chuẩn: `BusinessObject → DataAccess → BusinessLogic → Presentation`, không có tầng nào vi phạm chiều phụ thuộc.

## 2. Auth REST API Module

- [x] `AuthController` (`/api/auth`):
  - `POST /register` — đăng ký, trả JWT + refresh token luôn.
  - `POST /login` — đăng nhập.
  - `POST /refresh-token` — cấp access token mới, refresh token cũ bị thu hồi (rotation, single-use).
  - `POST /logout` — thu hồi refresh token.
  - `GET /profile` — cần JWT, trả thông tin user (bao gồm `TokenQuota`, `TokenBalance`).
- [x] JWT Bearer Authentication (HS256), claim gồm `UserId`, `Username`, `Email`, `Role`, `TokenQuota`.
- [x] Access token & refresh token có thời hạn cấu hình được (xem mục "Thời hạn token" bên dưới).
- [x] Refresh token: sinh ngẫu nhiên, chỉ lưu SHA-256 hash trong DB (không lưu plaintext).
- [x] Mã hoá mật khẩu bằng PBKDF2-HMACSHA256 (`PasswordHasher`, 100k vòng lặp).
- [x] Validate input bằng DataAnnotations (email hợp lệ, mật khẩu ≥ 8 ký tự, username 3-50 ký tự).
- [x] Global Exception Handling (`GlobalExceptionHandler`) — mọi lỗi trả về dạng ProblemDetails (RFC 7807) kèm thông báo tiếng Việt, không lộ stack trace.
- [x] Swagger/OpenAPI có nút Authorize để test JWT trực tiếp.
- [x] Seed tài khoản Admin khi khởi động (qua cấu hình `Auth:SeedAdmin`).
- [x] Không hard-code secret: JWT secret key + mật khẩu admin đọc từ `dotnet user-secrets` / biến môi trường.

### Thời hạn token

Cấu hình trong `Presentation/appsettings.json`:

```json
"Jwt": {
  "AccessTokenMinutes": 60,
  "RefreshTokenDays": 7
}
```

- **Access token**: hết hạn sau 60 phút.
- **Refresh token**: hết hạn sau 7 ngày (`refreshTokenExpiresAt` trong response `/login`, `/register`, `/refresh-token`).
- Refresh token bị coi là không hợp lệ khi **một trong hai** điều kiện xảy ra (`RefreshToken.IsActive`, `BusinessObject/Entities/RefreshToken.cs`):
  1. Đã bị revoke (dùng rồi — rotation single-use, hoặc do gọi `/logout`).
  2. Đã quá `ExpiresAt` (quá 7 ngày kể từ lúc cấp).
- Cả hai trường hợp trên đều trả **401** với cùng thông báo: `Refresh token không hợp lệ hoặc đã hết hạn.`
- Đổi thời hạn: chỉ cần sửa `AccessTokenMinutes` / `RefreshTokenDays` trong `appsettings.json`, không cần build lại code.

## 3. Kiểm thử đã thực hiện

- [x] Build toàn bộ solution: 0 lỗi, 0 warning.
- [x] Chạy API thật với SQL Server local, kiểm tra bằng `curl` từng case:
  - Đăng ký thành công (201), trùng email (409), dữ liệu không hợp lệ (400).
  - Đăng nhập sai mật khẩu (401), đăng nhập đúng trả JWT.
  - Gọi `/profile` không có token (401), có token hợp lệ (200), token bị sửa (401).
  - Refresh token: dùng được 1 lần, dùng lại token cũ bị từ chối (401).
  - Logout xong thì refresh token không dùng lại được (401).
  - Đăng nhập admin trả đúng `role: Admin`.
- [x] Kiểm tra Swagger UI hiển thị đủ 5 endpoint + schema.

## 4. Tài liệu

- [x] Viết lại `AGENTS.md` theo kiến trúc Web API mới (thay bản Razor Pages cũ) để hướng dẫn cả nhóm và AI code assistant đi đúng hướng.
- [x] Script setup 1 lệnh cho cả nhóm (`scripts/setup.ps1`, `scripts/setup.sh`).

## 5. Chưa làm / không thuộc phạm vi của Bảo

- [ ] Chat REST API, gRPC Client — của Vương.
- [ ] Document REST API, Crawler, Cron Job — của Phúc.
- [ ] gRPC Inference Service, Qdrant, Verification Engine — của Khôi.
- [ ] Message Broker (Redis/Kafka), Worker Service, Email Alert — của Khánh.
- [ ] Docker Compose, Dockerfiles — của Vương.

## Ghi chú cho các bạn khác trước khi pull

- Đã xoá toàn bộ domain cũ (Subject, RAGAS, EvaluationQuestion...) — code cũ lấy lại từ commit `f178699` nếu cần.
- Nếu máy đã có DB `ChatAIWebDb` theo schema cũ, nên `DROP DATABASE` trước khi chạy lần đầu để tránh xung đột migration.
- Auth chuyển hẳn sang JWT Bearer, không còn Cookie Authentication.

## Setup 1 lệnh sau khi pull

```bash
pwsh -File scripts/setup.ps1   # Windows
bash scripts/setup.sh          # macOS/Linux
```

Script tự động: restore packages, tạo `Jwt:SecretKey` ngẫu nhiên (bỏ qua nếu máy đã có), seed tài khoản admin mặc định (`admin@chataiweb.local` / `Admin@123456`), build solution. Sau đó chỉ cần:

```bash
dotnet run --project Presentation --launch-profile http
```

Database sẽ tự tạo/migrate khi chạy lần đầu — chỉ cần máy có SQL Server (local, LocalDB, hoặc container) và connection string đúng trong `Presentation/appsettings.json`.

## Cách test Refresh Token (Swagger hoặc curl)

1. Gọi `POST /api/auth/login` (hoặc `/register`) → copy `refreshToken` trong response.
2. Gọi `POST /api/auth/refresh-token` với `{ "refreshToken": "<token>" }` → nhận **200** kèm `accessToken` + `refreshToken` **mới hoàn toàn**.
3. Gọi lại `/refresh-token` với **refreshToken cũ** (vừa dùng ở bước 2) → phải trả **401** (single-use, chống replay).
4. Gọi `POST /api/auth/logout` với một refresh token đang active, sau đó gọi `/refresh-token` với token đó → cũng phải **401**.
