# Lab 3 test plan — chưa chạy ARTEMIS

Tài khoản Google kiểm thử riêng; Android thật/emulator có ADB; artifact mỗi lượt gồm commit/build, device, ARTEMIS pinned commit, instruction, trace ID, ảnh/replay, observed values và assertion. Không dùng tài khoản cá nhân trong suite.

Mỗi case dưới chạy độc lập ít nhất 3 lần bằng ARTEMIS Flash. Chưa có pass rate cho tới khi có trace thật. Test unit/widget hiện có không được đổi nhãn thành ARTEMIS.

| ID | Flow / precondition | Instruction và expected result | Loại | Runs |
|---|---|---|---|---|
| TC01 | Signed out | Mở app, chọn Google test account; Home hiện; report UID/session và nhãn tab | Native/auth | Chưa chạy |
| TC02 | Signed out | Bấm login rồi hủy account picker; ở login, có thông báo hủy | Native/error | Chưa chạy |
| TC03 | F01, signed in, có điểm test cố định | Đặt mục tiêu/kỳ, vào Bảng điểm xác nhận, Home→Kỳ tới→chi tiết; report GPA, mã môn, điều kiện | E2E | Chưa chạy |
| TC04 | F01, không có điểm | Mở Kỳ tới; không khẳng định đủ tiên quyết; có đường nhập điểm | Alternate | Chưa chạy |
| TC05 | F02, có profile | Mở môn từ chương trình; xem CLO/điều kiện/đánh giá; hỏi chiến lược; report mã môn, mục tiêu và nguồn hiển thị | E2E | Chưa chạy |
| TC06 | F03, OCR API lỗi | Nhập ảnh→lỗi→nhập tay→sửa→lưu; report mã, điểm, kỳ và GPA; mở lại vẫn đúng | Recovery | Chưa chạy |
| TC07 | Có lịch sử chat | Tạo phiên mới rồi mở phiên cũ; report scope/mã môn và nội dung phân biệt | E2E | Chưa chạy |
| TC08 | Signed in | Lần lượt mở 5 tab và S08; mở detail và Back; report title từng màn | Navigation | Chưa chạy |
| TC09 | Có dữ liệu để tìm | Tìm mã môn đã khóa ở fixture; report count và mã; tìm chuỗi không tồn tại có empty state | Search | Chưa chạy |
| TC10 | Có bảng điểm | Xuất báo cáo; kiểm nội dung đúng dữ liệu; upload; report progress kết thúc, per-UID path và URL | Export/upload | Chưa chạy |
| TC11 | Signed in, có Remote Config | Report 2 giá trị; cập nhật console, refresh; report hành vi đổi không cài build mới | Config | Chưa chạy |
| TC12 | Signed in A | Logout, login B; report không thấy điểm/profile/chat A; logout B không quay lại màn riêng bằng Back | Security | Chưa chạy |
| TC13 | Notification permission chưa chọn | Xin quyền; gửi FCM foreground/background/terminated; mở notification shade, tap; report inbox và màn đích | Native/FCM | Chưa chạy |
| TC14 | Analytics debug bật | Thực hiện mở chi tiết; đối chiếu event view_course/course_code trong Logcat hoặc DebugView | Instrumentation | Chưa chạy |
| TC15 | Network off | Mở thao tác API/cloud; report lỗi có retry; bật mạng rồi retry kết quả đúng, không spinner vô hạn | Recovery | Chưa chạy |

## Exploratory
Một phiên ARTEMIS Pro 15–30 phút, unscripted. Lưu replay và issues có màn, bước tái hiện, observed/expected, severity. Chưa chạy.

## Kết quả và flaky
Mỗi case: run 1/2/3, pass rate, thời gian trung bình, trace link, giá trị mong đợi/quan sát. Không chỉ assert SUCCESS. Case không 3/3 phải xác định app/timing/instruction và gắn fix. Không dùng thứ tự case làm precondition.

## Xác minh developer
Đã có unit/widget cho namespace UID, logout stale writes, failed logout retry, legacy isolation và login cancellation ở 360/412 dp. Các kết quả này chỉ là kiểm thử development, không chứng minh Google picker hay Firebase cloud hoạt động.
