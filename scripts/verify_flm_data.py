#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script: verify_flm_data.py
Author: Khánh (Khối A — Trích xuất dữ liệu & Obsidian)
Project: FLM Obsidian & Chat AI Assistant (PRM393 Lab 1)

MỤC ĐÍCH
    Kiểm chứng TỰ ĐỘNG các sản phẩm bàn giao của Khối A (Khánh) theo đặc tả
    `requirement_flm_obsidian_chat_v7.md`:
      - Mục 2.1 — schema front matter Subject / Curriculum.
      - Mục 2.2 — các truy vấn/thống kê bắt buộc.
      - Mục 2.3 — chuẩn hóa mã môn (hoa, bỏ khoảng trắng, gộp Ð/Đ).
      - Mục 3   — Obsidian Graph View cấu hình theo học kỳ.
      - Mục 6   — counts_in_gpa khớp grading_rules.yaml (tiền tố + mã đầy đủ).
      - Tính tương thích ngược: JSON vẫn parse được bởi backend & Flutter.

    Xuất mã thoát 1 nếu có tiêu chí FAIL — dùng được trong CI.

CHẠY
    python scripts/verify_flm_data.py
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any, Callable, Dict, List, Tuple

sys.path.insert(0, str(Path(__file__).resolve().parent))

from flm_data import (  # noqa: E402
    FLUTTER_ASSET_JSON,
    FLUTTER_JSON,
    FLMKnowledgeBase,
    GRADING_RULES_PATH,
    REPO_ROOT,
    VAULT_DIR,
    counts_in_gpa,
    is_excluded_from_gpa,
    load_grading_rules,
    normalize_course_code,
    normalize_score,
)

if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass


PASS = "PASS"
FAIL = "FAIL"
_results: List[Tuple[str, bool, str]] = []


def check(name: str, condition: bool, detail: str = "") -> None:
    _results.append((name, bool(condition), detail))
    icon = "[OK]  " if condition else "[FAIL]"
    print(f"  {icon} {name}")
    if detail and not condition:
        print(f"         -> {detail}")


def section(title: str) -> None:
    print()
    print("-" * 78)
    print(f"  {title}")
    print("-" * 78)


