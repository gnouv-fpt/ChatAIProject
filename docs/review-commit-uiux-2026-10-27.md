# Rà soát commit và feedback UI/UX — 27/10/2026

**Đây là bản review trước sửa.** Lỗi thiếu tín chỉ đã được xử lý và regression pass; kế hoạch đã triển khai ở [kết quả feedback](ux-feedback-validation.md). Số file và trạng thái bên dưới là snapshot ban đầu, không phải danh sách việc còn lại hiện tại.

Phạm vi: working tree nhánh `PRM-Lab3-integration`, source Flutter/FastAPI, tài liệu persona, handoff và bằng chứng thiết kế lưu trong repo. Feedback do người dùng cung cấp ngày 26/10: A-, bổ sung status component, hành trình học, mapping persona, kiểm thử UI/UX, tính nhất quán và nhịp demo. Chưa mở lại canvas Figma/Canva, chưa chạy prototype hay test với người dùng thật trong lượt này.

## 1. Các phần cần commit

Trước lượt review có **11 file tracked đã sửa và 53 file untracked** (Git gom các thư mục ở status). Chưa có file staged. Không nên dùng `git add .` vì đang lẫn cấu hình IDE và ghi chú local.

| Commit đề xuất | File/phạm vi | Kết luận review |
|---|---|---|
| `fix: improve transcript OCR and confirmation` | `backend/app/api/v1/endpoints/grade_import.py`, `backend/app/services/llm_service.py`, `backend/app/services/local_ocr.py`, `flutter_app/lib/screens/transcript_confirm_screen.dart`, `flutter_app/test/transcript_manual_entry_test.dart` | Cùng một flow OCR → chuẩn hóa → kiểm tra → lưu. Tests hiện có pass; còn vấn đề dữ liệu thiếu tín chỉ bên dưới cần xử lý trước khi coi hoàn tất. |
| `fix: use UTF-8 for Windows backend logs` | `run_backend.py` | Thay đổi nhỏ, độc lập với UI; cấu hình stdout/stderr trước khi import ứng dụng. |
| `docs: align personas and capture design evidence` | `README.md`, `ai/ai-design-log.md`, `ux/persona.md`, `ux/user-flow.md`, `design/DESIGN.md`; `ai/stitch/`; các file Figma/palette ngày 21/10; `design/figma-components-local/`; ảnh thiết kế trong `design/evidence/2026-10-21/` | Giữ phân biệt draft Stitch, receipt/export Figma và preview HTML. Các đường dẫn từ tài liệu cần đi cùng file đích. Xem lại ảnh có thông tin tài khoản trước khi đưa vào repo dùng chung. |
| `docs: capture presentation feedback and UX validation plan` | `docs/lab2-speaker-notes.md`, `docs/lab2-ux-presentation-story.md`, tài liệu review này | Là tài liệu/kế hoạch, không phải bằng chứng đã sửa xong UI hoặc đã user test. Nội dung trạng thái thiết kế cũ cần đối chiếu canvas trước buổi trình bày tiếp theo. |

**Để ngoài commit:** `.idea/` (workspace/cache IDE); `firebase/rules-analysis.local.md` (ghi chú phân tích local, nếu cần bàn giao thì biên tập sang tài liệu Firebase chung). Hai ảnh `analytics-terms-required.png`, `firebase-terms-required.png` chủ yếu ghi lại màn điều khoản, cần cân nhắc giá trị bằng chứng và thông tin tài khoản; không phải bằng chứng chức năng app.

Trong `design/figma-components-local/README.md`, đoạn đầu nói builder chưa chạy và tránh chạy trùng, nhưng mục hướng dẫn phía sau vẫn bảo chạy plugin. Cần làm rõ đó là hướng dẫn cho bản sao/file mới trước khi bàn giao.

`AGENTS.md` đang mô tả dự án ASP.NET Razor/SQL Server, khác source Flutter/FastAPI hiện tại; đây là nợ tài liệu cần chỉnh riêng, không phải lý do chuyển kiến trúc ứng dụng.

