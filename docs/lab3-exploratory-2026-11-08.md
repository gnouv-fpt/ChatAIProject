# Lab 3 manual exploratory log — 08/11/2026

Phân loại: manual Android exploratory, **không phải ARTEMIS run**.

- Thiết bị: `Codex_Lab3_API36`, Android 16/API 36, emulator `emulator-5554`.
- App: `com.example.flm_courses` 1.0.0, debug build.
- Thời gian: 13:21:19–13:37:06 Asia/Bangkok, 15 phút 47 giây.
- Session: Google đã đăng nhập từ trước; không ghi email, token hoặc UID vào log.

## Charter

Khám phá điều hướng chính, dữ liệu chương trình, trạng thái tải/lỗi và khả năng
quay lại mà không thay đổi dữ liệu học tập hoặc tạo cloud write.

## Phạm vi đã đi qua

| Khu vực | Thao tác | Quan sát |
|---|---|---|
| Home | Mở từ session đã đăng nhập | Hiển thị mục tiêu, môn ưu tiên và bottom navigation |
| Lộ trình | Chuyển tab, xem danh sách học kỳ, thử ô tìm kiếm | Progress và danh sách course render; không crash |
| Chi tiết CSD201 | Mở môn; chuyển Chuẩn đầu ra/Tiên quyết/Đánh giá; Back | Ba tab hoạt động; Back về Home đúng |
| Trợ lý | Mở màn và quan sát trạng thái kiểm tra kết nối/retry | UI recovery hiện diện; không gửi câu hỏi thật |
| Bảng điểm | Mở danh sách và cuộn | GPA/list render; không sửa hoặc lưu điểm |
| Cài đặt | Mở để kiểm layout rồi loại ảnh có email khỏi evidence | Không thay đổi profile/GPA target |
| Resume | Đưa app về foreground sau khi rời app ngoài ý muốn | App resume về state Lộ trình, không crash |

## Sự cố/ghi chú

- Một tọa độ tap nhầm mở Google Calendar. Đã thoát khỏi form tạo event mà không
  bấm Save; không có lịch mới. Hai screenshot Calendar không liên quan đã xóa.
- Ảnh Settings chứa email đã xóa. Ảnh DebugView gốc có UID rút gọn cũng đã xóa;
  chỉ giữ bản đã cắt vùng user properties.
- Không thấy crash, layout overflow hoặc mất state học tập trong session.
- Trợ lý vẫn phụ thuộc backend; session này chỉ kiểm UI/retry, không chứng minh
  câu trả lời AI live.

## Evidence giữ lại

Các ảnh trong `evidence/lab3/2026-11-08/` gồm Home, Lộ trình, chi tiết môn,
Trợ lý, Bảng điểm, start/end và DebugView đã che định danh.

## Kết luận

Manual exploratory tối thiểu 15 phút theo guide đã thực hiện và ghi log. Yêu cầu
ARTEMIS 10 case × 3 run vẫn mở vì repository không có runner/credential thật;
không dùng session này thay thế 30 ARTEMIS runs.
