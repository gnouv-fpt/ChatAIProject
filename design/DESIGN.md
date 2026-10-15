# FLM — design brief cho Lab 2

**Chủ đề cụ thể:** trợ lý chọn môn kỳ tới cho sinh viên FPT đang học chương trình FLM, có bảng điểm từng phần và cần đối chiếu tiên quyết trước khi xin chiến lược học. P01 hiện là **Proto-Persona (Assumed)** trong [`ux/persona.md`](../ux/persona.md).

Tài liệu này mô tả thiết kế **đang có trong source Flutter** và hướng chuẩn hóa cho Figma. Nó không phải bằng chứng Google Stitch hoặc Figma đã dựng xong. `DESIGN.md` ở gốc là bản style cũ, có palette khác; file này là brief cho luồng Lab 2 hiện tại.

## Mục tiêu màn hình

Sinh viên nhìn thấy ngay vị trí hiện tại, đi một bước tới môn kỳ tới, hiểu mã tiên quyết và hỏi cách học theo mục tiêu. Ưu tiên nội dung và căn cứ hơn trang trí. Từ ngữ hướng tới người học: “môn kỳ tới”, “còn thiếu”, “cần xác minh”, “bảng điểm đã xác nhận”.

## Token hiện tại và hướng đưa vào Figma

| Vai trò | Giá trị source Flutter | Figma Variable/Style cần tạo |
| --- | --- | --- |
| Primary | `#1565C0` | `color/primary` |
| Primary dark | `#0D47A1` | `color/primary-dark` |
| Surface | `#F8FAFC` | `color/surface` |
| Card | `#FFFFFF` | `color/card` |
| Text strong | `#0F172A` | `color/text-strong` |
| Text secondary | `#475569` | `color/text-secondary` |
| Border | `#E2E8F0` | `color/border` |
| Accent | `#B34700` | `color/accent` — bản đậm để chữ trắng đạt khoảng 5.5:1 |
| Success | `#2E7D32` | `color/success` + icon/nhãn chữ |
| Warning | `#E65100` | `color/warning` + icon/nhãn chữ |

Spacing 8/16/24/32 dp; lề mobile 16 dp. Radius 6/10/14/18 dp; ưu tiên radius 14 cho card và 10 cho input/nút. Typography source dùng Roboto; Figma cần định nghĩa title, section, body ≥14 sp, caption chỉ dùng cho metadata khi vẫn đọc được. Light theme bắt buộc. Giá trị trên là **source hiện tại**, chưa xác nhận tương phản của mọi cặp và chưa tạo Variables trong Figma.

## Quy tắc component

- Một CTA chính cho mỗi màn hình: S01 “Xem môn kỳ tới” hoặc “Nhập kết quả”, S05 “Nhập bảng điểm”, S06 “Lưu”, S03 “Hỏi trợ lý”.
- Card chỉ gom thông tin cùng nhiệm vụ; không dùng màu khác nhau để trang trí từng card.
- Trạng thái môn luôn có nhãn chữ và icon; không dựa riêng vào xanh/cam/đỏ.
- Nút, chip, trường nhập và mục điều hướng thiết kế vùng chạm tối thiểu 48×48 dp; cần đo trong Figma và trên thiết bị.
- Dữ liệu thiếu phải có câu rõ và hành động phục hồi. Không tự tạo điểm, lịch mở lớp, quy định du học hoặc nội dung môn.
- Với dữ liệu tải bất đồng bộ: loading, empty, error/retry và populated; success sau thao tác lưu.
- Thiết kế mobile ở 360×800 dp; kiểm tra thêm 412 dp. Từ 600 dp mô tả thay đổi trong handoff; app hiện chuyển sang NavigationRail từ 900 dp.

## Prompt đầu vào dự kiến cho Stitch

**Chưa gửi prompt này tới Google Stitch.** Đây là brief có thể dùng làm đầu vào; khi thực sự chạy Stitch phải chép nguyên văn prompt đã gửi và lưu ảnh kết quả vào `ai/ai-design-log.md` / `assets/stitch/`.

> Thiết kế ứng dụng mobile 360×800 dp bằng tiếng Việt cho sinh viên FPT đang theo chương trình FLM, có bảng điểm từng phần và cần biết môn kỳ tới. Primary Persona là proto-persona, chưa được xác thực. Luồng chính: xem tiến độ → nhập hoặc xác nhận kết quả → xem môn kỳ tới theo học kỳ → thấy rõ đủ, thiếu hoặc chưa xác minh tiên quyết → mở chi tiết môn với ba tab Chuẩn đầu ra, Điều kiện môn học, Tiêu chí đánh giá → hỏi trợ lý theo mục tiêu qua môn hoặc điểm cao. Dùng một màu nhấn xanh #1565C0, nền #F8FAFC, chữ #0F172A, khoảng cách bội số 8, một CTA chính mỗi màn. Chữ nội dung ít nhất 14 sp, vùng chạm ít nhất 48×48 dp, trạng thái có nhãn ngoài màu, có loading, empty và error/retry. Đừng tạo điểm số giả hoặc kết luận lịch mở lớp.

Nguồn yêu cầu: [Đề Lab 2](https://prm393-material.web.app/docs/PRM323-Lab2-Thiet-ke-UIUX-co-ho-tro-AI.pdf), [UI Checklist](https://prm393-material.web.app/ui-checklist.html).
