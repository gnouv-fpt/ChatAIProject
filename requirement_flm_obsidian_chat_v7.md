# YÊU CẦU DỰ ÁN LAB: HỆ THỐNG OBSIDIAN & CHAT AI MÔN HỌC (FLM)

> Phiên bản 7. Tổng hợp từ bản ghi âm trao đổi với giảng viên hướng dẫn, ghi chú bổ sung, các câu trả lời đã chốt, và buổi họp nhóm chốt các ý còn thiếu (Mục 1.1) trước khi chia task cho 5 thành viên (Mục 11).
> Các câu hỏi đã chốt được ghi lại ở Mục 9.

---

## 1. Tổng quan

Ứng dụng giúp sinh viên xem chương trình khung (Curriculum) và đề cương môn học (Syllabus) lấy từ hệ thống **FLM**, xem quan hệ giữa các môn bằng Graph View, hỏi đáp bằng Chat AI (RAG), và nhận tư vấn chiến lược học tập dựa trên bảng điểm cá nhân.

**Phạm vi dữ liệu mẫu:** 1 curriculum. Thiết kế phải đọc danh sách curriculum từ dữ liệu (không hard-code) để thêm curriculum sau này không phải sửa code.

**Nền tảng:** Lab 1 (bản làm việc với giảng viên) build và chạy trên **Flutter desktop app**. Các màn hình, thao tác chuột (hover, kéo, cuộn) và bố cục trong toàn bộ tài liệu này mặc định lấy chuẩn desktop; hành vi tương ứng trên di động/màn hẹp (chạm giữ thay hover, danh sách dọc thay cột...) chỉ là phương án responsive dự phòng, không phải mục tiêu chính của Lab 1.

### 1.1. Các ý bổ sung chốt trong buổi họp nhóm (đã đưa vào bản v7)

- **Luồng trải nghiệm liên tục, từ tổng quát đến chi tiết**: người dùng phải đi theo một mạch xuyên suốt — chọn Curriculum → xem tổng quan/học kỳ → chọn môn → hỏi Chat theo đúng ngữ cảnh đang xem — không được nhảy cóc hoặc tách rời các bước (chi tiết ở Mục 4.0).
- **Chất lượng UI tổng thể**: giảng viên chê bản cũ vì chữ/ô hiển thị quá nhỏ, nút bấm không linh hoạt, không có hiệu ứng highlight khi rê chuột. Đây là lỗi phải sửa trên toàn app, không chỉ riêng Graph View (chi tiết ở Mục 8.4).
- **Chat phải "ăn" được đúng những gì FLM/app đang hiển thị**: giảng viên nhấn mạnh nếu chat trả lời cứng/giống kịch bản có sẵn thì mất lý do dùng RAG. Chat phải trả lời động dựa trên dữ liệu thực tế đang xem, không phải câu trả lời dựng sẵn (siết lại ở Mục 5.3).
- **Vị trí khung chat**: xác nhận lại là **box nổi/cố định ở góc phải** màn hình chi tiết Curriculum và Subject, **không** tách thành một tab riêng (đã khớp với Mục 4.2, giữ nguyên).
- Hai điểm giảng viên từng nêu là "chưa ổn" — (a) UI Graph View kiểu Obsidian và (b) tư vấn lộ trình học tập cá nhân hoá theo học kỳ — đã có đặc tả đầy đủ ở Mục 4.3 và Mục 7; giữ nguyên, không phát sinh thêm yêu cầu mới ngoài Mục 8.4 ở trên.

**Quy trình thực hiện (theo thứ tự):**

1. Trích xuất dữ liệu FLM sang Markdown
2. Xây dựng Graph trên Obsidian
3. Xây dựng giao diện Flutter
4. Tích hợp Chat AI (RAG) hai cấp
5. Import bảng điểm và tư vấn chiến lược (làm cuối vì phụ thuộc dữ liệu, UI và chat)

---

## 2. Bước 1: Trích xuất dữ liệu

- Trích dữ liệu từ các trang HTML của FLM (FPT Curriculum / Syllabus).
- Chuyển thành file Markdown (`.md`) có YAML front matter để parse ổn định.
- Cấu trúc: `Curriculum (chương trình khung) → Syllabus (đề cương từng môn)`.

### 2.1. Mô hình dữ liệu

Một môn có thể nằm ở **học kỳ khác nhau tùy curriculum**, nên học kỳ **không** lưu trong file Subject mà lưu ở quan hệ Curriculum ↔ Subject (nhiều-nhiều, có thuộc tính `semester`).

**Subject** (1 file `.md` mỗi môn):

```yaml
---
type: subject
code: PRM392
title: Mobile Programming
credits: 3
prerequisites: [PRM301]
has_pe: true
counts_in_gpa: true          # sinh từ grading_rules.yaml lúc extract
appears_in:
  - {curriculum: SE-K17, semester: 6}
---
```

Nội dung thân file: mô tả môn, learning outcomes, hình thức đánh giá, kế hoạch học tập.

**Curriculum** (1 file `.md` mỗi chương trình):

```yaml
---
type: curriculum
id: SE-K17
name: Software Engineering K17
subjects:
  - {code: PRM392, semester: 6}
  - {code: SWD392, semester: 5}
---
```

### 2.2. Truy vấn/thống kê cần có

- Thống kê curriculum: số học kỳ, số môn, tổng tín chỉ.
- Với một môn: xuất hiện trong curriculum nào, ở học kỳ nào.
- Kiểm tra tiên quyết dựa trên quan hệ `prerequisites`.

### 2.3. Chuẩn hóa mã môn

