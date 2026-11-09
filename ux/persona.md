# User personas cho FLM Student Assistant

**Cập nhật 27/10:** [Matrix persona → nhu cầu → màn/component → task và cách tính coverage](../docs/ux-feedback-validation.md). Phạm vi production hiện đã chọn Firestore theo `docs/requirements-cloud-amendment.md`; điều này không có nghĩa nhu cầu local-only của P03 đã được đáp ứng. Những đoạn “chưa chốt” bên dưới mô tả mâu thuẫn ở đầu vào persona, không thay thế quyết định cloud hiện tại.

Nguồn: người dùng cung cấp `PRM393 User Persona.pptx` tại thư mục Lab1 ngày 21/10/2026, gồm 4 slide. Nội dung này thay bản P01 “Minh, 20 tuổi, mobile” do Codex giả định trước đây.

**Trạng thái: User-provided / Reported.** Slide không kèm phương pháp nghiên cứu, số người tham gia hoặc bản ghi phỏng vấn. Không tự coi persona đã được nghiên cứu/kiểm chứng. Tên, tuổi, địa điểm là nội dung slide, không phải thông tin cá nhân đã xác minh. Các suy ra cho thiết kế bên dưới chưa phải kết quả user test.

## P01 Hoàng Nam, Primary Persona

Nguồn: slide 1.

| Trường | Nội dung từ persona |
|---|---|
| Identity | Hoàng Nam, 21 tuổi, TP.HCM; FPT SE K19 |
| Giai đoạn | Năm 3, chuẩn bị kỳ làm đồ án |
| Bối cảnh | Đầu kỳ, trước đăng ký môn/học vượt/trả nợ; laptop/desktop tại nhà hoặc lab |
| Mục tiêu | Ưu tiên môn để không nghẽn chuỗi tiên quyết; biết tín chỉ và điểm trung bình cần đạt để hướng tới loại Giỏi; tự quản lý trạng thái môn |
| Pain points | FLM/FAP rời rạc, quan hệ môn thiếu trực quan; PDF/ảnh điểm khó theo dõi, tính GPA tay dễ sai; lời khuyên bạn/AI không bám chương trình riêng |
| Hành vi | Tự lập kế hoạch, dùng Notion/Obsidian, thường hỏi AI, có nhu cầu học nhóm ôn PE |
| JTBD | Xem mạng lưới môn và tính GPA tự động để phân bổ ôn PE/FE, hoàn thành chương trình theo mục tiêu |

**Suy ra cho thiết kế:** ưu tiên mạng lưới môn, danh sách/chi tiết và chat ngữ cảnh; GPA tính bằng code. Desktop cần bố cục rộng, hover/focus và bàn phím; mobile cần danh sách rõ và mở chi tiết theo từng bước. Không tự đổi đề Android thành desktop-only.

## P02 Thu Trang, Secondary Persona 1

Nguồn: slide 2.

- 19 tuổi, Cần Thơ, FPT SE K21; vừa qua tiếng Anh dự bị, chuẩn bị kỳ chuyên ngành 1.
- Chưa có bảng điểm; cần self-check thủ công, xem toàn cảnh 9 học kỳ như slide mô tả, lọc môn PE, hỏi cách học PRF192/CEA201 và xem tiến độ.
- Chưa hiểu PE/FE, tín chỉ tích lũy/tín chỉ GPA; khó đọc khung chương trình scan và bị ảnh hưởng bởi lời đồn tỷ lệ rớt thiếu bằng chứng.

**Suy ra:** empty state có Tự check/Nhập tay và giải thích thuật ngữ. Tách dự định/trạng thái tự khai với điểm đã xác nhận, không tính GPA từ một dấu tick. Danh mục BIT_SE_K19B hiện tại không tự động áp dụng cho K21; phải xác minh curriculum trước khi tư vấn.

## P03 Minh Tuấn, Secondary Persona 2

Nguồn: slide 3.

- 22 tuổi, TP.HCM, FPT SE K18; giai đoạn cuối, từng rớt một môn đại cương và một môn code cơ sở.
- Cần phân biệt học lại/học cải thiện, đánh giá mục tiêu GPA có khả thi không, lọc môn cần trả nợ và ưu tiên phục hồi.
- Lo về hạ bậc bằng, muốn giải thích có căn cứ và số liệu mô phỏng.
- **Ràng buộc từ slide:** bảng điểm phải lưu local, không muốn điểm cá nhân lên server.

