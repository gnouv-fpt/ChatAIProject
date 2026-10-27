# UI feedback evidence — 27/10/2026

PNG được export từ widget Flutter thật bằng `feedback_ui_test.dart`, viewport 360×844 và 412×844, font Roboto/MaterialIcons từ SDK. Catalog là asset hiện có; ba transcript rows là fixture synthetic (một đạt, một đang học, một chưa đạt), không phải dữ liệu sinh viên thật. Home empty dùng transcript rỗng. Không phải screenshot cloud login, thiết bị Android, ARTEMIS hoặc kết quả user research.

Tái hiện trong `flutter_app/`: `flutter test test/feedback_ui_test.dart --dart-define=UX_EVIDENCE=true`. Lệnh ghi đè sáu ảnh fixture hiện có. Test thường không ghi ảnh. Assertions kiểm counts, đường empty, lỗi layout và Home text scale 1.3. Ảnh là evidence có người review, không phải golden baseline tự so pixel.

Đã xem đủ sáu ảnh: Home có điểm, Home chưa có điểm và Confirmation ở cả 360/412 dp. Không có chữ/controls chồng nhau trong vùng chụp; các phần ngoài viewport cần cuộn kiểm riêng.
