# Figma → Flutter traceability

## Áp dụng vào code 29/10/2026

Đã đọc Figma Desktop qua bridge local và đối chiếu AUTH `90:443`, S07 `2:2915`, S08 `90:489`/`90:516`, S06 `90:552` với source. AUTH đồng bộ căn lề/typography/nút full width; S07 đồng bộ card tài khoản, mục tiêu/hồ sơ, privacy copy và CTA Xem chương trình; S08 đưa identity vào body, dùng lựa chọn tab xuống dòng trên mobile và chỉnh search/filter theo tokens. Giữ dữ liệu và hành vi thật; không đưa TEST/account picker giả vào app. Home/S06 và các flow tư vấn đã có trong code trước lượt này.

15 widget/regression tests liên quan pass, analyzer sạch; ảnh render ở `evidence/ux/2026-10-29/`. Kiểm 360/412/1280 dp với chữ 1.3×, login cancel, Settings → chương trình → Back, recovery, filter, OCR nhập tay và tư vấn mobile. Không phải pixel parity cả tám màn, live Firebase hoặc user research. Full suite bị gián đoạn do tài nguyên máy; APK mới chưa build thành công (Gradle daemon crash). Xem evidence README. Figma Desktop vẫn báo saved locally/will sync when reconnects.

## Đồng bộ thiết kế 29/10/2026

[Bàn giao và link node](figma-lab3-sync-2026-10-29.md): thêm S08 tổng quan/danh sách và layout 360/412/1280; S06 sửa từng dòng; S07 account/logout, AUTH và Home mở rộng học kỳ. Đã xem ảnh tám màn; 103 interaction configs khớp readback, validator 374 nodes không báo issue. Đây là kiểm cấu trúc/config và ảnh, chưa phải pixel parity, Present walkthrough, user test hoặc live Firebase. Figma Desktop có changes lưu local, chưa xác minh sync cloud.

- D01: AUTH `90:443`, hủy/thử lại và chọn tài khoản mô phỏng đã có.
- D02–D03: S07 `2:2915` có account/logout, copy theo tài khoản; badge bảng điểm đổi thành “CÁ NHÂN”.
- D04: disclosure Home `86:343` → expanded `90:610` → thu gọn Home; không còn mở màn lộ trình từ disclosure này.
- D05: Button `86:345` có nhãn “Mở lộ trình học”.
- S06 giữ root `2:2414`, thêm dialog `90:552` và ready `90:591`; Save thiếu tín chỉ đi tới validation.

Các thay đổi trên chưa đóng nghiệm thu UX-01 tổng thể. Các đoạn ngày 27/28 bên dưới là lịch sử; trạng thái mới dùng mục ngày 29 và báo cáo bàn giao.

## Kiểm chứng code 28/10/2026

[Review và bàn giao Vương](vuong-ui-review-2026-10-28.md): sửa đường tư vấn S08 trên mobile, recovery khi thiếu/sai curriculum, thống nhất trạng thái môn, responsive phần chiến lược và copy xóa dữ liệu theo account. Widget checks F01 Back, F02 scope/close, F03 lỗi OCR → nhập tay → lưu; 58 tests pass. Ảnh 360/412/1280 dp tại `evidence/ux/2026-10-28`. Đây không phải nghiệm thu Figma hay live services. Các deviation bên dưới tiếp tục mở.

## Cập nhật feedback 27/10/2026

S01 đã thêm `LearningJourneyCard` với counts/progress/từng kỳ lấy từ `LearningProgress`; S05/S06 dùng `FlmNotice` và token trạng thái chung. Theme chuẩn hóa typography, button và navigation. [Bảng persona–màn–component–task và phiếu test](ux-feedback-validation.md).

