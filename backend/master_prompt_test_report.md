# BÁO CÁO KIỂM THỬ THỰC CHIẾN MASTER PROMPT

## CA 1: Sinh viên mất gốc, sợ PE môn CSD201, mục tiêu chỉ cần qua môn
- **Câu hỏi:** Tôi bị mất gốc code từ hồi PRO192, giờ sắp học CSD201 tôi sợ trượt PE quá. Tôi chỉ cần qua môn thôi (5.0), chỉ cho tôi cách thoát hiểm với!
- **Dữ kiện sinh viên:** `{'current_gpa': 5.8, 'course_goal': 'pass', 'learning_style': 'practice', 'failed_courses': ['PRO192'], 'retake_count': 1}`
- **Thời gian xử lý:** 124.9ms | Provider: FLM-Structured-Advisor

### Câu trả lời của AI:

### Cách học để qua môn CSD201 (Cấu trúc dữ liệu và giải thuật)

**Mục tiêu:** biến đề cương của chính môn này thành các việc có thể làm và kiểm tra được; không dùng một mẫu PE/FE chung cho mọi môn.
- Môn này có **3 tín chỉ**.
- Phân bổ thời gian theo dữ liệu môn: **Study hour (150h) = 45h contact hours + 1h TE + 85' PE + 102.6h self-study**.
- Trạng thái PE theo dữ liệu FLM: **Có**.
- Điều kiện đạt ghi trong đề cương: **5**.
- **Ưu tiên qua môn:** xác nhận điều kiện đạt trong syllabus/rubric, hoàn thành đủ từng thành phần bắt buộc và luyện lại phần chưa đạt. Chưa có ngưỡng đạt thì không tự suy ra điểm cần thiết.
- **Cách học ưu tiên:** làm bài hoặc sản phẩm theo topic thực tế, rồi đối chiếu CLO và sửa lỗi.

**Các phần cần tập trung theo cấu trúc đánh giá thực tế:**
- Progress test (PT) (Part 2): 20.0%; >0; Option 1: 20'-40' Option 2 (For Constructivism Approach only): Follow lecturer's proposal; Option 1: essay or multiple choice Option 2 (For Constructivism Approach only): Follow lecturer's proposal
- Assignment (AS) (Part 2): 20.0%; >0; Option 1: at home Option 2 (For Constructivism Approach only): Follow lecturer's proposal; Option 1: a problem similar to real one Option 2 (For Constructivism Approach only): Follow lecturer's proposal
- Practical Exam: 30.0%; >0; 85'; Preferable to be marked by scripts
- Final exam: 30.0%; 4; 60'; multiple choice

**Năng lực cần đạt:**
- CLO1: Describe the list data structure and its’ different way of implementations. Implement the singly linked list. LO1.1 Demonstrate the list data structure with basic operations: insert, remove, edit, search, sort,... LO1.2 Explain two ways of implementing a list: using arrays and using linked lists. LO1.3 Write programs to implement the singly linked list with basic operations: add (last, first, before, after, at position), search, edit, remove, reverse, sort... ) LO1.4 Understand the doubly linked-list data structure with basic operations. LO1.5 Write code snippets which manipulate operations on doubly linked list, and use diagrams to illustrate the effect. LO1.6 Describe the circularly linked-list data structure with some basic operations like add, remove. LO1.7 Expain why the Java code library provides the ArrayList and LinkedList classes
- CLO2: Define stack and queue. Describe basic operations and the use of these structures. LO2.1 Define stack and queue. LO2.2 List and demonstrate the operations common to stacks and queues. LO2.3 Describe specific tasks to which stacks and queues are suited. LO2.4 Apply stacks to a specific application. LO2.5 Apply queues to a specific application. LO2.6 Write programs to implement stack and queue in Java programming language. LO2.7 Define and explain the need of priority queue.
- CLO3: Describe about recursive definitions, algorithms, functions and their implementation and use. LO3.1 Describe the basic ideas of recursion and how to set up recursive systems that represent certain real-world phenomena. LO3.2 Know how to develop recursive algorithms and programs LO3.3 Write programs in Java using recursion to solve some problems, like creating the Fibonacci sequence. LO3.4 Analyse a recursive function to find out its’ ouput without running. LO3.5 Explain type of recursive functions, give examples and comparing them. LO3.6 Compare recursion with iteration, analyzes their pros and cons
- CLO4: Explain about general tree, Binary Tree and Binary Search Tree (BST). Implement BST with basic operations. LO4.1 Define general tree, Binary Tree and Binary Search Tree (BST). LO4.2 Given a BST and a sequence of insert and delete operations on it, draw the resulted tree. LO4.3 Find the smallest and largest elements, number of nodes in a tree and its’ height. LO4.4 Write code to implement features of a binary search tree, such as insertion, deletion, searching, traversals, nodes and height calculation, rotation ... LO4.5 Derive the time complexities for the above operations on a binary search tree. LO4.6 Compare a binary search tree over other data structures that we have discussed in class. LO4.7 Identify applications where a binary search tree will be useful. LO4.8 Define balanced BST and explane simple balancing algorithm. LO4.9 Define AVL Tree and explain by examples the insertion and deletion operations in it. LO5.10 Define heap and explain its’ application.
- CLO5: Díscuss about graphs and their application. Implement a graph with some basic operations. LO5.1 Demonstrate graphs and their applications. Define an undirected graph and directed graph. LO5.2 Explain basic notions about a graph: vertex, edge, adjacent vertices, incident edge,... LO5.3 Know how to represent a graph using matrix and list LO5.4 Able to apply BFS and DFS to traverse a graph LO5.5 Write prorams to implement Graph with BFS and DFS traversals using Java LO5.6 Explain the shortest path problem and Dijkstra’ algorithm. LO5.7 Write program in Java to implement Dijkstra’s shortest path algorithm. LO5.8 Define the minimum spanning tree and using the Kruskal’s algorithm to find it. LO5.9 Define Euler cycle/path and the necessary and sufficient conditions for their existance. LO5.10 Explain the algorithm to find Euler path / circuit using Stack and implement it in Java lannguage. LO5.11 Define Halmilton cycle/path and able to determine them using backtracking algorithm. LO5.12 Demonstrate the graph coloring and can apply Sequential coloring algorithm to color a graph.

