#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script: configure_obsidian_graph.py
Author: Khánh (Khối A — Trích xuất dữ liệu & Obsidian)
Project: FLM Obsidian & Chat AI Assistant (PRM393 Lab 1)

MỤC ĐÍCH (Mục 3 — Bước 2: Graph trên Obsidian)
    Sinh/cập nhật `flm_knowledge_vault/.obsidian/graph.json` để Graph View gốc
    của Obsidian tô màu nhóm THEO HỌC KỲ và điều chỉnh lực mô phỏng, phục vụ:
      - Kiểm chứng dữ liệu (tiên quyết đúng, môn đúng học kỳ).
      - Làm bản đối chiếu chuẩn cho Graph View trong app (khối C, Mục 4.3).

CÁCH LÀM
    Bảng màu lấy từ `scripts/build_knowledge_base.py::get_semester_color()` để
    Obsidian và app Flutter dùng CHUNG một hệ màu, không lệch nhau.
    Màu được ghi vào `colorGroups` với query `path:"HK<n>"` — script đồng thời
    gắn tag học kỳ `HK<n>` vào front matter từng Subject để query này khớp.

CHẠY
    python scripts/configure_obsidian_graph.py
    python scripts/configure_obsidian_graph.py --dry-run
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any, Dict, List

sys.path.insert(0, str(Path(__file__).resolve().parent))

from flm_data import VAULT_DIR, read_front_matter  # noqa: E402

if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass


#: Hệ màu theo học kỳ — ĐỒNG BỘ với scripts/build_knowledge_base.py
#: (get_semester_color). Không đổi lệch ở một phía.
SEMESTER_COLORS: Dict[int, str] = {
    0: "#64748B",  # Slate — Học kỳ chuẩn bị
    1: "#0284C7",  # Sky
    2: "#0D9488",  # Teal
    3: "#16A34A",  # Green
    4: "#65A30D",  # Lime
    5: "#CA8A04",  # Yellow/Gold
    6: "#EA580C",  # Orange (OJT)
    7: "#DC2626",  # Red
    8: "#4F46E5",  # Indigo
    9: "#9333EA",  # Purple (Capstone)
}

_EXTRA_GROUPS: List[Dict[str, Any]] = [
    # Curriculum + các file index
    {"query": "file:curricula OR file:Curriculum OR file:Program", "rgb": 16498468},
]


def hex_to_rgb_int(hex_color: str) -> int:
    """'#4F46E5' -> 5200101 (số nguyên RGB mà Obsidian dùng trong graph.json)."""
    value = hex_color.lstrip("#")
    return int(value, 16)


def build_color_groups() -> List[Dict[str, Any]]:
    groups: List[Dict[str, Any]] = []
    for sem in sorted(SEMESTER_COLORS):
        groups.append(
            {
                "query": f"tag:#HK{sem}",
                "color": {"a": 1, "rgb": hex_to_rgb_int(SEMESTER_COLORS[sem])},
            }
        )
    for extra in _EXTRA_GROUPS:
        groups.append({"query": extra["query"], "color": {"a": 1, "rgb": extra["rgb"]}})
    return groups


def count_tagged_subjects(vault: Path) -> int:
    """Đếm số Subject đã có tag HK<n> (do enrich_vault_schema.py sinh)."""
    count = 0
    for md_path in sorted(vault.glob("*.md")):
        if md_path.name.startswith("_"):
            continue
        fm = read_front_matter(md_path)
        if fm.get("type") == "subject" and fm.get("tags"):
            count += 1
    return count


def build_graph_config(existing: Dict[str, Any]) -> Dict[str, Any]:
    """Giữ các khóa hiển thị người dùng đã chỉnh, chỉ thay phần màu."""
    config = dict(existing) if existing else {}
    config.update(
        {
            "collapse-filter": config.get("collapse-filter", True),
            "search": config.get("search", ""),
            "showTags": True,          # bật tag để nhìn thấy nhóm học kỳ
            "showAttachments": False,
            "hideUnresolved": False,
            "showOrphans": True,
            "collapse-color-groups": False,
            "colorGroups": build_color_groups(),
            "collapse-display": False,
            "showArrow": True,          # mũi tên chỉ hướng tiên quyết (Mục 4.3.a)
            "textFadeMultiplier": config.get("textFadeMultiplier", 0),
            "nodeSizeMultiplier": config.get("nodeSizeMultiplier", 1.25),
            "lineSizeMultiplier": config.get("lineSizeMultiplier", 1.4),
            "collapse-forces": config.get("collapse-forces", False),
            "centerStrength": config.get("centerStrength", 0.45),
            "repelStrength": config.get("repelStrength", 12),
            "linkStrength": config.get("linkStrength", 1),
            "linkDistance": config.get("linkDistance", 220),
            "scale": config.get("scale", 0.9),
            "close": config.get("close", False),
        }
    )
    return config


def main() -> int:
    parser = argparse.ArgumentParser(description="Cấu hình Obsidian Graph View theo học kỳ.")
    parser.add_argument("--dry-run", action="store_true", help="Chỉ báo cáo, không ghi.")
    parser.add_argument("--vault", default=str(VAULT_DIR))
    args = parser.parse_args()

    vault = Path(args.vault)
    obsidian_dir = vault / ".obsidian"
    graph_path = obsidian_dir / "graph.json"

    print("=" * 78)
    print("  CẤU HÌNH OBSIDIAN GRAPH VIEW — KHỐI A (Khánh)")
    print("=" * 78)
    print(f"  Vault : {vault}")
    print(f"  Chế độ: {'DRY-RUN' if args.dry_run else 'GHI FILE'}")
    print("  Nguồn tag HK<n>: do scripts/enrich_vault_schema.py sinh ở front matter.")
    print()

    existing: Dict[str, Any] = {}
    if graph_path.exists():
        try:
            existing = json.loads(graph_path.read_text(encoding="utf-8"))
        except Exception as exc:
            print(f"[WARN] graph.json lỗi định dạng, dùng mặc định: {exc}")

    config = build_graph_config(existing)
    print(f"  Nhóm màu theo học kỳ : {len(SEMESTER_COLORS)}")
    for sem, color in sorted(SEMESTER_COLORS.items()):
        print(f"      HK{sem:<2} -> {color}")
    print(f"  Nhóm bổ sung         : {len(_EXTRA_GROUPS)} (curriculum/index)")

    tagged = count_tagged_subjects(vault)
    print(f"  Subject có tag HK<n> : {tagged}")

    if not args.dry_run:
        obsidian_dir.mkdir(parents=True, exist_ok=True)
        with open(graph_path, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(json.dumps(config, ensure_ascii=False, indent=2))
        print(f"\n  ✔ Đã ghi {graph_path.relative_to(vault.parent)}")
    else:
        print("\n  (DRY-RUN: chưa ghi thay đổi nào.)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
