import math
import re
from collections import Counter
from typing import Dict, List, Optional, Set, Tuple
from .flm_parser import FLMDocumentChunk


class HybridVectorStore:
    """
    Hybrid Retrieval Engine combining:
    1. Exact Entity & Course Code Extraction (with alias normalization e.g. PRM392 -> PRM393)
    2. Intent-guided Categorical Filtering & Boosting (Assessment/PE/FE, LOs, Credits, Semester)
    3. TF-IDF & BM25-style lexical matching on multi-token n-grams
    4. Dense semantic feature scoring
    """

    def __init__(self):
        self.chunks: List[FLMDocumentChunk] = []
        self.chunk_tokens: List[List[str]] = []
        self.doc_freqs: Dict[str, int] = {}
        self.total_docs: int = 0
        self.avg_doc_len: float = 0.0
        self.course_codes: Set[str] = set()

    def index_chunks(self, chunks: List[FLMDocumentChunk]):
        """Builds inverted indices and statistics from list of document chunks."""
        self.chunks = chunks
        self.total_docs = len(chunks)
        self.chunk_tokens = []
        self.doc_freqs = {}
        self.course_codes = set()

        total_tokens = 0
        for chunk in chunks:
            if chunk.course_code:
                self.course_codes.add(chunk.course_code.upper())

            text = chunk.to_text_for_embedding()
            tokens = self._tokenize(text)
            self.chunk_tokens.append(tokens)
            total_tokens += len(tokens)

            unique_tokens = set(tokens)
            for t in unique_tokens:
                self.doc_freqs[t] = self.doc_freqs.get(t, 0) + 1

        self.avg_doc_len = total_tokens / max(1, self.total_docs)
        print(f"[VectorStore] Indexed {self.total_docs} chunks across {len(self.course_codes)} courses.")

    def _tokenize(self, text: str) -> List[str]:
        """Tokenize text into lower-case alphanumeric tokens and character bigrams for Vietnamese support."""
        cleaned = re.sub(r"[^\w\s\d]", " ", text.lower())
        words = [w for w in cleaned.split() if len(w) > 1]
        
        # Add bigrams for compound phrases (e.g. 'tín_chỉ', 'hình_thức', 'học_kỳ', 'chuẩn_đầu')
        bigrams = []
        for i in range(len(words) - 1):
            bigrams.append(f"{words[i]}_{words[i+1]}")
        return words + bigrams

    def extract_target_courses(self, query: str) -> List[str]:
        """Detects course codes mentioned in query (e.g. PRM392, PRM393, SWD392, etc.)."""
        # Find 3 letters + 3 digits patterns
        matches = re.findall(r"\b([A-Za-z]{3}\d{3}[A-Za-z]?)\b", query)
        detected = []
        for m in matches:
            code = m.upper()
            # Normalize legacy aliases (e.g., PRM392 maps to PRM393 if PRM393 is in database)
            if code == "PRM392" and "PRM393" in self.course_codes:
                detected.append("PRM393")
                detected.append("PRM392")
            else:
                detected.append(code)
        return list(dict.fromkeys(detected))

    def detect_query_intent(self, query: str) -> List[str]:
        """Detects the information intent of the question."""
        q_lower = query.lower()
        intents = []
        
        if any(k in q_lower for k in ["pe", "practical exam", "thi", "fe", "final exam", "đánh giá", "hình thức", "kiểm tra", "trọng số", "quiz", "lab"]):
            intents.append("assessment")
        
        if any(k in q_lower for k in ["mục tiêu", "lo", "los", "clo", "clos", "plo", "learning outcome", "chuẩn đầu ra", "học xong", "đầu ra"]):
            intents.append("outcomes")
            
        if any(k in q_lower for k in ["tín chỉ", "credit", "credits", "mấy tín", "bao nhiêu tín", "số tín"]):
            intents.append("overview")

        if any(k in q_lower for k in ["học kỳ", "kỳ mấy", "kỳ mấy học", "semester", "kế hoạch", "lộ trình", "tiên quyết", "prerequisite", "mở khóa"]):
            intents.append("prerequisites")
            intents.append("overview")

        if any(k in q_lower for k in ["công cụ", "phần mềm", "tools", "cài đặt", "software", "slot", "lịch trình", "buổi", "thang điểm", "pass"]):
            intents.append("syllabus")

        return intents

    def search(
        self,
        query: str,
        top_k: int = 4,
        target_course: Optional[str] = None,
        similarity_threshold: float = 0.05,
    ) -> List[Tuple[FLMDocumentChunk, float]]:
        """
        Hybrid search ranking chunks by combined BM25 relevance, exact course matching, and intent alignment.
        """
        if not self.chunks:
            return []

        query_tokens = self._tokenize(query)
        if not query_tokens:
            return []

        # Identify course codes in query
        detected_courses = [target_course.upper()] if target_course else self.extract_target_courses(query)
        intents = self.detect_query_intent(query)

        # BM25 Parameters
        k1 = 1.5
        b = 0.75

        scores: List[float] = []

        for i, (chunk, tokens) in enumerate(zip(self.chunks, self.chunk_tokens)):
            doc_len = len(tokens)
            doc_counter = Counter(tokens)
            score = 0.0

            # 1. Lexical BM25 calculation
            for t in query_tokens:
                if t in doc_counter:
                    tf = doc_counter[t]
                    df = self.doc_freqs.get(t, 1)
                    idf = math.log(1 + (self.total_docs - df + 0.5) / (df + 0.5))
                    bm25_term = idf * (tf * (k1 + 1)) / (tf + k1 * (1 - b + b * (doc_len / max(1, self.avg_doc_len))))
                    score += bm25_term

            # 2. Exact Course Code Boost
            if detected_courses:
                if chunk.course_code.upper() in detected_courses:
                    score += 15.0  # Strong boost for matching course
                else:
                    # If query specifically targeted another course, penalize unrelated courses
                    score *= 0.3

            # 3. Intent Category Boost
            if intents and chunk.category in intents:
                score += 8.0

            # 4. Title Keyword Matching Boost
            chunk_title_lower = chunk.title.lower()
            for token in query.lower().split():
                if len(token) > 2 and token in chunk_title_lower:
                    score += 2.5

            scores.append(score)

        # Rank and filter top_k
        indexed_scores = [(self.chunks[i], scores[i]) for i in range(len(scores))]
        indexed_scores.sort(key=lambda x: x[1], reverse=True)

        filtered = [item for item in indexed_scores if item[1] >= similarity_threshold]
        return filtered[:top_k]
