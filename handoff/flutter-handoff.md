# Flutter handoff — FLM S01–S08

Đây là đặc tả **từ source đang chạy** để chuyển sang Figma. Chưa khẳng định Figma đã có 6 page, component instances hay prototype. Mã màn/flow trong [`ux/user-flow.md`](../ux/user-flow.md); trạng thái trong [`design/screen-spec.md`](../design/screen-spec.md).

## Quy tắc chung

- Mobile 360×800 và 412 dp: `NavigationBar` năm đích S01/S02/S04/S05/S07. Màn con S03/S06/S08 dùng Back của `Navigator`.
- Từ 900 dp: `NavigationRail` bên trái; S03 có chat panel bên phải từ 960 dp. Từ 600–899 dp vẫn dùng bottom bar trong source hiện tại; kiểm overflow trước bàn giao.
- Lề 16 dp, spacing cơ bản 8/16/24/32; màn nội dung dài cuộn dọc. Text scale không được cắt chữ; cần QA ở 360/412 dp.
- Vùng chạm thiết kế ≥48×48 dp, chữ nội dung ≥14 sp. Các điểm chưa đạt trong source được ghi ở `design/design-decisions.md`.
- Fact môn/chương trình lấy từ danh mục FLM; điểm/GPA từ bảng điểm đã xác nhận; mục tiêu từ hồ sơ tự khai. Không hợp nhất ba nguồn này thành một lời khẳng định không có căn cứ.

## Đặc tả sáu mục cho từng màn hình

### S01 — Trang chủ

1. **Layout:** `Scaffold > AppBar > RefreshIndicator > ListView`; metric và “Vị trí hiện tại” trước danh sách khám phá; toàn phần dưới AppBar cuộn.
2. **Components:** AppBar/default, metric Card/default, Course Card/pressed, CTA Button/default, BottomNavigation/Trang chủ selected.
3. **States:** loading catalog; empty transcript hiện CTA nhập; error catalog có Thử lại; populated có GPA, tín chỉ, kỳ và gợi ý môn.
4. **Interactions:** kéo làm mới danh mục; chạm môn kỳ tới mở S03; CTA mở S02 hoặc S05 theo dữ liệu; chạm hồ sơ mở S07.
5. **Navigation:** app mở tại S01; bottom/rail tới S02/S04/S05/S07; card chương trình tới S08; Back từ S08/S03 về S01.
6. **Constraints:** tối đa ba môn gợi ý trong khối đầu; tên môn có thể xuống dòng; kỳ suy ra phải ghi nguồn suy ra, không gọi là kỳ hiện tại đã xác nhận.

### S02 — Lộ trình

1. **Layout:** `Scaffold > AppBar > Column` chứa chuyển danh sách/sơ đồ, tìm kiếm, chip kỳ, `Expanded ListView`; danh sách cuộn, chip cuộn ngang.
2. **Components:** Search TextField/default/focused, ChoiceChip/selected, Course Card/default/pressed, Loading/Error/Empty pattern.
3. **States:** loading/empty/error catalog; populated có môn theo kỳ; không bảng điểm có nhãn chưa xác nhận.
4. **Interactions:** chọn “Kỳ tới”, HK hoặc Tất cả; tìm mã/tên; chọn môn; chuyển sang sơ đồ.
5. **Navigation:** từ S01 hoặc tab; môn → S03; Back từ S03 trở S02 giữ lựa chọn tab trong `IndexedStack`.
6. **Constraints:** nhãn trạng thái phải có chữ; không kết luận đủ điều kiện đăng ký; hàng môn phải chấp nhận tên dài và text scale.

### S03 — Chi tiết môn

1. **Layout:** `Scaffold > AppBar > breadcrumb > scroll view`; desktop có cột chat; ba tab nội dung trong phần chính.
2. **Components:** AppBar/action, TabBar/selected, status Badge, Button/default, Advisor Dialog/confirm, Chat Sheet.
3. **States:** loading course; unknown code/empty data; lỗi dữ liệu cần đường quay lại; populated có điều kiện, đánh giá, CLO.
4. **Interactions:** chuyển ba tab; mở môn tiên quyết/kế tiếp; xem gợi ý chiến lược; hỏi AI; cập nhật điểm.
5. **Navigation:** từ S01/S02/S08; hỏi AI mở sheet mobile/panel desktop hoặc S04 ngữ cảnh; Back về nơi gọi.
6. **Constraints:** thiếu assessment/CLO hiện “chưa có dữ liệu”; điểm và tiên quyết chỉ lấy từ dữ liệu; không gán phần trăm hoặc ngưỡng mặc định. Nội dung tư vấn dài phải cuộn.

### S04 — Trợ lý và phiên

1. **Layout:** `Scaffold > AppBar > ListView messages > composer`; lịch sử phiên nằm trong modal/sheet mở từ action.
2. **Components:** ChatBubble/user/assistant/error, TextField/filled, Send Button/loading, Session ListTile/selected.
3. **States:** welcome/empty phiên; sending/loading; API error với gửi lại; populated với nguồn và lịch sử.
4. **Interactions:** nhập/gửi câu hỏi; mở phiên cũ; tạo phiên mới; câu hỏi theo scope môn/chương trình; link nguồn nếu có.
5. **Navigation:** tab từ S01 hoặc chat ngữ cảnh S03; Back khỏi sheet trở S03; các phiên giữ scope.
6. **Constraints:** không gửi câu hỏi rỗng; composer tránh bàn phím; câu trả lời dài cuộn; dữ liệu riêng tư không hiện trong tag phiên.

### S05 — Bảng điểm