- Home Figma giữ `2:2470`, Journey mới `86:337`, bản nội dung trước sửa `86:332`.
- [Design System một trang](https://www.figma.com/design/N3LyPn9HWDC0M34lVR5jCC/PRM323-Lab-2---FLM-Student-Assistant?node-id=86-558), [mapping và nhịp demo](https://www.figma.com/design/N3LyPn9HWDC0M34lVR5jCC/PRM323-Lab-2---FLM-Student-Assistant?node-id=86-543). Đây là board native editable có instance thư viện và token/style bindings, không phải ảnh UI nhập vào canvas.
- AI Loading `8:117`: timeout 1,2 → 3 giây. CTA Journey click sang danh sách `2:2563`.
- Deviation D04: Flutter mở rộng từng kỳ inline; Figma hiện mở màn lộ trình theo kỳ `2:2777`. Lý do: tái sử dụng đích prototype hiện có, chưa dựng state expansion tương ứng. Còn phải đồng bộ interaction trước nghiệm thu pixel/flow parity.
- Deviation D05: Figma dùng Button instance nhãn “Tiếp tục”, Flutter dùng “Mở lộ trình học”; cùng hành động mở lộ trình. Còn chuẩn hóa nhãn instance.
- S06 Figma đã sửa ba dòng hướng dẫn sang lưu theo tài khoản/kiểm dòng đánh dấu; bố cục form vẫn là bản cũ, khác danh sách sửa dòng trong app. Lượt này chưa coi màn S06 Figma đã khớp app.
- Thêm chữ/ảnh tài liệu mới không thay thế nghiệm thu tất cả màn và 3 flow. Số pass kỹ thuật hiện có: analyzer sạch, 50 unit/widget tests; user test/ARTEMIS chưa được ghi nhận mới.

Figma: https://www.figma.com/design/N3LyPn9HWDC0M34lVR5jCC/PRM323-Lab-2---FLM-Student-Assistant

Trạng thái: bảng ánh xạ source, chưa phải nghiệm thu pixel parity hoặc prototype. Đối chiếu cùng `design/screen-spec.md`, `ux/user-flow.md`, `handoff/flutter-handoff.md`.

| ID | Màn | Route / điểm vào | Widget / file trong flutter_app/lib | Dữ liệu | Trạng thái |
|---|---|---|---|---|---|
| S01 | Trang chủ / tiến độ | shell tab 0 | screens/home_screen.dart | CourseCatalog, TranscriptProvider, LearningProfileProvider | Có code; cần nghiệm thu Figma |
| S02 | Lộ trình | shell tab 1 | screens/roadmap_screen.dart; features/graph/views/graph_view_screen.dart | CourseCatalog, transcript | Có code; cần nghiệm thu quan hệ và layout |
| S03 | Chi tiết môn | /courses/:code | pages/course_detail_page.dart | CourseRepository; RAG theo mã môn | Có code; kiểm ba tab và error recovery |
| S04 | Trợ lý / lịch sử | shell tab 2; contextual panel | features/chat/views/chat_screen.dart | ChatProvider → ChatApiService; cache theo UID | Có code; backend thật cần chạy để nghiệm thu |
| S05 | Bảng điểm | shell tab 3 | screens/transcript_screen.dart | TranscriptProvider; OCR API | Có code; cloud chưa có bằng chứng |
| S06 | Sửa/xác nhận điểm | Navigator từ S05 | screens/transcript_confirm_screen.dart | TranscriptEntry; save callback | Figma sửa dòng + validation/ready; còn nghiệm thu app/Present |
| S07 | Cài đặt / hồ sơ | shell tab 4 | screens/settings_screen.dart | LearningProfileProvider; AuthViewModel | Figma có account/sign out; live account và sync cloud còn mở |
| S08 | Chương trình | /curricula/:id; CTA Home | pages/curriculum_detail_page.dart | CourseCatalog / repository | Có frame 90:489/90:516 và 360/412/1280; chưa pixel parity |
| AUTH | Google Sign-In | FirebaseEntry → AuthGate | screens/sign_in_screen.dart | AuthService | Figma 90:443; picker mô phỏng; Google thật còn mở |

| Flow | Màn | Kết quả cần kiểm |
|---|---|---|
| F01 | S01 → S07 → S05 → S06 → S01 → S02 → S03 | Tiến độ/môn kỳ tới, nhánh thiếu dữ liệu và tiên quyết |
| F02 | S02/S08 → S03 → S07 → S04 | Tư vấn theo mục tiêu, nguồn và giới hạn |
| F03 | S05 → lỗi OCR → S06 nhập tay → S05 → S04 | Phục hồi, sửa điểm và lịch sử phiên |

| Figma component | Mapping hiện tại | Gap |
|---|---|---|
| Button | Theme elevated/outlined + Material buttons | Chưa gom đủ variants thành wrapper chung |
| Text field | InputDecorationTheme | Cần đối chiếu state/error/helper |
| Card | Material Card + HoverCard | Còn nhiều card viết riêng |
| Navigation | AppShell NavigationBar/NavigationRail | Cần đối chiếu các breakpoint |
| App bar | Material AppBar | Cần gom variants |
| Dialog | AlertDialog, course summary modal | Cần đối chiếu overlay/back |
| Loading/Empty/Error | Screen-specific UI | Cần component và explicit state dùng chung |

## Deviation ledger
| ID | Thay đổi | Lý do | Code | Trạng thái Figma |
|---|---|---|---|---|
| D01 | Thêm Google Sign-In và auth gate | Lab 3 bắt buộc khi Lab 2 chưa có login | FirebaseEntry, AuthViewModel, SignInScreen | Prototype cập nhật 29/10; chưa live/Present/cloud sync |
| D02 | Thêm account và sign out tại S07 | Lab 3 yêu cầu logout và xóa cache | SettingsScreen | Prototype cập nhật 29/10; chưa nghiệm thu account thật |
| D03 | Cache tách UID; không tự nhận dữ liệu legacy | Ngăn lộ hồ sơ/điểm/chat giữa tài khoản | PersonalPreferences, các Provider | Copy theo tài khoản cập nhật 29/10; isolation runtime còn mở |

Mọi hàng chưa nghiệm thu phải giữ trạng thái mở; có widget không đồng nghĩa flow đã pass.
