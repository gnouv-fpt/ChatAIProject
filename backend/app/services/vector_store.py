import re
from typing import Dict, List, Optional, Set, Tuple

import numpy as np
from fastembed import TextEmbedding
from .flm_parser import FLMDocumentChunk


class SemanticVectorStore:
    """
    Embedding retrieval engine for FLM Knowledge & AI Assistant.

    Retrieval is based on multilingual sentence embeddings and cosine
    similarity. Exact course/entity detection remains only a scope guard; it
    is never used as a substitute for semantic retrieval.
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
        "thiết kế web": "WED201c",
        "wdu": "WDU203c",
        "quản lý yêu cầu": "SWR302",
        "swr": "SWR302",
        "lập trình c#": "PRN212",
        "c#": "PRN212",
        "c sharp": "PRN212",
        "net": "PRN212",
        "prn": "PRN212",
    }

    SEMANTIC_INTENT_EXAMPLES = {
        "strategy_advisor": [
            "Em nên bắt đầu từ đâu để học môn này cho đỡ ngợp?",
            "Tôi cần một lộ trình thực tế để cải thiện kết quả học tập.",
            "Nên ưu tiên phần nào và luyện như thế nào để làm bài tốt?",
        ],
        "assessment": [
            "Môn này được đánh giá và kiểm tra theo những phần nào?",
            "Tôi cần chuẩn bị cho các bài thi và bài thực hành ra sao?",
        ],
        "outcomes": [
            "Học xong môn này tôi phải làm được gì?",
            "Môn học muốn sinh viên đạt được năng lực nào?",
        ],
        "prerequisites": [
            "Trước khi học môn này cần biết những gì và học sau môn nào?",
            "Môn này nằm ở đâu trong lộ trình chương trình?",
        ],
        "grade_goal": [
            "Tôi muốn đạt điểm chín trong môn này, cần phân bổ nỗ lực thế nào?",
            "Tôi muốn ra trường với GPA cao hơn, hãy tính mục tiêu điểm cần đạt.",
            "Mục tiêu điểm số của tôi là bao nhiêu và có khả thi không?",
        ],
    }

    def __init__(self, model_name: str = "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2", cache_dir: str = ".rag_cache", embedder=None):
        self.chunks: List[FLMDocumentChunk] = []
        self.embeddings: Optional[np.ndarray] = None
        self.course_codes: Set[str] = set()
        self.course_name_map: Dict[str, str] = {}
        self.course_profile_codes: List[str] = []
        self.course_profile_embeddings: Optional[np.ndarray] = None
        self.chunk_tokens: List[Set[str]] = []
        self.token_idf: Dict[str, float] = {}
        self.model_name = model_name
        self.cache_dir = cache_dir
        self.embedder = embedder

    def index_chunks(self, chunks: List[FLMDocumentChunk]):
        """Encode every knowledge chunk once and keep a normalized matrix."""
        self.chunks = chunks
        self.course_codes = set()
        self.course_name_map = {}
        for chunk in chunks:
            if chunk.course_code:
                c_upper = chunk.course_code.upper()
                self.course_codes.add(c_upper)
                if chunk.course_name and c_upper not in self.course_name_map:
                    self.course_name_map[c_upper] = chunk.course_name.lower()

        texts = [f"passage: {chunk.to_text_for_embedding()}" for chunk in chunks]
        self.embeddings = self._encode(texts)
        self.chunk_tokens = [self._tokenize(chunk.to_text_for_embedding()) for chunk in chunks]
        document_frequency: Dict[str, int] = {}
        for tokens in self.chunk_tokens:
            for token in tokens:
                document_frequency[token] = document_frequency.get(token, 0) + 1
        total_chunks = max(1, len(self.chunk_tokens))
        self.token_idf = {
            token: float(np.log((1 + total_chunks) / (1 + frequency)) + 1.0)
            for token, frequency in document_frequency.items()
        }

        # A separate course-profile index lets semantic entity resolution work
        # even when the user describes a subject without using its exact alias.
        self.course_profile_codes = sorted(self.course_name_map)
        profile_texts = [
            f"Mã môn {code}. Tên môn: {self.course_name_map[code]}"
            for code in self.course_profile_codes
        ]
        self.course_profile_embeddings = self._encode(
            [f"passage: {text}" for text in profile_texts]
        ) if profile_texts else None
        print(f"[SemanticStore] Indexed {len(self.chunks)} chunks across {len(self.course_codes)} courses using {self.model_name}.")

    @staticmethod
    def _tokenize(text: str) -> Set[str]:
        """Tokenize Vietnamese text for a small BM25-like lexical signal."""
        tokens = re.findall(r"[a-z0-9À-ỹ]+", text.lower())
        stopwords = {
            "môn", "mon", "học", "hoc", "của", "cua", "và", "va", "là", "la",
            "cho", "có", "co", "tôi", "toi", "em", "mình", "minh", "này", "nay",
            "những", "nhung", "các", "cac", "trong", "với", "voi", "thì", "thi",
            "được", "duoc", "bao", "nhiêu", "nhieu", "gì", "gi", "nào", "nao",
        }
        return {token for token in tokens if len(token) > 1 and token not in stopwords}

    def _lexical_score(self, query_tokens: Set[str], chunk_index: int) -> float:
        if not query_tokens or not self.chunk_tokens:
            return 0.0
        chunk_tokens = self.chunk_tokens[chunk_index]
        if not chunk_tokens:
            return 0.0
        matched_weight = sum(self.token_idf.get(token, 1.0) for token in query_tokens & chunk_tokens)
        query_weight = sum(self.token_idf.get(token, 1.0) for token in query_tokens)
        return matched_weight / max(query_weight, 1e-9)

    def canonical_course_code(self, code: Optional[str]) -> Optional[str]:
        if not code:
            return None
        normalized = re.sub(r"\s+", "", code).upper()
        alias = self.ALIASES.get(normalized, normalized)
        return alias.upper()

    def _get_embedder(self):
        if self.embedder is None:
            self.embedder = TextEmbedding(model_name=self.model_name, cache_dir=self.cache_dir)
        return self.embedder

    def _encode(self, texts: List[str]) -> np.ndarray:
        if not texts:
            return np.empty((0, 0), dtype=np.float32)
        try:
            vectors = np.asarray(list(self._get_embedder().embed(texts)), dtype=np.float32)
        except Exception as exc:
            raise RuntimeError(
                f"Không thể tạo embedding semantic bằng model '{self.model_name}'. "
                "Kiểm tra fastembed/model cache hoặc kết nối mạng để tải model."
            ) from exc
        norms = np.linalg.norm(vectors, axis=1, keepdims=True)
        return vectors / np.maximum(norms, 1e-12)

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
            canonical = self.canonical_course_code(code) or code
            detected.append(canonical)

        # 2. Direct course codes in uppercase/lowercase (e.g. VOV114, GDQP1)
        direct_matches = re.findall(r"\b([A-Za-z]{2,5}\d{1,4}[A-Za-z]?)\b", q_norm)
        for dm in direct_matches:
            code = dm.upper()
            canonical = self.canonical_course_code(code) or code
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
                    canonical = self.canonical_course_code(matching[0]) or matching[0]
                    detected.append(canonical)

        # 5. Search in indexed course names
        for code, name in self.course_name_map.items():
            if len(name) > 3 and name in q_lower:
                detected.append(code)

        # Semantic entity resolution is deliberately applied after exact
        # detection. Exact codes/aliases remain authoritative, while a
        # paraphrase such as "lập trình trên điện thoại" can still resolve to
        # the mobile-programming course.
        if self.course_profile_embeddings is not None and not detected:
            try:
                query_vector = self._encode([f"query: {query}"])[0]
                profile_scores = self.course_profile_embeddings @ query_vector
                ranked_profiles = np.argsort(profile_scores)[::-1]
                if len(ranked_profiles):
                    best_index = int(ranked_profiles[0])
                    best_score = float(profile_scores[best_index])
                    second_score = float(profile_scores[ranked_profiles[1]]) if len(ranked_profiles) > 1 else -1.0
                    if best_score >= 0.55 and best_score - second_score >= 0.025:
                        detected.append(self.course_profile_codes[best_index])
            except Exception:
                # Entity enrichment must never break normal retrieval.
                pass

        # Keep only codes that exist in the indexed curriculum. Code-shaped
        # tokens such as "HK5" (học kỳ 5) must not be treated as subjects.
        final_list = []
        for c in detected:
            canonical = self.canonical_course_code(c) or c
            if canonical in self.course_codes or not self.course_codes:
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

        # 8. Curriculum Overview / Semester Breakdown / Program Structure
        if any(k in q_lower for k in [
            "curriculum", "khung chương trình", "chương trình đào tạo", "chương trình khung",
            "tổng số môn", "tổng số tín chỉ", "tín chỉ tích lũy", "bao nhiêu học kỳ", "bao nhiêu môn",
            "xuất hiện trong", "ở kỳ mấy", "thuộc kỳ nào", "học ở kỳ mấy"
        ]):
            intents.append("curriculum")
            intents.append("overview")

        # 9. Semester credits or semester courses query (e.g. "HK5 có bao nhiêu tín chỉ?")
        if any(k in q_lower for k in ["tín chỉ", "mấy tín", "bao nhiêu tín", "môn nào", "bao nhiêu môn"]) and any(k in q_lower for k in ["hk", "học kỳ", "kỳ "]):
            intents.append("curriculum")
            intents.append("overview")

        # Keyword rules handle explicit requests. Embedding prototypes handle
        # natural advisory language such as "em nên bắt đầu từ đâu" where no
        # fixed advice keyword is present.
        if self.embeddings is not None:
            try:
                query_vector = self._encode([f"query: {query}"])[0]
                intent_thresholds = {
                    "strategy_advisor": 0.58,
                    "assessment": 0.70,
                    "outcomes": 0.72,
                    "prerequisites": 0.72,
                    "grade_goal": 0.70,
                }
                for intent, examples in self.SEMANTIC_INTENT_EXAMPLES.items():
                    example_vectors = self._encode([f"query: {example}" for example in examples])
                    semantic_score = float(np.max(example_vectors @ query_vector))
                    if semantic_score >= intent_thresholds[intent] and intent not in intents:
                        intents.append(intent)

                # "Học xong ... làm được gì?" is an outcome question, not a
                # study-plan request. Prevent prototype overlap from routing
                # it into the generic strategy answer.
                explicit_strategy_terms = (
                    "tư vấn", "cách học", "ôn thi", "ôn tập", "chiến lược",
                    "lộ trình học", "phân bổ thời gian", "đạt điểm cao", "học tốt",
                )
                if "outcomes" in intents and "strategy_advisor" in intents \
                        and not any(term in q_lower for term in explicit_strategy_terms):
                    intents.remove("strategy_advisor")
            except Exception:
                # Retrieval still has a clear error path; intent enrichment is
                # optional and must not hide a valid semantic search result.
                pass

        return intents

    def search(
        self,
        query: str,
        top_k: int = 4,
        target_course: Optional[str] = None,
        similarity_threshold: float = 0.03,
    ) -> List[Tuple[FLMDocumentChunk, float]]:
        """Search by multilingual embedding similarity inside a safe scope."""
        if not self.chunks or self.embeddings is None:
            return []
        if not query.strip():
            return []

        detected_courses = [self.canonical_course_code(target_course)] if target_course else self.extract_target_courses(query)
        intents = self.detect_query_intent(query)

        target_course_code = detected_courses[0] if detected_courses else None
        target_indices: List[int] = []
        if target_course_code:
            if target_course_code in ["CURRICULUM", "BIT_SE_K19B"]:
                target_indices = [i for i, c in enumerate(self.chunks) if c.course_code in ["CURRICULUM", "BIT_SE_K19B"] or c.category == "curriculum"]
            else:
                target_indices = [
                    i for i, c in enumerate(self.chunks)
                    if (c.course_code or "").upper() == target_course_code.upper()
                ]

                if not target_indices:
                    return []

        candidate_indices = target_indices if target_indices else list(range(len(self.chunks)))
        query_tokens = self._tokenize(query)
        query_variants = [f"query: {query}"]
        intent_expansions = {
            "outcomes": "chuẩn đầu ra CLO năng lực sau khi hoàn thành mục tiêu môn học",
            "assessment": "hình thức kiểm tra thi PE FE trọng số đánh giá",
            "prerequisites": "môn tiên quyết lộ trình học học kỳ điều kiện",
            "overview": "tín chỉ học kỳ thông tin tổng quan môn học",
            "strategy_advisor": "cách học ôn tập kế hoạch luyện tập đạt kết quả",
        }
        query_variants.extend(
            f"query: {query}. {intent_expansions[intent]}"
            for intent in intents
            if intent in intent_expansions
        )
        query_vectors = self._encode(query_variants)
        semantic_scores = np.max(self.embeddings[candidate_indices] @ query_vectors.T, axis=1)

        category_bonus = {
            "outcomes": {"outcomes": 0.12},
            "assessment": {"assessment": 0.12},
            "prerequisites": {"prerequisites": 0.12, "schedule": 0.08},
            "overview": {"overview": 0.10},
            "strategy_advisor": {"syllabus": 0.08, "assessment": 0.06},
        }
        ranked_scores = []
        for candidate_position, index in enumerate(candidate_indices):
            lexical = self._lexical_score(query_tokens, index)
            category = self.chunks[index].category or "unknown"
            bonus = max(
                (category_bonus.get(intent, {}).get(category, 0.0) for intent in intents),
                default=0.0,
            )
            # Dense retrieval remains dominant; lexical overlap and intent
            # are precision signals, not hard keyword gates.
            combined = 0.68 * float(semantic_scores[candidate_position]) + 0.22 * lexical + bonus
            ranked_scores.append((index, combined))
        ranked = sorted(ranked_scores, key=lambda x: x[1], reverse=True)

        # Semantic similarity chooses relevance. Intent only diversifies the
        # evidence needed for an answer; it never turns an unrelated chunk
        # into a match.
        selected: List[Tuple[FLMDocumentChunk, float]] = []
        category_counts: Dict[str, int] = {}
        for index, score in ranked:
            if score < similarity_threshold:
                continue
            chunk = self.chunks[index]
            category = chunk.category or "unknown"
            if category_counts.get(category, 0) >= 2:
                continue
            selected.append((chunk, float(score)))
            category_counts[category] = category_counts.get(category, 0) + 1
            if len(selected) >= top_k:
                break
        return selected

