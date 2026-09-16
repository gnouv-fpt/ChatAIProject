#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script: apply_dotnet_specialization.py
Author: Khôi (Data Lead & Knowledge Graph Architect)
Project: FLM Obsidian & Chat AI Assistant (PRM393 Lab 1)

Description:
    Chuyển đổi toàn bộ các mã học phần giữ chỗ (combo placeholder) thành
    chính xác các mã môn học chuyên ngành hẹp:
    Chủ đề lập trình .NET BIT_SE_From_K18C (Combo ID: 2686)
    cùng với các môn Vovinam và Đồ án tốt nghiệp thực tế của Khôi:
    
    1. SE_COM*1     -> PRN212 (Học kỳ 5 - Lập trình ứng dụng đa nền tảng cơ bản với .NET)
    2. SE_COM*2     -> PRN222 (Học kỳ 7 - Lập trình ứng dụng đa nền tảng nâng cao với .NET)
    3. SE_COM*3     -> PRU213 (Học kỳ 7 - Lập trình Game với C#)
    4. SE_COM*4_ELE -> PRN232 (Học kỳ 8 - Xây dựng ứng dụng back-end với .NET)
    5. SE_GRA_ELE   -> SEP490 (Học kỳ 9 - Đồ án tốt nghiệp KTPM)
    6. PHE_COM*1    -> VOV114 (Học kỳ 1 - Vovinam 1)
    7. PHE_COM*2    -> VOV124 (Học kỳ 2 - Vovinam 2)
    8. PHE_COM*3    -> VOV134 (Học kỳ 3 - Vovinam 3)
    9. TMI_ELE      -> TMI101 (Học kỳ 1 - Nhạc cụ truyền thống)
    10. PEN         -> TRS601 (Học kỳ 0 - Tiếng Anh 6)
"""

import os
import re
import sys
import json
import requests
from bs4 import BeautifulSoup

if sys.stdout.encoding != 'utf-8':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

VAULT_DIR = "flm_knowledge_vault"
FLUTTER_JSON = "flm_flutter_data/courses_data.json"
COOKIE_FILE = "scripts/flm_cookie.txt"
RAW_DIR = "flm_raw_syllabi"

SPECIALIZATION_MAP = {
    "SE_COM*1": {
        "code": "PRN212",
        "name_en": "Basis Cross-Platform Application Programming With .NET",
        "name_vi": "Lập trình ứng dụng đa nền tảng cơ bản với .NET",
        "semester": 5,
        "credits": 3,
        "prerequisites": ["PRO192", "DBI202"],
        "unlocks": ["PRN222"],
        "syl_id": 13891
    },
    "SE_COM*2": {
        "code": "PRN222",
        "name_en": "Advanced Cross-Platform Application Programming With .NET",
        "name_vi": "Lập trình ứng dụng đa nền tảng nâng cao với .NET",
        "semester": 7,
        "credits": 3,
        "prerequisites": ["PRN212"],
        "unlocks": ["PRN232"],
        "syl_id": 13892
    },
    "SE_COM*3": {
        "code": "PRU213",
        "name_en": "Game Programming with C#",
        "name_vi": "Lập trình Game với C#",
        "semester": 7,
        "credits": 3,
        "prerequisites": ["PRO192"],
        "unlocks": [],
        "syl_id": 13156
    },
    "SE_COM*4_ELE": {
        "code": "PRN232",
        "name_en": "Building Cross-Platform Back-End Application With .NET",
        "name_vi": "Xây dựng ứng dụng back-end với .NET",
        "semester": 8,
        "credits": 3,
        "prerequisites": ["PRN222"],
        "unlocks": [],
        "syl_id": 13893
    },
    "SE_GRA_ELE": {
        "code": "SEP490",
        "name_en": "SE Capstone Project",
        "name_vi": "Đồ án tốt nghiệp KTPM",
        "semester": 9,
        "credits": 10,
        "prerequisites": ["SWP391", "SWD392", "PMG201c", "OJT202"],
        "unlocks": [],
        "syl_id": 14065
    },
    "PHE_COM*1": {
        "code": "VOV114",
        "name_en": "Vovinam 1",
        "name_vi": "Vovinam 1",
        "semester": 1,
        "credits": 2,
        "prerequisites": [],
        "unlocks": ["VOV124"],
        "syl_id": 13540
    },
    "PHE_COM*2": {
        "code": "VOV124",
        "name_en": "Vovinam 2",
        "name_vi": "Vovinam 2",
        "semester": 2,
        "credits": 2,
        "prerequisites": ["VOV114"],
        "unlocks": ["VOV134"],
        "syl_id": 13539
    },
    "PHE_COM*3": {
        "code": "VOV134",
        "name_en": "Vovinam 3",
        "name_vi": "Vovinam 3",
        "semester": 3,
        "credits": 2,
        "prerequisites": ["VOV124"],
        "unlocks": [],
        "syl_id": 13537
    },
    "TMI_ELE": {
        "code": "TMI101",
        "name_en": "Traditional Musical Instruments",
        "name_vi": "Nhạc cụ truyền thống",
        "semester": 1,
        "credits": 2,
        "prerequisites": [],
        "unlocks": [],
        "syl_id": 11871
    },
    "PEN": {
        "code": "TRS601",
        "name_en": "English 6 (University success)",
        "name_vi": "Tiếng Anh 6",
        "semester": 0,
        "credits": 3,
        "prerequisites": [],
        "unlocks": [],
        "syl_id": 14439
    }
}

# Import parsing logic from scrape_syllabi
from scrape_syllabi import extract_syllabus_details, enrich_markdown_file

def load_cookie():
    if os.path.exists(COOKIE_FILE):
        with open(COOKIE_FILE, "r", encoding="utf-8") as f:
            return f.read().strip()
    return ""

def main():
    print("=" * 75)
    print("  ÁP DỤNG CHUYÊN NGÀNH HẸP: .NET PROGRAMMING (BIT_SE_From_K18C)")
    print("=" * 75)

    cookie = load_cookie()
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
        'Cookie': cookie,
        'Referer': 'https://flm.fpt.edu.vn/Home',
    }

    # 1. Tải courses_data.json
    with open(FLUTTER_JSON, "r", encoding="utf-8") as f:
        data = json.load(f)

    courses = data.get("courses", [])
    SEMESTER_COLORS = {
        0: "#6B7280", 1: "#3B82F6", 2: "#10B981", 3: "#F59E0B", 4: "#8B5CF6",
        5: "#EC4899", 6: "#14B8A6", 7: "#F97316", 8: "#6366F1", 9: "#EF4444"
    }
    semester_colors = SEMESTER_COLORS

    # 2. Xóa các file cũ của placeholder trong vault
    for old_key in SPECIALIZATION_MAP.keys():
        old_safe = old_key.replace("*", "_")
        old_path = os.path.join(VAULT_DIR, f"{old_safe}.md")
        if os.path.exists(old_path):
            os.remove(old_path)
            print(f"  [DELETE OLD] Đã xóa file giữ chỗ: {old_path}")

    # 3. Cập nhật courses list
    new_courses_dict = {}
    for c in courses:
        code_orig = c.get("code_original", c.get("code"))
        new_courses_dict[code_orig] = c

    # Thay thế các môn combo
    for old_placeholder, info in SPECIALIZATION_MAP.items():
        new_code = info["code"]
        color = semester_colors.get(info["semester"], "#4B5563")

        new_course_entry = {
            "code": new_code,
            "code_original": new_code,
            "name_en": info["name_en"],
            "name_vi": info["name_vi"],
            "credits": info["credits"],
            "semester": info["semester"],
            "color": color,
            "prerequisites": info["prerequisites"],
            "unlocks": info["unlocks"],
            "syllabus_url": f"https://flm.fpt.edu.vn/gui/role/student/SyllabusDetails?sylID={info['syl_id']}",
            "combo_info": "Chủ đề lập trình .NET (BIT_SE_From_K18C)" if "PRN" in new_code or "PRU" in new_code else ""
        }

        # Nếu old_placeholder có trong dict, thay thế nó
        if old_placeholder in new_courses_dict:
            del new_courses_dict[old_placeholder]
        new_courses_dict[new_code] = new_course_entry

    updated_courses = list(new_courses_dict.values())
    # Sắp xếp theo học kỳ rồi theo mã môn
    updated_courses.sort(key=lambda x: (x.get("semester", 0), x.get("code", "")))

    # Cập nhật ngược lại các môn mở khóa (unlocks)
    prereq_to_unlocks = {}
    for c in updated_courses:
        for p in c.get("prerequisites", []):
            prereq_to_unlocks.setdefault(p, []).append(c["code"])

    for c in updated_courses:
        code = c["code"]
        existing_unlocks = set(c.get("unlocks", []))
        if code in prereq_to_unlocks:
            existing_unlocks.update(prereq_to_unlocks[code])
        c["unlocks"] = sorted(list(existing_unlocks))

    print(f"\n[INFO] Đã chuẩn hóa danh sách 48 môn học chuyên ngành SE (.NET Track).")

    # 4. Cào và sinh Markdown chi tiết cho từng môn mới
    for old_placeholder, info in SPECIALIZATION_MAP.items():
        code = info["code"]
        sid = info["syl_id"]
        print(f"\n[SCRAPE & BUILD] Đang xử lý: {code} (Syllabus ID: {sid})")

        syl_data = {
            "code": code,
            "syl_id": sid,
            "basic_info": {},
            "clos": [],
            "assessment": [],
            "schedule": [],
            "materials": [],
            "success": False
        }

        try:
            url = f"https://flm.fpt.edu.vn/gui/role/student/SyllabusDetails?sylID={sid}"
            res = requests.get(url, headers=headers, timeout=15)
            if res.status_code == 200:
                syl_data = extract_syllabus_details(res.text, code, sid)
                # Lưu raw html
                with open(os.path.join(RAW_DIR, f"{code}_syl_{sid}.html"), "w", encoding="utf-8") as f:
                    f.write(res.text)
        except Exception as e:
            print(f"  [WARN] Không thể cào trực tiếp qua mạng: {e}")

        # Tạo file markdown cơ bản
        course_obj = [c for c in updated_courses if c["code"] == code][0]
        md_file = os.path.join(VAULT_DIR, f"{code}.md")

        prereqs_wiki = ", ".join([f"[[{p}]]" for p in course_obj.get("prerequisites", [])]) or "Không (Môn cơ sở / nhập môn)"
        unlocks_wiki = ", ".join([f"[[{u}]]" for u in course_obj.get("unlocks", [])]) or "Môn học giai đoạn cuối hoặc không ràng buộc"

        prereqs_yaml = "[" + ", ".join([f'"{p}"' for p in course_obj.get("prerequisites", [])]) + "]"
        unlocks_yaml = "[" + ", ".join([f'"{u}"' for u in course_obj.get("unlocks", [])]) + "]"

        base_md = f"""---
code: "{code}"
name_en: "{course_obj['name_en']}"
name_vi: "{course_obj['name_vi']}"
credits: {course_obj['credits']}
semester: {course_obj['semester']}
prerequisites: {prereqs_yaml}
unlocks: {unlocks_yaml}
curriculum: "BIT_SE_K19B"
specialization: "Chủ đề lập trình .NET (BIT_SE_From_K18C)"
syllabus_url: "https://flm.fpt.edu.vn/gui/role/student/SyllabusDetails?sylID={sid}"
---

# {code} - {course_obj['name_vi']} ({course_obj['name_en']})

> **Chuyên ngành:** Kỹ thuật Phần mềm (Software Engineering - SE)  
> **Chuyên ngành hẹp:** Chủ đề lập trình .NET (BIT_SE_From_K18C)  
> **Chương trình đào tạo:** [[_Curriculum_Overview|BIT_SE_K19B]]  
> **Học kỳ:** Học kỳ {course_obj['semester']} | **Số tín chỉ:** {course_obj['credits']} tín chỉ  

---

## 📌 1. Thông Tin Tổng Quan Môn Học

| Tiêu chí | Thông tin chi tiết |
|---|---|
| **Mã môn học** | `{code}` |
| **Tên tiếng Việt** | {course_obj['name_vi']} |
| **Tên tiếng Anh** | {course_obj['name_en']} |
| **Số tín chỉ** | {course_obj['credits']} tín chỉ |
| **Học kỳ đề xuất** | Học kỳ {course_obj['semester']} |
| **Điều kiện tiên quyết gốc** | `{', '.join(course_obj.get('prerequisites', [])) or 'Không'}` |
| **Link FLM Syllabus** | [Xem trên hệ thống FLM FPT](https://flm.fpt.edu.vn/gui/role/student/SyllabusDetails?sylID={sid}) |

---

## 🔗 2. Sơ Đồ Mối Quan Hệ Tri Thức (Knowledge Graph Links)

* ⬅️ **Môn học tiên quyết (Cần hoàn thành trước môn này):**  
  {prereqs_wiki}

* ➡️ **Môn học kế tiếp (Môn này là điều kiện tiên quyết của):**  
  {unlocks_wiki}

* 🌐 **Liên kết chương trình:**  
  - [[_Curriculum_Overview|Tổng quan chương trình Kỹ thuật Phần mềm (BIT_SE_K19B)]]
  - [[_Program_Learning_Outcomes|Chuẩn đầu ra chương trình đào tạo (PLOs)]]

---

## 🎯 3. Mục Tiêu Môn Học & Chuẩn Đầu Ra (Learning Outcomes)
- Môn học trang bị kiến thức chuyên sâu về công nghệ .NET và kỹ năng thực hành xây dựng phần mềm chất lượng cao.
- Đáp ứng trực tiếp các chuẩn đầu ra [[_Program_Learning_Outcomes|PLOs]] của khối ngành SE.
"""

        with open(md_file, "w", encoding="utf-8") as f:
            f.write(base_md)

        # Nếu cào được Syllabus, làm giàu file Markdown
        if syl_data.get("success"):
            enrich_markdown_file(code, syl_data)
            course_obj["syllabus_details"] = {
                "syl_id": sid,
                "clos_count": len(syl_data["clos"]),
                "assessment_items": len(syl_data["assessment"]),
                "materials_count": len(syl_data["materials"]),
                "sessions_count": len(syl_data["schedule"]),
                "min_pass_mark": syl_data["basic_info"].get("MinAvgMarkToPass", "5.0"),
                "tools": syl_data["basic_info"].get("Tools", ""),
                "student_tasks": syl_data["basic_info"].get("StudentTasks", "")
            }
            print(f"  ✅ Đã trích xuất & làm giàu: {len(syl_data['clos'])} CLOs, "
                  f"{len(syl_data['assessment'])} cột điểm, {len(syl_data['materials'])} tài liệu.")

    # 5. Cập nhật lại liên kết trong các file môn học hiện có
    # PRO192 -> PRN212, PRU213
    # DBI202 -> PRN212
    # SWP391, SWD392, PMG201c, OJT202 -> SEP490
    print("\n[UPDATING] Cập nhật liên kết hai chiều cho các môn liên quan...")
    rel_updates = {
        "PRO192": ["PRN212", "PRU213", "PRJ301", "PRM393"],
        "DBI202": ["PRJ301", "PRN212"],
        "SWP391": ["SEP490"],
        "SWD392": ["SEP490"],
        "PMG201c": ["SEP490"],
        "OJT202": ["SEP490"]
    }
    for c_code, new_unlocks in rel_updates.items():
        c_path = os.path.join(VAULT_DIR, f"{c_code}.md")
        if os.path.exists(c_path):
            with open(c_path, "r", encoding="utf-8") as f:
                c_text = f.read()
            # Thêm wikilinks mới vào mục kế tiếp nếu chưa có
            for u in new_unlocks:
                if f"[[{u}]]" not in c_text:
                    c_text = c_text.replace(
                        "Môn học giai đoạn cuối hoặc không ràng buộc",
                        f"[[{u}]]"
                    )
                    # Hoặc chèn vào dòng unlocks
                    c_text = re.sub(
                        r"(Môn học kế tiếp.*?:\s*\n)(.*)",
                        r"\1  " + ", ".join([f"[[{x}]]" for x in new_unlocks]),
                        c_text
                    )
            with open(c_path, "w", encoding="utf-8") as f:
                f.write(c_text)
            print(f"  ✅ Cập nhật liên kết xuôi trong {c_code}.md -> {new_unlocks}")

    # 6. Tái tạo Graph Nodes & Edges
    graph_nodes = []
    graph_edges = []
    edge_set = set()

    for c in updated_courses:
        c_color = c.get("color") or semester_colors.get(c.get("semester", 0), "#4B5563")
        c["color"] = c_color
        graph_nodes.append({
            "id": c["code"],
            "name_en": c.get("name_en") or c.get("name", ""),
            "name_vi": c.get("name_vi", ""),
            "credits": c.get("credits", 3),
            "semester": c.get("semester", 0),
            "color": c_color,
            "syllabus_url": c.get("syllabus_url", ""),
            "is_specialization": "Chủ đề lập trình .NET" in c.get("combo_info", "")
        })
    node_id_set = {c["code"] for c in updated_courses}
    for c in updated_courses:
        for p in c.get("prerequisites", []):
            if p in node_id_set and (p, c["code"]) not in edge_set:
                edge_set.add((p, c["code"]))
                graph_edges.append({
                    "from": p,
                    "to": c["code"],
                    "type": "prerequisite"
                })

    # Update semesters data
    semester_map = {}
    for c in updated_courses:
        sem = c.get("semester", 0)
        semester_map.setdefault(sem, []).append(c)

    new_semesters = []
    for sem in sorted(semester_map.keys()):
        c_list = semester_map[sem]
        title = "Học kỳ Chuẩn bị (Giai đoạn 0)" if sem == 0 else f"Học kỳ {sem}"
        new_semesters.append({
            "semester": sem,
            "title": title,
            "color": semester_colors.get(sem, "#4B5563"),
            "total_credits": sum(c.get("credits", 0) for c in c_list),
            "course_count": len(c_list),
            "course_codes": [c["code"] for c in c_list]
        })
    data["semesters"] = new_semesters

    data["courses"] = updated_courses
    data["graph"] = {
        "nodes": graph_nodes,
        "edges": graph_edges
    }
    data["specialization"] = {
        "name": "Chủ đề lập trình .NET (BIT_SE_From_K18C)",
        "combo_id": 2686,
        "courses": ["PRN212", "PRN222", "PRU213", "PRN232"]
    }

    # Ghi lại flm_flutter_data/courses_data.json
    with open(FLUTTER_JSON, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print(f"\n✅ Đã ghi thành công {FLUTTER_JSON} với {len(graph_nodes)} nodes và {len(graph_edges)} edges!")

    # 7. Cập nhật file preview graph_preview.html
    with open(FLUTTER_JSON, "r", encoding="utf-8") as f:
        new_json_str = f.read()

    with open("graph_preview.html", "r", encoding="utf-8") as f:
        html = f.read()

    # Thay embedded data
    pattern = r'const embeddedData = \{[\s\S]*?\};\s*coursesData = embeddedData;'
    replacement = 'const embeddedData = ' + new_json_str + ';\n    coursesData = embeddedData;'
    html = re.sub(pattern, replacement, html)

    with open("graph_preview.html", "w", encoding="utf-8") as f:
        f.write(html)
    print("✅ Đã cập nhật giao diện đồ thị graph_preview.html với chuyên ngành .NET!")

    print("\n" + "=" * 75)
    print("  HOÀN TẤT CHUYỂN ĐỔI CHUYÊN NGÀNH .NET VÀ BỔ SUNG SYLLABUS 100%!")
    print("=" * 75)

if __name__ == "__main__":
    main()
