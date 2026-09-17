import os
import re
import json
from pathlib import Path
from typing import Dict, List, Optional, Any, Tuple
import yaml

from ..schemas.course import CourseDetail, CourseSummary


class FLMDocumentChunk:
    """Represents a discrete semantic chunk of an FLM document with rich metadata."""
    def __init__(
        self,
        chunk_id: str,
        course_code: str,
        course_name: str,
        category: str,
        title: str,
        content: str,
        file_name: str,
        metadata: Optional[Dict[str, Any]] = None,
    ):
        self.chunk_id = chunk_id
        self.course_code = course_code
        self.course_name = course_name
        self.category = category  # e.g., 'overview', 'assessment', 'outcomes', 'prerequisites', 'syllabus', 'schedule'
        self.title = title
        self.content = content.strip()
        self.file_name = file_name
        self.metadata = metadata or {}

    def to_text_for_embedding(self) -> str:
        """Returns unified text representation for semantic vectorization."""
        return (
            f"Mã môn: {self.course_code} | Tên môn: {self.course_name} | "
            f"Mục: {self.title} ({self.category})\n{self.content}"
        )


class FLMKnowledgeVaultParser:
    """Parses Obsidian Markdown knowledge vault and JSON data for FLM Curriculum & Syllabi."""

    def __init__(self, vault_dir: Path, courses_json_path: Optional[Path] = None):
        self.vault_dir = Path(vault_dir)
        self.courses_json_path = Path(courses_json_path) if courses_json_path else None
        self.courses: Dict[str, CourseDetail] = {}
        self.chunks: List[FLMDocumentChunk] = []
        self.curriculum_info: Dict[str, Any] = {}
        self.plo_info: Dict[str, Any] = {}

    def load_all(self) -> Tuple[Dict[str, CourseDetail], List[FLMDocumentChunk]]:
        """Parses all markdown files and builds structured courses and chunks."""
        self.courses.clear()
        self.chunks.clear()

        # 1. Load JSON data if available as supplementary metadata
        if self.courses_json_path and self.courses_json_path.exists():
            try:
                with open(self.courses_json_path, "r", encoding="utf-8") as f:
                    json_data = json.load(f)
                    self.curriculum_info = json_data.get("curriculum", {})
                    self.plo_info = {p.get("id"): p for p in json_data.get("plos", [])}
            except Exception as e:
                print(f"[FLMParser] Warning loading json data: {e}")

        # 2. Iterate markdown files in vault
        if not self.vault_dir.exists():
            print(f"[FLMParser] Vault directory not found: {self.vault_dir}")
            return self.courses, self.chunks

        for md_file in self.vault_dir.glob("*.md"):
            try:
                self._parse_markdown_file(md_file)
            except Exception as e:
                print(f"[FLMParser] Error parsing {md_file.name}: {e}")

        print(f"[FLMParser] Successfully loaded {len(self.courses)} courses and {len(self.chunks)} semantic chunks.")
        return self.courses, self.chunks

    def _parse_markdown_file(self, file_path: Path):
        with open(file_path, "r", encoding="utf-8") as f:
            raw_content = f.read()

        file_name = file_path.name

        # Special files handling
        if file_name == "_Curriculum_Overview.md":
            self._parse_overview_file(raw_content, file_name)
            return
        if file_name == "_Program_Learning_Outcomes.md":
            self._parse_plo_file(raw_content, file_name)
            return

        # Regular course markdown file
        frontmatter, markdown_body = self._split_frontmatter(raw_content)
        
        course_code = frontmatter.get("code") or frontmatter.get("code_original") or file_path.stem
        name_en = frontmatter.get("name_en", "")
        name_vi = frontmatter.get("name_vi", "")
        credits_val = int(frontmatter.get("credits", 3))
        semester_val = int(frontmatter.get("semester", 0))
        prerequisites = frontmatter.get("prerequisites", []) or []
        unlocks = frontmatter.get("unlocks", []) or []
        curriculum = frontmatter.get("curriculum", "BIT_SE_K19B")
        syllabus_url = frontmatter.get("syllabus_url", "")

        # Extract structured sections from markdown body
        sections = self._extract_sections(markdown_body)

        overview_text = sections.get("overview", "")
        graph_text = sections.get("graph", "")
        outcomes_text = sections.get("outcomes", "")
        assessment_text = sections.get("assessment", "")
        guidance_text = sections.get("guidance", "")
        syllabus_text = sections.get("syllabus", "")
        schedule_text = sections.get("schedule", "")

        # Extract specific syllabus fields
        pass_mark_match = re.search(r"MinAvgMarkToPass.*?`([^`]+)`", syllabus_text)
        min_pass_mark = pass_mark_match.group(1) if pass_mark_match else "5.0"

        tools_match = re.search(r"Công cụ & phần mềm yêu cầu.*?\n> (.*?)(?=\n- \*\*|\n##|\Z)", syllabus_text, re.DOTALL)
        software_tools = tools_match.group(1).strip() if tools_match else None

        time_match = re.search(r"Phân bổ thời gian học.*?: (.*?)(?=\n- \*\*|\n##|\Z)", syllabus_text)
        time_allocation = time_match.group(1).strip() if time_match else None

        course_detail = CourseDetail(
            code=course_code,
            name_en=name_en,
            name_vi=name_vi,
            credits=credits_val,
            semester=semester_val,
            prerequisites=prerequisites,
            unlocks=unlocks,
            curriculum=curriculum,
            syllabus_url=syllabus_url,
            overview=overview_text,
            learning_outcomes=outcomes_text,
            assessment_scheme=assessment_text,
            min_pass_mark=min_pass_mark,
            software_tools=software_tools,
            time_allocation=time_allocation,
            raw_markdown=raw_content,
        )
        self.courses[course_code] = course_detail

        # Create fine-grained semantic chunks for retrieval
        display_name = f"{name_vi} ({name_en})" if name_vi and name_en else name_vi or name_en or course_code

        # Chunk 1: General Info, Credits, Semester & Overview
        overview_chunk_content = (
            f"Mã môn: {course_code}\nTên môn học: {display_name}\n"
            f"Số tín chỉ: {credits_val} tín chỉ\nHọc kỳ đề xuất: Học kỳ {semester_val}\n"
            f"Chương trình: {curriculum}\n"
            f"Điều kiện tiên quyết: {', '.join(prerequisites) if prerequisites else 'Không có'}\n"
            f"Môn mở khóa tiếp theo: {', '.join(unlocks) if unlocks else 'Môn giai đoạn cuối / không ràng buộc'}\n"
            f"{overview_text}"
        )
        self.chunks.append(FLMDocumentChunk(
            chunk_id=f"{course_code}_overview",
            course_code=course_code,
            course_name=display_name,
            category="overview",
            title=f"Thông Tin Tổng Quan & Số Tín Chỉ {course_code}",
            content=overview_chunk_content,
            file_name=file_name,
            metadata={"credits": credits_val, "semester": semester_val, "prerequisites": prerequisites}
        ))

        # Chunk 2: Assessment Scheme (PE, FE, Labs, Quizzes, Grading)
        if assessment_text:
            self.chunks.append(FLMDocumentChunk(
                chunk_id=f"{course_code}_assessment",
                course_code=course_code,
                course_name=display_name,
                category="assessment",
                title=f"Hình Thức Thi & Cấu Trúc Đánh Giá {course_code} (PE/FE)",
                content=f"Cấu trúc đánh giá và hình thức thi môn {course_code} ({display_name}):\n{assessment_text}\n"
                        f"Điểm đạt tối thiểu: {min_pass_mark}/10\n"
                        f"Yêu cầu thi PE (Practical Exam) / FE (Final Exam): Kiểm tra chi tiết trong bảng thành phần điểm.",
                file_name=file_name,
                metadata={"has_pe": "practical exam" in assessment_text.lower() or "pe" in assessment_text.lower()}
            ))

        # Chunk 3: Learning Outcomes (LOs / CLOs / PLOs)
        if outcomes_text:
            self.chunks.append(FLMDocumentChunk(
                chunk_id=f"{course_code}_outcomes",
                course_code=course_code,
                course_name=display_name,
                category="outcomes",
                title=f"Mục Tiêu Môn Học & Chuẩn Đầu Ra {course_code} (LOs)",
                content=f"Mục tiêu môn học (Learning Outcomes - LOs) của môn {course_code} ({display_name}):\n{outcomes_text}",
                file_name=file_name,
                metadata={}
            ))

        # Chunk 4: Prerequisites and Roadmap
        if graph_text or prerequisites or unlocks:
            self.chunks.append(FLMDocumentChunk(
                chunk_id=f"{course_code}_prerequisites",
                course_code=course_code,
                course_name=display_name,
                category="prerequisites",
                title=f"Điều Kiện Tiên Quyết & Lộ Trình Học {course_code}",
                content=f"Lộ trình và điều kiện môn học {course_code} ({display_name}):\n"
                        f"- Học kỳ: {semester_val}\n"
                        f"- Môn tiên quyết cần học trước: {', '.join(prerequisites) if prerequisites else 'Không có'}\n"
                        f"- Các môn học sau được mở khóa: {', '.join(unlocks) if unlocks else 'Không ràng buộc'}\n"
                        f"{graph_text}\n{guidance_text}",
                file_name=file_name,
                metadata={"prerequisites": prerequisites, "unlocks": unlocks, "semester": semester_val}
            ))

        # Chunk 5: Detailed Syllabus, Software & Schedule Summary
        if syllabus_text:
            self.chunks.append(FLMDocumentChunk(
                chunk_id=f"{course_code}_syllabus",
                course_code=course_code,
                course_name=display_name,
                category="syllabus",
                title=f"Đề Cương Chi Tiết & Công Cụ Học Tập {course_code}",
                content=f"Thông tin quy chuẩn Syllabus FLM môn {course_code} ({display_name}):\n{syllabus_text}",
                file_name=file_name,
                metadata={"software_tools": software_tools, "min_pass_mark": min_pass_mark}
            ))

    def _parse_overview_file(self, content: str, file_name: str):
        """Parses curriculum overview markdown."""
        self.chunks.append(FLMDocumentChunk(
            chunk_id="curriculum_overview",
            course_code="CURRICULUM",
            course_name="Khung Chương Trình BIT_SE_K19B",
            category="overview",
            title="Khung Chương Trình Đào Tạo Kỹ Thuật Phần Mềm (BIT_SE_K19B)",
            content=content,
            file_name=file_name,
            metadata={"type": "curriculum_summary"}
        ))

    def _parse_plo_file(self, content: str, file_name: str):
        """Parses program learning outcomes markdown."""
        self.chunks.append(FLMDocumentChunk(
            chunk_id="program_learning_outcomes",
            course_code="PLO",
            course_name="Chuẩn Đầu Ra Ngành Kỹ Thuật Phần Mềm (PLOs)",
            category="outcomes",
            title="Chuẩn Đầu Ra Ngành Kỹ Thuật Phần Mềm (Program Learning Outcomes)",
            content=content,
            file_name=file_name,
            metadata={"type": "plo_summary"}
        ))

    def _split_frontmatter(self, text: str) -> Tuple[Dict[str, Any], str]:
        if text.startswith("---"):
            parts = text.split("---", 2)
            if len(parts) >= 3:
                try:
                    frontmatter = yaml.safe_load(parts[1]) or {}
                    body = parts[2]
                    return frontmatter, body
                except Exception:
                    pass
        return {}, text

    def _extract_sections(self, markdown_body: str) -> Dict[str, str]:
        sections: Dict[str, str] = {}
        
        # Regex to split on level 2 headers: ## [Title]
        raw_sections = re.split(r"\n##\s+", "\n" + markdown_body)
        for sec in raw_sections:
            sec = sec.strip()
            if not sec:
                continue
            lines = sec.split("\n", 1)
            title_line = lines[0].lower()
            body_line = lines[1].strip() if len(lines) > 1 else ""

            if "thông tin tổng quan" in title_line or "1." in title_line:
                sections["overview"] = body_line
            elif "mối quan hệ" in title_line or "sơ đồ" in title_line or "2." in title_line:
                sections["graph"] = body_line
            elif "mục tiêu" in title_line or "chuẩn đầu ra" in title_line or "3." in title_line:
                sections["outcomes"] = body_line
            elif "đánh giá" in title_line or "hình thức thi" in title_line or "4." in title_line:
                sections["assessment"] = body_line
            elif "lộ trình" in title_line or "gợi ý" in title_line or "5." in title_line:
                sections["guidance"] = body_line
            elif "dữ liệu syllabus" in title_line or "thông tin quy chuẩn" in title_line:
                sections["syllabus"] = body_line
            elif "lịch trình" in title_line or "slot" in title_line:
                sections["schedule"] = body_line
            else:
                sections[title_line[:20]] = body_line

        return sections
