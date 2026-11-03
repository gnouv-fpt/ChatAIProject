"""Prepare, but do not activate, the reviewed VBHN 55 Articles 56–89."""
import hashlib
import importlib.util
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'content-bank/legal/55-2026-source-web-324-464.txt'
OFFICIAL = ROOT / 'content-bank/legal/55-vbhn-vpqh-signed.pdf'
TARGET = ROOT / 'content-bank/legal/55-2026-articles-56-89-review.json'

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
    if sorted(lines) != list(range(324, 465)):
        raise ValueError('Incomplete public-source capture for Articles 56–89')
    web = re.sub(r'【[^】]+】', '', ' '.join(lines[n] for n in sorted(lines)))
    web = web[web.index('Điều 56.'):]
    articles = previous.article_sections(web)
    if sorted(articles) != list(range(56, 90)):
        raise ValueError('Incomplete or ambiguous article boundaries')

    with previous.pymupdf.open(OFFICIAL) as pdf:
        official = ' '.join(span['text'] for page in pdf for block in page.get_text('dict')['blocks']
                            if 'lines' in block for line in block['lines'] for span in line['spans']
                            if round(span['size'], 1) == 14.0)
    official_articles = previous.article_sections(official)
    mismatches = []
    for number, content in articles.items():
        # The official PDF renders cm³ in Article 57; its superscript is a
        # smaller font and is omitted by the 14pt text extractor.
        compare = content.replace('cm^{3}', 'cm') if number in (57, 89) else content
        if number == 89:
            # The signed PDF's page 74 is an image. Its selectable text ends
            # after clause 3; clauses 4–7 were checked visually on that page.
            matches = number in official_articles and previous.norm(compare).startswith(
                previous.norm(official_articles[number]))
        else:
            matches = number in official_articles and previous.norm(compare) == previous.norm(
                official_articles[number])
        if not matches:
            mismatches.append(number)
    if mismatches:
        raise ValueError(f'Article differences require review: {mismatches}')

    formatted = []
    for content in articles.values():
        content = content.replace('cm^{3}', 'cm³')
        content = re.sub(r'(?<!Điều )(?<!\d)(\d{1,2}\.\s)', r'\n\1', content)
        content = re.sub(r'\s+([a-zđ]\)\s)', r'\n\1', content)
        formatted.append(content.strip())
    content = '\n'.join(formatted)
    data = {
        'documentNumber': '55/VBHN-VPQH',
        'documentTitle': 'Luật Trật tự, an toàn giao thông đường bộ · VBHN 55/2026 · trích Điều 56–89',
        'sourceUrl': 'https://thuvienphapluat.vn/van-ban/Giao-thong-Van-tai/Van-ban-hop-nhat-55-VBHN-VPQH-2026-Luat-Trat-tu-an-toan-giao-thong-duong-bo-698683.aspx',
        'officialSourceUrl': 'https://datafiles.chinhphu.vn/cpp/files/vbpq/2026/3/55-vbhn-vpqh.pdf',
        'captureMethod': 'public web reader; local TVPL browser returned HTTP 403',
        'articles': [str(n) for n in articles],
        'content': content,
        'contentSha256': hashlib.sha256(content.encode('utf8')).hexdigest(),
        'evidence': {
            'captureSha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
            'officialPdfSha256': hashlib.sha256(OFFICIAL.read_bytes()).hexdigest(),
            'articlesCompared': len(articles),
            'articlesRequiringReview': [],
            'comparisonExceptions': [
                'Article 57 cm³ superscript is rendered on signed PDF page 45 but omitted by 14pt extractor; TVPL cm^{3} retained as cm³ in package.',
                'Article 89 selectable PDF text matches TVPL through clause 3 after cm³ normalization; clauses 4–7 on image-only signed PDF page 74 were compared visually. Mobile TVPL API LawID 698683 matches web-reader Article 89 after cm³ normalization.'
            ],
            'mobileSourceUrl': 'https://apimobile.thuvienphapluat.vn/Document/GetDocumentDetail?LawID=698683&language=&token=',
            'mobileCaptureSha256': 'e534abf0ec58b574bb9368600c5dfbf656102158ba4ab36efba0a32a164c7134'
        },
        'effectiveFromUtc': '2026-06-30T17:00:00Z',
        'reviewNotes': 'Đối chiếu từng Điều 56–89 với PDF ký. Điều 57/89 có ngoại lệ ký hiệu cm³ do bộ trích PDF bỏ chỉ số trên; phần cuối Điều 89 ở trang ảnh 74 đã so trực quan với bản đọc TVPL. Điều 88 ghi mốc hiệu lực riêng 2028/2029 cho khoản 2 Điều 35. Gói chưa active; không nhập khi thiếu cơ chế phục hồi an toàn.'
    }
    encoded = (json.dumps(data, ensure_ascii=False, indent=2) + '\n').encode('utf8')
    if TARGET.exists() and TARGET.read_bytes() != encoded:
        raise ValueError('Immutable reviewed package differs')
    if not TARGET.exists():
        TARGET.write_bytes(encoded)
    print(json.dumps({'articles': len(articles), 'contentSha256': data['contentSha256'],
                      'captureSha256': data['evidence']['captureSha256'], 'active': False}))


if __name__ == '__main__':
    prepare()
