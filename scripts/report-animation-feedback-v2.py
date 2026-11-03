"""Bind the 01-Nov repair ledger to captured revisions, without approving scenes."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / 'output/animation-review'
BANK = ROOT / 'content-animations/bank-review'


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


feedback = read(BANK / 'review-feedback.json')
scenes = read(BANK / 'scenes.json')['scenes']
baseline = read(BANK / 'review-approved-2026-11-01.json')['scenes']
desktop = read(WORK / 'v2-full-desktop.json')
mobile = read(WORK / 'v2-full-mobile.json')
continuous = read(WORK / 'v2-continuous.json')
preserved = read(WORK / 'v2-approved-regression.json')
geometry = read(WORK / 'v2-geometry-final.json')
lock = read(BANK / 'review-approved-lock-2026-11-01.json')
for name, sha in lock['files'].items():
    assert hashlib.sha256((ROOT / 'content-animations' / name).read_bytes()).hexdigest() == sha, name
for capture in [desktop, mobile, continuous, preserved]:
    assert not capture['errors'], capture['errors']
    # Retain Chromium cancellation events in the ledger. The scene readiness
    # and completed playback checks are separate from transport event counts.
    assert all(r.get('error') == 'net::ERR_ABORTED' for r in capture['failures']), capture['failures']
    for record in capture['records']:
        assert record['revision'] == scenes[str(record['number'])]['revision'], record['number']
assert len(desktop['records']) == len(mobile['records']) == 71
assert len(preserved['records']) == 44 and all(r['legacy'] and r['profile'] == '1' for r in preserved['records'])
assert all(not r['issues'] for r in mobile['records'])
assert len(mobile['playback']) == 30 and all(r['distance'] > 0 for r in mobile['playback'])
assert len(continuous['records']) == 14 and all(r['finished'] and r['paused'] for r in continuous['records'])
assert not geometry['errors'] and not geometry['collisions']
dmap = {r['number']: r for r in desktop['records']}
mmap = {r['number']: r for r in mobile['records']}
cmap = {r['number']: r for r in continuous['records']}
order = {r['number']: i for i, r in enumerate(desktop['records'])}
records = []
for original in feedback['records']:
    n = original['number']
    scene = scenes[str(n)]
    approved = original['status'] == 'approved'
    if approved:
        assert scene == baseline[str(n)], n
    else:
        assert original['revision'] != scene['revision'], n
    evidence = None if approved else dict(
        desktopTimes=dmap[n]['times'], mobileTimes=mmap[n]['times'],
        mobileLayoutIssues=mmap[n]['issues'],
        overviewSheet=f'output/playwright/feedback-v2/overview-{order[n] // 6:02}.jpg',
        allStepSheet=f'output/playwright/feedback-v2/question-{n}.jpg',
        continuousPlayback=cmap.get(n),
    )
    records.append(dict(
        number=n, originalReview=original, candidateRevision=scene['revision'],
        status='approved-preserved' if approved else 'repaired-awaiting-user-review',
        userAccepted=approved, originalRecipePreserved=approved,
        rendererVersion=scene.get('rendererVersion', 1), physicalPov=bool(scene.get('worldScene')),
        candidateSteps=[s['text'] for s in scene['steps']],
        agentSampledVisualReview=not approved,
        visualReviewScope=None if approved else 'Source/start/first and last movement midpoint/end in overview sheets; selected full step sheets. Not every animation frame.',
        evidence=evidence,
    ))
summary = dict(
    scenes=len(scenes), steps=sum(len(s['steps']) for s in scenes.values()),
    approvedPreserved=44, repairedAwaitingUserReview=71,
    physicalPovScenes=len(geometry['worldScenes']), overviewGeometryScenes=len(geometry['overviewScenes']),
    desktopFrames=sum(len(r['times']) for r in desktop['records']),
    mobileFrames=sum(len(r['times']) for r in mobile['records']),
    mobileRealPlaybackScenes=len(mobile['playback']), continuousPlaybackScenes=len(continuous['records']),
    continuousFrames=sum(len(r['frames']) for r in continuous['records']),
    geometrySamplesPerStep=geometry['samplesPerStep'],
    sourceFeedbackSha256=hashlib.sha256((BANK / 'review-feedback.json').read_bytes()).hexdigest(),
    scenesSha256=hashlib.sha256((BANK / 'scenes.json').read_bytes()).hexdigest(),
    rendererRevisions=sorted({s['rendererRevision'] for s in scenes.values()}),
)
payload = dict(summary=summary, limitations=[
    '31 POV scenes use a reconstructed 3D environment, not pixel-matched buildings/materials from the source photographs.',
    'Geometry checks sample 41 fractions of each step; overview checks exclude vehicles wholly outside the viewport and intentional guard/barrier contact.',
    'Fourteen scenes were played continuously to completion; the other changed scenes have sampled captures and mobile playback checks where applicable.',
    'These are local technical checks, not user acceptance or independent legal validation of the question bank.',
], transportCancellations=dict(approved=preserved['failures'], continuous=continuous['failures']), records=records)
stem = WORK / 'feedback-repair-ledger-2026-11-01-v2'
stem.with_suffix('.json').write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding='utf8')
lines = [
    '# Sổ sửa theo JSON người dùng ngày 01/11 — lượt 2', '',
    'Giữ nguyên 44 câu đã duyệt. 71 bản sửa chờ người dùng xác nhận; không tự duyệt.', '',
    'Ảnh tổng quan đã mở xem đủ 71 câu ở các mốc lấy mẫu, không phải mọi khung chuyển động.', '',
    '| Câu | Trạng thái | Revision hiện tại | Ghi chú gốc | Bằng chứng |',
    '| --- | --- | --- | --- | --- |',
]
for r in records:
    note = r['originalReview']['notes'].replace('|', '/').replace('\n', '<br>')
    evidence = 'Giữ nguyên kịch bản đã duyệt' if r['userAccepted'] else r['evidence']['allStepSheet']
    lines.append(f"| {r['number']} | {r['status']} | `{r['candidateRevision']}` | {note} | {evidence} |")
stem.with_suffix('.md').write_text('\n'.join(lines) + '\n', encoding='utf8')
print(json.dumps(summary, ensure_ascii=True))
