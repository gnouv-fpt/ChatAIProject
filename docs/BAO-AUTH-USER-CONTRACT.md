# Đề xuất contract P0 của Bảo — Auth và User DB (C2 27/10/2026)

Trạng thái: **đề xuất**, chờ Vương (schema/auth) và Khánh (save-result) xác nhận. Tài liệu không tạo migration và không sửa schema chung. Task IDs theo bản 27/10.

## 1. Auth không bảng RefreshTokens (B01, Bảo + Vương)

Đã code trên PRN-BAO-dev: `AuthService` và `JwtTokenService` không còn đọc/ghi `RefreshTokens`. Entity, DbSet, repository và migration cũ vẫn giữ nguyên để Vương gỡ trong migration tích hợp của User DB.

| Hạng mục | Hành vi hiện tại |
| --- | --- |
| Routes | Giữ nguyên `register/login/refresh-token/logout/profile`, request/response không đổi nên web client không phải sửa |
| Access token | JWT HS256, `aud = Jwt:Audience`, sống `Jwt:AccessTokenMinutes` (60), claims như cũ |
| Refresh token | JWT HS256 ký cùng secret, `aud = {Audience}.refresh`, claims `sub`, `sstamp`, `jti`, sống `Jwt:RefreshTokenDays` (7). Client tự lưu |
| Phân tách loại token | JwtBearer chỉ nhận `Audience`, endpoint refresh chỉ nhận `{Audience}.refresh`, nên hai loại không dùng thay nhau được |
| Refresh | Kiểm tra chữ ký/issuer/audience/hạn, user còn tồn tại và `sstamp` khớp, rồi cấp cặp token mới |
| `sstamp` | HMAC-SHA256(secret, PasswordHash), lấy 16 byte. Đổi mật khẩu thì mọi refresh token cũ mất hiệu lực, không cần bảng |
| Logout | 204, idempotent. Client xóa token; server không thu hồi |

**Không còn đảm bảo** (contract cũ dựa vào bảng):

- Refresh token **không single-use**: token cũ vẫn refresh được tới khi hết hạn.
- Logout **không thu hồi** token đã phát. Access token còn sống tới hết `AccessTokenMinutes`.
- Không thu hồi từng thiết bị riêng lẻ.

**Đề xuất cho Vương:** thêm `USERS.TokenVersion int NOT NULL DEFAULT 0` và đưa claim `tv` vào refresh token. Logout/"đăng xuất mọi nơi" sẽ tăng `TokenVersion`, còn refresh từ chối token có `tv` cũ. Như vậy thu hồi được theo user mà không cần bảng token. Nếu nhóm không thêm, giữ hành vi ở bảng trên và đổi mô tả Swagger thành "logout phía client".

Cần chốt thêm: có giữ refresh không (đề xuất: giữ), và có giảm `AccessTokenMinutes` xuống 15 khi không thu hồi được không.

## 2. Nhu cầu field/query User DB gửi Vương (B02–B04)

Không FK sang Content DB. `ExamCode`, `QuestionId`, `TemplateId`, `BankVersion` là tham chiếu logic.

### USERS

Giữ: `Id (Guid)`, `Username` unique, `Email` unique (lưu lowercase), `PasswordHash`, `Role` (string), `TokenQuota`, `TokenBalance`, `CreatedAt` UTC. Thêm `TokenVersion` nếu chốt mục 1.

### EXAM_ATTEMPTS (thay LearningAttempts/AttemptAnswers trong migration `LearningAndAttachments`)

