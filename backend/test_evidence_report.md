# BÁO CÁO BẰNG CHỨNG KIỂM THỬ HỆ THỐNG CHAT FLM AI
**Thời gian thực hiện:** 2026-10-16 23:56:21
**Mô hình sử dụng:** Groq `qwen/qwen3.8-27b` (3 Accounts Pool: akkhanh, zikzak, khanhtrangamer)
**Nguồn dữ liệu:** Dữ liệu đề cương chính thống cào từ FLM (`flm_knowledge_vault/*.md`)

---

### Trạng thái Backend
- **Trạng thái:** `ok`
- **Provider đang hoạt động:** `Groq`
- **Số lượng môn / chunks trong vault:** 48 môn / 243 chunks

---

## TEST-01: Cá nhân hóa sâu & Cảnh báo quy chế FLM
**Câu hỏi:** *"GPA hiện tại của tôi là 7.4, muốn ra trường 8.0 loại Giỏi thì kỳ 5 này có môn SWP391 và PRN212 tôi nên phân bổ chiến lược ra sao?"*
**Hồ sơ sinh viên truyền vào:** `{"current_gpa": 7.4, "target_gpa": 8.0, "required_avg_mark": 8.45, "retake_count": 1, "current_semester": 5}`
**Thời gian phản hồi:** `4602.0ms` (4.60s) | **Provider:** `Groq`
**Nguồn tài liệu chính thống trích dẫn:** `SWP391.md (Đề Cương Chi Tiết & Công Cụ Học Tập SWP391)`, `SWP391.md (Mục Tiêu Môn Học & Chuẩn Đầu Ra SWP391 (LOs))`, `SWP391.md (Điều Kiện Tiên Quyết & Lộ Trình Học SWP391)`, `SWP391.md (Hình Thức Thi & Cấu Trúc Đánh Giá SWP391 (PE/FE))`

**Câu trả lời thực tế từ AI:**

