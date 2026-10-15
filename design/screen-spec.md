# S01–S08 — mục đích, nội dung và flow

Các ID theo [IA và user flow](../ux/user-flow.md). Tám đích điều hướng này đã có cấu trúc trong source Flutter; **chưa xác nhận tám frame Final UI trong Figma**. Dialog, bottom sheet và state không được đếm thêm.

| ID | Mục đích | Nội dung ưu tiên | Flow | CTA / đường ra |
| --- | --- | --- | --- | --- |
| S01 Trang chủ | Thấy vị trí hiện tại và bước tiếp | Chương trình, tín chỉ, GPA, số môn xong, kỳ, đang học, tối đa ba môn kỳ tới | F01 | Nhập bảng điểm / xem môn kỳ tới; mở S07, S08, S04 |
| S02 Lộ trình | Tìm môn theo kỳ và hiểu trạng thái | Danh sách kỳ mặc định, bộ lọc kỳ tới, tìm kiếm, điểm môn xong, tiên quyết; sơ đồ là lựa chọn phụ | F01, F02 | Chọn môn → S03 |
| S03 Chi tiết môn | Hiểu môn và điều kiện | Ba tab CLO, điều kiện, đánh giá; trạng thái cá nhân, nguồn FLM, môn kế tiếp | F01, F02 | Hỏi trợ lý theo môn → S04/sheet; sửa điểm → S05 |
| S04 Trợ lý | Hỏi có ngữ cảnh và tìm lại phiên | Câu hỏi, câu trả lời và nguồn, scope môn/chương trình, phiên mới/lịch sử | F02, F03 | Gửi câu hỏi; mở phiên cũ; quay lại S03/S05 |
| S05 Bảng điểm | Xem và cập nhật dữ liệu cá nhân | GPA, tín chỉ, danh sách môn/điểm, lưu ý ảnh gửi backend | F01, F03 | Chọn ảnh hoặc nhập tay → S06 |
| S06 Xác nhận bảng điểm | Sửa OCR/điểm trước khi lưu | Mã, điểm, kỳ, trạng thái, cảnh báo dòng không chắc, thao tác thêm/sửa/xóa | F01, F03 | Lưu → S05; Back không lưu |
| S07 Hồ sơ tư vấn | Khai mục tiêu dần | Kỳ tự xác nhận, mục tiêu môn, ưu tiên/cách học, mục tiêu dài hạn/nghề | F01, F02 | Lưu → trở lại luồng trước |
| S08 Chương trình đào tạo | Khám phá chương trình và học kỳ | Board kỳ, map, danh sách môn, điều kiện, chat chương trình | F02 | Chọn môn → S03; Back → S01 |

## State cần đặt cạnh từng frame trong Figma

| Màn | Loading | Empty | Error/retry | Success/populated |
| --- | --- | --- | --- | --- |
| S01 | Tải danh mục | Chưa bảng điểm → CTA nhập | Danh mục lỗi → Thử lại | Dashboard và gợi ý kỳ tới |
| S02 | Tải danh mục | Kỳ/tìm kiếm không có môn | Danh mục lỗi → Thử lại | Danh sách trạng thái môn |
| S03 | Tải môn | Mã không tồn tại / thiếu trường dữ liệu | Lỗi tải → quay lại hoặc thử lại | Ba tab và chiến lược |
| S04 | Đang chờ trả lời | Chưa có câu hỏi trong phiên | API lỗi → báo lỗi và cho gửi lại | Trả lời có nguồn; phiên lưu |
| S05 | Đang đọc ảnh / tải điểm local | Chưa có bảng điểm | Ảnh/API lỗi → thử lại hoặc nhập tay | GPA và các dòng môn |
| S06 | Đang xử lý lưu | Chưa có dòng → thêm tay | Dòng/điểm không hợp lệ → sửa | Lưu xong và trở S05 |
| S07 | Đang tải hồ sơ local | Chưa khai → gợi ý trường đầu tiên | Lưu lỗi → thử lại | Hồ sơ đã lưu |
| S08 | Tải chương trình | Không có kỳ/môn | API lỗi → thử lại | Board/map và môn đã chọn |

Đây là **yêu cầu Figma cần dựng**, không tự nhận rằng mọi state đã được kiểm tra trên thiết bị. Nguồn: [Đề Lab 2, mục 3/7](https://prm393-material.web.app/docs/PRM323-Lab2-Thiet-ke-UIUX-co-ho-tro-AI.pdf), [Chuẩn chung C6](https://prm393-material.web.app/#standards).
