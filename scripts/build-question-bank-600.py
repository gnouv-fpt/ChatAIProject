"""Extract the pinned 2025 source PDF; never author or regenerate animation scenes.

Requires PyMuPDF (the existing local PDF tooling directory is also supported).
Outputs immutable source evidence, original image bytes and a local practice package.
"""
import argparse
import hashlib
import importlib.util
import json
import re
import sys
import tempfile
import unicodedata
import uuid
from pathlib import Path

sys.path.insert(0, str(Path(tempfile.gettempdir()) / 'prn_pdf_tools'))
import pymupdf as fitz

ROOT = Path(__file__).resolve().parents[1]
SOURCE = 'https://khodulieu.sohoa.tuyenquang.gov.vn/congthongtin/media/edb12a6ad8ecfde537ec02cbb7e2a1b1.pdf'
SOURCE_SHA = 'd473be679b53458a33acc52057f3a4fe532ea489e91d88fb86789073cd98a9c5'
GUIDE = 'https://cdn.thuvienphapluat.vn/uploads/DanLuat-BanAn/2025/5/huong-dan-so-2262-csgt-p5.pdf'
GUIDE_SHA = 'dcb0b42473a23af3b006ed07cfd3a728254eb3d5263f6a26d0536c576d69e634'
CHAPTERS = [(1, 180, 'Quy định chung và quy tắc giao thông đường bộ', 'RULES'),
            (181, 205, 'Văn hóa giao thông, đạo đức, phòng cháy và cứu nạn', 'CULTURE'),
            (206, 263, 'Kỹ thuật lái xe', 'DRIVING'),
            (264, 300, 'Cấu tạo và sửa chữa', 'MECHANICS'),
            (301, 485, 'Báo hiệu đường bộ', 'SIGN'),
            (486, 600, 'Sa hình', 'SCENARIO')]


