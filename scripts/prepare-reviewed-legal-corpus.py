"""Prepare TVPL public text captured by the web reader; compare with the signed official PDF.

This does not claim the local HTTP crawler succeeded (TVPL returned HTTP 403).
"""
import hashlib
import json
import re
import sys
import tempfile
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / 'artifacts/local-ai'
CAPTURES = ROOT / 'content-bank/legal'
SIGNED_PDF = CAPTURES / '55-vbhn-vpqh-signed.pdf'
CAPTURE_NAMES = ('source-web-136.txt', 'source-web-196.txt',
                 'source-web-256.txt', 'source-web-96.txt')
sys.path.insert(0, str(Path(tempfile.gettempdir()) / 'prn_pdf_tools'))
import pymupdf


def norm(text):
    return re.sub(r'\s+', '', unicodedata.normalize('NFC', text))


def prepare():
    lines = {}
    captures = {}
    for name in CAPTURE_NAMES:
        path = CAPTURES / name
        captures[path.name] = hashlib.sha256(path.read_bytes()).hexdigest()
        for line in path.read_text(encoding='utf8').splitlines():
            match = re.match(r'L(\d+): (.*)', line)
            if match:
                number = int(match[1])
                if number in lines and lines[number] != match[2]:
                    raise ValueError('Public source changed across captures; re-review required.')
                lines[number] = match[2]
    text = ' '.join(lines[number] for number in range(109, 228))
    text = re.sub(r'【[^】]+】', '', text)
    text = text[text.index('Điều 1.'):text.index('Điều 34.')].strip()
    sections = re.split(r'(?=Điều \d+\. )', text)
    articles = {}
    for section in sections:
        match = re.match(r'Điều (\d+)\.', section)
        if match:
            number = int(match[1])
            if number in articles: raise ValueError('Ambiguous article boundary')
            articles[number] = section.strip()
    if sorted(articles) != list(range(1, 34)): raise ValueError('Incomplete reviewed scope 1–33')
    # Remove PDF page numbers, footnotes and superscript editorial markers by retaining body font 14.
    with pymupdf.open(SIGNED_PDF) as doc:
        official = ' '.join(s['text'] for page in doc for block in page.get_text('dict')['blocks'] if 'lines' in block
                            for line in block['lines'] for s in line['spans'] if round(s['size'], 1) == 14.0)
    official_sections = re.split(r'(?=Điều \d+\. )', official)
    official_articles = {}
    for section in official_sections:
        match = re.match(r'Điều (\d+)\.', section)
        if match and int(match[1]) not in official_articles: official_articles[int(match[1])] = section
    # Visually checked PDF p11, Article 11(3)(c): signed PDF prints “điểu”, TVPL prints “điều”.
    # Keep TVPL wording; accept only this exact, recorded accent difference in the comparison.
    reviewed_official = dict(official_articles)
    reviewed_official[11] = reviewed_official[11].replace('người điểu khiển', 'người điều khiển')
    mismatches = [n for n, content in articles.items() if norm(content) != norm(reviewed_official.get(n, ''))]
    comparison = {'capturedArticles': len(articles), 'officialPdfSha256': hashlib.sha256(SIGNED_PDF.read_bytes()).hexdigest(),
                  'articlesRequiringReview': mismatches, 'captureHashes': captures,
                  'reviewedDifference': {'article': 11, 'clause': 3, 'point': 'c', 'pdfPage': 11,
                                        'official': 'người điểu khiển', 'tvplPreserved': 'người điều khiển'}}
    (WORK / 'source-comparison.json').write_text(json.dumps(comparison, indent=2), encoding='utf8')
    if mismatches:
        (WORK / 'comparison-details.json').write_text(json.dumps({str(n): {'tvpl': articles[n], 'official': official_articles.get(n, '')}
            for n in mismatches}, ensure_ascii=False, indent=2), encoding='utf8')
        raise ValueError(f'Public/official article differences require review: {mismatches}')
    formatted = []
    for content in articles.values():
        content = re.sub(r'(?<!Điều )(?<!\d)(\d{1,2}\.\s)', r'\n\1', content)
        content = re.sub(r'\s+([a-zđ]\)\s)', r'\n\1', content)
        formatted.append(content.strip())
    content = '\n'.join(formatted)
    manifest = {'documentNumber': '55/VBHN-VPQH', 'documentTitle': 'Luật Trật tự, an toàn giao thông đường bộ · VBHN 55/2026 · trích Điều 1–33',
        'sourceUrl': 'https://thuvienphapluat.vn/van-ban/Giao-thong-Van-tai/Van-ban-hop-nhat-55-VBHN-VPQH-2026-Luat-Trat-tu-an-toan-giao-thong-duong-bo-698683.aspx',
        'officialSourceUrl': 'https://datafiles.chinhphu.vn/cpp/files/vbpq/2026/3/55-vbhn-vpqh.pdf',
        'captureMethod': 'public-web-reader-text; local crawler returned HTTP 403',
        'articles': [str(n) for n in articles], 'content': content,
        'contentSha256': hashlib.sha256(content.encode()).hexdigest(),
        'evidence': comparison, 'effectiveFromUtc': '2026-06-30T17:00:00Z',
        'reviewNotes': 'Đối chiếu đủ Điều 1–33 giữa nội dung công khai TVPL và bản hợp nhất Chính phủ; '
                       'đã gồm sửa đổi Luật 118/2025 có hiệu lực 01/07/2026. Không nhập các điều/khoản áp dụng tương lai từ 2028 ngoài phạm vi này.'}
    target = ROOT / 'content-bank/legal/55-2026-articles-1-33.json'
    target.parent.mkdir(parents=True, exist_ok=True)
    data = (json.dumps(manifest, ensure_ascii=False, indent=2)+'\n').encode()
    if target.exists() and target.read_bytes() != data: raise ValueError('Immutable corpus differs; review a new edition')
    if not target.exists(): target.write_bytes(data)
    print(f'Prepared {len(articles)} articles: official PDF comparison passed, with one visually reviewed accent difference recorded.')


if __name__ == '__main__': prepare()
