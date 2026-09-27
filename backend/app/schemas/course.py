from typing import List, Optional, Dict, Any
from pydantic import BaseModel, Field


class AssessmentItem(BaseModel):
    category: str
    weight: Optional[str] = None
    description: Optional[str] = None


class CourseSummary(BaseModel):
    code: str = Field(..., description="Course code (e.g. PRM393)")
    name_vi: str = Field("", description="Vietnamese course title")
    name_en: str = Field("", description="English course title")
    credits: int = Field(3, description="Course credit count")
    semester: int = Field(0, description="Recommended semester")
    prerequisites: List[str] = Field(default_factory=list, description="Prerequisite course codes")
    unlocks: List[str] = Field(default_factory=list, description="Follow-up courses unlocked by this course")


class CourseDetail(CourseSummary):
    curriculum: str = Field("BIT_SE_K19B", description="Curriculum code")
    syllabus_url: Optional[str] = Field(None, description="FLM portal URL")
    overview: Optional[str] = Field(None, description="General overview")
    learning_outcomes: Optional[str] = Field(None, description="Learning outcomes (LOs/CLOs)")
    assessment_scheme: Optional[str] = Field(None, description="Grading & Exam breakdown (PE/FE)")
    min_pass_mark: Optional[str] = Field(None, description="Minimum mark to pass")
    software_tools: Optional[str] = Field(None, description="Required software and tools")
    time_allocation: Optional[str] = Field(None, description="Contact hours and self-study hours")
    raw_markdown: Optional[str] = Field(None, description="Full markdown document content")
    appears_in: List[Dict[str, Any]] = Field(default_factory=list, description="Curricula and semesters where this course appears")
    has_pe: bool = Field(False, description="Whether the course has a practical exam (PE)")
    counts_in_gpa: bool = Field(True, description="Whether the course counts towards graduation GPA")
    in_curriculum: bool = Field(True, description="Whether the course is in active curriculum")



class CourseListResponse(BaseModel):
    total: int = Field(..., description="Total number of courses")
    curriculum: str = Field("BIT_SE_K19B", description="Curriculum code")
    courses: List[CourseSummary] = Field(default_factory=list, description="List of courses")


class SemesterStat(BaseModel):
    semester: int = Field(..., description="Semester index (0-9)")
    course_count: int = Field(..., description="Number of courses in semester")
    total_credits: int = Field(..., description="Total credits for this semester")
    courses: List[str] = Field(default_factory=list, description="List of course codes in semester")


class CurriculumStats(BaseModel):
    curriculum_id: str = Field("BIT_SE_K19B", description="Curriculum code")
    name: str = Field("", description="Curriculum name")
    name_vi: str = Field("", description="Vietnamese curriculum name")
    total_semesters: int = Field(9, description="Number of formal semesters")
    total_courses: int = Field(0, description="Total number of courses")
    total_credits: int = Field(145, description="Total credits for graduation")
    semesters: List[SemesterStat] = Field(default_factory=list, description="Stats per semester")


class PrerequisiteCheckResult(BaseModel):
    course_code: str = Field(..., description="Target course code")
    is_satisfied: bool = Field(..., description="Whether all prerequisites are satisfied")
    required_prerequisites: List[str] = Field(default_factory=list, description="All required prerequisites")
    missing_prerequisites: List[str] = Field(default_factory=list, description="Missing prerequisite course codes")

