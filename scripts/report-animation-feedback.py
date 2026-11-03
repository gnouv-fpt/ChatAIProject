"""Record candidate changes without declaring unobserved visual acceptance."""
import hashlib
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
work=ROOT/'output/animation-review'
feedback=json.loads((work/'user-feedback-2026-10-31.json').read_text(encoding='utf8'))
before=json.loads((work/'scenes-before-feedback.json').read_text(encoding='utf8'))['scenes']
scenes=json.loads((ROOT/'content-animations/bank-review/scenes.json').read_text(encoding='utf8'))['scenes']
observations_path=work/'visual-observations.json'
observations=json.loads(observations_path.read_text(encoding='utf8'))['records'] if observations_path.exists() else []
full_review_path=work/'feedback-visual-review-2026-11-01.json'
full_reviews=json.loads(full_review_path.read_text(encoding='utf8'))['records'] if full_review_path.exists() else []
observations+=full_reviews
observed={str(r['number']):r for r in observations if scenes.get(str(r['number']),{}).get('revision')==r['revision']}
records=[]
for r in feedback['records']:
    key=str(r['number']);s=scenes[key]
    changes=[field for field in ['actors','steps','cleanBackground','connections','learningMode','motionVersion'] if before[key].get(field)!=s.get(field)]
    records.append(dict(number=r['number'],originalStatus=r['status'],originalNotes=r['notes'],markers=r['markers'],priorRevision=r['revision'],candidateRevision=s['revision'],changedFields=changes,repairStatus='preserved-recipe-needs-renderer-check' if r['status']=='approved' else 'candidate-needs-visual-review',visualVerified=False))
    if key in observed:
        records[-1]['visualReview']=observed[key]
        records[-1]['repairStatus']='agent-sampled-review-awaiting-user'
        records[-1]['agentReviewed']=True
payload=dict(sourceFileSha256=hashlib.sha256((work/'user-feedback-2026-10-31.json').read_bytes()).hexdigest(),records=records)
(work/'feedback-repair-ledger.json').write_text(json.dumps(payload,ensure_ascii=False,indent=2),encoding='utf8')
lines=['# Đối chiếu ghi chú sa hình ngày 31/10/2026','',
       '115 bản ghi: 12 đã duyệt, 103 cần sửa. Đây là bảng theo dõi bản sửa local, chưa phải kết quả nghiệm thu trực quan.',
       'Ghi chú/dấu gốc được sao lưu nguyên vẹn trong `user-feedback-2026-10-31.json`. Không tự đổi câu nào thành đã duyệt.','',
       'Quan sát được gắn với đúng revision trong `visual-observations.json` và `feedback-visual-review-2026-11-01.json`; `agentReviewed` chỉ là rà nội bộ trên các ảnh mẫu đã ghi, không phải nghiệm thu và không đặt `visualVerified=true`. Đổi revision sẽ bỏ quan sát cũ khỏi bản hiện hành.','',
       '| Câu | Trạng thái gốc | Ghi chú nguyên văn | Dữ liệu bản sửa | Kiểm tra hình ảnh |',
       '| --- | --- | --- | --- | --- |']
for r in records:
    notes=r['originalNotes'].replace('|','&#124;').replace('\n','<br>')
    changes=', '.join(r['changedFields']) or 'Giữ nguyên kịch bản'
    visual=r.get('visualReview')
    inspection=('Rà ảnh mẫu '+visual['date']+': '+visual['summary']).replace('|','&#124;').replace('\n','<br>') if visual else 'Chưa xác nhận'
    lines.append(f"| {r['number']} | {r['originalStatus']} | {notes} | {changes} | {inspection} |")
(work/'feedback-repair-ledger.md').write_text('\n'.join(lines)+'\n',encoding='utf8')
print(f"Recorded {len(records)} questions; {len(observed)} sampled agent reviews at current revisions; 0 marked accepted on the user's behalf.")