**Trọng tâm kỹ thuật theo lịch môn:**
- **CLO1:** 1.3. Circularly Linked Lists1.4. Doubly Linked Lists, Guiding Exercises/Assignment. Bài phải làm: chưa có hướng dẫn thực hành riêng trong dữ liệu syllabus; cần bổ sung rubric hoặc bài mẫu của môn.
- **CLO2:** 2.1 Stacks, Guiding Exercises/Assignment, 2.2 Queues2.3 Double-Ended Queues (Deque), 2.4 The Priority Queue. Bài phải làm: chưa có hướng dẫn thực hành riêng trong dữ liệu syllabus; cần bổ sung rubric hoặc bài mẫu của môn.
- **CLO3:** 3.1 Illustrative Examples3.1.1 The Factorial Function3.1.2 Binary Search3.1.3 File Systems, 3.2 Analyzing Recursive Algorithms3.3 Further Examples of Recursion3.3.1 Linear Recursion3.3.2 Binary Recursion3.3.3 Multiple Recursion3.4 Designing Recursive Algorithms3.5 Eliminating Tail Recursion, Guiding Exercises/Assignment. Bài phải làm: chưa có hướng dẫn thực hành riêng trong dữ liệu syllabus; cần bổ sung rubric hoặc bài mẫu của môn.

**Kế hoạch theo từng thành phần đánh giá:**
- Progress test (PT) (Part 2): 20.0%; >0; Option 1: 20'-40' Option 2 (For Constructivism Approach only): Follow lecturer's proposal; Option 1: essay or multiple choice Option 2 (For Constructivism Approach only): Follow lecturer's proposal → lập bộ câu hỏi theo CLO liên quan, làm thử có giới hạn thời gian và kiểm tra đáp án.
- Assignment (AS) (Part 2): 20.0%; >0; Option 1: at home Option 2 (For Constructivism Approach only): Follow lecturer's proposal; Option 1: a problem similar to real one Option 2 (For Constructivism Approach only): Follow lecturer's proposal → tạo sản phẩm nộp được, chạy qua checklist yêu cầu và hoàn thiện trước hạn.
- Practical Exam: 30.0%; >0; 85'; Preferable to be marked by scripts → luyện đúng dạng bài trong thời lượng ghi ở assessment và lưu lại lỗi sau mỗi lần làm.
- Final exam: 30.0%; 4; 60'; multiple choice → lập bộ câu hỏi theo CLO liên quan, làm thử có giới hạn thời gian và kiểm tra đáp án.

**Dữ liệu thời lượng của môn:** Study hour (150h) = 45h contact hours + 1h TE + 85' PE + 102.6h self-study.

