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


class CourseListResponse(BaseModel):
    total: int = Field(..., description="Total number of courses")
    curriculum: str = Field("BIT_SE_K19B", description="Curriculum code")
    courses: List[CourseSummary] = Field(default_factory=list, description="List of courses")