Mã môn phải được chuẩn hóa (normalize) trước khi so khớp giữa FLM, OCR và file cấu hình: viết hoa, bỏ khoảng trắng, thống nhất ký tự (ví dụ `Ð` (eth) và `Đ` (chữ Việt) về cùng một dạng).

---

## 3. Bước 2: Graph trên Obsidian

- Đưa toàn bộ file `.md` vào Obsidian.
- Thiết lập liên kết hai chiều `[[...]]` chủ yếu giữa **môn học ↔ môn tiên quyết**. Liên kết curriculum ↔ môn và học kỳ ↔ môn chỉ dùng ở mức cần thiết, tránh một node trung tâm nối với toàn bộ môn làm graph rối.
- Cấu hình Graph View trong Obsidian: tô màu nhóm theo học kỳ (dựa trên tag/thuộc tính), kích thước node theo số liên kết.
- Mục đích: kiểm chứng dữ liệu và làm chuẩn tham chiếu cho Graph View trong app (Mục 4.3), vốn phải có trải nghiệm tương tự Obsidian.

---

## 4. Bước 3: Giao diện Flutter

### 4.0. Luồng trải nghiệm liên tục (tổng quát → chi tiết)

- Người dùng phải đi theo đúng một mạch: **Màn 1 (chọn Curriculum) → Màn 2 (tổng quan chương trình, rồi tới danh sách/tab học kỳ, rồi tới Map) → Màn 3 (chi tiết một môn) → Chat**, mỗi bước sau kế thừa ngữ cảnh của bước trước thay vì là các màn hình rời rạc.
- Khung chat luôn "biết" người dùng đang đứng ở đâu trong mạch trên: đang mở Màn 2 thì chat ở chế độ `curriculum`, đang mở Màn 3 của một môn thì chat tự chuyển sang chế độ `subject` cho đúng môn đó (không cần người dùng chọn lại scope thủ công).
- Điều hướng lùi (breadcrumb hoặc nút back) phải giữ nguyên trạng thái đã xem trước đó (tab đang mở, vị trí zoom/pan của Map, học kỳ đang cuộn tới) để không phá mạch tổng quát → chi tiết.
- Đây là yêu cầu về trải nghiệm xuyên suốt cả 3 màn hình, bổ sung cho mô tả từng màn ở Mục 4.1–4.5.

### 4.1. Màn 1: Danh sách Curriculum

- Mỗi curriculum là một **card**: tên chương trình, số học kỳ, số môn, tổng tín chỉ.
- Bấm card để vào Màn 2.

### 4.2. Màn 2: Chi tiết Curriculum

Có các tab và một **khung chat cố định ở nửa bên phải** (không phải một tab):

| Thành phần | Nội dung |
|---|---|
| Tab **Tổng quan** | Thông tin chung, thống kê của curriculum |
| Tab **Danh sách môn** | Môn chia theo học kỳ, bố cục trực quan (xem Mục 4.5) |
| Tab **Map** | Graph View tương tác kiểu Obsidian (Mục 4.3) |
| Khung chat (bên phải) | Chat phạm vi curriculum (Mục 5) |
| Khu vực **Bảng điểm & Chiến lược** | Import bảng điểm, GPA hiện tại, tư vấn chiến lược (Mục 7) |

Bấm card môn để sang Màn 3.

### 4.3. Graph View (tab Map): tương tác như Obsidian

**Vấn đề của bản diagram tĩnh:** node bố trí cứng, đường nối chồng chéo, không nhìn ra môn nào đang liên kết với môn nào. Graph View phải được làm lại như một **đồ thị động** giống Graph View của Obsidian, người dùng khám phá bằng thao tác chứ không phải đọc một bức hình cố định.

**a. Nội dung đồ thị**
- **Node:** mỗi môn học là một node. Mặc định **không hiển thị node curriculum** (tránh một điểm nối tới toàn bộ môn gây rối); học kỳ thể hiện bằng **màu** node, có thể bật thành node riêng bằng tùy chọn.
- **Cạnh (link):** quan hệ tiên quyết, có **mũi tên chỉ hướng** (môn tiên quyết → môn sau).
- **Kích thước node** tỉ lệ số liên kết: môn nhiều liên kết (môn nền tảng) hiện lớn hơn, dễ nhận ra.
- **Chú giải màu** luôn hiển thị (màu theo học kỳ; khi đã import bảng điểm có thể đổi sang màu theo trạng thái đạt/học lại/đang học/chưa học).

**b. Bố cục và chuyển động (force-directed)**
- Node tự sắp xếp bằng mô phỏng vật lý: node đẩy nhau, liên kết kéo nhau lại; đồ thị chuyển động mượt rồi ổn định.
- **Kéo (drag) một node** thì các node liên kết di chuyển theo, thả ra thì đồ thị tự ổn định lại.
- Nút **"Sắp xếp theo học kỳ"**: chuyển sang bố cục cột theo HK1 → HKn để thấy lộ trình rõ ràng; bấm lại để về bố cục tự do.
- Nút **"Reset"** đưa đồ thị về trạng thái ban đầu và nút **"Vừa màn hình"** (fit to screen).

**c. Thao tác cơ bản**
- **Zoom** bằng cuộn chuột/pinch, **pan** bằng kéo nền, trên cả desktop lẫn mobile.
- Nhãn (tên/mã môn) **hiển thị theo mức zoom**: thu nhỏ thì chỉ hiện nhãn node lớn, phóng to thì hiện toàn bộ, để tránh chữ chồng lên nhau.

**d. Làm rõ liên kết khi tương tác**
- **Hover** (desktop) hoặc **chạm giữ/chọn** (mobile) một node: làm nổi bật node đó, các node và cạnh liên kết trực tiếp; **mờ đi toàn bộ phần còn lại**. Đây là cách chính để nhìn ra môn nào link với môn nào.
- Phân biệt bằng màu: **môn tiên quyết (phía trước)** và **môn phụ thuộc (phía sau)**.
- Chức năng **"Chuỗi tiên quyết"**: làm nổi bật toàn bộ đường tiên quyết từ môn được chọn ngược về gốc.

