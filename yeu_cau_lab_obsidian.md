# YÊU CẦU DỰ ÁN LAB: HỆ THỐNG OBSIDIAN & CHAT AI MÔN HỌC (FLM)

> **Tóm tắt từ bản ghi âm trao đổi với giảng viên hướng dẫn.**

---

## 1. Quy Trình Thực Hiện Cốt Lõi (4 Bước)

1. **Bước 1: Trích xuất Dữ liệu (Extract Data)**
   - Trích xuất dữ liệu từ các trang HTML của hệ thống **FLM** (FPT Curriculum / Syllabus).
   - Chuyển đổi dữ liệu thô thành các file **Markdown (`.md`)**.
   - Cấu trúc dữ liệu: *Curriculum (Chương trình khung) $\to$ Syllabus (Đề cương chi tiết từng môn)*.

2. **Bước 2: Xây dựng Graph trên Obsidian**
   - Đưa toàn bộ các file `.md` đã trích xuất vào **Obsidian**.
   - Thiết lập liên kết hai chiều (internal links `[[...]]`) để build sơ đồ đồ thị tri thức (**Graph View**) kết nối các môn học, điều kiện tiên quyết, học kỳ,...

3. **Bước 3: Xây dựng Giao diện Ứng dụng (Flutter UI)**
   - Phát triển app bằng **Flutter** với giao diện trực quan, chuyên nghiệp.
   - Hiển thị danh sách môn học theo card và tích hợp trình xem Graph View.

4. **Bước 4: Tích hợp Trợ lý Chat AI (RAG / LLM)**
   - Đấu nối ứng dụng với mô hình ngôn ngữ lớn (LLM).
   - Sử dụng kỹ thuật **RAG (Retrieval-Augmented Generation)** truy vấn trên tập dữ liệu FLM đã trích xuất.
   - *Lưu ý:* Chat là bước hoàn thiện sau cùng sau khi đã có data và UI hoàn chỉnh.

---

## 2. Chi Tiết Yêu Cầu Giao Diện (Flutter UI)

### 2.1. Chế độ danh sách môn học (List / Cards)
- Hiển thị môn học phân chia theo từng học kỳ (Ví dụ: Học kỳ 1 gồm các môn lập trình C, môn cơ sở,...).
- Mỗi môn thể hiện dưới dạng thẻ (**Card**).
- Bấm vào thẻ để chuyển sang màn hình **Xem chi tiết** (Chi tiết đề cương, số tín chỉ, nội dung môn học).

### 2.2. Chế độ Graph View (Sơ đồ liên kết)
- Có nút chức năng **"View Graph"** trên giao diện.
- Khi bấm, hiển thị Graph trực quan (dưới dạng màn hình riêng hoặc Pop-up / Modal).
- **Tương tác với Node trên Graph:**
  - Click vào 1 Node (môn học): Hiển thị cửa sổ tóm tắt (**Modal nhỏ**) gồm các thông tin cơ bản:
    - Mã môn học (ví dụ: `SWD392`, `PRM392`,...).
    - Tên môn học (Course Title).
    - Số lượng tín chỉ.
  - Trong Modal có nút bấm **"Xem chi tiết"**:
    - Nhấn nút này mới chuyển vào trang chi tiết đầy đủ của môn học.
    - Click bên ngoài modal sẽ quay lại xem graph bình thường mà không bị chuyển trang đột ngột.

---

## 3. Kịch Bản & Câu Hỏi Mẫu Cho Chat AI (RAG)

Chatbot phải trả lời chính xác dựa trên nguồn dữ liệu FLM đã extract:
- **Hình thức thi/đánh giá:** *Môn PRM392 có thi PE (Practical Exam) hay không?*
- **Mục tiêu môn học (Learning Outcomes):** *Mục tiêu của môn học này là gì?* (trích từ FLM).
- **Số tín chỉ:** *Trong khung chương trình của tôi, môn PRM392 có mấy tín chỉ?*
- **Kế hoạch học tập:** *Môn SWD392 học ở học kỳ mấy?*

---

## 4. Kiến Trúc Kỹ Thuật & Yêu Cầu Sống Còn (Non-Functional)

- **Kiến trúc hệ thống:**
  - **Frontend:** Ứng dụng Flutter.
  - **Backend:** Python (**FastAPI**) phụ trách xử lý logic AI, RAG và gọi LLM.
  - Kết nối giữa Flutter và Backend qua **RESTful API**.
- **Tính độc lập & Khả năng chịu lỗi (Crucial):**
  - **Nếu server AI / LLM bị lỗi hoặc mất mạng:** Ứng dụng Flutter **vẫn phải hoạt động bình thường** (xem danh sách môn học, duyệt UI, tương tác Graph View).
  - Lỗi từ phía AI không được làm crash toàn bộ app.