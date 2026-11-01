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

## Cấu hình Backend URL & Hướng dẫn Build Release

### 1. Thứ tự ưu tiên cấu hình URL Backend:
- **Bản Release (`kReleaseMode`)**: LUÔN bắt buộc sử dụng biến môi trường compile-time `--dart-define=FLM_API_BASE_URL=https://...`. Ứng dụng sẽ ném ngoại lệ cấu hình rõ ràng (`StateError`) nếu thiếu cờ này và tuyệt đối **KHÔNG** fallback về `localhost` hay `10.0.2.2`. Mọi URL lưu cục bộ trước đó trên thiết bị (vd `localhost:8000`) sẽ bị bỏ qua và dọn dẹp tự động.
- **Bản Debug / Profile**: Nếu có `--dart-define=FLM_API_BASE_URL` sẽ ưu tiên sử dụng; nếu không có, cho phép ghi đè từ cài đặt cục bộ đã lưu trên máy (`flm_custom_base_url`); nếu chưa cấu hình thì fallback về `http://10.0.2.2:8000` (Android emulator) hoặc `http://localhost:8000` (Web/Desktop/iOS simulator).

### 2. Lệnh Build Release:
```powershell
# Build Android APK Release
flutter build apk --release --dart-define=FLM_API_BASE_URL=https://api.yourdomain.com

# Build Android App Bundle Release
flutter build appbundle --release --dart-define=FLM_API_BASE_URL=https://api.yourdomain.com

# Build Web Release
flutter build web --release --dart-define=FLM_API_BASE_URL=https://api.yourdomain.com

# Build Windows Desktop Release
flutter build windows --release --dart-define=FLM_API_BASE_URL=https://api.yourdomain.com
```

### 3. Chế độ Nhà phát triển (Developer Mode):
- Trong bản **Release**, phần "Cấu hình máy chủ nâng cao" trong màn hình Cài đặt mặc định được **ẩn hoàn toàn** để bảo mật và chống nhập sai URL backend.
- Để kích hoạt/mở khóa ô nhập URL tùy chỉnh trong Release: chạm liên tục **7 lần** vào dòng phiên bản ở cuối màn hình Cài đặt ("Cố vấn học tập FLM · v1.0.0 (Build 2026)"). Khi mở khóa, ô nhập cấu hình máy chủ sẽ hiển thị kèm thông báo SnackBar xác nhận. Chạm tiếp 7 lần để khóa/ẩn lại.

### 4. Kiểm tra Build Web & Android Release (Có và Không có `--dart-define`):
Ứng dụng được thiết kế để bắt lỗi cấu hình ngay lúc khởi động (`validateReleaseConfig` trong `lib/main.dart`):
- **Trường hợp thiếu `--dart-define`**: Ứng dụng không bao giờ bị màn hình trắng/xám hoặc crash âm thầm; thay vào đó sẽ hiển thị màn hình thông báo trực quan [`ConfigErrorScreen`](lib/widgets/config_error_screen.dart) hướng dẫn cờ cần thiết.
- **Trường hợp có `--dart-define`**: Ứng dụng khởi động bình thường vào production.

Chạy script kiểm tra tự động cả 2 kịch bản:
```powershell
.\scripts\check_release_build.ps1
```

## Bộ Test Kiểm thử QA (Phase 4 QA Test Suite)

Chạy toàn bộ 49 automated test cases chuyên biệt cho QA cuối cùng (Trợ năng, Responsive, Flow người dùng, Đồng bộ dữ liệu):

```powershell
flutter test test/qa_accessibility_test.dart test/qa_responsive_test.dart test/qa_flows_test.dart test/phase3f_verification_test.dart
```

Kiểm tra phân tích mã tĩnh:
```powershell
flutter analyze lib/ test/qa_accessibility_test.dart test/qa_responsive_test.dart test/qa_flows_test.dart test/phase3f_verification_test.dart
```

## Kiểm tra tổng thể

```powershell
flutter test
flutter analyze
flutter build apk --debug
```

Để demo OCR thật, dùng ảnh bảng điểm có quyền sử dụng và kiểm tra chọn ảnh → xác nhận/sửa → lưu → khởi động lại app → xóa. Kết quả mô hình phụ thuộc backend và cấu hình Ollama/API trên máy demo.
