# Analytics event plan — DebugView evidence một phần

Không gửi tên, email, ảnh, điểm hoặc nội dung chat trong event. Sau sign in dùng Firebase UID làm user ID; sign out reset user ID. Event gọi qua service inject, không gọi SDK trong widget. Mỗi event bên dưới phải có DebugView trước khi đánh dấu hoàn thành.

## Trạng thái wiring 08/11/2026

Cả 11 event trong bảng đã có call site. Bổ sung ngày 08/11 gồm `search` khi
submit từ khóa, `view_course`/`view_curriculum` khi mở named route và
`transcript_import`/`transcript_import_error` cho OCR hoặc nhập tay. Search chỉ
gửi `query_length` và `result_count`, không gửi nội dung từ khóa.

APK debug đã bật Firebase Analytics debug mode. Ngày 08/11/2026, Firebase
DebugView nhận 8 event trong 30 phút: `login` (2), `screen_view` (2),
`view_course` (2), `session_start` (1) và `user_engagement` (1). Log SDK của
`view_course` xác nhận `course_code=CSD201`, `entry_point=named_route`, cờ
debug và HTTP 204. Ảnh Console đã cắt bỏ vùng user properties/UID trước khi lưu
tại `evidence/lab3/2026-11-08/firebase-debugview-redacted.png`.

| Event | Trigger / flow | Parameters (type) | Câu hỏi sản phẩm | Evidence |
|---|---|---|---|---|
| login | Google success | method:string | Người dùng có đăng nhập thành công? | DebugView: 2 event; chưa mở parameter detail |
| logout | Sign out | — | Phiên kết thúc ở đâu? | Chưa chạy |
| search | Tìm môn ở S02/S08 | query_length:int, result_count:int | Có tìm được môn cần xem? | Chưa chạy |
| view_course | S03, F01/F02 | course_code:string, entry_point:string | Môn nào được mở từ lộ trình? | DebugView: 2 event; Logcat xác nhận CSD201/named_route |
| view_curriculum | S08 | curriculum_id:string | Chương trình nào được xem? | Chưa chạy |
| transcript_import | S05→S06, F03 | source:string, row_count:int | OCR hay nhập tay hữu ích hơn? | Chưa chạy |
| transcript_import_error | F03 recovery | error_code:string | Lỗi nào làm gián đoạn nhập điểm? | Chưa chạy |
| advising_request | F02, F03 | scope:string, has_profile:int | Người dùng đi đến bước tư vấn? | Chưa chạy |
| export_report | Tạo file | row_count:int, file_size_kb:int | Có xuất báo cáo từ dữ liệu đang xem? | Chưa chạy |
| upload_report | Upload thành công | file_size_kb:int | Bao nhiêu lượt export hoàn tất upload? | Chưa chạy |
| notification_open | Tap thông báo | destination:string | Thông báo dẫn tới hành động nào? | Chưa chạy |

Không log search term/chat tự do để tránh thông tin cá nhân. Log query_length thay thế và ghi rõ lựa chọn này. Không ghi success trước khi thao tác thật thành công.
