# Đối chiếu requirement FLM v7 với code

Ngày kiểm tra: 2026-10-12. Nhánh: `PRM-LAB2-Vuong`. Trạng thái này dựa trên source và các phép thử ghi dưới đây; không thay thế nghiệm thu với ảnh bảng điểm thật và LLM đang chạy.

| Mục v7 | Code / dữ liệu | Kết quả kiểm tra |
| --- | --- | --- |
| 2.1–2.3 FLM Markdown, front matter, curriculum ↔ subject ↔ semester, chuẩn hóa mã | `flm_knowledge_vault/`, `scripts/flm_data.py`, `scripts/enrich_vault_schema.py`, `backend/app/services/flm_parser.py` | Có dữ liệu 48 môn active; parser và API thống kê/tiên quyết trong backend unittest đạt. Chưa chạy lại pipeline trích xuất HTML trong lượt này. |
| 3 Obsidian vault và liên kết | `flm_knowledge_vault/`, `flm_knowledge_vault/.obsidian/` | Vault có Markdown và Wikilinks; chưa kiểm tra Graph View trong ứng dụng Obsidian ở lượt này. |
| 4.0 luồng curriculum → học kỳ/map → môn → chat | `flutter_app/lib/pages/curriculum_list_page.dart`, `curriculum_detail_page.dart`, `course_detail_page.dart`, `features/chat/views/widgets/contextual_chat_panel.dart` | Route và scope chat có code; Flutter tests đạt. Chưa thử hết hành vi giữ zoom/pan/scroll sau mọi kiểu điều hướng trên desktop. |
| 4.1 card curriculum | `curriculum_list_page.dart`, `state/course_catalog.dart` | Card đọc dữ liệu JSON. Dữ liệu hiện có chỉ một curriculum; thêm curriculum thứ hai vào JSON rồi chạy xuyên suốt chưa được xác nhận. |
| 4.2 tab curriculum, chat cạnh phải, bảng điểm/chiến lược | `curriculum_detail_page.dart`, `widgets/grade_strategy_panel.dart` | Có 3 tab, khung chat desktop và lối vào nhập/sửa bảng điểm trong khu vực chiến lược. |
| 4.3 Map Obsidian động | `features/graph/views/graph_view_screen.dart` | Node/cạnh lấy từ môn và tiên quyết; có mô phỏng lực, kéo, bố cục kỳ, zoom/pan, hover/chọn, local graph 1–3 cấp, tìm/lọc, mũi tên, modal, legend và bộ chỉnh lực/độ dày/kích thước. Phân tích Dart đạt. Chưa đo FPS, chưa kiểm tra từng thao tác kéo/pan trên desktop; tùy chọn node học kỳ chưa có. |
| 4.4 chi tiết môn | `course_detail_page.dart` | Có syllabus, đánh giá, learning outcomes, tiên quyết, appears_in, chat và tư vấn. Đã sửa overflow ở hàng header trên Android; cần xem lại sau APK cuối. |
| 4.5 board học kỳ | `curriculum_detail_page.dart` | Học kỳ lấy từ dữ liệu, board ngang desktop/danh sách dọc mobile, chip nhảy kỳ, GPA kỳ, tìm/lọc, modal trước khi vào chi tiết, đồng bộ môn chọn với Map. Chưa đo độ mượt/cuộn và hover trên desktop. |
| 5.1–5.2 chat hai scope và câu hỏi mẫu | `backend/app/services/rag_engine.py`, `curriculum_facts.py`, `flutter_app/lib/features/chat/` | Fact tín chỉ, PE, CLO, học kỳ, xuất hiện trong và tiên quyết lấy từ dữ liệu có cấu trúc; các test mẫu tương ứng đạt. Scope/id được truyền trong request. |
| 5.3–5.4 tư vấn RAG động | `backend/app/services/study_planner.py`, `rag_engine.py`, `llm_service.py`, `features/chat/` | Code ghép dữ kiện sinh viên và FLM, lịch sử chat theo scope được lưu local. Các ca tư vấn cần LLM chưa đạt khi model text khai báo trong `.env` không có trong Ollama; không coi lỗi model là bằng chứng logic tư vấn đúng. |
| 6 GPA, loại trừ, học lại, xếp loại, mục tiêu | `grading_rules.yaml`, `flutter_app/assets/grading_rules.yaml`, `flutter_app/lib/services/grade_calculator.dart`, `state/transcript_provider.dart` | Flutter đọc bản YAML đồng bộ vào assets bằng `scripts/sync_grading_rules.py`; test retake/improvement, tín chỉ còn lại bằng 0, và dòng đang học không ảnh hưởng GPA đạt. Các nhánh cấu hình quy chế khác giá trị hiện tại chưa được thử. |
| 7.1 ảnh nhiều dạng → Vision → xác nhận/sửa → lưu | `backend/app/api/v1/endpoints/grade_import.py`, `flutter_app/lib/screens/transcript_screen.dart`, `transcript_confirm_screen.dart` | Vision là đường chính; OCR/text là dự phòng. Có nhiều ảnh, normalize, dedup, cảnh báo confidence/mã không khớp, nhập/sửa tay, lưu local. Test mock Vision đạt. Luồng nhập tay PRM393 8,5 → lưu → mở lại → xóa môn cuối có xác nhận → mở lại đã đạt trên Android. **Chưa thử bằng ảnh bảng điểm thật**, nhất là ảnh nghiêng/mờ/nhiều kỳ. |
| 7.2–7.4 tư vấn môn/kỳ/toàn lộ trình | `grade_strategy_panel.dart`, `study_planner.py`, `chat_provider.dart` | Có nút tư vấn theo phạm vi, GPA và lộ trình tính bằng code, câu trả lời giữ trong lịch sử chat scope. Chất lượng lời khuyên chưa thể nghiệm thu khi text LLM chưa chạy ổn định. |
| 8.1–8.2 Flutter/FastAPI/REST và riêng tư | `flutter_app/lib/services/grade_import_service.dart`, `backend/app/api/v1/endpoints/grade_import.py`, `state/transcript_provider.dart` | Ảnh xử lý trong RAM backend, bảng điểm lưu SharedPreferences trên thiết bị, màn nhập ảnh có thông báo gửi ảnh. Cần thử API và luồng Android với ảnh thật. |
| 8.3 mở rộng | `grading_rules.yaml`, `state/course_catalog.dart`, `data/course_repository.dart` | Quy chế có một nguồn YAML cho app và pipeline. Phần thêm curriculum thứ hai chưa được kiểm thử thực tế. |
| 8.4 chất lượng UI | Flutter theme, hover card, Map, các màn | APK mở trên emulator. Chưa có đo kiểm desktop từng màn, kích thước chữ/vùng bấm và đối chiếu pixel với Figma. |

