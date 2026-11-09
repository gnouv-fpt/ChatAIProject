#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script: enrich_vault_schema.py
Author: Khánh (Khối A - Trích xuất dữ liệu & Obsidian)
Project: FLM Obsidian & Chat AI Assistant (PRM393 Lab 1)

MỤC ĐÍCH
    Nâng dữ liệu vault + JSON hiện có lên ĐÚNG schema đặc tả
    `requirement_flm_obsidian_chat_v7.md` Mục 2.1, đồng thời bổ sung các
    trường phục vụ Mục 4.3 (Graph) / Mục 4.5 (bố cục học kỳ) / Mục 5 (Chat RAG)
    / Mục 7 (bảng điểm & chiến lược) mà KHÔNG phá vỡ code của các khối B/C/D/E.

CÁC VIỆC SCRIPT LÀM
    1. Subject .md  -> thêm/sửa front matter theo schema v7:
         type, code, title, title_vi, credits, prerequisites,
         has_pe, counts_in_gpa, appears_in[{curriculum, semester}]
       đồng thời GIỮ LẠI các khóa cũ (name_en/name_vi/semester/curriculum/...)
       để backend FastAPI (flm_parser.py) và Flutter (course.dart) không hỏng.
    2. Sinh file curriculum chuẩn: `flm_knowledge_vault/curricula/<ID>.md`
       với front matter `type: curriculum`, `subjects: [{code, semester}]`.
    3. has_pe: suy ra từ BẢNG ĐÁNH GIÁ CHI TIẾT thật đã cào từ FLM
       (khối "<code>.md" -> "### 📊 Cấu Trúc Điểm Thi & Đánh Giá Chi Tiết"),
       có fallback rõ ràng và lưu lại nguồn suy luận (`has_pe_source`).
    4. counts_in_gpa: sinh bằng `flm_data.is_excluded_from_gpa()` đọc từ
       grading_rules.yaml (KHÔNG hard-code).
    5. appears_in: sinh từ (curriculum, semester) — hỗ trợ nhiều dòng.
    6. Cập nhật `flm_flutter_data/courses_data.json` + bản sao asset Flutter:
         - mỗi course: has_pe, counts_in_gpa, appears_in, prerequisites_norm
         - curriculum: id + subjects[] + danh sách curricula
         - graph: sửa `code` (nhãn) vs `id` (định danh) + thêm cạnh `type`
       Giữ nguyên 100% khóa cũ để Flutter vẫn parse được.

CHẠY
    python scripts/enrich_vault_schema.py            # ghi vào file
    python scripts/enrich_vault_schema.py --dry-run  # chỉ báo cáo, không ghi
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import defaultdict
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

try:
    import yaml
except ImportError:  # pragma: no cover
    print("Cần cài PyYAML: pip install pyyaml")
    raise SystemExit(1)

sys.path.insert(0, str(Path(__file__).resolve().parent))

from flm_data import (  # noqa: E402
    DEFAULT_GRADING_RULES,
    FLUTTER_ASSET_JSON,
    FLUTTER_JSON,
    REPO_ROOT,
    VAULT_DIR,
    counts_in_gpa,
    is_excluded_from_gpa,
    load_grading_rules,
    normalize_course_code,
)

if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass


# =============================================================================
# HẰNG SỐ
# =============================================================================

CURRICULUM_ID = "BIT_SE_K19B"
CURRICULUM_NAME = "The Bachelor Program of Information Technology, Software Engineering Major"
CURRICULUM_NAME_VI = "Chương trình cử nhân ngành Công nghệ thông tin, chuyên ngành Kỹ thuật phần mềm"
CURRICULA_DIR = VAULT_DIR / "curricula"

ASSESS_HEADING = "Cấu Trúc Điểm Thi & Đánh Giá Chi Tiết"
DETAIL_MARKER = "DỮ LIỆU SYLLABUS CHI TIẾT"

