"""Compare Gazette Word text with TVPL and stage the unamended 168 baseline."""
import hashlib
import html
import json
import re
import unicodedata
from html.parser import HTMLParser
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / 'artifacts/local-ai'
TARGET = ROOT / 'content-bank/legal/168-2024-source-reviewed.json'
SOURCES = {
    '168-congbao-part1.doc': 'd820247114d1578a376f1932fba877f9ea1a070d182e72bc4e71eae512aaf23a',
    '168-congbao-part2.doc': 'd5dc7fdb300a1d2bb2b51b5169792774387083075cfe80f8b8ca785683aadc75',
    '168-congbao-part1.txt': '8d7247b4a00b67776cbc7bc564d72a3a506f86a03692b8e5955645b46ab2ee9e',
    '168-congbao-part2.txt': '6d4143f43d3c48d1098d4a28b05acb24f74a76cc08ed0542d2fa20d187c21c6d',
    '168-tvpl-mobile.json': 'b81f124df71337ff85a178c191ac642f1f391929e494aff764c8af5d94a15217',
}


class VisibleText(HTMLParser):
    def __init__(self):
        super().__init__()
        self.parts = []

    def handle_data(self, data):
        self.parts.append(data)


def sections(text):
    matches = list(re.finditer(r'(?m)^[^\S\r\n]*Điều\s+(\d+)\.\s', text))
    result = {}
    for index, match in enumerate(matches):
        number = int(match.group(1))
        if number in result:
            raise ValueError(f'Duplicate article {number}')
        result[number] = text[match.start():matches[index + 1].start() if index + 1 < len(matches) else len(text)]
    return result


def normalized(text):
    text = unicodedata.normalize('NFC', text).replace('“', '"').replace('”', '"')
    # Gazette Word headings omit the dot after Mục; TVPL adds it.
    text = re.sub(r'\bMục\s+(\d+)\.', r'Mục\1', text)
    return re.sub(r'[\s\x07]+', '', text)


def prepare():
    for name, expected in SOURCES.items():
        if hashlib.sha256((ARTIFACTS / name).read_bytes()).hexdigest() != expected:
            raise ValueError(f'Reviewed source changed: {name}')

    part1 = (ARTIFACTS / '168-congbao-part1.txt').read_text(encoding='utf-8')
    part2 = (ARTIFACTS / '168-congbao-part2.txt').read_text(encoding='utf-8')
    official = sections(part1)
    continuation = part2.split('(Tiếp theo Công báo số 75 + 76)', 1)[1].split('Điều 40.', 1)[0]
    official[39] = official[39].split('(Xem tiếp Công báo', 1)[0] + continuation
    official.update(sections(part2))
    official[55] = official[55].split('TM. CHÍNH PHỦ', 1)[0]
    # Word stores this paragraph's "1." in ListFormat.ListString, outside Range.Text.
    marker = 'Các chức danh có thẩm quyền xử phạt vi phạm hành chính'
    if official[46].count(marker) != 1:
        raise ValueError('Article 46 numbering location changed')
    official[46] = official[46].replace(marker, '1. ' + marker, 1)

    reader = VisibleText()
    reader.feed(json.loads((ARTIFACTS / '168-tvpl-mobile.json').read_text(encoding='utf-8-sig'))['ContentVN'])
    public = sections(html.unescape(' '.join(reader.parts)))
    public[55] = public[55].split('Nơi nhận:', 1)[0]
    expected_articles = set(range(1, 56))
    if set(official) != expected_articles or set(public) != expected_articles:
        raise ValueError('Expected exactly Articles 1–55 in both sources')

    articles = []
    for number in range(1, 56):
        if normalized(official[number]) != normalized(public[number]):
            raise ValueError(f'Gazette Word and TVPL differ at Article {number}')
        content = re.sub(r'\s+', ' ', public[number]).strip()
        articles.append({'number': number, 'content': content,
                         'contentSha256': hashlib.sha256(content.encode('utf8')).hexdigest()})

    result = {
        'reviewStatus': 'SourceVerifiedPendingEffectiveConsolidation',
        'isActive': False,
        'documentNumber': '168/2024/NĐ-CP',
        'sourceUrl': 'https://thuvienphapluat.vn/van-ban/giao-thong-van-tai/Nghi-dinh-168-2024-ND-CP-xu-phat-vi-pham-hanh-chinh-an-toan-giao-thong-duong-bo-619502.aspx',
        'officialSourceUrl': 'https://vanban.chinhphu.vn/?classid=1&docid=212167&pageid=27160',
        'officialGazettePageUrl': 'https://congbao.chinhphu.vn/van-ban/nghi-dinh-so-168-2024-nd-cp-43733.htm',
        'officialGazetteDocSha256': [SOURCES['168-congbao-part1.doc'], SOURCES['168-congbao-part2.doc']],
        'publicReaderApiUrl': 'https://apimobile.thuvienphapluat.vn/Document/GetDocumentDetail?LawID=619502&language=&token=',
        'publicReaderApiSha256': SOURCES['168-tvpl-mobile.json'],
        'effectiveDate': '2025-01-01',
        'comparison': {'articles': 55, 'differences': 0,
                       'normalization': 'NFC, whitespace/Word cell marker removed, heading Mục punctuation normalized; Article 46 Word auto-number restored'},
        'articles': articles,
        'reviewNotes': 'Nội dung gốc khớp từng Điều 1–55 với bản Word Công báo. Đây là bản 168 trước các sửa đổi NĐ 238/2026; chưa hợp nhất sửa đổi/bãi bỏ, hiệu lực riêng hoặc chuyển tiếp; không nhập vào RAG hiện hành.'
    }
    encoded = (json.dumps(result, ensure_ascii=False, indent=2) + '\n').encode('utf8')
    if TARGET.exists() and TARGET.read_bytes() != encoded:
        raise ValueError('Immutable reviewed package differs')
    if not TARGET.exists():
        TARGET.write_bytes(encoded)
    print(json.dumps({'articles': len(articles), 'differences': 0, 'active': False,
                      'packageSha256': hashlib.sha256(encoded).hexdigest()}))


if __name__ == '__main__':
    prepare()