**e. Chế độ xem cục bộ (Local graph)**
- Chọn một môn rồi bật **"Xem liên kết"** để chỉ hiển thị môn đó và các môn xung quanh trong **N cấp** (thanh trượt độ sâu 1 đến 3), ẩn phần còn lại. Dùng khi đồ thị toàn cục còn rối.

**f. Bảng điều khiển (thu gọn được, như Obsidian)**
- **Tìm kiếm** theo mã/tên môn: khớp thì làm nổi bật và tự căn giữa vào node đó.
- **Bộ lọc:** theo học kỳ, theo trạng thái (khi có bảng điểm), môn tính/không tính GPA, môn có/không có tiên quyết, hiện/ẩn node cô lập (không có liên kết).
- **Hiển thị:** bật/tắt nhãn, mũi tên, độ dày cạnh, kích thước node.
- **Lực mô phỏng (tùy chọn nâng cao):** thanh trượt lực đẩy, độ dài liên kết, lực hút về tâm.

**g. Click node và modal (giữ nguyên luồng cũ)**
- **Click/chạm một node** mở **modal nhỏ**: mã môn (ví dụ `SWD392`), tên môn, số tín chỉ, nút **"Xem chi tiết"**, và các lối tắt **"Xem liên kết"**, **"Tư vấn môn này"**.
- Chỉ khi bấm "Xem chi tiết" mới chuyển sang Màn 3.
- Click ra ngoài modal thì đóng modal, quay lại graph, **không chuyển trang**, và giữ nguyên vị trí zoom/pan.

**h. Hiệu năng**
- Một curriculum có khoảng vài chục môn: đồ thị phải mượt (không giật) khi kéo, zoom và hover trên điện thoại thông thường.

**Gợi ý kỹ thuật (Flutter):** dùng mô phỏng lực (force-directed) vẽ bằng `CustomPainter` kết hợp `InteractiveViewer` cho zoom/pan, hoặc một thư viện graph có hỗ trợ bố cục lực; tự xử lý hit-test cho hover/kéo node. Dữ liệu node/cạnh sinh từ front matter `prerequisites` của các Subject (Mục 2.1).

### 4.4. Màn 3: Chi tiết Subject

- Đề cương, số tín chỉ, hình thức đánh giá (có PE hay không), learning outcomes, môn tiên quyết.
- Mục **"Xuất hiện trong"**: danh sách curriculum kèm học kỳ (ví dụ: `SE-K17, HK6`). Với dữ liệu hiện tại mỗi môn chỉ có một dòng, nhưng thiết kế phải hỗ trợ nhiều dòng (một môn có thể ở HK5 trong curriculum này và HK6 trong curriculum khác).
- Khung chat riêng phạm vi môn (Mục 5).
- Nút **"Tư vấn cách học môn này"** (Mục 7).

### 4.5. Bố cục học kỳ trực quan, dễ thao tác

Tab danh sách môn phải cho người dùng nhìn toàn bộ lộ trình một cách nhanh chóng:

- **Mỗi học kỳ là một cột/khối** sắp theo thứ tự HK1 → HKn (dạng board hoặc timeline ngang, cuộn ngang mượt; trên màn hẹp chuyển thành danh sách dọc có thể thu gọn/mở rộng từng kỳ).
- **Header mỗi kỳ** hiển thị: tên kỳ, số môn, tổng tín chỉ, và GPA kỳ đó (khi đã import bảng điểm).
- **Card môn** gọn: mã môn, tên, số tín chỉ. Có màu/biểu tượng trạng thái khi có bảng điểm: đã đạt, chưa đạt/học lại, đang học, chưa học. Môn không tính GPA có nhãn riêng.
- **Thanh điều hướng nhanh** (chip HK1…HKn) để nhảy tới kỳ cần xem; kỳ hiện tại của người dùng được làm nổi bật.
- **Thao tác nhanh:** bấm card để xem tóm tắt (giống modal ở Graph), bấm tiếp "Xem chi tiết" để sang Màn 3; giữ/hover vào môn thì làm nổi bật các môn tiên quyết và môn phụ thuộc.
- **Tìm kiếm và lọc** theo mã/tên môn, theo trạng thái, theo môn tính GPA hay không.
- **Nút "Tư vấn kỳ này"** ngay trên header mỗi kỳ để mở chiến lược học tập cho kỳ đó (Mục 7).
- Cùng một bộ dữ liệu với tab Map: chọn môn ở tab này thì tab Map làm nổi bật cùng môn và ngược lại.

---

## 5. Bước 4: Chat AI (RAG)

Chatbot có hai vai trò: (1) **hỏi đáp thông tin** dựa trên dữ liệu FLM đã trích xuất, không bịa ngoài nguồn; (2) **tư vấn học tập**: đưa ra giải pháp, cách học và chiến lược dựa trên tình hình thực tế của người dùng (GPA, bảng điểm). Vai trò (2) mô tả chi tiết ở Mục 5.3 và 7.

### 5.1. Hai cấp chat (scope)

| | Chat Curriculum | Chat Subject |
|---|---|---|
| Vị trí | Khung bên phải Màn 2 | Trong Màn 3 |
| Phạm vi RAG | Lọc theo `curriculum_id` | Lọc theo `subject_code` |
| Ví dụ | "Môn SWD392 học ở kỳ mấy trong khung này?", "HK5 có bao nhiêu tín chỉ?" | "Môn PRM392 có thi PE không?", "Mục tiêu môn học là gì?" |

