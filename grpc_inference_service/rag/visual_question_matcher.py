"""Conservative visual lookup for published CSGT practice questions."""
import io
import json
import re
from pathlib import Path

from PIL import Image, ImageOps, UnidentifiedImageError


def visual_hash(image):
    values = ImageOps.grayscale(image).resize((32, 32)).tobytes()
    mean = sum(values) / len(values)
    return sum(1 << index for index, value in enumerate(values) if value >= mean)


class PublishedVisualQuestionMatcher:
    MAX_DISTANCE = 20
    NUMBERED_MAX_DISTANCE = 40
    MIN_MARGIN = 20

    def __init__(self):
        source = Path(__file__).resolve().parents[1] / 'visual_question_fingerprints.json'
        package = json.loads(source.read_text(encoding='utf8'))
        rows = package['questions']
        if len(rows) != 317 or sum(row['category'] == 'SCENARIO' for row in rows) != 115:
            raise ValueError('Published visual question lookup is incomplete')
        self.rows = [(row, int(row['visual_hash'], 16)) for row in rows]

    @staticmethod
    def _same_question(prompt, question):
        stripped = re.sub(r'^\s*câu(?:\s+(?:hỏi|số))?\s*\d{1,3}\s*[:.\-]?\s*',
                          '', prompt, count=1, flags=re.IGNORECASE)
        first_line = stripped.splitlines()[0].strip()
        if re.sub(r'\W+', '', first_line, flags=re.UNICODE).casefold() == \
                re.sub(r'\W+', '', question, flags=re.UNICODE).casefold():
            return True
        if re.search(r'đáp án\s*(?:nào|gì|đúng|là|số)|chọn\s*(?:đáp án|phương án)|'
                     r'phương án\s*(?:nào|đúng|số)', prompt, re.IGNORECASE):
            return True
        families = (
            r'thứ tự|đi trước|đi đầu tiên|nhường đường',
            r'hướng nào|được phép đi|được đi|quay đầu|rẽ',
            r'vi phạm|chấp hành|đúng quy tắc|có đúng',
            r'xử lý|làm gì|nên làm',
            r'vượt xe|được phép vượt|có được.*vượt',
            r'dừng xe|dừng lại|dừng đúng|đỗ xe',
            r'nhập làn|vào làn|chuyển làn',
            r'biển nào|biển báo nào|biển báo này|biển nào.*(cấm|báo|chỉ)|biển.*(ý nghĩa|tác dụng)',
            r'vạch.*(tác dụng|ý nghĩa|phân chia)|vạch nào',
        )
        return any(re.search(pattern, question, re.IGNORECASE)
                   and re.search(pattern, prompt, re.IGNORECASE) for pattern in families)

    def match(self, prompt, image_bytes):
        match = re.search(r'\bcâu(?:\s+(?:hỏi|số))?\s*(\d{3})\b', prompt, re.IGNORECASE)
        number = int(match.group(1)) if match else None
        try:
            with Image.open(io.BytesIO(image_bytes)) as image:
                if image.width * image.height > 12_000_000:
                    return None
                image.load()
                fingerprint = visual_hash(image)
        except (UnidentifiedImageError, OSError, ValueError):
            return None
        ranked = sorted((((fingerprint ^ saved).bit_count(), row) for row, saved in self.rows),
                        key=lambda item: (item[0], item[1]['number']))
        best_distance = ranked[0][0]
        if best_distance > (self.NUMBERED_MAX_DISTANCE if number is not None else self.MAX_DISTANCE):
            return None
        eligible = [row for distance, row in ranked if distance == best_distance]
        if number is not None:
            eligible = [row for row in eligible if row['number'] == number]
            if not eligible:
                return None
        elif len(eligible) != 1 or ranked[1][0] - best_distance < self.MIN_MARGIN:
            return None
        row = eligible[0]
        asks_for_explanation = number is not None and re.search(
            r'giải thích\s*(?:câu|đáp án)|vì sao\s*(?:câu|đáp án)', prompt, re.IGNORECASE)
        if not (asks_for_explanation or self._same_question(prompt, row['question'])):
            return None
        return (f"Câu {row['number']} trong bộ 600 câu CSGT 2025: {row['question']}\n"
                f"Đáp án: {row['answer']}\n\nNguồn đáp án bộ đề CSGT: {row['source_url']}\n"
                "Lưu ý: nguồn đáp án bộ đề chưa phải trích dẫn điều luật hoặc quy chuẩn cho lời giải.")
