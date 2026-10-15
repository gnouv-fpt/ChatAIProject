# Kiến trúc thông tin và user flow — FLM

Trạng thái: **luồng từ source Flutter hiện tại**. Đây là đặc tả để dựng Figma, chưa phải bằng chứng prototype Figma đã chạy.

## IA — tám đích điều hướng

| ID | Màn hình | Cấp | Đường vào hiện có |
| --- | --- | --- | --- |
| S01 | Trang chủ / tiến độ | Gốc | Khởi động app, tab Trang chủ |
| S02 | Lộ trình theo học kỳ / sơ đồ | Gốc | Tab Lộ trình, CTA từ S01 |
| S03 | Chi tiết môn | Con | Chọn môn từ S01/S02/S08 |
| S04 | Trợ lý và lịch sử phiên | Gốc | Tab Trợ lý, hoặc trợ lý ngữ cảnh từ S03 |
| S05 | Bảng điểm | Gốc | Tab Bảng điểm, CTA từ S01/S03 |
| S06 | Xác nhận / sửa bảng điểm | Con | Nhập ảnh hoặc nhập tay từ S05 |
| S07 | Cài đặt / hồ sơ tư vấn | Gốc | Tab Cài đặt, CTA từ S01 |
| S08 | Chương trình đào tạo | Con | “Chương trình đào tạo” từ S01 |

Dialog tư vấn, sheet chat, loading/empty/error là biến thể trạng thái, **không tính thêm màn hình**. Trên mobile dùng thanh điều hướng dưới; từ 900 dp, app dùng thanh điều hướng bên trái. Back ở S03/S06/S08 trở về màn đã mở; các tab gốc giữ vị trí riêng.

## F01 — Từ kết quả học đến môn kỳ tới

**Start:** S01, **goal:** biết một môn có thể cân nhắc kỳ tới và căn cứ tiên quyết, **end:** S03 đã xem điều kiện. Primary P01.

```mermaid
flowchart TD
  A[S01 Trang chủ] --> B[S07 Tự khai mục tiêu và kỳ hiện tại]
  B --> C[S05 Bảng điểm]
  C --> D[S06 Nhập và xác nhận kết quả]
  D --> E[S01 Xem tiến độ]
  E --> F[S02 Chọn Kỳ tới]
  F --> G{Trạng thái tiên quyết}
  G -->|Đủ theo dữ liệu| H[S03 Xem điều kiện và nguồn]
  G -->|Thiếu hoặc mã chưa xác minh| I[S03 Xem mã còn thiếu/cần xác minh]
  I --> J[S05 Bổ sung/sửa kết quả hoặc hỏi cố vấn]
  J --> F
  H --> K([Kết thúc: giải thích được lựa chọn])
```

Nếu bảng điểm trống, ứng dụng yêu cầu nhập trước khi kết luận đủ tiên quyết. Nếu chưa xác nhận kỳ, chỉ hiện kỳ suy ra từ kết quả gần nhất/môn đang học và cho phép sửa ở S07.

## F02 — Chiến lược cho một môn theo mục tiêu

**Start:** S02 hoặc S08, **goal:** nhận gợi ý theo mục tiêu cá nhân và dữ liệu môn, **end:** S04 trả lời có nguồn/giới hạn. Primary P01.

```mermaid
flowchart TD
  A[S02 hoặc S08 chọn môn] --> B[S03 Ba tab: CLO, điều kiện, đánh giá]
  B --> C{Đã đặt mục tiêu?}
  C -->|Chưa| D[S07 Đặt mục tiêu qua môn/điểm cao]
  D --> B
  C -->|Rồi| E[S03 Gợi ý chiến lược]
  E --> F[S04 Hỏi trợ lý theo ngữ cảnh môn]
  F --> G{Có dữ kiện FLM phù hợp?}
  G -->|Có| H[Trả lời nêu nguồn và mục tiêu]
  G -->|Thiếu| I[Nêu giới hạn, yêu cầu bổ sung]
  H --> J([Kết thúc: biết nên học thế nào])
  I --> J
```

## F03 — Nhập ảnh thất bại, phục hồi và hỏi lại

**Start:** S05, **goal:** có bảng điểm đúng rồi nhận tư vấn cập nhật, **end:** S04 có phiên mới và phiên cũ vẫn mở được. Primary P01.

```mermaid
flowchart TD
  A[S05 Chọn 1–10 ảnh] --> B{Đọc ảnh thành công?}
  B -->|Có| C[S06 Kiểm tra từng môn/điểm/kỳ]
  B -->|Không hoặc API lỗi| D[S05 Lỗi dễ hiểu và Thử lại]
  D --> E[S06 Nhập tay]
  E --> C
  C --> F{Có dòng sai?}
  F -->|Có| G[S06 Sửa hoặc xóa có xác nhận]
  G --> C
  F -->|Không| H[S05 Lưu và xem GPA]
  H --> I[S04 Tạo phiên tư vấn mới]
  I --> J[S04 Mở phiên cũ từ lịch sử]
  J --> K([Kết thúc: so sánh trước/sau])
```

Ảnh gửi backend để trích xuất; bảng điểm đã xác nhận lưu trên thiết bị. Flow thiết kế không khẳng định OCR luôn đúng.

## Flow → screen

| Flow | Màn hình | Nhánh thay thế / phục hồi |
| --- | --- | --- |
| F01 | S01, S07, S05, S06, S02, S03 | Thiếu tiên quyết hoặc chưa có kỳ/bảng điểm |
| F02 | S02, S08, S03, S07, S04 | Chưa có mục tiêu hoặc thiếu dữ liệu FLM |
| F03 | S05, S06, S04 | Ảnh/API lỗi → nhập tay; sửa/xóa trước lưu |

Tất cả S01–S08 thuộc ít nhất một flow. Nguồn quy cách flow: [Đề Lab 2](https://prm393-material.web.app/docs/PRM323-Lab2-Thiet-ke-UIUX-co-ho-tro-AI.pdf), [Chuẩn chung C6/C7](https://prm393-material.web.app/#standards).
