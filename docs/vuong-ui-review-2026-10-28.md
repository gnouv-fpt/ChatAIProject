# Bàn giao Vương — UI review, 28/10/2026

Nhánh riêng: `lab3/vuong-ui-review`, tách từ `035a5c7` trên `PRM-Lab3-integration`. Phạm vi: UX-01 và phần code/review của UX-02. Không đánh dấu toàn Lab 3 đã xong.

## Review và quyết định

Codex đọc source baseline `035a5c7`, viết regression test và sửa code; đây là AI-assisted internal review, không phải một reviewer độc lập hay usability study. Line tham chiếu thuộc baseline.

| ID | Loại | Bằng chứng / vấn đề trước sửa | Quyết định và kết quả | Commit |
|---|---|---|---|---|
| UXR01 | Navigation / responsive | `curriculum_detail_page.dart:277`: `_showRightChat=true` ẩn FAB cả trên mobile, trong khi panel chỉ render ở desktop. CTA tư vấn học kỳ cũng chỉ bật panel bị ẩn. | Accept. Dùng chung đường mở: mobile bottom sheet có Close/Back và keyboard inset, desktop panel; header chat không còn ép title và badge vào một hàng. | `b59ddf6` |
| UXR02 | Data integrity / error recovery | `curriculum_detail_page.dart:140`: thiếu curriculum vẫn hiện 48 môn/145 tín chỉ và quyết định mẫu. Route ID khác catalog cũng hiện nhầm chương trình. | Accept. Loading/error có retry và Back; chặn catalog không khớp route. Không tự tạo metadata khi thiếu dữ liệu. Tab dùng nhãn Sơ đồ môn học, cuộn được ở màn nhỏ. | `3f4ddd8` |
| UXR03 | Data consistency | `curriculum_detail_page.dart:544,779`: filter và badge dựa vào `attempts.last`; import lần rớt cũ sau lần đạt làm trạng thái khác Home/Lộ trình. | Accept. Dùng `LearningProgress` chung, ưu tiên đã đạt rồi đang học; một nguồn trạng thái cho filter và badge. Regression fixture nhập đạt trước/rớt sau. Không đổi quy tắc GPA. | `a916554` |
| UXR04 | Responsive / accessibility | `grade_strategy_panel.dart:117,255`: menu chen cùng tiêu đề, ba chip xếp Row. Regression tái hiện overflow khi chữ 1.3×. | Accept. Menu tách dòng, feature chips dùng Wrap/Flexible; nhãn gợi ý chat lấy typography chung. Test 360/412/1280 dp, text scale 1.3; ảnh widget thật. | `a815e9d` |
| UXR05 | Privacy / UX copy | Dialog xóa điểm mô tả chỉ xóa trên thiết bị trong khi provider có thể đồng bộ theo UID. | Accept. Nói rõ xóa bảng điểm tài khoản hiện tại và cập nhật dữ liệu đồng bộ khi thành công. Không thay auth/persistence của Bảo. | `a815e9d` |

Ba finding đầu có commit riêng, tên commit chứa ID. UXR04/05 cùng sửa widget chiến lược. Thay đổi format sau cùng được ghi ở commit bàn giao.

## Kiểm chứng

- `flutter analyze`: No issues found.
- `flutter test --exclude-tags live --reporter expanded --dart-define=UX_REVIEW_EVIDENCE=true`: 58 tests pass (50 baseline + 8 tests mới).
- F01: tiến độ → kỳ tới → điều kiện môn → system Back, giữ danh sách/bộ lọc ở 360/412 dp (`advising_flow_test.dart`).
- F02: curriculum → tư vấn → Back → tư vấn học kỳ, giữ scope ID và semester; close/reopen panel desktop (`curriculum_ux_test.dart`).
- F03: OCR service giả ném lỗi kết nối → nhập tay → xác nhận → lưu → đọc lại provider, đúng PRF192/8.5 và GPA 8.50. Không gọi OCR thật.
- Layout S08 tổng quan/danh sách ở 360/412/1280 dp, text scale 1.3. Ảnh dưới `evidence/ux/2026-10-28/`, render widget Flutter và font Roboto SDK, fixture có nhãn TEST; không phải screenshot tài khoản Firebase thật.
- Build APK và log: xem evidence README. Đây là kiểm chứng build, không chứng minh Google login, cloud, backend AI hay ARTEMIS.

## Figma và việc còn mở

- S08 vẫn cần frame chính thức. Code hiện có tab Tổng quan/Danh sách/Sơ đồ và tư vấn mobile/desktop, không khẳng định pixel parity với Figma.
- D04 (expand theo kỳ), D05 (nhãn CTA), S06 (form sửa từng dòng), D01–D03 (auth/account/privacy) vẫn mở ở Figma. Giữ ledger `design-traceability.md`; lượt này không sửa file Figma.
- F01–F03 đã có kiểm chứng widget nêu trên; live backend/source citations, Google/Firestore và nhánh lỗi dịch vụ thực cần nghiệm thu trên build tích hợp.
- User test T1–T6, desktop với người dùng thật, ARTEMIS ≥10 cases ×3, persona satisfaction/coverage vẫn chưa có evidence mới. Không quy đổi widget pass thành nhu cầu persona đã pass.
- Bộ nộp report/slides/video cuối chờ tính năng và evidence của Bảo/Khánh/Phúc/Khôi. Không lấy snapshot TEST hoặc fake OCR làm minh chứng Firebase/API thật.

## Checklist giao nhóm

1. Pull nhánh này, chạy suite/build theo evidence README, review 4 commit sửa và 5 findings.
2. Ghép vào `PRM-Lab3-integration` qua PR sau review; resolve tuần tự nếu Bảo đã đổi composition root/dependencies.
3. Bảo nghiệm thu auth/account thật, Khôi gắn runner, mỗi owner bàn giao hai cases và đoạn demo phần mình theo `lab3-team-plan.md`.
4. Vương đồng bộ các frame Figma còn mở, chạy user tasks thực và biên tập bộ nộp từ kết quả nhóm. Các phần đó chưa Verified.
