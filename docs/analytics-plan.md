# Analytics event plan — chưa có DebugView evidence

Không gửi tên, email, ảnh, điểm hoặc nội dung chat trong event. Sau sign in dùng Firebase UID làm user ID; sign out reset user ID. Event gọi qua service inject, không gọi SDK trong widget. Mỗi event bên dưới phải có DebugView trước khi đánh dấu hoàn thành.

| Event | Trigger / flow | Parameters (type) | Câu hỏi sản phẩm | Evidence |
|---|---|---|---|---|
| login | Google success | method:string | Người dùng có đăng nhập thành công? | Chưa chạy |
| logout | Sign out | — | Phiên kết thúc ở đâu? | Chưa chạy |
| search | Tìm môn ở S02/S08 | query_length:int, result_count:int | Có tìm được môn cần xem? | Chưa chạy |
| view_course | S03, F01/F02 | course_code:string, entry_point:string | Môn nào được mở từ lộ trình? | Chưa chạy |
| view_curriculum | S08 | curriculum_id:string | Chương trình nào được xem? | Chưa chạy |
| transcript_import | S05→S06, F03 | source:string, row_count:int | OCR hay nhập tay hữu ích hơn? | Chưa chạy |
| transcript_import_error | F03 recovery | error_code:string | Lỗi nào làm gián đoạn nhập điểm? | Chưa chạy |
| advising_request | F02, F03 | scope:string, has_profile:int | Người dùng đi đến bước tư vấn? | Chưa chạy |
| export_report | Tạo file | row_count:int, file_size_kb:int | Có xuất báo cáo từ dữ liệu đang xem? | Chưa chạy |
| upload_report | Upload thành công | file_size_kb:int | Bao nhiêu lượt export hoàn tất upload? | Chưa chạy |
| notification_open | Tap thông báo | destination:string | Thông báo dẫn tới hành động nào? | Chưa chạy |

Không log search term/chat tự do để tránh thông tin cá nhân. Log query_length thay thế và ghi rõ lựa chọn này. Không ghi success trước khi thao tác thật thành công.
