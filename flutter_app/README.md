# Cố vấn học tập FLM — Flutter

Ứng dụng không có màn đăng nhập. `lib/main.dart` khởi tạo `CourseCatalog`, `ChatProvider` và `TranscriptProvider`, sau đó mở `AppShell` với năm tab: Trang chủ, Lộ trình, Trợ lý, Bảng điểm và Cài đặt.

## Chạy ứng dụng

```powershell
cd flutter_app
flutter pub get
flutter run
```

Khởi động FastAPI từ thư mục repository bằng `python run_backend.py`. Trên Android emulator, app mặc định gọi `http://10.0.2.2:8000`; trên desktop/web dùng `http://localhost:8000`. Có thể đổi URL ở Cài đặt hoặc truyền `--dart-define=FLM_API_BASE_URL=http://HOST:8000` khi chạy. Danh sách môn, chi tiết và Graph đọc asset cục bộ nên vẫn mở được nếu API AI mất kết nối.

Trước khi demo AI/OCR, chạy `ollama list` và bảo đảm thư mục `OLLAMA_MODELS` chứa đúng text model và vision model khai báo trong `.env`. Endpoint health chỉ xác nhận backend và dữ liệu FLM đã nạp, chưa xác nhận model sinh câu trả lời hoạt động.

## Luồng chức năng

| Luồng | Code chính |
| --- | --- |
| Tổng quan và điều hướng | `lib/app/app_shell.dart`, `lib/screens/home_screen.dart` |
| Lộ trình, tìm kiếm, lọc học kỳ, Map và môn học | `lib/screens/roadmap_screen.dart`, `lib/features/graph/views/graph_view_screen.dart`, `lib/pages/course_detail_page.dart` |
| Chat theo curriculum/môn, gửi ảnh, trạng thái lỗi, thử lại và lịch sử cục bộ theo phạm vi | `lib/features/chat/views/chat_screen.dart`, `lib/features/chat/views/widgets/contextual_chat_panel.dart`, `lib/features/chat/providers/chat_provider.dart` |
| OCR bảng điểm, xác nhận, sửa/nhập tay, GPA, lưu trên thiết bị | `lib/screens/transcript_screen.dart`, `lib/screens/transcript_confirm_screen.dart`, `lib/state/transcript_provider.dart`, `lib/services/grade_calculator.dart` |
| Mục tiêu GPA, API và xóa bảng điểm | `lib/screens/settings_screen.dart` |

Import ảnh đi qua `/api/v1/import-grade`. Backend dùng Vision trước cho mọi ảnh, sau đó mới dùng OCR/text nếu Vision không đọc được dòng nào. Người dùng phải xác nhận, sửa mã môn/điểm/học kỳ trước khi lưu. Mã môn phải có trong dữ liệu curriculum; tín chỉ lấy từ dữ liệu đó. Lần import tiếp theo giữ các môn đã lưu và thay dòng trùng mã môn cùng học kỳ. Ảnh không được lưu vào bảng điểm.

`grading_rules.yaml` ở root là nguồn quy chế cần sửa. Flutter cần bản sao đóng gói trong `assets/`; sau khi đổi quy chế, chạy `python scripts/sync_grading_rules.py` ở root. `python scripts/sync_grading_rules.py --check` và `flutter test` sẽ phát hiện bản sao cũ.

## Kiểm tra

```powershell
flutter test
flutter analyze
flutter build apk --debug
```

Để demo OCR thật, dùng ảnh bảng điểm có quyền sử dụng và kiểm tra chọn ảnh → xác nhận/sửa → lưu → khởi động lại app → xóa. Kết quả mô hình phụ thuộc backend và cấu hình Ollama/API trên máy demo.