### Vấn đề cần xử lý trước commit chức năng

**P1 — Dòng OCR thiếu tín chỉ có thể được lưu với 0 tín chỉ dù môn trong catalog có tín chỉ.** Backend dùng `0` khi thiếu cột và chỉ hạ confidence. `_save()` ở màn xác nhận chỉ chặn tín chỉ âm; bản sửa hiện giữ `entry.credits` thay vì lấy catalog. `GradeCalculator` nhân điểm với tín chỉ và cộng tín chỉ trực tiếp, nên một môn 3 tín chỉ đọc thiếu có thể bị bỏ khỏi trọng số GPA/tín chỉ tích lũy. Cảnh báo vàng chưa phân biệt số 0 hợp lệ với dữ liệu chưa đọc được.

Hướng sửa: phân biệt unknown với 0 hợp lệ; cho dùng tín chỉ catalog khi đã xác định đúng chương trình/môn, hoặc yêu cầu sửa **chỉ các dòng thiếu dữ liệu ảnh hưởng kết quả**. Giữ được các môn 0 tín chỉ/kỳ 0 có thật; không bắt người dùng sửa lại tất cả dòng OCR. Thêm regression test cho môn có tín chỉ nhưng OCR thiếu cột, và môn 0 tín chỉ hợp lệ.

**Khoảng trống kiểm thử:** ba backend unit tests vừa chạy kiểm vision và điểm ngoài miền; chưa kiểm nhánh vision lỗi → RapidOCR → Groq mới sửa. Các crop OCR dùng kích thước pixel cố định và ngưỡng nhận số cần thử nhiều kích thước/bố cục bảng điểm, chưa thể suy ra độ chính xác tổng quát từ một mẫu.

## 2. Đối chiếu feedback

| Feedback | Hiện có theo source/tài liệu | Việc còn thiếu / tiêu chí nghiệm thu |
|---|---|---|
| Mỗi thành phần mô tả status; 6 thành phần cơ bản | Handoff có Button, TextField, Card, Navigation, AppBar, Dialog; thư viện còn có Loading/Empty/Error | Làm board 6 nhóm với state, trigger, phản hồi và màn sử dụng; xem bảng bên dưới. Cách hiểu “6 thành phần” ở đây là đề xuất từ handoff, chưa phải danh sách được thầy xác nhận. |
| Hành trình học: tới đâu, còn bao nhiêu môn | Home có tổng môn, môn hoàn thành, tín chỉ/GPA, vị trí học kỳ, môn kỳ tới đủ tiên quyết | Bổ sung trực tiếp đã hoàn thành/tổng, còn lại, đang học, cần học lại, tiến độ theo kỳ; chỉ rõ dữ liệu dựa trên bảng điểm đã nhập. Chưa đủ dữ liệu không kết luận tiến độ toàn chương trình. |
| UI bắt mắt, nhất quán hơn | Có `AppTheme`, token và review component; S06 vẫn hardcode indigo/amber/red/grey và cỡ chữ riêng | Giữ một ngôn ngữ thị giác; đưa màu ngữ nghĩa, typography, card, khoảng cách và CTA về token chung; kiểm màn thật cạnh nhau. Chưa có visual QA mới để kết luận đẹp hơn. |
| Component/màn nào phục vụ persona nào | Có persona → 3 flow, có S01–S08 → source | Bổ sung nhu cầu → màn → component → task → evidence; mapping đề xuất ở mục 3. |
| Bao nhiêu % nhu cầu được đáp ứng | Chưa có bộ nhu cầu với kết quả nghiệm thu đầy đủ | Tính theo task đạt / nhu cầu đã định nghĩa; không lấy số màn / 8 làm % đáp ứng persona. |
| Prototype chuyển hơi nhanh | Chưa kiểm tốc độ trên prototype đang dùng | Dùng click/tap cho bước ra quyết định; demo dừng đủ thời gian chỉ thông tin chính và kết quả; tránh tự chuyển màn trước khi người xem đọc xong. Phân biệt tốc độ animation với tốc độ người demo thao tác. |
| Mỗi người tự test rồi tổng hợp | Có widget/unit tests; chưa có log usability test trong lượt này | Mỗi người chạy cùng task và biểu mẫu, ghi kết quả quan sát, ảnh/video, mức độ lỗi; gom theo task/issue, không cộng trùng số người hoặc số lỗi. |