Mỗi request chat gửi kèm `scope` (`curriculum` hoặc `subject`) và `id`. Backend dùng làm metadata filter khi truy xuất.

### 5.2. Câu hỏi mẫu phải trả lời được

- Hình thức thi/đánh giá: *Môn PRM392 có thi PE không?*
- Mục tiêu môn học (Learning Outcomes).
- Số tín chỉ: *Trong khung chương trình của tôi, PRM392 có mấy tín chỉ?*
- Kế hoạch học tập: *SWD392 học ở học kỳ mấy?*
- Môn này xuất hiện trong curriculum nào, học kỳ nào.

### 5.3. Tư vấn học tập bằng RAG

Ngoài hỏi đáp, chat phải trả lời được các câu hỏi về cách học và chiến lược, ví dụ:

- *Môn PRM392 nên học/ôn như thế nào để qua PE?*
- *Kỳ 5 của tôi có 5 môn, nên ưu tiên và phân bổ thời gian ra sao?*
- *GPA hiện tại của tôi là 7.4, muốn ra trường 8.0 thì cần làm gì từ giờ đến cuối?*

**Cách hoạt động:** RAG truy xuất phần liên quan trong dữ liệu FLM (đề cương, hình thức đánh giá, learning outcomes, tiên quyết, kế hoạch học tập) theo scope đang chọn, rồi ghép với **ngữ cảnh cá nhân** (bảng điểm, GPA hiện tại, mục tiêu, số môn đã học lại) để LLM viết lời khuyên. Các con số (GPA, điểm cần đạt, xếp loại) do code tính sẵn (Mục 6) và đưa vào prompt như dữ kiện, LLM không tự tính.

Khi chưa có bảng điểm, chat vẫn tư vấn cách học chung dựa trên đề cương và nhắc người dùng import bảng điểm để được chiến lược sát thực tế.

### 5.4. Chat phải trả lời động theo đúng dữ liệu đang xem, không phải kịch bản cứng

Yêu cầu chốt thêm sau góp ý của giảng viên: nếu chat chỉ lặp lại một số câu trả lời dựng sẵn giống nhau bất kể người dùng hỏi gì, sản phẩm mất lý do tồn tại so với việc đọc thẳng FLM.

- Chat phải truy xuất (RAG) đúng nội dung mà **màn hình đang mở đang hiển thị hoặc có thể hiển thị** (đề cương, tiên quyết, tín chỉ, học kỳ, bảng điểm/GPA nếu có), không giới hạn ở danh sách câu hỏi mẫu tại Mục 5.2 — danh sách đó là **tối thiểu phải trả lời đúng**, không phải toàn bộ phạm vi.
- Với câu hỏi ngoài phạm vi dữ liệu FLM đã trích xuất (không có trong RAG), chat phải nói rõ là không có dữ liệu, không bịa.
- Câu trả lời phải thay đổi theo `scope`/`id` gửi kèm (Mục 5.1): cùng một câu hỏi ("môn này có mấy tín chỉ") hỏi ở hai môn khác nhau phải ra hai câu trả lời khác nhau, không dùng chung một mẫu câu.

---

## 6. Quy chế tính điểm

Toàn bộ quy tắc nằm trong một file cấu hình `grading_rules.yaml`; đổi quy chế chỉ sửa một chỗ. Phần tính toán chạy bằng **code, không qua LLM**.

```yaml
gpa_scale: 10
excluded_from_gpa:            # khớp nếu mã đã chuẩn hóa == mục này HOẶC bắt đầu bằng mục này
  [GDQP, ENT, VOV, TRS, DSA, LAB, OJS, OJT, SYB301]
retake:
  counts_in_gpa: true         # môn học lại vẫn tính vào GPA
  gpa_policy: last_attempt    # chỉ lấy điểm lần học cuối cùng của mỗi môn
  penalty_threshold: 2        # học lại từ 2 môn trở lên
  penalty_levels: 1           # hạ 1 bậc
  applies_to: [Excellent, Good]
  count_excluded_subjects: true   # môn không tính GPA vẫn được đếm khi học lại
  count_grade_improvement: false  # học cải thiện điểm không tính là học lại
graduation_grades:            # GPA thang 10, cận dưới (>=)
  Excellent: 9.0
  Good: 8.0
  Fair: 6.5
  Pass: 5.0
```

### 6.1. GPA

- Thang 10, có trọng số theo tín chỉ: `GPA = Σ(điểm môn × tín chỉ) / Σ(tín chỉ tính GPA)`.
- Các mã trong `excluded_from_gpa` **không** đưa vào tử số và mẫu số của GPA, nhưng vẫn có tín chỉ và vẫn phải đạt để tốt nghiệp.
- Tách hai khái niệm: **tín chỉ tích lũy** (xét tốt nghiệp) và **tín chỉ tính GPA**.
- Khớp mã loại trừ sau khi chuẩn hóa (Mục 2.3), theo quy tắc **bằng mục trong danh sách hoặc bắt đầu bằng mục đó**. Một quy tắc này bao được cả trường hợp tiền tố (`ENT` khớp `ENT201`, `GDQP` khớp `GDQP1`) lẫn mã đầy đủ (`SYB301`).

### 6.2. Học lại

- Môn học lại **vẫn tính vào GPA**, và GPA chỉ lấy **điểm lần học cuối cùng** của mỗi môn (các lần trước không đưa vào tử số và mẫu số).
- Phân biệt hai trường hợp khi một mã môn xuất hiện từ 2 lần trở lên (lần cuối xác định theo thứ tự học kỳ):
  - **Học lại:** các lần trước đó có lần **chưa đạt** (rớt). Được đếm vào số môn học lại để xét hạ bậc.
  - **Học cải thiện điểm:** lần trước đã đạt, học lại để nâng điểm. **Không** được đếm là học lại, nên không gây hạ bậc.
