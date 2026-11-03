"""Build immutable B theory mock-exam bank using verified, time-bounded official rules."""
import argparse
import copy
import hashlib
import importlib.util
import json
import uuid
from pathlib import Path
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parents[1]
PROFILE_ID = 'gplx-B-tt12-2025-until-2027-02-28'
SOURCES = {
    'tt12-2025.pdf': ('307f993f81e3949da59812a0cbabef58f6d1c4b62caecf8362b84c65ae949ed3',
        'https://datafiles.chinhphu.vn/cpp/files/vbpq/2025/3/15-bca.signed.pdf'),
    'tt108-2026.pdf': ('7f879c2404948203d693a0109b1f584a5484c1514b5c5ea6c6d4d7c956983c71',
        'https://datafiles.chinhphu.vn/cpp/files/vbpq/2026/7/thong-tu-so-108.2026.tt-bca-ngay-29.6.2026-ban-day-du-v03.pdf'),
}
OUTPUT = ROOT / 'content-bank/csgt-2025-B-current/package.json'


def derive(source):
    package = copy.deepcopy(source)
    identity = json.dumps([source, PROFILE_ID, SOURCES], sort_keys=True, ensure_ascii=False)
    bank_id = uuid.uuid5(uuid.NAMESPACE_URL, 'chataiweb/official-b/' + hashlib.sha256(identity.encode()).hexdigest())
    bank = package['bank']
    bank.update(id=str(bank_id), title='Thi thử hạng B · 30 câu / 20 phút · quy tắc đến 28/02/2027',
                sourceDescription='Thi thử lý thuyết hạng B theo Phụ lục IV.A TT12/2025/TT-BCA, '
                'tiếp tục áp dụng đến hết 28/02/2027 theo Điều 41 khoản 6 TT108/2026/TT-BCA. '
                '30 câu, 20 phút, đạt ít nhất 27/30 và không sai hoặc bỏ trống câu điểm liệt. '
                'Cấu trúc B và 60 câu điểm liệt theo CV2262/CSGT-P5, bộ 600 CSGT 2025. '
                'Đây là thi thử trên web local, không cấp kết quả sát hạch chính thức. Ảnh/mô phỏng HTTPS.')
    bank['profile'] = {'id': PROFILE_ID, 'version': '1', 'sourceUrl': SOURCES['tt12-2025.pdf'][1],
                       'questionCount': 30, 'durationSeconds': 1200, 'passCount': 27, 'failOnCriticalWrong': True}
    mapping = {}
    for question in bank['questions']:
        old_id = question.pop('id')
        question['id'] = str(uuid.uuid5(bank_id, json.dumps(question, sort_keys=True, ensure_ascii=False)))
        mapping[old_id] = question['id']
    for index, template in enumerate(package['templates'], 1):
        template.update(examCode=f'gplx-B-{str(bank_id)[:8]}-{index:02}',
                        title=f'Thi thử B-{index:02} · 30 câu / 20 phút · đạt 27, không sai điểm liệt',
                        durationMinutes=20, passingScore=27, questionIds=[mapping[qid] for qid in template['questionIds']])
    package['evidence'].update(predecessorBankId=source['bank']['id'], practiceOnly=False,
        mockExamOnly=True, officialPassingThresholdConfigured=True, licenseClass='B',
        effectiveFrom='2026-07-01T00:00:00+07:00', effectiveUntilExclusive='2027-03-01T00:00:00+07:00',
        rulesSources={key: {'sha256': digest, 'url': url} for key, (digest, url) in SOURCES.items()},
        reviewedPdfPages={'tt12-2025.pdf': [47, 48], 'tt108-2026.pdf': [36, 37]})
    return package


def prepare(verify_only=False):
    spec = importlib.util.spec_from_file_location('https_bank', ROOT / 'scripts/prepare-question-bank-https.py')
    builder = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(builder)
    source_dir = ROOT / 'artifacts/official-profile'
    source_dir.mkdir(parents=True, exist_ok=True)
    for filename, (digest, url) in SOURCES.items():
        target = source_dir / filename
        if not target.exists():
            temporary = source_dir / (filename + '.download')
            if temporary.exists():
                raise ValueError(f'Unfinished source download requires inspection: {filename}')
            try:
                with urlopen(url, timeout=180) as response, temporary.open('xb') as output:
                    while block := response.read(1024 * 1024):
                        output.write(block)
                if hashlib.sha256(temporary.read_bytes()).hexdigest() != digest:
                    raise ValueError(f'Official source download hash differs: {filename}')
                temporary.replace(target)
            finally:
                if temporary.exists():
                    temporary.unlink()
        if hashlib.sha256(target.read_bytes()).hexdigest() != digest:
            raise ValueError('Official source PDF differs from the reviewed signed copy.')
    package = derive(builder.prepare(True))
    if verify_only:
        if json.loads(OUTPUT.read_text(encoding='utf8')) != package:
            raise ValueError('Official B package differs from reviewed source/rules.')
    else:
        OUTPUT.parent.mkdir(parents=True, exist_ok=True)
        data = (json.dumps(package, ensure_ascii=False, indent=2) + '\n').encode()
        if OUTPUT.exists() and OUTPUT.read_bytes() != data:
            raise ValueError('Refusing to overwrite a different immutable edition.')
        if not OUTPUT.exists(): OUTPUT.write_bytes(data)
    return package


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--verify', action='store_true')
    result = prepare(parser.parse_args().verify)
    print(f"Verified B bank {result['bank']['id']} / 1: 30 questions, 20 minutes, 27 correct, critical policy enabled.")