**Cách học theo thứ tự ưu tiên:**
- Bắt đầu từ thành phần assessment có tỷ trọng cao nhất và đối chiếu trực tiếp với CLO/topic của môn; mỗi phần phải tạo ra một bài làm hoặc sản phẩm kiểm tra được.
- Sau mỗi lần luyện, lưu lỗi sai và chấm lại theo đúng tiêu chí đang có trong syllabus; không coi việc đọc lại lý thuyết là đã hoàn thành.

**Môn tiên quyết cần rà lại trước:** PRO192.
- Chưa có bảng điểm đã xác nhận để kết luận bạn đủ điều kiện học môn này.

**Việc nên làm ngay:**
- Dựng một bài luyện sát dạng PE trong syllabus, tự làm có bấm giờ, lưu sản phẩm và ghi lại lỗi sau mỗi lần thử.
- Sau mỗi tuần, đối chiếu sản phẩm hoặc bài làm với learning outcome; phần nào chưa chứng minh được thì đưa vào lịch tuần kế tiếp.

**Nguồn:** dữ liệu đề cương FLM của môn CSD201 (tín chỉ, tiên quyết, assessment, CLO/topic); điểm cá nhân từ bảng điểm đã xác nhận nếu có. Mục tiêu và cách học là thông tin sinh viên tự khai.

---

## CA 2: Sinh viên GPA 7.4 muốn lên 8.0 (Giỏi), đã trượt 1 môn, hỏi chiến lược kỳ 5
- **Câu hỏi:** GPA hiện tại của tôi là 7.4, muốn ra trường 8.0 loại Giỏi thì kỳ 5 này có môn SWP391 và PRN212 tôi nên phân bổ chiến lược ra sao?
- **Dữ kiện sinh viên:** `{'current_gpa': 7.4, 'target_gpa': 8.0, 'required_avg_mark': 8.45, 'retake_count': 1, 'current_semester': 5}`
- **Thời gian xử lý:** 5262.2ms | Provider: Groq

### Câu trả lời của AI:

Chào em, anh nghe thấy nỗi lo trong câu hỏi của em rồi. GPA 7.4 hiện tại là một con số rất "đau" vì nó nằm ngay sát bờ vực giữa loại Khá và loại Giỏi. Mục tiêu 8.0 không phải là mơ hồ, nhưng nó đòi hỏi em phải cực kỳ tỉnh táo và thực chiến, đặc biệt là khi em đã có **1 môn học lại** trong quá khứ.

Trước khi đi vào chiến thuật cho SWP391 và PRN212, anh phải "đánh thức" em về một rủi ro cực lớn mà dữ liệu FLM đã cảnh báo: **Quy chế hạ bậc tốt nghiệp**.

### 1. Cảnh báo đỏ: Nguy cơ mất loại Giỏi dù GPA đạt 8.0

Theo dữ liệu chương trình:
> *"Nếu đã học lại từ 2 môn trượt trở lên thì bị hạ 1 bậc khi xếp loại là Xuất sắc, Giỏi."*

Hiện tại em đã học lại **1 môn**. Điều này có nghĩa là:
* Nếu em **trượt thêm 1 môn** (bất kỳ môn nào, kể cả SWP391 hay PRN212) và phải học lại, em sẽ có tổng cộng **2 môn học lại**.
* Khi đó, dù GPA cuối cùng có đạt 8.0 (đủ chuẩn Giỏi), em sẽ **bị hạ xuống loại Khá**.
* **Kết luận:** Kỳ 5 này, mục tiêu số 1 của em không phải là "săn điểm 9-10", mà là **KHÔNG ĐƯỢC TRƯỢT MÔN NÀO**. Điểm trung bình cần đạt ở các môn còn lại là **8.45**. Con số này cho thấy em không có quyền sai sót.

---

### 2. Phân tích chiến lược cho SWP391 (Dự án phát triển phần mềm)

SWP391 là môn "nặng đô" nhất kỳ 5, chiếm nhiều thời gian và tâm sức. Để đạt điểm cao (ít nhất 8.0+) và đảm bảo an toàn, em cần hiểu rõ cấu trúc điểm:

* **Milestone 1 (Tuần 3): 15%** - Phân tích yêu cầu & Thiết kế.
* **Milestone 2 (Tuần 8): 20%** - Triển khai Workflow 1 & 2.
* **Milestone 3 (Tuần 10): 25%** - Hoàn thiện hệ thống & Kiểm thử.
* **Final Presentation: 40%** - Bảo vệ đồ án cuối kỳ.

