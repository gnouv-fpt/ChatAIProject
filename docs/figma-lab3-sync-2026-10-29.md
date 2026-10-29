# Đồng bộ Figma Lab 3 — 29/10/2026

Baseline app `493942c`, nhánh local `PRM-Lab3-integration`. Chỉnh file FLM hiện có, page `03 Final UI`, bằng MCP Bridge local sau khi connector chính hết quota. Không đổi source app/backend.

## Thiết kế và điểm vào

| Phần | Figma | Kết quả |
|---|---|---|
| AUTH / D01 | [90:443](https://www.figma.com/design/N3LyPn9HWDC0M34lVR5jCC/FLM?node-id=90-443) | Google login, chọn tài khoản mô phỏng, hủy và thử lại. |
| S07 / D02–D03 | [2:2915](https://www.figma.com/design/N3LyPn9HWDC0M34lVR5jCC/FLM?node-id=2-2915) | Account TEST, copy Firestore theo tài khoản, logout về AUTH, các trường hồ sơ và navbar. |
| S06 | [2:2414](https://www.figma.com/design/N3LyPn9HWDC0M34lVR5jCC/FLM?node-id=2-2414) | Dòng OCR thiếu tín chỉ, thêm/sửa môn, validation trước lưu. |
| S06 sửa / ready | [dialog](https://www.figma.com/design/N3LyPn9HWDC0M34lVR5jCC/FLM?node-id=90-552), [ready](https://www.figma.com/design/N3LyPn9HWDC0M34lVR5jCC/FLM?node-id=90-591) | Mã, điểm, kỳ, tín chỉ; fixture PRF192/8.5/3 tín chỉ/kỳ 1 → GPA 8.50/Giỏi → Save tới S05. |
| S01 / D04–D05 | [expanded](https://www.figma.com/design/N3LyPn9HWDC0M34lVR5jCC/FLM?node-id=90-610) | Disclosure mở rộng học kỳ trong Home và thu gọn; CTA “Mở lộ trình học”. Số môn từng kỳ đối chiếu catalog. |
| S08 | [danh sách](https://www.figma.com/design/N3LyPn9HWDC0M34lVR5jCC/FLM?node-id=90-489), [tổng quan](https://www.figma.com/design/N3LyPn9HWDC0M34lVR5jCC/FLM?node-id=90-516) | Frame chương trình, môn PRF192 → chi tiết, tư vấn mobile và lỗi/retry/Back. |
| S08 layout | [360](https://www.figma.com/design/N3LyPn9HWDC0M34lVR5jCC/FLM?node-id=90-674), [412](https://www.figma.com/design/N3LyPn9HWDC0M34lVR5jCC/FLM?node-id=90-697), [1280](https://www.figma.com/design/N3LyPn9HWDC0M34lVR5jCC/FLM?node-id=90-814) | Bản tĩnh; desktop có cột tư vấn. Chưa chứng nhận pixel parity. |

Giữ ID S06/S07; nội dung cũ được chuyển vào `05 · Archive · S06 S07 before Lab 3 sync`. Source action có nhãn cố định nằm tại `04C`, dùng vì bridge không nhận ID con của instance để override text. Màn vẫn là text/frame/vector/instance editable, không dùng ảnh UI làm nền.

## Đối chiếu tám màn nghiệp vụ

| Màn | Node | Implementation trong `flutter_app/lib/` |
|---|---|---|
| S01 | `2:2470`, expanded `90:610` | `screens/home_screen.dart`, `widgets/learning_journey_card.dart` |
| S02 | `2:2563`, `2:2777` | `screens/roadmap_screen.dart` |
| S03 | `2:2673` | `pages/course_detail_page.dart` |
| S04 | `2:2905` | `features/chat/views/chat_screen.dart` |
| S05 | `2:2910`, `25:772` | `screens/transcript_screen.dart` |
| S06 | `2:2414`, `90:552`, `90:591` | `screens/transcript_confirm_screen.dart` |
| S07 | `2:2915` | `screens/settings_screen.dart` |
| S08 | `90:489`, `90:516` | `pages/curriculum_detail_page.dart` |

Đã xem ảnh cả tám màn. Đối chiếu cấu trúc/nội dung và sửa các gap trên; S02/S03/S04 vẫn có nội dung prototype giản lược. PLO/CLO, search/filter và form input chưa mô phỏng đầy đủ runtime. Không cộng AUTH/dialog thành màn nghiệp vụ mới.

## Ba flow và kiểm chứng

- F01: Home → mở/thu học kỳ → lộ trình → chi tiết → Back. Navbar nối năm tab; header Home có đích S08.
- F02: S08 → tổng quan/danh sách → môn → chi tiết; tư vấn mobile mở overlay và Close/Back. Chat mẫu ghi rõ nguồn AI thật chưa nghiệm thu.
- F03: nhập ảnh → lỗi → nhập thủ công → S06 → sửa dòng → ready → Save → S05. Save còn thiếu tín chỉ mở validation, không chuyển thẳng tới đã lưu.

Readback **103 cấu hình interaction: 103 khớp destination/Back**. Năm tab đang chọn không NAVIGATE về chính màn đó. Đây là kiểm cấu hình bằng Plugin API, **chưa phải walkthrough trong Present hoặc user study**.

Validator cuối: **374 nodes, scan complete, 0 issues được báo** trên 17 roots. Lượt bind đầu áp dụng 897 usage màu/spacing/type/radius, không lỗi; sửa form bổ sung 12 usage. Text mới dùng Roboto; device status/header kế thừa có Inter. Các màn đã kiểm editability không có image-fill UI. Không suy rộng validator sang keyboard, assistive technology hoặc pixel parity.

[Ảnh, snapshot và verification JSON](../design/evidence/2026-10-29/README.md).

## Còn mở

- Desktop báo changes lưu local, sẽ sync khi reconnect. **Chưa xác minh cloud đã nhận node mới**; kiểm sync trước khi nộp/chia sẻ link cho nhóm.
- Cần Present walkthrough ba flow và nghiệm thu trên build tích hợp. D01–D05 đã cập nhật thiết kế/config, chưa biến toàn UX-01 thành Verified.
- [Phiếu T1–T6](ux-user-test-session.md) đã chuẩn bị; chưa có người tham gia hoặc observed values. Không coi internal review là user research.
- Live Google/Firestore/OCR/AI, ARTEMIS, persona satisfaction và report/slides/video còn mở.
- Không chạy lại suite chỉ vì đổi thiết kế/tài liệu; 58 tests/analyze/APK của lượt trước vẫn là evidence baseline code, không phải kết quả mới của lượt này.
