"""Record the second 01-Nov user review and bind evidence to each revision."""
import hashlib
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
BANK=ROOT/'content-animations/bank-review'
WORK=ROOT/'output/animation-review'
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
scenes=read(BANK/'scenes.json')['scenes']
before=read(BANK/'review-baseline-v3.json')['scenes']
feedback=read(BANK/'review-feedback-v3-input.json')
desktop=read(WORK/'v3-desktop-final.json')
mobile=read(WORK/'v3-mobile-final.json')
continuous=read(WORK/'v3-continuous.json')
transitions=read(WORK/'v3-renderer-transitions.json')
geometry=read(WORK/'v3-geometry-final.json')
lock=read(BANK/'review-approved-lock-v3.json')
assert read(BANK/'review-feedback.json')==feedback
assert len(lock['approved'])==70
for n in lock['approved']:assert scenes[str(n)]==before[str(n)],n
for name,sha in lock['files'].items():assert hashlib.sha256((ROOT/'content-animations'/name).read_bytes()).hexdigest()==sha,name
for capture in [desktop,mobile,continuous]:
    assert not capture['errors'],capture['errors']
    # Browser cancellation events remain evidence; they are not HTTP successes.
    assert all(r.get('error')=='net::ERR_ABORTED' for r in capture['failures']),capture['failures']
    for record in capture['records']:assert record['revision']==scenes[str(record['number'])]['revision'],record['number']
assert len(desktop['records'])==len(mobile['records'])==45
assert all(not r['issues'] for r in mobile['records'])
assert len(continuous['records'])==10 and all(r['finished'] and r['paused'] for r in continuous['records'])
assert not transitions['errors'] and transitions['back']=='CÂU 544'
assert not geometry['collisions'] and not geometry['errors']
dmap={r['number']:r for r in desktop['records']}
mmap={r['number']:r for r in mobile['records']}
cmap={r['number']:r for r in continuous['records']}
order={r['number']:i for i,r in enumerate(desktop['records'])}
records=[]
for original in feedback['records']:
    n=original['number'];scene=scenes[str(n)];approved=original['status']=='approved'
    evidence=None if approved else dict(
        desktopTimes=dmap[n]['times'],mobileTimes=mmap[n]['times'],mobileLayoutIssues=mmap[n]['issues'],
        overviewSheet=f'output/playwright/feedback-v3/overview-{order[n]//6:02}.jpg',
        stepSheet=f'output/playwright/feedback-v3/question-{n}.jpg',continuousPlayback=cmap.get(n))
    records.append(dict(number=n,originalReview=original,candidateRevision=scene['revision'],
        userAccepted=approved,status='approved-preserved' if approved else 'repaired-awaiting-user-review',
        changedFields=[k for k in sorted(set(before[str(n)])|set(scene)) if before[str(n)].get(k)!=scene.get(k)],
        candidateSteps=[st['text'] for st in scene['steps']],
        agentSampledVisualReview=not approved,evidence=evidence))
summary=dict(scenes=len(scenes),steps=sum(len(s['steps']) for s in scenes.values()),
    approvedPreserved=70,repairedAwaitingUserReview=45,
    desktopFrames=sum(len(r['times']) for r in desktop['records']),mobileFrames=sum(len(r['times']) for r in mobile['records']),
    mobileRealPlaybackScenes=len(mobile['playback']),continuousPlaybackScenes=len(continuous['records']),
    continuousFrames=sum(len(r['frames']) for r in continuous['records']),
    sourceFeedbackSha256=hashlib.sha256((BANK/'review-feedback-v3-input.json').read_bytes()).hexdigest(),
    scenesSha256=hashlib.sha256((BANK/'scenes.json').read_bytes()).hexdigest(),
    rendererRevision=scenes['544']['rendererRevision'])
payload=dict(summary=summary,records=records,transportCancellations=continuous['failures'],limitations=[
    'POV uses a reconstructed 3D environment; buildings, materials and dimensions are not pixel-identical to the source photos.',
    'Visual review uses source/start/movement midpoints/end in overview sheets and selected detailed sheets, not every frame of 115 animations.',
    'Geometry uses actual GLB footprints with the rendering depth scale at 41 samples per step; wholly offscreen vehicles and intentional guard/barrier contact are excluded.',
    'Ten scenes were played continuously at 2x; the remaining captures are sampled. No FPS claim or independent legal-bank validation.',
    'Browser transport cancellations, if present, are retained separately from JavaScript/HTTP checks and scene readiness.',
])
stem=WORK/'feedback-repair-ledger-2026-11-01-v3'
stem.with_suffix('.json').write_text(json.dumps(payload,ensure_ascii=False,indent=2),encoding='utf8')
lines=['# Sổ sửa JSON xuất 17:27 ngày 01/11 — lượt 3','','70 câu đã duyệt giữ nguyên; 45 bản sửa chờ người dùng xác nhận. Không tự duyệt.','',
    '| Câu | Trạng thái | Revision | Ghi chú gốc | Sheet kiểm tra |','| --- | --- | --- | --- | --- |']
for r in records:
    note=r['originalReview']['notes'].replace('|','/').replace('\n','<br>')
    sheet='Giữ nguyên bản duyệt' if r['userAccepted'] else r['evidence']['stepSheet']
    lines.append(f"| {r['number']} | {r['status']} | `{r['candidateRevision']}` | {note} | {sheet} |")
stem.with_suffix('.md').write_text('\n'.join(lines)+'\n',encoding='utf8')
print(json.dumps(summary,ensure_ascii=True))
