# Kịch bản quay nộp PRM393 Lab 3

Mục tiêu: video 7-9 phút. Chỉ quay evidence thực có trên máy/Console. Không dùng ảnh minh họa thay cho kết quả Firebase Console hay thiết bị.

## Chuẩn bị trước khi quay

- Cài `flutter_app/build/app/outputs/flutter-apk/app-debug.apk` trên Android 13+.
- Chuẩn bị một tài khoản Google test riêng và bật USB debugging nếu quay thiết bị vật lý.
- Mở Firebase Console đúng project `flm-prm323-20261021`; đăng nhập sẵn nhưng không hiển thị token, email riêng hoặc project không thuộc bài.
- Chuẩn bị log lệnh: Flutter test, Firebase emulator rules test, ARTEMIS run log.
- Dùng profile test không chứa điểm hoặc ảnh bảng điểm thật.

## Timeline quay

| Phút | Cảnh quay | Lời dẫn và bằng chứng cần thấy |
|---|---|---|
| 0:00-0:35 | Mở slide tiêu đề và repo | Nêu tên app, mục tiêu Lab 3, phạm vi Firebase. Hiển thị commit và report local. |
| 0:35-1:35 | Authentication | Signed-out gate, Google sign-in, hủy sign-in, signed-in home, logout. Sau đó mở Authentication Users Console đúng project. |
| 1:35-2:25 | Storage | Tạo report PDF từ dữ liệu test, upload, progress, URL. Mở Storage Console thấy object `reports/{uid}/...`. Nêu rule owner-only và thử account khác hoặc anonymous bị deny. |
| 2:25-3:20 | FCM | Gửi test message từ Console. Lần lượt quay foreground, background và terminated. Chạm notification và thấy route đích. Quay trạng thái từ chối quyền nếu có. |
| 3:20-4:05 | Analytics | Chạy các flow đã chọn. Mở DebugView và chỉ từng event, parameter không chứa PII. |
| 4:05-4:45 | Crashlytics | Tạo một nonfatal ở luồng demo và intentional crash tách biệt. Mở Crashlytics Console, chỉ user ID/key đã ẩn dữ liệu nhạy cảm. |
| 4:45-5:35 | Remote Config | Quay Home trước publish, đổi một parameter, publish, fetch/activate, quay Home sau đổi mà không build lại. Kiểm tra fallback khi tắt mạng. |
| 5:35-6:30 | ARTEMIS | Mở catalogue 10 ca, log 3 lần chạy/case và summary pass rate. Nêu exploratory session 15-30 phút, lỗi nếu có và cách ghi nhận. |
| 6:30-7:15 | AI code review | Mở `docs/code-review.md`, chỉ 6 findings, ít nhất 3 accept/fix và commit trace. Nêu review local, không gọi là PR review remote. |
| 7:15-8:00 | Regression và kết luận | Chạy/hiển thị `flutter analyze`, 238/238 tests, 14/14 rules. Nêu giới hạn còn lại nếu một evidence không được quay. |

## Danh sách cảnh bắt buộc theo rubric

- Authentication: before/after sign-in, cancel/error, logout, Console Users.
- Storage: progress, final URL, object Console, unauthorized deny, `storage.rules`.
- Messaging: permission, foreground/background/terminated, notification tap route, token/device note.
- Analytics: DebugView evidence của các event được trình diễn, parameter policy.
- Crashlytics: nonfatal, intentional crash, custom key và user identity.
- Remote Config: default, Console parameter, publish, before/after observable behavior, offline fallback.
- ARTEMIS: 10 test cases, 30 device runs, actual observation, exploratory note.
- Review: 5+ findings thuộc >=2 nhóm, 3+ accepted fixes, commit trace.

## Không được nói khi quay

- Không nói upload/notification/DebugView/Crashlytics đã thành công nếu chưa thấy trên thiết bị hay Console.
- Không dùng emulator rules pass để thay evidence Storage Console hoặc Firebase production.
- Không đọc hoặc hiển thị token FCM, API key, email cá nhân hay điểm thật.
