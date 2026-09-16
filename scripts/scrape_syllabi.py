#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script: scrape_syllabi.py
Author: Khôi (Data Lead & Knowledge Graph Architect)
Project: FLM Obsidian & Chat AI Assistant (PRM393 Lab 1)

Description:
    Tự động sử dụng Cookie phiên làm việc FLM đã xác thực để:
    1. Lấy danh sách Syllabus chi tiết (SyllabusDetails?sylID=...) của từng môn.
    2. Trích xuất 100% dữ liệu gốc:
       - Chuẩn đầu ra (CLO1 - CLOn)
       - Thang điểm thi và đánh giá (PE, FE, PT, Lab, Project, điểm liệt, hình thức thi)
       - Yêu cầu công cụ phần mềm & điều kiện dự thi (Tools, Attendance > 80%, Min Pass Mark)
       - Giáo trình và tài liệu tham khảo (Materials, Books, Online links)
       - Lịch trình 30-60 buổi học chi tiết (Sessions & Topics)
    3. Cập nhật trực tiếp vào Obsidian Knowledge Vault (flm_knowledge_vault/*.md)
    4. Cập nhật dữ liệu cấu trúc vào flm_flutter_data/courses_data.json
"""

import os
import re
import sys
import json
import time
import random
import requests
from bs4 import BeautifulSoup

if sys.stdout.encoding != 'utf-8':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

COOKIE_FILE = os.path.join(os.path.dirname(__file__), "flm_cookie.txt")
CURRICULUM_ID = "3338"
BASE_URL = "https://flm.fpt.edu.vn"
VAULT_DIR = "flm_knowledge_vault"
FLUTTER_JSON = "flm_flutter_data/courses_data.json"
RAW_SYLLABI_DIR = "flm_raw_syllabi"

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
                  "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "vi-VN,vi;q=0.9,en;q=0.8",
    "Referer": f"{BASE_URL}/Home",
    "Connection": "keep-alive",
}

def load_cookie():
    if not os.path.exists(COOKIE_FILE):
        print(f"[ERROR] Không tìm thấy file: {COOKIE_FILE}")
        sys.exit(1)

    with open(COOKIE_FILE, "r", encoding="utf-8") as f:
        cookie_str = f.read().strip()

    if not cookie_str:
        print("[ERROR] Cookie rỗng. Vui lòng kiểm tra lại.")
        sys.exit(1)

    return cookie_str

def extract_syllabus_details(html_content, subject_code, syl_id):
    """
    Phân tích trang SyllabusDetails của FLM.
    Nhận diện bảng theo cấu trúc headers động để không phụ thuộc vào thứ tự table.
    """
    soup = BeautifulSoup(html_content, "html.parser")
    result = {
        "code": subject_code,
        "syl_id": syl_id,
        "basic_info": {},
        "clos": [],
        "assessment": [],
        "schedule": [],
        "materials": [],
        "success": True
    }

    if "Login" in soup.get_text()[:400] or soup.find("input", {"type": "password"}):
        result["success"] = False
        result["error"] = "Phiên đăng nhập đã hết hạn (Cookie expired)"
        return result

    tables = soup.find_all("table")

    for tbl in tables:
        # Lấy tiêu đề các cột
        th_list = [th.get_text(strip=True) for th in tbl.find_all("th")]
        th_lower = [t.lower() for t in th_list]

        # 1. Bảng Thông tin cơ bản (thường là key-value không có th hoặc th là 2 cột)
        if not th_list and len(tbl.find_all("tr")) >= 8:
            for tr in tbl.find_all("tr"):
                cells = [c.get_text(strip=True) for c in tr.find_all(["td", "th"])]
                if len(cells) >= 2 and cells[0]:
                    key = cells[0].rstrip(":").strip()
                    val = " ".join(cells[1:]).strip()
                    result["basic_info"][key] = val

        # 2. Bảng Materials / Giáo trình tài liệu
        elif any("material description" in t or "author" in t or "publisher" in t for t in th_lower):
            for tr in tbl.find_all("tr")[1:]:
                cells = [c.get_text(strip=True) for c in tr.find_all(["td", "th"])]
                if len(cells) >= 3:
                    # No, Description, Author, Publisher, Published Date, Edition, ISBN, Is Main, ...
                    mat = {
                        "description": cells[1] if len(cells) > 1 else "",
                        "author": cells[2] if len(cells) > 2 else "",
                        "publisher": cells[3] if len(cells) > 3 else "",
                        "year": cells[4] if len(cells) > 4 else "",
                        "edition": cells[5] if len(cells) > 5 else "",
                        "isbn": cells[6] if len(cells) > 6 else "",
                        "is_main": cells[7] if len(cells) > 7 else "",
                        "note": cells[10] if len(cells) > 10 else ""
                    }
                    result["materials"].append(mat)

        # 3. Bảng CLOs (Course Learning Outcomes)
        elif any("clo name" in t or "clo details" in t or "lo name" in t for t in th_lower):
            for tr in tbl.find_all("tr")[1:]:
                cells = [c.get_text(strip=True) for c in tr.find_all(["td", "th"])]
                if len(cells) >= 3:
                    result["clos"].append({
                        "name": cells[1],
                        "details": cells[2]
                    })
                elif len(cells) == 2:
                    result["clos"].append({
                        "name": cells[0],
                        "details": cells[1]
                    })

        # 4. Bảng Đánh giá học phần (Assessment Scheme)
        elif any("weight" in t for t in th_lower) and any("category" in t or "completion criteria" in t or "part" in t for t in th_lower):
            for tr in tbl.find_all("tr")[1:]:
                cells = [c.get_text(strip=True) for c in tr.find_all(["td", "th"])]
                if len(cells) >= 5:
                    # ['No.', 'Category', 'Type', 'Part', 'Weight', 'Completion Criteria', 'Duration', 'CLO', 'Question Type', 'No Question', 'Knowledge and Skill', 'Grading Guide', 'Note']
                    asmt = {
                        "category": cells[1] if len(cells) > 1 else "",
                        "type": cells[2] if len(cells) > 2 else "",
                        "part": cells[3] if len(cells) > 3 else "",
                        "weight": cells[4] if len(cells) > 4 else "",
                        "min_criteria": cells[5] if len(cells) > 5 else "",
                        "duration": cells[6] if len(cells) > 6 else "",
                        "clo": cells[7] if len(cells) > 7 else "",
                        "question_type": cells[8] if len(cells) > 8 else "",
                        "grading_guide": cells[11] if len(cells) > 11 else "",
                        "note": cells[12] if len(cells) > 12 else ""
                    }
                    result["assessment"].append(asmt)

        # 5. Bảng Lịch học / Sessions
        elif any("session" in t for t in th_lower) and any("topic" in t or "learning-teaching type" in t for t in th_lower):
            for tr in tbl.find_all("tr")[1:]:
                cells = [c.get_text(strip=True) for c in tr.find_all(["td", "th"])]
                if len(cells) >= 2 and cells[0].isdigit():
                    result["schedule"].append({
                        "session": cells[0],
                        "topic": cells[1] if len(cells) > 1 else "",
                        "type": cells[2] if len(cells) > 2 else "",
                        "lo": cells[3] if len(cells) > 3 else "",
                        "materials": cells[5] if len(cells) > 5 else ""
                    })

    return result

def enrich_markdown_file(code, syllabus_info):
    """
    Cập nhật file Markdown trong flm_knowledge_vault/ với dữ liệu chuẩn từ Syllabus.
    """
    safe_code = code.replace("*", "_")
    md_path = os.path.join(VAULT_DIR, f"{safe_code}.md")
    if not os.path.exists(md_path):
        return

    with open(md_path, "r", encoding="utf-8") as f:
        content = f.read()

    # Xóa phần syllabus cũ nếu đã từng chèn trước đó để tránh trùng lặp
    marker = "## 🔬 DỮ LIỆU SYLLABUS CHI TIẾT"
    if marker in content:
        content = content.split(marker)[0].rstrip()

    # Tạo nội dung bổ sung cực kỳ chi tiết cho AI RAG
    sections = [f"\n\n---\n\n{marker} (Trích Xuất Từ FLM FPT University)"]

    info = syllabus_info.get("basic_info", {})
    if info:
        sections.append(f"""
### ⚙️ Thông Tin Quy Chuẩn & Điều Kiện Môn Học
- **Thang điểm:** {info.get('Scoring Scale', '10')}
- **Điểm trung bình tối thiểu để qua môn (MinAvgMarkToPass):** `{info.get('MinAvgMarkToPass', '5.0')}`
- **Phân bổ thời gian học (Time Allocation):** {info.get('Time Allocation', 'N/A')}
- **Phương pháp giảng dạy:** {info.get('Learning-Teaching Method', 'N/A')}
- **Quyết định ban hành:** {info.get('DecisionNo MM/dd/yyyy', 'N/A')}
- **Yêu cầu chuyên cần & sinh viên (Student Tasks):**
> {info.get('StudentTasks', 'Tham gia trên 80% số buổi học để đủ điều kiện thi.')}
- **Công cụ & phần mềm yêu cầu (Tools & Software):**
> {info.get('Tools', 'N/A')}
""")
        if info.get("Note"):
            sections.append(f"- **Ghi chú thêm:** {info.get('Note')}\n")

    # CLOs
    clos = syllabus_info.get("clos", [])
    if clos:
        sections.append("### 🎯 Chuẩn Đầu Ra Môn Học (Course Learning Outcomes - CLOs)\n")
        sections.append("| Mã CLO | Mô Tả Chi Tiết Mục Tiêu |")
        sections.append("|---|---|")
        for clo in clos:
            sections.append(f"| **{clo['name']}** | {clo['details']} |")
        sections.append("")

    # Assessment Scheme
    asmts = syllabus_info.get("assessment", [])
    if asmts:
        sections.append("### 📊 Cấu Trúc Điểm Thi & Đánh Giá Chi Tiết (Assessment Scheme)\n")
        sections.append("| Thành Phần Đánh Giá | Tỷ Trọng (%) | Điểm Tối Thiểu (Liệt) | Thời Lượng | Hình Thức Đánh Giá | Ghi Chú |")
        sections.append("|---|---|---|---|---|---|")
        for a in asmts:
            name = a['category']
            if a.get('part') and a['part'] not in ['1', '']:
                name += f" (Part {a['part']})"
            sections.append(
                f"| **{name}** | **{a['weight']}** | `{a['min_criteria']}` | {a['duration']} | {a['question_type']} | {a['note'] or a['grading_guide']} |"
            )
        sections.append("")

    # Materials
    mats = syllabus_info.get("materials", [])
    if mats:
        sections.append("### 📚 Giáo Trình & Tài Liệu Tham Khảo (Materials)\n")
        for idx, m in enumerate(mats, 1):
            is_main = " ⭐ **[Giáo trình chính]**" if m.get("is_main", "").lower() == "true" else ""
            sections.append(f"{idx}.{is_main} *{m['description']}*")
            if m.get("author"):
                sections.append(f"   - Tác giả: {m['author']} | NXB: {m['publisher']} ({m['year']}) | Tái bản: {m['edition']}")
            if m.get("isbn"):
                sections.append(f"   - ISBN: `{m['isbn']}`")
            if m.get("note"):
                sections.append(f"   - Link / Ghi chú: {m['note']}")
        sections.append("")

    # Schedule / Sessions (Top 20 sessions đầu để tránh file quá dài hoặc toàn bộ nếu cần)
    sched = syllabus_info.get("schedule", [])
    if sched:
        sections.append(f"### 🗓️ Lịch Trình Buổi Học ({len(sched)} Buổi)\n")
        sections.append("| Buổi | Chủ Đề / Nội Dung (Topic) | Hình Thức | Chuẩn Đầu Ra (LO) | Tài Liệu Chuẩn Bị |")
        sections.append("|---|---|---|---|---|")
        for s in sched:
            sections.append(f"| Slot {s['session']} | {s['topic']} | {s['type']} | {s['lo']} | {s['materials']} |")
        sections.append("")

    new_content = content + "\n".join(sections)
    with open(md_path, "w", encoding="utf-8") as f:
        f.write(new_content)

def main():
    print("=" * 75)
    print("  FLM DEEP SYLLABUS SCRAPER — Trích xuất 100% dữ liệu gốc từ FLM")
    print("=" * 75)

    cookie_str = load_cookie()
    HEADERS["Cookie"] = cookie_str

    if not os.path.exists(FLUTTER_JSON):
        print(f"[ERROR] Không tìm thấy {FLUTTER_JSON}")
        sys.exit(1)

    with open(FLUTTER_JSON, "r", encoding="utf-8") as f:
        flutter_data = json.load(f)

    courses = flutter_data.get("courses", [])
    print(f"[INFO] Tổng số môn học cần xử lý: {len(courses)}")

    os.makedirs(RAW_SYLLABI_DIR, exist_ok=True)
    os.makedirs(VAULT_DIR, exist_ok=True)

    session = requests.Session()
    session.headers.update(HEADERS)

    success_count = 0
    fail_count = 0

    for i, course in enumerate(courses):
        code = course.get("code_original", course.get("code", ""))
        safe_code = course.get("code", code)
        index_url = f"{BASE_URL}/gui/role/student/Syllabuses?subCode={code}&curriculumID={CURRICULUM_ID}"

        print(f"\n[{i+1}/{len(courses)}] Đang xử lý: {safe_code} ({code})")

        try:
            # 1. Gọi trang Index của Syllabus để tìm ID chi tiết
            res_idx = session.get(index_url, timeout=15)
            if "Login" in res_idx.text[:400] or "login" in res_idx.url.lower():
                print("  [ERROR] Cookie đã hết hạn! Vui lòng cập nhật lại flm_cookie.txt.")
                break

            soup_idx = BeautifulSoup(res_idx.text, "html.parser")
            detail_links = []

            # Duyệt bảng để tìm đúng dòng của môn
            for tr in soup_idx.find_all("tr"):
                a = tr.find("a", href=re.compile(r"SyllabusDetails\?sylID=\d+"))
                if a:
                    cells = [c.get_text(strip=True) for c in tr.find_all(["td", "th"])]
                    link = a.get("href")
                    m = re.search(r"sylID=(\d+)", link)
                    syl_id = m.group(1) if m else ""
                    # Ưu tiên đúng mã môn
                    is_exact = any(code.lower() == c.lower() for c in cells)
                    detail_links.append((syl_id, link, is_exact))

            if not detail_links:
                print(f"  [WARN] Không tìm thấy Syllabus nào cho {code}. Thử tìm link tự do...")
                raw_matches = re.findall(r"SyllabusDetails\?sylID=(\d+)", res_idx.text)
                if raw_matches:
                    detail_links.append((raw_matches[0], f"/gui/role/student/SyllabusDetails?sylID={raw_matches[0]}", True))

            if not detail_links:
                print(f"  [SKIP] Không có Syllabus online cho {code}.")
                fail_count += 1
                continue

            # Chọn link chuẩn nhất: ưu tiên exact match, hoặc link đầu tiên
            exact_links = [l for l in detail_links if l[2]]
            target_id, target_link, _ = exact_links[0] if exact_links else detail_links[0]

            detail_url = f"{BASE_URL}{target_link}" if target_link.startswith("/") else target_link
            print(f"  -> Chi tiết Syllabus ID: {target_id} ({detail_url})")

            # 2. Tải trang chi tiết Syllabus
            res_detail = session.get(detail_url, timeout=15)
            res_detail.raise_for_status()

            # Lưu HTML thô
            raw_file = os.path.join(RAW_SYLLABI_DIR, f"{safe_code}_syl_{target_id}.html")
            with open(raw_file, "w", encoding="utf-8") as f:
                f.write(res_detail.text)

            # 3. Trích xuất toàn bộ dữ liệu
            syl_data = extract_syllabus_details(res_detail.text, safe_code, target_id)

            if not syl_data["success"]:
                print(f"  [ERROR] {syl_data.get('error')}")
                fail_count += 1
                break

            # 4. Ghi đè cập nhật vào Markdown trong Knowledge Vault
            enrich_markdown_file(safe_code, syl_data)

            # 5. Lưu thông tin vào course object trong memory
            course["syllabus_details"] = {
                "syl_id": target_id,
                "clos_count": len(syl_data["clos"]),
                "assessment_items": len(syl_data["assessment"]),
                "materials_count": len(syl_data["materials"]),
                "sessions_count": len(syl_data["schedule"]),
                "min_pass_mark": syl_data["basic_info"].get("MinAvgMarkToPass", "5.0"),
                "tools": syl_data["basic_info"].get("Tools", ""),
                "student_tasks": syl_data["basic_info"].get("StudentTasks", "")
            }

            print(f"  ✅ Đã trích xuất: {len(syl_data['clos'])} CLOs | "
                  f"{len(syl_data['assessment'])} mục điểm thi | "
                  f"{len(syl_data['materials'])} tài liệu | "
                  f"{len(syl_data['schedule'])} buổi học.")
            success_count += 1

        except Exception as e:
            print(f"  [EXCEPTION] Lỗi khi xử lý {code}: {e}")
            fail_count += 1

        # Trễ ngẫu nhiên 1 - 2.5s để tôn trọng máy chủ FLM
        time.sleep(1.0 + random.random() * 1.5)

    # 6. Ghi lại courses_data.json được làm giàu
    with open(FLUTTER_JSON, "w", encoding="utf-8") as f:
        json.dump(flutter_data, f, ensure_ascii=False, indent=2)

    print("\n" + "=" * 75)
    print(f"  HOÀN THÀNH CÀO DỮ LIỆU SYLLABUS:")
    print(f"  - Thành công: {success_count}/{len(courses)} môn")
    print(f"  - Bỏ qua/Lỗi: {fail_count}")
    print(f"  - Thư mục HTML thô: {RAW_SYLLABI_DIR}/")
    print(f"  - Thư mục Vault đã nâng cấp: {VAULT_DIR}/")
    print(f"  - File JSON cho Flutter: {FLUTTER_JSON}")
    print("=" * 75)

if __name__ == "__main__":
    main()