### Board trạng thái cho 6 nhóm cơ bản (đề xuất cần hoàn thiện)

| Nhóm | State/variant cần trình bày | Tình huống chứng minh |
|---|---|---|
| Button | Default, pressed, focused/hovered desktop, disabled, loading | S06 lưu: đang lưu khóa thao tác trùng; lỗi cho thử lại |
| TextField | Empty, focused, filled, error, disabled/read-only khi áp dụng | Nhập điểm sai → thông báo ngay tại trường → sửa hợp lệ |
| Card | Default, pressed, selected, disabled khi áp dụng | Chọn môn; phân biệt đủ/thiếu tiên quyết bằng nhãn, không chỉ màu |
| Navigation | Selected, unselected, focused/hovered desktop | Đổi tab vẫn nhận ra vị trí; mobile/desktop giữ nhãn và thứ tự |
| AppBar | Root, back, actions; actions enabled/disabled nếu có | Màn con quay về đúng nơi; không nhầm variant Root/Back với interaction state |
| Dialog | Open, validation error, submitting nếu có, confirm/cancel | Sửa điểm hoặc xác nhận xóa; Back/dismiss và nút hủy có kết quả rõ |

Loading/Empty/Error là pattern của màn/flow bổ sung. Không ép component có state vô nghĩa chỉ để đủ số; state nào không áp dụng cần ghi N/A và lý do.

## 3. Mapping persona → màn và cách đo

ID màn theo `docs/design-traceability.md`: S01 Home, S02 Lộ trình, S03 Chi tiết, S04 Chat/lịch sử, S05 Bảng điểm, S06 Xác nhận điểm, S07 Hồ sơ, S08 Chương trình. AUTH là màn đăng nhập riêng, không cộng vào 8 màn nghiệp vụ.

| Persona | Màn liên quan, đếm distinct | Nhu cầu → màn → component chính | Khoảng trống cần giữ rõ |
|---|---|---|---|
| P01 Hoàng Nam | **8**: S01–S08 | Tiến độ → S01/S05, metric/progress card; tiên quyết → S02/S03/S08, course card/navigation; GPA/mục tiêu → S05/S06/S07, field/dialog; tư vấn → S03/S04, chat input/source card | Desktop và tính đúng chương trình cần kiểm; chưa có evidence người dùng tự hoàn thành task. |
| P02 Thu Trang | **7**: S01/S02/S03/S04/S05/S07/S08 | Chưa có điểm → S01/S05, empty/CTA; xem chương trình → S02/S08, navigation/filter; PE/FE/cách học → S03/S04, course card/chat; mục tiêu → S07, fields | Nhập tay bảng điểm không tự tương đương self-check. Chưa xác minh chương trình K21, giải thích thuật ngữ và flow người mới. S06 có thể liên quan về sau khi có điểm, chưa tính ở tình huống này. |
| P03 Minh Tuấn | **5**: S04/S05/S06/S07/S01 | Học lại/GPA → S05/S06/S01, metric/entry card; mô phỏng/tư vấn → S04/S05/S07, goal fields/chat | Local-only chưa được đáp ứng chỉ nhờ có màn: source có Firestore và ảnh/chat đi backend. Cần nghiệm thu chính sách dữ liệu, quy chế và chương trình K18. |
| P04 Giảng viên | **6**: S08/S03/S04/S05/S06/S02 | Curriculum → Subject → Chat → S08/S03/S04, navigation/source card; kiểm phép tính → S05/S06, metric/entry fields; kiểm mạng lưới → S02, graph/course card | Cần nguồn kiểm chứng, dữ liệu mẫu và desktop test; persona này không tự tạo quyền Admin. |