1. **Layout:** `Scaffold > AppBar > ListView`; GPA và tín chỉ đầu tiên, sau đó thông báo riêng tư, nút nhập ảnh/nhập tay, danh sách môn.
2. **Components:** Metric Card, FilledButton/default/loading/disabled, Entry Card, Empty/Error pattern.
3. **States:** loading local; empty; ảnh đang xử lý; lỗi import có thử lại/nhập tay; populated có điểm và GPA.
4. **Interactions:** chọn 1–10 PNG/JPG; nhập tay; mở S06; xem/sửa dòng; chọn lại ảnh sau lỗi.
5. **Navigation:** tab hoặc CTA S01/S03; S06 Back trở S05; sau lưu hiện dữ liệu mới.
6. **Constraints:** ảnh gửi backend, cần thông báo rõ; không hiển thị stack trace; tên file dài ngắt dòng; bàn phím số cho điểm ở S06.

### S06 — Xác nhận/sửa bảng điểm

1. **Layout:** `Scaffold > AppBar > scrollable form/list` với dòng mã, điểm, kỳ, trạng thái; action lưu luôn truy cập được khi bàn phím mở.
2. **Components:** TextField/default/filled/error, Entry Card, Delete Dialog/confirm/cancel, Save Button/loading.
3. **States:** dữ liệu OCR chờ xác nhận; empty cho nhập tay; lỗi validation; success sau lưu.
4. **Interactions:** thêm/sửa/xóa dòng, chọn trạng thái đang học/đã đạt; xác nhận xóa; lưu chỉ khi hợp lệ.
5. **Navigation:** từ S05; Back bỏ thay đổi chưa lưu; lưu → S05; đóng dialog giữ S06.
6. **Constraints:** điểm trong thang 0–10, mã môn rõ; cảnh báo độ tin cậy OCR không bị che; không coi OCR là bản điểm đã xác nhận trước khi nhấn Lưu.

### S07 — Cài đặt/hồ sơ tư vấn

1. **Layout:** `Scaffold > AppBar > ListView`; mục tiêu môn và kỳ ở đầu; ưu tiên, cách học, mục tiêu dài hạn và nghề ở dưới.
2. **Components:** Dropdown/default/selected, Slider, TextField, Save Button, Clear Dialog.
3. **States:** empty persona, loaded, saving, save success/error; server URL được cấu hình riêng.
4. **Interactions:** chọn trường từng phần; lưu hồ sơ; sửa GPA mục tiêu; xóa bảng điểm qua xác nhận.
5. **Navigation:** tab hoặc CTA S01/S03; sau lưu giữ S07 và thông báo; Back tab tới nơi khác không tự lưu field chưa nhấn Lưu.
6. **Constraints:** không yêu cầu mọi trường; nghề tối đa 80 ký tự; kỳ 0–12 hoặc chưa xác định; bàn phím không che Lưu.

### S08 — Chương trình đào tạo

1. **Layout:** `Scaffold > AppBar > tab/board/map` theo kỳ; danh sách/board cuộn, sơ đồ có zoom/pan.
2. **Components:** Semester Card, SearchField, GraphNode/selected, CourseSummary Modal, Chat Panel.
3. **States:** loading/empty/error danh mục; populated với kỳ và môn; selected subject.
4. **Interactions:** chọn kỳ, tìm môn, chọn node/card, mở modal, mở S03, hỏi chat chương trình.
5. **Navigation:** từ card ở S01; môn → S03; Back từ S03 về S08, từ S08 về S01.
6. **Constraints:** quan hệ tiên quyết phải rõ mũi tên/nhãn; chỉ dùng quan hệ có trong danh mục, mã thiếu cần xác minh; sơ đồ phụ trợ danh sách.

## Token → Flutter

| Figma token dự kiến | Flutter hiện tại |
| --- | --- |
| `color/primary` `#1565C0` | `AppTheme.primaryBlue`, `ColorScheme.primary` |
| `color/surface` `#F8FAFC` | `AppTheme.slate50`, `scaffoldBackgroundColor` |
| `color/text-strong` `#0F172A` | `AppTheme.slate900` |
| `color/text-secondary` `#475569` | `AppTheme.slate600` |
| `color/border` `#E2E8F0` | `AppTheme.slate200` |
| `color/accent` | `AppTheme.accentOrange`; phải dùng bản đạt contrast khi đặt chữ trắng |
| `type/body` ≥14 sp | `TextTheme.bodyMedium` / `TextStyle(fontSize: 14)` |
| `space/1,2,3,4` = 8,16,24,32 | `SizedBox`, `EdgeInsets` tương ứng |
| `radius/sm,md,lg,xl` = 6,10,14,18 | `AppTheme.radiusSm/Md/Lg/Xl` |

## Component → Flutter widget

| Figma component/variant cần dựng | Flutter widget/pattern |
| --- | --- |
| Button/default/pressed/disabled/loading | `FilledButton` + progress/disabled state |
| Text field/default/focused/filled/error/disabled | `TextFormField`/`TextField` + `InputDecoration` |
| Card/default/pressed | `Card` + `ListTile` / `InkWell` |
| Navigation/selected destination | `NavigationBar`, `NavigationRail` |
| App bar/default/action | `AppBar` |
| Dialog/confirm/cancel/error | `AlertDialog` |
| Loading/screen | `CircularProgressIndicator` + label |
| Empty/screen | Icon, lời giải thích, CTA |
| Error/screen | Icon, lỗi dễ hiểu, `Thử lại` |

Nguồn yêu cầu 6 mục/màn và hai bảng: [Đề Lab 2, mục 8](https://prm393-material.web.app/docs/PRM323-Lab2-Thiet-ke-UIUX-co-ho-tro-AI.pdf).
