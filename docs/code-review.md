# AI code review — Codex, 21/10/2026

Tool: Codex (đọc source và diff trực tiếp). Baseline `6e4640bfc8399e824064546149b9b3302c281d50`. Mục đích: rà bảo mật dữ liệu cá nhân, auth routing và MVVM. Đây là review local; chưa có PR review output từ dịch vụ độc lập, chưa đánh dấu toàn bộ yêu cầu review Lab 3 đã khép.

## Findings và quyết định
Đường dẫn/line bên dưới thuộc baseline nêu trên, trước khi sửa.

| ID | File:line | Kind | Finding | Decision / căn cứ | Fix |
|---|---|---|---|---|---|
| CR01 | flutter_app/lib/state/transcript_provider.dart:13 | Security | Cache dùng key toàn cục; không có ranh giới tài khoản cho điểm, profile và chat | Accept: Lab 3 auth/signout và Final dữ liệu cá nhân cần gắn UID | c5499d5; kiểm thử cách ly/late write trong account_isolation_test.dart |
| CR02 | flutter_app/lib/main.dart:19 | Security | main mở thẳng FlmApp/AppShell, không auth-state routing | Accept: Lab 3 mục 6 yêu cầu signed out→login, signed in→home | 8b29088; auth_gate_test.dart kiểm chưa login không có navigation bar |
| CR03 | flutter_app/lib/screens/transcript_screen.dart:59 | Architecture | Widget tự tạo GradeImportService; chọn ảnh, gọi API và gộp dữ liệu trong State | Accept: Lab 3 mục 5 yêu cầu service inject và business logic ngoài widget | 5c7d664; service/VM được đăng ký trong 8b29088, screen chuyển sang VM trong commit riêng này |
| CR04 | flutter_app/lib/screens/transcript_screen.dart:133 | Architecture | Sắp xếp dữ liệu bảng điểm trong build | Accept: đưa sortedEntries vào TranscriptProvider để UI chỉ render | c5499d5 thêm getter; 5c7d664 đổi screen sử dụng getter |
| CR05 | flutter_app/lib/state/transcript_provider.dart:122 | Error handling | Lỗi load chỉ debugPrint rồi đánh dấu loaded, UI có thể hiểu là chưa có dữ liệu | Accept: cần explicit load error và retry theo Lab 3 mục 5/6 | Còn mở, chưa ghi là đã sửa |

## Review khi triển khai
- Nguy cơ late request ghi lại cache sau logout: storage seal trước signout, serialize ghi, drain trước remove. Có regression test.
- Signout thất bại không được làm mất cache: mở lại store, giữ account, cho retry. Có regression test.
- OCR trả kết quả sau dispose không được mở màn xác nhận ở session khác: VM disposed guard và screen mounted check. Có regression test.

## Disclosure và giới hạn
Codex dùng cho phân tích đề, code, test, review và Markdown. Google/Firebase SDK được dùng thật trong production service; test doubles chỉ nằm trong unit/widget test. Chưa có Google native picker, Firestore, FCM, Analytics, Crashlytics hoặc Remote Config console evidence. Chưa có ARTEMIS runs. Ba commit là sửa local, chưa push.