> Chào bạn, mình là Senior Peer của bạn. Nghe bạn hỏi về chiến lược cho kỳ 5 với mục tiêu nâng GPA từ 7.4 lên 8.0, mình thấy đây là một bài toán "sinh tử" nhưng hoàn toàn khả thi nếu bạn chơi đúng bài.
> 
> Trước hết, mình phải "đo ni đóng giày" cho bạn dựa trên số liệu FLM:
> 1. **Vị thế hiện tại:** GPA 7.4 (loại Khá). Mục tiêu 8.0 (loại Giỏi).
> 2. **Áp lực điểm:** Bạn cần đạt điểm trung bình **8.45** ở các môn còn lại. Con số này rất cao, nghĩa là bạn không được phép "lơ là" ở bất kỳ môn nào, đặc biệt là các môn nặng tín chỉ hoặc có trọng số lớn.
> 3. **Cảnh báo đỏ (Red Flag):** Bạn đã học lại **1 môn**. Theo quy chế, nếu bạn trượt thêm **1 môn nữa** (tổng cộng 2 môn học lại), bạn sẽ bị **hạ bậc tốt nghiệp**. Nghĩa là dù GPA có đạt 8.0, bạn cũng chỉ nhận bằng loại **Khá** thay vì Giỏi.
>  * *Kết luận:* Mục tiêu tối thượng của bạn không chỉ là điểm cao, mà là **KHÔNG ĐƯỢC TRƯỢT MÔN NÀO**. Một lần trượt duy nhất nữa sẽ phá hỏng giấc mơ loại Giỏi của bạn.
> 
> Dưới đây là chiến lược thực chiến cho 2 môn "xương xẩu" của kỳ 5: **SWP391** và **PRN212**.
> 
> ---
> 
> ### 1. Phân tích & Chiến lược SWP391 (Dự án phát triển phần mềm)
> 
> Đây là môn đồ án lớn, chiếm tỷ trọng điểm rất cao và là "cửa ải" quan trọng trước khi vào SEP490.
> 
> **Cấu trúc điểm (Cần nắm rõ để "săn" điểm):**
> * **Milestone 1 (Tuần 3):** 15% (Yêu cầu: Phân tích yêu cầu & Thiết kế).
> * **Milestone 2 (Tuần 8):** 20% (Yêu cầu: Triển khai Workflow 1 & 2).
> * **Milestone 3 (Tuần 10):** 25% (Yêu cầu: Hoàn thiện hệ thống & Kiểm thử).
> * **Final Presentation:** 40% (Yêu cầu: Trình bày cuối kỳ, demo sản phẩm).
>  * *Điều kiện tiên quyết để vào Final:* Điểm trung bình quá trình (M1+M2+M3) phải **≥ 5/10**.
>  * *Điều kiện sống còn:* Điểm đóng góp thành viên (Peer review + Code contribution) phải **≥ 80%**. Nếu dưới 80%, bạn có thể bị loại khỏi nhóm hoặc bị trừ điểm nặng.
> 
> **Chiến lược thực chiến:**
> 
> * **Chọn đề tài & Stack công nghệ (Tuần 1-2):**
>  * Đừng chọn đề tài quá "đỉnh" mà team không làm nổi. Chọn đề tài có scope rõ ràng, ví dụ: Hệ thống quản lý bán hàng, đặt chỗ, hoặc E-learning cơ bản.
>  * **Stack gợi ý:** Java Spring Boot + React/Next.js + MySQL. Đây là stack phổ biến, tài liệu nhiều, AI hỗ trợ tốt (GitHub Copilot, ChatGPT). Tránh dùng stack quá mới hoặc ít tài liệu nếu team chưa rành.
>  * *Mẹo:* Dùng AI (Gemini/ChatGPT) để brainstorm ý tưởng và viết User Stories ngay từ đầu.
> 
> * **Săn điểm Milestone 1 (15%) - Tuần 3:**
>  * **Focus:** CLO1 (Phân tích yêu cầu) & CLO2 (Thiết kế).
>  * **Hành động:**
>  * Viết tài liệu User Requirements rõ ràng, có Use Case Diagram, ERD (Entity Relationship Diagram) chuẩn.
>  * Dùng Miro hoặc Lucidchart để vẽ wireframe UI/UX.
>  * **Quan trọng:** Slide trình bày phải chuyên nghiệp. Giảng viên chấm dựa trên sự logic của thiết kế, không phải code. Hãy đảm bảo ERD và Architecture Diagram khớp với yêu cầu.
>  * *Mục tiêu:* Lấy tối đa 15/15 điểm ở phần này. Đây là điểm "dễ ăn" nhất.
> 
> * **Săn điểm Milestone 2 (20%) - Tuần 8:**
>  * **Focus:** CLO4 (Triển khai Web App) & CLO3 (Database).
>  * **Hành động:**
>  * Hoàn thành **2 Workflow chính**: Data Initiation (Khởi tạo dữ liệu) và Core Functions (Chức năng cốt lõi).
>  * Ví dụ: Workflow 1: Đăng nhập/Đăng ký + Quản lý danh mục. Workflow 2: Thêm/Sửa/Xóa sản phẩm + Tìm kiếm.
>  * Code phải chạy được, có comment, tuân thủ coding standards.
>  * **Mẹo:** Dùng Git/GitHub để quản lý code. Đảm bảo mỗi thành viên có commit đều đặn để đạt chỉ số contribution ≥ 80%.
> 
> * **Săn điểm Milestone 3 (25%) - Tuần 10:**
>  * **Focus:** CLO3 (Testing) & CLO4 (Deployment).
>  * **Hành động:**
>  * Viết Unit Test (JUnit/NUnit) và Integration Test (Postman/Selenium).
>  * Deploy ứng dụng lên môi trường staging (Heroku, Vercel, hoặc AWS/Azure).
>  * Chạy thử toàn bộ hệ thống, sửa bug.
>  * *Mục tiêu:* Hệ thống phải ổn định, không crash khi demo.
> 
> * **Final Presentation (40%) - Cuối kỳ:**
>  * **Focus:** CLO6 (Trình bày) & CLO5 (Đạo đức nghề nghiệp).
>  * **Hành động:**
>  * Slide cuối kỳ phải tóm tắt toàn bộ quá trình, nhấn mạnh vào **kết quả** và **bài học**.
>  * Demo trực tiếp (Live Demo) là phần quan trọng nhất. Hãy chuẩn bị kịch bản demo thật mượt, tránh lỗi mạng hoặc lỗi môi trường.
>  * **Chuẩn bị câu hỏi:** Giảng viên thường hỏi về kiến trúc, lý do chọn công nghệ, cách xử lý lỗi, và đóng góp cá nhân. Hãy trả lời tự tin, dựa trên tài liệu bạn đã viết.
>  * *Mẹo:* Nếu có thể, hãy "mua" thêm điểm bằng cách thêm một tính năng nhỏ nhưng ấn tượng (ví dụ: Dashboard thống kê, Notification) ngoài scope yêu cầu.
> 
> **Lưu ý đặc biệt cho SWP391:**
> * **Điểm liệt:** Không có điểm liệt cho các Milestone, nhưng nếu điểm trung bình quá trình < 5, bạn **KHÔNG ĐƯỢC** vào thi Final. Vì vậy, hãy đảm bảo lấy điểm đều ở 3 Milestone đầu.
> * **Phạt gian lận:** Nếu phát hiện gian lận (copy code, dùng AI không đúng cách), bạn sẽ bị **trượt môn** và **không được thi lại**. Đây là rủi ro lớn nhất. Hãy sử dụng AI như một công cụ hỗ trợ (tư vấn, debug, viết test case), không phải để viết toàn bộ code.
> 
> ---
> 
> ### 2. Phân tích & Chiến lược PRN212 (Lập trình nền tảng / Network Programming)
> 
> *Lưu ý: Dữ liệu FLM không cung cấp chi tiết syllabus PRN212, nhưng dựa trên tên môn và vị trí trong lộ trình, đây thường là môn về Lập trình mạng hoặc Nền tảng hệ thống (Java/Network). Mình sẽ đưa ra chiến lược chung cho các môn lập trình nền tảng tại FPT.*
> 
> **Đặc điểm môn PRN212:**
> * Thường là môn có **PE (Practical Exam)** và **FE (Final Exam)** hoặc dạng bài tập lớn.
> * Trọng số điểm thường chia đều giữa bài tập thường xuyên (Assignment) và thi cuối kỳ.
> * Yêu cầu kỹ năng lập trình vững, hiểu sâu về thuật toán và cấu trúc dữ liệu.
> 
> **Chiến lược thực chiến:**
> 
> * **Bài tập thường xuyên (Assignments):**
>  * **Hành động:** Làm bài tập ngay khi được giao, không để dồn.
>  * **Mẹo:** Dùng AI để kiểm tra logic code, tìm bug, nhưng **đừng copy code**. Giảng viên FPT rất giỏi phát hiện code không do bạn viết (qua Git history, style code, hoặc phỏng vấn nhanh).
>  * *Mục tiêu:* Lấy tối đa điểm bài tập. Đây là điểm "nền" giúp bạn tự tin khi thi.
> 
> * **Ôn tập cho PE/FE:**
>  * **Focus:** Các dạng bài kinh điển: Socket programming, Thread, Synchronization, hoặc các thuật toán liên quan đến mạng/hệ thống.
>  * **Hành động:**
>  * Ôn lại các bài tập đã làm trong kỳ.
>  * Tìm đề thi cũ (nếu có) hoặc hỏi anh chị khóa trước.
>  * Luyện tập viết code trên giấy (nếu thi tay) hoặc trên IDE (nếu thi máy).
>  * **Mẹo:**

