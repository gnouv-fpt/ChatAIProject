import time
from typing import Dict, List, Optional, Tuple, Any
from ..config import settings
from ..schemas.chat import ChatRequest, ChatResponse, SourceChunk
from ..schemas.course import CourseDetail, CourseSummary
from .flm_parser import FLMKnowledgeVaultParser, FLMDocumentChunk
from .vector_store import HybridVectorStore
from .llm_service import LLMService


class RAGEngine:
    """
    Central RAG Coordinator for the FLM Knowledge & AI Assistant System.
    """

    def __init__(self):
        self.parser: Optional[FLMKnowledgeVaultParser] = None
        self.vector_store: HybridVectorStore = HybridVectorStore()
        self.llm_service: LLMService = LLMService()
        self.courses: Dict[str, CourseDetail] = {}
        self.is_initialized: bool = False

    def initialize(self):
        """Loads and indexes knowledge base on application startup."""
        vault_path = settings.get_vault_path()
        courses_json_path = settings.get_courses_data_path()

        print(f"[RAGEngine] Initializing knowledge base from {vault_path}...")
        self.parser = FLMKnowledgeVaultParser(vault_path, courses_json_path)
        self.courses, chunks = self.parser.load_all()
        self.vector_store.index_chunks(chunks)
        self.is_initialized = True
        print(f"[RAGEngine] Knowledge base initialized with {len(self.courses)} courses and {len(chunks)} chunks.")

    async def answer_query(self, request: ChatRequest) -> ChatResponse:
        """
        Executes end-to-end RAG retrieval, context formulation, and answer generation.
        """
        start_time = time.time()
        query = request.query_text

        if not query:
            return ChatResponse(
                answer="Vui lòng cung cấp câu hỏi về môn học hoặc chương trình đào tạo FLM.",
                sources=[],
                question=query,
                latency_ms=0.0,
                provider="None",
            )

        # 1. Detect target courses & query intent
        detected_courses = self.vector_store.extract_target_courses(query)
        target_course = request.course_code or (detected_courses[0] if detected_courses else None)

        top_k = request.top_k or settings.TOP_K_CHUNKS

        # 2. Retrieve most relevant context chunks
        retrieved_results = self.vector_store.search(
            query=query,
            top_k=top_k,
            target_course=target_course,
            similarity_threshold=settings.SIMILARITY_THRESHOLD,
        )

        # 3. Generate Answer via LLM / Synthesizer
        answer_text, provider_name = await self.llm_service.generate_response(
            question=query,
            retrieved_chunks=retrieved_results,
            detected_courses=detected_courses,
        )

        # 4. Construct human-readable sources list & detailed source chunks
        sources_list: List[str] = []
        detailed_sources: List[SourceChunk] = []

        seen_sources = set()
        for chunk, score in retrieved_results:
            source_label = f"{chunk.file_name} ({chunk.title})"
            if source_label not in seen_sources:
                sources_list.append(source_label)
                seen_sources.add(source_label)

            detailed_sources.append(
                SourceChunk(
                    course_code=chunk.course_code,
                    section=chunk.category,
                    file_name=chunk.file_name,
                    score=round(score, 3),
                    content_snippet=chunk.content[:200] + "..." if len(chunk.content) > 200 else chunk.content,
                )
            )

        if not sources_list:
            sources_list = ["Hệ thống dữ liệu FLM FPT University (Curriculum & Syllabus)"]

        latency_ms = round((time.time() - start_time) * 1000, 2)

        return ChatResponse(
            answer=answer_text,
            sources=sources_list,
            question=query,
            matched_courses=detected_courses,
            provider=provider_name,
            latency_ms=latency_ms,
            detailed_sources=detailed_sources,
        )

    def get_all_courses(self) -> List[CourseSummary]:
        """Returns summary list of all available courses."""
        return [
            CourseSummary(
                code=c.code,
                name_vi=c.name_vi,
                name_en=c.name_en,
                credits=c.credits,
                semester=c.semester,
                prerequisites=c.prerequisites,
                unlocks=c.unlocks,
            )
            for c in self.courses.values()
        ]

    def get_course_detail(self, code: str) -> Optional[CourseDetail]:
        """Retrieves complete course syllabus details by code."""
        code_upper = code.upper()
        if code_upper in self.courses:
            return self.courses[code_upper]
        
        # Alias fallback (e.g. PRM392 -> PRM393)
        if code_upper == "PRM392" and "PRM393" in self.courses:
            return self.courses["PRM393"]

        return None


# Global singleton instance
rag_engine = RAGEngine()
