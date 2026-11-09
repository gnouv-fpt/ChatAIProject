# Kịch bản trình bày Lab 2 từ UX research đến Figma prototype

Mục tiêu của bài trình bày là giải thích **vì sao từng quyết định thiết kế được đưa ra**, rồi mở bằng chứng tương ứng. Sản phẩm là FLM Student Assistant, hỗ trợ sinh viên FPT xem tiến độ, hiểu điều kiện môn học và nhận tư vấn học tập theo mục tiêu. Thứ tự kể: **người dùng và vấn đề → UX research → UX design → wireframe → app style guide → mockup → Figma prototype → handoff**.

## Lời mở đầu khoảng 30 giây

> Sinh viên phải ghép thông tin từ chương trình học, bảng điểm và lời khuyên rời rạc để quyết định kỳ tới học gì. Nhóm thiết kế một luồng giúp người học thấy mình đang ở đâu, kiểm tra môn và điều kiện tiên quyết, rồi hỏi trợ lý theo đúng ngữ cảnh. Hôm nay em trình bày các quyết định từ nghiên cứu vấn đề đến prototype, cùng bằng chứng và phần còn phải kiểm chứng.

## Kịch bản 12 slide

| Slide | Nội dung trên slide | Cách kể và thứ cần mở |
| --- | --- | --- |
| 1. Bối cảnh sản phẩm | Đối tượng: sinh viên FPT; tác vụ: lập kế hoạch học tập theo chương trình, điểm và mục tiêu | Nêu một tình huống xuyên suốt: Hoàng Nam muốn chọn môn kỳ tới nhưng chưa chắc điều kiện tiên quyết. Mở link [Figma](https://www.figma.com/design/N3LyPn9HWDC0M34lVR5jCC/PRM323-Lab-2---FLM-Student-Assistant) và repo. |
| 2. UX research: câu hỏi | Người dùng gặp khó ở bước nào? Cần thông tin nào để tin vào tư vấn? Điều gì xảy ra khi bảng điểm thiếu hoặc nhập ảnh lỗi? | Nguồn đã có: nhận xét giảng viên về Lab 1, phân tích chương trình/luồng hiện tại và bộ persona do nhóm cung cấp. **Chưa có log phỏng vấn, khảo sát hoặc usability test sinh viên**, nên gọi đây là *nghiên cứu thứ cấp và giả thuyết thiết kế*, không gọi là insight đã xác nhận. |
| 3. Người dùng và persona | Primary: Hoàng Nam, sinh viên năm 3; secondary: Thu Trang năm đầu, Minh Tuấn giai đoạn cuối; giảng viên là supporting persona | Mỗi persona chỉ nêu một nhu cầu ảnh hưởng trực tiếp đến thiết kế: Nam cần lộ trình/tiên quyết; Trang chưa có điểm nên cần self-check và giải thích thuật ngữ; Tuấn cần học lại/GPA và kiểm soát dữ liệu; giảng viên cần kiểm tra câu trả lời có nguồn. Mở `ux/persona.md` và slide persona nguồn. |
| 4. Tổng hợp vấn đề → yêu cầu UX | Problem statement và 3 quyết định ưu tiên | Nói rõ quan hệ nhân quả: dữ liệu rời rạc → Trang chủ phải thể hiện tiến độ; quan hệ môn khó đọc → Lộ trình + Chi tiết môn; lời khuyên thiếu căn cứ → chat theo môn, có nguồn và giới hạn. Tiêu chí thành công là người dùng chọn được môn kỳ tới và giải thích vì sao, **chưa có số đo thực tế**. |
| 5. UX design: information architecture | 8 màn S01–S08: Trang chủ, Lộ trình, Chi tiết môn, Trợ lý, Bảng điểm, Xác nhận điểm, Hồ sơ, Chương trình | Chỉ rõ năm tab gốc trên mobile và ba màn con có Back. Dialog/state không tính thành màn riêng. Mở `ux/user-flow.md` và `design/screen-spec.md`. |
| 6. UX design: 3 user flows | F01 kết quả → môn kỳ tới → tiên quyết; F02 chương trình → chi tiết → tư vấn; F03 import ảnh lỗi → nhập tay/sửa → tư vấn | Theo F01, cho thấy cả nhánh thiếu bảng điểm và thiếu tiên quyết. Theo F03, chỉ ra đường phục hồi từ OCR/API lỗi. Mở ba sơ đồ trong `ux/user-flow.md`; đây là flow được đặc tả, **chưa tự nhận cả ba đã chạy trong prototype**. |
| 7. Wireframe | Bố cục thấp độ trung thực cho màn chính; vị trí thông tin, CTA và đường điều hướng | So sánh một cặp có thật, ưu tiên Trang chủ hoặc Bảng điểm: wireframe đặt tiến độ và hành động chính ở đâu, vì sao; thông tin nào được hoãn sang Chi tiết. Mở page `02 Wireframe` trong Figma. Nếu một wireframe không có đối tác final rõ ràng, không đưa vào cặp so sánh. |
| 8. App style guide | Màu, chữ, khoảng cách, radius, elevation, trạng thái và accessibility | Màu primary `#1565C0`, accent `#B34700`, nền `#F8FAFC`, chữ chính `#0F172A`; giải thích chọn tương phản và vai trò token, không chỉ đọc mã màu. Figma đã có variable/text style và thư viện 9 nhóm component với 30 variants đã xử lý; còn cần xác minh instance trên màn thật. Mở Variables/styles và review board component. |
| 9. Mockup / Final UI | Wireframe → màn hoàn chỉnh; hierarchy, nội dung thật, empty/loading/error | Mở page `03 Final UI`; chỉ đếm **màn khác nhau** khớp S01–S08. Figma từng có 11 mobile frame gồm cả state, vì vậy không tuyên bố đủ 8 màn distinct trước khi đối chiếu. Nêu ví dụ màu đã đồng bộ với app và một quyết định UI từ feedback. |
| 10. Vòng lặp thiết kế và AI critique | Vấn đề → thay đổi → bằng chứng trước/sau → quyết định | Có ảnh Figma thật trước/sau cho màu và component. Có các nhận xét UX trong `ai/ai-design-log.md`, nhưng đây là critique từ source/ảnh và chưa phải user test. **Chưa có output Google Stitch và ba vòng lặp Stitch được yêu cầu**, nên không gán các lần sửa Figma thành Stitch iterations. |
| 11. Figma prototype | Điểm bắt đầu, thao tác, Back, dialog overlay, loading/result, lỗi/phục hồi | Demo lần lượt F01–F03 khi đã kiểm từng đường đi. Kiểm không có dead end, Back quay đúng nơi, dialog là overlay. Hiện trạng ghi nhận 281 node có reaction và 3 starting point, nhưng con số đó **không chứng minh** ba flow đạt yêu cầu; cần chạy và ghi kết quả. |
| 12. Handoff và kết luận | Screen spec, token → Flutter, component → widget; những gì hoàn tất và còn mở | Mở `handoff/flutter-handoff.md`. Kết luận bằng một chuỗi trace: nhu cầu của Nam → F01 → wireframe Trang chủ/Lộ trình → style guide → final UI → prototype. Nói rõ giới hạn: thiếu nghiên cứu người dùng thực, Stitch evidence, nghiệm thu 8 màn/3 flow và QA toàn màn 360/412 dp. |

## Demo một tình huống xuyên suốt

1. **Persona và mục tiêu:** Nam muốn đạt loại Giỏi và không bị nghẽn môn tiên quyết.
2. **Thông tin cần:** kỳ hiện tại, điểm đã xác nhận, môn đã hoàn thành, điều kiện của môn định học.
3. **Thiết kế:** nhập/xác nhận điểm → xem tiến độ → mở Lộ trình → chọn môn → xem điều kiện → hỏi trợ lý theo môn.
4. **Trạng thái lỗi:** nếu thiếu điểm, giao diện không kết luận đã đủ điều kiện; nếu nhập ảnh lỗi, cho thử lại hoặc nhập tay.
5. **Kết quả cần kiểm với người dùng:** Nam tự chọn được một môn có thể cân nhắc và giải thích đúng lý do. Đây là mục tiêu kiểm chứng, chưa phải kết quả test.

## Bằng chứng và cách gọi đúng hiện trạng

| Hạng mục | Bằng chứng hiện có | Cách trình bày |
| --- | --- | --- |
| UX research | Nhận xét giảng viên ở `../nhan_xet_giang_vien.md`; persona PowerPoint do nhóm cung cấp | Phân tích phản hồi và xây giả thuyết; chưa có phỏng vấn/khảo sát sinh viên được lưu. |
| Persona | `ux/persona.md` và `../PRM393 User Persona.pptx` | Persona do nhóm cung cấp, chưa được xác nhận bằng nghiên cứu người dùng. |
| UX design | `ux/user-flow.md`, `design/screen-spec.md` | Có IA, 8 đích điều hướng và 3 flow được đặc tả. |
| Wireframe | Figma page `02 Wireframe` | Mở cặp wireframe/final cụ thể và giải thích thay đổi. |
| App style guide | `design/figma-progress-2026-10-21.md` và Figma variables/components | Có token, text styles, 9 nhóm component; kiểm instance và các màn trước khi tuyên bố áp dụng toàn bộ. |
| Mockup | Figma page `03 Final UI`, ảnh export thật trong `design/evidence/` | Đếm màn distinct theo S01–S08; không cộng dialog và state. |
| Prototype | Figma interactions hiện có | Chạy nghiệm thu ba flow đầu-cuối; ghi đường lỗi/phục hồi và Back. |
| AI process | `ai/ai-design-log.md` | Có critique và sửa Figma; Stitch output/ba vòng lặp riêng vẫn thiếu. |

## Việc cần hoàn tất trước khi trình bày như một quá trình đã khép kín

- Có ít nhất một hoạt động UX research với người dùng thực và lưu phương pháp, số người, nhiệm vụ/câu hỏi, ghi nhận ẩn danh, kết luận; nếu không kịp thì giữ nhãn giả thuyết, không bịa số người hoặc câu nói.
- Đối chiếu 8 màn S01–S08 với 8 frame Final UI khác nhau, kèm cặp wireframe → mockup rõ ràng.
- Chạy và ghi bằng chứng ba flow prototype, gồm error/recovery, Back, overlay và loading → result.
- Bổ sung output/prompt thật của Google Stitch và ba vòng lặp khác mục tiêu nếu vẫn áp dụng rubric gốc.
- Kiểm giao diện ở 360 và 412 dp, chữ, vùng chạm và tương phản trên **màn thật**; phép kiểm token/component chưa thay thế được bước này.
- Kiểm quyền xem Figma và GitHub bằng tài khoản ngoài nhóm.

Tài liệu hướng dẫn slide trong thư mục Lab1 đề xuất 10 phút, 10–12 slide, 5 phút demo và 5 phút hỏi đáp; đây là **đề xuất tổ chức**, giảng viên có thể thay đổi. Rubric gốc cho điểm quá trình UX/AI lẫn sản phẩm Figma/handoff, nên mỗi slide cần có một bằng chứng mở được.
