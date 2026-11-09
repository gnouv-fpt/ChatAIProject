# AI design log — trạng thái thực tế

**27/10/2026 — sửa feedback:** Codex đọc source/feedback, thêm LearningJourneyCard và phép đếm distinct trong service, đồng bộ theme/thông báo S05/S06, chặn lưu thiếu tín chỉ. Figma official MCP dùng để đọc, hết quota Starter; tiếp tục bằng Figma MCP Bridge đã cài. Đã sửa Home native editable, tạo board 6 nhóm component với 7 instances và board persona/task, bind 134 token/style usages trong scope mới, đổi loading 1,2 → 3 giây. Bounded layout: 122 nodes, không issue, một limitation fixed text; xem ảnh export và [kết quả/giới hạn](../docs/ux-feedback-validation.md). Không gọi các hoạt động này là Stitch iterations hoặc user test. Persona cloud production theo quyết định trong `docs/requirements-cloud-amendment.md`; nhu cầu local-only P03 vẫn chưa đạt.

**Cập nhật 21/10/2026:** Đã có [file Figma được người dùng cung cấp](https://www.figma.com/design/N3LyPn9HWDC0M34lVR5jCC/PRM323-Lab-2---FLM-Student-Assistant). Codex đã chỉnh foundation, Button/Text field bằng Figma MCP và tạo 7 family còn lại bằng local MCP Bridge. Thư viện có 9 family/30 variants đã xử lý; riêng lượt bridge có 7 set/20 variants/20 review instances, ảnh export thật và bounded layout check 702 node/44 target, không phát hiện lỗi trong scope thư viện. [Ảnh thật và quyết định](../design/figma-progress-2026-10-21.md); [receipt](../design/figma-components-local/bridge-receipt.json). Còn tích hợp vào màn và kiểm prototype. Nội dung ngày 15/10 bên dưới là lịch sử tại thời điểm đó. Chưa có bằng chứng Google Stitch hoặc ba vòng lặp Stitch; các lần sửa bằng MCP không được đổi nhãn thành vòng lặp Stitch.

**Persona được bổ sung:** người dùng cung cấp `PRM393 User Persona.pptx` (4 slide): Hoàng Nam là Primary, Thu Trang và Minh Tuấn là Secondary, giảng viên là Supporting. Đã thay bản persona giả định cũ trong `ux/persona.md`, cập nhật design brief, user flow và draft prompt Stitch. P01 ưu tiên desktop; Android vẫn theo đề. Local-only của P03 xung đột phạm vi Firestore Final, chưa có quyết định tự đồng bộ điểm. Nội dung slide là nguồn do người dùng cung cấp, không có hồ sơ nghiên cứu mới để xác nhận persona.

**Stitch:** đã mở trang và quan sát dialog Additional Terms of Service; chưa chấp nhận điều khoản, chưa gửi prompt thành công, chưa có project/output. Bốn prompt chuẩn bị ở [`stitch/`](stitch/README.md) chỉ là draft. Chưa tạo bằng chứng before/after Stitch.

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