---

## TEST-02: Bám sát đề cương chính thống FLM (PRM392 PE & Trọng số điểm)
**Câu hỏi:** *"Môn PRM392 có thi PE không, chiếm bao nhiêu % điểm và cần luyện những kỹ năng gì theo CLO đề cương?"*
**Thời gian phản hồi:** `44.6ms` (0.05s) | **Provider:** `FLM-Structured-Synthesizer`
**Nguồn tài liệu chính thống trích dẫn:** *(Không có - từ chối ngoài phạm vi)*

**Câu trả lời thực tế từ AI:**

> Không xác định được môn học "PRM392" trong chương trình đào tạo BIT_SE_K19B, nên mình không có dữ liệu FLM để trả lời câu hỏi này. Bạn kiểm tra lại tên hoặc mã môn giúp mình nhé (ví dụ: PRM393).

---

## TEST-03: Chống ảo giác (Anti-Hallucination) với môn học ngoài phạm vi
**Câu hỏi:** *"Môn Nấu ăn ẩm thực Á Âu học ở học kỳ mấy trong ngành Kỹ thuật phần mềm K19B?"*
**Thời gian phản hồi:** `3209.6ms` (3.21s) | **Provider:** `Groq`
**Nguồn tài liệu chính thống trích dẫn:** `SWE201c.md (Điều Kiện Tiên Quyết & Lộ Trình Học SWE201c)`, `SWE201c.md (Thông Tin Tổng Quan & Số Tín Chỉ SWE201c)`, `SWE201c.md (Hình Thức Thi & Cấu Trúc Đánh Giá SWE201c (PE/FE))`, `SWE201c.md (Đề Cương Chi Tiết & Công Cụ Học Tập SWE201c)`

