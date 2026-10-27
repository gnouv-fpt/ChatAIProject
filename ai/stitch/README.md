# Chuẩn bị bằng chứng Google Stitch

Ngày 21/10/2026, người dùng xác nhận chưa có project Stitch hoặc prompt/ảnh từ các vòng trước.

Sau đó người dùng cung cấp `PRM393 User Persona.pptx` gồm 4 persona. Draft ban đầu đã cập nhật: primary SE K19 ưu tiên desktop, vẫn có Android theo đề; nhánh chưa có bảng điểm; local-only cần chốt trước cloud; không dùng chung curriculum khác khóa. Chỉ đưa đặc điểm tác vụ cần thiết vào prompt, không gửi tên/địa điểm hoặc thông tin nhận diện persona.

Lần mở Stitch đang dừng tại dialog **Additional Terms of Service for Stitch**. Chưa bấm Continue, chưa chấp nhận điều khoản, chưa tạo project hay output. Có thử điền một bản brief vào textbox trước khi dialog xuất hiện, nhưng thao tác timeout vì trang chuyển hướng; chưa có bằng chứng điền/gửi thành công. Prompt trong file là draft hiện hành, không được ghi thành prompt đã gửi.

Các file prompt trong thư mục này là **bản chuẩn bị, chưa được đánh dấu đã gửi**. Chỉ đổi trạng thái sau khi quan sát thấy prompt đã gửi và output tương ứng trên Google Stitch. Không tính các lần sửa Figma bằng MCP thành vòng lặp Stitch.

| Mục | File | Trạng thái |
|---|---|---|
| Prompt ban đầu | `00-initial-prompt.txt` | Soạn xong; chưa gửi |
| Vòng 1: hierarchy và navigation | `01-iteration-navigation-draft.txt` | Dự kiến; phải sửa theo vấn đề quan sát trên output thật |
| Vòng 2: accessibility | `02-iteration-accessibility-draft.txt` | Dự kiến; chưa gửi/chưa đo |
| Vòng 3: recovery | `03-iteration-recovery-draft.txt` | Dự kiến; chưa gửi/chưa chạy |

Mỗi vòng thực tế cần: timestamp, URL project, prompt nguyên văn, ảnh before/after thật, >=1 phát hiện có màn hình cụ thể, quyết định accept/modify/reject và thay đổi tương ứng trong Figma. Toàn bộ các vòng cần có ít nhất 5 phát hiện UX theo rubric. Nếu output ban đầu không có vấn đề dự kiến, đổi prompt vòng đó theo vấn đề thực tế, không dựng trước kết luận.