- Số môn học lại để xét hạ bậc **tính cả các môn thuộc danh sách không tính GPA** (ví dụ học lại `VOV` vẫn được đếm), dù các môn này không ảnh hưởng đến con số GPA.
- Nếu học lại **từ 2 môn trở lên**, xếp loại tốt nghiệp **Giỏi hoặc Xuất sắc** bị **hạ 1 bậc**.

| Số môn đã học lại | Xếp loại thực nhận |
|---|---|
| 0 hoặc 1 | Đúng theo GPA |
| Từ 2 trở lên | Nếu Giỏi/Xuất sắc thì hạ 1 bậc |

### 6.3. Xếp loại tốt nghiệp

Theo GPA thang 10 (chưa trừ bậc học lại):

| Loại | Điều kiện GPA |
|---|---|
| Xuất sắc | ≥ 9.0 |
| Giỏi | ≥ 8.0 |
| Khá | ≥ 6.5 |
| Trung bình | ≥ 5.0 |

Nếu học lại từ 2 môn trở lên: Xuất sắc hạ thành Giỏi, Giỏi hạ thành Khá. Khá và Trung bình không bị ảnh hưởng.

### 6.4. Điểm cần đạt cho mục tiêu

```
điểm TB cần đạt ở các môn còn lại =
  (GPA mục tiêu × tổng tín chỉ tính GPA cuối cùng − Σ(điểm × tín chỉ) đã có)
  / tổng tín chỉ tính GPA còn lại
```

Nếu kết quả lớn hơn 10, mục tiêu **không khả thi** và app phải báo rõ, không gợi ý sai. Khi đánh giá mục tiêu, phải xét cả xếp loại thực nhận sau khi trừ bậc do học lại.

---

## 7. Bước 5: Import bảng điểm và tư vấn chiến lược

Đặt ở màn Curriculum. Đây là tính năng mới, làm sau cùng.

### 7.1. Import bảng điểm bằng ảnh chụp

**Yêu cầu quan trọng:** ảnh bảng điểm có thể ở **nhiều dạng khác nhau**, không có mẫu cố định. Vì vậy bước trích xuất phải dùng **mô hình đa phương thức (vision LLM) tổng quát**, không dựa vào template hay tọa độ cố định. Hệ thống phải đọc được ít nhất các dạng:

- Ảnh chụp màn hình (screenshot) trang điểm trên web/app của trường.
- Ảnh chụp bằng điện thoại: chụp nghiêng, có phản chiếu, mờ, thiếu sáng.
- Bảng in trên giấy, bảng có dòng kẻ hoặc không kẻ, bố cục nhiều cột/nhiều kỳ trên cùng một ảnh.
- Một bảng điểm trải trên **nhiều ảnh** (cho phép tải nhiều ảnh cho một lần import).

**Luồng xử lý:**

1. Người dùng tải một hoặc nhiều ảnh bảng điểm.
2. Backend gửi ảnh cho vision LLM với prompt yêu cầu trả về **JSON theo schema cố định**, bất kể ảnh dạng nào: danh sách `{course_code, score, semester, status}`, kèm độ tin cậy (`confidence`) cho từng dòng.
3. **Hậu xử lý bằng code:** chuẩn hóa mã môn (Mục 2.3), chuẩn hóa số điểm (dấu phẩy/dấu chấm), loại dòng trùng giữa các ảnh, gộp các lần học của cùng một môn.
4. **Màn hình xác nhận bắt buộc:** hiển thị bảng đọc được, đánh dấu nổi bật các dòng có độ tin cậy thấp hoặc mã không khớp, để người dùng kiểm tra và sửa tay trước khi lưu. Không được bỏ bước này vì một chữ số sai làm sai toàn bộ GPA và lời khuyên.
5. **Đối chiếu với FLM:** mã môn phải khớp mã trong curriculum (để lấy tín chỉ, học kỳ, tiên quyết). Mã không khớp thì đánh dấu để người dùng sửa.
6. **Dự phòng:** cho phép nhập/sửa điểm thủ công (ảnh quá mờ hoặc đọc sai nhiều).

### 7.2. Đầu vào tư vấn

- Mục tiêu GPA (thang 10), ví dụ 8.0.
- Phạm vi tư vấn: cả curriculum, một học kỳ, hoặc một môn.

### 7.3. Đầu ra: giải pháp học tập và chiến lược theo tình hình thực tế

Chiến lược dựa trên GPA và bảng điểm thực tế của người dùng, ở **3 mức phạm vi**. Người dùng chọn mức bằng nút "Tư vấn" ở card môn, header học kỳ, hoặc khu vực Bảng điểm & Chiến lược của curriculum.

**Mức 1: Theo môn**
- Gợi ý **cách học/ôn** cho môn dựa trên hình thức đánh giá (PE/FE/assignment/quiz) và learning outcomes.
- Chỉ ra kiến thức tiên quyết còn yếu (theo điểm các môn tiên quyết) cần ôn trước.
- Nêu điểm tối thiểu cần đạt ở môn này để giữ hoặc đạt mục tiêu GPA.

**Mức 2: Theo học kỳ** (ví dụ HK5 có 5 môn)
- Chiến lược cả kỳ thay vì xem từng môn rời rạc: thứ tự ưu tiên, phân bổ thời gian giữa các môn, môn nào cần đầu tư nhiều nhất theo tín chỉ và độ khó.
- Có nên đăng ký đủ môn hay giảm tải, dựa trên GPA hiện tại và số môn đang có nguy cơ học lại.
- Cần chuẩn bị gì trước kỳ học (môn nền, kỹ năng, tài liệu).