| Field | Ghi chú |
| --- | --- |
| `Id` Guid | Attempt ID do Khánh sinh lúc tạo đề custom, ổn định qua retry |
| `UserId` | FK USERS, index `(UserId, SubmittedAt desc)` cho history |
| `ExamCode` | Mã đề custom (Redis) hoặc mã đề mẫu |
| `Source` | `Custom` / `Template` (string enum) |
| `TemplateId?`, `BankVersion` | Tham chiếu logic sang Content DB |
| `CategoryIds` JSON | Chủ đề được chọn, dùng cho progress theo chủ đề |
| `StartedAt`, `DeadlineAt?`, `SubmittedAt` | UTC |
| `SubmitKey` | Idempotency key; **unique `(UserId, SubmitKey)`** chống retry/concurrent submit |
| `QuestionCount`, `CorrectCount`, `WrongCount`, `UnansweredCount`, `Score`, `IsPassed`, `FailReason?` | Kết quả chấm |
| `SnapshotJson` | Mỗi câu: `questionId`, `position`, nội dung/ảnh/options đã hiển thị (giữ option IDs), `correctOptionIds`, `selectedOptionIds`, `isCorrect`, `isCritical`, `explanationAnimationUrl?`. Đủ để xem lại sau khi Redis hết hạn hoặc bank đổi |
| `RowVersion` | Concurrency |

Đề xuất bỏ hẳn `QuestionBookmarks` vì C2 không có. Nếu nhóm vẫn muốn bookmark, Vương quyết định có thêm bảng hay không.

### Query Bảo cần trong repository interface

- `GetAttemptPageAsync(userId, page, size, source?)`: history, mới nhất trước, không load `SnapshotJson`.
- `GetAttemptAsync(userId, attemptId)`: kèm snapshot, lọc owner.
- `FindBySubmitKeyAsync(userId, submitKey)`: cho idempotency.
- `GetQuestionOutcomesAsync(userId)`: lần làm gần nhất mỗi `questionId` (parse snapshot hoặc dùng cột computed). Phục vụ progress/câu sai/câu chưa làm; danh sách câu tổng lấy từ Content API của Phúc.
- Usage report: đếm messages/tokens từ USER_CHAT_MESSAGES theo ngày/user. Không có bảng UsageReports.

## 3. Save-result contract (B03, Bảo + Khánh)

`POST /api/internal/exam-attempts` (gọi service-to-service qua Gateway, hoặc qua method `IExamAttemptService.SaveResultAsync` nếu cùng host). Auth: token user gốc, kiểm tra `sub == UserId`.

```json
{
  "attemptId": "guid", "submitKey": "guid", "examCode": "C-8F2K", "source": "Custom",
  "templateId": null, "bankVersion": "2026.10", "categoryIds": ["..."],
  "startedAt": "UTC", "deadlineAt": "UTC", "submittedAt": "UTC",
  "result": { "correct": 21, "wrong": 3, "unanswered": 1, "score": 21, "isPassed": true, "failReason": null },
  "items": [ { "questionId": "...", "position": 1, "snapshot": { }, "correctOptionIds": ["b"], "selectedOptionIds": ["b"], "isCorrect": true, "isCritical": false } ]
}
```

- Lần đầu trả `201` kèm attempt. Retry cùng `(UserId, SubmitKey)` và payload trùng trả `200` với kết quả đã lưu. Cùng key nhưng payload khác trả `409`.
- Khánh chỉ xóa hoặc đánh dấu Redis sau khi nhận 200/201 (durable save).
- Bảo không chấm lại. Điểm do engine Khánh tính theo đáp án chuẩn; User service chỉ kiểm tra tính nhất quán số đếm.

## 4. Việc tiếp theo của Bảo khi schema P0 phát hành

1. B02: đổi `LearningAttemptRepository`, `LearningProgressRepository` sang EXAM_ATTEMPTS theo interface của Vương.
2. B03: `ExamAttemptService.SaveResultAsync` theo mục 3, kèm test retry/concurrent.
3. B04: progress/history/report đọc từ attempts + Content API. Bỏ phụ thuộc Question/QuestionBank SQL cũ.
4. B05: UI account/progress đổi theo DTO mới. B06: test auth (đã có) + ownership attempts.
