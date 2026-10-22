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

## Cập nhật 22/10/2026
- Flutter tests: 43 passed, 0 failed với `flutter test --exclude-tags live`; raw log ở `evidence/firebase/2026-10-22/flutter-tests.log`.
- Firestore: 9/9 pass ở emulator Standard, sau đó 9/9 pass ở Enterprise 1.22.0. Raw log `rules-emulator-enterprise.log` là bản khớp edition production; dùng demo project, không ghi production.
- Rules và indexes đã deploy thành công vào named database flm-app; metadata trả ENTERPRISE/FIRESTORE_NATIVE/asia-southeast1/freeTier=true/realtime enabled.
- Analyzer: No issues found sau cloud integration; APK debug build thành công và install/launch thành công trên FLM_API36 (Android 36). Ảnh android-login.png và android-login-error.png là ảnh thật từ ADB.
- Emulator có Google Play Services nhưng chưa có tài khoản Google. Google sign-in attempt hiển thị lỗi có retry; không tính là login thành công. Chưa có pass rate ARTEMIS.
- Web release build với `--no-web-resources-cdn` thành công. Bản debug localhost bị treo tải DDC; bản 127.0.0.1 render được login nhưng domain đó chưa nằm trong authorized domains. Không dùng các lượt đó làm bằng chứng đăng nhập.
- Cloud profile/transcript có code, tests repository và rules; smoke bằng Google account thật còn mở. Chưa có FCM/Storage/Analytics/Crashlytics/Remote Config evidence.

## Kiểm tra trước bàn giao nhóm — 22/10/2026
Phát hiện và sửa SettingsScreen che nút đăng xuất khi profile loading/error. Hai regression test mới pass; toàn suite không cần backend đạt 45/45, flutter analyze sạch. APK sau sửa build thành công (9.7s). File settings_sign_out_test.dart xác minh hai trạng thái này. Không chạy lại rules vì không đổi rules; không đổi trạng thái của live backend/Google production/ARTEMIS thành pass. Xem team-handoff.md để biết phạm vi commit và các gap còn mở.
