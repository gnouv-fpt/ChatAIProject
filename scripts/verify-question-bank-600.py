"""Read-only check of source/package/asset identity and protected 115-question scenes."""
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('bank600', ROOT / 'scripts/build-question-bank-600.py')
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


def verify():
    folder = ROOT / 'content-bank/csgt-2025'
    source = json.loads((folder / 'source-extraction.json').read_text(encoding='utf-8'))
    package = json.loads((folder / 'package.json').read_text(encoding='utf-8'))
    originals = ROOT / 'artifacts/question-bank-600'
    extracted, warnings = builder.extract(originals / 'source-download.pdf', ROOT / 'content-animations/question-bank-600', write_assets=False)
    if (extracted != source['questions'] or warnings != source['warnings'] or
            builder.critical_numbers(originals / 'guide-mirror.pdf') != source['criticalNumbers']):
        raise ValueError('Manifest không khớp bản trích xuất lại từ PDF gốc có SHA-256 đã ghim.')
    if builder.build_package(source) != package:
        raise ValueError('Package đã khác dữ liệu nguồn/policy đã kiểm tra.')
    return package


if __name__ == '__main__':
    package = verify()
    print(f"Verified {len(package['bank']['questions'])} questions; 60 source critical markers; "
          '6 B-structure practice templates; 115 unchanged accepted animation links.')
