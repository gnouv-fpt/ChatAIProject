# Tổng kết chỉnh sửa UI/UX — 30/10/2026

Phạm vi: hai lượt chỉnh sửa trên nhánh local `codex/ui-review-fixes`, bắt đầu từ `lab3/vuong-ui-review`. Đây là rà soát nội bộ bằng code, ảnh giao diện và kiểm tra tự động; chưa phải nghiệm thu với người dùng thật.

## Đã sửa

| Khu vực | Thay đổi và tác dụng |
|---|---|
| Trang chủ mobile | Thu gọn phần chào, ưu tiên tiến độ và hành động tiếp theo; đưa nút mở lộ trình lên trước phần chi tiết; bỏ thẻ hành động và số liệu lặp, thêm khoảng cách giữa các nhóm. |
| Bảng điểm | Một nút **Lưu bảng điểm** chính ở cuối màn hình, có trạng thái đang lưu; nút thêm là hành động phụ. Cảnh báo, thống kê và danh sách cuộn chung để vẫn xem/sửa được môn khi màn hình thấp hoặc tăng cỡ chữ. |
| Chương trình học | Rút gọn tên tab, bổ sung tên chương trình, thu gọn bộ lọc; mở sẵn học kỳ đầu. Ô tìm kiếm cao tối thiểu 48, chữ rõ hơn, có nhãn nút xóa; khôi phục mũi tên mở/đóng học kỳ; chừa chỗ cho nút AI ở cuối danh sách. |
| Cài đặt | Làm rõ thang GPA `/ 10`, thêm đường dẫn xem chương trình đang chọn. |
| Dashboard web | Dùng hệ thống giao diện chung, bỏ Tailwind CDN riêng; sắp xếp lại tiêu đề, hành động chính, thống kê, môn gần đây và trạng thái chưa có dữ liệu. |
| Chat web | Bổ sung **Trò chuyện mới / Lịch sử** khi thanh bên bị ẩn; vùng chạm tối thiểu 44 px. Bộ chọn môn co giãn và xuống dòng, có nhãn truy cập; dùng chiều cao viewport động. Việt hóa “đã index” và nhãn nguồn trích dẫn. |
| Tài liệu web | Chuyển bảng thành thẻ trên mobile/tablet, có nhãn từng thông tin; sửa chiều rộng thẻ cộng lề gây tràn, cho tên file dài xuống dòng và nút thao tác tự xuống hàng. |

Các thay đổi giao diện nằm trong Flutter và Presentation; không chuyển nghiệp vụ vào PageModel hay đổi hướng phụ thuộc các tầng.

## Kiểm chứng

- 18 bài kiểm tra Flutter liên quan đều đạt sau sửa: trang chủ, xác nhận bảng điểm, đăng nhập/cài đặt, chương trình học và mở tư vấn.
- Có trường hợp 360/412/1280 dp, chữ 1,3×; bổ sung trường hợp bảng điểm 360×640, chữ 2×, cảnh báo dài, cuộn và mở sửa môn được, nút lưu vẫn chạm được.
- `dart analyze lib`: không có vấn đề. Build ASP.NET Core: 0 lỗi, 0 cảnh báo.
- Kiểm tra bố cục web bằng Chrome headless với CSS thật và nội dung mẫu có tên môn/tài liệu dài: header chat, bộ chọn môn và bảng tài liệu không tràn ngang ở 360/412/768/1280 px. Đây là kiểm tra bố cục độc lập, chưa phải luồng web đăng nhập với dữ liệu thật.
- Ảnh chụp từ Flutter widget với dữ liệu kiểm thử: [Trang chủ](../evidence/ux/2026-10-30/home-360.png), [Bảng điểm](../evidence/ux/2026-10-30/transcript-360.png), [Chương trình học](../evidence/ux/2026-10-30/curriculum-412.png). Số liệu và chương trình TEST trong ảnh là fixture.

## Còn giới hạn

- Figma chưa đồng bộ vì phiên truy cập chỉ cho xem, chưa có quyền chỉnh sửa.
- Chưa kiểm tra OCR, Firebase, AI và cơ sở dữ liệu thật trong lượt này; chưa build APK mới.
- Thay đổi đang ở nhánh local, chưa push/merge lên GitHub.
