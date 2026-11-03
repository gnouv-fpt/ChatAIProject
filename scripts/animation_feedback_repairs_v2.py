"""The 71 revisions requested in the user's 01-Nov review; 44 approvals frozen.

Pixel routes belong to the photographed overview. POV routes are metres on a
shared road surface, with a camera attached to the ego vehicle, not pixel paths.
"""
import copy
import hashlib
import json


def apply_feedback_v2(scenes, root):
    work=root/'content-animations/bank-review'
    source=work/'review-feedback-v2-input.json'
    feedback=json.loads(source.read_text(encoding='utf8'))
    baseline=json.loads((work/'review-approved-2026-11-01.json').read_text(encoding='utf8'))['scenes']
    approved={r['number'] for r in feedback['records'] if r['status']=='approved'}
    changed={r['number'] for r in feedback['records'] if r['status']=='changes'}
    def S(n):return scenes[str(n)]
    def A(n,id):return next(a for a in S(n)['actors'] if a['id']==id)
    def route(n,id,path):
        a=A(n,id);a.update(path=path,guidePath=path,at=path[0],headingFromPath=True)
    def region(n,id,rect):
        a=A(n,id);x,y,w,h=rect;a.update(rect=rect,at=[x+w/2,y+h/2])
    def place(n,id,rect,heading):
        a=A(n,id);x,y,w,h=rect;a.update(rect=rect,sourceRect=rect,at=[x+w/2,y+h/2],width=w,heading=heading,anchor='box',exactHeading=True)
    def action(id,kind='move',**kw):return dict(actor=id,action=kind,**kw)
    def step(text,*ids,kind='move',duration=6,actions=None):return dict(text=text,duration=duration,actions=actions or [action(id,kind) for id in ids])
    def steps(n,*items):S(n)['steps']=list(items)+[S(n)['steps'][-1]]
    def exit_route(n,id,path):
        a=A(n,id);margin=max(26,a['width']+8);x,y=path[-1];dx=x-path[-2][0];dy=y-path[-2][1]
        if -margin<x<100+margin and -margin<y<100+margin:
            ts=[(edge-v)/d for edge,v,d in [(-margin,x,dx),(100+margin,x,dx),(-margin,y,dy),(100+margin,y,dy)] if abs(d)>1e-7 and (edge-v)/d>0]
            t=min(ts);path=path+[[round(x+dx*t,3),round(y+dy*t,3)]]
        route(n,id,path)
    for n in approved:scenes[str(n)]=copy.deepcopy(baseline[str(n)])
    for n in changed:
        S(n).update(rendererVersion=2,motionVersion=2,note='Bản sửa theo nhận xét ngày 01/11. Chọn Ảnh gốc để đối chiếu; trạng thái duyệt cũ và ghi chú được giữ riêng.')
        S(n).pop('learningMode',None)

    # Exact destinations from each source arrow: left turns are not U-turns.
    for n in [488,489]:exit_route(n,'bus',[[9,86],[30,66],[43,53],[46,45],[43,37],[32,28],[-20,-10]])
    exit_route(491,'truck',[[61,65],[70,52],[73,43],[69,33],[61,25],[57,18],[56,9],[56,-30]])
    exit_route(491,'car',[[82,73],[79,51],[78,38],[74,31],[64,24],[51,22],[30,25],[8,23],[-28,18]])
    exit_route(496,'truck',[[83.5,29],[65,42],[55,44],[44,39],[33,31],[20,21]])
    for a in S(499)['actors']:
        if a['kind']=='marker' and 'đèn' in a['label'].lower():region(499,a['id'],[86.6,34.5,5,14])
    region(505,'sign',[12,37,12,55])
    for id in ['truck','moto']:A(508,id)['heading']=[1,-.36]
    for id in ['car','moto']:A(509,id)['heading']=[1,-.23]
    A(509,'truck')['heading']=[-1,.23]
    # Separate bridge approaches in both directions; the bus waits until the
    # truck's complete body has cleared its lane at the near end.
    exit_route(516,'truck',[[36,17],[72,126]])
    exit_route(516,'bus',[[80,80],[24,-14]])
    steps(516,step('Xe khách dừng trước cầu, nhường xe tải.','bus',kind='wait',duration=3),step('Xe tải đi thẳng qua cầu và ra khỏi phần đường xe khách.','truck',duration=8),step('Xe khách đi thẳng qua cầu sau khi xe tải đã qua.','bus',duration=8))
    exit_route(504,'bus',[[11,22],[22,31],[26,44],[27,56],[35,64],[53,67],[67,63],[75,55],[85,46],[108,43]])
    exit_route(504,'truck',[[7,76],[27,65],[43,61],[62,63],[76,57],[85,47],[110,44]])
    exit_route(504,'car',[[54,11],[45,23],[35,31],[31,41],[32,51],[41,57],[56,60],[67,56],[70,47],[67,36],[61,28],[59,17],[61,0]])
    exit_route(520,'moto',[[74,29],[58,38],[49,43],[46,49],[50,57],[69,79],[101,112]])
    exit_route(520,'b',[[13,73],[37,59],[49,52],[54,45],[53,38],[45,31],[31,21]])
    # Give the bicycle clearance before the motorcycle turns across the same
    # approach, without asserting an extra legal priority between the pair.
    steps(520,step('Minh họa nhóm mô tô và xe đạp đi trước: xe đạp đi thẳng.','cycle'),step('Mô tô rẽ trái theo mũi tên.','moto'),step('Xe con A đi sau nhóm hai bánh.','a'),step('Xe con B rẽ trái, không quay đầu.','b'))
    region(523,'sign',[69,28,8,27])
    exit_route(523,'vehicle',[[20,81],[35,59],[48,49],[59,55],[92,68]])
    S(523)['learningMode']='alternatives'
    for st in S(523)['steps']:
        for ac in st['actions']:
            if ac['action']=='move' and ac.get('path'):
                ac['path']=[[20,81],[34,60],[46,45],[54,38],[51,32],[44,36],[40,44],[29,55],[-35,119]];ac['guidePath']=ac['path']
    place(524,'vehicle',[70,61,29,38],[-1,-.6])
    S(524)['learningMode']='alternatives'
    for st in S(524)['steps']:
        for ac in st['actions']:
            if ac['action']=='move':
                path=ac.get('path',A(524,'vehicle')['path'])
                if path:path[0]=A(524,'vehicle')['at'][:]
    route(524,'vehicle',copy.deepcopy(next(ac['path'] for st in S(524)['steps'] for ac in st['actions'] if ac['action']=='move')))
    region(527,'works',[24,45,14,22])
    exit_route(527,'moto',[[31.5,76],[42,66],[48,54],[83,31],[105,17]])
    steps(527,step('Quan sát chướng ngại và phần đường còn lại.','works',kind='focus',duration=3),step('Xe con vi phạm, giữ nguyên để đối chiếu.','car',kind='forbidden',duration=3),step('Mô tô đi qua chướng ngại trên phần đường minh họa.','moto'))
    A(528,'bus')['heading']=[1,-.3];A(528,'truck-north')['heading']=[.48,1];A(528,'car')['heading']=[-1,.28]
    exit_route(528,'inside',[[59.5,59],[79,105]])
    exit_route(530,'truck',[[37,56],[54,43],[62,34],[62,29],[52,22],[35,13]])
    steps(530,step('Xe tải rẽ trái; xe con vượt theo hướng thẳng.','truck','car',duration=9))
    exit_route(531,'car',[[68,39.5],[75,32],[78,21],[84,17],[92,17],[108,6]])
    steps(531,step('Xe tải vượt không đúng, giữ nguyên để đối chiếu.','truck',kind='forbidden',duration=3),step('Xe con vượt xe van theo đường trong đề.','car',duration=8))
    A(532,'truck')['heading']=[1,-.45];A(532,'fire')['heading']=[-1,-.45]
    exit_route(532,'fire',[[84.5,60.5],[12,18]])
    steps(532,step('Xe tải không được quay đầu theo hướng bị cấm.','truck',kind='forbidden',duration=3),step('Xe chữa cháy tiếp tục đi thẳng theo mũi tên.','fire'))
    exit_route(534,'bus',[[17,66],[37,54],[48,52],[62,61],[91,80]])
    exit_route(534,'truck',[[89,47],[77,38],[72,32],[73,27],[83,17],[105,1]])
    exit_route(534,'car',[[62,17],[47,28],[44,36],[49,43],[67,53],[95,71]])
    exit_route(536,'car',[[90,77],[63,56],[53,48],[47,44],[42,45],[11,69]])
    exit_route(536,'bus',[[11,85],[40,64],[49,53],[53,44],[48,35],[35,23]])
    S(539)['learningMode']='alternatives'
    place(539,'vehicle',[9,59,14,22],[1,-.5])
    route(539,'vehicle',[[16,70],[37,60],[50,60],[61,68],[78,84],[120,126]])
    for st in S(539)['steps']:
        for ac in st['actions']:
            if ac.get('path') and ac['action']=='move' and max(p[1] for p in ac['path'])<70:
                ac['path']=[[16,70],[44,56],[53,46],[55,37],[46,29],[31,19],[-26,-12]];ac['guidePath']=ac['path']
            elif ac.get('path') and ac['action']=='move':ac['path']=A(539,'vehicle')['path'][:];ac['guidePath']=ac['path']
    steps(540,step('Xe quân sự đi trước.','army'),step('Xe công an đi sau xe quân sự.','police'),step('Minh họa mô tô đi trước để hai xe cùng nhánh không đè nhau.','moto'),step('Xe con rẽ theo nhánh sau khi mô tô đã qua.','car'))
    steps(499,step('Đối chiếu đèn đỏ ở nhánh mô tô.','red',kind='focus',duration=3),step('Xe con đi thẳng khi đèn xanh.','car'),step('Minh họa riêng xe khách rẽ trái, không đè lên lượt xe con.','bus'))

    # Traffic-light family: physical lane boxes and each drawing's own arrows.
    signal_numbers=[500,503,538,553,560,561,562,563,565]
    boxes={'bus':([0,64,29,35],[1,-.56]),'truck':([22,72,16,22],[1,-.56]),'car':([32,84,12,12],[1,-.56]),'far-truck':([63,13,9,12],[-1,.56]),'far-car':([68,18,6,9],[-1,.56]),'moto':([72,19,6,12],[-1,.56]),'far-moto-2':([63,17,5,12],[-1,.56])}
    for n in signal_numbers:
        for a in S(n)['actors']:
            if a['id'] in boxes:place(n,a['id'],*boxes[a['id']])
        paths={
            'car':[[38,90],[55,67],[62,64],[70,70],[98,98]],
            'truck':[[30,83],[94,19]],
            'bus':[[14.5,81.5],[40,56],[48,44],[48,36],[41,28],[28,18]],
            'far-truck':[[67.5,19],[55,30],[48,30],[37,22],[24,14]],
            'far-car':[[71,22.5],[16,63],[-26,94]],
            'moto':[[75,25],[9,91]],
            'far-moto-2':[[65.5,23],[55,33],[54,43],[63,52],[94,83]],
        }
        if n==538:paths['bus']=[[14.5,81.5],[18,78]];paths['moto']=[[75,25],[72,28]]
        if n==561:
            paths['moto']=[[75,25],[57,34],[50,33],[41,26],[30,18]]
            paths['far-moto-2']=[[65.5,23],[55,30],[48,29],[39,23],[27,16]]
        if n==563:
            place(n,'car',[68,18,6,9],[-1,.56])
            paths['car']=[[71,22.5],[16,63],[-26,94]]
            paths['far-truck']=[[67.5,19],[57,32],[55,43],[62,54],[91,78]]
        if n==565:paths['moto']=[[75,25],[62,38],[61,49],[75,64],[95,84]]
        for id,path in paths.items():
            if any(a['id']==id for a in S(n)['actors']):
                if n==538 and id in ['bus','moto']:route(n,id,path);A(n,id)['stayInFrame']=True
                else:exit_route(n,id,path)
        invalid={500:['bus','moto'],503:['bus','truck','far-truck','moto'],538:[],553:['car','truck'],560:['truck'],561:['bus','truck'],562:['bus','truck','moto'],563:['bus','truck','far-truck'],565:['truck','car','far-truck','far-car']}[n]
        if n==553:
            steps(n,step('Xe con và xe tải ở làn đèn đỏ phải dừng. Ảnh này không có mũi tên chuyển hướng.','car','truck',kind='wait',duration=5),step('Đối chiếu các xe còn lại theo tín hiệu, không tự thêm đường rẽ vào ảnh.','bus','far-truck','far-car','moto',kind='focus',duration=5))
        else:
            valid={500:['truck','car'],503:['car'],538:['bus','truck','car','far-truck','far-car','moto'],560:['bus','car','far-truck','far-car','moto'],561:['car','moto','far-moto-2'],562:['car'],563:['car'],565:['bus','moto']}[n]
            initial=[step('Nhóm vi phạm giữ nguyên vị trí để đối chiếu.','unused',kind='forbidden',duration=3,actions=[action(id,'forbidden') for id in invalid])] if invalid else []
            steps(n,*initial,*[step(A(n,id)['label']+' đi theo nhánh trong ảnh; các lượt minh họa được tách để không va chạm.',id) for id in valid])
            if n==538:
                for st in S(n)['steps']:
                    if any(ac['actor'] in ['bus','moto'] and ac['action']=='move' for ac in st['actions']):st['text']='Tiến chậm tới vạch rồi dừng theo đèn đỏ; không đi qua giao lộ.'
    # All traffic continues along its own lane in the overtaking examples.
    exit_route(597,'ahead-car',[[68,16.5],[130,-21]])
    A(597,'ahead-car')['kind']='van'
    steps(597,step('Xe đỏ không nhập theo đường sai trong đề.','red',kind='forbidden',duration=3),step('Hai xe trên cao tốc tiếp tục đi thẳng.','blue','ahead-car',duration=8))
    route(598,'red',[[14,79],[35,63],[55,48]])
    steps(598,step('Xe đỏ tiếp tục đi chậm trong làn, không vượt nối; xe xanh đang vượt xe tải.','red','blue','truck',duration=9))
    A(598,'red')['stayInFrame']=True
    route(599,'red',[[36,75],[64,54],[92,33]])
    exit_route(599,'blue',[[88,24],[130,-7.5]])
    exit_route(599,'yellow',[[54,42],[71,30],[86,27],[105,13]])
    steps(599,step('Cả ba xe tiếp tục di chuyển; xe vàng chỉ trở lại làn sau khi đã vượt xe đỏ.','yellow','red','blue',duration=9))
    A(599,'red')['stayInFrame']=True
    route(599,'blue',[[88,24],[152,-24]])
    # Parallel lane centre-lines for the following group; no diagonal fan-out.
    exit_route(600,'container',[[44,53],[51,46],[56,47],[75,61],[110,84]])
    place(600,'blue',[3,82,13,13],[1,-.45])
    place(600,'moto-near',[11,89,7,11],[1,-.45])
    for id in ['blue','moto','moto-near']:
        x,y=A(600,id)['at'];route(600,id,[[x,y],[x+120,y-96]])
    exit_route(600,'red-car',[[91.5,40],[14,-5]])
    exit_route(600,'moto-far',[[65,4],[110,90]])
    steps(600,step('Xe xanh và hai mô tô giảm tốc, giữ khoảng cách chờ container.','blue','moto','moto-near',kind='wait',duration=4),step('Container rẽ phải, các xe khác tiếp tục chờ.','container',duration=10),step('Minh họa lượt xe ở nhánh đối diện sau khi container đã qua.','red-car'),step('Minh họa riêng mô tô trên nhánh còn lại.','moto-far'),step('Xe xanh và hai mô tô phía sau container đi thẳng, giữ nguyên khoảng cách.','blue','moto','moto-near',duration=8))
    A(557,'a')['heading']=[1,-.075]

    _driver_scenes(S,A,route,steps,step,action,changed)
    files=['review-player-v2.js','review-vehicles-v2.js','review-pov.js','review-traffic.mjs','review-attachments.mjs','review-v2.css']
    digest=hashlib.sha256()
    for file in files:digest.update(file.encode());digest.update((root/'content-animations'/file).read_bytes())
    revision=digest.hexdigest()[:16]
    for n in changed:
        s=S(n);s['vehicleCount']=sum(a['kind']!='marker' for a in s['actors']);s['rendererRevision']=revision
        s['revision']=hashlib.sha256(json.dumps({k:v for k,v in s.items() if k!='revision'},ensure_ascii=False,sort_keys=True).encode()).hexdigest()[:16]


