# Khối A — Trích xuất dữ liệu & Obsidian (Khánh)

> Đặc tả: `requirement_flm_obsidian_chat_v7.md` — Mục 2, 3 (+ Mục 6 cho `grading_rules.yaml`).
> Đây là **tầng dữ liệu nền**: các khối B (Flutter), C (Graph), D (RAG), E (GPA/Tư vấn) đều đọc từ đây.

---

## 1. Sản phẩm bàn giao

| Sản phẩm | Đường dẫn | Ghi chú |
|---|---|---|
| Vault Obsidian (Subject .md) | `flm_knowledge_vault/*.md` | 52 file, front matter schema v7 |
| Vault Obsidian (Curriculum .md) | `flm_knowledge_vault/curricula/BIT_SE_K19B.md` | Front matter `type: curriculum` + `subjects[]` |
| Cấu hình Graph View | `flm_knowledge_vault/.obsidian/graph.json` | Tô màu theo học kỳ, mũi tên tiên quyết |
| Dữ liệu cho Flutter | `flm_flutter_data/courses_data.json` + `flutter_app/assets/courses_data.json` | Giữ nguyên khóa cũ + bổ sung khóa mới |
| Quy chế tính điểm | `grading_rules.yaml` | Nguồn sự thật duy nhất (Mục 6) |
| Module dùng chung | `scripts/flm_data.py` | Chuẩn hóa mã môn (2.3) + thống kê (2.2) |
| Script sinh dữ liệu | `scripts/enrich_vault_schema.py` | Nâng schema v7, sinh curriculum, JSON |
| Script cấu hình graph | `scripts/configure_obsidian_graph.py` | Sinh `graph.json` |
| Script kiểm chứng | `scripts/verify_flm_data.py` | **85 tiêu chí**, exit code 1 nếu FAIL |

---

## 2. Cách chạy

```bash
# 1. Sinh/cập nhật dữ liệu (idempotent — chạy lại nhiều lần vẫn cho cùng kết quả)
python scripts/enrich_vault_schema.py
python scripts/configure_obsidian_graph.py

# 2. Kiểm chứng toàn bộ tiêu chí của Khối A
python scripts/verify_flm_data.py
```

Script ghi file với **xuống dòng LF** để `git diff` không bị nhiễu (xem `.gitattributes`).

---

## 3. Schema front matter (`flm_knowledge_vault/PRM393.md`)

```yaml
---
type: subject
code: PRM393
title: Mobile Programming
title_vi: Lập trình di động
credits: 3
prerequisites: [PRO192]
has_pe: true
has_pe_source: detailed_assessment_table:practical_exam   # truy vết căn cứ
counts_in_gpa: true
appears_in:
  - {curriculum: BIT_SE_K19B, semester: 8}
in_curriculum: true
tags: [HK8]          # phục vụ colorGroups của Obsidian Graph View

# --- Khóa tương thích ngược (backend FastAPI + Flutter đang đọc) ---
code_original: PRM393
name_en: Mobile Programming
name_vi: Lập trình di động
semester: 8
curriculum: BIT_SE_K19B
syllabus_url: https://flm.fpt.edu.vn/...
---
```

**`has_pe` được SUY RA từ dữ liệu thật**, không hard-code: đọc bảng
`### 📊 Cấu Trúc Điểm Thi & Đánh Giá Chi Tiết` (dữ liệu cào từ FLM) và tìm dòng
`Practical Exam`. `has_pe_source` ghi lại căn cứ để truy vết. Kết quả: **17 môn có PE**.

---

## 4. Module dùng chung — `scripts/flm_data.py`

Các khối B/C/D/E **gọi lại module này, không tự tính riêng**.

```python
from flm_data import FLMKnowledgeBase, normalize_course_code, counts_in_gpa

kb = FLMKnowledgeBase()

# Mục 2.3 — chuẩn hóa mã môn (hoa, bỏ khoảng trắng, gộp Ð/Đ, bỏ dấu)
normalize_course_code("Ð  prm393 ")   # -> 'DPRM393'

# Mục 2.2 — thống kê curriculum: số học kỳ / số môn / tổng tín chỉ
kb.curriculum_stats("BIT_SE_K19B")
# {'semester_count': 10, 'subject_count': 48, 'total_credits': 147, 'total_credits_in_gpa': 125, ...}

# Mục 2.2 — môn X xuất hiện ở đâu (hỗ trợ nhiều dòng)
kb.subject_appears_in("PRM393")        # [{'curriculum': 'BIT_SE_K19B', 'semester': 8}]

# Mục 2.2 — kiểm tra tiên quyết (có chuỗi bắc cầu + phát hiện chu trình)
kb.check_prerequisites("SWP391")       # {'prerequisites': [...], 'chain': [...], 'depth': {...}}

# Mục 6 — quy chế điểm (khớp tiền tố HOẶC mã đầy đủ)
counts_in_gpa("VOV114")                # False  (khớp tiền tố VOV)
counts_in_gpa("SYB301")                # False  (khớp mã đầy đủ)
counts_in_gpa("PRM393")                # True
```

CLI:

```bash
python scripts/flm_data.py stats BIT_SE_K19B
python scripts/flm_data.py appears PRM393
python scripts/flm_data.py prereq SWP391
python scripts/flm_data.py gpa-rule VOV114
```

---

## 5. Hợp đồng tích hợp với các khối khác

| Khối | Dùng gì |
|---|---|
| **B — Flutter** | `courses_data.json`: `curriculum.subjects[]` (danh sách môn + `semester`), mỗi course có `has_pe`, `counts_in_gpa`, `appears_in`, `credits`. Màn 1 đọc `curriculum.curricula` để **không hard-code** danh sách chương trình. |
| **C — Graph** | `graph.nodes[]` (`id`, `semester`, `credits`, `color`, `type`) và `graph.edges[]` (`from`/`to` + `source`/`target`, `type: prerequisite`). Mọi cạnh đã được kiểm tra **không treo**. |
| **D — RAG** | Vault `.md` — backend `flm_parser.py` đã parse thành 52 môn / 240 chunks. Trường `has_pe` giúp trả lời câu hỏi PE/FE chính xác. |
| **E — GPA/Tư vấn** | `grading_rules.yaml` + `counts_in_gpa` của từng môn (đã sinh sẵn theo đúng quy tắc tiền tố/mã đầy đủ). |

---

## 6. Lưu ý dữ liệu (đã xử lý & còn tồn tại)

- **Mã alias:** vault có 4 môn "mã cũ/tương đương" không nằm trong curriculum:
  `MAC101 → MAE101`, `SWE102 → SWE201c`, `SWE202c → SWE201c`, `JPD133 → JPD123`.
  Chúng được giữ lại để phân giải tiên quyết, nhưng đánh dấu `in_curriculum: false`
  để khối B/C **lọc bỏ khi vẽ graph/thống kê**. 7 tiên quyết trỏ vào mã alias đã được quy về canonical.
- **1 tiên quyết không phân giải được:** `OJT202 → JPD133`. Đây là ràng buộc có điều kiện
  thật của FLM ("sinh viên chọn tổ hợp JS - Japanese Bridge Engineer phải đạt JPD133"),
  không phải lỗi dữ liệu.
- **`has_pe` của `LAB211` và `OTP101`:** FLM không có bảng đánh giá chi tiết cho 2 môn này,
  nên `has_pe = false` theo mặc định; `has_pe_source` ghi rõ `default:no_evidence` để tra soát.