#: Bỏ dấu tiếng Việt (dùng cho so khớp nhãn, không dùng cho mã môn).
#: Dùng phân rã Unicode NFD + loại bỏ combining marks thay vì bảng tra thủ công
#: để tránh sai lệch độ dài bảng.
import unicodedata as _ud  # noqa: E402


def strip_vi(text: str) -> str:
    """Bỏ dấu tiếng Việt: 'Thực hành' -> 'Thuc hanh' (đ/Đ -> d/D)."""
    text = (text or "").replace("\u0111", "d").replace("\u0110", "D")
    decomposed = _ud.normalize("NFD", text)
    return "".join(ch for ch in decomposed if not _ud.combining(ch))


# =============================================================================
# 1. PHÂN TÍCH BẢNG ĐÁNH GIÁ ĐỂ SUY RA has_pe
# =============================================================================

def _assessment_block(md_text: str) -> str:
    """Lấy đoạn markdown của '### 📊 Cấu Trúc Điểm Thi & Đánh Giá Chi Tiết'."""
    if DETAIL_MARKER not in md_text:
        return ""
    detail = md_text.split(DETAIL_MARKER, 1)[1]
    if ASSESS_HEADING not in detail:
        return ""
    block = detail.split(ASSESS_HEADING, 1)[1]
    for stop in ("### ", "\n---\n# "):
        if stop in block:
            block = block.split(stop, 1)[0]
    return block


def detect_has_pe(subject: Dict[str, Any], md_text: str) -> Tuple[bool, str]:
    """Suy ra môn có thi PE (Practical Exam) hay không.

    Trả về ``(has_pe, source)`` với ``source`` mô tả căn cứ để truy vết.

    Thứ tự ưu tiên:
      1. Bảng đánh giá chi tiết cào trực tiếp từ FLM (nguồn đáng tin nhất).
      2. assessment_scheme trong JSON (nếu không khớp template mặc định).
      3. Quy ước mã môn (VOV/OTP/TMI... là môn thể chất/định hướng -> không PE).
    """
    block = _assessment_block(md_text)
    if block:
        norm_block = strip_vi(block).lower()
        # Bỏ dòng 'Progress test' để tránh khớp nhầm cụm 'Practice/Practical'
        without_progress = re.sub(r"progress\s*test", " ", norm_block)
        if re.search(r"practical\s*exam", without_progress):
            return True, "detailed_assessment_table:practical_exam"
        if re.search(r"\bpe\b", without_progress) or "thi thuc hanh" in without_progress:
            return True, "detailed_assessment_table:pe_keyword"
        return False, "detailed_assessment_table:no_pe_row"

    # Fallback: assessment_scheme từ JSON (khác template mặc định)
    scheme = subject.get("assessment_scheme") or []
    items_norm = " | ".join(strip_vi(str(i.get("item", ""))).lower() for i in scheme if isinstance(i, dict))
    generic_template = "quiz & class assignments | practical exam (pe) / progress test | final exam (fe)"
    if items_norm and items_norm != generic_template and re.search(r"\bpe\b|practical exam", items_norm):
        return True, "assessment_scheme:pe"

    # Quy ước mã môn: thể chất / định hướng / tiếng Anh nền -> không có PE
    code_norm = normalize_course_code(subject.get("code"))
    if code_norm.startswith(("VOV", "OTP", "TMI", "TRS", "PEN", "PHE")):
        return False, "course_code_convention:non_pe"

    return False, "default:no_evidence"


# =============================================================================
# 2. GHI FRONT MATTER
# =============================================================================

