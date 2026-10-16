# BẰNG CHỨNG KIỂM THỬ GIAO TIẾP FLUTTER APP -> BACKEND API

**Thời gian:** 2026-10-17 00:29:29.145983
**Target URL:** `http://127.0.0.1:8000`
**Service:** `ChatApiService` (Package: `flm_courses`)

## 1. Test Ca 1: Tư vấn lộ trình Kỳ 5 & GPA 7.4 -> 8.0
- **Thời gian phản hồi:** `4826ms`
- **Lỗi:** `None`
- **Tài liệu trích dẫn:** `SWP391.md (Đề Cương Chi Tiết & Công Cụ Học Tập SWP391), SWP391.md (Mục Tiêu Môn Học & Chuẩn Đầu Ra SWP391 (LOs)), SWP391.md (Điều Kiện Tiên Quyết & Lộ Trình Học SWP391), SWP391.md (Hình Thức Thi & Cấu Trúc Đánh Giá SWP391 (PE/FE))`

### Câu trả lời nhận được tại Flutter:
Chào em, anh đọc kỹ hồ sơ của em rồi. Trước khi đi vào chiến thuật, anh phải "nói thẳng" với em một con số rất quan trọng để em tỉnh táo:

**Em đang ở trong vùng nguy hiểm đỏ.**

1. **Khoảng cách GPA:** Em đang có **7.4**, mục tiêu **8.0** (loại Giỏi).
2. **Yêu cầu điểm trung bình còn lại:** Hệ thống tính ra em cần đạt trung bình **8.45** ở các môn còn lại. Đây là mức điểm rất cao, gần như yêu cầu em phải đạt điểm 8.5 - 9.0 ở hầu hết các môn còn lại, đặc biệt là các môn nặng tín chỉ.
3. **Cảnh báo hạ bậc (Quan trọng nhất):** Em đã từng **học lại 1 môn**. Theo quy chế FLM, nếu em **học lại thêm 1 môn nữa** (tổng cộng 2 môn), em sẽ **bị hạ 1 bậc** khi xếp loại tốt nghiệp. Nghĩa là dù GPA em có đạt 8.0 hay 9.0, em cũng chỉ nhận bằng **Khá** (vì bị hạ từ Giỏi xuống Khá).

**Kết luận chiến lược tổng quát:**
Mục tiêu tối thượng của em không phải là "săn điểm 10" hay "săn điểm 9", mà là **TUYỆT ĐỐI KHÔNG TRƯỢT MÔN NÀO NỮA** và **đạt điểm cao nhất có thể** ở SWP391 và PRN212 để kéo GPA lên 8.0. Nếu em trượt thêm 1 môn, mọi nỗ lực săn GPA 8.0 đều vô nghĩa vì em sẽ bị khóa ở loại Khá.

Dưới đây là chiến lược thực chiến cho 2 môn "gánh nặng" của kỳ 5: SWP391 và PRN212.

---

### 1. Phân tích SWP391 (Dự án phát triển phần mềm) - Môn "Sống Còn"

SWP391 là môn đồ án lớn, chiếm tỷ trọng điểm rất cao và là yếu tố quyết định GPA kỳ này.

**Cấu trúc điểm (Cần nắm chắc để "lấy điểm" đúng chỗ):**
* **Milestone 1 (Tuần 3):** 15% (Yêu cầu: Phân tích yêu cầu & Thiết kế).
* **Milestone 2 (Tuần 8):** 20% (Yêu cầu: Triển khai Workflow 1 & 2).
* **Milestone 3 (Tuần 10):** 25% (Yêu cầu: Hoàn thiện hệ thống & Kiểm thử).
* **Thi Cuối kỳ (Final Presentation):** 40% (Yêu cầu: Trình bày, Demo, Trả lời câu hỏi).

**Chiến lược thực chiến cho SWP391:**

* **Nguyên tắc vàng:** "Hoàn thành 2 workflow chính" là điều kiện bắt buộc để được thi cuối kỳ. Nếu không hoàn thành, em trượt ngay lập tức, không có cơ hội học lại (hoặc nếu có, em sẽ dính vào cảnh báo hạ bậc).
* **Chọn đề tài & Stack công nghệ:**
 * Đừng chọn đề tài quá mới lạ hoặc stack công nghệ mà cả nhóm chưa ai rành.
 * **Khuyến nghị:** Chọn stack phổ biến, tài liệu nhiều, dễ tìm code mẫu (Java Spring Boot + MySQL hoặc .NET Core + SQL Server). Điều này giúp em và nhóm tiết kiệm thời gian debug, tập trung vào logic nghiệp vụ.
 * **Vai trò:** Em nên đảm nhận vai trò **Backend Developer** hoặc **Tech Lead**. Vì điểm số dựa trên "contribution score" (đóng góp code, task tracking). Nếu em làm Backend, em dễ kiểm soát được code contribution trên GitHub (commit rõ ràng, code review). Nếu làm Frontend, đôi khi code bị coi là "dễ" hơn trong mắt giảng viên nếu không có logic phức tạp.
