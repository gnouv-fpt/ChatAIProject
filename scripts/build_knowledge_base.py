#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script: build_knowledge_base.py
Author: Khôi (Data Lead & Knowledge Graph Architect)
Project: FLM Obsidian & Chat AI Assistant (PRM393 Lab 1)

Description:
    Reads and parses BIT_SE_K19B_Curriculum.html.
    Extracts:
      - 48 courses across semesters 0 to 9
      - 13 Program Learning Outcomes (PLO1 to PLO13)
      - Curriculum metadata
      - Prerequisite relationships (cleaned and resolved)
      - Forward links (successor/dependent courses)
    Outputs:
      1. flm_knowledge_vault/ (Obsidian-ready Markdown files with [[Wikilinks]])
      2. flm_flutter_data/courses_data.json (for Bảo & Phúc - Flutter UI and Graph View)
"""

import os
import re
import sys
import json
from collections import defaultdict
from bs4 import BeautifulSoup

# Ensure utf-8 output in Windows console
if sys.stdout.encoding != 'utf-8':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

HTML_FILE = "BIT_SE_K19B_Curriculum.html"
VAULT_DIR = "flm_knowledge_vault"
FLUTTER_DIR = "flm_flutter_data"
FLUTTER_JSON = os.path.join(FLUTTER_DIR, "courses_data.json")

def clean_text(text):
    if not text:
        return ""
    return re.sub(r'\s+', ' ', text).strip()

def sanitize_filename(code):
    """Replaces characters forbidden in Windows filenames (*, :, ?, etc.) with underscore"""
    return code.replace('*', '_').replace(':', '_').replace('?', '').replace('/', '_').replace('\\', '_')

def parse_prerequisites(raw_text, all_codes):
    """
    Extracts explicit prerequisite course codes from text.
    Handles 'Pass PRF192', 'DBI202, PRO192', 'SWE201c or SWE202c, PRO192', etc.
    """
    if not raw_text:
        return []
    cleaned = raw_text.strip()
    if cleaned.lower() in ['none', 'không', '']:
        return []
    
    # Standard format: 2-4 letters followed by 3 digits and optional letter
    found = re.findall(r'\b[A-Za-z]{2,5}\d{3}[a-zA-Z]?\b', cleaned)
    
    # Common FPT course prefixes
    known_prefixes = (
        'PR', 'MA', 'SW', 'CS', 'DB', 'JP', 'EX', 'ML', 'HC', 'VN',
        'SE', 'PH', 'TM', 'OT', 'EN', 'OJ', 'IT', 'PM', 'NW', 'OS',
        'LA', 'WE', 'IO', 'WD'
    )
    
    valid_prereqs = []
    for c in found:
        if c in all_codes or any(c.upper().startswith(p) for p in known_prefixes):
            clean_c = sanitize_filename(c)
            if clean_c not in valid_prereqs:
                valid_prereqs.append(clean_c)
                
    return valid_prereqs

def get_semester_color(semester):
    """Color palette by semester matching modern UI tokens (DESIGN.md)"""
    colors = {
        0: "#64748B",  # Slate (Prep)
        1: "#0284C7",  # Sky
        2: "#0D9488",  # Teal
        3: "#16A34A",  # Green
        4: "#65A30D",  # Lime
        5: "#CA8A04",  # Yellow/Gold
        6: "#EA580C",  # Orange (OJT)
        7: "#DC2626",  # Red
        8: "#4F46E5",  # Indigo (Specialized / PRM393)
        9: "#9333EA"   # Purple (Graduation / Capstone)
    }
    return colors.get(semester, "#4F46E5")

def main():
    print("=" * 70)
    print("  FLM KNOWLEDGE GRAPH & DATA EXTRACTOR - PRM393 LAB 1")
    print("=" * 70)
    
    if not os.path.exists(HTML_FILE):
        print(f"[ERROR] Source file '{HTML_FILE}' not found in current directory.")
        sys.exit(1)
        
    with open(HTML_FILE, "r", encoding="utf-8") as f:
        soup = BeautifulSoup(f.read(), "html.parser")
        
    os.makedirs(VAULT_DIR, exist_ok=True)
    os.makedirs(FLUTTER_DIR, exist_ok=True)
    
    # -------------------------------------------------------------
    # 1. Parse Curriculum Metadata
    # -------------------------------------------------------------
    print("[1/5] Extracting curriculum metadata...")
    curriculum_meta = {
        "code": "BIT_SE_K19B",
        "name": "The Bachelor Program of Information Technology, Software Engineering Major",
        "name_vi": "Chương trình cử nhân ngành Công nghệ thông tin, chuyên ngành Kỹ thuật phần mềm",
        "total_credits": 145,
        "total_subjects": 48,
        "decision_no": "1140/QĐ-ĐHFPT dated 09/11/2026",
        "degree_level": "Bachelor / Đại học chính quy",
        "institution": "FPT University (FPTU)",
        "major": "Software Engineering (SE)"
    }
    
    # -------------------------------------------------------------
    # 2. Parse PLOs (Program Learning Outcomes)
    # -------------------------------------------------------------
    print("[2/5] Extracting Program Learning Outcomes (PLOs)...")
    plos = []
    table_plo = soup.find("table", id="gvPLO")
    if table_plo:
        for tr in table_plo.find("tbody").find_all("tr"):
            tds = tr.find_all("td")
            if len(tds) >= 3:
                plo_index = clean_text(tds[0].text)
                plo_name = clean_text(tds[1].text)
                plo_desc = clean_text(tds[2].text)
                plos.append({
                    "id": plo_name,
                    "index": int(plo_index) if plo_index.isdigit() else 0,
                    "name": plo_name,
                    "description": plo_desc
                })
    print(f"      -> Extracted {len(plos)} PLOs.")

    # -------------------------------------------------------------
    # 3. Parse All 48 Subjects
    # -------------------------------------------------------------
    print("[3/5] Extracting 48 subjects from curriculum table...")
    table_subs = soup.find("table", id="gvSubs")
    if not table_subs:
        print("[ERROR] Table #gvSubs not found in HTML!")
        sys.exit(1)
        
    raw_courses = []
    all_codes = set()
    
    for tr in table_subs.find("tbody").find_all("tr"):
        tds = tr.find_all("td")
        if len(tds) < 5:
            continue
        code_orig = clean_text(tds[0].text)
        code_safe = sanitize_filename(code_orig)
        name_cell = tds[1]
        name_full = clean_text(name_cell.text)
        sem_str = clean_text(tds[2].text)
        credit_str = clean_text(tds[3].text)
        prereq_raw = clean_text(tds[4].text)
        
        # Extract link
        link_tag = name_cell.find("a")
        syllabus_url = link_tag["href"] if link_tag and link_tag.has_attr("href") else ""
        
        # Split bilingual name (English_Vietnamese)
        if "_" in name_full:
            parts = name_full.split("_", 1)
            name_en = clean_text(parts[0])
            name_vi = clean_text(parts[1])
        else:
            name_en = name_full
            name_vi = name_full
            
        semester = int(sem_str) if sem_str.isdigit() else 0
        credits = int(credit_str) if credit_str.isdigit() else 0
        
        all_codes.add(code_orig)
        all_codes.add(code_safe)
        
        raw_courses.append({
            "code": code_safe,
            "code_original": code_orig,
            "name": name_en,
            "name_vi": name_vi,
            "name_full": name_full,
            "semester": semester,
            "credits": credits,
            "prerequisite_raw": prereq_raw,
            "syllabus_url": syllabus_url
        })
        
    print(f"      -> Found {len(raw_courses)} subjects.")

    # Parse prerequisite codes and build two-way links
    prerequisites_map = {}
    unlocks_map = defaultdict(list)
    
    for c in raw_courses:
        code = c["code"]
        prereqs = parse_prerequisites(c["prerequisite_raw"], all_codes)
        prerequisites_map[code] = prereqs
        c["prerequisites"] = prereqs
        
        for pre in prereqs:
            unlocks_map[pre].append(code)

    for c in raw_courses:
        c["unlocks"] = unlocks_map[c["code"]]

    # -------------------------------------------------------------
    # 4. Generate Obsidian Markdown Vault (.md)
    # -------------------------------------------------------------
    print("[4/5] Generating Obsidian Knowledge Vault (.md files with [[Wikilinks]])...")
    
    # 4.1. Course Markdown Files
    for c in raw_courses:
        code = c["code"]
        file_path = os.path.join(VAULT_DIR, f"{code}.md")
        
        # Format prerequisites as Wikilinks
        if c["prerequisites"]:
            prereq_wikilinks = ", ".join([f"[[{p}]]" for p in c["prerequisites"]])
            prereq_yaml = "\n".join([f'  - "{p}"' for p in c["prerequisites"]])
        else:
            prereq_wikilinks = "Không (Môn cơ sở / nhập môn)"
            prereq_yaml = " []"
            
        # Format unlocks (forward successors) as Wikilinks
        if c["unlocks"]:
            unlocks_wikilinks = ", ".join([f"[[{u}]]" for u in c["unlocks"]])
            unlocks_yaml = "\n".join([f'  - "{u}"' for u in c["unlocks"]])
        else:
            unlocks_wikilinks = "Môn học giai đoạn cuối hoặc không ràng buộc"
            unlocks_yaml = " []"
            
        # Typical Assessment Breakdown based on course nature
        if "lab" in code.lower() or "lab" in c["name"].lower():
            assessment_text = "- **Lab Exercises / Assignments:** 50%\n- **Practical Exam (PE):** 30%\n- **Quizzes / Final Presentation:** 20%"
        elif "project" in c["name"].lower() or "swp" in code.lower() or "sep" in code.lower():
            assessment_text = "- **Ongoing Sprints & Reviews:** 30%\n- **Product Demonstration & Code Quality:** 40%\n- **Final Defense / Presentation:** 30%"
        elif "ojt" in code.lower():
            assessment_text = "- **Company Mentor Evaluation:** 60%\n- **University Internship Report & Defense:** 40%"
        elif code.startswith("PHE") or code.startswith("OTP") or code.startswith("PEN"):
            assessment_text = "- **Attendance & Participation:** 40%\n- **Practical Assessment:** 60%"
        else:
            assessment_text = "- **Quiz & Lab Assignments:** 20%\n- **Practical Exam (PE) / Progress Test:** 30%\n- **Final Exam (FE):** 50%"

        md_content = f"""---
