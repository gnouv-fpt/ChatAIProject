"""Prepare TVPL Articles 50–55 only after comparison with the signed official PDF."""
import hashlib
import importlib.util
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / 'artifacts/local-ai'
SOURCE = ROOT / 'content-bank/legal/55-2026-source-web-297-324.txt'
TARGET = ROOT / 'content-bank/legal/55-2026-articles-50-55-review.json'

spec = importlib.util.spec_from_file_location('previous', ROOT / 'scripts/prepare-reviewed-legal-extension.py')
previous = importlib.util.module_from_spec(spec)
spec.loader.exec_module(previous)


def prepare():
    lines = {}
    for line in SOURCE.read_text(encoding='utf8').splitlines():
        match = re.fullmatch(r'L(\d+): (.*)', line)
        if not match or int(match[1]) in lines:
            raise ValueError('Invalid or duplicate public-source line')
        lines[int(match[1])] = match[2]
    if sorted(lines) != list(range(297, 325)):
        raise ValueError('Incomplete public-source capture for Articles 50–55')
    text = re.sub(r'【[^】]+】', '', ' '.join(lines[n] for n in sorted(lines)))
    text = text[text.index('Điều 50.'):text.index('Điều 56.')]
    articles = previous.article_sections(text)
    if sorted(articles) != list(range(50, 56)):
        raise ValueError('Incomplete or ambiguous article boundaries')

    with previous.pymupdf.open(previous.SIGNED_PDF) as pdf:
        official = ' '.join(span['text'] for page in pdf for block in page.get_text('dict')['blocks']
                            if 'lines' in block for line in block['lines'] for span in line['spans']
                            if round(span['size'], 1) == 14.0)
    official_articles = previous.article_sections(official)
    mismatches = [n for n in articles if n not in official_articles or
                  previous.norm(articles[n]) != previous.norm(official_articles[n])]
    if mismatches:
        (WORK / 'extension-50-55-comparison-details.json').write_text(json.dumps({str(n): {
            'tvpl': articles[n], 'officialPdf': official_articles.get(n, '')} for n in mismatches},
            ensure_ascii=False, indent=2), encoding='utf8')
        raise ValueError(f'Article differences require review: {mismatches}')

    formatted = []
    for content in articles.values():
        content = re.sub(r'(?<!Điều )(?<!\d)(\d{1,2}\.\s)', r'\n\1', content)
        content = re.sub(r'\s+([a-zđ]\)\s)', r'\n\1', content)
        formatted.append(content.strip())
    content = '\n'.join(formatted)
    data = {
        'documentNumber': '55/VBHN-VPQH',
        'documentTitle': 'Luật Trật tự, an toàn giao thông đường bộ · VBHN 55/2026 · trích Điều 50–55',
        'sourceUrl': 'https://thuvienphapluat.vn/van-ban/Giao-thong-Van-tai/Van-ban-hop-nhat-55-VBHN-VPQH-2026-Luat-Trat-tu-an-toan-giao-thong-duong-bo-698683.aspx',
        'officialSourceUrl': 'https://datafiles.chinhphu.vn/cpp/files/vbpq/2026/3/55-vbhn-vpqh.pdf',
        'captureMethod': 'public web reader; local TVPL HTTP crawler returned 403',
        'articles': [str(n) for n in articles], 'content': content,
        'contentSha256': hashlib.sha256(content.encode('utf8')).hexdigest(),
        'evidence': {'captureSha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
                     'officialPdfSha256': hashlib.sha256(previous.SIGNED_PDF.read_bytes()).hexdigest(),
                     'articlesCompared': 6, 'articlesRequiringReview': []},
        'effectiveFromUtc': '2026-06-30T17:00:00Z',
        'reviewNotes': 'Đối chiếu nguyên văn Điều 50–55 giữa nội dung công khai TVPL và PDF Chính phủ của VBHN 55/2026; không nhập Điều 56 khi capture mới chỉ bắt đầu điều này.'
    }
    encoded = (json.dumps(data, ensure_ascii=False, indent=2) + '\n').encode('utf8')
    if TARGET.exists() and TARGET.read_bytes() != encoded:
        raise ValueError('Immutable reviewed package differs')
    if not TARGET.exists():
        TARGET.write_bytes(encoded)
    print(f"Prepared {len(articles)} articles; content SHA-256 {data['contentSha256']}")


if __name__ == '__main__':
    prepare()