* **Quản lý tiến độ theo Milestone:**
 * **Tuần 1-3 (M1 - 15%):** Tập trung 100% vào tài liệu. Sử dụng AI (ChatGPT/Gemini) để hỗ trợ viết User Requirements, tạo ERD, UML. **Đừng tự viết tay từ đầu.** Hãy để AI gợi ý khung, em chỉnh sửa cho khớp đề tài. Điểm M1 chủ yếu nằm ở sự logic của tài liệu và khả năng trình bày slide.
 * **Tuần 4-8 (M2 - 20%):** Đây là giai đoạn code nặng nhất.
 * **Tuần 4-5:** Xây dựng Database Schema và API cơ bản (CRUD).
 * **Tuần 6-7:** Triển khai 2 Workflow chính (Data Initiation và Core Functions). **Lưu ý:** "Core Functions" phải là tính năng cốt lõi của đề tài, không phải tính năng phụ.
 * **Tuần 8:** Chốt code, chạy thử nghiệm nội bộ. Đảm bảo 2 workflow chạy thông suốt.
 * **Tuần 9-10 (M3 - 25%):** Kiểm thử (Testing) và hoàn thiện UI/UX.
 * Viết Unit Test/Integration Test (JUnit/NUnit). Giảng viên rất thích thấy bằng chứng kiểm thử.
 * Deploy lên môi trường staging (Heroku/AWS/Vercel). Một link demo chạy được trên cloud sẽ tăng điểm cảm tình rất nhiều.
* **Thi Cuối kỳ (40%):**
 * **Điều kiện tiên quyết:** Điểm trung bình quá trình (M1+M2+M3) phải >= 5/10. Với chiến lược trên, em sẽ dễ dàng đạt 7-8 điểm quá trình, nên an toàn.
 * **Trình bày:** 60 phút cho cả nhóm. Mỗi thành viên cần chuẩn bị phần riêng. Em nên chuẩn bị phần **Architecture & Database Design** hoặc **Key Technical Challenges**. Đây là phần thể hiện tư duy kỹ thuật, dễ ăn điểm cao.
 * **Trả lời câu hỏi:** Giảng viên sẽ hỏi sâu về cách em xử lý lỗi, cách tối ưu query, hoặc lý do chọn công nghệ X. Hãy chuẩn bị sẵn các câu trả lời dựa trên tài liệu đã viết.

**Mẹo "ăn điểm" SWP391:**
* **Git Commit:** Commit code thường xuyên, message rõ ràng. Đây là bằng chứng đóng góp.
* **AI Usage:** Sử dụng AI một cách "trách nhiệm". Đừng copy-paste nguyên khối. Hãy dùng AI để giải thích code, gợi ý test case, hoặc viết tài liệu. Trong báo cáo, hãy ghi rõ phần nào dùng AI hỗ trợ.
* **Peer Review:** Đảm bảo điểm đóng góp từ các thành viên khác cho em >= 80%. Hãy làm việc nhóm chuyên nghiệp, hỗ trợ nhau, đừng để xảy ra mâu thuẫn.

---

### 2. Phân tích PRN212 (Lập trình nền tảng / Java hoặc C++ tùy khóa)

*Ghi chú: PRN212 thường là môn lập trình nền tảng (Java/C++/C#). Vì em không cung cấp chi tiết đề cương PRN212, anh sẽ tư vấn dựa trên đặc thù chung của các môn lập trình nền tảng tại FPT.*

**Đặc điểm môn PRN212:**
* Thường có **PE (Practical Exam)** hoặc **Lab** chiếm tỷ trọng cao (thường 40-50%).
* Yêu cầu giải thuật, xử lý dữ liệu, OOP.
* Điểm liệt thường là điểm PE < 5 hoặc không nộp bài lab.

**Chiến lược thực chiến cho PRN212:**

* **Tập trung vào PE (Practical Exam):**
 * **Rèn dạng bài:** Hãy tìm đề thi PE các năm trước (hỏi anh chị khóa trên hoặc trên diễn đàn). Các dạng bài thường gặp:
 * Xử lý mảng, chuỗi.
 * OOP: Kế thừa, đa hình, interface.
 * Cấu trúc dữ liệu cơ bản (Stack, Queue, Linked List).
 * SQL cơ bản (nếu môn có liên quan đến DB).
 * **Thói quen code:** Code phải sạch, có comment, tuân thủ naming convention. Giảng viên thường trừ điểm nếu code "rác".
 * **Thời gian:** PE thường có thời gian giới hạn (ví dụ 90-120 phút). Hãy luyện tập giải bài trong thời gian giới hạn. Đừng cố làm bài khó nếu chưa chắc chắn, hãy làm chắc bài dễ để lấy điểm tối đa.
* **Lab & Bài tập:**
 * Nộp đầy đủ, đúng hạn.
 * Nếu có bài lab nhóm, hãy đảm bảo đóng góp rõ ràng.
* **Thi Lý thuyết (FE):**
 * Ôn tập các khái niệm OOP, thiết kế phần mềm, cấu trúc dữ liệu.
 * Làm bài tập trắc nghiệm online nếu có.

**Mẹo "ăn điểm" PRN212:**
* **Code Skeleton:** Khi gặp bài PE khó, hãy viết khung code (skeleton) trước: khai báo biến, hàm, cấu trúc lớp. Sau đó điền logic vào. Điều này giúp em không bị

---

## 2. Test Ca 2: Tư vấn môn học CSD201
- **Thời gian phản hồi:** `75ms`
- **Tài liệu trích dẫn:** `CSD201.md (Dữ liệu môn học FLM)`

### Câu trả lời nhận được tại Flutter:
Theo dữ liệu FLM, CSD201 có thi PE (thực hành).
