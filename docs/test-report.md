# Development verification — 21/10/2026

Đây là kết quả developer checks, không phải ARTEMIS hoặc chứng nhận cloud.

| Lệnh | Kết quả đã quan sát |
|---|---|
| flutter analyze | No issues found; sau refactor cuối |
| flutter test --exclude-tags live | 38 passed, 0 failed |
| flutter build apk --debug | Thành công sau refactor cuối; Gradle 13.6s |
| flutter test (toàn bộ, trước refactor import) | 31 passed, 3 failed trong live_backend_e2e_test.dart |

Ba live test thất bại: health check backend false; query nhận HTTP 400; ChatProvider trả MessageStatus.error. Flutter test harness cảnh báo HttpClient bị chặn/trả 400; backend live cũng chưa được nghiệm thu. Không thay API thật bằng mock để ghi live pass. Chưa sửa/chạy lại live suite; lệnh exclude-tags chỉ xác nhận phần unit/widget.

## Test mới (12 case)
- 5 case account namespace/persistence/logout/cancellation/retry.
- 2 case auth gate và cancellation UI ở 360/412 dp.
- 5 case OCR ViewModel: picker cancel/error, empty recovery/duplicate request, merge giữ retake, late response sau dispose.

APK: `flutter_app/build/app/outputs/flutter-apk/app-debug.apk` (build artifact local, không commit binary).

## Còn thiếu để nghiệm thu bài
ARTEMIS ≥10×3 và exploratory; Google sign-in thật; Firebase console evidence; Firestore persistence đa thiết bị và rules; Final web/cross-role/AI. Mọi pass rate ARTEMIS hiện để trống, không suy ra từ 38 unit/widget test.