**Mức 3: Toàn lộ trình (từ đầu đến cuối)**
- Tổng quan các kỳ còn lại: mục tiêu điểm trung bình từng kỳ để đạt GPA mong muốn khi ra trường.
- Môn nào nên học lại hoặc cải thiện điểm để tăng GPA hiệu quả nhất (điểm thấp, tín chỉ cao, tính GPA).
- Phân biệt rõ với người dùng: học cải thiện điểm không bị tính là học lại nên không gây hạ bậc, còn học lại môn đã rớt thì có (kể cả môn không tính GPA).
- Cảnh báo học lại: ví dụ đã học lại 1 môn và nhắm loại Giỏi, báo *"học lại thêm 1 môn nữa sẽ bị hạ bậc"*.
- Nếu mục tiêu không khả thi (điểm cần đạt lớn hơn 10), báo rõ và đề xuất mục tiêu thực tế hơn.

**Định dạng kết quả:** rõ ràng, có cấu trúc (tóm tắt tình hình hiện tại, mục tiêu, các bước hành động ưu tiên), có thể lưu lại và xem lại trong app.

### 7.4. Phân vai tính toán và LLM

- **Code:** GPA, điểm cần đạt, kiểm tra tiên quyết, xét ngưỡng học lại. Kết quả chính xác, được đưa vào prompt như dữ kiện.
- **RAG + LLM:** truy xuất thông tin môn học từ FLM và viết giải pháp, cách học, chiến lược bằng ngôn ngữ tự nhiên dựa trên dữ kiện trên.

---

## 8. Kiến trúc và yêu cầu phi chức năng

### 8.1. Kiến trúc

- **Frontend:** Flutter.
- **Backend:** Python (FastAPI), xử lý RAG, gọi LLM, đọc ảnh bảng điểm.
- Kết nối qua RESTful API.

### 8.2. Riêng tư

- Bảng điểm là dữ liệu cá nhân: **lưu local** trên thiết bị, **không đưa vào Obsidian/RAG chung**, tách khỏi kho tri thức FLM.
- Ảnh bảng điểm chứa tên và MSSV: chỉ gửi lên backend để trích xuất, **không lưu ảnh trên server**. Thông báo cho người dùng biết ảnh được gửi đi xử lý.
- Khi gọi tư vấn, chỉ gửi phần dữ liệu cần thiết.

### 8.3. Khả năng mở rộng

- Danh sách curriculum đọc từ dữ liệu; thêm curriculum không cần sửa code.
- Quy chế nằm trong `grading_rules.yaml`.

### 8.4. Chất lượng UI (áp dụng cho toàn app, không chỉ Graph View)

Bổ sung sau góp ý trực tiếp của giảng viên về bản cũ ("chữ và ô hiển thị quá nhỏ", "nút không di chuyển linh hoạt", "không highlight lúc di chuột"):

- **Cỡ chữ và vùng hiển thị**: text và các ô/card (card môn, card curriculum, nhãn node...) phải đủ lớn để đọc được ở kích thước cửa sổ desktop thông thường, không co cụm; ưu tiên co giãn theo kích thước màn hình thay vì cố định pixel nhỏ.
- **Vùng bấm/kéo linh hoạt**: các nút, node, card phải có vùng chạm đủ lớn và phản hồi ngay khi bấm/kéo; node trên Graph View kéo được mượt như mô tả ở Mục 4.3.b, không bị giật hoặc "dính" ở vị trí cũ.
- **Hiệu ứng hover bắt buộc** trên desktop cho mọi phần tử có thể tương tác (card môn, card curriculum, node, nút trong bảng điều khiển...): đổi màu/viền/bóng rõ ràng khi rê chuột qua, không chỉ riêng node trong Graph View (Mục 4.3.d).
- Yêu cầu này là tiêu chí nghiệm thu chung, áp dụng khi review từng màn hình ở Mục 4, không phải một mục riêng biệt cần code tách rời.

---

## 9. Các điểm đã chốt với giảng viên

- Mã loại trừ GPA: khớp cả tiền tố lẫn mã đầy đủ.
- Môn học lại: GPA lấy điểm lần học cuối.
- Ngưỡng GPA: Trung bình ≥ 5, Khá ≥ 6.5, Giỏi ≥ 8, Xuất sắc ≥ 9.
- Ảnh bảng điểm có nhiều dạng: dùng vision LLM tổng quát.
- Học cải thiện điểm **không** tính là học lại.
- Môn học lại thuộc danh sách không tính GPA **vẫn được đếm** vào số môn học lại để xét hạ bậc.

Hiện không còn câu hỏi mở.

---

## 10. Tiêu chí nghiệm thu