def _driver_scenes(S,A,route,steps,step,action,changed):
    J=-24
    straight=[[1.75,0],[1.75,-65]]
    right=[[1.75,0],[1.75,J+4],[3.5,J+1.75],[55,J+1.75]]
    left=[[1.75,0],[1.75,J-1.75],[0,J-1.75],[-55,J-1.75]]
    def spec(at,end=None,via=None,heading=None,scale=1):
        d=dict(at=at,scale=scale)
        if end:d['route']=[at]+(via or [])+[end]
        if heading is not None:d['heading']=heading
        return d
    north=lambda z=-40:spec([-1.75,z],[-1.75,35])
    east=lambda x=-22:spec([x,J+1.75],[55,J+1.75])
    west=lambda x=22:spec([x,J-1.75],[-55,J-1.75])
    own=lambda path=straight:dict(egoRoute=copy.deepcopy(path))
    configs={
      544:dict(participants={'car':spec([-12,J+1.75],[1.75,-120],[[.25,J+1.75],[1.75,J-3]])},**own()),
      545:dict(participants={},median=True,**own()),
      547:dict(participants={'bus':north(),'truck':west()},lights=[dict(at=[5,J+4],state='green')],**own(left)),
      549:dict(endAhead=True,participants={'truck':east()},**own(right)),
      550:dict(participants={},**own([[1.75,0],[1.75,-10],[.8,-14],[-1.75,-14],[-1.75,20]])),
      551:dict(participants={'car':spec([-22,J+1.75],[-1.75,35],[[-3,J+1.75],[-1.75,J+4]]),'truck':west()},**own(left)),
      552:dict(type='straight',participants={'truck':spec([1.75,-16],[1.75,-32]),'ahead':spec([1.75,14],[1.75,-5])},**own([[1.75,0],[1.75,-6],[-1.75,-11],[-1.75,-40],[1.75,-49],[1.75,-70]])),
      567:dict(participants={'moto':spec([-18,J+1.75],[1.75,-65],[[.25,J+1.75],[1.75,J-3]]),'car':west()},**own()),
      568:dict(participants={'car':spec([20,J-1.75],[1.75,-65],[[3,J-1.75],[1.75,J-4]]),'moto':north()},**own()),
      569:dict(participants={'car':spec([-1.75,-35],heading=-1.570796)},lights=[dict(at=[-5,J-4],state='red')],**own(right)),
      572:dict(participants={'truck':east(),'cycle':spec([2.8,J+9],[2.8,-65])},**own(right)),
      573:dict(crossing=J+6,participants={'ped':spec([5.3,J+6],[-5.3,J+6]),'car':spec([1.75,J+10],[55,J+1.75],[[1.75,J+4],[4,J+1.75]])},**own(right)),
      574:dict(participants={'cycle':east(-17),'bus':north()},**own(left)),
      575:dict(participants={'car':north(-43),'truck':spec([-15,J+1.75],heading=0)},**own()),
      576:dict(type='straight',participants={'van':spec([1.75,-16],heading=1.570796),'opposite':north(-48)},**own([[1.75,0],[1.75,-4]])),
      579:dict(type='straight',participants={'reverse':spec([5,-19],[2,-19],heading=0),'parked':spec([6,-28],heading=0),'right-car':spec([6,-9],heading=0)},**own([[1.75,0],[1.75,-4]])),
      580:dict(type='straight',participants={'overtake':spec([1.75,-38],[-1.75,30],[[1.75,-25],[-1.75,-15]]),'yellow':spec([-1.75,-48],[-1.75,-13])},**own([[1.75,0],[2.8,-3]])),
      581:dict(type='straight',sameDirection=True,participants={'truck':spec([1.75,-19],[-1.75,-100],[[1.75,-24],[-1.75,-37]])},**own([[1.75,0],[1.75,-4]])),
      582:dict(participants={'mirror-car':spec([1.75,14],heading=1.570796)},**own()),
      583:dict(participants={'cycle':east(-17),'moto':west(22),'opposite':spec([-1.75,-50],heading=-1.570796)},**own(left)),
      584:dict(participants={'car':north(-43),'truck':west()},**own(left)),
      585:dict(participants={'car':spec([-22,J+1.75],[1.75,-70],[[0,J+1.75],[1.75,J-4]])},**own()),
      586:dict(type='narrow',roadWidth=5.5,participants={'car':spec([-1.3,-34],[-1.3,35])},**own([[1.3,0],[1.3,-5],[1.3,-55]])),
      587:dict(type='straight',crossing=J+6,participants={'ped':spec([-5.3,J+6],[5.3,J+6]),'ahead-car':spec([1.75,-58],[1.75,-90])},**own()),
      588:dict(participants={'car':west()},**own(left)),
      589:dict(participants={'truck':north(),'car':west(),'right-car':spec([2.8,13],heading=1.570796)},**own(left)),
      591:dict(participants={'truck':north()},lights=[dict(at=[5,J+4],state='green')],**own(left)),
      593:dict(participants={'truck':east(),'cycle':north(-42)},**own()),
      594:dict(endAhead=True,participants={},**own(left)),
      595:dict(type='straight',night=True,participants={'opposite':north(-38),'ahead':spec([1.75,-14],[1.75,-90]),'near-car':spec([5,10],heading=1.570796)},**own([[1.75,0],[1.75,-40]])),
      596:dict(type='railway',participants={'sliding-gate':spec([-8,J+5],[.25,J+5],heading=1.570796,scale=1.25),'ped':spec([-4.25,J+5.4],[4,J+5.4],heading=0)},**own([[1.75,0]])),
    }
    for n,c in configs.items():
        if n not in changed:continue
        c.setdefault('type','junction');c.setdefault('junction',J);c['seed']=n;c.setdefault('markers',{})
        S(n)['worldScene']=c;S(n).pop('foregroundRegions',None)
        for a in S(n)['actors']:
            if a['kind']=='marker' and a['id']!='self':c['markers'][a['id']]=[5,2.8,J+3]
        for id in c['participants']:
            a=A(n,id)
            if a['kind']=='marker':a['kind']='truck' if id=='truck' else 'car';a['path']=[]
        if not any(a['id']=='self' for a in S(n)['actors']):S(n)['actors'].append(dict(id='self',label='Xe của bạn',kind='marker',at=[50,80],width=6,path=[]))
        A(n,'self')['path']=[[50,80],[50,20]]
        for id,p in c['participants'].items():
            path=p.get('route')
            # Through traffic continues beyond the ego's stopping point. A
            # completed cue must not park another car at the camera endpoint.
            if path and max(abs(v) for v in path[-1])>=55:
                end=path[-1]
                if abs(end[0])>abs(end[1]):end[0]=120 if end[0]>0 else -120
                else:end[1]=120 if end[1]>0 else -120
    # Preserve traffic controls in the physical scene at the source branch.
    signs={544:'warning',545:'noRight',547:None,549:'yield',550:'noUTurn',551:'warning',567:'yield',568:None,572:'warning',574:'stop',575:'warning',582:'yield',584:'priority',585:'yield',587:'warning',588:'priority',596:'railwayWarning'}
    for n,type in signs.items():
        if type:configs[n]['signs']=[dict(type=type,at=[5.1,J+3])]
    configs[545]['signs'].append(dict(type='noentry',at=[-2.6,-32]))
    configs[552]['markers']['mirrors']=[1.75,1.82,-.9]
    configs[582]['markers']['mirror']=[1.75,1.82,-.9]
    # Following vehicles finish behind the ego car after it has turned; they
    # do not drive into its completed camera pose on the same exit lane.
    for n,id,x in [(551,'truck',-40),(584,'truck',-40),(588,'car',-42)]:configs[n]['participants'][id]['route'][-1]=[x,J-1.75]
    # Explicit ego moves replace the previous source-image focus markers.
    steps(544,step('Xe con rẽ trái trước, xe của bạn chờ.','car'),step('Xe của bạn đi thẳng qua giao lộ.','self'))
    S(545)['learningMode']='alternatives'
    steps(545,step('Hướng 1: quay đầu qua khoảng mở của dải phân cách.','self',actions=[action('self',worldPath=[[1.75,0],[1.75,-10],[.8,-13],[-1.75,-13],[-1.75,20]])]),step('Hướng 2: tiếp tục đi thẳng.','self'),step('Hướng 3 và 4 bị cấm theo biển; không lái xe vào hai nhánh này.','signs',kind='forbidden',duration=3))
    steps(550,step('Quay đầu theo đường A, trước vị trí biển cấm.','self',duration=8),step('Không quay đầu theo đường B.','b',kind='forbidden',duration=3))
    steps(551,step('Xe của bạn rẽ trái, xe con bên trái rẽ phải; hai quỹ đạo không giao nhau.','self','car',duration=8),step('Xe tải đi sau.','truck'))
    A(552,'ahead').update(label='Xe phía sau trong gương',color='#31527c')
    steps(552,step('Quan sát xe phía sau trong gương, kiểm tra đường phía trước trước khi vượt.','mirrors',kind='focus',duration=3),step('Báo hiệu và vượt xe tải khi đường đã thoáng, trở lại làn sau xe tải.','self','truck','ahead',duration=10))
    steps(572,step('Giảm tốc, nhường xe tải qua giao lộ.','truck'),step('Tiếp tục nhường xe đạp.','cycle'),step('Xe của bạn rẽ phải sau cả hai xe.','self',duration=8))
    steps(574,step('Dừng trước STOP, nhường xe đạp.','cycle'),step('Tiếp tục nhường xe khách đi thẳng qua.','bus'),step('Xe của bạn rẽ trái sau các xe được ưu tiên.','self',duration=8))
    steps(576,step('Xe của bạn tiến chậm rồi dừng sau xe van có cửa mở.','self',duration=3),step('Nhường xe ngược chiều đi thẳng, không lấn sang làn đối diện.','opposite',duration=8))
    steps(579,step('Giảm tốc và dừng trước xe đang lùi khỏi nơi đỗ.','self',duration=3),step('Xe van lùi ra; xe của bạn tiếp tục chờ.','reverse',duration=6))
    steps(580,step('Phanh giảm tốc và đi sát bên phải phần đường của mình.','self',duration=3),step('Xe xanh hoàn tất vượt và trở lại làn ngược chiều.','overtake','yellow',duration=8))
    steps(581,step('Giảm tốc, giữ khoảng cách phía sau xe tải.','self',duration=3),step('Xi nhan trái trên thân xe tải nhấp nháy; xe tải chuyển làn rồi tiếp tục chạy.','truck',duration=10))
    steps(582,step('Quan sát gương và biển nhường đường.','mirror','sign',kind='focus',duration=3),step('Giảm tốc, đi thẳng qua giao lộ.','self',duration=8))
    steps(586,step('Xe của bạn giảm tốc, nhường trước hầm hẹp.','self',duration=3,actions=[action('self',worldPath=[[1.3,0],[1.3,-5]])]),step('Xe đối diện đi thẳng qua hầm trước.','car',duration=8),step('Sau khi xe đối diện đã qua, tiếp tục trên phần đường bên phải.','self',duration=7,actions=[action('self',worldPath=[[1.3,-5],[1.3,-55]])]))
    steps(587,step('Dừng trước vạch, nhường người đi bộ.','self',kind='wait',duration=3),step('Người đi bộ sang ngang trên vạch.','ped'),step('Người đã tới lề; xe của bạn và xe phía trước tiếp tục đi thẳng.','self','ahead-car',duration=8))
    steps(591,step('Nhường xe tải đi thẳng theo tín hiệu.','truck',duration=8),step('Xe của bạn đi sau và rẽ trái.','self',duration=8))
    steps(594,step('Hướng 2 cắt góc, không chọn.','two',kind='forbidden',duration=3),step('Hướng 1: tiến tới giữa giao lộ rồi rẽ trái trên phần đường bên phải.','self',duration=8))
    steps(595,step('Giữ đèn chiếu gần và giảm tốc, tiếp tục đi sau xe phía trước.','self','ahead','opposite',duration=10))
    steps(596,step('Xe của bạn dừng trước đường sắt, không tiến vào rào chắn.','self',kind='wait',duration=3),step('Người gác kéo rào trượt ngang qua mặt đường; không đi qua đường ray.','sliding-gate','ped',duration=8),step('Giữ xe dừng trước rào chắn.','self',kind='wait',duration=4))
    A(596,'ped')['label']='Người gác kéo rào'
    # Marker positions and participant routes for UI comparisons remain valid
    # schema data, but only worldScene routes drive the POV camera and actors.
    for n,c in configs.items():
        for id,v in c['participants'].items():
            if len(v.get('route',[]))>1:
                a=A(n,id)
                if len(a['path'])<2:a['path']=[[50,60],[110,60]]
        S(n)['note']='Cảnh 3D dựng lại theo tình huống nguồn. Camera ở vị trí người lái và di chuyển theo lượt xe của bạn. Dùng Ảnh gốc để đối chiếu bố cục/biển trong đề.'
        if S(n).get('learningMode')=='alternatives':S(n)['note']+=' Mỗi hướng là một ví dụ độc lập, camera trở về đầu khi đổi hướng.'
