# P01 — Proto-Persona cho cố vấn học tập FLM

> **Trạng thái: Assumed.** Đây là giả thuyết thiết kế dựa trên bài toán và nhận xét giảng viên trong `nhan_xet_giang_vien.md`, không phải kết quả phỏng vấn sinh viên. Không dùng tên, câu nói hay số liệu bên dưới như bằng chứng nghiên cứu.

## Problem statement

Sinh viên đang theo chương trình FLM cần ghép bảng điểm, điều kiện tiên quyết và mục tiêu học tập để biết môn nào nên xem cho kỳ tới; thông tin rải ở nhiều chỗ khiến việc tự lập lộ trình và hỏi chiến lược cho từng môn mất thời gian.

## 12 trường lõi

| Trường | P01 — Sinh viên tự lập kế hoạch học |
| --- | --- |
| 01 Identity & archetype | “Minh” là tên giả định; sinh viên cần tự xem tiến độ và chọn môn tiếp theo. |
| 02 Priority | Primary: luồng chính của sản phẩm phục vụ sinh viên đang học, có bảng điểm từng phần. |
| 03 Usage context | **Assumed:** xem nhanh trên điện thoại trước khi hỏi cố vấn/chọn môn; có thể quay lại trên web để xem sơ đồ. |
| 04 Goals | Biết mình đã hoàn thành gì; tìm môn kỳ tới có điều kiện phù hợp; nhận chiến lược học theo mục tiêu. |
| 05 JTBD | Khi chuẩn bị học kỳ tiếp theo, tôi muốn đối chiếu kết quả đã xác nhận với tiên quyết của chương trình để biết môn nào cần xem tiếp và vì sao. |
| 06 Current behaviors | **Assumed:** tự đối chiếu bảng điểm và chương trình đào tạo, hỏi bạn học/giảng viên khi không chắc điều kiện. Cần phỏng vấn để xác nhận. |
| 07 Pain points | Khó thấy vị trí hiện tại; không rõ mã môn tiên quyết còn thiếu; lời khuyên chung không phản ánh mục tiêu qua môn/điểm cao. Đây là vấn đề giảng viên nêu, chưa phải lời kể của người dùng. |
| 08 Motivations | Muốn quyết định có căn cứ, tiết kiệm thời gian và kiểm soát điểm mục tiêu. **Assumed.** |
| 09 Constraints | Bảng điểm có thể thiếu/ảnh đọc sai; mạng hoặc AI có thể lỗi; ứng dụng không biết lịch mở lớp. **Assumed** về hoàn cảnh sử dụng. |
| 10 Key scenarios | F01 nhập kết quả rồi tìm môn kỳ tới; F02 mở môn và xin chiến lược; F03 ảnh nhập sai thì sửa tay và hỏi lại. |
| 11 Success criteria | Trong think-aloud, tự chỉ được ít nhất một môn kỳ tới và nói đúng căn cứ tiên quyết, không cần người hướng dẫn; đo thời gian và lỗi thao tác. Chưa có kết quả đo. |
| 12 Evidence & status | `nhan_xet_giang_vien.md` và `gop_y_de_xuat_them.md`: **Reported** (góp ý giảng viên); mã màn hình và luồng từ source Flutter: **Observed**; hành vi cá nhân của Minh: **Assumed**. Chưa có E-ID phỏng vấn/quan sát sinh viên. |

### Chi tiết Lab 2 bắt buộc

- Tuổi: **20, giả định**; cần xác nhận với sinh viên tham gia.
- Vai trò: sinh viên FPT theo chương trình FLM.
- Thói quen thiết bị: **giả định** dùng điện thoại cho tác vụ nhanh, web cho quan hệ môn; chưa khảo sát.
- Accessibility: **chưa có bằng chứng cá nhân**; thiết kế mặc định phải dùng chữ nội dung ≥14 sp, vùng chạm ≥48×48 dp, nhãn trạng thái không chỉ dùng màu và hỗ trợ phóng to chữ.

## Giả thuyết thiết kế và cách kiểm chứng

| ID | Giả thuyết | Quyết định để thử | Kiểm chứng |
| --- | --- | --- | --- |
| H01 | Vị trí học tập khó nhận ra | S01 đặt tín chỉ, GPA, môn hoàn thành và kỳ ở đầu trang | T01: 5-second test, hỏi người dùng chỉ ra mình đang ở đâu |
| H02 | Tiên quyết là trở ngại chính khi chọn môn | S02 hiển thị danh sách theo kỳ và nhãn đủ/thiếu/cần xác minh | T02: tìm môn kỳ tới và giải thích lý do |
| H03 | Mục tiêu môn làm thay đổi cách học | S07 lưu mục tiêu dần; S03/S04 tư vấn qua môn và điểm cao khác nhau | T03: đổi mục tiêu rồi so sánh hai câu trả lời |
| H04 | Ảnh bảng điểm có thể đọc sai | S06 bắt buộc xác nhận/sửa trước khi lưu | T04: nhập ảnh có lỗi giả lập và sửa đúng một dòng |

## Kế hoạch nghiên cứu còn thiếu

Phỏng vấn/quan sát sinh viên thực hiện gần đây việc chọn môn và đối chiếu bảng điểm; hỏi từng bước, công cụ đã dùng, đoạn khó và thiết bị. Ghi mã E01… cho bằng chứng đã ẩn danh. Sau đó sửa/tách P01 theo khác biệt hành vi thực sự. Không gắn nhãn *Qualitative Persona* trước bước này.

Nguồn rubric: [Persona Guideline](https://prm393-material.web.app/persona-guideline.html), [Chuẩn chung C2/C5](https://prm393-material.web.app/#standards).