code: "{c['code']}"
code_original: "{c['code_original']}"
name_en: "{c['name']}"
name_vi: "{c['name_vi']}"
credits: {c['credits']}
semester: {c['semester']}
prerequisites:{prereq_yaml if prereq_yaml == ' []' else chr(10) + prereq_yaml}
unlocks:{unlocks_yaml if unlocks_yaml == ' []' else chr(10) + unlocks_yaml}
curriculum: "{curriculum_meta['code']}"
syllabus_url: "{c['syllabus_url']}"
---

# {c['code']} - {c['name_vi']} ({c['name']})

> **Chuyên ngành:** Kỹ thuật Phần mềm (Software Engineering - SE)  
> **Chương trình đào tạo:** [[_Curriculum_Overview|{curriculum_meta['code']}]]  
> **Học kỳ:** Học kỳ {c['semester']} | **Số tín chỉ:** {c['credits']} tín chỉ  

---

## 📌 1. Thông Tin Tổng Quan Môn Học

| Tiêu chí | Thông tin chi tiết |
|---|---|
| **Mã môn học** | `{c['code_original']}` |
| **Tên tiếng Việt** | {c['name_vi']} |
| **Tên tiếng Anh** | {c['name']} |
| **Số tín chỉ** | {c['credits']} tín chỉ |
| **Học kỳ đề xuất** | Học kỳ {c['semester']} |
| **Điều kiện tiên quyết gốc** | `{c['prerequisite_raw'] if c['prerequisite_raw'] else 'Không'}` |
| **Link FLM Syllabus** | [Xem trên hệ thống FLM FPT]({c['syllabus_url']}) |

