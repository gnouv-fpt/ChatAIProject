"""Derive two reviewed sign fingerprints from page 80 of the official QCVN PDF."""
import hashlib
import json
import subprocess
import tempfile
from pathlib import Path
from urllib.request import urlopen

from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]
SOURCE = 'https://datafiles.chinhphu.vn/cpp/files/vbpq/2024/11/51-bgtvt-kem.pdf'
PDF_SHA256 = 'b6b99d0a0aeb13fe79072831857ece15bb254d8fb7817e80e4a2739a0d2145ce'
BOXES = {'P.101': (427, 548, 578, 693), 'P.102': (427, 915, 578, 1067)}


def visual_hash(image):
    values = ImageOps.grayscale(image).resize((32, 32)).tobytes()
    mean = sum(values) / len(values)
    return sum(1 << index for index, value in enumerate(values) if value >= mean)


def main():
    cache = ROOT / 'artifacts/local-ai/qcvn41-2024-official.pdf'
    if cache.exists():
        pdf = cache.read_bytes()
    else:
        with urlopen(SOURCE, timeout=90) as response:
            pdf = response.read()
    if hashlib.sha256(pdf).hexdigest() != PDF_SHA256:
        raise ValueError('Official QCVN source PDF changed')
    with tempfile.TemporaryDirectory() as directory:
        source = Path(directory) / 'source.pdf'
        rendered = Path(directory) / 'page.png'
        source.write_bytes(pdf)
        subprocess.run(['pdftoppm', '-f', '80', '-l', '80', '-png', '-r', '120',
                        '-singlefile', str(source), str(rendered.with_suffix(''))], check=True)
        with Image.open(rendered) as page:
            rows = [{'code': code, 'clause': 'B.' + str(index),
                     'visual_hash': f'{visual_hash(page.crop(box)):0256x}',
                     'crop120dpi': list(box)} for index, (code, box) in enumerate(BOXES.items(), start=1)]
    output = {'sourceUrl': SOURCE, 'officialPdfSha256': PDF_SHA256, 'pdfPage': 80,
              'hashSize': 32, 'signs': rows}
    path = ROOT / 'grpc_inference_service/qcvn_sign_fingerprints.json'
    path.write_text(json.dumps(output, ensure_ascii=False, indent=2) + '\n', encoding='utf8')
    print(f'Wrote {len(rows)} official sign fingerprints')


if __name__ == '__main__':
    main()
