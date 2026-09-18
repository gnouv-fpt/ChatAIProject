# Flutter FLM — phần việc của Bảo

Ứng dụng Flutter độc lập với dự án ASP.NET trong thư mục cha. Có danh sách môn học theo học kỳ, thẻ môn học, trang chi tiết, Provider quản lý trạng thái và dữ liệu JSON đóng gói để dùng không cần mạng hay AI server.

```powershell
cd flutter_app
flutter pub get
flutter run
```

`assets/courses_data.json` hiện chứa **dữ liệu minh họa**, không phải dữ liệu FLM chính thức. Khi Khôi bàn giao, thay file đó theo cấu trúc:

```json
{
  "courses": [
    {
      "code": "MAMON",
      "name": "Tên môn học",
      "credits": 3,
      "semester": 1,
      "learningOutcomes": ["Mục tiêu 1"],
      "prerequisites": ["MAMONTRUOC"]
    }
  ]
}
```

`code`, `name`, `credits`, `semester` là bắt buộc. `learningOutcomes` và `prerequisites` có thể bỏ trống hoặc là mảng rỗng. Dữ liệu sai định dạng được báo lỗi trên màn hình cùng nút thử lại.

Điểm ghép cho nhóm: Phúc thay widget `_IntegrationPage` của tab Sơ đồ trong `lib/main.dart` bằng Graph View; Vương thay widget tương ứng của tab Trợ lý AI bằng Chat UI. Cả hai có thể mở chi tiết môn qua `Navigator.pushNamed(context, '/courses/MAMON')`. Danh sách và chi tiết chỉ đọc asset nên vẫn hoạt động khi API chat mất kết nối; việc bắt lỗi kết nối trong tab chat thuộc phần tích hợp của Vương.

Chạy kiểm tra bằng `flutter analyze` và `flutter test`.

Trên Windows nếu đường dẫn project có dấu (như `D:\kỳ 8`), lệnh build web mặc định có thể lỗi khi rút gọn font icon. Dùng `flutter build web --no-tree-shake-icons` trong trường hợp đó.
