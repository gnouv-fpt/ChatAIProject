"""Create/verify an immutable HTTPS edition for the LOCAL learning stack.

Reads the pinned, verified 600-question package; never writes animation assets.
"""
import argparse
import copy
import hashlib
import importlib.util
import json
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ORIGIN = 'https://content-animations.vercel.app'
LOCAL = 'http://localhost:8765'
OUTPUT = ROOT / 'content-bank/csgt-2025-https/package.json'


def derive(source):
    package = copy.deepcopy(source)
    bank = package['bank']
    # Bind the new namespace to every source field and the hosting origin.
    identity = json.dumps([source, ORIGIN, 'https-assets-edition-v1'], sort_keys=True, ensure_ascii=False)
    bank_id = uuid.uuid5(uuid.NAMESPACE_URL, 'chataiweb/csgt-600-https/' + hashlib.sha256(identity.encode()).hexdigest())
    bank['id'] = str(bank_id)
    bank['title'] = '600 câu CSGT 2025 · luyện tập local · ảnh/mô phỏng HTTPS'
    bank['sourceDescription'] += ' Bản tài nguyên HTTPS v1; giữ nguyên nguồn, đáp án và chính sách luyện tập.'
    mapping = {}
    for question in bank['questions']:
        old_id = question.pop('id')
        urls = question['assets'] + ([{'url': question['explanationAnimationUrl']}] if question['explanationAnimationUrl'] else [])
        for entry in urls:
            if not entry['url'].startswith(LOCAL + '/'):
                raise ValueError('Expected the verified local asset origin.')
            entry['url'] = ORIGIN + entry['url'][len(LOCAL):]
        if question['explanationAnimationUrl']:
            question['explanationAnimationUrl'] = urls[-1]['url']
        question['id'] = str(uuid.uuid5(bank_id, json.dumps(question, sort_keys=True, ensure_ascii=False)))
        mapping[old_id] = question['id']
    for index, template in enumerate(package['templates'], 1):
        template['examCode'] = f'local-600-https-{str(bank_id)[:8]}-B-{index:02}'
        template['title'] += ' · HTTPS'
        template['questionIds'] = [mapping[qid] for qid in template['questionIds']]
    package['evidence'].update(assetOrigin=ORIGIN, predecessorBankId=source['bank']['id'],
                               predecessorVersion=source['bank']['version'], assetEdition='https-v1')
    return package


def prepare(verify_only=False):
    spec = importlib.util.spec_from_file_location('verify600', ROOT / 'scripts/verify-question-bank-600.py')
    verifier = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(verifier)
    source = verifier.verify()
    package = derive(source)
    if verify_only:
        if json.loads(OUTPUT.read_text(encoding='utf8')) != package:
            raise ValueError('HTTPS package differs from the verified source and pinned transformation.')
    else:
        verifier.builder.write_json(OUTPUT, package)
    return package


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--verify', action='store_true')
    args = parser.parse_args()
    result = prepare(args.verify)
    print(f"Verified HTTPS bank {result['bank']['id']} / 1: 600 questions, 319 assets, 115 animation links.")