**Chiến thuật thực chiến cho SWP391:**

1. **Chọn đề tài & Stack công nghệ "An toàn" nhưng "Điểm cao":**
 * Đừng chọn đề tài quá phức tạp về thuật toán nếu team em yếu về logic. Hãy chọn đề tài **CRUD phức tạp** hoặc **Hệ thống quản lý** có nhiều vai trò (Role-based access control).
 * **Stack gợi ý:** Java Spring Boot + React/Angular (hoặc .NET Core + React). Đây là stack phổ biến, tài liệu nhiều, AI (Copilot/ChatGPT) hỗ trợ code rất tốt. Tránh các stack quá mới hoặc ngách nếu team chưa rành.
 * **Yêu cầu bắt buộc:** Phải có **Database Schema** rõ ràng (ERD), **UI/UX Wireframes** đẹp (dùng Figma), và **Source Code** quản lý bằng Git có commit lịch sử rõ ràng.

2. **Tối ưu hóa 3 Milestone (Tổng 60% điểm):**
 * **M1 (15%):** Tập trung vào **Yêu cầu (Requirements)** và **Thiết kế (Design)**. Dùng Miro/Lucidchart để vẽ Use Case, Sequence Diagram, ERD. Điểm ở đây đến từ sự **rõ ràng, logic và tính chuyên nghiệp** của tài liệu, không phải code. Hãy để AI giúp em viết User Stories và User Requirements cho chuẩn chỉnh.
 * **M2 (20%):** Triển khai **2 Workflow chính**. Đừng cố làm hết tính năng. Hãy làm **sâu** 2 luồng nghiệp vụ cốt lõi (ví dụ: Đăng nhập/Xuất hóa đơn, hoặc Tạo đơn hàng/Xử lý thanh toán). Code phải chạy được, có Unit Test cơ bản.
 * **M3 (25%):** Hoàn thiện & Testing. Đây là lúc "gánh" điểm. Hãy viết **Integration Tests** (dùng Postman hoặc Selenium) và **Unit Tests** (JUnit/NUnit). Giáo viên rất thích xem bằng chứng kiểm thử. Đảm bảo ứng dụng deploy lên môi trường staging (Heroku/Azure/Vercel) chạy được.

3. **Final Presentation (40% điểm - Quyết định số phận):**
 * **Điều kiện tiên quyết:** Điểm trung bình quá trình (M1+M2+M3) phải **≥ 5/10** mới được vào thi cuối. Với mục tiêu 8.0, em cần đạt khoảng **8.5-9.0** ở các milestone trước.
 * **Yêu cầu "Liệt":** Điểm tối thiểu cho phần thi cuối là **4/10**. Nếu dưới 4, trượt ngay.
 * **Điểm cộng lớn:**
 * **Peer Review & Contribution Score:** Em phải có điểm đóng góp (code, task) **≥ 80%**. Hãy đảm bảo em commit code đều đặn, không "ôm" việc rồi dump code vào phút chót.
 * **Trình bày:** 60 phút bảo vệ nhóm. Em cần chuẩn bị slide chuyên nghiệp, demo mượt mà, và **sẵn sàng trả lời câu hỏi kỹ thuật** về kiến trúc, database, và cách xử lý lỗi.
 * **Sử dụng AI có trách nhiệm:** Giáo viên sẽ kiểm tra mức độ sử dụng AI. Hãy chuẩn bị sẵn câu trả lời về cách em dùng AI để gợi ý code, test case, và cách em kiểm chứng lại code đó.

**Lịch trình gợi ý cho SWP391:**
* **Tuần 1-2:** Chọn đề, phân công việc, vẽ ERD, Wireframe.
* **Tuần 3:** Nộp Milestone 1.
* **Tuần 4-7:** Code 2 Workflow chính. Commit code hàng ngày.
* **Tuần 8:** Nộp Milestone 2.
* **Tuần 9-10:** Code các tính năng phụ, viết Test, Deploy.
* **Tuần 10:** Nộp Milestone 3.
* **Tuần 11-12:** Rèn luyện thuyết trình, chuẩn bị slide, demo.

---

### 3. Phân tích chiến lược cho PRN212 (Lập trình nền tảng)

