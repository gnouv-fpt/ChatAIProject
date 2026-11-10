"""Conservative matching against reviewed sign drawings in the official QCVN."""
import io
import json
from pathlib import Path

from PIL import Image, UnidentifiedImageError

from rag.visual_question_matcher import visual_hash


class QcvnSignMatcher:
    MAX_DISTANCE = 24
    MIN_MARGIN = 100
    MEANINGS = {
        'P.101': 'Đường cấm: cấm các loại phương tiện đi lại theo cả hai hướng, trừ xe được ưu tiên theo quy định.',
        'P.102': 'Cấm đi ngược chiều: các loại xe không được đi vào theo chiều đặt biển, trừ xe được ưu tiên theo quy định; người đi bộ được đi trên vỉa hè hoặc lề đường.',
    }

    def __init__(self):
        package = json.loads((Path(__file__).resolve().parents[1] /
                              'qcvn_sign_fingerprints.json').read_text(encoding='utf8'))
        if package['officialPdfSha256'] != \
                'b6b99d0a0aeb13fe79072831857ece15bb254d8fb7817e80e4a2739a0d2145ce' or \
                {row['code'] for row in package['signs']} != set(self.MEANINGS):
            raise ValueError('Official sign fingerprint inventory changed')
        self.rows = [(row, int(row['visual_hash'], 16)) for row in package['signs']]

    def match(self, image_bytes):
        try:
            with Image.open(io.BytesIO(image_bytes)) as image:
                if image.width * image.height > 12_000_000:
                    return None
                image.load()
                fingerprint = visual_hash(image)
        except (UnidentifiedImageError, OSError, ValueError):
            return None
        ranked = sorted(((fingerprint ^ saved).bit_count(), row)
                        for row, saved in self.rows)
        if ranked[0][0] > self.MAX_DISTANCE or ranked[1][0] - ranked[0][0] < self.MIN_MARGIN:
            return None
        return ranked[0][1]