def clean(text):
    return re.sub(r'\s+', ' ', unicodedata.normalize('NFC', text)).strip()


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_once(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and path.read_bytes() != data:
        raise ValueError(f'Không ghi đè dữ liệu khác nội dung: {path}')
    if not path.exists():
        path.write_bytes(data)


def write_json(path, value):
    write_once(path, (json.dumps(value, ensure_ascii=False, indent=2) + '\n').encode('utf-8'))


def critical_numbers(guide):
    if sha(guide) != GUIDE_SHA:
        raise ValueError('Công văn không khớp SHA-256 đã đối chiếu.')
    with fitz.open(guide) as doc:
        text = doc[-1].get_text()
    if 'PHỤ LỤC 3' not in text:
        raise ValueError('Thiếu Phụ lục 3.')
    numbers = [int(line.strip()) for line in text.splitlines() if line.strip().isdigit()]
    if len(numbers) != 60 or len(set(numbers)) != 60 or min(numbers) != 19 or max(numbers) != 260:
        raise ValueError('Danh sách 60 câu không đầy đủ hoặc trùng.')
    return numbers


def extract(pdf, asset_dir, write_assets=True):
    if sha(pdf) != SOURCE_SHA:
        raise ValueError('PDF không khớp nguồn 186 trang đã đối chiếu; không nhập bản redirect/HTML hay bộ năm khác.')
    doc = fitz.open(pdf)
    if len(doc) != 186:
        raise ValueError('Nguồn phải có 186 trang.')
    pages, starts = [], []
    for p, page in enumerate(doc):
        lines = []
        for block in page.get_text('rawdict')['blocks']:
            if block['type'] != 0:
                continue
            for line in block['lines']:
                chars = [c for s in line['spans'] for c in s['chars']]
                raw = ''.join(c['c'] for c in chars)
                # Keep each printed option's own bbox: some pages print options in columns,
                # or three options in a single PDF text span. A whole-line bbox gives wrong keys.
                cuts = [0] + [m.end() for m in re.finditer(r'\s{3,}(?=[1-4]\.\s)', raw)] + [len(raw)]
                for left, right in zip(cuts, cuts[1:]):
                    segment = chars[left:right]
                    text = clean(raw[left:right])
                    if not text:
                        continue
                    visible = [c for c in segment if not c['c'].isspace()]
                    bbox = [min(c['bbox'][0] for c in visible), min(c['bbox'][1] for c in visible),
                            max(c['bbox'][2] for c in visible), max(c['bbox'][3] for c in visible)]
                    item = {'text': text, 'bbox': bbox, 'baseline': line['spans'][0]['origin'][1]}
                    lines.append(item)
                    match = re.match(r'^Câu\s+(\d+)\s*[.:]', text)
                    if match:
                        starts.append({'number': int(match[1]), 'page': p, 'y': bbox[1]})
        pages.append({'lines': sorted(lines, key=lambda l: (l['bbox'][1], l['bbox'][0])),
                      'images': page.get_image_info(xrefs=True), 'drawings': page.get_drawings()})
    if [q['number'] for q in starts] != list(range(1, 601)):
        raise ValueError('Số câu nguồn không liên tục 1–600 hoặc có câu trùng.')
    questions, warnings = [], []
    for i, start in enumerate(starts):
        n = start['number']
        end = starts[i+1] if i+1 < len(starts) else {'page': len(doc)-1, 'y': doc[-1].rect.height-35}
        lines, images, underlines, regions = [], [], [], []
        for p in range(start['page'], end['page']+1):
            top = start['y']-1 if p == start['page'] else 40
            bottom = end['y']-3 if p == end['page'] else doc[p].rect.height-40
            if bottom <= top:
                continue
            # Chapter headings immediately before the next question are not part of an option.
            selected = [l for l in pages[p]['lines'] if top <= l['bbox'][1] < bottom]
            heading = next((l['bbox'][1] for l in selected if l['text'].startswith('CHƯƠNG ')), None)
            if heading is not None:
                bottom = heading-1
            regions.append({'pdfPage': p+1, 'bbox': [76, top, 552, bottom]})
            lines.extend({**l, 'page': p} for l in selected
                         if l['bbox'][1] < bottom and not re.fullmatch(r'\d+', l['text']))
            images.extend({**img, 'page': p} for img in pages[p]['images'] if top <= img['bbox'][1] < bottom)
            for drawing in pages[p]['drawings']:
                rect = drawing['rect']
                if top <= rect.y0 < bottom and rect.height < 2 and rect.width > 10:
                    underlines.append({'page': p, 'rect': list(rect)})
        prompt, options, current, key_evidence = [], [], None, []
        for line in lines:
            text = re.sub(r'^Câu\s+\d+\s*[.:]\s*', '', line['text'])
            match = re.match(r'^([1-4])\.\s*(.*)', text)
            if match:
                current = {'id': int(match[1]), 'text': match[2], 'underlined': False}
                options.append(current)
            elif current:
                current['text'] = clean(current['text']+' '+text)
            else:
                prompt.append(text)
            if current:
                for underline in underlines:
                    x0, y0, x1, _ = underline['rect']
                    if (underline['page'] == line['page'] and -.7 <= y0-line['baseline'] <= 3.3
                            and min(x1, line['bbox'][2])-max(x0, line['bbox'][0]) > 10):
                        current['underlined'] = True
                        key_evidence.append({'optionId': current['id'], 'pdfPage': line['page']+1,
                                             'line': line['text'], 'underline': underline['rect']})
        entries = []
        for index, img in enumerate(images, 1):
            data = doc.extract_image(img['xref'])
            relative = f'question-bank-600/{n}/image-{index}.{data["ext"]}'
            if n < 486 and write_assets:
                write_once(asset_dir / str(n) / f'image-{index}.{data["ext"]}', data['image'])
            entries.append({'sha256': hashlib.sha256(data['image']).hexdigest(), 'url': relative,
                            'pdfPage': img['page']+1, 'pdfBBox': list(img['bbox']),
                            'width': img['width'], 'height': img['height']})
        options.sort(key=lambda o: o['id'])
        keys = [o['id'] for o in options if o['underlined']]
        if (len(keys) != 1 or not 2 <= len(options) <= 4
                or [o['id'] for o in options] != list(range(1, len(options)+1))
                or not all(o['text'] for o in options) or not prompt or (n >= 301 and not images)):
            warnings.append({'number': n, 'keys': keys, 'options': len(options), 'images': len(images)})
        questions.append({'number': n, 'prompt': clean(' '.join(prompt)), 'options': options,
                          'correctOptionIds': keys, 'images': entries, 'pdfPage': start['page']+1,
                          'regions': regions, 'answerEvidence': key_evidence})
    doc.close()
    return questions, warnings


def load_accepted():
    spec = importlib.util.spec_from_file_location('accepted_learning', ROOT / 'scripts/build-local-learning-bank.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.build('http://localhost:8765')


def validate_source(manifest):
    questions = manifest['questions']
    if manifest['sourceSha256'] != SOURCE_SHA or manifest['guideSha256'] != GUIDE_SHA or manifest['warnings']:
        raise ValueError('Nguồn chưa đạt kiểm tra trích xuất.')
    if [q['number'] for q in questions] != list(range(1, 601)):
        raise ValueError('Thiếu/trùng số câu 1–600.')
    seen = {}
    for q in questions:
        n = q['number']
        if (len(q['correctOptionIds']) != 1 or q['correctOptionIds'][0] not in [o['id'] for o in q['options']]
                or not 2 <= len(q['options']) <= 4 or not q['answerEvidence']):
            raise ValueError(f'Câu {n}: thiếu đáp án/phương án hoặc bằng chứng gạch chân.')
        if n >= 301 and not q['images']:
            raise ValueError(f'Câu {n}: thiếu ảnh nguồn.')
        fingerprint = json.dumps([q['prompt'], q['options'], [a['sha256'] for a in q['images']]], sort_keys=True)
        if fingerprint in seen:
            raise ValueError(f'Câu trùng nội dung/phương án/ảnh: {seen[fingerprint]} và {n}.')
        seen[fingerprint] = n
        for a in q['images']:
            relative = a['url'] if n < 486 else a['url'].replace('question-bank-600/', 'bank-review/', 1)
            path = ROOT / 'content-animations' / relative
            if not path.resolve().is_relative_to((ROOT / 'content-animations').resolve()) or sha(path) != a['sha256']:
                raise ValueError(f'Câu {n}: thiếu ảnh hoặc SHA không khớp.')
    old = json.loads((ROOT / 'content-animations/bank-review/bank.json').read_text(encoding='utf-8'))
    if old['sourceSha256'] != SOURCE_SHA:
        raise ValueError('115 câu đã duyệt không cùng nguồn.')
    for actual, expected in zip(questions[485:], old['questions']):
        for key in ('number', 'prompt', 'options', 'correctOptionIds', 'pdfPage'):
            if actual[key] != expected[key]:
                raise ValueError(f'Câu {actual["number"]}: lệch {key} so với bản đã duyệt.')
        if [a['sha256'] for a in actual['images']] != [a['sha256'] for a in expected['images']]:
            raise ValueError(f'Câu {actual["number"]}: ảnh khác bản đã duyệt.')


def build_package(manifest):
    validate_source(manifest)
    accepted = load_accepted()  # checks accepted feedback, scenes, revisions and all 115 assets
    identity = json.dumps([manifest, accepted['bank'], 'practice-30-30-80pct-B-structure-v1'],
                          ensure_ascii=False, sort_keys=True)
    bank_id = uuid.uuid5(uuid.NAMESPACE_URL, 'chataiweb/csgt-600-2025/' + hashlib.sha256(identity.encode()).hexdigest())
    questions = []
    for q in manifest['questions']:
        n = q['number']
        _, _, topic, kind = next(ch for ch in CHAPTERS if ch[0] <= n <= ch[1])
        if n >= 486:
            question = dict(accepted['bank']['questions'][n-486])
        else:
            correct = next(o for o in q['options'] if o['id'] == q['correctOptionIds'][0])
            question = {'number': n, 'topic': topic, 'categoryType': kind, 'text': q['prompt'],
                        'explanation': f"Đáp án {correct['id']}: {correct['text']}\n"
                            f"Theo phương án gạch chân trong PDF Cục CSGT 2025, trang PDF {q['pdfPage']}. "
                            'Không bổ sung diễn giải hay căn cứ điều luật ngoài tài liệu nguồn.',
                        'sourceUrl': SOURCE + f"#page={q['pdfPage']}", 'allowOptionShuffle': False,
                        'options': [{'id': str(o['id']), 'text': o['text']} for o in q['options']],
                        'correctOptionIds': [str(q['correctOptionIds'][0])], 'explanationAnimationUrl': None,
                        'assets': [{'id': f'original-{i}', 'url': 'http://localhost:8765/' + a['url'],
                                    'sha256': a['sha256'], 'mimeType': 'image/jpeg' if a['url'].endswith('.jpeg') else 'image/png',
                                    'altText': f'Ảnh nguyên bản từ PDF câu {n}, hình {i}'}
                                   for i, a in enumerate(q['images'], 1)]}
        question['isCritical'] = n in manifest['criticalNumbers']
        question['id'] = str(uuid.uuid5(bank_id, json.dumps(question, sort_keys=True, ensure_ascii=False)))
        questions.append(question)
    bank = {'id': str(bank_id), 'version': '1', 'title': '600 câu CSGT 2025 · luyện tập local',
            'sourceUrl': SOURCE, 'sourceDescription': 'Đủ câu 1–600 từ PDF Cục CSGT 2025; đáp án gạch chân, ảnh nguyên bản. '
                'Mã nguồn: CSGT-600-2025-CV2262; bản import 1. Câu điểm liệt theo Phụ lục 3 CV2262. '
                'Luyện tập: mục tiêu 80%, 30 câu/30 phút; không áp rớt điểm liệt, không phải ngưỡng thi GPLX chính thức. '
                'Chỉ 486–600 có mô phỏng đã duyệt. SHA-256 PDF: ' + SOURCE_SHA,
            'profile': {'id': 'csgt-600-2025-practice', 'version': '1', 'sourceUrl': GUIDE,
                        'questionCount': 30, 'durationSeconds': 1800, 'passCount': 24, 'failOnCriticalWrong': False},
            'questions': questions}
    # CV2262 section II.1: B structure = 8 rules + 1 critical + 1 culture +
    # 1 driving + 1 mechanics + 9 signs + 9 scenarios. Exclude critical items from
    # ordinary pools so each sample has exactly one, even if drawn from another chapter.
    templates = []
    for index in range(6):
        selected = []
        for kind, count in [('RULES', 8), ('CRITICAL', 1), ('CULTURE', 1), ('DRIVING', 1),
                            ('MECHANICS', 1), ('SIGN', 9), ('SCENARIO', 9)]:
            pool = [q for q in questions if q['isCritical']] if kind == 'CRITICAL' else [
                q for q in questions if q['categoryType'] == kind and not q['isCritical']]
            selected.extend(pool[(index*count+j) % len(pool)] for j in range(count))
        templates.append({'examCode': f'local-600-{str(bank_id)[:8]}-B-{index+1:02}', 'version': 1,
                          'title': f'Luyện tập {index+1:02} · cấu trúc B CV2262/2025 · mục tiêu 80%',
                          'durationMinutes': 30, 'passingScore': 24, 'questionIds': [q['id'] for q in selected]})
    result = {'bank': bank, 'templates': templates, 'evidence': {
        'localOnly': True, 'sourceEdition': 'CSGT-600-2025-CV2262', 'sourcePdfSha256': SOURCE_SHA,
        'guideSha256': GUIDE_SHA, 'sourceManifestSha256': hashlib.sha256(json.dumps(manifest, sort_keys=True, ensure_ascii=False).encode()).hexdigest(),
        'preservedBankId': accepted['bank']['id'], 'scenesSha256': accepted['evidence']['scenesSha256'],
        'questionCount': 600, 'newSourceQuestions': 485, 'criticalCount': 60,
        'animationCount': 115, 'practiceOnly': True, 'officialPassingThresholdConfigured': False}}
    validate_package(result)
    return result


def validate_package(package):
    qs = package['bank']['questions']
    if [q['number'] for q in qs] != list(range(1, 601)) or len({q['id'] for q in qs}) != 600:
        raise ValueError('Package thiếu/trùng câu hoặc ID.')
    for q in qs:
        expected = f"http://localhost:8765/q{q['number']}.html" if q['number'] >= 486 else None
        if q['explanationAnimationUrl'] != expected:
            raise ValueError(f"Câu {q['number']}: mô phỏng liên kết sai.")
        if expected and f'data-question="{q["number"]}"' not in (ROOT / f'content-animations/q{q["number"]}.html').read_text(encoding='utf-8'):
            raise ValueError('HTML learner không đúng số câu.')
        for a in q['assets']:
            suffix = Path(a['url']).suffix.lower()
            if suffix not in ('.jpeg', '.jpg', '.png'):
                raise ValueError('Định dạng ảnh chưa được kiểm tra.')
    lookup = {q['id']: q for q in qs}
    for t in package['templates']:
        selected = [lookup[qid] for qid in t['questionIds']]
        counts = {kind: sum(q['categoryType'] == kind and not q['isCritical'] for q in selected)
                  for _, _, _, kind in CHAPTERS}
        if (len(selected) != 30 or len(set(t['questionIds'])) != 30 or sum(q['isCritical'] for q in selected) != 1
                or counts != {'RULES': 8, 'CULTURE': 1, 'DRIVING': 1, 'MECHANICS': 1, 'SIGN': 9, 'SCENARIO': 9}):
            raise ValueError('Đề mẫu không khớp cấu trúc B CV2262.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--pdf', required=True, type=Path)
    parser.add_argument('--guide', required=True, type=Path)
    parser.add_argument('--output-dir', required=True, type=Path)
    args = parser.parse_args()
    questions, warnings = extract(args.pdf, ROOT / 'content-animations/question-bank-600')
    manifest = {'sourceUrl': SOURCE, 'sourceSha256': SOURCE_SHA, 'guideUrl': GUIDE,
                'guideSha256': GUIDE_SHA, 'criticalNumbers': critical_numbers(args.guide),
                'questions': questions, 'warnings': warnings}
    write_json(args.output_dir / 'source-extraction.json', manifest)
    if not warnings:
        package = build_package(manifest)
        write_json(args.output_dir / 'package.json', package)
        print(f"Bank {package['bank']['id']}: 600 questions, 6 practice templates, 115 existing animations.")
    print(json.dumps({'questions': len(questions), 'warnings': warnings}, ensure_ascii=False))


if __name__ == '__main__':
    main()
