# Figma → Flutter — 29/10/2026

Ảnh là widget Flutter render với font Roboto và fixture TEST, không phải ảnh tài khoản hoặc dịch vụ cloud thật. Chữ 1.3×, viewport 360/412/1280 ×900 dp. Đã xem ảnh AUTH, Settings và S08 mobile/desktop; sửa tab bị cắt, filter tràn và khoảng cách form từ kết quả render.

## Thay đổi

- AUTH: căn trái nội dung, typography theo tokens, bỏ icon trang trí không có trong frame, Google action rộng hết khối nội dung. Giữ busy/cancel/error thật.
- S07: card tài khoản/đăng xuất, mục tiêu GPA và hồ sơ; khoảng cách form; CTA `Xem chương trình` theo ID catalog, Back trở lại Settings. Nhãn xóa dữ liệu phân biệt local/cloud.
- S08: header Chương trình học, ID/tên/thống kê lấy catalog trong body; tabs dạng nút tự xuống dòng, breadcrumb desktop; search 48 dp và filters co giãn. Giữ ba tab và tư vấn mobile/desktop.
- Home/S06: các hành vi cập nhật trong Figma đã có ở baseline code; không thay form thành dữ liệu prototype cố định.

## Kiểm chứng

- `flutter analyze`: pass, `flutter-analyze.log`.
- `flutter test test/figma_sync_test.dart test/curriculum_ux_test.dart test/auth_gate_test.dart test/settings_sign_out_test.dart --concurrency=1 --reporter expanded --dart-define=FIGMA_SYNC_EVIDENCE=true`: **15 pass**, `flutter-targeted-tests.log`.
- Tests dùng Auth/OCR/network fakes. Kiểm hủy login, logout khi profile loading/error, Settings → S08 → Back, đủ ba lựa chọn tab nhìn thấy, error recovery, trạng thái/filter môn, nhập tay sau lỗi OCR, advisor và layout chữ lớn.
- 9 PNG: `auth-*`, `settings-*`, `curriculum-*`.
- `git diff --check`: pass.

## Lượt thất bại và giới hạn

- Lượt đầu của test mới thất bại do finder Scrollable không duy nhất; đã chọn đúng ListView.
- Regression phát hiện dropdown overflow 5.3 px sau khi đổi padding; sửa co giãn + typography rồi chạy lại pass.
- `flutter-tests.log` chỉ là log **full-suite chưa hoàn tất**, đã hủy; không dùng làm bằng chứng pass. Các lần tiếp theo báo ổ C đầy khi copy dill và Dart out-of-memory.
- Chuyển TEMP/TMP sang thư mục task trên E cho lần chạy tuần tự (chỉ môi trường process); không thay cấu hình máy. Lượt 15 tests nêu trên thành công.
- Lệnh dọn `tmp/flutter-temp` bị policy của công cụ chặn; giữ nguyên thư mục tạm, không đưa vào commit.
- `flutter build apk --debug`: **failed**. Gradle daemon PID 19224 biến mất, JVM crash log `flutter_app/android/hs_err_pid19224.log`; chưa có APK mới được xác minh. Không kết luận build error do source. Máy lúc kiểm ổ C chỉ còn khoảng 205 MiB; Dart đã báo thiếu bộ nhớ, Gradle hiện cấu hình heap 8 GiB. Không tự dọn cache máy hay đóng ứng dụng của người dùng.
- Figma vẫn báo lưu local, chưa xác nhận sync cloud. Chưa Present walkthrough, user test, ARTEMIS hoặc live Firebase.

Source thay đổi chưa commit/push trên `PRM-Lab3-integration` tại `493942c` (ahead origin 6 theo refs local). Giữ nguyên các tài liệu/evidence có sẵn trước lượt này.