# =============================================================================
def main() -> int:
    print("=" * 78)
    print("  VERIFICATION REPORT — KHỐI A (Khánh): Dữ liệu FLM & Obsidian")
    print("  Đặc tả: requirement_flm_obsidian_chat_v7.md")
    print("=" * 78)

    # -------------------------------------------------------------------------
    section("1. CHUẨN HÓA MÃ MÔN (Mục 2.3)")
    # -------------------------------------------------------------------------
    cases = [
        ("Ð PRM393 ", "DPRM393", "eth 'Ð' -> D + bỏ khoảng trắng + hoa"),
        ("Đpm393", "DPM393", "Đ chữ Việt -> D"),
        ("  prm393  ", "PRM393", "bỏ khoảng trắng hai đầu"),
        ("prm 393", "PRM393", "bỏ khoảng trắng giữa"),
        ("đồ án", "DOAN", "bỏ dấu tiếng Việt + hoa"),
        (None, "", "None an toàn"),
    ]
    for raw, expected, desc in cases:
        got = normalize_course_code(raw)
        check(f"normalize({raw!r}) == {expected!r}  ({desc})", got == expected, f"nhận được {got!r}")

    # Ð (U+00D0) và Đ (U+0110) phải về cùng một dạng
    check(
        "Ð (U+00D0) và Đ (U+0110) chuẩn hóa về cùng kết quả",
        normalize_course_code("\u00d0PRM393") == normalize_course_code("\u0110PRM393"),
    )

    score_cases = [("7,5", 7.5), ("7.5", 7.5), ("", None), ("N/A", None), ("9", 9.0)]
    for raw, expected in score_cases:
        got = normalize_score(raw)
        check(f"normalize_score({raw!r}) == {expected}", got == expected, f"nhận được {got!r}")

    # -------------------------------------------------------------------------
    section("2. QUY CHẾ ĐIỂM — grading_rules.yaml (Mục 6.1)")
    # -------------------------------------------------------------------------
    check("File grading_rules.yaml tồn tại ở repo root", GRADING_RULES_PATH.exists(), str(GRADING_RULES_PATH))
    rules = load_grading_rules()
    check("Có gpa_scale, excluded_from_gpa, retake, graduation_grades",
          all(k in rules for k in ("gpa_scale", "excluded_from_gpa", "retake", "graduation_grades")))

    # Khớp TIỀN TỐ
    prefix_cases = [("VOV114", False), ("ENT201", False), ("GDQP1", False), ("TRS601", False),
                    ("LAB211", False), ("OJT202", False), ("DSA101", False)]
    for code, expect_gpa in prefix_cases:
        got = counts_in_gpa(code, rules)
        check(f"counts_in_gpa({code}) == {expect_gpa} (khớp tiền tố)", got == expect_gpa, f"nhận được {got}")
    # Khớp MÃ ĐẦY ĐỦ
    check("counts_in_gpa('SYB301') == False (khớp mã đầy đủ)", counts_in_gpa("SYB301", rules) is False)
    check("counts_in_gpa('SYB301x') == False (mã đầy đủ vẫn là tiền tố)",
          counts_in_gpa("SYB301x", rules) is False)
    # Môn thường
    for code in ("PRM393", "PRO192", "SWD392", "DBI202"):
        check(f"counts_in_gpa({code}) == True", counts_in_gpa(code, rules) is True)
    # Chuẩn hóa trước khi khớp
    check("counts_in_gpa(' vov114 ') == False (đã chuẩn hóa trước khi khớp)",
          counts_in_gpa(" vov114 ", rules) is False)

    # -------------------------------------------------------------------------
    section("3. SCHEMA FRONT MATTER SUBJECT (Mục 2.1)")
    # -------------------------------------------------------------------------
    REQUIRED_SUBJECT_KEYS = ["type", "code", "title", "credits", "prerequisites", "has_pe", "counts_in_gpa", "appears_in"]
    subject_files = sorted(p for p in VAULT_DIR.glob("*.md") if not p.name.startswith("_"))
    check("Vault có >= 48 file Subject .md", len(subject_files) >= 48, f"thực tế {len(subject_files)}")

    kb = FLMKnowledgeBase()
    missing_keys: Dict[str, List[str]] = {}
    bad_type: List[str] = []
    bad_appears: List[str] = []
    for subj in kb.subjects.values():
        raw = subj.raw
        miss = [k for k in REQUIRED_SUBJECT_KEYS if k not in raw]
        if miss:
            missing_keys[subj.code] = miss
        if raw.get("type") != "subject":
            bad_type.append(subj.code)
        for entry in raw.get("appears_in") or []:
            if not isinstance(entry, dict) or "curriculum" not in entry or not isinstance(entry.get("semester"), int):
                bad_appears.append(f"{subj.code}:{entry}")

    check("Mọi Subject có đủ khóa schema v7",
          not missing_keys,
          f"thiếu: {list(missing_keys.items())[:5]}")
    check("Mọi Subject có type == 'subject'", not bad_type, f"sai: {bad_type[:5]}")
    check("Mọi appears_in có dạng {curriculum, semester:int}", not bad_appears, f"sai: {bad_appears[:5]}")

    # Kiểm tra cụ thể PRM393 theo đúng ví dụ trong đặc tả
    prm = kb.get_subject("PRM393")
    check("PRM393 tồn tại trong vault", prm is not None)
    if prm:
        check("PRM393 type == 'subject'", prm.raw.get("type") == "subject")
        check("PRM393 credits == 3", prm.credits == 3, f"nhận {prm.credits}")
        check("PRM393 has_pe là bool", isinstance(prm.raw.get("has_pe"), bool))
        check("PRM393 counts_in_gpa là bool", isinstance(prm.raw.get("counts_in_gpa"), bool))
        check("PRM393 prerequisites chứa PRO192", "PRO192" in prm.prerequisites, f"{prm.prerequisites}")
        check("PRM393 appears_in có curriculum + semester",
              bool(prm.appears_in) and all("curriculum" in e and "semester" in e for e in prm.appears_in),
              f"{prm.appears_in}")

    # has_pe phải suy ra được từ dữ liệu thật (có truy vết nguồn)
    no_source = [s.code for s in kb.subjects.values() if not s.raw.get("has_pe_source")]
    check("Mọi Subject có has_pe_source (truy vết được căn cứ)", not no_source, f"thiếu: {no_source[:5]}")
    pe_codes = sorted(s.code for s in kb.subjects.values() if s.raw.get("has_pe"))
    check("Có môn has_pe == true (suy từ bảng đánh giá FLM)", len(pe_codes) > 0, f"số lượng {len(pe_codes)}")
    check("PRM393 has_pe == true (có 'Practical Exam' trong bảng đánh giá)",
          prm is not None and prm.raw.get("has_pe") is True)

    # -------------------------------------------------------------------------
    section("4. SCHEMA FRONT MATTER CURRICULUM (Mục 2.1)")
    # -------------------------------------------------------------------------
    cur_files = sorted((VAULT_DIR / "curricula").glob("*.md"))
    check("Có file Curriculum trong vault/curricula/", len(cur_files) >= 1, f"thực tế {len(cur_files)}")
    if cur_files:
        cur = kb.get_curriculum("BIT_SE_K19B")
        check("Nạp được Curriculum BIT_SE_K19B", cur is not None)
        if cur:
            check("Curriculum có type == 'curriculum'", cur.raw.get("type") == "curriculum")
            check("Curriculum có id", bool(cur.id))
            check("Curriculum có subjects[] dạng {code, semester}",
                  bool(cur.subjects) and all("code" in s and "semester" in s for s in cur.subjects),
                  f"{len(cur.subjects)} entries")
            check("Curriculum có >= 48 môn", len(cur.subjects) >= 48, f"{len(cur.subjects)}")

    # -------------------------------------------------------------------------
    section("5. TRUY VẤN / THỐNG KÊ (Mục 2.2)")
    # -------------------------------------------------------------------------
    stats = kb.curriculum_stats("BIT_SE_K19B")
    check("Thống kê: có semester_count / subject_count / total_credits",
          all(k in stats for k in ("semester_count", "subject_count", "total_credits")))
    check("Thống kê: subject_count >= 48", stats["subject_count"] >= 48, f"{stats['subject_count']}")
    check("Thống kê: total_credits > 0", stats["total_credits"] > 0, f"{stats['total_credits']}")
    check("Thống kê: number of semesters hợp lý (>= 6)", stats["semester_count"] >= 6, f"{stats['semester_count']}")
    check("Thống kê: không có môn 'unknown' (mọi mã đều có file .md)",
          not stats["unknown_subjects"], f"{stats['unknown_subjects'][:5]}")
    check("Thống kê: tổng tín chỉ tính GPA <= tổng tín chỉ",
          stats["total_credits_in_gpa"] <= stats["total_credits"],
          f"{stats['total_credits_in_gpa']} vs {stats['total_credits']}")
    print(f"         | Học kỳ: {stats['semester_count']} | Số môn: {stats['subject_count']} "
          f"| Tín chỉ: {stats['total_credits']} (tính GPA: {stats['total_credits_in_gpa']})")

    appears = kb.subject_appears_in("PRM393")
    check("subject_appears_in('PRM393') trả về danh sách có curriculum + semester",
          bool(appears) and all("curriculum" in a and "semester" in a for a in appears),
          f"{appears}")
    check("Appears_in hỗ trợ nhiều dòng (kiểu trả về là list)",
          isinstance(appears, list))
    check("subject_appears_in(mã không tồn tại) trả về []", kb.subject_appears_in("KHONGCO") == [])

    pre = kb.check_prerequisites("SWP391")
    check("check_prerequisites('SWP391') có prerequisites/chain/depth",
          all(k in pre for k in ("prerequisites", "chain", "depth")))
    check("check_prerequisites('SWP391').chain không rỗng", bool(pre.get("chain")), f"{pre.get('chain')}")
    check("check_prerequisites('SWP391') bao gồm tiên quyết bắc cầu (PRF192)",
          "PRF192" in (pre.get("chain") or []), f"{pre.get('chain')}")
    check("check_prerequisites(mã không tồn tại) báo lỗi rõ ràng",
          "error" in kb.check_prerequisites("KHONGCO"))
    # không có chu trình tiên quyết trong dữ liệu
    cycle_courses = [s.code for s in kb.subjects.values() if kb.check_prerequisites(s.code).get("has_cycle")]
    check("Không phát hiện chu trình tiên quyết", not cycle_courses, f"{cycle_courses[:5]}")

    # -------------------------------------------------------------------------
    section("6. OBSIDIAN GRAPH VIEW (Mục 3)")
    # -------------------------------------------------------------------------
    graph_cfg_path = VAULT_DIR / ".obsidian" / "graph.json"
    check("graph.json tồn tại", graph_cfg_path.exists())
    if graph_cfg_path.exists():
        cfg = json.loads(graph_cfg_path.read_text(encoding="utf-8"))
        groups = cfg.get("colorGroups") or []
        check("colorGroups > 0 (tô màu theo học kỳ)", len(groups) > 0, f"{len(groups)}")
        queries = " ".join(g.get("query", "") for g in groups)
        check("colorGroups có nhóm theo tag học kỳ (HK<n>)", "HK0" in queries and "HK1" in queries, queries[:120])
        check("showArrow == true (cạnh tiên quyết có mũi tên)", cfg.get("showArrow") is True)
        tagged = [s for s in kb.subjects.values() if s.raw.get("tags")]
        check("Subject trong curriculum có tag HK<n>", len(tagged) >= 48, f"{len(tagged)}")

    # -------------------------------------------------------------------------
    section("7. WIKILINK TIÊN QUYẾT HAI CHIỀU (Mục 3)")
    # -------------------------------------------------------------------------
    prm_path = VAULT_DIR / "PRM393.md"
    content = prm_path.read_text(encoding="utf-8") if prm_path.exists() else ""
    check("PRM393.md có [[PRO192]] (liên kết tiên quyết)",
          "[[PRO192]]" in content)
    check("PRM393.md có [[_Curriculum_Overview]]",
          "[[_Curriculum_Overview" in content)
    check("PRM393.md có [[_Program_Learning_Outcomes]]",
          "[[_Program_Learning_Outcomes" in content)

    # Mọi tiên quyết (trừ alias hợp lệ) phải trỏ tới file .md tồn tại
    vault_codes = {normalize_course_code(s.code) for s in kb.subjects.values()}
    broken_links: List[str] = []
    for subj in kb.subjects.values():
        for p in subj.prerequisites:
            if normalize_course_code(p) not in vault_codes:
                broken_links.append(f"{subj.code} -> {p}")
    check("Mọi tiên quyết [[...]] trỏ tới file .md tồn tại trong vault",
          not broken_links, f"{broken_links}")

    # -------------------------------------------------------------------------
    section("8. JSON CHO FLUTTER (tương thích ngược)")
    # -------------------------------------------------------------------------
    check("courses_data.json tồn tại", FLUTTER_JSON.exists())
    if FLUTTER_JSON.exists():
        data = json.loads(FLUTTER_JSON.read_text(encoding="utf-8"))
        check("JSON có các khóa gốc curriculum/plos/semesters/courses/graph",
              all(k in data for k in ("curriculum", "plos", "semesters", "courses", "graph")))
        check("JSON courses >= 48", len(data.get("courses", [])) >= 48, f"{len(data.get('courses', []))}")
        check("JSON curriculum.subjects >= 48",
              len(data.get("curriculum", {}).get("subjects", [])) >= 48)
        check("JSON curriculum có danh sách curricula (đọc từ dữ liệu, không hard-code)",
              bool(data.get("curriculum", {}).get("curricula")))

        jc = [c for c in data["courses"] if normalize_course_code(c.get("code")) == "PRM393"]
        check("JSON PRM393 có has_pe / counts_in_gpa / appears_in",
              bool(jc) and all(k in jc[0] for k in ("has_pe", "counts_in_gpa", "appears_in")))
        # Khóa cũ vẫn còn (backend flm_parser.py + flutter course.dart phụ thuộc)
        legacy_keys = ["code", "code_original", "name", "name_vi", "semester", "credits",
                       "prerequisites", "unlocks", "syllabus_url", "learning_outcomes"]
        if jc:
            legacy_missing = [k for k in legacy_keys if k not in jc[0]]
            check("JSON giữ đủ khóa cũ (backend/Flutter không hỏng)", not legacy_missing, f"thiếu {legacy_missing}")

        nodes = data.get("graph", {}).get("nodes", [])
        edges = data.get("graph", {}).get("edges", [])
        check("Graph nodes >= 48", len(nodes) >= 48, f"{len(nodes)}")
        check("Graph edges > 0 (cạnh tiên quyết)", len(edges) > 0, f"{len(edges)}")
        # id vs code: node id không được chứa ký tự lạ
        bad_ids = [n.get("id") for n in nodes if not re.fullmatch(r"[A-Za-z0-9_]+", str(n.get("id", "")))]
        check("Graph node id không chứa ký tự lạ (*, :, khoảng trắng)",
              not bad_ids, f"{bad_ids[:5]}")
        check("Mọi node có 'type'", all(n.get("type") for n in nodes))
        check("Mọi edge có 'type' == 'prerequisite'",
              all(e.get("type") == "prerequisite" for e in edges),
              f"{[e for e in edges if e.get('type') != 'prerequisite'][:3]}")
        # cạnh phải nối node tồn tại
        node_ids = {n.get("id") for n in nodes}
        dangling_edges = [e for e in edges if e.get("from") not in node_ids or e.get("to") not in node_ids]
        check("Mọi cạnh nối tới node tồn tại (không cạnh treo)",
              not dangling_edges, f"{dangling_edges[:3]}")

        if FLUTTER_ASSET_JSON.exists():
            asset = json.loads(FLUTTER_ASSET_JSON.read_text(encoding="utf-8"))
            check("Bản sao asset Flutter khớp với flm_flutter_data",
                  asset.get("graph", {}).get("nodes") == data.get("graph", {}).get("nodes"))

    # -------------------------------------------------------------------------
    section("9. KẾT QUẢ")
    # -------------------------------------------------------------------------
    total = len(_results)
    failed = [r for r in _results if not r[1]]
    print()
    print(f"  Tổng tiêu chí : {total}")
    print(f"  Đạt           : {total - len(failed)}")
    print(f"  Không đạt     : {len(failed)}")
    if failed:
        print()
        print("  Các tiêu chí KHÔNG ĐẠT:")
        for name, _, detail in failed:
            print(f"    - {name}")
            if detail:
                print(f"      {detail}")
    print()
    print("=" * 78)
    print("  " + ("TẤT CẢ TIÊU CHÍ ĐỀU ĐẠT ✔" if not failed else f"CÒN {len(failed)} TIÊU CHÍ CHƯA ĐẠT ✘"))
    print("=" * 78)
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