def build_subject_front_matter(fm: Dict[str, Any], subj_code: str, has_pe: bool,
                               has_pe_source: str, rules: Dict[str, Any],
                               appears_in: List[Dict[str, Any]],
                               in_curriculum: bool = True) -> Dict[str, Any]:
    """Tạo dict front matter theo schema v7 nhưng giữ tương thích ngược.

    Thứ tự khóa được sắp để file dễ đọc: khối v7 trước, khối legacy sau.
    ``in_curriculum=False`` dùng cho các môn "mã cũ/tương đương" có file trong
    vault nhưng KHÔNG nằm trong danh sách môn của curriculum (ví dụ MAC101,
    SWE102) — giúp các khối B/C lọc bỏ khi vẽ graph thống kê.
    """
    out: Dict[str, Any] = {}

    # --- Khối schema v7 (Mục 2.1) ---
    out["type"] = "subject"
    out["code"] = fm.get("code") or fm.get("code_original") or subj_code
    out["title"] = fm.get("name_en") or fm.get("name") or fm.get("title") or ""
    out["title_vi"] = fm.get("name_vi") or out["title"]
    out["credits"] = int(fm.get("credits") or 0)
    out["prerequisites"] = [str(p) for p in (fm.get("prerequisites") or [])]
    out["has_pe"] = bool(has_pe)
    out["has_pe_source"] = has_pe_source
    out["counts_in_gpa"] = counts_in_gpa(out["code"], rules)
    out["appears_in"] = appears_in
    out["in_curriculum"] = bool(in_curriculum)

    # Tag học kỳ HK<n> phục vụ colorGroups của Obsidian Graph View (Mục 3).
    # Đặt cạnh `type` để dễ đọc; đồng bộ hệ màu với SEMESTER_COLORS ở
    # scripts/configure_obsidian_graph.py.
    sem_tags = sorted({f"HK{e['semester']}" for e in appears_in if isinstance(e.get("semester"), int)})
    if sem_tags:
        out["tags"] = sem_tags

    if fm.get("syllabus_url"):
        out["syllabus_url"] = fm["syllabus_url"]

    # --- Khối legacy/canonical (giữ nguyên cho backend + Flutter) ---
    legacy_keys = [
        "code_original", "name_en", "name_vi", "semester", "unlocks",
        "curriculum", "curriculum_name", "curriculum_name_vi",
        "color", "specialization", "equivalent_to", "status",
    ]
    for key in legacy_keys:
        if key in fm and fm[key] not in (None, []):
            out[key] = fm[key]

    # Giữ mọi khóa lạ khác (forward-compatible)
    for key, value in fm.items():
        if key not in out and value not in (None, []):
            out[key] = value

    return out


def render_front_matter(data: Dict[str, Any]) -> str:
    """Render YAML front matter với thứ tự khóa ổn định, giữ tiếng Việt."""
    return "---\n" + yaml.safe_dump(
        data,
        allow_unicode=True,
        sort_keys=False,
        default_flow_style=False,
        width=1000,
    ) + "---\n"


def write_text(path: Path, text: str, newline: str = "\n") -> None:
    """Ghi file với kiểu xuống dòng chỉ định, sau khi CHUẨN HÓA mọi kiểu về LF.

    QUAN TRỌNG: trên Windows, ghi text bằng chế độ mặc định sẽ sinh CRLF và làm
    `git diff` báo thay đổi toàn bộ file dù nội dung không đổi. Ngoài ra thân
    file markdown cào từ web có thể còn sót ``\\r\\n`` — nếu ghi thẳng sẽ tạo ra
    file trộn hai kiểu xuống dòng. Vì vậy mọi chỗ ghi file trong module này đều
    đi qua hàm này và toàn bộ ``\\r\\n`` được quy về ``\\n`` trước khi ghi.
    """
    path.parent.mkdir(parents=True, exist_ok=True)
    normalized = text.replace("\r\n", "\n").replace("\r", "\n")
    if newline != "\n":
        normalized = normalized.replace("\n", newline)
    with open(path, "w", encoding="utf-8", newline="") as handle:
        handle.write(normalized)


def detect_newline(raw_bytes: bytes) -> str:
    """Phát hiện kiểu xuống dòng của file gốc từ BYTES.

    Phải đọc bytes vì ``Path.read_text()`` dùng universal-newlines và tự đổi
    CRLF -> LF, khiến không thể nhận ra file gốc dùng CRLF.
    """
    return "\r\n" if b"\r\n" in raw_bytes else "\n"


