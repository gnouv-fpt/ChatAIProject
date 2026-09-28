from typing import List, Optional, Any, Dict
from pydantic import BaseModel, Field, model_validator


class SourceChunk(BaseModel):
    course_code: str = Field(..., description="Course code (e.g. PRM393, SWD392)")
    section: str = Field(..., description="Document section (e.g. Overview, Assessment, LOs, Syllabus)")
    file_name: str = Field(..., description="Source markdown file name")
    score: float = Field(0.0, description="Relevance similarity score")
    content_snippet: str = Field(..., description="Relevant text snippet extracted from source")


class StudentContext(BaseModel):
    current_gpa: Optional[float] = Field(None, description="Current cumulative GPA calculated by code")
    target_gpa: Optional[float] = Field(None, description="Target GPA for graduation")
    retake_count: Optional[int] = Field(None, description="Number of retaken courses (failed in previous attempts)")
    improvement_count: Optional[int] = Field(None, description="Number of grade improvement attempts")
    target_rank: Optional[str] = Field(None, description="Target graduation rank (Xuất sắc, Giỏi, Khá, Trung bình)")
    required_avg_mark: Optional[float] = Field(None, description="Required average mark in remaining courses")
    is_target_feasible: Optional[bool] = Field(None, description="Whether target is feasible (required_avg <= 10)")
    rank_penalty_applied: Optional[bool] = Field(None, description="Whether rank penalty applies (retake >= 2)")
    current_semester: Optional[int] = Field(None, description="Current semester of student")
    target_semester: Optional[int] = Field(None, description="Semester currently being advised")
    failed_courses: Optional[List[str]] = Field(default_factory=list, description="List of failed course codes")
    completed_courses: Optional[List[str]] = Field(default_factory=list, description="List of passed course codes")


class ChatRequest(BaseModel):
    question: Optional[str] = Field(None, description="User question / prompt")
    prompt: Optional[str] = Field(None, description="Alternative alias for question")
    top_k: Optional[int] = Field(None, description="Number of context chunks to retrieve (optional)")
    course_code: Optional[str] = Field(None, description="Optional target course code filter (e.g. PRM393)")
    scope: Optional[str] = Field(None, description="Scope of conversation: 'curriculum' or 'subject'")
    id: Optional[str] = Field(None, description="Identifier for active scope (e.g. 'BIT_SE_K19B' or 'PRM393')")
    student_context: Optional[Dict[str, Any]] = Field(None, description="Student academic facts pre-calculated by Khối E")


    @model_validator(mode="before")
    @classmethod
    def unify_fields(cls, data: Any) -> Any:
        if isinstance(data, dict):
            if not data.get("question") and data.get("prompt"):
                data["question"] = data["prompt"]
            elif not data.get("prompt") and data.get("question"):
                data["prompt"] = data["question"]
            if not data.get("course_code") and data.get("scope") == "subject" and data.get("id"):
                data["course_code"] = data["id"]
        return data

    @property
    def query_text(self) -> str:
        return (self.question or self.prompt or "").strip()


class ChatResponse(BaseModel):
    answer: str = Field(..., description="AI generated answer based strictly on FLM knowledge base")
    sources: List[str] = Field(default_factory=list, description="List of source references and filenames")
    question: str = Field(..., description="Original user question")
    matched_courses: List[str] = Field(default_factory=list, description="Course codes detected and retrieved")
    provider: str = Field("FLM-RAG", description="LLM / Generation engine used")
    latency_ms: float = Field(0.0, description="Processing time in milliseconds")
    detailed_sources: Optional[List[SourceChunk]] = Field(None, description="Detailed source chunks with snippets")
    error: Optional[str] = Field(None, description="Error or warning message if any")
