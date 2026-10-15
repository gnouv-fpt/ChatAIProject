# Quyết định thiết kế và kiểm tra còn mở

Đây là quyết định cho luồng FLM dựa trên source và góp ý giảng viên. Quyết định Figma cần được đối chiếu lại sau khi có file thực tế. Nhãn **Modify** nghĩa là đã điều chỉnh hướng thiết kế trong source; không phải “AI đề xuất rồi sinh viên chấp nhận”.

| ID | Quyết định | Lý do | Trạng thái |
| --- | --- | --- | --- |
| D01 | Danh sách theo kỳ là mặc định, sơ đồ là tab phụ | P01 cần nhận ra môn kỳ tới trước khi khám phá quan hệ phức tạp | Modify trong source |
| D02 | Dashboard đặt GPA, tín chỉ, số môn, kỳ và môn đang học trước các lối khám phá | H01: thấy vị trí sau 5 giây | Modify trong source; T01 chưa chạy |
| D03 | Trạng thái môn ghi “đủ theo bảng điểm”, “còn thiếu” hoặc “cần xác minh” bằng chữ | Tránh nhầm nhãn màu và tránh kết luận quá dữ liệu | Modify trong source |
| D04 | Chi tiết môn có ba tab CLO, điều kiện, đánh giá | Thông tin đúng tác vụ, bớt phải cuộn qua đề cương dài | Modify trong source |
| D05 | Hồ sơ có thể bổ sung dần, kỳ hiện tại tự xác nhận | Không bắt điền persona dài và không coi kỳ suy ra là kỳ thật | Modify trong source |
| D06 | Ảnh bảng điểm phải qua màn xác nhận/sửa; lỗi ảnh cho nhập tay | OCR có thể sai; F03 phải phục hồi được | Modify trong source; ảnh thật chưa thử |
| D07 | Tư vấn môn lấy fact từ FLM và mục tiêu tự khai, nêu giới hạn khi thiếu dữ liệu | Không bịa điểm, tiên quyết hoặc lịch mở lớp | Modify trong source; chất lượng với người dùng chưa thử |
| D08 | Lịch sử chat chia phiên, gắn nhóm câu hỏi tự động | Sinh viên cần tìm lại tư vấn cũ và so sánh sau khi cập nhật điểm | Modify trong source |
| D09 | 360/412 dp dùng điều hướng dưới; desktop dùng rail | Giữ đích điều hướng rõ và giảm độ sâu click trên web | Modify trong source; bố cục 360/412 cần QA trực quan |

## Accessibility và responsive — kết quả trung thực

| Mục yêu cầu | Trạng thái | Bằng chứng/công việc tiếp theo |
| --- | --- | --- |
| Chữ thường ≥4.5:1; chữ lớn và điều khiển ≥3:1 | **Chưa đo toàn bộ màn** | Đo từng cặp foreground/background trong Figma và snapshot app; sửa cặp không đạt. |
| Vùng chạm ≥48×48 dp | **Chưa đo toàn bộ controls** | Kiểm Button, chip, icon, tab, ListTile ở 360/412 dp. |
| Nội dung ≥14 sp | **Chưa đạt nhất quán** | Một số chú thích trong source còn 12–13 sp; cần nâng khi dựng Final UI và kiểm thử text scale. |
| Không chỉ dựa vào màu | **Có nhãn chữ ở trạng thái môn**, chưa kiểm mọi màn | Grayscale test từng frame. |
| Bố cục 360 và 412 dp | **Widget flow test đạt ở cả hai rộng** | Chưa thay cho chụp/kiểm ảnh trực quan và text scale trên thiết bị. |
| Từ 600 dp | **Đã đặc tả** | Xem handoff; cần xác nhận Figma design và web thực tế. |

Chưa tự chấm ≥80/100 khi chưa có bản Figma, kiểm tương phản và buổi thử người dùng. [UI Checklist](https://prm393-material.web.app/ui-checklist.html) là công cụ tự kiểm, không phải điểm Lab 2 chính thức.