def write_subject_file(path: Path, fm: Dict[str, Any], body: str, newline: str = "\n") -> None:
    write_text(path, render_front_matter(fm) + body, newline=newline)


# =============================================================================
# 3. MAIN
# =============================================================================

def main() -> int:
    parser = argparse.ArgumentParser(description="Nâng vault + JSON lên schema v7 (Khối A).")
    parser.add_argument("--dry-run", action="store_true", help="Chỉ báo cáo, không ghi file.")
    parser.add_argument("--vault", default=str(VAULT_DIR), help="Thư mục vault.")
    args = parser.parse_args()

    vault = Path(args.vault)
    dry = args.dry_run

    if not vault.exists():
        print(f"[ERROR] Không tìm thấy vault: {vault}")
        return 1
    if not FLUTTER_JSON.exists():
        print(f"[ERROR] Không tìm thấy {FLUTTER_JSON}")
        return 1

    rules = load_grading_rules()
    print("=" * 78)
    print("  ENRICH VAULT SCHEMA v7 — KHỐI A (Khánh)")
    print("=" * 78)
    print(f"  Quy chế điểm: {'grading_rules.yaml' if (REPO_ROOT / 'grading_rules.yaml').exists() else 'DEFAULT (chưa có file)'}")
    print(f"  Chế độ      : {'DRY-RUN (không ghi)' if dry else 'GHI FILE'}")
    print()

    json_data = json.loads(FLUTTER_JSON.read_text(encoding="utf-8"))
    json_courses: Dict[str, Dict[str, Any]] = {
        normalize_course_code(c.get("code")): c for c in json_data.get("courses", [])
    }

    subject_files = sorted(
        p for p in vault.glob("*.md") if not p.name.startswith("_")
    )

    # --- Quét trước toàn bộ vault để dựng bảng alias ------------------------
    # alias_map: mã alias (đã chuẩn hóa) -> mã canonical (đã chuẩn hóa)
    # Vault có các môn "mã cũ/tương đương" (MAC101 -> MAE101, SWE102 -> SWE201c,
    # SWE202c -> SWE201c, JPD133 -> JPD123). Tiên quyết có thể trỏ vào mã alias,
    # ta quy về canonical để graph/Flutter không bị cạnh treo.
    alias_map: Dict[str, str] = {}
    vault_codes: set = set()
    for md_path in subject_files:
        try:
            head_fm = _split(md_path.read_text(encoding="utf-8"))[0]
        except Exception:
            continue
        v_code = head_fm.get("code") or head_fm.get("code_original") or md_path.stem
        vault_codes.add(normalize_course_code(v_code))
        target = head_fm.get("equivalent_to")
        if target:
            alias_map[normalize_course_code(v_code)] = normalize_course_code(target)

    def resolve_code(raw_code: Any) -> str:
        """Quy mã (có thể là alias) về mã canonical nếu biết."""
        norm_code = normalize_course_code(raw_code)
        seen: set = set()
        while norm_code in alias_map and norm_code not in seen:
            seen.add(norm_code)
            norm_code = alias_map[norm_code]
        return norm_code

    # --- Thu thập trước để phát hiện vấn đề dữ liệu -------------------------
    stats = {
        "subjects_processed": 0,
        "has_pe_true": 0,
        "has_pe_false": 0,
        "excluded_gpa": 0,
        "extra_not_in_json": [],
        "missing_pe_evidence": [],
        "dangling_prereqs": [],
        "alias_prereqs_resolved": [],
    }

    for md_path in subject_files:
        raw_bytes = md_path.read_bytes()
        raw = raw_bytes.decode("utf-8")
        file_newline = detect_newline(raw_bytes)
        try:
            fm, body = _split(raw)
        except Exception as exc:
            print(f"[WARN] Bỏ qua {md_path.name}: {exc}")
            continue

        code = fm.get("code") or fm.get("code_original") or md_path.stem
        norm = normalize_course_code(code)

        has_pe, has_pe_src = detect_has_pe(fm, raw)
        if has_pe_src == "default:no_evidence":
            stats["missing_pe_evidence"].append(code)

        # --- Tên định danh dùng chung cho việc phân giải tham chiếu ---
        # Vault có thêm các môn "mã cũ/tương đương" (MAC101, SWE102, JPD133...)
        # không nằm trong danh sách curriculum. Chúng vẫn được giữ lại trong
        # vault để phân giải tiên quyết, nhưng KHÔNG tính vào thống kê curriculum.
        alias_updates: Dict[str, Any] = {}
        alias = fm.get("equivalent_to")
        if alias:
            alias_updates["equivalent_to"] = str(alias)
        for key in ("canonical_code", "alias_of"):
            if fm.get(key):
                alias_updates[key] = str(fm[key])

        # appears_in: ưu tiên dữ liệu cũ, đồng thời đồng bộ từ JSON nếu có
        appears_in = _normalize_appears_in(fm)
        jc = json_courses.get(norm)
        in_curriculum = jc is not None
        if not appears_in and jc and isinstance(jc.get("semester"), int):
            appears_in = [{"curriculum": CURRICULUM_ID, "semester": jc["semester"]}]

        # Môn có trong vault nhưng không có trong curriculum JSON -> ghi nhận
        if not in_curriculum:
            stats["extra_not_in_json"].append(code)

        # Kiểm tra tiên quyết: phân giải alias trước khi kết luận "trỏ ra ngoài".
        for pre in fm.get("prerequisites") or []:
            pre_norm = normalize_course_code(pre)
            resolved = resolve_code(pre)
            if resolved in json_courses:
                # Tiên quyết trỏ tới mã alias nhưng canonical có trong curriculum
                if pre_norm != resolved:
                    stats["alias_prereqs_resolved"].append(
                        {"subject": code, "prerequisite": str(pre), "canonical": resolved}
                    )
                continue
            stats["dangling_prereqs"].append({"subject": code, "prerequisite": str(pre)})

        new_fm = build_subject_front_matter(
            fm, code, has_pe, has_pe_src, rules, appears_in, in_curriculum=in_curriculum
        )
        new_fm.update({k: v for k, v in alias_updates.items() if k not in new_fm})

        if has_pe:
            stats["has_pe_true"] += 1
        else:
            stats["has_pe_false"] += 1
        if not new_fm["counts_in_gpa"]:
            stats["excluded_gpa"] += 1
        stats["subjects_processed"] += 1

        if not dry:
            # Ghi với LF — chuẩn hóa toàn vault về một kiểu xuống dòng duy nhất
            # (khớp .gitattributes: flm_knowledge_vault/** text eol=lf).
            write_subject_file(md_path, new_fm, body, newline="\n")

        # Đồng bộ ngược vào JSON
        if jc is not None:
            jc["code"] = new_fm["code"]
            jc["has_pe"] = new_fm["has_pe"]
            jc["has_pe_source"] = new_fm["has_pe_source"]
            jc["counts_in_gpa"] = new_fm["counts_in_gpa"]
            jc["appears_in"] = new_fm["appears_in"]
            jc["prerequisites_norm"] = [normalize_course_code(p) for p in new_fm["prerequisites"]]

    # --- Sinh file curriculum chuẩn -----------------------------------------
    curriculum_subjects: List[Dict[str, Any]] = []
    for code, jc in json_courses.items():
        sem = jc.get("semester")
        if isinstance(sem, int):
            curriculum_subjects.append({"code": jc.get("code"), "semester": sem})
    curriculum_subjects.sort(key=lambda e: (e["semester"], normalize_course_code(e["code"])))

    curricula_dir = vault / "curricula"
    if not dry:
        curricula_dir.mkdir(parents=True, exist_ok=True)

    cur_fm = {
        "type": "curriculum",
        "id": CURRICULUM_ID,
        "name": CURRICULUM_NAME,
        "name_vi": CURRICULUM_NAME_VI,
        "institution": "FPT University (FPTU)",
        "major": "Software Engineering (SE)",
        "total_credits": json_data.get("curriculum", {}).get("total_credits", 0),
        "subjects": curriculum_subjects,
    }
    cur_body = _render_curriculum_body(cur_fm, json_courses)

    cur_file = curricula_dir / f"{CURRICULUM_ID}.md"
    if not dry:
        write_text(cur_file, render_front_matter(cur_fm) + cur_body)

    # --- Cập nhật JSON: curriculum + graph ----------------------------------
    if isinstance(json_data.get("curriculum"), dict):
        json_data["curriculum"]["id"] = CURRICULUM_ID
        json_data["curriculum"]["subjects"] = curriculum_subjects
        json_data["curriculum"]["curricula"] = [
            {"id": CURRICULUM_ID, "name": CURRICULUM_NAME, "name_vi": CURRICULUM_NAME_VI}
        ]

    graph = json_data.get("graph")
    if isinstance(graph, dict):
        for node in graph.get("nodes", []):
            jc = json_courses.get(normalize_course_code(node.get("id")))
            node["type"] = "subject"
            if jc is not None:
                node["code"] = jc.get("code")          # nhãn hiển thị
                node["semester"] = jc.get("semester", node.get("semester"))
                node["credits"] = jc.get("credits", node.get("credits"))
                node["has_pe"] = jc.get("has_pe")
                node["counts_in_gpa"] = jc.get("counts_in_gpa")
            node["label"] = str(jc.get("code") if jc else node.get("id", "")).upper()
        for edge in graph.get("edges", []):
            edge["type"] = edge.get("type") or "prerequisite"

    if not dry:
        _write_json(FLUTTER_JSON, json_data)
        _write_json(FLUTTER_ASSET_JSON, json_data)

    # --- Báo cáo ------------------------------------------------------------
    print("── KẾT QUẢ ──")
    print(f"  Subject .md đã xử lý        : {stats['subjects_processed']}")
    print(f"  has_pe = true / false       : {stats['has_pe_true']} / {stats['has_pe_false']}")
    print(f"  Môn không tính GPA          : {stats['excluded_gpa']}")
    print(f"  Môn trong vault ngoài curr. : {len(stats['extra_not_in_json'])} {stats['extra_not_in_json']}")
    print(f"  Tiên quyết qua mã alias     : {len(stats['alias_prereqs_resolved'])}")
    for item in stats["alias_prereqs_resolved"]:
        print(f"      ~ {item['subject']}: {item['prerequisite']} -> {item['canonical']}")
    print(f"  Tiên quyết trỏ ra ngoài     : {len(stats['dangling_prereqs'])}")
    for item in stats["dangling_prereqs"]:
        print(f"      - {item['subject']} -> {item['prerequisite']}")
    print(f"  Curriculum subjects         : {len(curriculum_subjects)}")
    print(f"  File curriculum             : {cur_file.relative_to(REPO_ROOT)}")
    print(f"  JSON cập nhật               : {FLUTTER_JSON.relative_to(REPO_ROOT)}")
    if FLUTTER_ASSET_JSON.exists():
        print(f"                                {FLUTTER_ASSET_JSON.relative_to(REPO_ROOT)}")
    print()
    if dry:
        print("  (DRY-RUN: chưa ghi thay đổi nào. Bỏ --dry-run để áp dụng.)")
    else:
        print("  ✔ HOÀN TẤT.")
    return 0


