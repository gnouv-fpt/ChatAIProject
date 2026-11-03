import cv2,numpy as np,json,math
from pathlib import Path
bank=json.loads(Path('content-animations/bank-review/bank.json').read_text(encoding='utf8'));scenes=json.loads(Path('content-animations/bank-review/scenes.json').read_text(encoding='utf8'))['scenes'];result={}
for q in bank['questions']:
 n=q['number'];s=scenes[str(n)]
 if s.get('perspective')=='driver':continue
 im=cv2.imread(str(Path('content-animations')/q['images'][0]['url']));h,w=im.shape[:2]
 lines=cv2.HoughLinesP(cv2.Canny(cv2.cvtColor(im,cv2.COLOR_BGR2GRAY),70,160),1,np.pi/360,25,minLineLength=w*.12,maxLineGap=8)
 hist=np.zeros(180)
 for x1,y1,x2,y2 in ([] if lines is None else lines.reshape(-1,4)):
  angle=(math.degrees(math.atan2(y2-y1,x2-x1))+90)%180-90
  if 8<abs(angle)<80:hist[int(angle+90)]+=math.hypot(x2-x1,y2-y1)
 hist=np.convolve(hist,np.ones(7)/7,'same');a=int(hist[10:82].argmax()+10-90);b=int(hist[98:170].argmax()+98-90)
 if b<12:b=30
 result[str(n)]={'angles':[a,b],'method':'image-line-fit'}
# Roundabouts and steep driver-style photos need the local entry axes, not the most frequent curb edge.
for n,angles in {491:[-27,32],504:[-30,42],511:[-22,27],541:[-26,29],546:[-17,20],597:[-25,33],598:[-26,35],599:[-28,36],600:[-34,30]}.items():result[str(n)]={'angles':angles,'method':'source-entry-axes'}
Path('content-animations/bank-review/road-calibration.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf8')
print('calibrated',len(result))
