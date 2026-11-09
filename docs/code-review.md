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
| CR05 | flutter_app/lib/state/transcript_provider.dart:122 | Error handling | Lỗi load chỉ debugPrint rồi đánh dấu loaded, UI có thể hiểu là chưa có dữ liệu | Accept: cần explicit load error và retry theo Lab 3 mục 5/6 | Đã triển khai LoadStatus/error/retry; regression test dữ liệu hỏng giữ nguyên source và retry. Fix commit: bf03501; toàn suite hiện tại 45/45 pass. |

## Review khi triển khai
- Nguy cơ late request ghi lại cache sau logout: storage seal trước signout, serialize ghi, drain trước remove. Có regression test.
- Signout thất bại không được làm mất cache: mở lại store, giữ account, cho retry. Có regression test.
- OCR trả kết quả sau dispose không được mở màn xác nhận ở session khác: VM disposed guard và screen mounted check. Có regression test.

## Disclosure và giới hạn
Codex dùng cho phân tích đề, code, test, review và Markdown. Google/Firebase SDK được dùng thật trong production service; test doubles chỉ nằm trong unit/widget test. Chưa có Google native picker, Firestore, FCM, Analytics, Crashlytics hoặc Remote Config console evidence. Chưa có ARTEMIS runs. Ba commit là sửa local, chưa push.

## Kiểm tra trước push 22/10/2026
CR06 (error handling): SettingsScreen che nút logout khi profile đang tải/lỗi. Đã sửa trong bf03501; hai regression tests tại settings_sign_out_test.dart pass. Code cloud/rules đã triển khai, rules emulator Enterprise 9/9 pass; Google production end-to-end vẫn mở. Các nhận xét chưa có Firebase phía trên mô tả thời điểm review 21/10, không phải trạng thái provisioning hiện tại.

## Review bổ sung cho tích hợp Lab 3 — 07/11/2026

Review local bằng Codex trên diff `PRM-dev`; không giả mạo output Copilot/CodeRabbit hay PR remote.

| ID | Nhóm | Phát hiện | Quyết định | Trạng thái |
|---|---|---|---|---|
| CR-L3-01 | Error handling | Telemetry có thể làm đăng xuất thất bại dù Auth đã sign out | Chấp nhận; telemetry phải best-effort | Đã cô lập lỗi callback trong `auth_view_model.dart` |
| CR-L3-02 | Reliability | Listener tiến độ upload không được hủy | Chấp nhận; tránh listener sống lâu | Đã hủy subscription trong `report_service.dart` |
| CR-L3-03 | Product/architecture | Remote Config chỉ ở màn demo, chưa đổi hành vi thật | Chấp nhận | Hai tham số hiện điều khiển Home |
| CR-L3-04 | Data consistency | Thông báo nền không lưu lịch sử | Chấp nhận, trong giới hạn nền tảng | Background handler lưu khi còn phiên |
| CR-L3-05 | Security | Rules thiếu ownership/schema/MIME/size rõ ràng | Chấp nhận | Đã harden và test bằng emulator |
| CR-L3-06 | Privacy | Analytics có nguy cơ nhận free text/PII | Điều chỉnh bằng allowlist | Service chỉ nhận event/parameter định trước |

Các fix chấp nhận sẽ nằm trong commit local sau khi kiểm tra đạt; không push khi chưa có ủy quyền.

## PR review cuối — 08/11/2026

- PR: https://github.com/gnouv-fpt/ChatAIProject/pull/5, `PRM-dev` → `main`.
- Trạng thái khi review: open, mergeable clean; không merge.
- PR chứa toàn bộ lịch sử nhánh (123 commit, 539 file), nên lượt này rà sâu commit
  Lab 3 mới nhất và các đường rủi ro Auth/Storage/Messaging/Analytics/Crashlytics/
  Remote Config. Đây không phải tuyên bố audit chi tiết mọi file lịch sử.

| ID | Nhóm | Phát hiện | Quyết định | Trạng thái |
|---|---|---|---|---|
| CR-L3-07 | Analytics correctness | `transcript_import` được gửi ngay sau OCR, trước khi người dùng xác nhận/lưu; hủy màn vẫn bị tính là thành công | Chấp nhận; chỉ log sau `provider.save` thành công | Đã chuyển event vào callback `onSaved` cho cả OCR và nhập tay |

Sau fix CR-L3-07, không còn finding blocking trong phạm vi Lab 3 đã review.
Các khoảng trống FCM ba trạng thái, nonfatal context, Remote Config before/after,
Storage production và ARTEMIS 30 runs là thiếu evidence/runtime, không được đổi
thành finding code đã khép.
