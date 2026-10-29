# Lab 3 — kiểm tra tiếp ngày 29/10/2026

Trạng thái đang nghiệm thu, chưa phải tuyên bố Lab 3 hoàn tất. Nhánh local `PRM-Lab3-integration`, HEAD `493942c`, có sẵn nhiều thay đổi chưa commit trước phiên này. Không push, tạo PR hoặc merge remote trong phiên.

## Đã làm trong phiên

- Áp dụng keystore nhóm từ `prm-bao-dev`; `signingReport` thành công, SHA-1 `14:E0:41:99:B0:C4:39:99:C6:35:CD:A8:F5:B3:68:B0:8C:AB:E5:EA`. Keystore/key.properties được ignore.
- Build APK mới thành công; cài lên FLM_API36 (`emulator-5554`, Android API 36). Bản cũ khác chữ ký đã được gỡ sau khi user xác nhận. Google account của máy được giữ nguyên.
- Mở native Google picker thật, hủy bằng Back thấy `Bạn đã hủy đăng nhập.`. Sau đó chọn test account: vào được Home, dữ liệu Firestore của tài khoản được tải lại sau cài mới. Không thay dữ liệu đang có; chưa chứng minh isolation A→B hoặc persistence đa thiết bị.
- PDF có thao tác tạo URL tải theo yêu cầu đề; chỉ thực hiện sau xác nhận vì bearer URL cho phép bất kỳ ai giữ link đọc file. Không tự tạo URL khi upload, không lưu URL vào metadata/telemetry; dispose xóa URL khỏi provider.
- Di chuyển crash SDK call khỏi UI sang telemetry service inject. Thêm Semantics cho progress; Remote Config debug bỏ chờ 5 phút để nghiệm thu live.
- ARTEMIS official checkout/client tại commit `351ca8422f7b5b54e80a9c1ce03a222e02415b6b`; suite 15 cases ×3 = 45 lượt được pytest collect. Harness checks kiểm malformed/missing/wrong/type-mismatched observations và session/screenshot boundary. Đây không phải 45 lượt E2E pass.

## Kiểm chứng developer

- `flutter analyze --no-pub`: sạch trước thay đổi RC interval cuối; cần kiểm cuối khi chốt build.
- Full unit/widget suite: **71 pass**, loại live backend tests; [raw log](../evidence/lab3/2026-10-29/flutter-tests.log).
- Widget tests URL consent/cancel/reveal và error/retry: 360/412/1280 dp, text scale 1.3×; đã xem ảnh 360 dp. Ảnh dùng fixture `TEST` và `example.invalid`, không phải upload production.
- `flutter build apk --debug --no-pub`: thành công, APK cài được. APK hash của đợt auth/ARTEMIS hiện tại: `267bd19ad2ae7425be0da0fd9b15b5f106ef99af314ae371bc1f1c43c007de03`. Chưa chứa thay đổi RC interval cuối; chốt build mới sau suite.

## ARTEMIS: kết quả đang chạy

Daemon local `127.0.0.1:8769`, Gemini key đọc từ cấu hình backend có sẵn mà không in/chép khóa vào evidence. Model-list và generation probe thành công. Runtime model config dùng `gemini-2.5-flash`, fallback cùng model; detector `gemini-robotics-er-2-preview` được model-list xác nhận. Dependencies chỉ cài trong `.venv` của task; không chạy installer hoặc thay global agent/MCP rules.

Hai lượt TC01 đầu bị runner đánh fail: session API trả `completed` nhưng không trả `output`; adapter ban đầu tìm Outputter cũng không có dữ liệu. Đã inspect source và trace, xác định giá trị JSON thực nằm trong `report_task_status.args.explanation` của terminal step. Adapter mới đọc đúng session qua API `/steps`, yêu cầu terminal report completed + screenshot rồi vẫn assert chính xác JSON values/types. Không đổi hai lượt lỗi thành pass, không dùng status thay observations.

Raw traces/screenshots/JSON có thể chứa account picker/dữ liệu test: giữ tại `tmp/lab3-validation` và `e2e_test/.local-evidence` (local, chưa dùng làm public evidence). Thiếu `scrcpy` nên chưa có video recording; step screenshots vẫn được giữ. Cần hoàn tất chạy và kiểm trace trước khi cập nhật pass rate.

## Còn mở

| Hạng mục | Trạng thái / dependency |
|---|---|
| Firestore activity rules, Storage rules, Remote Config | File local sẵn; đang chờ user cho phép deploy đúng project/target. Đã đọc RC production: 0 parameters/0 conditions tại thời điểm kiểm. |
| Storage production | Chưa xác minh bucket/plan; chưa upload/download thật. Không bật billing/terms tự động. |
| FCM | Chưa gửi/nhận đủ foreground/background/terminated và tap routing thật. |
| Analytics / Crashlytics | Chưa có DebugView cho ≥7 events hoặc Console non-fatal/test crash có keys. |
| Auth A→B | User xác nhận có một test account; chưa xác nhận tài khoản thứ hai. |
| ARTEMIS toàn suite | Đang chạy auth subset; các feature cases cần fixture độc lập, backend và cloud services thật. Còn exploratory Pro 15–30 phút. |
| Figma | Cloud sync + Present walkthrough 3 flow và deviations chưa nghiệm thu. |
| AI review | Có local findings/fix history; output review PR và commit-ID requirement cần khép. Chưa có phép tạo/sửa remote PR. |
| Bộ nộp | Report PDF 8–12 trang, slides PDF 12–15, video 5–10 phút chưa chốt vì evidence trên còn mở. Không đưa mock/fixture thành live evidence. |

Không đưa web admin/cross-role/Gemini AI Logic của Final vào phạm vi Lab 3.
