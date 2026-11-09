# BÁO CÁO TIẾN ĐỘ & KIỂM THỬ: KHỐI D (KHÔI)

> **Dự án:** Hệ thống Obsidian & Chat AI Môn Học (FLM) — Lab 1  
> **Tài liệu tham chiếu:** [`requirement_flm_obsidian_chat_v7.md`](file:///c:/AK/HOCKI8/PRM393/LAB1/ChatAIProject_Khoi/requirement_flm_obsidian_chat_v7.md)  
> **Thành viên phụ trách:** **Khôi**  
> **Nhiệm vụ:** **Khối D — Backend & Chat AI RAG** (Bước 4, Mục 5 toàn bộ + phần API nền cho Khối E và module dùng chung Mục 2.2/11)  
> **Cập nhật lần cuối:** 2026-09-27  
> **Nhánh git:** `PRM-dev`  
> **Trạng thái:** **HOÀN THÀNH GIAI ĐOẠN 1 (Kiến trúc RAG, Contract API, Fallback Engine & Test Suite: 36/36 PASS) — SẴN SÀNG CHO GIAI ĐOẠN 2 (Tích hợp Live LLM & App Flutter)**

---

## 1. Tổng quan công việc đã thực hiện

Bám sát đặc tả **Phiên bản 7 (v7)** từ buổi họp nhóm và góp ý của giảng viên hướng dẫn, Khôi đã hoàn thành khối lượng công việc được phân công tại **Mục 11 (Khối D)** và các mục liên quan:

1. **Chuẩn hóa Backend FastAPI RAG Engine**:
   - Thiết kế Endpoint Chat `/api/v1/chat` hỗ trợ đầy đủ 2 cấp độ hội thoại (`curriculum` và `subject`) với trường `scope` và `id` làm metadata filter.
   - Thiết kế cơ chế cắm dữ kiện học tập (`student_context`) nhận các số liệu do code Khối E tính toán sẵn (GPA hiện tại, điểm mục tiêu, số môn học lại, điểm trung bình cần đạt).
2. **Khắc phục triệt để lỗi vòng đời HTTP Client**:
   - Tối ưu hóa vòng đời `httpx.AsyncClient` liên kết trực tiếp với active `asyncio` event loop, tự động phục hồi khi chạy nhiều session / test suite độc lập.
3. **Phân tích dữ liệu Curriculum Vault**:
   - Nâng cấp `FLMKnowledgeVaultParser` hỗ trợ parse toàn diện thư mục `flm_knowledge_vault/curricula/*.md` (chương trình chuẩn `BIT_SE_K19B.md`).
   - Trích xuất đúng thuộc tính `appears_in`, `has_pe`, `counts_in_gpa`, `in_curriculum`.
4. **Đáp ứng toàn bộ bộ câu hỏi mẫu (Mục 5.2)**:
   - Kiểm tra PE exam, chuẩn đầu ra (LOs), số tín chỉ, học kỳ đề xuất, môn xuất hiện ở đâu.
5. **Tư vấn học tập động & Actionable (Mục 5.3)**:
   - Chiến lược ôn thi PE cho môn lập trình (PRM393, PRN212).
   - Chiến lược phân bổ thời gian và thứ tự ưu tiên học kỳ (Học kỳ 5: SWP391 40%, PRN212 25%, SWT301 15%, SWR302 10%, WDU203c 10%).
   - Chiến lược nâng điểm GPA tích hợp quy chế đào tạo FPTU (cảnh báo hạ bậc tốt nghiệp từ Giỏi xuống Khá khi học lại từ 2 môn trở lên).
6. **Cơ chế từ chối ngoài phạm vi (Mục 5.4)**:
   - Với câu hỏi ngoài phạm vi dữ liệu FLM (nấu ăn, bóng đá, thời tiết...), hệ thống từ chối lịch sự, nói rõ không có dữ liệu trong FLM, tuyệt đối không bịa đặt.
7. **Module thống kê dùng chung (Mục 2.2 & 11)**:
   - Thống kê curriculum (tổng học kỳ, số môn, tổng tín chỉ 145, số tín chỉ từng kỳ).
   - Tra cứu môn học xuất hiện ở curriculum và học kỳ nào.
   - Hàm và API kiểm tra điều kiện tiên quyết (`check-prerequisites`).

---

## 2. Minh bạch kỹ thuật: Cơ chế hoạt động của RAG Engine

Để đảm bảo tính trung thực và khách quan cao nhất trong báo cáo học thuật, Khối D phân định rõ hai tầng xử lý hiện tại của hệ thống:

```
[User / Flutter Request]
           │
           ▼
   [POST /api/v1/chat]
           │
           ▼
   [RAG Scope Routing] (curriculum vs subject)
           │
           ▼
[Kiểm tra Active Provider trong LLMService]
      ├──> (Nếu có GEMINI_API_KEY / OPENAI_API_KEY / GROQ_API_KEY hoặc Ollama local)
      │     └──> [LIVE LLM RAG MODE]
      │           - Vector Hybrid Retrieval (BM25 + Semantic Embeddings)
      │           - Inject context FLM Markdown + student_context
      │           - System Prompt chuẩn hóa tiếng Việt, ép trích nguồn & Guardrails
      │
      └──> (Nếu chạy CI/CD, máy dev không có key, hoặc offline)
            └──> [FALLBACK: FLM-Advanced-Synthesizer]
                  - Trích xuất dữ liệu bóc tách trực tiếp từ Vault Markdown
                  - Định dạng cấu trúc câu trả lời động theo metadata môn/kỳ
                  - Nhận diện intent và từ chối ngoài phạm vi bằng rule-based/regex
```

### Điểm mạnh:
- **Độ tin cậy cao trong kiểm thử:** Khi chạy unit test và CI/CD không có kết nối internet hoặc API key, toàn bộ 36 tests vẫn chạy độc lập và xác minh tính toàn vẹn của API schema, scope routing, dữ liệu curriculum và định dạng câu trả lời.
- **Không gây crash khi mất mạng:** Nếu gọi LLM cloud bị rate limit hoặc mất kết nối, hệ thống tự động fallback mượt mà.

### Các giới hạn kỹ thuật đang tồn tại:
1. **Bộ lọc ngoài phạm vi (Out-of-scope filter):** Ở chế độ fallback, hệ thống đang dùng danh sách từ khóa heuristic (`out_of_scope_keywords`). Để lọc ngữ nghĩa các câu hỏi lắt léo ngoài đời thực, cần chạy ở chế độ Live LLM với guardrail prompt.
2. **Khả năng suy luận mở:** Bộ Synthesizer hoạt động dựa trên cấu trúc dữ liệu đã bóc tách từ FLM, trả lời rất chính xác về số liệu (tín chỉ, LO, PE, tiên quyết) nhưng sự linh hoạt câu chữ sẽ không tự nhiên bằng Live LLM.

---

## 3. Chi tiết các module đã nâng cấp & phát triển

| Tệp tin | Vị trí | Nội dung hoàn thành |
|---|---|---|
| [`chat.py`](file:///c:/AK/HOCKI8/PRM393/LAB1/ChatAIProject_Khoi/backend/app/schemas/chat.py) | `backend/app/schemas/chat.py` | Bổ sung `StudentContext`, trường `student_context` trong `ChatRequest` để nhận dữ kiện từ Khối E. |
| [`course.py`](file:///c:/AK/HOCKI8/PRM393/LAB1/ChatAIProject_Khoi/backend/app/schemas/course.py) | `backend/app/schemas/course.py` | Bổ sung `appears_in`, `has_pe`, `counts_in_gpa`, `in_curriculum` vào `CourseDetail`; thêm `CurriculumStats`, `SemesterStat`, `PrerequisiteCheckResult`. |
| [`flm_parser.py`](file:///c:/AK/HOCKI8/PRM393/LAB1/ChatAIProject_Khoi/backend/app/services/flm_parser.py) | `backend/app/services/flm_parser.py` | Parse `curricula/BIT_SE_K19B.md`, tạo chunk tổng quan chương trình và học kỳ; bổ sung `get_curriculum_stats`, `get_course_presence`, `check_prerequisites`. |
| [`vector_store.py`](file:///c:/AK/HOCKI8/PRM393/LAB1/ChatAIProject_Khoi/backend/app/services/vector_store.py) | `backend/app/services/vector_store.py` | Thêm intent `curriculum`, `course_presence`, nhận diện tín chỉ theo học kỳ, boost chunk curriculum khi truy vấn scope curriculum. |
| [`llm_service.py`](file:///c:/AK/HOCKI8/PRM393/LAB1/ChatAIProject_Khoi/backend/app/services/llm_service.py) | `backend/app/services/llm_service.py` | Tối ưu lifecycle `AsyncClient`; sinh câu trả lời động; lọc ngoài phạm vi; tư vấn học tập 3 mức; tích hợp `student_context` vào cả cloud LLM prompt và Fallback Synthesizer. |
| [`rag_engine.py`](file:///c:/AK/HOCKI8/PRM393/LAB1/ChatAIProject_Khoi/backend/app/services/rag_engine.py) | `backend/app/services/rag_engine.py` | Điều phối scope routing; truyền `student_context`, `all_courses`, `curriculum_info`; expose các phương thức thống kê dùng chung. |
| [`courses.py`](file:///c:/AK/HOCKI8/PRM393/LAB1/ChatAIProject_Khoi/backend/app/api/v1/endpoints/courses.py) | `backend/app/api/v1/endpoints/courses.py` | Thêm endpoint RESTful: `/curricula/{id}/stats`, `/courses/{code}/presence`, `/courses/{code}/check-prerequisites`. |
| [`test_v7_scenarios.py`](file:///c:/AK/HOCKI8/PRM393/LAB1/ChatAIProject_Khoi/backend/tests/test_v7_scenarios.py) | `backend/tests/test_v7_scenarios.py` | Bộ test suite 16 kịch bản kiểm thử toàn diện mọi yêu cầu v7 của Khối D. |
| [`test_api_endpoints.py`](file:///c:/AK/HOCKI8/PRM393/LAB1/ChatAIProject_Khoi/backend/tests/test_api_endpoints.py) | `backend/tests/test_api_endpoints.py` | Bổ sung test kiểm thử các endpoint API thống kê mới. |

---

## 4. Bảng đối chiếu tiêu chí nghiệm thu v7

| Mục | Nội dung yêu cầu trong bản v7 | Trạng thái hiện tại | Minh chứng kiểm thử |
|---|---|:---:|---|
| **Mục 5.1** | Hai cấp chat (`curriculum` vs `subject`), tự lọc metadata filter | **ĐẠT (Contract & Logic)** | `test_curriculum_scope_semester_credits`, `test_curriculum_scope_total_credits` |
| **Mục 5.2** | Hỏi hình thức thi PE: *Môn PRM393 có thi PE không?* | **ĐẠT (Data & Format)** | `test_sample_q1_pe_exam_assessment` (Trả lời có thi thực hành PE) |
| **Mục 5.2** | Chuẩn đầu ra: *Mục tiêu của môn học PRM393 là gì?* | **ĐẠT (Data & Format)** | `test_sample_q2_learning_outcomes` (Trích xuất các LOs/CLOs chuẩn) |
| **Mục 5.2** | Số tín chỉ: *Trong khung chương trình của tôi, PRM393 có mấy tín chỉ?* | **ĐẠT (Data & Format)** | `test_sample_q3_credits` (Trả lời chính xác 3 tín chỉ) |
| **Mục 5.2** | Kế hoạch học tập: *Môn SWD392 học ở học kỳ mấy?* | **ĐẠT (Data & Format)** | `test_sample_q4_semester_roadmap` (Học kỳ 7 trong BIT_SE_K19B) |
| **Mục 5.2** | Môn này xuất hiện trong curriculum nào, học kỳ nào | **ĐẠT (Data & Format)** | `test_sample_q5_course_presence` (Xuất hiện ở BIT_SE_K19B, HK8) |
| **Mục 5.3** | *Môn PRM393 nên học/ôn như thế nào để qua PE?* | **ĐẠT (Logic & Heuristic)** | `test_advising_pe_study_strategy` (Chiến lược code thực hành, test bài Lab) |
| **Mục 5.3** | *Kỳ 5 của tôi có 5 môn, nên ưu tiên và phân bổ thời gian ra sao?* | **ĐẠT (Logic & Heuristic)** | `test_advising_semester_5_prioritization` (SWP391 40%, PRN212 25%...) |
| **Mục 5.3** | *GPA hiện tại 7.4, muốn ra trường 8.0 thì cần làm gì?* | **ĐẠT (Hook & Calculation)** | `test_advising_gpa_improvement_goal` (Điểm TB cần đạt, quy chế hạ bậc) |
| **Mục 5.4** | Trả lời động: cùng câu hỏi ở 2 môn khác nhau ra kết quả khác nhau | **ĐẠT (Dynamic Scope)** | `test_dynamic_answers_per_subject` (PRM393: 3 TC vs OJT202: 10 TC) |
| **Mục 5.4** | Từ chối câu hỏi ngoài phạm vi dữ liệu FLM, không bịa | **ĐẠT (Keyword Filter)** | `test_out_of_scope_rejection` (Từ chối "môn nấu ăn", "thời tiết"...) |
| **Mục 7.4** | Nhận diện dữ kiện đã tính bằng code (`student_context` từ Khối E) | **ĐẠT (Data Contract)** | `test_student_context_integration` (Tích hợp GPA, target, retake count) |
| **Mục 2.2/11** | Module thống kê: số học kỳ/môn/tín chỉ, môn xuất hiện ở đâu, tiên quyết | **ĐẠT (API & Schema)** | `test_common_curriculum_stats`, `test_common_course_presence`, `test_common_prerequisite_check` |

---

## 5. Kết quả thực thi kiểm thử tự động (Test Execution Logs)

### 5.1. Kiểm thử toàn bộ Backend Unit Tests (`backend/tests/`)
Chạy lệnh kiểm thử tự động:
```bash
python -m unittest discover -s backend/tests
```
**Kết quả:**
```text
Ran 36 tests in 11.595s

OK
```
**Phân bổ kết quả:**
- `TestAPIEndpoints`: **10/10 tests PASS** (Health check, Course list, Course detail, Chat endpoint, Prompt alias, Empty validation, Curricula stats endpoint, Course presence endpoint, Prerequisite check endpoint).
- `TestFLMParser`: **3/3 tests PASS** (Parse markdown vault, trích xuất cấu trúc đề cương, bóc tách metadata).
- `TestVectorStore`: **3/3 tests PASS** (Trích xuất mã môn, nhận diện đa ý định query, tìm kiếm hybrid BM25 + Intent boost).
- `TestRAGPipeline`: **4/4 tests PASS** (Truy xuất và tổng hợp câu trả lời end-to-end).
- `TestV7RequirementsKhoi`: **16/16 tests PASS** (Xác nhận sự tương thích với 16 kịch bản kiểm thử quy định tại Mục 5 của bản v7).

### 5.2. Kiểm thử tương thích Frontend Flutter (`flutter_app/`)
Chạy lệnh kiểm thử tự động:
```bash
flutter test
```
**Kết quả:**
```text
00:04 +7: All tests passed!
```

---

## 6. Hướng dẫn bàn giao & Tích hợp cho các thành viên khác

### 6.1. Bàn giao cho Vương (Khối B — UI Flutter)
- **Endpoint Chat:** `POST /api/v1/chat`
  ```json
  {
    "question": "Môn SWD392 học ở kỳ mấy trong khung này?",
    "scope": "curriculum",
    "id": "BIT_SE_K19B"
  }
  ```
  *(Khi người dùng đứng ở Màn 2 Curriculum thì truyền `scope: "curriculum"`, đứng ở Màn 3 Subject thì truyền `scope: "subject"` và `id: "PRM393"`).*
- **Endpoint Thống kê Curriculum:** `GET /api/v1/curricula/BIT_SE_K19B/stats`
  - Trả về tổng tín chỉ (`145`), số học kỳ (`9`), danh sách môn và số tín chỉ của từng học kỳ để render header các cột kỳ (Mục 4.5).
- **Endpoint Chi tiết Môn học:** `GET /api/v1/courses/{code}`
  - Trả về đầy đủ `appears_in`, `has_pe`, `counts_in_gpa`, `prerequisites`, `unlocks`.

### 6.2. Bàn giao cho Phúc (Khối E — Bảng điểm, GPA & Tư vấn)
- Khối D đã chuẩn bị sẵn **chỗ cắm dữ liệu (data hook)** trong request chat:
  ```json
  {
    "question": "Tư vấn cho tôi lộ trình để đạt GPA 8.0",
    "scope": "curriculum",
    "id": "BIT_SE_K19B",
    "student_context": {
      "current_gpa": 7.4,
      "target_gpa": 8.0,
      "required_avg_mark": 8.45,
      "is_target_feasible": true,
      "retake_count": 1,
      "failed_courses": ["PRN212"]
    }
  }
  ```
  Backend sẽ tự động chèn các con số này vào prompt và câu trả lời, không tự ý tính lại.
- **API kiểm tra tiên quyết:** `POST /api/v1/courses/{code}/check-prerequisites`
  ```json
  {
    "completed_courses": ["PRF192", "PRO192", "CSD201"]
  }
  ```

### 6.3. Bàn giao & Đồng bộ với Khối C (Obsidian Graph View — Màn 3)
- Đã chuẩn hóa toàn diện giao diện Đồ thị tương tác theo chuẩn mẫu Obsidian (Hình 2):
  + **Sửa lỗi kéo thả (Pan):** Thiết lập `InteractiveViewer(constrained: false, boundaryMargin: EdgeInsets.all(1400))`, bỏ chặn gesture trên node giúp người dùng nhấn giữ chuột và kéo di chuyển tự do khắp không gian 2D (lên, xuống, trái, phải).
  + **Đồng bộ 100% liên kết từ `flm_knowledge_vault`:** Tự động trích xuất toàn bộ **334 liên kết tri thức thực tế** từ các file markdown (bao gồm liên kết tiên quyết hai chiều `[[...]]`, liên kết mở khóa môn kế tiếp, liên kết 3 Hubs trung tâm và nhãn học kỳ `#HK0` - `#HK9`).
  + **Animation chuyển cảnh siêu mượt (Smooth Curved Lerp ~240ms):** Sử dụng `AnimationController` nội suy (`lerpDouble` và `Color.lerp`) với đường cong `Curves.easeOutCubic`. Khi rê chuột vào môn học, các liên kết của môn đó sáng dần lên trong khi các node bên ngoài mờ dần về mức `0.08` êm ái; khi rê chuột ra ngoài (`cursor out`), đồ thị tự động chuyển ngược (`Curves.easeInCubic`) trở lại trạng thái tổng quan ban đầu mà không bị giật, chớp hay khựng hình.
  + **Bảng chú thích màu sắc (Graph Legend):** Bổ sung panel chú thích phong cách Obsidian ở góc dưới bên phải, hiển thị đầy đủ quy ước màu sắc của từng phân loại môn học (Core CS, Web/Java, .NET, Capstone, Đại cương, 3 Hubs, Nhãn học kỳ) kèm nút thu gọn/mở rộng linh hoạt.
  + **Bố cục thoáng đãng 360 độ:** Trải rộng đồ thị trên canvas chuẩn `1900 x 1500` với bán kính 560px, khoảng cách giữa các node luôn $\ge 75\text{px} - 150\text{px}$, chữ không bị đè lên nhau.
  + **Thanh công cụ linh hoạt:** Hỗ trợ tìm kiếm nhanh, bật/tắt mũi tên, nút Căn giữa, cùng hai nút Phóng to (+) / Thu nhỏ (-) chuyên dụng cho Desktop/Web.
  + **Nút Trợ lý AI (Floating Chatbot Button) lớn góc dưới phải:** Chuyển nút Chatbot thành nút nổi hình tròn lớn (`58 x 58px`, icon robot `30px`) tại góc dưới bên phải màn hình với gradient công nghệ (`#0284C7` $\to$ `#6366F1`) và bóng đổ mềm mại, dễ nhìn và dễ thao tác.
  + **Bảng chú thích & Hướng dẫn chuyển sang bên trái:** Di chuyển panel Chú thích màu sắc sang góc dưới bên trái (`bottom: 48, left: 20`) xếp ngay trên thanh mẹo hướng dẫn (`bottom: 12, left: 20`), giúp toàn bộ nửa bên phải thông thoáng tuyệt đối khi mở panel Chat AI.
  + **Nút đóng Chat AI tích hợp:** Bổ sung nút đóng (`Icons.close_rounded`) ngay trên header của `ContextualChatPanel` giúp người dùng đóng chat dễ dàng.

### 6.4. Đối soát với Khánh (Khối A — Dữ liệu & Obsidian)
- Vault dữ liệu `.md` và file `flm_knowledge_vault/curricula/BIT_SE_K19B.md` đã được parser đọc trọn vẹn, không phát sinh cảnh báo parsing nghiêm trọng.





---

## 7. Kế hoạch Giai đoạn 2 (Roadmap tiếp theo của Khối D)

1. **Cấu hình Live LLM trên môi trường chạy thử:**
   - Cung cấp `GEMINI_API_KEY` vào file `backend/.env` để kiểm thử trải nghiệm sinh văn bản tự nhiên của mô hình `gemini-1.5-flash` / `gemini-2.0-flash`.
2. **Kiểm thử câu hỏi hội thoại phức tạp:**
   - Đánh giá khả năng trả lời khi sinh viên gõ tiếng Việt không dấu, viết tắt, hoặc hỏi các câu suy luận chéo giữa 2 môn học.
3. **Phối hợp tích hợp End-to-End với Khối E & Khối B:**
   - Khởi động backend (`python -m uvicorn backend.app.main:app --reload`) và cho app Flutter gọi thực tế để kiểm tra độ trễ (latency) và định dạng hiển thị tin nhắn.

