# Feedback UI/UX 26/10 — bản sửa và phiếu kiểm chung

Cập nhật 27/10/2026. Nhánh chung: `PRM-Lab3-integration`. Mục đích: chốt phần sửa feedback để nhóm tiếp tục Lab 3, không tuyên bố Lab 3 hoặc nghiên cứu người dùng đã hoàn tất.

## Đã thay đổi

| Feedback | Thay đổi cụ thể | Bằng chứng |
|---|---|---|
| Học tới đâu, còn bao nhiêu môn | S01 có hoàn thành/tổng, progress, còn lại, đang học, cần học lại và mở rộng từng kỳ. Chưa có điểm hiện lời dẫn và CTA, không tạo GPA/tiến độ giả. | `learning_progress.dart`, `learning_journey_card.dart`; unit/widget tests và ảnh `evidence/ux/2026-10-27/` |
| UI chưa đồng bộ | Roboto/body ≥14, theme cho FilledButton/IconButton/navigation; S05/S06 dùng màu trạng thái chung; FlmNotice dùng lại; nút có tooltip và trạng thái disabled khi lưu. | `app_theme.dart`, `flm_notice.dart`, S01/S02/S05/S06; ảnh render Flutter ở 360/412 dp |
| Status của 6 thành phần | Board mô tả Button/Text field/Card/Navigation/App bar/Dialog, state/variant, tình huống và persona; có 7 instance từ thư viện thật. | [Figma board](https://www.figma.com/design/N3LyPn9HWDC0M34lVR5jCC/PRM323-Lab-2---FLM-Student-Assistant?node-id=86-348) |
| Mapping và số màn theo persona | Bảng nhu cầu–màn–component–task bên dưới; board Figma riêng. | [Figma mapping](https://www.figma.com/design/N3LyPn9HWDC0M34lVR5jCC/PRM323-Lab-2---FLM-Student-Assistant?node-id=86-543) |
| Prototype chuyển nhanh | AI Loading tự chuyển từ 1,2 lên 3 giây; CTA Home có click sang Lộ trình. Kịch bản demo dừng tại điểm quyết định. | Node `8:117`, `86:345`; hướng dẫn bên dưới |
| Tự test rồi gom lại | Bộ task, tiêu chí pass và mẫu ghi kết quả chung; phân biệt developer checks với usability test. | Các bảng bên dưới; chưa có buổi user test mới |

Sửa thêm lỗi dữ liệu ảnh hưởng hành trình: dòng 0 tín chỉ nhưng catalog có tín chỉ phải được kiểm trước khi lưu; bỏ trống trường sửa sẽ dùng tín chỉ catalog. Không chặn môn 0 tín chỉ hợp lệ/kỳ 0. Không bắt duyệt lại mọi dòng OCR. GPA preview tạm ẩn nếu còn dòng thiếu tín chỉ.

## Quy tắc số liệu hành trình

- Mỗi môn catalog chỉ đếm một lần, kể cả nhiều lần học. Môn ngoài catalog không làm tăng phần trăm.
- Còn lại = tổng môn catalog − số môn đã đạt; có gồm môn đang học.
- Đang học không gồm môn đã có kết quả đạt; cần học lại chỉ gồm môn từng chưa đạt, chưa được học lại thành công và không đang học.
- Kỳ trong các chip lấy từ curriculum của môn; không cộng trùng kỳ học lại.
- Dữ liệu là phần bảng điểm đã nhập, chưa chứng minh toàn bộ lịch sử học. Chưa nhập dữ liệu không đồng nghĩa 0 môn đã từng học.
- App tính dữ liệu thật theo tài khoản đang dùng; ảnh test và Home Figma 1/48 là fixture minh họa có nhãn trong hồ sơ evidence.

## Sáu nhóm component

| Nhóm | State / variant | Quy tắc nhất quán | Persona / màn |
|---|---|---|---|
| Button | Default, Pressed, Focused, Disabled, Loading | Một hành động chính mỗi khối; thao tác đang lưu không gửi trùng; lỗi cho thử lại | P01–P04, S01–S08 |
| Text field | Default, Focused, Filled, Error, Disabled | Label không biến mất; báo lỗi có chữ tại trường; giữ dữ liệu để sửa | P01/P03 S06; P01–P03 S04/S07 |
| Card | Default, Pressed, Selected, Disabled khi áp dụng | Cùng radius/border; status có nhãn, không chỉ màu | P01/P02/P04 S02/S03/S08; P01/P03 S05/S06 |
| Navigation | Selected/Unselected; 5 active variants | Cùng thứ tự/nhãn; mobile bottom bar, desktop rail; màn con dùng Back | P01–P04, S01/S02/S04/S05/S07 |
| App bar | Root, Back; action enabled/disabled | Cùng hierarchy; action có tooltip; không coi Root/Back là trạng thái nhấn | P01–P04, root và S03/S06/S08 |
| Dialog | Confirm, Error; open/submit/confirm/cancel khi áp dụng | Hủy giữ dữ liệu; xác nhận báo kết quả; lỗi validation giữ nội dung | P01/P03 S06, P04 kiểm |

Loading/Empty/Error là pattern bổ sung, dùng `DataStateView`/`FlmNotice` khi phù hợp. Navigation label là 12 sp để 5 đích không chen nhau ở 360 dp; body và thông báo là ≥14 sp. Những màn cũ còn style viết riêng phải tiếp tục đối chiếu trong Lab 3; lượt này không chứng nhận toàn app đã hết hardcode hoặc đạt pixel parity.

## Persona và số màn liên quan

Theo `ux/persona.md` và IDs trong `docs/design-traceability.md`. Đây là mapping thiết kế, không phải tỷ lệ hài lòng hoặc kết quả usability test.

| Persona | Màn distinct có liên quan | Tổng nhu cầu dùng làm mẫu số |
|---|---|---|
| P01 Hoàng Nam | 8: S01–S08 | 5 |
| P02 Thu Trang | 7: S01/S02/S03/S04/S05/S07/S08 | 5 |
| P03 Minh Tuấn | 5: S01/S04/S05/S06/S07 | 4 |
| P04 Giảng viên | 6: S02/S03/S04/S05/S06/S08 | 3 |

Không cộng dialog/loading thành màn mới. AUTH hỗ trợ truy cập, không cộng vào 8 màn nghiệp vụ. S06 có thể phục vụ P02 sau khi có điểm nhưng chưa tính trong tình huống người mới chưa có điểm này.

| ID nhu cầu | Nhu cầu / tiêu chí người dùng cần đạt | Màn và component | Task / trạng thái bằng chứng |
|---|---|---|---|
| P01-N1 | Đọc đúng đã học/còn lại, biết dữ liệu chỉ là bảng điểm đã nhập | S01/S05, Journey/metric card | T1; developer regression pass, người dùng chưa test |
| P01-N2 | Chọn môn kỳ tới và giải thích đúng chuỗi tiên quyết | S02/S03/S08, course card/navigation | T2; flow widget 360/412 pass, người dùng chưa test |
| P01-N3 | Đối chiếu GPA/mục tiêu từ tín chỉ và điểm xác nhận | S05/S06/S07, fields/metric | T4/T5; đã chặn thiếu tín chỉ, chưa nghiệm thu task đầy đủ |
| P01-N4 | Nhập/sửa kết quả mà không biến dự định thành điểm | S05/S06, fields/dialog | T4; test nhập tay/lưu pass; cần kiểm dữ liệu nhiều lần học |
| P01-N5 | Tư vấn bám môn, chương trình và mục tiêu | S03/S04/S07, chat/source card | T5; cần backend thật và kiểm nội dung |
| P02-N1 | Bắt đầu khi chưa có điểm, phân biệt self-check với kết quả | S01/S05, empty/CTA | T3; empty UI pass, self-check độc lập còn thiếu |
| P02-N2 | Hiểu PE/FE, tín chỉ tích lũy và tín chỉ GPA | S03/S04/S05, body/help | T3/T5; chưa user test giải thích thuật ngữ |
| P02-N3 | Xem đúng toàn cảnh chương trình khóa mình | S02/S08, navigation/filter | T2; catalog K21 chưa xác minh |
| P02-N4 | Tìm môn PE và cách học phù hợp | S02/S03/S04, filter/card/chat | T2/T5; chưa nghiệm thu task với người mới |
| P02-N5 | Hiểu tiến độ cá nhân, không hiểu empty là chưa từng học | S01/S07, journey/fields | T1/T3; empty có copy và regression, người dùng chưa test |
| P03-N1 | Phân biệt học lại/cải thiện có căn cứ | S04/S05/S06, entry/source | T4/T5; cần quy chế và curriculum K18 phù hợp |
| P03-N2 | Hiểu tính khả thi của mục tiêu GPA | S01/S05/S07/S04, metric/goal | T1/T5; chưa nghiệm thu task đầy đủ |
| P03-N3 | Xác định đúng môn còn nợ để ưu tiên | S01/S05/S06, journey/entry | T1/T4; unit test loại nợ đã trả và đếm distinct pass |
| P03-N4 | Local-only đúng như nhu cầu persona đã nêu | S05/S06/S07/S04, privacy copy | Chưa đáp ứng ở production Firestore; nhập tay không tự tạo local-only |
| P04-N1 | Kiểm Curriculum → Subject → Chat có nguồn | S08/S03/S04/S02, navigation/source | T2/T5; cần backend/source verification |
| P04-N2 | Kiểm được GPA nhiều lần học bằng thuật toán | S05/S06, fields/metric | T4; cần đối chiếu fixture với phép tính độc lập |
| P04-N3 | Thao tác desktop rõ, đọc được và không lỗi layout | S02/S03/S04/S05/S06/S08 | T6; desktop walkthrough còn mở |

**Tỷ lệ đã kiểm chứng = số nhu cầu Pass / tổng nhu cầu × 100%.** Mỗi nhu cầu có đúng một kết quả tổng hợp Pass / Partial / Fail / Not tested; Partial không tính Pass trong chỉ số chính. Nhiều màn cùng phục vụ một nhu cầu không làm tăng mẫu số. Developer test chỉ chứng minh điều kiện kỹ thuật đã nêu, không thay user-task pass. Hiện chưa đủ user-task evidence cho bộ nhu cầu này nên giữ **N/A**, không báo 0% hay 100%.

## Task chung để từng thành viên tự kiểm rồi tổng hợp

| Task | Cách chạy và tiêu chí pass | Persona |
|---|---|---|
| T1 Hành trình | Có điểm gồm đã đạt/đang học/chưa đạt và một lần học lại đã đạt; đọc số còn lại, mở từng kỳ, chọn bước tiếp theo; không đếm trùng | P01/P02/P03 |
| T2 Tiên quyết | Tìm một môn đủ và một môn thiếu tiên quyết; mở chi tiết; giải thích đúng lý do và Back giữ ngữ cảnh | P01/P02/P04 |
| T3 Chưa có điểm | Mở tài khoản mới; hiểu chưa đủ dữ liệu; tìm đường nhập tay hoặc xem chương trình; không hiểu tick là điểm GPA | P02 |
| T4 OCR và nhập tay | Ảnh lỗi → nhập tay; dòng thiếu tín chỉ → sửa dòng đó → lưu; so GPA/tín chỉ và mở lại; 0 tín chỉ hợp lệ vẫn lưu được | P01/P03/P04 |
| T5 Tư vấn có nguồn | Chọn môn, đặt mục tiêu, hỏi theo môn; chỉ ra nguồn/giới hạn. Khi API lỗi có thông báo và phục hồi | P01/P02/P03/P04 |
| T6 Nhất quán và điều hướng | 5 tab, Back, dialog hủy/xác nhận; 360/412 dp, text scale 1.3, desktop, bàn phím; không overflow/đích cụt | P01–P04 |

Ghi **mỗi lượt thực tế** theo mẫu sau; mỗi người ít nhất một lượt có điểm và một lượt chưa có điểm. Internal review phải ghi là internal review; không tự coi đồng đội đóng vai persona là người dùng đại diện.

| Người test | Commit/build | Thiết bị/viewport | Task/fixture | Kết quả | Thời gian | Lần trợ giúp | Expected/Observed | Evidence | Issue ID |
|---|---|---|---|---|---|---|---|---|---|
| Chưa ghi nhận phiên người dùng | — | — | — | Not tested | — | — | — | — | — |

Khôi tổng hợp theo task/issue, chủ phần việc sửa lỗi mình phụ trách. Giữ số lượt độc lập, không cộng trùng cùng video/fixture. Kết quả phải ghi lại bước thực tế và lỗi, không chỉ nhận xét “đẹp/xấu”.

## Nhịp demo mới

1. Nói persona và câu hỏi trước khi thao tác.
2. F01: mở bảng điểm xác nhận → Home; dừng 5–8 giây chỉ đã hoàn thành/còn lại/đang học → mở kỳ → môn → giải thích tiên quyết.
3. F02: chương trình → môn → mục tiêu → chat; dừng chỉ nguồn. Loading Figma 3 giây là mô phỏng, không phải latency backend.
4. F03: mở lỗi OCR → chỉ đường nhập tay → sửa dòng đánh dấu → lưu → đối chiếu kết quả. Không click liên tục qua lỗi.
5. Sau mỗi hành động, nói rõ điều gì đã thay đổi rồi mới chuyển màn. Slide không cần quay lại toàn bộ prototype ở tốc độ cao.

## Evidence và phạm vi nghiệm thu

- `flutter analyze`: pass.
- `python -m unittest backend.tests.test_grade_import_fallback_unittest`: **5 tests pass**, có mock Groq text extraction và kiểm missing-credits confidence; không phải gọi OCR/API thật.
- `flutter build apk --debug`: pass từ source cuối, Gradle 13,5 giây (build trước đó 63 giây).
- `flutter test --exclude-tags live`: **50 tests pass**, gồm counts/distinct/debt, thiếu tín chỉ, flow tiên quyết 360/412 và UI journey/empty/confirm + text scale 1.3.
- Ảnh test render bằng widget thật, font SDK Roboto/MaterialIcons, dữ liệu synthetic; không phải ảnh tài khoản thật, ARTEMIS hay user research. Chạy lại: `flutter test test/feedback_ui_test.dart --dart-define=UX_EVIDENCE=true` trong `flutter_app/`.
- Figma export thật trước/sau và hai board nằm ở `design/evidence/2026-10-27/`. Home cũ lưu ở frame `86:332`; Home chính giữ ID `2:2470`.
- Bounded validator: **122 nodes**, không báo issue trong Journey và hai board; có limitation không xác minh fixed-text overflow cho `86:343`. Đã xem ảnh export. Không suy ra toàn file đạt accessibility hoặc toàn prototype đã chạy end-to-end.
- Còn khác biệt được ghi ở `docs/design-traceability.md`; chưa chạy lại đủ 3 prototype flow, chưa kiểm canvas Canva, chưa có phỏng vấn/usability session mới. Các phần này không được đổi thành Pass khi push nhánh chung.