**Suy ra:** GPA/điểm cần đạt tính bằng thuật toán; lịch sử từng lần học và quy chế có nguồn. Không lấy lời kể persona làm quy chế chính thức hoặc tự gán ngưỡng hạ bậc. K18 cần curriculum/quy chế phù hợp.

**Xung đột với Final:** đề yêu cầu dữ liệu Firestore, còn P03 yêu cầu local-only. Không tự chuyển điểm lên cloud hoặc coi đã có đồng ý. Cần thống nhất phạm vi với giảng viên/chủ sản phẩm. Phương án giữ điểm chi tiết local, đưa dữ liệu công khai/quy trình cross-role lên cloud mới là đề xuất; chưa được duyệt, chưa khẳng định đáp ứng “all data on Firestore”.

**Ảnh hưởng app hiện tại:** import ảnh gửi ảnh tới backend; chat có thể gửi GPA/dữ kiện học tập tới LLM. “Lưu local” không có nghĩa “không truyền lên server”. Cần thông báo trước và đường nhập tay/local-only nếu muốn đáp ứng P03; chưa có xác nhận chấp thuận truyền dữ liệu.

## P04 Giảng viên, Supporting Persona

Nguồn: slide 4, tên hiển thị “Giáo làng”, 42 tuổi, Dĩ An; giảng viên CNTT/trưởng bộ môn SE, hơn 15 năm kinh nghiệm theo slide.

- Kiểm tra luồng Curriculum → Subject → Contextual Chat, RAG động và câu trả lời có căn cứ.
- Dùng bảng điểm nhiều lần học để kiểm tra GPA; yêu cầu thuật toán thay vì LLM tự tính.
- Đánh giá desktop: chữ dễ đọc, hover rõ, bố cục gọn và không lỗi hiển thị.

**Suy ra:** có đường demo và nguồn để kiểm chứng phép tính/câu trả lời. Supporting Persona không tự động là vai trò Admin/Staff của Final; quyền nghiệp vụ cần đặc tả riêng.

## Problem statement

Sinh viên cần kết hợp chương trình đúng khóa, quan hệ tiên quyết, trạng thái môn và điểm đã xác nhận để lập kế hoạch. Dữ liệu rời rạc và lời khuyên thiếu nguồn khiến họ khó biết môn cần ưu tiên và mục tiêu điểm có khả thi không. Primary Persona ưu tiên desktop; đề PRM393 vẫn yêu cầu Android nên cần bố cục đáp ứng cả hai.

## Persona và flow

| Flow | Persona | Điều chỉnh cần giữ |
|---|---|---|
| F01 Tiến độ → môn kỳ tới → tiên quyết | P01; nhánh P02 chưa có điểm | Nhập tay/self-check; tách dự định với kết quả; không kết luận từ dữ liệu thiếu |
| F02 Chương trình → môn → tư vấn theo mục tiêu | P01, P02; P04 kiểm tra | Đúng khóa; giữ Curriculum → Subject → Contextual Chat, nguồn và giới hạn |
| F03 Import lỗi → xác nhận → lưu → tư vấn/lịch sử | P01, P03 | Có nhập tay và thông báo truyền dữ liệu; P03 cần quyết định local-only trước khi gửi |

## Chỉ số thành công đề xuất, chưa đo

- P01 chọn được ít nhất một môn kỳ tới và giải thích đúng chuỗi tiên quyết theo curriculum, không cần hướng dẫn; đo thời gian/lỗi/lần cần trợ giúp.
- P02 phân biệt self-check với kết quả đã xác nhận, mở được giải thích PE/FE; không có GPA giả khi thiếu điểm.
- P03 phân biệt học lại/học cải thiện từ quy chế có nguồn và hiểu dữ liệu nào lưu local, dữ liệu nào gửi đi.
- P04 kiểm tra được một phép tính GPA và một câu trả lời có nguồn; HTTP thành công không chứng minh nội dung đúng.

Đây là tiêu chí kiểm chứng đề xuất của dự án, không phải kết quả nghiên cứu hoặc số đo trong slide.
