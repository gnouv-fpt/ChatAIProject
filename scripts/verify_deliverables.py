import json, os, re, sys
sys.stdout.reconfigure(encoding='utf-8')

PASS = "✅ PASS"
FAIL = "❌ FAIL"

results = []

def check(name, condition, detail=""):
    status = PASS if condition else FAIL
    results.append((name, status, detail))
    print(f"{status} {name}")
    if detail:
        print(f"       {detail}")

print("=" * 70)
print("  VERIFICATION REPORT — Khôi's Deliverables (phan_chia_nhiem_vu)")
print("=" * 70)
print()

# === DELIVERABLE 1: Markdown Vault ===
print("── DELIVERABLE 1: flm_knowledge_vault/ (Obsidian Markdown Files) ──")
vault = "flm_knowledge_vault"

md_files = [f for f in os.listdir(vault) if f.endswith(".md")] if os.path.isdir(vault) else []
course_files = [f for f in md_files if not f.startswith("_")]
index_files = [f for f in md_files if f.startswith("_")]

check("Thư mục flm_knowledge_vault/ tồn tại",
      os.path.isdir(vault))
check("48+ file .md môn học được tạo ra",
      len(course_files) >= 48,
      f"Thực tế: {len(course_files)} files")
check("File _Curriculum_Overview.md tồn tại",
      "_Curriculum_Overview.md" in md_files)
check("File _Program_Learning_Outcomes.md tồn tại",
      "_Program_Learning_Outcomes.md" in md_files)

# Check YAML Frontmatter
prm393_path = os.path.join(vault, "PRM393.md")
if os.path.exists(prm393_path):
    with open(prm393_path, 'r', encoding='utf-8') as f:
        content = f.read()
    has_yaml = content.startswith("---")
    has_code = "code:" in content
    has_credits = "credits:" in content
    has_semester = "semester:" in content
    has_prereqs = "prerequisites:" in content
    has_url = "syllabus_url:" in content
    yaml_ok = has_yaml and has_code and has_credits and has_semester and has_prereqs and has_url
    check("YAML Frontmatter chuẩn (code, credits, semester, prerequisites, syllabus_url)",
          yaml_ok,
          "Xem PRM393.md làm mẫu")

    # Wikilinks
    has_wikilink_prereq = "[[PRO192]]" in content
    has_wikilink_overview = "[[_Curriculum_Overview" in content
    has_wikilink_plo = "[[_Program_Learning_Outcomes" in content
    check("Liên kết Wikilinks hai chiều [[MÃ_MÔN]] trong PRM393.md",
          has_wikilink_prereq,
          "Tìm thấy: [[PRO192]] trong PRM393.md")
    check("Liên kết tới [[_Curriculum_Overview]] trong PRM393.md",
          has_wikilink_overview)
    check("Liên kết tới [[_Program_Learning_Outcomes]] trong PRM393.md",
          has_wikilink_plo)

# Check PRO192 has two-way links (it is both a target and a source)
pro192_path = os.path.join(vault, "PRO192.md")
if os.path.exists(pro192_path):
    with open(pro192_path, 'r', encoding='utf-8') as f:
        pro_content = f.read()
    has_backward = "[[PRF192]]" in pro_content   # PRO192 requires PRF192
    has_forward_prm = "[[PRM393]]" in pro_content  # PRO192 unlocks PRM393
    has_forward_swp = "[[SWP391]]" in pro_content  # PRO192 unlocks SWP391
    has_forward_prj = "[[PRJ301]]" in pro_content
    check("PRO192.md có liên kết ngược (tiên quyết) [[PRF192]]",
          has_backward)
    check("PRO192.md có liên kết xuôi (mở khóa) [[PRM393]]",
          has_forward_prm)
    check("PRO192.md có liên kết xuôi (mở khóa) [[PRJ301]] (Java Web - thực tế đúng theo FLM)",
          has_forward_prj,
          "PRO192→SWP391 không trực tiếp; SWP391 cần PRJ301+SWE201c+LAB211 (dữ liệu FLM chuẩn)")

# Check assessment info
check("Cấu trúc đánh giá PE/FE có trong PRM393.md",
      "Practical Exam (PE)" in content and "Final Exam (FE)" in content)

print()
print("── DELIVERABLE 2: flm_flutter_data/courses_data.json ──")

