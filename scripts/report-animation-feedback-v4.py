"""Evidence for the 18:37 review and shared cockpit; never approve for the user."""
import hashlib
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
BANK=ROOT/'content-animations/bank-review'
WORK=ROOT/'output/animation-review'
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
scenes=read(BANK/'scenes.json')['scenes'];before=read(BANK/'review-baseline-v4.json')['scenes']
feedback=read(BANK/'review-feedback-v4-input.json');lock=read(BANK/'review-approved-lock-v4.json')
desktop=read(WORK/'v4-desktop-final.json');mobile=read(WORK/'v4-mobile-final.json');continuous=read(WORK/'v4-continuous.json');geometry=read(WORK/'v4-geometry-final.json')
assert len(feedback['records'])==115  # Historical repair input; the live seed may be the final accepted export.
for n in lock['approved']:assert scenes[str(n)]==before[str(n)],n
for name,sha in lock['files'].items():assert hashlib.sha256((ROOT/'content-animations'/name).read_bytes()).hexdigest()==sha,name
for capture in [desktop,mobile,continuous]:
    assert not capture['errors'],capture['errors']
    assert all(r.get('error')=='net::ERR_ABORTED' for r in capture['failures']),capture['failures']
    for r in capture['records']:assert r['revision']==scenes[str(r['number'])]['revision'],r['number']
assert len(desktop['records'])==len(mobile['records'])==52
assert all(not r['issues'] for r in mobile['records'])
assert len(continuous['records'])==13 and all(r['finished'] and r['paused'] for r in continuous['records'])
assert len(geometry['worldScenes'])==42 and not geometry['collisions'] and not geometry['errors']
povs=0
for r in desktop['records']:
    if scenes[str(r['number'])].get('worldScene'):
        povs+=1;assert all(f.get('cockpitVersion')=='blue-hatchback-v1' and f.get('egoModel')=='car' for f in r['frames']),r['number']
assert povs==42
assert len(mobile['playback'])==31 and all(r['distance']>0 for r in mobile['playback'])
dmap={r['number']:r for r in desktop['records']};mmap={r['number']:r for r in mobile['records']};cmap={r['number']:r for r in continuous['records']};order={r['number']:i for i,r in enumerate(desktop['records'])}
records=[]
for original in feedback['records']:
    n=original['number'];s=scenes[str(n)];changed=s['revision']!=original['revision']
    records.append(dict(number=n,originalReview=original,candidateRevision=s['revision'],
        status='awaiting-user-review' if changed else 'approved-preserved',userAccepted=not changed,
        changeKind=s.get('reviewChangeKind') if changed else None,
        previousAcceptedCockpitChanged=changed and original['status']=='approved',
        agentSampledVisualReview=changed,candidateSteps=[st['text'] for st in s['steps']],
        evidence=None if not changed else dict(desktopTimes=dmap[n]['times'],mobileTimes=mmap[n]['times'],
            overviewSheet=f'output/playwright/feedback-v4/overview-{order[n]//6:02}.jpg',stepSheet=f'output/playwright/feedback-v4/question-{n}.jpg',continuousPlayback=cmap.get(n))))
summary=dict(scenes=len(scenes),steps=sum(len(s['steps']) for s in scenes.values()),markedFixes=13,
    commonPovCockpitScenes=42,previouslyApprovedCockpitUpdates=39,approvedUnchanged=63,awaitingUserReview=52,
    desktopFrames=sum(len(r['times']) for r in desktop['records']),mobileFrames=sum(len(r['times']) for r in mobile['records']),
    mobileMovingCameraScenes=len(mobile['playback']),continuousPlaybackScenes=13,continuousFrames=sum(len(r['frames']) for r in continuous['records']),
    sourceFeedbackSha256=hashlib.sha256((BANK/'review-feedback-v4-input.json').read_bytes()).hexdigest(),
    scenesSha256=hashlib.sha256((BANK/'scenes.json').read_bytes()).hexdigest(),rendererRevision=scenes['544']['rendererRevision'])
payload=dict(summary=summary,records=records,transportCancellations=continuous['failures'],limitations=[
    '39 previous approvals have a new cockpit/3D image and therefore await review; they are not silently carried over.',
    'Eleven photo cabins are now reconstructed worlds; Original mode retains the immutable question photos.',
    'Visual inspection samples source/start/movement midpoints/end and selected detailed sheets, not every frame of 115 animations.',
    'Actual model footprints are sampled at 41 fractions per step; offscreen vehicles and intentional guard/barrier contact are excluded.',
    'Thirteen scenes were played continuously at 2x, plus mobile playback for every moving POV. No FPS or independent legal validation claim.',
])
stem=WORK/'feedback-repair-ledger-2026-11-01-v4';stem.with_suffix('.json').write_text(json.dumps(payload,ensure_ascii=False,indent=2),encoding='utf8')
lines=['# Sổ sửa JSON xuất 18:37 và đồng bộ POV — lượt 4','','13 câu có nhận xét + 39 câu đã duyệt đổi khoang lái = 52 bản cần xác nhận. 63 câu giữ nguyên. Không duyệt thay người dùng.','',
    '| Câu | Trạng thái | Loại thay đổi | Revision | Ghi chú gốc |','| --- | --- | --- | --- | --- |']
for r in records:
    note=r['originalReview']['notes'].replace('|','/').replace('\n','<br>')
    lines.append(f"| {r['number']} | {r['status']} | {r['changeKind'] or 'giữ nguyên'} | `{r['candidateRevision']}` | {note} |")
stem.with_suffix('.md').write_text('\n'.join(lines)+'\n',encoding='utf8');print(json.dumps(summary,ensure_ascii=True))