- [ ] Trích xuất được curriculum và toàn bộ subject sang `.md` với front matter đúng.
- [ ] Obsidian Graph hiển thị đúng liên kết tiên quyết và học kỳ.
- [ ] Màn 1 hiển thị card curriculum (tên, số HK, số môn, số tín chỉ).
- [ ] Màn 2 có 3 tab và khung chat bên phải; Màn 3 có mục "Xuất hiện trong".
- [ ] Graph động kiểu Obsidian: bố cục lực, kéo node, zoom/pan mượt, nhãn theo mức zoom.
- [ ] Hover/chọn node làm nổi bật node và liên kết trực tiếp, làm mờ phần còn lại; phân biệt tiên quyết và phụ thuộc.
- [ ] Có tìm kiếm, bộ lọc, chế độ xem cục bộ theo độ sâu, nút "Sắp xếp theo học kỳ", Reset và Vừa màn hình.
- [ ] Click node ra modal, "Xem chi tiết" mới chuyển trang, click ngoài đóng modal và giữ nguyên vị trí graph.
- [ ] Chat curriculum và chat subject trả lời đúng các câu hỏi mẫu (Mục 5.2).
- [ ] Import ảnh bảng điểm có bước xác nhận/sửa tay; nhập thủ công hoạt động.
- [ ] Bố cục học kỳ trực quan: cột/khối theo kỳ, trạng thái môn, điều hướng nhanh, tìm kiếm/lọc (Mục 4.5).
- [ ] Chat/tư vấn đưa ra cách học và chiến lược theo môn, theo kỳ và toàn lộ trình, dựa trên GPA thực tế.
- [ ] GPA loại đúng các mã không tính điểm (cả tiền tố lẫn mã đầy đủ) và chỉ lấy điểm lần học cuối.
- [ ] Xếp loại đúng theo ngưỡng 5 / 6.5 / 8 / 9; hạ 1 bậc với Giỏi/Xuất sắc khi học lại từ 2 môn; cảnh báo trước khi bị hạ bậc.
- [ ] Phân biệt học lại (đã rớt) và học cải thiện (đã đạt); chỉ học lại được đếm để hạ bậc, kể cả môn không tính GPA.
- [ ] Đọc được bảng điểm từ nhiều dạng ảnh (screenshot, ảnh điện thoại, ảnh giấy, nhiều ảnh) và luôn qua bước xác nhận.
- [ ] Mục tiêu GPA không khả thi thì báo rõ.
- [ ] Đi được trọn mạch Màn 1 → Màn 2 (tổng quan → học kỳ/Map) → Màn 3 → Chat mà không mất ngữ cảnh; chat tự đổi scope theo màn đang mở (Mục 4.0).
- [ ] Toàn app (không chỉ Map): chữ/card đủ lớn, nút/card có hover rõ ràng, kéo-thả mượt (Mục 8.4).
- [ ] Chat trả lời đúng theo đúng dữ liệu của scope/id đang mở, không trả lời giống nhau cho các môn/curriculum khác nhau (Mục 5.4).

---

## 11. Chia task cho 5 thành viên

> Chia theo 5 khối công việc bám sát quy trình 5 bước ở Mục 1, cân đối độ khó, độ phụ thuộc dữ liệu và mức độ mơ hồ kỹ thuật. Khánh nhận khối **A — dữ liệu**, vì đây là phần đặc tả rõ ràng nhất (input/output cố định là HTML → Markdown + YAML theo đúng schema Mục 2.1, không phụ thuộc UI/AI, ít việc "tùy biến cảm tính"), phù hợp làm nền cho 4 khối còn lại.

### Khối A — Trích xuất dữ liệu & Obsidian — **Khánh**
*(Bước 1 + Bước 2, Mục 2, 3)*

- Viết script trích HTML FLM (Curriculum + Syllabus) → file `.md` có YAML front matter đúng schema Subject/Curriculum (Mục 2.1).
- Chuẩn hóa mã môn (Mục 2.3): viết hoa, bỏ khoảng trắng, gộp `Ð`/`Đ`.
- Sinh quan hệ `appears_in` (curriculum ↔ subject ↔ semester), set cờ `counts_in_gpa` dựa trên `grading_rules.yaml` (khối E cung cấp file này sớm để không chặn tiến độ).
- Cài Obsidian, đưa toàn bộ `.md` vào, dựng liên kết `[[...]]` tiên quyết hai chiều, cấu hình Graph View gốc (màu theo học kỳ, size theo số liên kết) — dùng làm bản đối chiếu cho khối C.
- Viết hàm/API nội bộ cho thống kê: số học kỳ/môn/tín chỉ của 1 curriculum, "môn X xuất hiện ở đâu", kiểm tra tiên quyết (Mục 2.2) — các khối B, C, D, E gọi lại hàm này, không tự tính riêng.
- **Đầu ra bàn giao:** thư mục `.md` chuẩn, Obsidian vault mẫu, module thống kê dùng chung.

### Khối B — Khung Flutter & 2 màn nền + bố cục học kỳ — **Vương**
*(Bước 3 — Mục 4.0, 4.1, 4.2 khung tab, 4.4, 4.5)*

- Màn 1: danh sách card curriculum (tên, số HK, số môn, tổng tín chỉ), đọc từ dữ liệu khối A, không hard-code.
- Màn 2: dựng khung 3 tab (Tổng quan / Danh sách môn / Map — nội dung tab Map do khối C làm) + khung chat cố định bên phải (nội dung chat do khối D làm, Vương chỉ dựng khung UI + truyền `scope`/`id`).
- Tab "Danh sách môn" theo Mục 4.5: cột/khối theo học kỳ, header kỳ (tên, số môn, tín chỉ, GPA nếu có), card môn, chip điều hướng nhanh HK1…HKn, tìm kiếm/lọc, nút "Tư vấn kỳ này" (mở modal/khu vực do khối E cung cấp nội dung).
- Màn 3: đề cương, tín chỉ, đánh giá, learning outcomes, tiên quyết, mục "Xuất hiện trong" (nhiều dòng), khung chat subject (khung UI, nội dung do khối D), nút "Tư vấn cách học môn này".
- Đảm bảo mạch liên tục Mục 4.0: giữ trạng thái khi back, chat tự đổi scope theo màn đang mở.
- Áp dụng chuẩn UI Mục 8.4 (cỡ chữ, hover, vùng bấm) cho toàn bộ 3 màn mình dựng — đây là chuẩn chung cả nhóm phải theo, Vương làm mẫu trước cho các khối khác tham chiếu.
- **Đầu ra bàn giao:** Màn 1, khung Màn 2 (3 tab rỗng nội dung Map/Chat, có hook để khối C/D gắn vào), Màn 3, style/theme dùng chung cho cả app.