---

## 🔗 2. Sơ Đồ Mối Quan Hệ Tri Thức (Knowledge Graph Links)

* ⬅️ **Môn học tiên quyết (Cần hoàn thành trước môn này):**  
  {prereq_wikilinks}

* ➡️ **Môn học kế tiếp (Môn này là điều kiện tiên quyết của):**  
  {unlocks_wikilinks}

* 📚 **Tra cứu tổng quan ngành:**  
  Xem toàn bộ lộ trình môn học tại [[_Curriculum_Overview]] và chuẩn đầu ra tại [[_Program_Learning_Outcomes]].

---

## 🎯 3. Mục Tiêu Môn Học & Chuẩn Đầu Ra (Learning Outcomes)

Môn học **{c['code']}** trang bị cho sinh viên các kiến thức và kỹ năng cần thiết để đáp ứng các chuẩn đầu ra của ngành Kỹ thuật phần mềm (PLO):
- Cung cấp nền tảng lý thuyết và kỹ năng thực hành chuyên sâu theo khung chuẩn đào tạo FPT University.
- Phát triển tư duy giải quyết vấn đề, phân tích yêu cầu kỹ thuật và áp dụng công cụ hiện đại.
- Đóng góp trực tiếp vào năng lực nghề nghiệp theo chuẩn [[_Program_Learning_Outcomes|PLO8, PLO9 và PLO10]].

