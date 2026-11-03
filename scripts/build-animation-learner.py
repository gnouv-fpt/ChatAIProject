"""Generate stable question HTML paths without changing accepted scenes or renderers."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / 'content-animations'
template = (ROOT / 'learn.html').read_text(encoding='utf-8')
scenes = json.loads((ROOT / 'bank-review/scenes.json').read_text(encoding='utf-8'))['scenes']
accepted = json.loads((ROOT / 'bank-review/accepted-release.json').read_text(encoding='utf-8'))
for number, recipe in scenes.items():
    if accepted['approvedRevisions'].get(number) != recipe['revision']:
        raise SystemExit(f'Question {number} is not accepted at its current revision')
for number in sorted(scenes, key=int):
    page = template.replace('data-question="486"', f'data-question="{number}"')
    (ROOT / f'q{int(number)}.html').write_text(page, encoding='utf-8')
print(f'Generated {len(scenes)} learner URLs; scenes/renderers unchanged.')
