import cv2,numpy as np,json,heapq,math
from scipy.ndimage import distance_transform_edt,gaussian_filter1d
from pathlib import Path
base=Path('content-animations/bank-review');data=json.loads((base/'scenes.json').read_text(encoding='utf8'));scenes=data['scenes'];records={};report=[]
manual={
 '486':{
 'car':[[39,92],[44,84.5],[49,78.4],[54,74.7],[59,73.3],[64,74.8],[70,79.5],[81.5,92]],
 'bus':[[17,92],[35.7,71.5],[43,64.5],[52,56],[65,43],[79.5,30.5]],
 'truck':[[31,91],[39.5,77],[48,63],[51.4,53],[52.4,43.5],[50.2,34.5],[45.5,27.5],[38.5,22]],
 'moto':[[75,30],[71.8,27.3],[66,31.8],[60,34.4],[54,34.8],[48,33.3],[42,28.7],[36,23]],
 'far-truck':[[65,22],[61,25.5],[57.2,33.8],[56.4,41.5],[58.2,50],[62.3,58.8],[70,70.3],[85.7,84.8]]}}

def trace(im,path,actors):
 h,w=im.shape[:2];rgb=im.astype(float);red=(rgb[:,:,2]>130)&(rgb[:,:,2]>rgb[:,:,1]*1.3)&(rgb[:,:,2]>rgb[:,:,0]*1.3)
 # Red vehicle bodies and large circular red signs are not route centre lines.
 kernel=cv2.getStructuringElement(cv2.MORPH_ELLIPSE,(7,7));thick=cv2.morphologyEx(red.astype('uint8'),cv2.MORPH_OPEN,kernel);# Keep thick arrow curves; opening also erased valid source strokes.
 selected=np.zeros(red.shape,np.uint8)
 count,labels,stats,centers=cv2.connectedComponentsWithStats(thick,8)
 for i in range(1,count):
  if stats[i,cv2.CC_STAT_AREA]<35:continue
  cx,cy=centers[i]
  if any(math.hypot(cx-a['at'][0]*w/100,cy-a['at'][1]*h/100)<a.get('width',10)*w/100*.8 for a in actors.values() if a.get('at')):selected[labels==i]=1
 red=red&~cv2.dilate(selected,np.ones((3,3),np.uint8)).astype(bool)
 ys,xs=np.where(red)
 if len(xs)<30:return None,'no-red-route'
 coords=np.c_[xs,ys];dist=distance_transform_edt(~red);prior=np.ones((h,w),np.uint8)
 pix=np.array([[x*w/100,y*h/100] for x,y in path]);cv2.polylines(prior,[np.rint(pix).astype('int32')],False,0,1);pd=distance_transform_edt(prior)
 anchors=[]
 for p in pix[1:]:
  ds=((coords-p)**2).sum(1);i=ds.argmin()
  if ds[i]<=max(18,w*.045)**2:
   a=tuple(coords[i]);
   if not anchors or math.dist(a,anchors[-1])>5:anchors.append(a)
 if len(anchors)<2:return None,'too-few-source-anchors'
 def astar(start,end):
  heap=[(0,0,start)];seen={start:0};back={};bound=45
  while heap:
   _,cost,p=heapq.heappop(heap)
   if cost>seen[p]+.001:continue
   if p==end:
    out=[p]
    while p in back:p=back[p];out.append(p)
    return out[::-1]
   for dx,dy in [(1,0),(-1,0),(0,1),(0,-1),(1,1),(1,-1),(-1,1),(-1,-1)]:
    x,y=p[0]+dx,p[1]+dy
    if x<0 or y<0 or x>=w or y>=h or pd[y,x]>bound:continue
    nc=cost+math.hypot(dx,dy)*(1+dist[y,x]*2.8+pd[y,x]*.055)
    q=(x,y)
    if nc<seen.get(q,1e20):seen[q]=nc;back[q]=p;heapq.heappush(heap,(nc+math.dist(q,end),nc,q))
  return None
 pixels=[]
 for a,b in zip(anchors,anchors[1:]):
  segment=astar(a,b)
  if segment is None:return None,'disconnected'
  pixels.extend(segment if not pixels else segment[1:])
 if len(pixels)<15:return None,'too-short'
 if len(set(pixels))/len(pixels)<.96:return None,'backtracking'
 pp=np.array(pixels,float);pp[:,0]=gaussian_filter1d(pp[:,0],1.3);pp[:,1]=gaussian_filter1d(pp[:,1],1.3)
 coverage=float(np.mean([dist[min(h-1,max(0,round(y))),min(w-1,max(0,round(x)))]<2.3 for x,y in pp]))
 if coverage<.82:return None,'low-coverage'
 simplified=cv2.approxPolyDP(pp.astype('float32'),.7,False).reshape(-1,2)
 def crosses(points):
  def side(a,b,c):return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
  total=0
  for i in range(len(points)-1):
   for j in range(i+2,len(points)-1):
    a,b=points[i],points[i+1];c,d=points[j],points[j+1]
    if side(a,b,c)*side(a,b,d)<-.01 and side(c,d,a)*side(c,d,b)<-.01:total+=1
  return total
 clean=cv2.approxPolyDP(pp.astype('float32'),3,False).reshape(-1,2)
 if crosses(clean)>crosses(pix):return None,'new-self-intersection'
 length=lambda a:float(np.linalg.norm(np.diff(a,axis=0),axis=1).sum())
 if length(pp)>length(pix)*1.25:return None,'excessive-detour'
 guide=[[round(float(x/w*100),3),round(float(y/h*100),3)] for x,y in simplified]
 # Keep the original ground anchor, and the original off-image continuation.
 full=[path[0]]+guide
 if math.hypot((guide[-1][0]-path[-1][0])*w/100,(guide[-1][1]-path[-1][1])*h/100)>2:full.append(path[-1])
 else:full[-1]=path[-1]
 return {'path':full,'guidePath':guide,'coverage':round(coverage,4),'originalEnd':path[-1]},None
for number,s in scenes.items():
 im=cv2.imread(str(base/number/'image-1.jpeg'));actors={a['id']:a for a in s['actors']};actors.update({k:{'path':v} for k,v in manual.get(number,{}).items() if k not in actors})
 rec={'actors':{},'actions':{}}
 for id,a in actors.items():
  path=manual.get(number,{}).get(id,a.get('path',[]))
  if len(path)<2:continue
  result,error=trace(im,path,actors)
  if result:rec['actors'][id]=result
  report.append({'number':number,'actor':id,'traced':bool(result),'error':error,'coverage':result and result['coverage']})
 for i,step in enumerate(s['steps']):
  for action in step['actions']:
   if action.get('path'):
    result,error=trace(im,action['path'],actors)
    if result:rec['actions'][str(i)+':'+action['actor']]=result
 if rec['actors'] or rec['actions']:records[number]=rec
records.setdefault('486',{'actors':{},'actions':{}})['actors']=json.loads((base/'source-routes.json').read_text(encoding='utf8'))['questions']['486']['actors']
(base/'source-routes.json').write_text(json.dumps({'sourceSha256':data['sourceSha256'],'questions':records},ensure_ascii=False,indent=2),encoding='utf8')
Path('output/animation-review/route-trace-report.json').write_text(json.dumps(report,indent=2),encoding='utf8')
print('routes',len(report),'traced',sum(r['traced'] for r in report),'questions',len(records))
