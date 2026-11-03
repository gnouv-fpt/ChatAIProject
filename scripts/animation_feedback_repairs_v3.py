"""Apply the user's 17:27 review: 70 accepted recipes frozen, 45 repairs."""
import copy
import hashlib
import json


def apply_feedback_v3(scenes, root):
    folder = root / 'content-animations/bank-review'
    feedback = json.loads((folder / 'review-feedback-v3-input.json').read_text(encoding='utf8'))
    baseline = json.loads((folder / 'review-baseline-v3.json').read_text(encoding='utf8'))['scenes']
    changed = {r['number'] for r in feedback['records'] if r['status'] == 'changes'}
    scenes.clear()
    scenes.update(copy.deepcopy(baseline))
    def S(n): return scenes[str(n)]
    def A(n, id): return next(a for a in S(n)['actors'] if a['id'] == id)
    def move(id, **kw): return dict(actor=id, action='move', **kw)
    def step(text, ids=(), kind='move', duration=6, actions=None):
        return dict(text=text, duration=duration, actions=actions if actions is not None else [dict(actor=id, action=kind) for id in ids])
    def steps(n, *items): S(n)['steps'] = list(items) + [baseline[str(n)]['steps'][-1]]
    def path(n, id, points, exit=True):
        points = copy.deepcopy(points)
        a = A(n, id)
        if exit:
            x,y = points[-1];dx=x-points[-2][0];dy=y-points[-2][1];margin=max(30,a['width']+8)
            if -margin<x<100+margin and -margin<y<100+margin:
                ts=[(edge-v)/d for edge,v,d in [(-margin,x,dx),(100+margin,x,dx),(-margin,y,dy),(100+margin,y,dy)] if abs(d)>1e-8 and (edge-v)/d>0]
                t=min(ts);points.append([round(x+dx*t,3),round(y+dy*t,3)])
        a.update(path=points, guidePath=points, at=points[0], headingFromPath=True)
    def placed(n,id,at,width=None,heading=None):
        a=A(n,id);a['at']=at
        if width is not None:a['width']=width
        if heading is not None:a.update(heading=heading,exactHeading=True)
        a.pop('anchor',None)
    def region(n,id,rect):
        a=A(n,id);x,y,w,h=rect;a.update(rect=rect,at=[x+w/2,y+h/2])
    def rect(p):
        x,y,w,h=p;return [[x,y],[x+w,y],[x+w,y+h],[x,y+h]]
    for n in changed:
        s=S(n);s.update(rendererVersion=3,motionVersion=2,status='draft')
        s['note']='Bản sửa theo nhận xét xuất lúc 17:27 ngày 01/11. Ảnh gốc giữ nguyên để đối chiếu; chờ người dùng xác nhận.'

    # Routes are ground-contact centres; chassis origins have no image-box offset.
    placed(488,'bus',[7,80],24)
    path(488,'bus',[[7,80],[27,66],[42,56],[47,48],[45,40],[32,27],[-18,-10]])
    placed(488,'truck',[74,27],22)
    path(488,'truck',[[74,27],[39,47],[-30,86]])
    placed(489,'bus',[7,81],24)
    path(489,'bus',[[7,81],[28,66],[43,55],[47,47],[44,38],[31,25],[-25,-16]])
    path(489,'police',[[87,74],[67,56],[55,45],[47,43],[34,46],[10,59],[-30,82]])
    steps(489,step('Xe công an rẽ trái, không đi thẳng.', ['police']),step('Xe tải đi sau xe công an.', ['truck']),step('Xe khách rẽ trái theo nét đỏ.', ['bus']),step('Xe con đi cuối theo thứ tự trong đáp án nguồn.', ['car']))
    path(504,'truck',[[7,72],[28,62],[48,64],[67,60],[77,50],[79,38],[75,27],[69,20],[65.5,14],[65.5,-20]])
    A(504,'truck')['depthScale']=dict(horizon=-60,max=1)
    # The truck and car both leave by the upper branch, on separate turns.
    steps(504,step('Mô tô đi qua vòng xuyến trước.', ['moto']),step('Xe tải theo vòng xuyến và ra cùng nhánh phía trên với xe con.', ['truck'],duration=10),step('Xe khách đi tới nhánh bên phải theo nét đỏ.', ['bus']),step('Xe con đi cuối, quay lại nhánh phía trên theo nét đỏ.', ['car']))
    placed(508,'truck',[31.5,65],40,[1,-.30]);placed(508,'moto',[81,45],14,[1,-.30])
    path(516,'truck',[[35.5,17],[86,128]])
    placed(518,'tractor',[38,64],65,[-1,.34]);placed(518,'towed',[83,38],27,[-1,.34])
    path(520,'b',[[13,69],[37,55],[48,48],[51,41],[45,33],[30,21],[-20,-14]])
    region(523,'sign',[70,17,9,20])
    path(523,'vehicle',[[20,80],[33,59],[44,43],[49,36],[47,31],[42,32],[37,39],[24,51],[-30,111]])
    S(523).pop('learningMode',None)
    steps(523,step('Đối chiếu biển cấm ô tô trong đề.', ['sign'],kind='focus',duration=3),step('Minh họa riêng hướng 5: xe quay đầu theo nét đỏ.', ['vehicle'],duration=8))
    # Keep each independent source route but align the first tangent with the road.
    placed(524,'vehicle',[84,81],27)
    for st in S(524)['steps']:
        for ac in st['actions']:
            if ac['action']=='move':
                p=copy.deepcopy(ac.get('path',A(524,'vehicle')['path']));p[0]=[84,81];p[1]=[71,55]
                x,y=p[-1];dx=x-p[-2][0];dy=y-p[-2][1]
                if -45<x<145 and -45<y<145:
                    t=min((edge-v)/d for edge,v,d in [(-45,x,dx),(145,x,dx),(-45,y,dy),(145,y,dy)] if abs(d)>1e-8 and (edge-v)/d>0)
                    p.append([round(x+dx*t,3),round(y+dy*t,3)])
                ac.update(path=p,guidePath=p)
    path(524,'vehicle',next(ac['path'] for st in S(524)['steps'] for ac in st['actions'] if ac['action']=='move'),exit=False)
    placed(528,'inside',[59,64],17)
    path(528,'inside',[[59,64],[77,101],[94,136]])
    placed(528,'truck-north',[40,28],17,[.52,1]);placed(528,'bus',[19,76],37,[1,-.25])
    path(530,'truck',[[37,54],[49,44],[59,35],[61,29],[56,23],[40,12],[12,-6]])
    # These are the two distinct red traces from the source, even while stopped.
    S(531)['preserveBoxOffset']=True
    S(531)['sourceGuides']=[dict(actor='truck',path=[[51.4,44.1],[47.7,47.3],[45.2,49.8],[43.6,57.1],[41.6,62.9],[38.4,69],[33.4,73.5],[28.2,75.5],[22.7,77.6],[17,78],[14.3,78.8],[3.2,91.4]]),dict(actor='car',path=[[71.8,34.3],[75.2,32.7],[75.9,25.3],[76.4,19.6],[78.2,16.7],[81.6,14.7],[86.8,14.7],[90.5,15.5],[93.2,13.1],[96.4,9.8]])]
    path(534,'bus',[[17,69],[36,53],[46,50],[57,53],[72,64],[91,79]])
    placed(534,'truck',[88,47],22)
    path(534,'truck',[[88,47],[77,39],[72,35],[70,31],[72,27],[81,20],[111,-3]])
    path(534,'car',[[62,17],[52,25],[47,31],[46,37],[50,43],[62,51],[76,62]])
    steps(534,step('Xe khách và xe tải rẽ phải theo nét đỏ trên hai nhánh riêng.', ['bus','truck'],duration=8),step('Xe con rẽ trái sau hai xe đi trước.', ['car']))
    placed(539,'vehicle',[13,69],12)
    path(539,'vehicle',[[13,69],[37,56],[51,53],[60,59],[77,78],[114,114]])
    for st in S(539)['steps']:
        for ac in st['actions']:
            if ac['action']=='move':
                p=[[13,69],[37,56],[50,49],[54,42],[51,35],[43,29],[34,24],[-27,-10]] if '3' in st['text'] else A(539,'vehicle')['path']
                ac.update(path=p,guidePath=p)
    path(540,'moto',[[60,27],[43,38],[22,51],[-30,83]])
    placed(540,'moto',[60,27],8)

    # Per-source lane centres in the repeated three-lane intersection drawings.
    for n in [500,503,538,553,560,561,562,565]:
        for id,at,width,heading in [('bus',[14,83],27,[1,-.55]),('truck',[26,84],16,[1,-.55]),('car',[33,91],11,[1,-.55]),('far-truck',[65,21],9,[-1,.55]),('far-car',[68,24],5.5,[-1,.55]),('moto',[71.5,27],5.5,[-1,.55]),('far-moto-2',[66,23],5,[-1,.55])]:
            if any(a['id']==id for a in S(n)['actors']):
                a=A(n,id);old=a['at'][:];placed(n,id,at,width,heading)
                if a['path']:
                    dx=at[0]-old[0];dy=at[1]-old[1]
                    p=[[x+dx,y+dy] for x,y in a['path']];path(n,id,p,exit=False)
        if n in [500,503,538,562]:path(n,'car',[[33,91],[51,72],[58,67],[64,67],[73,74],[91,92],[126,127]])
        if n==538:
            # The permitted movements use separate lanes and may run together.
            steps(n,step('Xe khách và mô tô tiến chậm tới vạch rồi dừng theo đèn đỏ; các xe có hướng được phép cùng đi, giữ khoảng cách.',actions=[move('bus'),move('moto'),move('truck'),move('car'),move('far-truck'),move('far-car',startAt=.3)],duration=10))
        if n==553:
            for id in ['bus','moto']:A(n,id)['guidePath']=[]
            steps(n,step('Xe khách và mô tô bị cấm theo tín hiệu: khoanh đỏ và giữ dừng.', ['bus','moto'],kind='forbidden',duration=5),step('Đối chiếu vị trí các làn và đèn; không tự thêm hướng rẽ vào ảnh không có mũi tên.', ['truck','car','far-truck','far-car'],kind='focus',duration=5))
        if n==560:
            steps(n,step('Xe tải có hướng đi vi phạm: giữ nguyên để đối chiếu.', ['truck'],kind='forbidden',duration=3),*[step(A(n,id)['label']+' đi theo đúng mũi tên được phép trong đề.',[id]) for id in ['bus','car','far-truck','far-car','moto']])
        if n==561:
            path(n,'moto',[[71.5,27],[60,32],[55,31],[48,25],[34,15]])
            path(n,'far-moto-2',[[66,23],[56,28],[51,27],[45,22],[31,12]])
        if n==565:
            path(n,'moto',[[71.5,27],[61,38],[59,45],[62,53],[76,68],[101,93]])
            path(n,'bus',[[14,83],[34,62],[45,48],[47,38],[44,29],[35,22],[19,10]])
        if n in [500,562]:
            S(n)['cleanBackground']['regions'] += [rect([59,11,15,19]),rect([64,14,13,19])]
            if n==500:
                # Preserve the board and the thin pole, not the cars underneath.
                S(n)['cleanBackground']['protectedRegions']=[[[26.3,45.5],[45.8,59.5],[45.8,70.5],[26.3,56.5]],rect([44.7,68,1,22])]

    # POV changes only affect the new renderer; accepted v2 scenes keep its bytes.
    def W(n):return S(n)['worldScene']
    def signs(n,*specs):W(n)['signs']=[];W(n)['sourceSigns']=list(specs)
    def sign(crop,shape='triangle-down',at=(5.1,-21),**extra):return dict(crop=crop,shape=shape,at=list(at),**extra)
    W(544)['egoModel']=True
    W(545)['guides']=[dict(label='1',path=[[1.75,0],[1.75,-10],[.8,-13],[-1.75,-13],[-1.75,10]]),dict(label='2',path=[[1.75,0],[1.75,-65]]),dict(label='3',path=[[1.75,-12],[1.75,-24],[-30,-24]]),dict(label='4',path=[[1.75,-12],[1.75,-22],[30,-22]])]
    W(545)['guides'][2]['labelAt']=[-4,-24]
    W(545)['guides'][3]['labelAt']=[6,-22]
    signs(545,sign([68.2,39.5,7.7,14.2],'circle'),sign([40,39,4.6,8.5],'circle',at=(-2.6,-32)))
    # The ego route is the left turn already shown in the source; reinforce it.
    steps(547,step('Xe của bạn chờ xe khách đi trước.', ['bus'],duration=7),step('Tiếp tục nhường xe tải.', ['truck'],duration=7),step('Xe của bạn rẽ trái theo mũi tên, không đi thẳng.', ['self'],duration=9))
    signs(549,sign([54.5,34,12,18]))
    signs(550,sign([60.4,46.3,8.4,14.3],'circle'))
    W(550)['egoRoute']=[[1.75,0],[1.75,-18],[1.75,-23],[.8,-25],[-1.75,-25],[-1.75,20]]
    W(550)['guides']=[dict(label='A',path=W(550)['egoRoute']),dict(label='B',path=[[1.75,0],[1.75,-14],[.4,-17],[-1.75,-17],[-1.75,8]])]
    steps(550,step('Hướng A: đi qua vạch người đi bộ rồi mới quay đầu.', ['self'],duration=10),step('Hướng B quay đầu ngay trên vạch: không chọn.', ['b'],kind='forbidden',duration=3))
    W(551)['egoRoute']=[[1.75,0],[1.75,-65]]
    steps(551,step('Xe của bạn đi thẳng; xe con từ bên trái rẽ phải trên làn ngược chiều.', ['self','car'],duration=8),step('Xe tải đi sau.', ['truck']))
    W(569)['island']=[[4,-27.5],[12,-27.5],[12,-24],[5,-24]]
    steps(573,step('Người đi bộ sang đường; cả xe xanh và xe của bạn dừng chờ.', ['ped'],duration=7),step('Người đã sang hết; xe xanh rẽ phải.', ['car'],duration=7),step('Xe của bạn rẽ phải sau xe xanh.', ['self'],duration=8))
    signs(575,sign([64.3,14,14,22],'triangle-up'))
    steps(580,step('Giảm tốc, giữ bên phải khi xe đối diện đang vượt.', ['self'],duration=3),step('Chờ xe xanh vượt xong và về làn của nó.', ['overtake','yellow'],duration=8),step('Đường đã thoáng; xe của bạn tiếp tục đi thẳng.', actions=[move('self',worldPath=[[2.8,-3],[2.8,-10],[1.75,-18],[1.75,-65]])],duration=8))
    W(581)['egoRoute']=[[1.75,0],[1.75,-4]]
    steps(581,step('Xe của bạn vẫn tiến chậm, giữ khoảng cách khi xe tải chuyển làn.',actions=[move('self',worldPath=[[1.75,0],[1.75,-14]]),move('truck')],duration=10),step('Tiếp tục đi chậm trên làn của mình sau khi xe tải đã chuyển làn.',actions=[move('self',worldPath=[[1.75,-14],[1.75,-32]])],duration=8))
    signs(582,sign([80,1,16.7,20.3]))
    signs(584,sign([77.8,13.8,8.7,13.5],'diamond'),sign([78.7,28.5,6.4,10],'square',height=1.65,size=.75,pole=False))
    signs(585,sign([65.3,33.8,8.8,14]),sign([67,48.7,6,6.5],'square',height=1.65,size=.65,pole=False))
    signs(586,sign([69.2,33.7,7.5,11.4],'circle',at=(3.4,-13)))
    signs(587,sign([66.3,30,5.2,8.5],'square',at=(4.3,-12)))
    signs(588,sign([78,39,6.6,10.5],'triangle-up'))
    W(594)['guides']=[dict(label='1',path=W(594)['egoRoute']),dict(label='2',path=[[1.75,0],[1.75,-12],[-4,-16],[-12,-23],[-30,-25.75]])]
    # A lawful merge stays on the acceleration lane until the main-lane gap.
    path(597,'red',[[34,78],[40,61],[47,50],[62,40],[84,27],[130,-1]])
    steps(597,step('Hai xe trên cao tốc đi trước; xe đỏ tăng tốc trong làn nhập và quan sát khoảng trống.', ['blue','ahead-car'],duration=7),step('Khoảng trống đã đủ: xe đỏ nhập theo hướng cùng chiều, không cắt ngang nét đứt đỏ sai trong ảnh.', ['red'],duration=9))
    path(598,'blue',[[39,60],[41,41],[49,32],[68,17],[97,-5],[128,-27],[140,-34]])
    steps(598,step('Xe xanh hoàn tất vượt nhanh hơn; xe đỏ và xe tải tiếp tục chạy trong làn.',actions=[move('blue',endAt=.65),move('red'),move('truck')],duration=9))
    path(599,'red',[[36,75],[68,50.3],[100,25.6]],exit=False)
    placed(600,'moto-far',[65,5],6,[1,.55]);A(600,'moto-far')['path']=[];A(600,'moto-far')['guidePath']=[]
    steps(600,step('Các xe khác giữ nguyên vị trí; xe phía sau chờ container.', ['blue','moto','moto-near'],kind='wait',duration=4),step('Chỉ minh họa container rẽ phải; các xe còn lại không di chuyển.', ['container'],duration=10))

    digest=hashlib.sha256()
    for name in ['review-player-v3.js','review-pov-v3.js']:
        digest.update(name.encode());digest.update((root/'content-animations'/name).read_bytes())
    revision=digest.hexdigest()[:16]
    for n in changed:
        s=S(n);s['rendererRevision']=revision;s['vehicleCount']=sum(a['kind']!='marker' for a in s['actors'])
        s['revision']=hashlib.sha256(json.dumps({k:v for k,v in s.items() if k!='revision'},ensure_ascii=False,sort_keys=True).encode()).hexdigest()[:16]