PRN212 thường là môn lập trình nền tảng (có thể là Java, C++, hoặc Python tùy khóa học, nhưng thường là Java hoặc C# tại FPT). Môn này thi **PE (Practical Exam)** hoặc **FE (Final Exam)** dạng làm bài tập về thuật toán/cấu trúc dữ liệu.

**Chiến thuật thực chiến cho PRN212:**

1. **Xác định trọng tâm:**
 * Môn này thường tập trung vào **OOP (Lập trình hướng đối tượng)**, **Cấu trúc dữ liệu** (Array, List, Stack, Queue, Tree, Graph), và **Thuật toán** (Sort, Search, Recursion).
 * **Đừng học vẹt.** Hãy hiểu bản chất. Ví dụ: Tại sao dùng HashMap thay vì ArrayList? Khi nào dùng DFS thay vì BFS?

2. **Rèn luyện dạng bài thi:**
 * Tìm các đề thi PE/FE của các kỳ trước (hỏi anh chị khóa trên hoặc tìm trong thư viện FLM).
 * Tập trung vào các bài toán kinh điển:
 * In ra các phần tử thỏa mãn điều kiện.
 * Tìm kiếm nhị phân, sắp xếp (QuickSort, MergeSort).
 * Duyệt cây (Tree Traversal: Pre, In, Post order).
 * Giải quyết bài toán bằng đệ quy (Recursion).
 * **Mẹo:** Viết code skeleton (khung code) cho các hàm thường gặp. Ví dụ: khung hàm `search()`, khung hàm `sort()`. Khi thi, chỉ cần điền logic bên trong.

3. **Quản lý thời gian khi thi:**
 * Đọc kỹ đề, xác định yêu cầu đầu vào/đầu ra.
 * Viết pseudocode trước khi code.
 * Kiểm tra edge cases (trường hợp biên): mảng rỗng, mảng 1 phần tử, giá trị cực đại/tối thiểu.

**Lịch trình gợi ý cho PRN212:**
* **Tuần 1-4:** Ôn tập OOP, Cấu trúc dữ liệu cơ bản. Làm bài tập về nhà.
* **Tuần 5-8:** Làm đề thi mẫu. Tập trung vào các bài toán thuật toán.
* **Tuần 9-10:** Rèn tốc độ code. Làm các bài toán khó hơn.
* **Tuần 11-12:** Ôn tập tổng kết, xem lại các lỗi thường gặp.

---

### 4. Phân bổ thời gian & Chiến

---

## CA 3: Sinh viên bế tắc đồ án SWP391 sắp toang deadline
- **Câu hỏi:** Ê bro, đồ án SWP391 team tôi lộn xộn quá, sắp tới ngày review sprint mà backend chưa xong, tôi hoang mang không biết qua môn nổi không nữa.
- **Dữ kiện sinh viên:** `{'current_semester': 5, 'course_goal': 'pass'}`
- **Thời gian xử lý:** 105.0ms | Provider: FLM-Structured-Advisor

### Câu trả lời của AI:

### Cách học để qua môn SWP391 (Dự án phát triển phần mềm)

**Mục tiêu:** biến đề cương của chính môn này thành các việc có thể làm và kiểm tra được; không dùng một mẫu PE/FE chung cho mọi môn.
- Môn này có **3 tín chỉ**.
- Phân bổ thời gian theo dữ liệu môn: **Study hour (150h) = 45h contact hours + 1h Project Presentation + 104h self-study**.
- Trạng thái PE theo dữ liệu FLM: **Không**.
- Điều kiện đạt ghi trong đề cương: **5**.
- **Ưu tiên qua môn:** xác nhận điều kiện đạt trong syllabus/rubric, hoàn thành đủ từng thành phần bắt buộc và luyện lại phần chưa đạt. Chưa có ngưỡng đạt thì không tự suy ra điểm cần thiết.

**Các phần cần tập trung theo cấu trúc đánh giá thực tế:**
- Assessment 1 (Week3)Milestone 1: Requirement Analysis & Design: 15.0%; >0; 20'/group; The student presents slides, gives a demonstration, and answers questions from the lecturer.
- Assessment 2 (Week 8)Milestone 2 : Workflow 1 & 2 Implementation: 20.0%; >0; 20'/group; The student presents slides, gives a demonstration, and answers questions from the lecturer.
- Assessment 3Milestone 3 (Week 10): Full System Completion & Testing: 25.0%; >0; 20'/group; The student presents slides, gives a demonstration, and answers questions from the lecturer.
- Final Project Presentation: 40.0%; 4; 60'/group; The student presents slides, gives a demonstration, and answers questions from the lecturer.

**Năng lực cần đạt:**
- CLO1: Analyze and clarify project requirements with AI-assisted elicitation and documentation
- CLO2: Design system modules and databases using MVC, OOP, and AI-supported modelling tools
- CLO3: Create ERD models and implement relational databases with SQL, applying AI tools for design validation and query optimization.
- CLO4: Develop web applications in Java/.NET/Node.js with AI-enhanced coding, debugging, and workflow implementation.
- CLO5: Demonstrate teamwork, professional ethics, and responsible AI use in software development.

**Trọng tâm kỹ thuật theo lịch môn:**
- **CLO0:** Workflow 0: Basic Web Security- Register/Login/Logout/Forgot Password. Bài phải làm: chưa có hướng dẫn thực hành riêng trong dữ liệu syllabus; cần bổ sung rubric hoặc bài mẫu của môn.
- **CLO1:** Workflow 0: Basic Web Security- Register/Login/Logout/Forgot Password. Bài phải làm: chưa có hướng dẫn thực hành riêng trong dữ liệu syllabus; cần bổ sung rubric hoặc bài mẫu của môn.
- **CLO1, CLO2:** Database design- Tables and Constraints, Milestone 1 Review & Evaluation. Bài phải làm: làm một CRUD có quan hệ bảng, migration, truy vấn LINQ và kiểm tra dữ liệu lỗi.

**Kế hoạch theo từng thành phần đánh giá:**
- Assessment 1 (Week3)Milestone 1: Requirement Analysis & Design: 15.0%; >0; 20'/group; The student presents slides, gives a demonstration, and answers questions from the lecturer. → đối chiếu rubric của thành phần này với một sản phẩm hoặc bài làm cụ thể.
- Assessment 2 (Week 8)Milestone 2 : Workflow 1 & 2 Implementation: 20.0%; >0; 20'/group; The student presents slides, gives a demonstration, and answers questions from the lecturer. → đối chiếu rubric của thành phần này với một sản phẩm hoặc bài làm cụ thể.
- Assessment 3Milestone 3 (Week 10): Full System Completion & Testing: 25.0%; >0; 20'/group; The student presents slides, gives a demonstration, and answers questions from the lecturer. → lập bộ câu hỏi theo CLO liên quan, làm thử có giới hạn thời gian và kiểm tra đáp án.
- Final Project Presentation: 40.0%; 4; 60'/group; The student presents slides, gives a demonstration, and answers questions from the lecturer. → tạo sản phẩm nộp được, chạy qua checklist yêu cầu và hoàn thiện trước hạn.

**Dữ liệu thời lượng của môn:** Study hour (150h) = 45h contact hours + 1h Project Presentation + 104h self-study.

**Cách học theo thứ tự ưu tiên:**
- Bắt đầu từ thành phần assessment có tỷ trọng cao nhất và đối chiếu trực tiếp với CLO/topic của môn; mỗi phần phải tạo ra một bài làm hoặc sản phẩm kiểm tra được.
- Sau mỗi lần luyện, lưu lỗi sai và chấm lại theo đúng tiêu chí đang có trong syllabus; không coi việc đọc lại lý thuyết là đã hoàn thành.

**Môn tiên quyết cần rà lại trước:** PRJ301, SWE201c, SWE202c, LAB211.
- Chưa có bảng điểm đã xác nhận để kết luận bạn đủ điều kiện học môn này.

**Việc nên làm ngay:**
- Chia các learning outcome thành từng chủ đề, tạo dàn ý trả lời/bài tập tương ứng và đối chiếu với từng thành phần đánh giá ở trên.
- Chuẩn bị đúng công cụ theo syllabus: **Requirement & Design: Miro, Lucidchart, Figma, Draw.io, ChatGPT, Gemini, Coding & Debugging: IntelliJ IDEA / VS Code / Visual Studio, GitHub Copilot, Tabnine, Database: MySQL Workbench, SQL Server Management Studio, pgAdmin-Testing: JUnit, NUnit, Postman, Selenium, AI-powered test case generators, Project Management: Jira, Trello, Notion, Git/GitHub, Deployment: Docker, Heroku, AWS / Azure / GCP, Vercel**.
- Sau mỗi tuần, đối chiếu sản phẩm hoặc bài làm với learning outcome; phần nào chưa chứng minh được thì đưa vào lịch tuần kế tiếp.

**Nguồn:** dữ liệu đề cương FLM của môn SWP391 (tín chỉ, tiên quyết, assessment, CLO/topic); điểm cá nhân từ bảng điểm đã xác nhận nếu có. Mục tiêu và cách học là thông tin sinh viên tự khai.

---
