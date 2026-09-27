#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Module: flm_data.py
Author: Khánh (Khối A - Trích xuất dữ liệu & Obsidian)
Project: FLM Obsidian & Chat AI Assistant (PRM393 Lab 1)

MỤC ĐÍCH
    Module dùng chung cho TOÀN BỘ nhóm (khối B, C, D, E gọi lại, KHÔNG tự tính
    riêng). Cung cấp đúng 3 nhóm chức năng theo đặc tả
    `requirement_flm_obsidian_chat_v7.md`:

    1. Chuẩn hóa mã môn (Mục 2.3)
       - Viết hoa, bỏ khoảng trắng, gộp 'Ð' (eth) / 'đ' / 'Đ' về 'D'.

    2. Truy vấn / thống kê (Mục 2.2)
       - Thống kê curriculum: số học kỳ, số môn, tổng tín chỉ.
       - Với một môn: xuất hiện trong curriculum nào, ở học kỳ nào.
       - Kiểm tra tiên quyết dựa trên quan hệ `prerequisites`.

    3. Đọc quy chế tính điểm (Mục 6)
       - Đọc `grading_rules.yaml` (nguồn sự thật duy nhất, do khối E cung cấp).
       - `counts_in_gpa(code)`: khớp danh sách loại trừ theo quy tắc
         "bằng mục trong danh sách HOẶC bắt đầu bằng mục đó".

CÁCH DÙNG (CLI)
    python scripts/flm_data.py stats BIT_SE_K19B
    python scripts/flm_data.py appears PRM393
    python scripts/flm_data.py prereq PRM393
    python scripts/flm_data.py normalize "Ð  prm393 "
