from typing import List, Optional
from fastapi import APIRouter, HTTPException, Query, status
from ....schemas.course import CourseDetail, CourseListResponse, CourseSummary
from ....schemas.chat import SourceChunk
from ....services.rag_engine import rag_engine

router = APIRouter()


@router.get(
    "/courses",
    response_model=CourseListResponse,
    summary="List all FLM courses",
    description="Returns the full list of curriculum courses with credits, semester, prerequisites and unlock information.",
)
async def list_courses() -> CourseListResponse:
    courses = rag_engine.get_all_courses()
    return CourseListResponse(
        total=len(courses),
        curriculum="BIT_SE_K19B",
        courses=courses,
    )


@router.get(
    "/courses/{code}",
    response_model=CourseDetail,
    summary="Get Course Syllabus Details",
    description="Returns full detailed information of a course including assessment scheme, learning outcomes, pass criteria, and tools.",
)
async def get_course(code: str) -> CourseDetail:
    course = rag_engine.get_course_detail(code)
    if not course:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Môn học với mã '{code}' không tồn tại trong cơ sở dữ liệu FLM.",
        )
    return course


@router.get(
    "/search",
    response_model=List[SourceChunk],
    summary="Direct Vector/Semantic Retrieval Inspection",
    description="Debugging endpoint to inspect raw retrieved chunks and relevance scores for a given query.",
)
async def search_chunks(
    q: str = Query(..., description="Search query string"),
    top_k: int = Query(5, ge=1, le=20),
    course: Optional[str] = Query(None, description="Optional course filter"),
) -> List[SourceChunk]:
    results = rag_engine.vector_store.search(
        query=q,
        top_k=top_k,
        target_course=course,
    )
    return [
        SourceChunk(
            course_code=chunk.course_code,
            section=chunk.category,
            file_name=chunk.file_name,
            score=round(score, 3),
            content_snippet=chunk.content,
        )
        for chunk, score in results
    ]
