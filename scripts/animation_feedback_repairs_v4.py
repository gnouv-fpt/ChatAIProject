"""13 review corrections plus one shared real-car cockpit for every POV scene."""
import copy
import hashlib
import json


def apply_feedback_v4(scenes,root):
    bank=root/'content-animations/bank-review'
    feedback=json.loads((bank/'review-feedback-v4-input.json').read_text(encoding='utf8'))
    baseline=json.loads((bank/'review-baseline-v4.json').read_text(encoding='utf8'))['scenes']
    scenes.clear();scenes.update(copy.deepcopy(baseline))
    flagged={r['number'] for r in feedback['records'] if r['status']=='changes'}
    pov={int(n) for n,s in scenes.items() if s.get('perspective')=='driver'}
    changed=flagged|pov
    def S(n):return scenes[str(n)]
    def A(n,id):return next(a for a in S(n)['actors'] if a['id']==id)
    def path(n,id,points):
        a=A(n,id);a.update(path=points,guidePath=points,at=points[0])
    def step(text,*ids,kind='move',duration=6,actions=None):return dict(text=text,duration=duration,actions=actions if actions is not None else [dict(actor=id,action=kind) for id in ids])
    def steps(n,*items):S(n)['steps']=list(items)+[baseline[str(n)]['steps'][-1]]
    def source_sign(crop,shape='triangle-up',at=(5.1,-21),**extra):return dict(crop=crop,shape=shape,at=list(at),**extra)
    # Preserve the user's source-arrow priority, tightening only the truck arc.
    path(504,'truck',[[7,72],[28,62],[48,62],[64,58],[74,49],[76,38],[72,28],[67,21],[65.5,14],[65.5,-35]])
    one=[[20,80],[33,59],[43,51],[53,51],[70,59],[94,69],[138,88]]
    five=A(523,'vehicle')['path']
    S(523)['learningMode']='alternatives'
    steps(523,step('Đối chiếu biển cấm trong đề.','sign',kind='focus',duration=3),step('Hướng 1: rẽ phải theo nét đỏ.',actions=[dict(actor='vehicle',action='move',path=one,guidePath=one)],duration=7),step('Hướng 5: ví dụ độc lập, quay đầu theo nét đỏ.',actions=[dict(actor='vehicle',action='move',path=five,guidePath=five)],duration=8))
    S(531).pop('sourceGuides',None)
    # Source arrows begin at the leading axle, not at the body-box centre.
    for id in ['bus','truck','car']:A(534,id)['routeAnchor']='front-axle'
    path(534,'bus',[[31,57],[39,50],[47,47],[53,48],[62,53],[77,63],[140,109]])
    A(534,'truck')['width']=20
    path(534,'truck',[[80,44],[74,39],[68,34],[66,29],[68,25],[76,19],[140,-34]])
    path(534,'car',[[57,23],[50,27],[46,33],[46,38],[52,43],[66,53],[140,108]])
    for st in S(538)['steps']:
        for a in st['actions']:
            if a['actor']=='moto':a['action']='wait';a.pop('startAt',None)
    A(538,'moto')['guidePath']=[]
    S(538)['steps'][0]['text']='Mô tô đứng yên. Xe khách tiến tới vạch dừng; các xe có hướng được phép tiếp tục đi.'
    for st in S(560)['steps']:
        for a in st['actions']:
            if a['actor'] in ['bus','moto'] and a['action']=='move':a['action']='wait';st['text']='Xe khách và mô tô đứng yên, chờ tín hiệu theo nhận xét.'
    for id in ['bus','moto']:A(560,id)['guidePath']=[]
    bg=S(561)['cleanBackground'];file=root/'content-animations/clean-plates/q561-v4.webp'
    bg.update(url='clean-plates/q561-v4.webp',sha256=hashlib.sha256(file.read_bytes()).hexdigest(),editNote='Built-in ImageGen removed both original distant motorcycles; original question image remains unchanged.')
    A(562,'moto').update(at=[68.8,25.2],path=[],guidePath=[],heading=[-1,.55],exactHeading=True)
    path(597,'red',[[34,78],[41,58],[48,44],[138,-13]])
    path(599,'red',[[36,75],[93,23.7]])

    # Eleven photo-cabin scenes now use the same world/cockpit renderer, while
    # keeping their accepted wait/focus behaviour and immutable Original mode.
    def spec(at,heading=1.5707963267948966):return dict(at=at,heading=heading,scale=1)
    new={
      555:dict(participants={'truck':spec([1.75,-14])}),
      556:dict(participants={'moto':spec([2.6,-11])},sourceSigns=[source_sign([65.7,34.2,8,13.3],'triangle-down')]),
      557:dict(participants={'a':spec([-2.75,-18]),'b':spec([2.75,-11]),'c':spec([2.75,-35])},sourceSigns=[source_sign([66.4,28.9,6.4,11.6],'circle',at=(5.1,-22))]),
      558:dict(type='straight',participants={'a':spec([2.75,-11]),'b':spec([2.75,-34])},sourceSigns=[source_sign([68,39,7,12],'circle',at=(5.1,-22))]),
      559:dict(participants={'car':spec([1.75,-10]),'moto':spec([2.5,-21])},sourceSigns=[source_sign([61.6,45.4,7.5,13.7],'circle',at=(5.1,-21))]),
      564:dict(type='straight',participants={'broken':spec([2,-15],3.141592653589793)}),
      570:dict(sameDirection=True,participants={},laneChoices=True,egoRoute=[[-1.75,0]],lights=[dict(at=[5,-20],state='green')]),
      571:dict(sameDirection=True,participants={},laneChoices=True,egoRoute=[[-1.75,0]],lights=[dict(at=[5,-20],state='red')],rightGreen=True),
      577:dict(type='straight',participants={'cycle-1':spec([2.3,-14]),'cycle-2':spec([1.8,-20]),'cycle-3':spec([2.5,-26]),'car-context':spec([-1.75,-32],-1.5707963267948966)}),
      578:dict(type='straight',sameDirection=True,participants={'parking':spec([2.75,-14]),'car':spec([-1.75,-18]),'park-2':spec([2.75,-23]),'park-3':spec([2.75,-32])}),
      590:dict(type='straight',participants={},curvedRoad=[[0,50],[0,0],[0,-12],[5,-25],[14,-40],[14,-270]],egoRoute=[[1.75,0],[1.75,-12],[6.75,-25],[15.75,-40],[15.75,-75]]),
    }
    for n,c in new.items():
        c.setdefault('egoRoute',[[1.75,0]]);c.setdefault('type','junction');c.update(junction=-24,seed=n,markers={})
        S(n)['worldScene']=c
        if not any(a['id']=='self' for a in S(n)['actors']):S(n)['actors'].append(dict(id='self',kind='marker',label='Xe của bạn',at=[50,80],width=6,path=[[50,80],[50,20]]))
        for a in S(n)['actors']:
            if a['kind']=='marker' and a['id']!='self':
                c['markers'][a['id']]=[1.75,1.82,-.9] if a['id'] in ['mirrors','mirror'] else [0,1.5,-20]
        if n in [555,556]:c['markers']['cross']=[1.75,.15,-19]
        if n in [570,571]:c['markers'].update(light=[5,3.5,-20],stop=[-1.75,.1,-16.5],arrows=[-1.75,.1,-12],straight=[-1.75,.1,-12],left=[-2.5,.1,-13],right=[1.75,.1,-12])
    S(544)['worldScene'].update(sideJunction='left',sourceSigns=[source_sign([61.3,18.3,13.2,20])],signs=[])
    S(551)['worldScene'].update(sourceSigns=[source_sign([61,41.6,7.2,12.4])],signs=[])
    S(569)['worldScene'].update(island=[[-.2,-27],[1.2,-28],[8,-27.4],[10,-26.3],[9,-25.2],[1,-25.5]],islandGrass=True,lights=[dict(at=[.7,-26.3],state='red')])
    for n in pov:
        w=S(n)['worldScene'];w['egoModel']=True;w['cockpitVersion']='blue-hatchback-v1'
        S(n)['note']='Cùng model xe POV màu xanh và camera ở vị trí người lái. Bối cảnh 3D dựng lại; chọn Ảnh gốc để đối chiếu đề.'
    for n in changed:
        s=S(n);s.update(rendererVersion=4,motionVersion=2,status='draft')
        s['reviewChangeKind']='marked-fix-and-cockpit' if n in flagged and n in pov else 'marked-fix' if n in flagged else 'cockpit-consistency'
        if n not in pov:s['note']='Bản sửa theo JSON xuất 18:37 ngày 01/11. Ghi chú và dấu của người dùng được giữ nguyên; chờ xác nhận.'
    digest=hashlib.sha256()
    for name in ['review-player-v4.js','review-pov-v4.js']:
        digest.update(name.encode());digest.update((root/'content-animations'/name).read_bytes())
    for n in changed:
        s=S(n);s['rendererRevision']=digest.hexdigest()[:16];s['vehicleCount']=sum(a['kind']!='marker' for a in s['actors'])
        s['revision']=hashlib.sha256(json.dumps({k:v for k,v in s.items() if k!='revision'},ensure_ascii=False,sort_keys=True).encode()).hexdigest()[:16]
