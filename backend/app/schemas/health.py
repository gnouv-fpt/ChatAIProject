from typing import List, Optional
from pydantic import BaseModel, Field


class HealthResponse(BaseModel):
    status: str = Field("ok", description="Server health status (ok / degraded)")
    app_name: str = Field(..., description="Application name")
    version: str = Field(..., description="API Version")
    total_courses: int = Field(0, description="Total number of parsed FLM courses")
    total_chunks: int = Field(0, description="Total indexed text chunks in vector store")
    active_llm_provider: str = Field(..., description="Active LLM generation provider")
    vault_loaded: bool = Field(True, description="Whether knowledge vault loaded successfully")