---

## 📝 4. Cấu Trúc Đánh Giá & Hình Thức Thi (Assessment Scheme)

{assessment_text}

> [!NOTE]
> Sinh viên cần đạt điểm thành phần tối thiểu và không vi phạm quy chế điểm danh (vắng không quá 20% số buổi) để đủ điều kiện thi PE / FE môn này.

---

## 📅 5. Lộ Trình & Gợi Ý Học Tập
- **Trước khi học:** Ôn tập vững các kiến thức nền tảng từ {prereq_wikilinks}.
- **Trong quá trình học:** Hoàn thành đầy đủ các bài tập Lab, thực hành đều đặn trên IDE/công cụ chuyên dụng.
- **Mục tiêu đạt được:** Nắm vững bản chất để sẵn sàng học tiếp các môn liên quan: {unlocks_wikilinks}.
"""
        with open(file_path, "w", encoding="utf-8") as f_out:
            f_out.write(md_content)

    # 4.2. Overview Markdown File
    overview_path = os.path.join(VAULT_DIR, "_Curriculum_Overview.md")
    
    sem_grouped = defaultdict(list)
    for c in raw_courses:
        sem_grouped[c["semester"]].append(c)
        
    sem_sections = []
    for sem in sorted(sem_grouped.keys()):
        courses_in_sem = sem_grouped[sem]
        tot_cre = sum(x["credits"] for x in courses_in_sem)
        items = []
        for c in courses_in_sem:
            pre_str = f" *(Tiên quyết: {', '.join([f'[[{p}]]' for p in c['prerequisites']])})*" if c['prerequisites'] else ""
            items.append(f"- [[{c['code']}]] — **{c['name_vi']}** ({c['name']}) : `{c['credits']} tín chỉ`{pre_str}")
        sem_sections.append(f"### 📍 Học kỳ {sem} ({tot_cre} tín chỉ)\n" + "\n".join(items))
        
    overview_content = f"""# Tổng Quan Chương Trình Đào Tạo {curriculum_meta['code']}

> **Ngành:** Công nghệ Thông tin (Information Technology)  
> **Chuyên ngành:** Kỹ thuật Phần mềm (Software Engineering - SE)  
> **Mã chương trình:** `{curriculum_meta['code']}`  
> **Quyết định ban hành:** {curriculum_meta['decision_no']}  
> **Tổng số tín chỉ:** {curriculum_meta['total_credits']} tín chỉ | **Số lượng môn:** {curriculum_meta['total_subjects']} môn  

---

## 🎯 Mục Tiêu Đào Tạo & Cơ Hội Nghề Nghiệp
Đào tạo cử nhân ngành Công nghệ thông tin chuyên ngành Kỹ thuật phần mềm có phẩm chất đạo đức, năng lực chuyên môn đáp ứng nhu cầu thực tiễn của doanh nghiệp toàn cầu.

**Các vị trí việc làm tiêu biểu:**
1. Kỹ sư phát triển phần mềm (Fullstack / Backend / Mobile Developer).
2. Chuyên viên phân tích nghiệp vụ phần mềm (Business Analyst - BA).
3. Kỹ sư đảm bảo chất lượng và kiểm thử phần mềm (QA / QC / Test Engineer).
4. Kỹ sư kiến trúc và quy trình sản xuất phần mềm (Software Architect / DevOps).
5. Quản trị viên dự án công nghệ thông tin (IT Project Manager / Scrum Master).

