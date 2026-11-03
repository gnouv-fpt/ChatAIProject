"""Prepare a contiguous extension of the reviewed 55/VBHN-VPQH corpus.

Uses only existing public TVPL reader captures and compares every selected
article with the signed Government PDF. It does not import or activate data.
"""
import hashlib
import json
import re
import sys
import tempfile
import unicodedata
from pathlib import Path

sys.path.insert(0, str(Path(tempfile.gettempdir()) / "prn_pdf_tools"))
import pymupdf

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / "artifacts/local-ai"
CAPTURES = ROOT / "content-bank/legal"
SIGNED_PDF = CAPTURES / "55-vbhn-vpqh-signed.pdf"
CAPTURE_NAMES = ("source-web-136.txt", "source-web-196.txt",
                 "source-web-256.txt", "source-web-96.txt")
FIRST, LAST = 34, 49


def norm(text):
    return re.sub(r"\s+", "", unicodedata.normalize("NFC", text))


def article_sections(text):
    sections = re.split(r"(?=Điều\s+\d+\.\s)", text)
    found = {}
    for section in sections:
        match = re.match(r"Điều\s+(\d+)\.\s", section)
        if match:
            number = int(match.group(1))
            if number in found:
                raise ValueError(f"Duplicate article boundary: {number}")
            found[number] = section.strip()
    return found


def prepare():
    lines, capture_hashes = {}, {}
    for name in CAPTURE_NAMES:
        path = CAPTURES / name
        capture_hashes[path.name] = hashlib.sha256(path.read_bytes()).hexdigest()
        for line in path.read_text(encoding="utf8").splitlines():
            match = re.match(r"L(\d+): (.*)", line)
            if not match:
                continue
            number, content = int(match.group(1)), match.group(2)
            if number in lines and lines[number] != content:
                raise ValueError(f"Public source changed at captured line {number}; re-review required")
            lines[number] = content
    supplement = ROOT / "content-bank/legal/55-2026-articles-34-49-source-supplement.txt"
    capture_hashes[supplement.name] = hashlib.sha256(supplement.read_bytes()).hexdigest()
    supplement_parts = dict(line.split(": ", 1) for line in supplement.read_text(encoding="utf8").splitlines())
    if set(supplement_parts) != {"A35-tail", "A36-start"}:
        raise ValueError("Public-source supplement must contain only the reviewed Article 35 tail and Article 36 start")

    # Captures skip three page-reader lines between articles 35 and 36. Their
    # reviewed public text is supplied separately; article 50 starts at L296
    # and is deliberately excluded because its body is incomplete.
    if any(n not in lines for n in range(227, 234)) or any(n not in lines for n in range(237, 296)):
        raise ValueError("Missing public-source capture lines for reviewed scope 34–49")
    public_text = " ".join([lines[n] for n in range(227, 234)])
    public_text = re.sub(r"\s+4\.\s*$", "", public_text)
    public_text += " " + supplement_parts["A35-tail"] + " Điều 36. Biển số xe " + supplement_parts["A36-start"]
    public_text += " " + " ".join(lines[n] for n in range(237, 296))
    public_text = re.sub(r"【[^】]+】", "", public_text)
    public_sections = article_sections(public_text)
    selected = {n: public_sections[n] for n in range(FIRST, LAST + 1) if n in public_sections}
    if sorted(selected) != list(range(FIRST, LAST + 1)):
        raise ValueError("Public source does not contain every article 34–49 in order")

    with pymupdf.open(SIGNED_PDF) as pdf:
        official_text = " ".join(
            span["text"]
            for page in pdf
            for block in page.get_text("dict")["blocks"]
            if "lines" in block
            for line in block["lines"]
            for span in line["spans"]
            if round(span["size"], 1) == 14.0
        )
    official_sections = article_sections(official_text)
    # PDF extraction omits the superscript glyph in this one body-font size
    # span. The visible signed PDF was checked for this specific symbol.
    reviewed_official = dict(official_sections)
    reviewed_official[34] = reviewed_official[34].replace("50 cm ", "50 cm 3")
    mismatch = [n for n in selected if n not in reviewed_official or norm(selected[n]) != norm(reviewed_official[n])]
    if mismatch:
        (WORK / "extension-comparison-details.json").write_text(
            json.dumps({str(n): {"tvpl": selected[n], "officialPdf": official_sections.get(n, "")} for n in mismatch},
                       ensure_ascii=False, indent=2), encoding="utf8")
        raise ValueError(f"Public/official article differences require visual review: {mismatch}")

    formatted = []
    for content in selected.values():
        # Preserve the exponent lost by the PDF text extractor / plain-text capture.
        content = content.replace("50 cm 3", "50 cm³")
        content = re.sub(r"(?<!Điều )(?<!\d)(\d{1,2}\.\s)", r"\n\1", content)
        content = re.sub(r"\s+([a-zđ]\)\s)", r"\n\1", content)
        formatted.append(content.strip())
    content = "\n".join(formatted)
    content_hash = hashlib.sha256(content.encode("utf8")).hexdigest()
    pdf_hash = hashlib.sha256(SIGNED_PDF.read_bytes()).hexdigest()
    manifest = {
        "documentNumber": "55/VBHN-VPQH",
        "documentTitle": "Luật Trật tự, an toàn giao thông đường bộ · VBHN 55/2026 · trích Điều 34–49",
        "sourceUrl": "https://thuvienphapluat.vn/van-ban/Giao-thong-Van-tai/Van-ban-hop-nhat-55-VBHN-VPQH-2026-Luat-Trat-tu-an-toan-giao-thong-duong-bo-698683.aspx",
        "officialSourceUrl": "https://datafiles.chinhphu.vn/cpp/files/vbpq/2026/3/55-vbhn-vpqh.pdf",
        "captureMethod": "existing public-web-reader captures plus targeted public web-reader retrieval for the capture gap; local crawler returned HTTP 403",
        "articles": [str(n) for n in selected],
        "content": content,
        "contentSha256": content_hash,
        "evidence": {
            "capturedArticles": len(selected),
            "captureLineStart": 227,
            "captureLineEnd": 295,
            "officialPdfSha256": pdf_hash,
            "articlesRequiringReview": [],
            "visuallyReviewedPdfDifference": {"article": 34, "clause": 1, "point": "g", "difference": "TVPL shows 50 cm³; PDF text extraction omits superscript 3, confirmed in visible signed PDF."},
            "captureHashes": capture_hashes,
        },
        "effectiveFromUtc": "2026-06-30T17:00:00Z",
        "reviewNotes": "Đối chiếu nguyên văn Điều 34–49 giữa nội dung công khai TVPL đã thu nhận và PDF ký số trên Cổng TTĐT Chính phủ; các điều khoản sửa đổi có hiệu lực từ 01/07/2026 được lấy theo VBHN 55/2026. Điều 50 bị loại vì capture hiện có kết thúc giữa phần mở đầu Điều này. Đây là gói mở rộng chờ importer hỗ trợ edition/phạm vi bổ sung an toàn; chưa import hoặc kích hoạt.",
    }
    target = ROOT / "content-bank/legal/55-2026-articles-34-49-review.json"
    data = (json.dumps(manifest, ensure_ascii=False, indent=2) + "\n").encode("utf8")
    if target.exists() and target.read_bytes() != data:
        raise ValueError("Existing reviewed extension differs; do not overwrite")
    if not target.exists():
        target.write_bytes(data)
    print(f"Prepared {len(selected)} articles; TVPL/public text matches the signed Government PDF.")
    print(f"Package: {target}")
    print(f"Content SHA-256: {content_hash}")


if __name__ == "__main__":
    prepare()
