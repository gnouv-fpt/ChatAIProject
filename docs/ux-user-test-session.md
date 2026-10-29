# Phiếu chạy user tasks T1–T6

Trạng thái: **chưa có phiên người dùng thực tế**. Đây là hướng dẫn và phiếu ghi nhận, không phải kết quả nghiên cứu. Tiêu chí gốc: [ux-feedback-validation.md](ux-feedback-validation.md).

## Chuẩn bị

- Ghi commit/build, thiết bị, viewport và text scale trước mỗi phiên.
- Người tham gia tự nguyện; dùng mã P01/P02…, không đưa tên, email, UID hoặc bảng điểm cá nhân vào evidence công khai.
- Có hai tình huống: chưa nhập điểm và có điểm đã đạt/đang học/chưa đạt/học lại đã đạt. Ghi rõ dữ liệu mẫu hay dữ liệu người tham gia tự nguyện dùng.
- Người điều phối đọc mục tiêu; không chỉ đường bấm trước. Ghi riêng số lần phải trợ giúp.
- Figma chỉ kiểm interaction được mô phỏng. Persistence, OCR/AI có nguồn và Google/Firebase phải kiểm trên app thật; không suy ra từ prototype.

## Nhiệm vụ

| ID | Lời giao nhiệm vụ | Điều kiện cần quan sát |
|---|---|---|
| T1 | Hãy cho biết bạn đã học đến đâu và bước tiếp theo. | Phân biệt đã hoàn thành/còn lại/đang học; mở từng kỳ; không đếm trùng môn học lại. |
| T2 | Tìm một môn có thể học và một môn còn thiếu điều kiện. | Giải thích đúng mã tiên quyết; Back giữ ngữ cảnh. |
| T3 | Bạn chưa nhập bảng điểm. Hãy tìm cách bắt đầu. | Tìm nhập tay hoặc xem chương trình; không hiểu trạng thái trống là GPA bằng 0. |
| T4 | Ảnh bảng điểm không đọc được. Hãy khôi phục và lưu điểm. | Nhập tay; sửa mã/điểm/kỳ/tín chỉ; kiểm GPA và mở lại trên app. |
| T5 | Hãy nhờ tư vấn một môn theo mục tiêu của bạn. | Xác định môn, nguồn và giới hạn; khôi phục khi API lỗi. |
| T6 | Hãy đi qua các màn và quay về nơi bắt đầu. | 5 tab, chi tiết, Back, dialog hủy; kiểm 360/412 dp, chữ 1.3× và desktop. |

## Ghi từng lượt thực tế

| Người/loại phiên | Build hoặc Figma node | Thiết bị/viewport | Task/fixture | Expected | Observed | Kết quả | Thời gian/trợ giúp | Evidence/issue |
|---|---|---|---|---|---|---|---|---|
| Chưa chạy | — | — | — | — | — | Not tested | — | — |

Không tính internal walkthrough hoặc widget test là user-task pass. Chỉ tính tỷ lệ persona sau khi có kết quả thực tế; Partial không tính Pass.
