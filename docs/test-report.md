# Development verification — 21/10/2026

## Kiểm tra tiếp 29/10/2026

- `flutter analyze --no-pub`: sạch. Full `flutter test --no-pub --exclude-tags live --concurrency=1 --reporter expanded`: **72 pass**. `flutter build apk --debug --no-pub`: thành công; đã cài bản mới lên FLM_API36. [Raw logs](../evidence/lab3/2026-10-29/README.md).
- Regression mới: search ở Roadmap chỉ gửi query_length/result_count khi submit, có kết quả và empty result; không gửi từ khóa. URL PDF yêu cầu consent, cancel không gọi SDK, link lỗi giữ PDF, dispose xóa link khỏi phiên; layout 360/412/1280 dp 1.3× đã kiểm.
- Google login/cancel thật; Remote Config đổi giá trị/PE hint không rebuild; reports offline hiện lỗi rồi retry thành công. Đây là Android walkthrough bằng ADB, không tự đổi nhãn thành ARTEMIS.
- ARTEMIS TC01: **2/5 attempts pass** tổng cộng; hai lỗi adapter ban đầu và một lỗi Gemini HTTP 429/timeout vẫn được giữ. Sau sửa adapter, run slots 1/2 pass, slot 3 fail do quota. TC02 và các cases còn lại chưa chạy ARTEMIS vì dừng `-x` ở TC01. [Bảng đầy đủ](../evidence/lab3/2026-10-29/artemis-results.md). Chưa đạt ≥10 cases ×3 hoặc exploratory Pro.
- Firestore rules production đã đọc lại và khớp source cho đúng named database `flm-app`; RC restored `3/true`. Storage deploy fail do chưa thiết lập và yêu cầu billing Blaze, chưa phải production pass.

Các số liệu cũ bên dưới là lịch sử, không đại diện source hiện tại.

## Feedback UI/UX — 27/10/2026

- `flutter analyze`: No issues found.
- Backend grade-import unittest: 5/5 pass (mock, không có live OCR/Groq call).
- `flutter test --exclude-tags live`: 50 pass, gồm counts không trùng, nợ môn đã trả, thiếu tín chỉ OCR, flow tiên quyết 360/412 dp và journey/empty/confirm + Home text scale 1.3.
- `flutter build apk --debug`: thành công từ source cuối, Gradle 13,5 giây; cảnh báo tương thích KGP/SDK không làm build fail.
- Ảnh fixture bằng renderer Flutter thật: `evidence/ux/2026-10-27/`; ảnh canvas Figma thật: `design/evidence/2026-10-27/`. [Phạm vi và cách tái hiện](ux-feedback-validation.md).
- Chưa có user test/ARTEMIS hoặc live Google/Firestore mới; không đổi trạng thái các gap cũ thành pass.

Các mục tiếp theo giữ lại lịch sử kiểm tra trước lượt này.

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