"""

from __future__ import annotations

import json
import os
import re
import sys
import unicodedata
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Sequence, Tuple

try:
    import yaml
except ImportError:  # pragma: no cover
    yaml = None  # type: ignore

if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass


# =============================================================================
# 0. ĐƯỜNG DẪN CHUẨN CỦA DỰ ÁN
# =============================================================================

REPO_ROOT = Path(__file__).resolve().parent.parent
VAULT_DIR = REPO_ROOT / "flm_knowledge_vault"
FLUTTER_DATA_DIR = REPO_ROOT / "flm_flutter_data"
FLUTTER_JSON = FLUTTER_DATA_DIR / "courses_data.json"
FLUTTER_ASSET_JSON = REPO_ROOT / "flutter_app" / "assets" / "courses_data.json"
GRADING_RULES_PATH = REPO_ROOT / "grading_rules.yaml"


# =============================================================================
# 1. CHUẨN HÓA MÃ MÔN (Mục 2.3)
# =============================================================================

#: Các ký tự "D gạch ngang" gặp trong dữ liệu FLM / OCR / tên file:
#:   - 'Ð' U+00D0  LATIN CAPITAL LETTER ETH
#:   - 'Đ' U+0110  LATIN CAPITAL LETTER D WITH STROKE
#:   - 'đ' U+0111  LATIN SMALL LETTER D WITH STROKE
#:   - 'ð' U+00F0  LATIN SMALL LETTER ETH
_D_STROKE_CHARS = "\u00d0\u0110\u0111\u00f0"

#: Khoảng trắng "lạ" thường xuất hiện khi copy từ web/PDF/OCR.
_WEIRD_SPACES = "\u00a0\u2007\u202f\u200b\u200e\u200f\ufeff"


def normalize_course_code(raw: Any) -> str:
    """Chuẩn hóa mã môn về dạng so khớp được (Mục 2.3).

    Quy tắc:
      1. ``NFD`` tách tổ hợp Unicode rồi **bỏ dấu tiếng Việt** (combining marks).
      2. Gộp mọi biến thể 'Ð'/'Đ'/'đ'/'ð' (không tách được bằng NFD) về 'D'.
      3. Bỏ toàn bộ khoảng trắng (kể cả NBSP, zero-width).
      4. Viết hoa toàn bộ.

    Nhờ vậy mã môn nhập từ FLM, OCR ảnh bảng điểm hay file cấu hình đều quy về
    cùng một khóa so khớp, ví dụ ``Ð PRM393``, ``đ prm393`` và ``ĐPM393``.

    Ví dụ:
        >>> normalize_course_code("Ð  prm393 ")
        'DPRM393'
        >>> normalize_course_code("Đồ án")
        'DOAN'
        >>> normalize_course_code(None)
        ''

    Lưu ý: đây là khóa so khớp nội bộ, KHÔNG dùng để hiển thị. Mã hiển thị
    giữ nguyên trong trường ``code`` của front matter.
    """
    if raw is None:
        return ""
    text = str(raw)
    # 1. Bỏ dấu tiếng Việt (NFD + loại combining marks).
    text = unicodedata.normalize("NFD", text)
    text = "".join(ch for ch in text if not unicodedata.combining(ch))
    # 2. Gộp các biến thể chữ D gạch ngang / eth.
    for ch in _D_STROKE_CHARS:
        text = text.replace(ch, "D")
    # 3. Bỏ khoảng trắng các loại.
    for sp in _WEIRD_SPACES:
        text = text.replace(sp, "")
    text = re.sub(r"\s+", "", text)
    # 4. Viết hoa.
    return text.upper()


def codes_match(a: Any, b: Any) -> bool:
    """So khớp hai mã môn sau khi chuẩn hóa."""
    return normalize_course_code(a) == normalize_course_code(b)


def normalize_score(raw: Any) -> Optional[float]:
    """Chuẩn hóa số điểm đọc từ ảnh/OCR (Mục 7.1 bước 3).

    Xử lý: dấu phẩy thập phân kiểu Việt Nam ("7,5" -> 7.5), dấu chấm,
    khoảng trắng, ký tự tiền tệ, ô trống/rác -> ``None``.
    """
    if raw is None:
        return None
    if isinstance(raw, (int, float)):
        return float(raw)
    text = str(raw).strip()
    if not text:
        return None
    if normalize_course_code(text) in {"", "-", "--", "N/A", "NA", "NONE", "NULL"}:
        return None
    text = text.replace(",", ".").replace(" ", "")
    text = re.sub(r"[^0-9.\-]", "", text)
    if text.count(".") > 1:  # "7.5.1" kiểu lỗi OCR -> lấy cụm đầu
        text = text.split(".")[0] + "." + text.split(".")[1]
    try:
        value = float(text)
    except ValueError:
        return None
    return value


# =============================================================================
# 2. YAML FRONT MATTER
# =============================================================================

_FRONT_MATTER_RE = re.compile(r"^---\s*\n(.*?)\n---\s*(?:\n|$)", re.DOTALL)


def split_front_matter(raw_text: str) -> Tuple[Dict[str, Any], str]:
    """Tách YAML front matter và phần thân markdown.

    Trả về ``(front_matter_dict, body)``. File không có front matter -> ``({}, raw)``.
    """
    if yaml is None:  # pragma: no cover
        raise RuntimeError("Cần cài PyYAML: pip install pyyaml")
    match = _FRONT_MATTER_RE.match(raw_text)
    if not match:
        return {}, raw_text
    try:
        data = yaml.safe_load(match.group(1)) or {}
    except yaml.YAMLError:
        return {}, raw_text
    if not isinstance(data, dict):
        return {}, raw_text
    return data, raw_text[match.end():]


def read_front_matter(path: Path) -> Dict[str, Any]:
    """Đọc riêng phần YAML front matter của một file ``.md``."""
    if not Path(path).exists():
        return {}
    raw = Path(path).read_text(encoding="utf-8")
    return split_front_matter(raw)[0]


# =============================================================================
# 3. QUY CHẾ TÍNH ĐIỂM — grading_rules.yaml (Mục 6)
# =============================================================================

#: Giá trị mặc định nếu chưa có file `grading_rules.yaml`.
#: Giữ đồng bộ với grading_rules.yaml để khối A không bị chặn tiến độ.
DEFAULT_GRADING_RULES: Dict[str, Any] = {
    "gpa_scale": 10,
    "excluded_from_gpa": ["GDQP", "ENT", "VOV", "TRS", "DSA", "LAB", "OJS", "OJT", "SYB301"],
    "retake": {
        "counts_in_gpa": True,
        "gpa_policy": "last_attempt",
        "penalty_threshold": 2,
        "penalty_levels": 1,
        "applies_to": ["Excellent", "Good"],
        "count_excluded_subjects": True,
        "count_grade_improvement": False,
    },
    "graduation_grades": {"Excellent": 9.0, "Good": 8.0, "Fair": 6.5, "Pass": 5.0},
}


def load_grading_rules(path: Optional[Path] = None) -> Dict[str, Any]:
    """Đọc `grading_rules.yaml`. Fallback về mặc định nếu thiếu file/lỗi parse."""
    target = Path(path) if path else GRADING_RULES_PATH
    if yaml is not None and target.exists():
        try:
            data = yaml.safe_load(target.read_text(encoding="utf-8")) or {}
            if isinstance(data, dict) and data:
                merged = dict(DEFAULT_GRADING_RULES)
                merged.update(data)
                return merged
        except Exception as exc:  # pragma: no cover
            print(f"[flm_data] Cảnh báo: không đọc được {target}: {exc}")
    return dict(DEFAULT_GRADING_RULES)


def is_excluded_from_gpa(course_code: Any, rules: Optional[Dict[str, Any]] = None) -> bool:
    """Mã môn có bị loại khỏi GPA không (Mục 6.1).

    Quy tắc khớp: sau khi chuẩn hóa, mã môn **bằng** một mục trong
    ``excluded_from_gpa`` **HOẶC bắt đầu bằng** mục đó.

    Ví dụ: ``VOV114`` khớp tiền tố ``VOV``; ``SYB301`` khớp mã đầy đủ.
    """
    rules = rules or load_grading_rules()
    code = normalize_course_code(course_code)
    if not code:
        return False
    for prefix in rules.get("excluded_from_gpa", []) or []:
        norm_prefix = normalize_course_code(prefix)
        if norm_prefix and (code == norm_prefix or code.startswith(norm_prefix)):
            return True
    return False


def counts_in_gpa(course_code: Any, rules: Optional[Dict[str, Any]] = None) -> bool:
    """Ngược lại của :func:`is_excluded_from_gpa` — dùng để sinh front matter."""
    return not is_excluded_from_gpa(course_code, rules)


# =============================================================================
# 4. MÔ HÌNH DỮ LIỆU
# =============================================================================

@dataclass
class Subject:
    """Một môn học (đọc từ front matter file Subject .md — schema Mục 2.1)."""

    code: str
    title: str = ""
    title_vi: str = ""
    credits: int = 0
    prerequisites: List[str] = field(default_factory=list)
    has_pe: bool = False
    counts_in_gpa: bool = True
    appears_in: List[Dict[str, Any]] = field(default_factory=list)
    syllabus_url: str = ""
    source_file: Optional[Path] = None
    raw: Dict[str, Any] = field(default_factory=dict)

    @property
    def norm(self) -> str:
        return normalize_course_code(self.code)

    def semesters_in(self, curriculum_id: Optional[str] = None) -> List[int]:
        """Danh sách học kỳ môn này xuất hiện (lọc theo curriculum nếu cần)."""
        out: List[int] = []
        for entry in self.appears_in:
            if curriculum_id and normalize_course_code(entry.get("curriculum", "")) != normalize_course_code(curriculum_id):
                continue
            sem = entry.get("semester")
            if isinstance(sem, int):
                out.append(sem)
        return sorted(out)

    @classmethod
    def from_front_matter(cls, fm: Dict[str, Any], source_file: Optional[Path] = None) -> "Subject":
        appears_in = fm.get("appears_in") or []
        if isinstance(appears_in, dict):  # hỗ trợ YAML viết dạng map
            appears_in = [appears_in]

        # Tương thích ngược: vault cũ lưu phẳng `semester` + `curriculum`.
        if not appears_in:
            legacy_sem = fm.get("semester")
            legacy_cur = fm.get("curriculum")
            if isinstance(legacy_sem, int):
                appears_in = [{"curriculum": legacy_cur or "", "semester": legacy_sem}]

        return cls(
            code=str(fm.get("code") or fm.get("code_original") or (source_file.stem if source_file else "")),
            title=str(fm.get("title") or fm.get("name_en") or fm.get("name") or ""),
            title_vi=str(fm.get("title_vi") or fm.get("name_vi") or ""),
            credits=int(fm.get("credits") or 0),
            prerequisites=[str(p) for p in (fm.get("prerequisites") or [])],
            has_pe=bool(fm.get("has_pe", False)),
            counts_in_gpa=bool(fm.get("counts_in_gpa", True)),
            appears_in=[dict(e) for e in appears_in if isinstance(e, dict)],
            syllabus_url=str(fm.get("syllabus_url") or ""),
            source_file=Path(source_file) if source_file else None,
            raw=dict(fm),
        )


@dataclass
class Curriculum:
    """Một chương trình khung (đọc từ front matter file Curriculum .md)."""

    id: str
    name: str = ""
    name_vi: str = ""
    subjects: List[Dict[str, Any]] = field(default_factory=list)
    raw: Dict[str, Any] = field(default_factory=dict)
    source_file: Optional[Path] = None

    @property
    def norm(self) -> str:
        return normalize_course_code(self.id)

    @classmethod
    def from_front_matter(cls, fm: Dict[str, Any], source_file: Optional[Path] = None) -> "Curriculum":
        subjects = fm.get("subjects") or []
        return cls(
            id=str(fm.get("id") or fm.get("code") or (source_file.stem if source_file else "")),
            name=str(fm.get("name") or ""),
            name_vi=str(fm.get("name_vi") or ""),
            subjects=[dict(s) for s in subjects if isinstance(s, dict)],
            raw=dict(fm),
            source_file=Path(source_file) if source_file else None,
        )


# =============================================================================
# 5. KHO TRI THỨC DÙNG CHUNG (Mục 2.2)
# =============================================================================

class FLMKnowledgeBase:
    """Nạp toàn bộ vault và cung cấp API thống kê dùng chung cho mọi khối.

    Ví dụ::

        kb = FLMKnowledgeBase()
        kb.curriculum_stats("BIT_SE_K19B")
        kb.subject_appears_in("PRM393")
        kb.check_prerequisites("SWP391")
    """

    def __init__(self, vault_dir: Optional[Path] = None, rules: Optional[Dict[str, Any]] = None):
        self.vault_dir = Path(vault_dir) if vault_dir else VAULT_DIR
        self.rules = rules or load_grading_rules()
        self.subjects: Dict[str, Subject] = {}      # key = mã đã chuẩn hóa
        self.curricula: Dict[str, Curriculum] = {}  # key = id đã chuẩn hóa
        self._load()

    # -- Nạp dữ liệu ---------------------------------------------------------
    def _load(self) -> None:
        if not self.vault_dir.exists():
            print(f"[flm_data] Không tìm thấy vault: {self.vault_dir}")
            return
        # Đệ quy để bắt cả file curriculum trong thư mục con (curricula/).
        # Bỏ qua các file index bắt đầu bằng "_" (ví dụ _Curriculum_Overview.md).
        for md_file in sorted(self.vault_dir.rglob("*.md")):
            if md_file.name.startswith("_"):
                continue
            fm = read_front_matter(md_file)
            if not fm:
                continue
            doc_type = normalize_course_code(fm.get("type", ""))
            if doc_type == "CURRICULUM" or ("subjects" in fm and "credits" not in fm):
                cur = Curriculum.from_front_matter(fm, md_file)
                self.curricula[cur.norm] = cur
            else:
                subj = Subject.from_front_matter(fm, md_file)
                self.subjects[subj.norm] = subj

    # -- Tiện ích tra cứu ----------------------------------------------------
    def get_subject(self, code: Any) -> Optional[Subject]:
        """Tra môn học theo mã (đã chuẩn hóa). ``None`` nếu không có."""
        return self.subjects.get(normalize_course_code(code))

    def get_curriculum(self, curriculum_id: Any) -> Optional[Curriculum]:
        """Tra curriculum theo id (đã chuẩn hóa)."""
        return self.curricula.get(normalize_course_code(curriculum_id))

    def all_subject_codes(self) -> List[str]:
        return sorted(s.code for s in self.subjects.values())

    # -- API 1: Thống kê curriculum (Mục 2.2) --------------------------------
    def curriculum_stats(self, curriculum_id: Any) -> Dict[str, Any]:
        """Thống kê 1 curriculum: số học kỳ, số môn, tổng tín chỉ.

        Trả về dict::

            {
              "curriculum": "BIT_SE_K19B",
              "name": "...",
              "semester_count": 10,
              "subject_count": 48,
              "total_credits": 145,
              "total_credits_in_gpa": 130,
              "semesters": [{"semester": 1, "subject_count": 7,
                             "total_credits": 17, "subject_codes": [...]}, ...],
              "unknown_subjects": ["..."]   # mã có trong curriculum nhưng thiếu file .md
            }
        """
        cur = self.get_curriculum(curriculum_id)
        entries: List[Dict[str, Any]] = []
        if cur and cur.subjects:
            entries = list(cur.subjects)
        else:
            # Fallback: suy ra từ `appears_in` của từng Subject (không hard-code).
            target = normalize_course_code(curriculum_id)
            for subj in self.subjects.values():
                for entry in subj.appears_in:
                    if normalize_course_code(entry.get("curriculum", "")) == target:
                        entries.append({"code": subj.code, "semester": entry.get("semester")})

        per_semester: Dict[int, Dict[str, Any]] = {}
        unknown: List[str] = []
        total_credits = 0
        total_credits_gpa = 0

        for entry in entries:
            code = entry.get("code")
            sem = entry.get("semester")
            subj = self.get_subject(code)
            if subj is None:
                unknown.append(str(code))
                continue
            credits = subj.credits
            total_credits += credits
            if subj.counts_in_gpa:
                total_credits_gpa += credits
            sem_key = int(sem) if isinstance(sem, int) else 0
            bucket = per_semester.setdefault(
                sem_key, {"semester": sem_key, "subject_count": 0, "total_credits": 0, "subject_codes": []}
            )
            bucket["subject_count"] += 1
            bucket["total_credits"] += credits
            bucket["subject_codes"].append(subj.code)

        semesters = [per_semester[k] for k in sorted(per_semester)]
        return {
            "curriculum": cur.id if cur else str(curriculum_id),
            "name": (cur.name if cur else "") or "",
            "name_vi": (cur.name_vi if cur else "") or "",
            "semester_count": len(semesters),
            "subject_count": sum(s["subject_count"] for s in semesters),
            "total_credits": total_credits,
            "total_credits_in_gpa": total_credits_gpa,
            "semesters": semesters,
            "unknown_subjects": sorted(set(unknown)),
        }

    # -- API 2: Môn xuất hiện ở đâu (Mục 2.2) --------------------------------
    def subject_appears_in(self, subject_code: Any) -> List[Dict[str, Any]]:
        """Môn X xuất hiện trong curriculum nào, ở học kỳ nào.

        Trả về ``[{"curriculum": "BIT_SE_K19B", "semester": 8}, ...]``.
        Thiết kế hỗ trợ nhiều dòng (1 môn có thể ở nhiều curriculum/học kỳ khác nhau).
        """
        subj = self.get_subject(subject_code)
        if subj is None:
            return []
        result = []
        for entry in subj.appears_in:
            result.append(
                {
                    "curriculum": str(entry.get("curriculum", "")),
                    "semester": entry.get("semester"),
                }
            )
        return result

    # -- API 3: Kiểm tra tiên quyết (Mục 2.2) --------------------------------
    def check_prerequisites(self, subject_code: Any) -> Dict[str, Any]:
        """Kiểm tra tiên quyết của một môn dựa trên quan hệ ``prerequisites``.

        Trả về::

            {
              "code": "SWP391",
              "prerequisites": ["PRJ301", "SWE201c", "LAB211"],
              "missing_files": ["..."],      # tiên quyết không có file .md
              "dangling": [...],             # như trên (alias, giữ tương thích)
              "chain": ["SWE201c", "PRO192", ...],  # toàn bộ tổ tiên (dedup, BFS)
              "depth": {"SWP391": 0, "PRJ301": 1, ...},
              "has_cycle": false,
              "cycles": []
            }
        """
        subj = self.get_subject(subject_code)
        if subj is None:
            return {"code": str(subject_code), "error": "Không tìm thấy môn học trong vault."}

        direct = list(subj.prerequisites)
        depth: Dict[str, int] = {subj.code: 0}
        chain: List[str] = []
        missing: List[str] = []
        queue: List[Tuple[str, int]] = [(p, 1) for p in direct]
        cycles: List[List[str]] = []

        while queue:
            code, level = queue.pop(0)
            norm = normalize_course_code(code)
            if norm in depth and depth.get(norm) is not None:
                # đã thăm -> bỏ qua (đồng thời tránh lặp vô hạn nếu có chu trình)
                continue
            node = self.get_subject(code)
            if node is None:
                missing.append(code)
                depth[norm] = level
                continue
            depth[node.code] = level
            chain.append(node.code)
            for pre in node.prerequisites:
                if normalize_course_code(pre) in depth:
                    cycles.append([node.code, pre])
                queue.append((pre, level + 1))

        # Bỏ chu trình tự thân khỏi báo cáo nhiễu
        cycles = [c for c in cycles if normalize_course_code(c[0]) != normalize_course_code(c[1])]

        return {
            "code": subj.code,
            "prerequisites": direct,
            "missing_files": missing,
            "dangling": missing,
            "chain": chain,
            "depth": depth,
            "has_cycle": bool(cycles),
            "cycles": cycles,
        }

    def prerequisite_graph(self) -> Dict[str, List[Tuple[str, str]]]:
        """Sinh cạnh tiên quyết (tiên quyết -> môn sau) cho các khối B/C dùng."""
        edges: List[Tuple[str, str]] = []
        for subj in self.subjects.values():
            for pre in subj.prerequisites:
                if self.get_subject(pre) is not None:
                    edges.append((self.get_subject(pre).code, subj.code))
        return {"edges": edges}


# =============================================================================
# 6. CLI TIỆN DỤNG
# =============================================================================

def _cli(argv: Sequence[str]) -> int:
    if not argv:
        print(__doc__)
        return 0

    command = argv[0].lower()
    kb = FLMKnowledgeBase()

    if command == "stats":
        cid = argv[1] if len(argv) > 1 else "BIT_SE_K19B"
        print(json.dumps(kb.curriculum_stats(cid), ensure_ascii=False, indent=2))
    elif command == "appears":
        if len(argv) < 2:
            print("Thiếu mã môn. Ví dụ: appears PRM393")
            return 2
        print(json.dumps(kb.subject_appears_in(argv[1]), ensure_ascii=False, indent=2))
    elif command == "prereq":
        if len(argv) < 2:
            print("Thiếu mã môn. Ví dụ: prereq SWP391")
            return 2
        print(json.dumps(kb.check_prerequisites(argv[1]), ensure_ascii=False, indent=2))
    elif command == "normalize":
        print(normalize_course_code(argv[1] if len(argv) > 1 else ""))
    elif command == "gpa-rule":
        code = argv[1] if len(argv) > 1 else ""
        print(json.dumps(
            {
                "code": code,
                "normalized": normalize_course_code(code),
                "counts_in_gpa": counts_in_gpa(code, kb.rules),
            },
            ensure_ascii=False,
            indent=2,
        ))
    else:
        print(f"Lệnh không hợp lệ: {command}")
        print("Dùng: stats | appears | prereq | normalize | gpa-rule")
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(_cli(sys.argv[1:]))