# =============================================================================
# TIỆN ÍCH NỘI BỘ
# =============================================================================

_FM_RE = re.compile(r"^---\s*\n(.*?)\n---\s*(?:\n|$)", re.DOTALL)


def _split(raw_text: str) -> Tuple[Dict[str, Any], str]:
    match = _FM_RE.match(raw_text)
    if not match:
        return {}, raw_text
    data = yaml.safe_load(match.group(1)) or {}
    if not isinstance(data, dict):
        data = {}
    return data, raw_text[match.end():]


def _normalize_appears_in(fm: Dict[str, Any]) -> List[Dict[str, Any]]:
    """Chuẩn hóa `appears_in` về list[dict] với khóa curriculum/semester."""
    raw = fm.get("appears_in") or []
    if isinstance(raw, dict):
        raw = [raw]
    out: List[Dict[str, Any]] = []
    for entry in raw:
        if not isinstance(entry, dict):
            continue
        cur = entry.get("curriculum") or entry.get("id") or CURRICULUM_ID
        sem = entry.get("semester")
        if isinstance(sem, str) and sem.isdigit():
            sem = int(sem)
        if not isinstance(sem, int):
            continue
        out.append({"curriculum": str(cur), "semester": sem})
    out.sort(key=lambda e: (e["curriculum"], e["semester"]))
    return out