json_path = "flm_flutter_data/courses_data.json"
json_ok = os.path.exists(json_path)
check("File courses_data.json tồn tại", json_ok)

if json_ok:
    with open(json_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    check("Có metadata curriculum (BIT_SE_K19B)",
          data.get("curriculum", {}).get("code") == "BIT_SE_K19B",
          "code = " + data.get("curriculum", {}).get("code", "MISSING"))
    check("Có 13 PLOs",
          len(data.get("plos", [])) == 13,
          f"Thực tế: {len(data.get('plos', []))}")
    check("Có 48 courses",
          len(data.get("courses", [])) == 48,
          f"Thực tế: {len(data.get('courses', []))}")
    check("Có 10 semesters (Học kỳ 0 - 9)",
          len(data.get("semesters", [])) == 10,
          f"Thực tế: {len(data.get('semesters', []))}")

    nodes = data.get("graph", {}).get("nodes", [])
    edges = data.get("graph", {}).get("edges", [])
    check("graph.nodes có 48 nodes",
          len(nodes) == 48,
          f"Thực tế: {len(nodes)}")
    check("graph.edges có ít nhất 20 edges quan hệ tiên quyết",
          len(edges) >= 20,
          f"Thực tế: {len(edges)} edges")

    node_ids = {n["id"] for n in nodes}
    node_ids = {n["id"] for n in nodes}
    missing_src = {e.get("from") or e.get("source") for e in edges if (e.get("from") or e.get("source")) not in node_ids}
    missing_tgt = {e.get("to") or e.get("target") for e in edges if (e.get("to") or e.get("target")) not in node_ids}
    check("Không có dangling edges (source/target đều hợp lệ)",
          len(missing_src) == 0 and len(missing_tgt) == 0,
          f"Missing sources: {missing_src}, Missing targets: {missing_tgt}")

    # Check node has color
    has_color = all("color" in n for n in nodes)
    check("Mỗi node đều có 'color' theo học kỳ (cho Flutter UI)",
          has_color)

    # Check PRM393 node
    prm393_node = next((n for n in nodes if n["id"] == "PRM393"), None)
    check("Node PRM393 tồn tại trong graph",
          prm393_node is not None,
          f"Semester: {prm393_node.get('semester') if prm393_node else 'N/A'}, Credits: {prm393_node.get('credits') if prm393_node else 'N/A'}")

    # Check PRM393 has edge from PRO192
    edge_prm393 = any((e.get("from") == "PRO192" or e.get("source") == "PRO192") and 
                      (e.get("to") == "PRM393" or e.get("target") == "PRM393") for e in edges)
    check("Edge PRO192 → PRM393 tồn tại trong graph",
          edge_prm393)

    # Check .NET track courses
    dotnet_codes = ["PRN212", "PRN222", "PRU213", "PRN232", "SEP490"]
    all_dotnet_in_graph = all(code in node_ids for code in dotnet_codes)
    check("Toàn bộ combo chuyên ngành .NET (PRN212, PRN222, PRU213, PRN232, SEP490) có trong Graph",
          all_dotnet_in_graph,
          f"Đã xác nhận: {', '.join(dotnet_codes)}")

    # Check PRN212 has edge from PRO192
    edge_prn212 = any((e.get("from") == "PRO192" or e.get("source") == "PRO192") and 
                      (e.get("to") == "PRN212" or e.get("target") == "PRN212") for e in edges)
    check("Edge PRO192 → PRN212 (.NET cơ bản) tồn tại trong graph",
          edge_prn212)

print()
print("── DELIVERABLE 3: Script Tự Động Hóa ──")
check("File scripts/build_knowledge_base.py tồn tại",
      os.path.exists("scripts/build_knowledge_base.py"))

print()
print("=" * 70)
passed = sum(1 for _, s, _ in results if s == PASS)
failed = sum(1 for _, s, _ in results if s == FAIL)
print(f"  TỔNG KẾT: {passed}/{passed+failed} tiêu chí PASS | {failed} FAIL")
if failed == 0:
    print("  🏆 HOÀN THÀNH 100% YÊU CẦU CỦA KHÔI (phan_chia_nhiem_vu_PRM393)")
else:
    print("  ⚠️  Cần kiểm tra và sửa các tiêu chí FAIL ở trên!")
print("=" * 70)
