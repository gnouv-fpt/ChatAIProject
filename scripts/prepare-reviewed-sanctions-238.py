"""Compare the official Gazette DOCX with TVPL and prepare an inactive source package."""
import hashlib
import html
import json
import re
import unicodedata
import xml.etree.ElementTree as ET
import zipfile
from html.parser import HTMLParser
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OFFICIAL = ROOT / 'artifacts/local-ai/238-ndcp-congbao.docx'
PUBLIC = ROOT / 'artifacts/local-ai/tvpl-mobile-238.json'
TARGET = ROOT / 'content-bank/legal/238-2026-source-reviewed.json'
OFFICIAL_SHA256 = 'e103437f9b4489db2b55ea005365c430c9b2711f5ae4bf2bab5c87de6f6c479a'
PUBLIC_SHA256 = '54166b789bd56900d929df6a3ddb5716eec0c23f92555ff5034312d36ca8c2b3'


class VisibleText(HTMLParser):
    def __init__(self):
        super().__init__()
        self.parts = []

    def handle_data(self, data):
        self.parts.append(data)


def normalized(text):
    return re.sub(r'\s+', '', unicodedata.normalize('NFC', text)).replace('“', '"').replace('”', '"')


def prepare():
    official_bytes, public_bytes = OFFICIAL.read_bytes(), PUBLIC.read_bytes()
    if hashlib.sha256(official_bytes).hexdigest() != OFFICIAL_SHA256 or \
            hashlib.sha256(public_bytes).hexdigest() != PUBLIC_SHA256:
        raise ValueError('Reviewed official or public source changed')
    with zipfile.ZipFile(OFFICIAL) as archive:
        root = ET.fromstring(archive.read('word/document.xml'))
    namespace = '{http://schemas.openxmlformats.org/wordprocessingml/2006/main}'
    lines = [''.join(node.text or '' for node in paragraph.iter(namespace + 't')).strip()
             for paragraph in root.iter(namespace + 'p')]
    lines = [line for line in lines if line]
    start = next(i for i, line in enumerate(lines) if line.startswith('Điều 1. Sửa đổi'))
    end = next(i for i, line in enumerate(lines[start:], start) if line == 'TM. CHÍNH PHỦ')
    selected = lines[start:end]
    articles = [int(match[1]) for line in selected if (match := re.match(r'^Điều (\d+)\.\s', line))]
    if articles != list(range(1, 22)):
        raise ValueError(f'Unexpected amendment articles: {articles}')
    content = '\n'.join(selected)

    reader = VisibleText()
    reader.feed(json.loads(public_bytes)['ContentVN'])
    public = re.sub(r'\s+', ' ', html.unescape(' '.join(reader.parts)))
    public = public[public.index('Điều 1. Sửa đổi'):public.index('Nơi nhận:')]
    if normalized(content) != normalized(public):
        raise ValueError('Official Gazette DOCX and public TVPL reader differ')

    data = {
        'reviewStatus': 'SourceVerifiedPendingEffectiveConsolidation',
        'isActive': False,
        'documentNumber': '238/2026/NĐ-CP',
        'documentTitle': 'Nghị định 238/2026/NĐ-CP sửa đổi Nghị định 168/2024/NĐ-CP',
        'sourceUrl': 'https://thuvienphapluat.vn/van-ban/Vi-pham-hanh-chinh/Nghi-dinh-238-2026-ND-CP-sua-doi-Nghi-dinh-168-2024-ND-CP-xu-phat-hanh-chinh-giao-thong-duong-bo-712521.aspx',
        'officialSourceUrl': 'https://datafiles.chinhphu.vn/cpp/files/vbpq/2026/7/238-ndcp.signed.pdf',
        'officialGazettePageUrl': 'https://congbao.chinhphu.vn/van-ban/nghi-dinh-so-238-2026-nd-cp-469913.htm',
        'officialGazetteDocxSha256': OFFICIAL_SHA256,
        'publicReaderApiUrl': 'https://apimobile.thuvienphapluat.vn/Document/GetDocumentDetail?LawID=712521&language=&token=',
        'publicReaderApiSha256': PUBLIC_SHA256,
        'articles': [str(n) for n in articles],
        'content': content,
        'contentSha256': hashlib.sha256(content.encode('utf8')).hexdigest(),
        'comparison': {'normalizedCharacters': len(normalized(content)), 'differences': 0,
                       'normalization': 'Unicode NFC, whitespace removed, curly quotes canonicalized'},
        'effectiveFromUtc': '2026-08-14T17:00:00Z',
        'laterClauseEffectiveDates': {'Article 18 adds Article 53 clause 3': '2028-01-01',
                                      'Article 18 adds Article 53 clause 4': '2029-01-01'},
        'reviewNotes': 'Nguồn NĐ 238 đã khớp toàn văn Điều 1–21 với DOCX Công báo. Chưa hợp nhất từng sửa đổi/bãi bỏ vào NĐ 168, chưa kiểm tra hiệu lực từng chế tài; không nhập hoặc kích hoạt cho RAG hiện hành.'
    }
    encoded = (json.dumps(data, ensure_ascii=False, indent=2) + '\n').encode('utf8')
    if TARGET.exists() and TARGET.read_bytes() != encoded:
        raise ValueError('Immutable reviewed package differs')
    if not TARGET.exists():
        TARGET.write_bytes(encoded)
    print(json.dumps({'articles': len(articles), 'normalizedCharacters': len(normalized(content)),
                      'differences': 0, 'contentSha256': data['contentSha256'], 'active': False}))


if __name__ == '__main__':
    prepare()
