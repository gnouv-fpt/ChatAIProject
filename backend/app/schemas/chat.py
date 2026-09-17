from typing import List, Optional, Any, Dict
from pydantic import BaseModel, Field, model_validator


class SourceChunk(BaseModel):
    course_code: str = Field(..., description="Course code (e.g. PRM393, SWD392)")
    section: str = Field(..., description="Document section (e.g. Overview, Assessment, LOs, Syllabus)")
    file_name: str = Field(..., description="Source markdown file name")
    score: float = Field(0.0, description="Relevance similarity score")
    content_snippet: str = Field(..., description="Relevant text snippet extracted from source")


class ChatRequest(BaseModel):
    question: Optional[str] = Field(None, description="User question / prompt")
    prompt: Optional[str] = Field(None, description="Alternative alias for question")
    top_k: Optional[int] = Field(None, description="Number of context chunks to retrieve (optional)")
    course_code: Optional[str] = Field(None, description="Optional target course code filter (e.g. PRM393)")

    @model_validator(mode="before")
    @classmethod
    def unify_question_and_prompt(cls, data: Any) -> Any:
        if isinstance(data, dict):
            if not data.get("question") and data.get("prompt"):
                data["question"] = data["prompt"]
            elif not data.get("prompt") and data.get("question"):
                data["prompt"] = data["question"]
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
