import hashlib
import math
import os
import re
import unicodedata
from collections import Counter
from urllib.error import HTTPError, URLError
from qdrant_client import QdrantClient, models


class QdrantTrafficStore:
    COLLECTION_NAME = "traffic_law_documents"

    def __init__(self, embedding_engine, host=None, port=None, *, client=None):
        self.COLLECTION_NAME = os.getenv("QDRANT_COLLECTION", self.COLLECTION_NAME)
        self.embedding_engine = embedding_engine
        self.vector_size = embedding_engine.DIMENSION
        # Tests explicitly inject their isolated client; runtime always connects to Qdrant.
        self._client = client if client is not None else QdrantClient(
            host=host or os.getenv("QDRANT_HOST", "localhost"),
            port=port or int(os.getenv("QDRANT_PORT", "6333")), timeout=10)
        if not self._client.collection_exists(self.COLLECTION_NAME):
            self._client.create_collection(self.COLLECTION_NAME,
                vectors_config=models.VectorParams(size=self.vector_size, distance=models.Distance.COSINE))
        info = self._client.get_collection(self.COLLECTION_NAME)
        if info.config.params.vectors.size != self.vector_size:
            raise RuntimeError("Qdrant collection dimension does not match the embedding API")

    @staticmethod
    def chunk_id_to_point_id(chunk_id):
        return int(hashlib.sha256(chunk_id.encode()).hexdigest()[:16], 16) % (2**63)

    def upsert_chunks(self, chunks, is_active=lambda: True):
        if not chunks:
            return 0
        batch_size = int(os.getenv("EMBEDDING_INDEX_BATCH_SIZE", "8"))
        if not 1 <= batch_size <= 32:
            raise ValueError("EMBEDDING_INDEX_BATCH_SIZE must be between 1 and 32")
        payloads = []
        for chunk in chunks:
            if not chunk.get("chunk_id"):
                raise ValueError("SQL chunk ID is required")
            payload = dict(chunk)
            payload["content_hash"] = hashlib.sha256(chunk["content"].encode()).hexdigest()
            payloads.append(payload)
        for offset in range(0, len(payloads), batch_size):
            if not is_active():
                raise RuntimeError("Indexing request cancelled")
            batch = payloads[offset:offset+batch_size]
            prior = {point.id: point for point in self._client.retrieve(self.COLLECTION_NAME,
                ids=[self.chunk_id_to_point_id(c['chunk_id']) for c in batch], with_payload=True, with_vectors=True)}
            pending = [c for c in batch if not (point := prior.get(self.chunk_id_to_point_id(c['chunk_id'])))
                       or point.payload != c]
            if not pending:
                continue
            reusable = {}
            needs_embedding = []
            for chunk in pending:
                point = prior.get(self.chunk_id_to_point_id(chunk['chunk_id']))
                if point and point.payload.get('chunk_id') == chunk['chunk_id'] and \
                        point.payload.get('content_hash') == chunk['content_hash'] and \
                        isinstance(point.vector, list) and len(point.vector) == self.vector_size:
                    reusable[chunk['chunk_id']] = point.vector
                else:
                    needs_embedding.append(chunk)
            embedded = self.embedding_engine.embed_documents([c['content'] for c in needs_embedding])
            vectors = {**reusable, **dict(zip((c['chunk_id'] for c in needs_embedding), embedded))}
            points = [models.PointStruct(id=self.chunk_id_to_point_id(c['chunk_id']),
                                         vector=vectors[c['chunk_id']], payload=c) for c in pending]
            result = self._client.upsert(self.COLLECTION_NAME, points=points, wait=True)
            if result.status != models.UpdateStatus.COMPLETED:
                raise RuntimeError("Qdrant did not acknowledge indexing")
        return len(chunks)

    def deactivate_document(self, document_number, chunk_ids=None):
        if document_number:
            selector = models.Filter(must=[models.FieldCondition(key="document_number",
                match=models.MatchValue(value=document_number))])
            count = self._client.count(self.COLLECTION_NAME, count_filter=selector, exact=True).count
        elif chunk_ids:
            selector = [self.chunk_id_to_point_id(cid) for cid in chunk_ids]
            count = len(self._client.retrieve(self.COLLECTION_NAME, ids=selector))
        else:
            raise ValueError("Document number or chunk IDs are required")
        result = self._client.set_payload(self.COLLECTION_NAME, payload={"is_active": False}, points=selector, wait=True)
        if result.status != models.UpdateStatus.COMPLETED:
            raise RuntimeError("Qdrant did not acknowledge deactivation")
        return count

    def verify_document_index(self, chunks):
        if not chunks or len({c['chunk_id'] for c in chunks}) != len(chunks):
            return False, 0, "Missing or duplicate expected chunk IDs"
        document_ids = {c['document_id'] for c in chunks}
        document_numbers = {c['document_number'] for c in chunks}
        if len(document_ids) != 1 or len(document_numbers) != 1:
            return False, 0, "Expected chunks span multiple documents"
        expected = {}
        for chunk in chunks:
            point_id = self.chunk_id_to_point_id(chunk['chunk_id'])
            if point_id in expected:
                return False, 0, "Point ID collision in expected chunks"
            payload = dict(chunk)
            content_hash = hashlib.sha256(payload['content'].encode()).hexdigest()
            if payload['content_hash'].lower() != content_hash:
                return False, 0, "Expected content hash mismatch"
            payload['content_hash'] = content_hash
            expected[point_id] = payload
        selector = models.Filter(must=[models.FieldCondition(key="document_id",
            match=models.MatchValue(value=next(iter(document_ids))))])
        actual_count = self._client.count(self.COLLECTION_NAME, count_filter=selector, exact=True).count
        if actual_count != len(expected):
            return False, 0, "Document point count mismatch"
        matched = 0
        for offset in range(0, len(expected), 64):
            ids = list(expected)[offset:offset + 64]
            points = self._client.retrieve(self.COLLECTION_NAME, ids=ids, with_payload=True)
            if len(points) != len(ids):
                return False, matched, "Missing expected point"
            for point in points:
                if point.payload != expected[point.id]:
                    return False, matched, "Point payload mismatch"
                matched += 1
        return True, matched, "All point IDs and payload fields match"

    def search_verified_chunks(self, query, top_k=5, score_threshold=0.20):
        if self._is_sanction_query(query):
            lexical = self._lexical_verified_chunks(query, top_k)
            if lexical and lexical[0].get('point') and lexical[0]['score'] >= 10:
                return lexical
        try:
            vector = self.embedding_engine.embed_query(query)
        except (HTTPError, URLError) as error:
            if isinstance(error, HTTPError) and error.code != 429:
                raise
            return self._lexical_verified_chunks(query, top_k)
        result = self._client.query_points(self.COLLECTION_NAME, query=vector,
            query_filter=models.Filter(must=[models.FieldCondition(key=key, match=models.MatchValue(value=True))
                for key in ("is_verified", "is_active")]), limit=top_k, score_threshold=score_threshold,
            with_payload=True)
        return [dict(point.payload, score=point.score) for point in result.points]

    @staticmethod
    def _words(value):
        plain = ''.join(char for char in unicodedata.normalize('NFD', value.lower())
                        if unicodedata.category(char) != 'Mn').replace('đ', 'd')
        return re.findall(r'[a-z0-9]+', plain)

    @staticmethod
    def _is_sanction_query(query):
        return bool(re.search(r'\bphạt\b|\bphat\b|xử phạt|xử lý vi phạm|trừ điểm|tước|tịch thu|khắc phục',
                              query, re.IGNORECASE))

    def _lexical_verified_chunks(self, query, top_k):
        stop = {'xe', 'nguoi', 'dieu', 'khien', 'muc', 'phat', 'xu', 'ly', 'bao', 'nhieu',
                'vi', 'pham', 'bi', 'the', 'nao', 'voi', 'cua', 'va', 'trong', 'nam', 'co'}
        words = self._words(query)
        plain_query = ' '.join(words)
        red_light = bool(re.search(r'\b(?:đèn|den)\s+(?:đỏ|do)\b', query, re.IGNORECASE))
        vehicle_article = None
        if 'xe may chuyen dung' in plain_query:
            vehicle_article = '8'
        elif 'xe dap' in plain_query:
            vehicle_article = '9'
        elif 'xe may' in plain_query or 'xe mo to' in plain_query or 'xe gan may' in plain_query:
            vehicle_article = '7'
        elif 'o to' in plain_query or 'xe tai' in plain_query:
            vehicle_article = '6'
        if red_light:
            words.extend(self._words('không chấp hành hiệu lệnh của đèn tín hiệu giao thông'))
        terms = set(words) - stop
        if len(terms) < 2:
            return []
        selector = models.Filter(must=[models.FieldCondition(key=key, match=models.MatchValue(value=True))
            for key in ('is_verified', 'is_active')])
        rows, offset = [], None
        while True:
            page, offset = self._client.scroll(self.COLLECTION_NAME, scroll_filter=selector,
                                                limit=256, offset=offset, with_payload=True)
            rows.extend(point.payload for point in page)
            if offset is None:
                break
        titles = {(row.get('document_id'), row.get('article')): row['content']
                  for row in rows if row.get('content', '').startswith('Điều ')
                  and not row.get('clause')}
        headers = {(row.get('document_id'), row.get('article'), row.get('clause')): row.get('content', '')
                   for row in rows if row.get('clause') and not row.get('point')}
        asks_sanction = self._is_sanction_query(query)
        records = [(row, self._words(row.get('content', '')),
                    set(self._words(titles.get((row.get('document_id'), row.get('article')), ''))))
                   for row in rows]
        document_frequencies = Counter(term for _, content_words, _ in records for term in set(content_words))
        average_length = sum(len(content_words) for _, content_words, _ in records) / max(1, len(records))
        question_grams = set(zip(words, words[1:], words[2:], words[3:]))
        query_long_grams = set(zip(*(words[i:] for i in range(8))))
        query_title_grams = set(zip(*(words[i:] for i in range(6))))
        title_grams = {key: set(zip(*(self._words(value)[i:] for i in range(6))))
                       for key, value in titles.items()}
        ranked = []
        for row, content_words, title_terms in records:
            if asks_sanction and row.get('document_number') == '168/2024/NĐ-CP' and \
                    not row.get('clause') and not row.get('point'):
                continue
            if vehicle_article and row.get('document_number') == '168/2024/NĐ-CP' and \
                    row.get('article') in {'6', '7', '8', '9'} and row.get('article') != vehicle_article:
                continue
            counts = Counter(content_words)
            content_terms = set(counts)
            overlap = terms & (content_terms | title_terms)
            if len(overlap) < 2:
                continue
            length = sum(counts.values())
            score = 0.0
            for term in terms:
                frequency = counts.get(term, 0)
                idf = math.log(1 + (len(records) - document_frequencies[term] + .5) /
                               (document_frequencies[term] + .5))
                if frequency:
                    score += idf * frequency * 2.2 / (
                        frequency + 1.2 * (.25 + .75 * length / average_length))
                if term in title_terms:
                    score += .25 * idf
            if asks_sanction and row.get('document_number') == '168/2024/NĐ-CP':
                if row.get('point') and re.match(r'^\s*\d+[a-z]?\.\s*Phạt tiền', headers.get(
                        (row.get('document_id'), row.get('article'), row.get('clause')), ''), re.IGNORECASE):
                    score += 2
            content_plain = ' '.join(content_words)
            if red_light:
                if asks_sanction and 'khong chap hanh hieu lenh cua den tin hieu giao thong' in content_plain:
                    score += 10
                elif not asks_sanction and 'tin hieu den mau do' in content_plain:
                    score += 10
            if asks_sanction and 'may' in words and ('mo' in title_terms or 'gan' in title_terms):
                score += 2
            if 'khong doi mu' in plain_query and content_plain.startswith(('h khong doi mu', 'b khong doi mu')):
                score += 3
            content_grams = set(zip(content_words, content_words[1:], content_words[2:], content_words[3:]))
            score += min(8, 2 * len(question_grams & content_grams))
            # Short sanction points can be an entire four-word violation; match
            # their phrase as a whole instead of burying them under long chunks.
            if content_grams:
                score += 24 * len(question_grams & content_grams) / len(content_grams)
            content_long_grams = set(zip(*(content_words[i:] for i in range(8))))
            shared_long_grams = len(query_long_grams & content_long_grams)
            if shared_long_grams >= 3 and content_long_grams:
                score += 30 * shared_long_grams / len(content_long_grams)
            # An article heading identifies the vehicle/operator class. Its exact
            # wording can disambiguate identical violations across several articles.
            score += min(18, 3 * len(title_grams.get(
                (row.get('document_id'), row.get('article')), set()) & query_title_grams))
            if score >= 4:
                ranked.append(dict(row, score=float(score)))
        ranked.sort(key=lambda row: row['score'], reverse=True)
        return ranked[:top_k]

    def get_verified_chunk(self, document_id, article, clause, point=None):
        filters = [("document_id", document_id), ("article", article), ("clause", clause),
                   ("is_verified", True), ("is_active", True)]
        if point is not None:
            filters.append(("point", point))
        conditions = [models.FieldCondition(key=key, match=models.MatchValue(value=value))
                      for key, value in filters]
        points, _ = self._client.scroll(self.COLLECTION_NAME,
            scroll_filter=models.Filter(must=conditions), limit=2, with_payload=True)
        if len(points) != 1:
            return None
        return dict(points[0].payload)

    def get_verified_article_chunks(self, document_id, article):
        selector = models.Filter(must=[models.FieldCondition(key=key, match=models.MatchValue(value=value))
            for key, value in (("document_id", document_id), ("article", article),
                               ("is_verified", True), ("is_active", True))])
        rows, offset = [], None
        while True:
            page, offset = self._client.scroll(self.COLLECTION_NAME, scroll_filter=selector,
                                                limit=128, offset=offset, with_payload=True)
            rows.extend(dict(point.payload) for point in page)
            if offset is None:
                break
        return rows