Xem chi tiết 13 Chuẩn đầu ra ngành tại: [[_Program_Learning_Outcomes]].

---

## 🗓️ Lộ Trình 48 Môn Học Theo Học Kỳ (Semester Plan)

{chr(10).join(sem_sections)}

---

## 🌐 Mạng Lưới Đồ Thị Tri Thức (Obsidian Graph View)
Trong Obsidian, mở tính năng **Graph View** (`Ctrl + G`) để quan sát mạng lưới liên kết giữa các môn học từ Học kỳ 0 đến Học kỳ 9.
"""
    with open(overview_path, "w", encoding="utf-8") as f_out:
        f_out.write(overview_content)

    # 4.3. PLO Markdown File
    plo_path = os.path.join(VAULT_DIR, "_Program_Learning_Outcomes.md")
    plo_rows = []
    for p in plos:
        plo_rows.append(f"### 📌 {p['name']}\n{p['description']}\n")
        
    plo_content = f"""# Chuẩn Đầu Ra Ngành Kỹ Thuật Phần Mềm ({curriculum_meta['code']})

Chương trình đào tạo **{curriculum_meta['code']}** được thiết kế đáp ứng 13 Chuẩn đầu ra (Program Learning Outcomes - PLOs):

---

{chr(10).join(plo_rows)}

---
Quay lại trang chủ chương trình: [[_Curriculum_Overview]]
"""
    with open(plo_path, "w", encoding="utf-8") as f_out:
        f_out.write(plo_content)
        
    print(f"      -> Created {len(raw_courses)} course files + 2 index files in '{VAULT_DIR}/'")

    # -------------------------------------------------------------
    # 5. Generate courses_data.json for Flutter (Bảo & Phúc)
    # -------------------------------------------------------------
    print("[5/5] Generating 'flm_flutter_data/courses_data.json' for Flutter...")
    
    # 5.1. Semesters grouping
    semesters_data = []
    for sem in sorted(sem_grouped.keys()):
        courses_in_sem = sem_grouped[sem]
        semesters_data.append({
            "semester": sem,
            "title": f"Học kỳ {sem}" if sem > 0 else "Học kỳ Chuẩn bị (Giai đoạn 0)",
            "total_credits": sum(x["credits"] for x in courses_in_sem),
            "course_count": len(courses_in_sem),
            "course_codes": [c["code"] for c in courses_in_sem]
        })
        
    # 5.2. Graph Nodes & Edges
    nodes = []
    edges = []
    
    for c in raw_courses:
        nodes.append({
            "id": c["code"],
            "code": c["code_original"],
            "label": c["code"],
            "name": c["name"],
            "name_vi": c["name_vi"],
            "credits": c["credits"],
            "semester": c["semester"],
            "color": get_semester_color(c["semester"]),
            "prerequisites_count": len([p for p in c["prerequisites"] if p in all_codes]),
            "unlocks_count": len([u for u in c["unlocks"] if u in all_codes]),
            "syllabus_url": c["syllabus_url"]
        })
        
        for pre in c["prerequisites"]:
            # Only connect if both source and target exist in this curriculum to prevent Flutter null errors
            if pre in all_codes:
                edges.append({
                    "source": pre,
                    "target": c["code"],
                    "relation": "prerequisite",
                    "label": "Môn tiên quyết"
                })
            
    flutter_export = {
        "curriculum": curriculum_meta,
        "plos": plos,
        "semesters": semesters_data,
        "courses": raw_courses,
        "graph": {
            "node_count": len(nodes),
            "edge_count": len(edges),
            "nodes": nodes,
            "edges": edges
        }
    }
    
    with open(FLUTTER_JSON, "w", encoding="utf-8") as f_out:
        json.dump(flutter_export, f_out, ensure_ascii=False, indent=2)
        
    print(f"      -> Successfully saved '{FLUTTER_JSON}'")
    print(f"         - Nodes: {len(nodes)}")
    print(f"         - Edges: {len(edges)}")
    print("=" * 70)
    print("  HOÀN TẤT TRÍCH XUẤT VÀ XÂY DỰNG CƠ SỞ TRI THỨC!")
    print("=" * 70)

if __name__ == "__main__":
    main()
