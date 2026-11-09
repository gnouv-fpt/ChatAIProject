from typing import List, Optional, Dict, Any
from fastapi import APIRouter, HTTPException, Query, Body, status
from ....schemas.course import CourseDetail, CourseListResponse, CourseSummary, CurriculumStats, PrerequisiteCheckResult
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


@router.get(
    "/curricula/{curriculum_id}/stats",
    response_model=CurriculumStats,
    summary="Get Curriculum Statistics",
    description="Returns structured statistics of a curriculum: total semesters, courses, credits, and semester distribution.",
)
async def get_curriculum_stats(curriculum_id: str = "BIT_SE_K19B") -> CurriculumStats:
    stats = rag_engine.get_curriculum_stats(curriculum_id)
    if not stats:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Curriculum '{curriculum_id}' không tìm thấy.",
        )
    return stats


@router.get(
    "/courses/{code}/presence",
    response_model=List[Dict[str, Any]],
    summary="Check where course appears across curricula",
    description="Returns the list of curricula and semesters in which this course appears.",
)
async def get_course_presence(code: str) -> List[Dict[str, Any]]:
    presence = rag_engine.get_course_presence(code)
    return presence


@router.post(
    "/courses/{code}/check-prerequisites",
    response_model=PrerequisiteCheckResult,
    summary="Check prerequisite satisfaction for a course",
    description="Evaluates whether a student has completed all required prerequisites for a course.",
)
async def check_prerequisites(
    code: str,
    completed_courses: List[str] = Body(..., embed=True, description="List of passed course codes"),
) -> PrerequisiteCheckResult:
    result = rag_engine.check_prerequisites(code, completed_courses)
    if not result:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Môn học '{code}' không tồn tại.",
        )
    return result