def _render_curriculum_body(cur_fm: Dict[str, Any], json_courses: Dict[str, Dict[str, Any]]) -> str:
    """Sinh thân file curriculum: danh sách môn theo học kỳ + liên kết [[...]]."""
    by_sem: Dict[int, List[Dict[str, Any]]] = defaultdict(list)
    for entry in cur_fm["subjects"]:
        by_sem[entry["semester"]].append(entry)

    lines: List[str] = [
        f"# {cur_fm['name_vi']} ({cur_fm['id']})",
        "",
        f"> **Ngành:** Công nghệ Thông tin (Information Technology)  ",
        f"> **Chương trình:** `{cur_fm['id']}`  ",
        f"> **Tổng tín chỉ:** {cur_fm['total_credits']} | **Số môn:** {len(cur_fm['subjects'])}  ",
        "",
        "> [!NOTE]",
        "> File này là dữ liệu CURRICULUM cho Flutter + RAG.",
        "> Không sửa tay — sinh tự động bởi `scripts/enrich_vault_schema.py`.",
        "",
        "---",
        "",
        "## Lộ trình môn học theo học kỳ",
        "",
    ]
    for sem in sorted(by_sem):
        entries = by_sem[sem]
        total = sum(
            int(json_courses.get(normalize_course_code(e["code"]), {}).get("credits", 0) or 0)
            for e in entries
        )
        lines.append(f"### Học kỳ {sem} ({total} tín chỉ)")
        lines.append("")
        for entry in entries:
            code = entry["code"]
            jc = json_courses.get(normalize_course_code(code), {})
            name = jc.get("name_vi") or jc.get("name") or ""
            credits = jc.get("credits", 0)
            flags: List[str] = []
            if jc.get("has_pe"):
                flags.append("PE")
            if jc.get("counts_in_gpa") is False:
                flags.append("không tính GPA")
            suffix = f" — *{', '.join(flags)}*" if flags else ""
            lines.append(f"- [[{code}]] — **{name}** : `{credits} tín chỉ`{suffix}")
        lines.append("")

    lines += [
        "---",
        "",
        "## Truy vấn nhanh",
        "",
        "```bash",
        "# Thống kê chương trình",
        "python scripts/flm_data.py stats " + cur_fm["id"],
        "# Môn xuất hiện ở đâu",
        "python scripts/flm_data.py appears PRM393",
        "# Kiểm tra tiên quyết",
        "python scripts/flm_data.py prereq SWP391",
        "```",
        "",
        "Xem chuẩn đầu ra ngành tại [[_Program_Learning_Outcomes]].",
        "Xem tổng quan định dạng cũ tại [[_Curriculum_Overview]].",
        "",
    ]
    return "\n".join(lines)


def _write_json(path: Path, data: Dict[str, Any]) -> None:
    # JSON gốc dùng LF; giữ nguyên để diff chỉ hiện thay đổi nội dung.
    write_text(path, json.dumps(data, ensure_ascii=False, indent=2), newline="\n")


if __name__ == "__main__":
    raise SystemExit(main())