### Khối C — Graph View động kiểu Obsidian (tab Map) — **Bảo**
*(Mục 4.3 — toàn bộ)*

- Dựng đồ thị lực (force-directed) bằng `CustomPainter` + `InteractiveViewer` (hoặc thư viện graph có layout lực).
- Node theo môn (màu theo học kỳ, size theo số liên kết), cạnh tiên quyết có mũi tên hướng, chú giải màu luôn hiện.
- Chuyển động mượt, kéo node kéo theo liên kết rồi tự ổn định; nút "Sắp xếp theo học kỳ", "Reset", "Vừa màn hình".
- Zoom/pan, nhãn hiện theo mức zoom.
- Hover/chọn node: highlight node + liên kết trực tiếp, mờ phần còn lại, phân biệt màu tiên quyết/phụ thuộc, chức năng "Chuỗi tiên quyết".
- Local graph theo N cấp (slider 1–3), bảng điều khiển thu gọn được: tìm kiếm, bộ lọc (kỳ, trạng thái, GPA, tiên quyết, node cô lập), hiển thị (nhãn/mũi tên/độ dày/size), lực mô phỏng nâng cao.
- Modal khi click node (mã, tên, tín chỉ, "Xem chi tiết", "Xem liên kết", "Tư vấn môn này"), click ngoài đóng modal không đổi trang, giữ zoom/pan.
- Đồng bộ chọn môn hai chiều với tab "Danh sách môn" (khối B).
- Tối ưu để mượt với vài chục node trên desktop (Mục 4.3.h).
- **Đầu ra bàn giao:** widget Graph View hoàn chỉnh, lắp vào tab Map do khối B chừa sẵn.

### Khối D — Backend & Chat AI RAG — **Khôi**
*(Bước 4, Mục 5 toàn bộ + phần API nền cho khối E)*

- Backend FastAPI, endpoint chat nhận `scope` (`curriculum`/`subject`) + `id`, dùng làm metadata filter khi retrieve.
- Xây pipeline RAG trên dữ liệu `.md` của khối A (embedding, index, retrieval theo filter).
- Đảm bảo trả lời đúng bộ câu hỏi mẫu Mục 5.2, và đáp ứng yêu cầu Mục 5.4 (trả lời động theo đúng dữ liệu đang mở, không kịch bản cứng, từ chối rõ ràng khi ngoài phạm vi dữ liệu).
- Thiết kế endpoint/prompt để nhận thêm "dữ kiện đã tính sẵn bằng code" (GPA, điểm cần đạt, xếp loại...) do khối E đưa vào, dùng cho tư vấn học tập (Mục 5.3, 7.4) — khối D chỉ cần chỗ cắm dữ liệu, không tự tính GPA.
- **Đầu ra bàn giao:** API chat RESTful hoạt động theo 2 scope, sẵn sàng để khối B gắn UI khung chat vào và khối E gắn thêm ngữ cảnh cá nhân.

### Khối E — Bảng điểm, GPA & Tư vấn chiến lược — **Phúc**
*(Bước 5, Mục 6 + Mục 7 toàn bộ — làm sau cùng vì phụ thuộc A, B, D)*

- Viết `grading_rules.yaml` sớm và gửi cho khối A dùng (Mục 6, cần có trước để khối A gắn `counts_in_gpa`).
- Code tính GPA có trọng số tín chỉ, loại trừ đúng theo tiền tố/mã đầy đủ, lấy điểm lần học cuối, phân biệt học lại vs cải thiện điểm, xét hạ bậc, xếp loại theo ngưỡng, điểm cần đạt cho mục tiêu và báo mục tiêu bất khả thi (Mục 6.1–6.4). Toàn bộ bằng code, không qua LLM.
- Import bảng điểm bằng ảnh (vision LLM, nhiều dạng ảnh, nhiều ảnh một lần), hậu xử lý (chuẩn hóa mã/điểm, gộp trùng), màn xác nhận/sửa tay bắt buộc, đối chiếu mã với dữ liệu khối A, nhập tay dự phòng (Mục 7.1).
- Tư vấn 3 mức (môn / kỳ / toàn lộ trình) theo Mục 7.3: tính dữ kiện bằng code rồi gửi cho khối D ghép vào prompt RAG (Mục 7.4) — Phúc phối hợp với Khôi để thống nhất format "dữ kiện" gửi kèm.
- Gắn các điểm vào UI mà khối B đã chừa sẵn: khu vực "Bảng điểm & Chiến lược" ở Màn 2, nút "Tư vấn kỳ này"/"Tư vấn môn này"/"Tư vấn môn này" trong modal graph.
- Đảm bảo riêng tư: bảng điểm lưu local, ảnh không lưu server, chỉ gửi phần dữ liệu cần thiết khi gọi tư vấn (Mục 8.2).
- **Đầu ra bàn giao:** `grading_rules.yaml`, module tính điểm/xếp loại, luồng import ảnh + xác nhận, tính năng tư vấn 3 mức chạy được trong UI.

### Phụ thuộc & thứ tự gợi ý

1. Khánh (A) chạy trước để có dữ liệu `.md` + module thống kê cho mọi người dùng chung; đồng thời gửi `grading_rules.yaml` sớm nếu Phúc soạn trước.
2. Vương (B) dựng khung 3 màn ngay khi có dữ liệu mẫu từ Khánh, chừa sẵn chỗ cho Bảo (Map) và Khôi (Chat).
3. Bảo (C) và Khôi (D) làm song song sau khi có khung từ Vương và dữ liệu từ Khánh.
4. Phúc (E) làm sau cùng, cần A (dữ liệu), B (chỗ gắn UI), D (chỗ cắm dữ kiện vào prompt) đã có phần khung trước.
