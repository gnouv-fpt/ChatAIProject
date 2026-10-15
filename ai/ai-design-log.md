# AI design log — trạng thái thực tế

Lab 2 yêu cầu **Google Stitch UI ban đầu, prompt nguyên văn, ảnh đầu ra, ít nhất ba vòng lặp khác mục tiêu có ảnh trước/sau, phản biện AI ≥5 phát hiện và quyết định Accept/Modify/Reject**. Không có bằng chứng Stitch/ảnh Figma trong repository tại thời điểm kiểm tra 15/10/2026, nên các mục đó **chưa hoàn thành**. Không dựng ảnh giả hoặc ghi prompt “đã gửi” khi chưa gửi.

## Công cụ AI đã dùng trong lượt này

| Công cụ | Mục đích | Bằng chứng |
| --- | --- | --- |
| Codex | Đọc tài liệu PRM393, đối chiếu source Flutter, soạn proto-persona/flow/spec và nêu vấn đề UI | Lượt làm việc 15/10/2026; các file trong `ux/`, `design/`, `handoff/` |
| Google Stitch | Chưa dùng/không có bằng chứng trong lượt này | Cần prompt gửi thực tế và ảnh kết quả |
| Figma | Chưa có URL file để kiểm tra/chỉnh sửa trong lượt này | Cần URL và quyền truy cập |

**Prompt người dùng nguyên văn cho lượt Codex này:**

> https://prm393-material.web.app/ đọc thông tin từ web trên để sửa theo yêu cầu của giảng viên

Đây là prompt yêu cầu đối chiếu và sửa dự án, **không phải prompt tạo UI trên Stitch**.

## AI critique sơ bộ dựa trên source, chưa phải review ảnh Figma

| ID | Màn | Phát hiện cụ thể | Heuristic / tiêu chí | Quyết định đề xuất |
| --- | --- | --- | --- | --- |
| C01 | S01 | Nhiều card liên tiếp cùng trọng số có thể làm CTA môn kỳ tới kém nổi bật | Visual hierarchy; UI checklist 11/13/14 | Modify: nhóm số liệu thành một khối, làm CTA nhiệm vụ chính nổi hơn; kiểm qua 5-second test |
| C02 | S02 | Trạng thái “đủ tiên quyết” khi bảng điểm chưa nhập dễ bị hiểu là đủ điều kiện đăng ký | Error prevention; match to real world | Accept: giữ nhãn “chưa xác nhận điều kiện” và thông báo giới hạn dữ liệu |
| C03 | S03 | Một số chữ trong chi tiết/tư vấn nhỏ hơn 14 sp | Accessibility; UI checklist 12 | Modify: nâng cỡ chữ nội dung, kiểm tràn ở 360/412 dp |
| C04 | S03 | Nút cam `#F57C00` với chữ trắng có tương phản khoảng 2.7:1 | WCAG text contrast; checklist 18 | Modify: đổi token sang `#B34700`, khoảng 5.5:1 với chữ trắng; còn cần kiểm toàn bộ cặp màu |
| C05 | S05 | Lỗi nhập ảnh có thể hiển thị raw exception từ backend | Help recover from errors; checklist 20 | Modify: thông báo ngắn, nói rõ thử lại/nhập tay, log kỹ thuật riêng |
| C06 | S07 | Nhiều trường hồ sơ trong một màn có thể thành biểu mẫu dài | Recognition; progressive disclosure | Modify: trường thiết yếu lên trước, trường dài hạn tùy chọn; thử với P01 |
| C07 | S04 | Nếu câu trả lời thiếu nguồn hoặc nguồn không rõ, sinh viên khó phân biệt fact FLM và lời khuyên | Visibility/trust | Accept: giữ nguồn và nhãn giới hạn; kiểm thực tế trên câu hỏi môn |

Các phát hiện là **đánh giá AI trên code**, chưa được kiểm chứng bằng người dùng hoặc ảnh Figma. Quyết định cuối phải ghi lại sau khi xem UI thật và test.

## Mẫu ghi ba vòng lặp Stitch cần hoàn tất

| Vòng | Vấn đề khác biệt cần giải quyết | Prompt gửi nguyên văn | Ảnh trước | Ảnh sau | Critique/decision |
| --- | --- | --- | --- | --- | --- |
| I01 | CTA tìm môn kỳ tới không nổi bật | Chưa chạy | Chưa có | Chưa có | Chưa quyết định |
| I02 | Tiên quyết/điểm thiếu khó đọc | Chưa chạy | Chưa có | Chưa có | Chưa quyết định |
| I03 | Empty/error của nhập ảnh chưa rõ đường phục hồi | Chưa chạy | Chưa có | Chưa có | Chưa quyết định |

Nguồn yêu cầu: [Đề Lab 2, mục 4–5](https://prm393-material.web.app/docs/PRM323-Lab2-Thiet-ke-UIUX-co-ho-tro-AI.pdf), [Chuẩn chung C3](https://prm393-material.web.app/#standards).
