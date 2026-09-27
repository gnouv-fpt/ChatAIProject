import math
import re
from collections import Counter
from typing import Dict, List, Optional, Set, Tuple
from .flm_parser import FLMDocumentChunk


class HybridVectorStore:
    """
    Enhanced Hybrid Retrieval Engine for FLM Knowledge & AI Assistant:
    1. Exact Entity & Course Code Extraction (with alias normalization).
    2. Multi-intent Classification: Advising/Strategy, Assessment/PE/FE, LOs, Credits, Semester/Prereq, GPA Rules.
    3. Multi-token n-gram lexical BM25 matching.
    4. Intent-guided contextual ranking boost.
    """

    ALIASES = {
        "PRM392": "PRM393",
        "MAC101": "MAE101",
        "SWE102": "SWE201c",
        "SWE202C": "SWE201c",
        "JPD133": "JPD123",
    }

    KEYWORD_COURSE_MAP = {
        "di động": "PRM393",
        "di dong": "PRM393",
        "android": "PRM393",
        "mobile": "PRM393",
        "prm": "PRM393",
        "nhập môn c": "PRF192",
        "nhap mon c": "PRF192",
        "lập trình c": "PRF192",
        "lap trinh c": "PRF192",
        "ngôn ngữ c": "PRF192",
        "prf": "PRF192",
        "hướng đối tượng": "PRO192",
        "huong doi tuong": "PRO192",
        "oop": "PRO192",
        "java cơ bản": "PRO192",
        "pro": "PRO192",
        "java web": "PRJ301",
        "servlet": "PRJ301",
        "jsp": "PRJ301",
        "prj": "PRJ301",
        "cơ sở dữ liệu": "DBI202",
        "co so du lieu": "DBI202",
        "database": "DBI202",
        "sql": "DBI202",
        "dbi": "DBI202",
        "cấu trúc dữ liệu": "CSD201",
        "cau truc du lieu": "CSD201",
        "giải thuật": "CSD201",
        "giai thuat": "CSD201",
        "dsa": "CSD201",
        "csd": "CSD201",
        "kiến trúc phần mềm": "SWD392",
        "kien truc phan mem": "SWD392",
        "swd": "SWD392",
        "công nghệ phần mềm": "SWE201c",
        "cong nghe phan mem": "SWE201c",
        "kỹ thuật phần mềm": "SWE201c",
        "ky thuat phan mem": "SWE201c",
        "swe": "SWE201c",
        "kiểm thử": "SWT301",
        "kiem thu": "SWT301",
        "testing": "SWT301",
        "swt": "SWT301",
        "đồ án chuyên ngành": "SWP391",
        "do an chuyen nganh": "SWP391",
        "dự án kỳ 5": "SWP391",
        "swp": "SWP391",
        "đồ án tốt nghiệp": "SEP490",
        "do an tot nghiep": "SEP490",
        "khóa luận": "SEP490",
        "capstone": "SEP490",
        "sep": "SEP490",
        "mạng máy tính": "NWC203c",
        "mang may tinh": "NWC203c",
        "nwc": "NWC203c",
        "hệ điều hành": "OSG202",
        "he dieu hanh": "OSG202",
        "osg": "OSG202",
        "toán rời rạc": "MAD101",
        "toan roi rac": "MAD101",
        "mad": "MAD101",
        "giải tích": "MAE101",
        "giai tich": "MAE101",
        "mae": "MAE101",
        "xác suất": "MAS291",
        "xac suat": "MAS291",
        "thống kê": "MAS291",
        "thong ke": "MAS291",
        "mas": "MAS291",
        "lập trình web": "WED201c",
        "lap trinh web": "WED201c",
        "frontend": "WED201c",
        "wed": "WED201c",
        "quản trị dự án": "PJM301",
        "quan tri du an": "PJM301",
        "pjm": "PJM301",
        "yêu cầu phần mềm": "SRE301",
        "yeu cau phan mem": "SRE301",
        "sre": "SRE301",
        "iot": "IOT102",
        "an toàn thông tin": "IA201",
        "an toan thong tin": "IA201",
        "bảo mật": "IA201",
        "vovinam": "VOV114",
        "vov": "VOV114",
        "quân sự": "GDQP1",
        "gdqp": "GDQP1",
        "khoa học máy tính": "CSI106",
        "khoa hoc may tinh": "CSI106",
        "csi": "CSI106",
        "kiến trúc máy tính": "CEA201",
        "kien truc may tinh": "CEA201",
        "cea": "CEA201",
        "nhạc cụ truyền thống": "TMI101",
        "nhac cu truyen thong": "TMI101",
        "nhạc cụ": "TMI101",
        "nhac cu": "TMI101",
        "tmi": "TMI101",
        "hệ thống thông tin": "ITE302c",
        "ite": "ITE302c",
        "tiếng nhật": "JPD123",
        "tieng nhat": "JPD123",
        "jpd": "JPD123",
        "kỹ năng giao tiếp": "SSG104",
        "ky nang giao tiep": "SSG104",
        "ssg": "SSG104",
        "kỹ năng học tập": "SSL101c",
        "ky nang hoc tap": "SSL101c",
        "ssl": "SSL101c",
        "tư tưởng hồ chí minh": "HCM202",
        "hcm": "HCM202",
        "triết học": "MLN111",
        "kinh tế chính trị": "MLN122",
        "chủ nghĩa xã hội": "MLN131",
        "mln": "MLN111",
        "khởi nghiệp": "EXE101",
        "exe": "EXE101",
        "quản trị dự án cntt": "PMG201c",
        "pmg": "PMG201c",
        "pháp luật đại cương": "VNR202",
        "vnr": "VNR202",
        "thiết kế web": "WDU203c",
        "wdu": "WDU203c",
        "quản lý yêu cầu": "SWR302",
        "swr": "SWR302",
        "lập trình c#": "PRN212",
        "c#": "PRN212",
        "c sharp": "PRN212",
        "net": "PRN212",
        "prn": "PRN212",
    }

    def __init__(self):
        self.chunks: List[FLMDocumentChunk] = []
        self.chunk_tokens: List[List[str]] = []
        self.doc_freqs: Dict[str, int] = {}
        self.total_docs: int = 0
        self.avg_doc_len: float = 0.0
        self.course_codes: Set[str] = set()
        self.course_name_map: Dict[str, str] = {}

    def index_chunks(self, chunks: List[FLMDocumentChunk]):
        """Builds inverted indices and statistics from list of document chunks."""
        self.chunks = chunks
        self.total_docs = len(chunks)
        self.chunk_tokens = []
        self.doc_freqs = {}
        self.course_codes = set()
        self.course_name_map = {}

        total_tokens = 0
        for chunk in chunks:
            if chunk.course_code:
                c_upper = chunk.course_code.upper()
                self.course_codes.add(c_upper)
                if chunk.course_name and c_upper not in self.course_name_map:
                    self.course_name_map[c_upper] = chunk.course_name.lower()

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
        """Tokenize text into lower-case words and meaningful phrase bigrams."""
        cleaned = re.sub(r"[^\w\s\d]", " ", (text or "").lower())
        words = [w for w in cleaned.split() if len(w) > 1]
        
        expanded = []
        for w in words:
            expanded.append(w)
            m = re.match(r"^([a-z]{2,5})(\d{1,4}[a-z]?)$", w)
            if m:
                expanded.append(m.group(1))
                expanded.append(m.group(2))

        bigrams = []
        for i in range(len(words) - 1):
            bigrams.append(f"{words[i]}_{words[i+1]}")
        return expanded + bigrams

    def extract_target_courses(self, query: str) -> List[str]:
        """
        Detects course codes mentioned in query:
        1. Regex matching standard codes with optional spaces (e.g. 'PRM393', 'PRM 393', 'SWE201c').
        2. Direct alias mapping.
        3. Natural language keyword and subject alias lookup.
        4. 3-letter course prefix lookup (e.g. 'csi' -> 'CSI106', 'swd' -> 'SWD392').
        5. Course name substring matching.
        """
        detected = []
        q_norm = query.strip()
        q_lower = q_norm.lower()

        # 1. Regex matching (supports optional space e.g. PRM 393)
        matches = re.findall(r"\b([A-Za-z]{3})\s*(\d{3}[A-Za-z]?)\b", q_norm)
        for prefix, number in matches:
            code = f"{prefix}{number}".upper()
            canonical = self.ALIASES.get(code, code)
            detected.append(canonical)

        # 2. Direct course codes in uppercase/lowercase (e.g. VOV114, GDQP1)
        direct_matches = re.findall(r"\b([A-Za-z]{2,5}\d{1,4}[A-Za-z]?)\b", q_norm)
        for dm in direct_matches:
            code = dm.upper()
            canonical = self.ALIASES.get(code, code)
            detected.append(canonical)

        # 3. Natural keyword and subject alias lookup
        for kw, mapped_code in self.KEYWORD_COURSE_MAP.items():
            pattern = rf"\b{re.escape(kw)}\b"
            if re.search(pattern, q_lower):
                detected.append(mapped_code)

        # 4. 3-letter course prefix lookup (e.g. 'csi' -> 'CSI106', 'swd' -> 'SWD392')
        STOPWORDS = {
            "MON", "HOC", "THI", "LAM", "SAO", "NHU", "THE", "NAO", "KHO", "QUA",
            "BAI", "HAY", "CHO", "CUA", "CAC", "NEN", "CAN", "TAP", "GIA", "KET", "VAN"
        }
        three_letter_tokens = re.findall(r"\b([A-Za-z]{3})\b", q_norm)
        for t in three_letter_tokens:
            t_upper = t.upper()
            if t_upper not in STOPWORDS:
                matching = sorted([c for c in self.course_codes if c.startswith(t_upper)])
                if matching:
                    canonical = self.ALIASES.get(matching[0], matching[0])
                    detected.append(canonical)

        # 5. Search in indexed course names
        for code, name in self.course_name_map.items():
            if len(name) > 3 and name in q_lower:
                detected.append(code)

        # Validate against known codes or retain detected
        final_list = []
        for c in detected:
            canonical = self.ALIASES.get(c, c)
            if canonical in self.course_codes or not self.course_codes:
                final_list.append(canonical)
            else:
                final_list.append(canonical)

        return list(dict.fromkeys(final_list))

    def detect_query_intent(self, query: str) -> List[str]:
        """Detects the specific intent of the user's query."""
        q_lower = query.lower()
        intents = []
        
        # 1. Study Strategy / Advising / How to study
        if any(k in q_lower for k in [
            "tư vấn", "cách học", "làm sao để qua", "làm sao để pass", "học thế nào",
            "học như thế nào", "ôn thi", "ôn tập", "bí kíp", "chiến lược", "kinh nghiệm",
            "ưu tiên môn nào", "phân bổ thời gian", "đạt điểm cao", "học tốt"
        ]):
            intents.append("strategy_advisor")

        # 2. Assessment / PE / FE / Grading
        if any(k in q_lower for k in [
            "pe", "practical exam", "thực hành", "thi", "fe", "final exam",
            "đánh giá", "hình thức", "kiểm tra", "trọng số", "quiz", "lab", "điểm thi"
        ]):
            intents.append("assessment")
        
        # 3. Learning Outcomes / LOs / PLOs
        if any(k in q_lower for k in [
            "mục tiêu", "lo", "los", "clo", "clos", "plo", "learning outcome",
            "chuẩn đầu ra", "học xong", "đầu ra"
        ]):
            intents.append("outcomes")
            
        # 4. Credits / Tín chỉ
        if any(k in q_lower for k in ["tín chỉ", "credit", "credits", "mấy tín", "bao nhiêu tín", "số tín"]):
            intents.append("overview")

        # 5. Semester / Prerequisites / Roadmap
        if any(k in q_lower for k in [
            "học kỳ", "kỳ mấy", "kỳ mấy học", "semester", "kế hoạch", "lộ trình",
            "tiên quyết", "prerequisite", "mở khóa", "thứ tự học"
        ]):
            intents.append("prerequisites")
            intents.append("overview")

        # 6. GPA Rules / Retake / Graduation Policies
        if any(k in q_lower for k in [
            "gpa", "hạ bậc", "hạ bằng", "tốt nghiệp", "học lại", "cải thiện",
            "rớt môn", "không tính gpa", "tính gpa", "xếp loại", "giỏi", "xuất sắc"
        ]):
            intents.append("gpa_rules")

        # 7. Syllabus / Tools
        if any(k in q_lower for k in ["công cụ", "phần mềm", "tools", "software", "slot", "nhiệm vụ", "thang điểm", "pass"]):
            intents.append("syllabus")

        return intents

    def search(
        self,
        query: str,
        top_k: int = 4,
        target_course: Optional[str] = None,
        similarity_threshold: float = 0.03,
    ) -> List[Tuple[FLMDocumentChunk, float]]:
        """
        Hybrid search combining BM25 scoring with course targeting and intent boosting.
        """
        if not self.chunks:
            return []

        query_tokens = self._tokenize(query)
        if not query_tokens:
            return []

        # Identify course codes in query
        detected_courses = [target_course.upper()] if target_course else self.extract_target_courses(query)
        intents = self.detect_query_intent(query)

        # Candidate filtering: if a specific course was detected, evaluate ONLY that course's chunks
        target_course_code = detected_courses[0] if detected_courses else None
        target_indices = (
            [i for i, c in enumerate(self.chunks) if c.course_code == target_course_code]
            if target_course_code
            else []
        )
        candidate_indices = target_indices if target_indices else list(range(len(self.chunks)))

        # BM25 Parameters
        k1 = 1.2
        b = 0.75
        scored_chunks: List[Tuple[FLMDocumentChunk, float]] = []

        q_tf = Counter(query_tokens)

        for i in candidate_indices:
            chunk = self.chunks[i]
            doc_tokens = self.chunk_tokens[i]
            doc_len = len(doc_tokens)
            doc_tf = Counter(doc_tokens)
            bm25_score = 0.0

            for term, count in q_tf.items():
                if term in doc_tf:
                    tf = doc_tf[term]
                    df = self.doc_freqs.get(term, 1)
                    idf = math.log(1 + (self.total_docs - df + 0.5) / (df + 0.5))
                    term_score = idf * (tf * (k1 + 1)) / (tf + k1 * (1 - b + b * (doc_len / self.avg_doc_len)))
                    bm25_score += term_score

            # Boost 1: Exact Course Match
            course_boost = 1.0
            if detected_courses:
                if chunk.course_code in detected_courses:
                    course_boost = 3.5
                else:
                    course_boost = 0.1

            # Boost 2: Intent Category Alignment
            intent_boost = 1.0
            if intents:
                if "strategy_advisor" in intents:
                    # Strategy advisor needs assessment + syllabus + outcomes
                    if chunk.category in ["assessment", "syllabus", "outcomes"]:
                        intent_boost = 2.2
                elif chunk.category in intents:
                    intent_boost = 2.0

            base_bm25 = bm25_score if bm25_score > 0 else 0.5
            final_score = base_bm25 * course_boost * intent_boost

            if final_score > similarity_threshold:
                scored_chunks.append((chunk, final_score))

        # Sort descending by score
        scored_chunks.sort(key=lambda x: x[1], reverse=True)
        return scored_chunks[:top_k]