## Phép thử đã chạy

- `flutter test`: 17/17 đạt trước thay đổi xác nhận xóa; test nhập/xóa thủ công đạt 2/2 sau thay đổi. Cần chạy lại toàn bộ sau sửa Map cuối.
- `flutter analyze` các file đã sửa: không có lỗi.
- `flutter build apk --debug`: đạt sau sửa quy chế/header/xóa bảng điểm; APK cài và mở được trên emulator. Cần build lại sau sửa Map cuối.
- Backend unittest trọng điểm: các fact câu hỏi mẫu, OCR/Vision mock và trường hợp mã môn không tồn tại đạt.
- API: health 200; `GET /courses/PRM392` trả 404; chat subject `PRM392` trả câu không xác định từ structured synthesizer.
- Bộ backend tích hợp có các ca LLM thất bại khi `OLLAMA_MODEL=qwen2.5:latest` thiếu; thử `qwen3.8:27b` trả HTTP 500/timeout. Model Vision `qwen2.5vl:3b` đã có; model text đang tải, cần chạy lại sau khi sẵn sàng.

## Bằng chứng còn thiếu

1. Ảnh bảng điểm thật → Vision → xác nhận/sửa → lưu → mở lại app → xóa → mở lại app trên Android. Luồng nhập tay tương ứng đã đạt.
2. Tư vấn RAG động với model text hoạt động, và benchmark câu hỏi ngoài mẫu.
3. Kiểm tra thao tác Map/board/hover ở cửa sổ desktop và đối chiếu chi tiết với Figma.
4. Rubric Figma sáu trang và prompt/output AI là đầu ra riêng; chưa hoàn tất, không tạo bằng chứng giả.