Đây là **mapping mục tiêu thiết kế theo source**, không phải kết quả Figma hay phần trăm đáp ứng. Component dùng chung có thể phục vụ nhiều persona, nhưng chỉ tính đạt khi hoàn tất được task của persona đó.

### Bộ nhu cầu ban đầu để làm mẫu số

- P01 (5): xác định tiến độ/còn lại; chọn môn đủ tiên quyết; tính GPA/mục tiêu; cập nhật trạng thái/kết quả; nhận tư vấn bám chương trình.
- P02 (5): bắt đầu khi chưa có điểm/self-check; hiểu PE/FE và tín chỉ; xem toàn chương trình đúng khóa; tìm môn PE và cách học; hiểu tiến độ cá nhân.
- P03 (4): phân biệt học lại/cải thiện; đánh giá mục tiêu GPA; ưu tiên môn nợ; bảo đảm chính sách local-only đã yêu cầu.
- P04 (3): kiểm luồng chương trình–môn–chat có nguồn; đối chiếu phép tính nhiều lần học; đánh giá thao tác/bố cục desktop.

Mỗi nhu cầu phải có acceptance criteria và task kiểm trước khi chấm. **Coverage đã kiểm chứng = số nhu cầu pass / tổng nhu cầu × 100%.** Đánh dấu từng nhu cầu Pass / Partial / Fail / Not tested; Partial không tính Pass trong chỉ số chính. Luôn ghi riêng Not tested, không gọi đó là thất bại. Hiện chưa đủ kết quả cho bộ task này nên **chưa công bố %**; không suy ra 8/8 màn của P01 là 100% nhu cầu.

## 4. Phiếu UI/UX test để nhóm gom kết quả

Task chung: (T1) đọc tiến độ và số môn còn lại; (T2) chọn môn kỳ tới và giải thích tiên quyết; (T3) bắt đầu khi chưa có điểm; (T4) sửa một dòng OCR sai rồi lưu và đối chiếu GPA; (T5) hỏi theo môn và tìm nguồn; (T6) đổi tab/Back/dialog và tìm đường phục hồi lỗi.

| Người test | Phiên bản/build | Thiết bị/viewport | Persona/task | Pass/Partial/Fail/Not tested | Thời gian | Lần cần giúp | Lỗi quan sát | Ảnh/video | Mức độ |
|---|---|---|---|---|---|---|---|---|---|
| Chưa ghi nhận | — | — | — | Not tested | — | — | — | — | — |

Kiểm thêm 360/390/412 dp, desktop, text scaling, bàn phím đang mở, mạng lỗi, loading/empty, label dài, focus, tương phản và vùng chạm. Đồng đội tự test là internal evaluation; chỉ gọi user usability test khi có người dùng đại diện, ghi phương pháp và kết quả thật. Không gán đồng đội thành người dùng đại diện chỉ vì họ chọn một persona.

Ưu tiên: **(1)** sửa thiếu tín chỉ ảnh hưởng GPA; **(2)** làm rõ hành trình trên Home và đồng bộ S05/S06 với theme; **(3)** board state và mapping vào màn thật; **(4)** test task + prototype chậm, gom evidence; **(5)** cập nhật slide bằng kết quả đã kiểm.

## 5. Kiểm tra thực hiện trong lượt review

- `git diff --check`: pass; Git có cảnh báo chuyển LF → CRLF, không phải lỗi whitespace.
- `python -m unittest backend.tests.test_grade_import_fallback_unittest`: **3 tests pass**; dùng mock, không chứng minh OCR/Groq thật.
- `flutter test test/transcript_manual_entry_test.dart test/grade_import_test.dart test/transcript_import_view_model_test.dart test/learning_progress_test.dart`: **15 tests pass**. Có một widget case kích thước 390×844; không thay thế visual QA toàn app hay 360/412 dp.
- `flutter analyze`: **pass, No issues found** (32,6 giây).

Lượt này không sửa source sản phẩm, không stage/commit/push và không tuyên bố feedback đã được giải quyết.