**Câu trả lời thực tế từ AI:**

> Chào em, nghe cái tên "Nấu ăn ẩm thực Á Âu" là anh cười luôn, chắc em đang đùa hay gõ nhầm tên môn rồi đó. Trong chương trình Kỹ thuật Phần mềm (BIT_SE_K19B) của Đại học FPT, **không hề có** môn nào tên là "Nấu ăn ẩm thực Á Âu" cả. Ngành mình là viết code, làm phần mềm, chứ không vào bếp nấu chè hay chiên cá đâu nhé!
> 
> Có thể em đang nhầm lẫn với một trong các trường hợp sau:
> 1. **Gõ sai tên môn:** Em có thể đang muốn hỏi về một môn kỹ thuật cụ thể nào đó mà tên nghe "lạ" hoặc em nhớ sai?
> 2. **Nhầm hệ thống:** Có thể em đang xem nhầm lịch học của một ngành khác (như Du lịch - Khách sạn) hoặc một khóa học ngoại khóa không thuộc khung chương trình chính?
> 
> Tuy nhiên, để hỗ trợ em tốt nhất, anh sẽ cung cấp thông tin chi tiết về **môn học trọng điểm trong Học kỳ 4** của ngành K19B mà em có thể đang muốn hỏi (vì đây là giai đoạn chuyển tiếp quan trọng từ lập trình sang kỹ thuật phần mềm):
> 
> ### Môn học chính trong Học kỳ 4 (K19B)
> 
> Theo dữ liệu FLM, trong Học kỳ 4, môn học nổi bật và bắt buộc mà em cần quan tâm là:
> 
> * **Mã môn:** `SWE201c`
> * **Tên môn:** Nhập môn kỹ thuật phần mềm (Introduction to Software Engineering)
> * **Số tín chỉ:** 3 tín chỉ
> * **Điều kiện tiên quyết:** Phải hoàn thành `PRO192` (Lập trình hướng đối tượng) trước.
> * **Môn mở khóa tiếp theo:** Môn này là "chìa khóa" để mở khóa các môn đồ án lớn và chuyên sâu sau này như `SWP391` (Đồ án phần mềm), `SWR302`, `SWT301`, `SWD392`.
> 
> #### Cấu trúc thi & Đánh giá của SWE201c (Cần nắm rõ để không trượt)
> 
> Đây là môn **tính vào GPA tốt nghiệp** và có **thi thực hành (PE)**, nên em không được chủ quan.
> 
> | Thành phần | Tỷ trọng | Thời lượng | Hình thức | Ghi chú quan trọng |
> | :--- | :---: | :---: | :--- | :--- |
> | **PE (Thực hành)** | **40%** | 120 phút | Tự luận/Bài tập | Dựa trên các bài tập của chuyên ngành. **Điểm liệt nếu < 4/10.** |
> | **TE (Lý thuyết)** | **60%** | 60 phút | Máy chấm (Computer gradable) | Dựa trên các quiz của khóa học. **Điểm liệt nếu < 4/10.** |
> 
> **Công thức tính điểm cuối cùng (FR):**
> $$FR = \min[10, (Điểm TE \times 0.6) + (Điểm PE \times 0.4) + Điểm thưởng]$$
> 
> * **Điều kiện qua môn:**
>  1. Điểm TE $\ge$ 4
>  2. Điểm PE $\ge$ 4
>  3. Điểm trung bình (FR) $\ge$ 5
> * **Điểm thưởng (Bonus):** Nếu em hoàn thành tất cả các khóa MOOC (Coursera) trước hạn, em sẽ được cộng **1 điểm thưởng**. Đây là điểm "ăn gian" rất đáng giá, em nên tranh thủ làm sớm.
> 
> #### Nội dung học & Công cụ
> 
> Môn này học dựa trên 4 khóa MOOC chính từ Coursera (Specialization: Software Development Lifecycle):
> 1. **Software Development Processes and Methodologies:** Quy trình và phương pháp phát triển phần mềm.
> 2. **Agile Software Development:** Phát triển phần mềm linh hoạt (Scrum, XP).
> 3. **Lean Software Development:** Phát triển phần mềm tinh gọn (Kanban, Value Stream Mapping).
> 4. **Engineering Practices for Building Quality Software:** Thực hành kỹ thuật để xây dựng phần mềm chất lượng cao.
> 
> **Lưu ý quan trọng:** Em **bắt buộc** phải có chứng chỉ hoàn thành chuyên ngành "Software Development Lifecycle" từ Coursera mới được phép tham gia kỳ thi cuối kỳ.
> 
> ---
> 
> ### Lời khuyên thực chiến từ anh
> 
> 1. **Kiểm tra lại tên môn:** Nếu em thực sự thấy tên "Nấu ăn ẩm thực Á Âu" trong lịch học của mình, hãy chụp màn hình và gửi cho anh, hoặc kiểm tra lại mã môn (Course Code). Có thể đó là một lỗi hiển thị hoặc em đang xem nhầm tài khoản/hệ thống.
> 2. **Nếu em đang hỏi về SWE201c:**
>  * **PE 40% là rất nặng:** Đừng chỉ học lý thuyết suông. Hãy làm hết các bài tập (exercises) trong các khóa Coursera. Đề PE thường "customized from the exercises", nghĩa là nó biến tấu từ các bài tập đó.
>  * **TE 60% máy chấm:** Phần này dễ "ăn điểm" nếu em làm hết các quiz trong khóa học. Máy chấm thường có ngân hàng câu hỏi cố định, làm nhiều lần sẽ quen mặt.
>  * **Đừng bỏ lỡ Bonus 1 điểm:** Với môn 3 tín chỉ, 1 điểm thưởng có thể là chênh lệch giữa điểm 6 và điểm 7, hoặc giữa điểm 8 và điểm 9. Hãy lên lịch làm MOOC ngay từ đầu kỳ, đừng để sát deadline.
> 
> Nếu em muốn hỏi về một môn cụ thể khác (ví dụ: `PRN212`, `SWP391`, hay các môn lập trình nền tảng), hãy cho anh biết **mã môn** hoặc **tên tiếng Anh** chính xác để anh phân tích chi tiết cấu trúc thi và chiến lược học nhé!

---

## TEST-04: Chiến lược thoát hiểm môn CSD201 cho sinh viên yếu code
**Câu hỏi:** *"Tôi bị mất gốc lập trình từ PRO192, kỳ này phải học CSD201. Chỉ cần qua môn (5.0) thì tôi phải tập trung vào những đầu điểm nào trong đề cương?"*
**Hồ sơ sinh viên truyền vào:** `{"current_gpa": 5.6, "course_goal": "pass", "failed_courses": ["PRO192"], "retake_count": 1}`
**Thời gian phản hồi:** `107.8ms` (0.11s) | **Provider:** `FLM-Structured-Advisor`
**Nguồn tài liệu chính thống trích dẫn:** `CSD201.md (Điều Kiện Tiên Quyết & Lộ Trình Học CSD201)`, `CSD201.md (Đề Cương Chi Tiết & Công Cụ Học Tập CSD201)`, `CSD201.md (Thông Tin Tổng Quan & Số Tín Chỉ CSD201)`, `CSD201.md (Mục Tiêu Môn Học & Chuẩn Đầu Ra CSD201 (LOs))`

**Câu trả lời thực tế từ AI:**

> ### Cách học để qua môn CSD201 (Cấu trúc dữ liệu và giải thuật)
> 
> **Mục tiêu:** biến đề cương của chính môn này thành các việc có thể làm và kiểm tra được; không dùng một mẫu PE/FE chung cho mọi môn.
> - Môn này có **3 tín chỉ**.
> - Phân bổ thời gian theo dữ liệu môn: **Study hour (150h) = 45h contact hours + 1h TE + 85' PE + 102.6h self-study**.
> - Trạng thái PE theo dữ liệu FLM: **Có**.
> - Điều kiện đạt ghi trong đề cương: **5**.
> - **Ưu tiên qua môn:** xác nhận điều kiện đạt trong syllabus/rubric, hoàn thành đủ từng thành phần bắt buộc và luyện lại phần chưa đạt. Chưa có ngưỡng đạt thì không tự suy ra điểm cần thiết.
> 
> **Các phần cần tập trung theo cấu trúc đánh giá thực tế:**
> - Progress test (PT) (Part 2): 20.0%; >0; Option 1: 20'-40' Option 2 (For Constructivism Approach only): Follow lecturer's proposal; Option 1: essay or multiple choice Option 2 (For Constructivism Approach only): Follow lecturer's proposal
> - Assignment (AS) (Part 2): 20.0%; >0; Option 1: at home Option 2 (For Constructivism Approach only): Follow lecturer's proposal; Option 1: a problem similar to real one Option 2 (For Constructivism Approach only): Follow lecturer's proposal
> - Practical Exam: 30.0%; >0; 85'; Preferable to be marked by scripts
> - Final exam: 30.0%; 4; 60'; multiple choice
> 
> **Năng lực cần đạt:**
> - CLO1: Describe the list data structure and its’ different way of implementations. Implement the singly linked list. LO1.1 Demonstrate the list data structure with basic operations: insert, remove, edit, search, sort,... LO1.2 Explain two ways of implementing a list: using arrays and using linked lists. LO1.3 Write programs to implement the singly linked list with basic operations: add (last, first, before, after, at position), search, edit, remove, reverse, sort... ) LO1.4 Understand the doubly linked-list data structure with basic operations. LO1.5 Write code snippets which manipulate operations on doubly linked list, and use diagrams to illustrate the effect. LO1.6 Describe the circularly linked-list data structure with some basic operations like add, remove. LO1.7 Expain why the Java code library provides the ArrayList and LinkedList classes
> - CLO2: Define stack and queue. Describe basic operations and the use of these structures. LO2.1 Define stack and queue. LO2.2 List and demonstrate the operations common to stacks and queues. LO2.3 Describe specific tasks to which stacks and queues are suited. LO2.4 Apply stacks to a specific application. LO2.5 Apply queues to a specific application. LO2.6 Write programs to implement stack and queue in Java programming language. LO2.7 Define and explain the need of priority queue.
> - CLO3: Describe about recursive definitions, algorithms, functions and their implementation and use. LO3.1 Describe the basic ideas of recursion and how to set up recursive systems that represent certain real-world phenomena. LO3.2 Know how to develop recursive algorithms and programs LO3.3 Write programs in Java using recursion to solve some problems, like creating the Fibonacci sequence. LO3.4 Analyse a recursive function to find out its’ ouput without running. LO3.5 Explain type of recursive functions, give examples and comparing them. LO3.6 Compare recursion with iteration, analyzes their pros and cons
> - CLO4: Explain about general tree, Binary Tree and Binary Search Tree (BST). Implement BST with basic operations. LO4.1 Define general tree, Binary Tree and Binary Search Tree (BST). LO4.2 Given a BST and a sequence of insert and delete operations on it, draw the resulted tree. LO4.3 Find the smallest and largest elements, number of nodes in a tree and its’ height. LO4.4 Write code to implement features of a binary search tree, such as insertion, deletion, searching, traversals, nodes and height calculation, rotation ... LO4.5 Derive the time complexities for the above operations on a binary search tree. LO4.6 Compare a binary search tree over other data structures that we have discussed in class. LO4.7 Identify applications where a binary search tree will be useful. LO4.8 Define balanced BST and explane simple balancing algorithm. LO4.9 Define AVL Tree and explain by examples the insertion and deletion operations in it. LO5.10 Define heap and explain its’ application.
> - CLO5: Díscuss about graphs and their application. Implement a graph with some basic operations. LO5.1 Demonstrate graphs and their applications. Define an undirected graph and directed graph. LO5.2 Explain basic notions about a graph: vertex, edge, adjacent vertices, incident edge,... LO5.3 Know how to represent a graph using matrix and list LO5.4 Able to apply BFS and DFS to traverse a graph LO5.5 Write prorams to implement Graph with BFS and DFS traversals using Java LO5.6 Explain the shortest path problem and Dijkstra’ algorithm. LO5.7 Write program in Java to implement Dijkstra’s shortest path algorithm. LO5.8 Define the minimum spanning tree and using the Kruskal’s algorithm to find it. LO5.9 Define Euler cycle/path and the necessary and sufficient conditions for their existance. LO5.10 Explain the algorithm to find Euler path / circuit using Stack and implement it in Java lannguage. LO5.11 Define Halmilton cycle/path and able to determine them using backtracking algorithm. LO5.12 Demonstrate the graph coloring and can apply Sequential coloring algorithm to color a graph.
> 
> **Trọng tâm kỹ thuật theo lịch môn:**
> - **CLO1:** 1.3. Circularly Linked Lists1.4. Doubly Linked Lists, Guiding Exercises/Assignment. Bài phải làm: chưa có hướng dẫn thực hành riêng trong dữ liệu syllabus; cần bổ sung rubric hoặc bài mẫu của môn.
> - **CLO2:** 2.1 Stacks, Guiding Exercises/Assignment, 2.2 Queues2.3 Double-Ended Queues (Deque), 2.4 The Priority Queue. Bài phải làm: chưa có hướng dẫn thực hành riêng trong dữ liệu syllabus; cần bổ sung rubric hoặc bài mẫu của môn.
> - **CLO3:** 3.1 Illustrative Examples3.1.1 The Factorial Function3.1.2 Binary Search3.1.3 File Systems, 3.2 Analyzing Recursive Algorithms3.3 Further Examples of Recursion3.3.1 Linear Recursion3.3.2 Binary Recursion3.3.3 Multiple Recursion3.4 Designing Recursive Algorithms3.5 Eliminating Tail Recursion, Guiding Exercises/Assignment. Bài phải làm: chưa có hướng dẫn thực hành riêng trong dữ liệu syllabus; cần bổ sung rubric hoặc bài mẫu của môn.
> 
> **Kế hoạch theo từng thành phần đánh giá:**
> - Progress test (PT) (Part 2): 20.0%; >0; Option 1: 20'-40' Option 2 (For Constructivism Approach only): Follow lecturer's proposal; Option 1: essay or multiple choice Option 2 (For Constructivism Approach only): Follow lecturer's proposal → lập bộ câu hỏi theo CLO liên quan, làm thử có giới hạn thời gian và kiểm tra đáp án.
> - Assignment (AS) (Part 2): 20.0%; >0; Option 1: at home Option 2 (For Constructivism Approach only): Follow lecturer's proposal; Option 1: a problem similar to real one Option 2 (For Constructivism Approach only): Follow lecturer's proposal → tạo sản phẩm nộp được, chạy qua checklist yêu cầu và hoàn thiện trước hạn.
> - Practical Exam: 30.0%; >0; 85'; Preferable to be marked by scripts → luyện đúng dạng bài trong thời lượng ghi ở assessment và lưu lại lỗi sau mỗi lần làm.
> - Final exam: 30.0%; 4; 60'; multiple choice → lập bộ câu hỏi theo CLO liên quan, làm thử có giới hạn thời gian và kiểm tra đáp án.
> 
> **Dữ liệu thời lượng của môn:** Study hour (150h) = 45h contact hours + 1h TE + 85' PE + 102.6h self-study.
> 
> **Cách học theo thứ tự ưu tiên:**
> - Bắt đầu từ thành phần assessment có tỷ trọng cao nhất và đối chiếu trực tiếp với CLO/topic của môn; mỗi phần phải tạo ra một bài làm hoặc sản phẩm kiểm tra được.
> - Sau mỗi lần luyện, lưu lỗi sai và chấm lại theo đúng tiêu chí đang có trong syllabus; không coi việc đọc lại lý thuyết là đã hoàn thành.
> 
> **Môn tiên quyết cần rà lại trước:** PRO192.
> - Chưa có bảng điểm đã xác nhận để kết luận bạn đủ điều kiện học môn này.
> 
> **Việc nên làm ngay:**
> - Dựng một bài luyện sát dạng PE trong syllabus, tự làm có bấm giờ, lưu sản phẩm và ghi lại lỗi sau mỗi lần thử.
> - Sau mỗi tuần, đối chiếu sản phẩm hoặc bài làm với learning outcome; phần nào chưa chứng minh được thì đưa vào lịch tuần kế tiếp.
> 
> **Nguồn:** dữ liệu đề cương FLM của môn CSD201 (tín chỉ, tiên quyết, assessment, CLO/topic); điểm cá nhân từ bảng điểm đã xác nhận nếu có. Mục tiêu và cách học là thông tin sinh viên tự khai.

---
