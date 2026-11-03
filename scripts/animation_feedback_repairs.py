"""Per-question corrections from the user's 2026-10-31 review.

Coordinates are authored against the original JPEG, not inferred from feedback
text. This runs before source tracing; repaired scenes opt out of pixel traces.
"""
import math

APPROVED={486,502,505,541,548,551,552,554,555,556,570,582}

def apply_feedback_repairs(scenes):
    def scene(n):return scenes[str(n)]
    def actor(n,id):return next(a for a in scene(n)['actors'] if a['id']==id)
    def step(text,*ids,action='move',duration=6):
        return dict(text=text,duration=duration,actions=[dict(actor=id,action=action) for id in ids])
    def steps(n,*items):scene(n)['steps']=list(items)+[scene(n)['steps'][-1]]
    def route(n,id,path):
        a=actor(n,id);a['path']=path;a['guidePath']=path;a['routeSource']='manual-review-2026-10-31'
        if a.get('anchor')!='box':a['at']=path[0]
    def box(n,id,rect,heading=None,kind=None,color=None):
        a=actor(n,id);x,y,w,h=rect
        a.update(rect=rect,sourceRect=rect,at=[x+w/2,y+h/2],width=w,anchor='box',heading=heading or a.get('heading',[0,-1]),exactHeading=True)
        if kind:a['kind']=kind
        if color:a['color']=color
        a['path']=[];a['guidePath']=[]
    def add(n,id,label,kind,rect,heading,color=None):
        scene(n)['actors'].append(dict(id=id,label=label,kind=kind,path=[],width=rect[2],at=[0,0]))
        box(n,id,rect,heading,kind,color)
    def region(n,id,rect):
        a=actor(n,id);x,y,w,h=rect;a.update(rect=rect,at=[x+w/2,y+h/2])
    def moving_box(n,id,end,via=None):
        a=actor(n,id);route(n,id,[a['at']]+(via or [])+[end]);a['headingFromPath']=True
    def ego(n,path):
        if not any(a['id']=='self' for a in scene(n)['actors']):
            scene(n)['actors'].append(dict(id='self',label='Hướng xe của bạn',kind='marker',at=path[0],width=6,path=[]))
        a=actor(n,'self');a.update(path=path,guidePath=path,at=path[0],ego=True)

    for key,s in scenes.items():
        if int(key) in APPROVED:continue
        s.update(motionVersion=2,mode='3d',note='Bản sửa theo ghi chú ngày 31/10: cần bạn duyệt lại trên ảnh gốc.')
        # Vehicle boxes use their own measured orientation, not the nearest of
        # two global intersection axes (which breaks side views and curved roads).
        for a in s['actors']:
            a['exactHeading']=True
            if a.get('rect') and a['kind']!='marker':a['sourceRect']=a['rect'][:]
        if s.get('perspective')=='driver':
            s['note']+=' Khoang lái vẫn là xe của bạn; chấm hướng đi chỉ xuất hiện khi xe của bạn được phép tiến.'

    # Straight lanes: two endpoints prevent accumulated annotation noise.
    straight={
      487:{'truck':[[92,76],[26,13]],'bus':[[83,23],[-18,75]]},
      488:{'police':[[21,33],[95,103]],'car':[[89,79],[16,15]],'truck':[[74,32],[-18,86]]},
      489:{'police':[[86,85],[18,12]],'truck':[[74,29],[-18,80]]},
      490:{'car':[[52,23],[-18,100]]},
      492:{'moto':[[91,78],[14,14]]},
      493:{'a':[[23,62],[116,13]],'b':[[88,75],[14,9]]},
      494:{'fire':[[86,64],[4,7]],'ambulance':[[56,16],[-18,76]]},
      495:{'ambulance':[[87,72],[12,11]]},
      497:{'truck':[[84,71],[11,10]],'car':[[11,79],[100,10]]},
      498:{'police':[[11,72],[78,1]]},
      499:{'car':[[18,81],[110,16]]},
      501:{'army':[[85,68],[14,11]]},
      506:{'b':[[88,69],[14,8]],'truck':[[74,23],[-18,75]]},
      516:{'bus':[[80,80],[26,-8]],'truck':[[36,17],[103,120]]},
      533:{'bus':[[15,69],[102,1]]},
      536:{'police':[[74,23],[-18,83]],'car':[[90,77],[16,7]]},
      540:{'army':[[85,66],[15,10]],'car':[[67,28],[-18,75]],'moto':[[59,23],[-12,85]]},
      546:{'a':[[26,65],[-18,90]]},
    }
    for n,paths in straight.items():
        for id,path in paths.items():route(n,id,path)

    # Explicit turn centers, clear exit lanes and corrected source directions.
    corrections={
      487:{'moto':[[27,26],[44,45],[54,48],[90,28]],'car':[[10,74],[42,56],[53,46],[52,40],[31,19]]},
      490:{'moto':[[6,35],[39,52],[49,51],[57,43],[84,0]],'truck':[[88,56],[52,42],[44,43],[35,51],[-18,110]]},
      525:{'moto':[[89,75],[56,48],[48,45],[37,47],[-18,78]],'car':[[73,25],[-18,78]]},
      520:{'moto':[[74,29],[-18,66]],'cycle':[[69,26],[-18,63]],'a':[[87,74],[20,10]],'b':[[13,73],[36,59],[51,49],[55,41],[51,35],[46,38],[45,47],[52,60],[93,100]]},
      529:{'truck':[[90,57],[50,40],[8,17]]},
      530:{'truck':[[37,56],[58,43],[65,31],[59,23],[28,0]]},
      536:{'truck':[[26,27],[46,49],[54,51],[99,24]],'bus':[[11,85],[44,61],[50,51],[47,44],[40,43],[10,66]]},
      597:{'blue':[[15,50],[99,0]]},
      598:{'truck':[[78,31],[115,3]],'blue':[[39,65],[44,50],[53,43],[96,11]]},
      599:{'blue':[[88,24],[117,3]],'yellow':[[54,42],[66,34],[78,32],[105,13]]},
      600:{'container':[[44,53],[58,39],[67,39],[85,53],[118,75]]},
    }
    for n,paths in corrections.items():
        for id,path in paths.items():route(n,id,path)
    actor(520,'cycle')['width']=6
    # Alternative legal directions are independent demonstrations, never a jump
    # from one exit back across the intersection while another vehicle moves.
    for n in [507,514,519,521,522,523,524,535,537,539]:scene(n)['learningMode']='alternatives'
    steps(517,step('Xe con chờ; mô tô được quyền đi trước theo đáp án nguồn.','car',action='wait'),step('Xe mô tô đi trước.','moto'),step('Xe con đi sau khi mô tô đã ra khỏi giao lộ.','car'))
    steps(525,step('Xe con nhường đường.','car',action='wait'),step('Mô tô rẽ theo mũi tên trong đề và đi trước.','moto'),step('Xe con đi sau khi mô tô đã ra khỏi giao lộ.','car'))
    for n in [511,512]:
        for st in scene(n)['steps']:
            for action in st['actions']:
                if action['action']=='forbidden':
                    st['text']='Xe đứng yên: '+st['text']+' Đường đỏ chỉ hướng bị cấm, không phải lượt được đi.'
                    action['verdict']='invalid'
    # 496 asks only who goes last: preceding participants are shown together.
    route(496,'car',[[18,32],[37,50],[48,52],[88,34]])
    route(496,'truck',[[83,29],[-18,75]])
    route(496,'bus',[[12,79],[45,59],[52,48],[47,41],[21,17]])
    steps(496,step('Xe khách chờ hai xe còn lại qua giao lộ.','bus',action='wait'),step('Minh họa hai xe còn lại đi trước; không đặt thêm thứ tự ưu tiên giữa chúng.','car','truck'),step('Xe khách đi cuối cùng.','bus'))
    for n,id,h in [(509,'truck',[-1,.4]),(509,'car',[1,-.4]),(518,'tractor',[-1,.5]),(518,'towed',[-1,.5]),(531,'car',[1,-.65]),(527,'bus',[1,-.5]),(543,'a',[1,-.55])]:
        actor(n,id)['heading']=h
    box(509,'car',[9,56,27,24],[1,-.4])
    box(526,'car',[68,60,22,30],[-.62,-1])
    box(531,'car',[62,41,13,16],[1,-.65])
    box(532,'truck',[2,56,24,28],[1,-.5]);box(532,'fire',[69,47,31,27],[-1,-.5])
    box(542,'car',[0,65,23,31],[1,-.55]);box(542,'truck',[75,36,25,26],[-1,-.55])
    # Keep real tow connections visible. Their endpoints follow model geometry.
    scene(510)['connections']=[['truck','moto']]
    scene(515)['connections']=[['tow-1','tow-2'],['tow-2','tow-3']]
    scene(518)['connections']=[['tractor','towed']]
    scene(518)['note']='Đầu kéo, sơ-mi rơ-moóc và xe được kéo có khớp/dây nối riêng để đối chiếu.'
    for n in [510,515,518]:
        for st in scene(n)['steps']:
            if st['actions']:st['text']+=' Dây nối màu vàng thể hiện liên kết kéo.'
    for id in ['car','bus']:
        a=actor(513,id);a['heading']=[.45,-1];a['exactHeading']=True
    # Leave the sign face clear and pass the truck before merging back right.
    # sourceRect still describes the original vehicle for background removal.
    actor(513,'car').update(rect=[0,55,13,36],at=[6.5,73],width=13)
    actor(513,'bus')['at']=[61,70]
    moving_box(513,'car',[43,-12],[[14,50],[20,30],[25,15],[33,6]])
    moving_box(513,'bus',[94,-12],[[65,49],[68,31],[74,15],[84,6]])
    steps(513,step('Hai xe vượt về bên trái, trở lại làn sau khi đã qua xe phía trước.','car','bus',duration=9))
    moving_box(528,'inside',[76,110])
    steps(528,step('Tất cả xe chưa vào ngã tư dừng lại.','bus','truck-north','car','moto',action='wait'),step('Xe tải đã ở trong ngã tư tiếp tục thoát khỏi giao lộ.','inside'))
    # Each signal diagram has its own legal set and arrow geometry.
    signal_valid={500:['car','truck'],503:['car'],538:['car','truck','bus','far-truck','far-car','moto'],553:['bus','far-truck','far-car','moto'],560:['car','bus','far-truck','far-car','moto'],561:['car','moto','far-moto-2'],562:['car'],563:['car','far-truck'],565:['bus','moto']}
    for n,ids in signal_valid.items():
        if n==563:scene(n)['actors']=[a for a in scene(n)['actors'] if a['id']!='far-car']
        valid=[id for id in ids if any(a['id']==id for a in scene(n)['actors'])]
        paths={
          'car':[[39,89],[53,66],[61,65],[101,103]],
          'truck':[[31,82],[81,3]],
          'bus':[[17,81],[43,44],[45,36],[25,13]],
          'far-truck':[[67,20],[58,33],[57,43],[97,99]],
          'far-car':[[71,22],[47,74],[42,100]],
          'moto':[[75,25],[59,48],[51,67],[44,100]],
          'far-moto-2':[[65,26],[57,42],[59,54],[94,93]],
        }
        if n in [500,538,553]:
            paths['bus']=[[17,81],[43,44],[61,26],[96,51]]
        if n==560:paths['bus']=[[17,81],[45,44],[52,32],[42,24],[12,55]]
        if n==565:
            paths['bus']=[[17,81],[44,44],[48,34],[41,28],[30,21]]
            paths['moto']=[[75,25],[58,44],[56,53],[95,99]]
        moving=[]
        for id in valid:
            a=actor(n,id)
            # Start at the source vehicle's box center, not its old broad hotspot.
            path=paths[id];path[0]=a['at'][:];route(n,id,path);a['headingFromPath']=True
            moving.append(step('Minh họa lượt của '+a['label'].lower()+' chấp hành đúng; các xe vi phạm giữ nguyên vị trí.',id))
        existing=scene(n)['steps'][:-1]
        steps(n,*existing,*moving)
    # Correct the extra far motorcycle and retain all non-vehicle signal pixels.
    box(561,'far-moto-2',[61,17,7,13],[-1,.6])
    moving_box(561,'far-moto-2',[100,101],[[56,41],[58,52]])
    steps(566,*scene(566)['steps'][:-1],step('Xe con C cũng chấp hành đúng; A, C, E và xe buýt G không thuộc nhóm vi phạm.','a','c','e','bus',action='focus'))

    # Driver-view rectangles: use the visible vehicle, never its sign/arrow label.
    driver_boxes={
      544:{'car':([16,47,19,11],[1,0])},
      547:{'bus':([35,36,11,18],[0,1]),'truck':([55,34,19,21],[-1,0])},
      549:{'truck':([0,43,10,20],[1,0])},
      557:{'a':([4,52,17,12],[1,0]),'b':([69,47,23,27],[0,-1]),'c':([61,48,7,9],[0,-1])},
      558:{'a':([68,53,32,27],[0,-1]),'b':([58,48,9,10],[0,-1])},
      559:{'car':([50,68,18,32],[0,1]),'moto':([62,60,5,12],[0,-1])},
      564:{'broken':([45,50,15,13],[-1,0])},
      567:{'moto':([10,49,10,13],[1,0]),'car':([63,50,12,11],[-1,0])},
      568:{'car':([76,54,23,13],[-1,0]),'moto':([39,55,3,8],[0,1])},
      569:{'car':([49,47,7,12],[0,1])},
      572:{'truck':([0,35,34,28],[1,0]),'cycle':([75,56,8,26],[0,-1])},
      573:{'car':([52,48,15,14],[0,-1])},
      574:{'cycle':([31,54,5,13],[1,0]),'bus':([38,46,9,16],[0,1])},
      576:{'van':([52,46,15,22],[0,-1]),'opposite':([42,52,4,5],[0,1])},
      577:{'cycle-1':([48,44,7,19],[0,-1]),'cycle-2':([54,42,7,21],[0,-1]),'cycle-3':([60,48,10,29],[0,-1])},
      579:{'reverse':([46,45,19,16],[.8,.1]),'parked':([59,46,30,24],[1,.1]),'right-car':([70,58,30,24],[-1,0])},
      580:{'overtake':([46,49,3,5],[0,1]),'yellow':([41,50,4,5],[0,1])},
      581:{'truck':([52,29,35,36],[0,-1])},
      583:{'cycle':([37,50,4,13],[1,0]),'moto':([60,50,10,13],[-1,0])},
      584:{'truck':([80,37,20,22],[-1,0])},
      585:{'car':([2,48,18,11],[1,0])},
      586:{'car':([43,51,8,9],[0,1])},
      587:{'ahead-car':([45,51,5,7],[0,-1])},
      588:{'car':([76,52,10,8],[-1,0])},
      591:{'truck':([43,40,9,15],[0,1])},
      592:{'moto':([54,49,8,21],[1,-.6])},
      593:{'truck':([0,40,24,24],[1,0]),'cycle':([55,50,4,13],[0,1])},
      595:{'opposite':([39,44,9,18],[0,1]),'ahead':([54,58,9,9],[0,-1])},
    }
    for n,items in driver_boxes.items():
        for id,(rect,heading) in items.items():box(n,id,rect,heading)
    actor(580,'overtake')['color']='#1f88cf';actor(580,'yellow')['color']='#efd032'
    actor(586,'car').update(kind='car',label='Xe con đối diện',color='#b31b2a')
    for n,id,rect in [(545,'one',[20,61,18,8]),(545,'two',[48,49,5,37]),(549,'sign',[43,34,12,22]),(550,'a',[36,66,20,5]),(550,'b',[36,74,20,5]),(571,'light',[72,14,9,24]),(574,'stop',[68,48,9,25]),(591,'light',[88,6,8,24]),(594,'one',[36,68,22,13]),(594,'two',[32,67,13,12])]:region(n,id,rect)

    # Animate external participants in the order already given by the source.
    movements={544:{'car':([112,56],None)},547:{'bus':([-15,83],[[37,63]]),'truck':([-20,55],None)},549:{'truck':([114,55],None)},567:{'moto':([112,58],None),'car':([-18,55],None)},568:{'car':([-20,61],None),'moto':([112,66],[[42,66]])},572:{'truck':([120,58],None),'cycle':([60,38],None)},573:{'car':([108,52],[[65,53]])},574:{'cycle':([115,68],None),'bus':([43,108],None)},575:{'car':([-20,88],[[34,66]])},576:{'opposite':([35,110],None)},580:{'overtake':([54,100],[[49,64]])},581:{'truck':([44,45],[[57,51]])},583:{'cycle':([110,62],None),'moto':([-18,61],None)},584:{'car':([-18,70],None),'truck':([-18,56],None)},585:{'car':([116,55],None)},586:{'car':([48,100],None)},588:{'car':([-15,63],None)},589:{'truck':([-15,75],[[25,66]]),'car':([-15,62],None)},591:{'truck':([-15,70],[[42,59]])},593:{'truck':([115,56],None),'cycle':([115,71],[[60,65]])},595:{'opposite':([22,100],None),'ahead':([59,48],None)}}
    for n,items in movements.items():
        for id,(end,via) in items.items():moving_box(n,id,end,via)
    ego_paths={544:[[50,77],[50,56],[50,41]],545:[[50,85],[50,50]],547:[[50,82],[48,62],[36,59],[10,66]],549:[[50,77],[50,65],[65,64],[92,65]],567:[[48,78],[48,55],[49,40]],568:[[48,79],[47,54],[48,40]],569:[[48,78],[55,66],[68,61],[91,60]],572:[[48,82],[50,68],[64,64],[91,66]],573:[[48,77],[49,68],[62,65],[91,65]],574:[[49,86],[49,67],[34,65],[14,69]],575:[[49,80],[49,59],[50,48]],583:[[51,76],[49,63],[38,62],[20,69]],584:[[50,76],[48,63],[33,61],[9,64]],585:[[49,78],[49,58],[50,43]],587:[[49,76],[49,59],[49,44]],588:[[52,73],[47,65],[34,61],[11,64]],589:[[53,76],[48,65],[32,63],[13,72]],590:[[51,75],[55,65],[63,58],[75,54]],593:[[49,77],[49,58],[50,43]],594:[[55,81],[52,72],[43,68],[33,71]],596:[[50,86],[50,79]]}
    for n,path in ego_paths.items():ego(n,path)
    sequences={
      544:[('car',),('self',)],547:[('bus',),('truck',),('self',)],549:[('truck',),('self',)],
      567:[('moto',),('car',),('self',)],568:[('car',),('self',),('moto',)],569:[('self',)],
      572:[('truck','cycle'),('self',)],573:[('ped',),('car',),('self',)],574:[('cycle','bus'),('self',)],575:[('car','self')],
      576:[('opposite',)],580:[('overtake',)],581:[('truck',)],583:[('cycle',),('moto',),('self',)],584:[('self',),('car',),('truck',)],585:[('car',),('self',)],586:[('car',)],587:[('ped',),('self',)],588:[('self',),('car',)],589:[('truck',),('car',),('self',)],590:[('self',)],591:[('truck',)],593:[('self',),('truck',),('cycle',)],594:[('self',)],595:[('opposite','ahead')],596:[('self',)]}
    # Pedestrians use an articulated walking rig, cyclists have seated riders.
    for n,rect,end in [(573,[68,45,4,16],[47,61]),(587,[33,48,4,14],[70,61])]:
        box(n,'ped',rect,[1,0],kind='pedestrian');moving_box(n,'ped',end)
    # Pass in front of the waiting blue car, then reach the sidewalk before
    # either car advances. Stopping at [47,67] left the pedestrian in ego's path.
    route(573,'ped',[[70,53],[70,56],[46,56],[30,50],[14,49]])
    route(587,'ped',[[35,55],[70,61],[80,57]])
    for n,groups in sequences.items():
        old=[s for s in scene(n)['steps'][:-1] if any(a['action'] in ['wait','forbidden'] for a in s['actions'])]
        items=[step('Lượt '+str(i+1)+': '+', '.join(actor(n,id)['label'].lower() for id in ids)+'.',*ids) for i,ids in enumerate(groups)]
        steps(n,*old,*items)
    # Highlight direction choices explicitly, not a large rectangle across lanes.
    actor(545,'one')['path']=[[50,85],[49,65],[30,62],[20,66]]
    actor(545,'two')['path']=[[50,85],[50,49]]
    steps(545,step('Hướng 1: rẽ trái theo nhánh gần, được phép.','one'),step('Hướng 2: đi thẳng, được phép.','two'),step('Các nhánh 3 và 4 có biển cấm; không chọn các nhánh này.','signs',action='forbidden'))
    scene(545)['learningMode']='alternatives'
    actor(550,'a')['path']=[[56,86],[54,70],[43,70],[36,74]]
    actor(550,'b')['path']=[[56,86],[53,78],[43,77],[36,80]]
    steps(550,step('Quay đầu theo đường A, trước vị trí biển cấm.','a'),step('Đường B không thuộc đáp án đúng.','b',action='forbidden'))
    # Visible vehicle signals, rear cargo doors, and walking/cycling actors.
    actor(559,'car')['signal']='left';actor(559,'moto')['signal']='left'
    actor(581,'truck')['signal']='left';actor(595,'opposite')['headlights']=True
    actor(576,'van')['openRearDoors']=True
    # This source depicts a sliding gate, not a lifting boom.
    add(596,'sliding-gate','Rào chắn đang đóng','barrier',[22,54,54,13],[1,0])
    actor(596,'sliding-gate').update(heading=[0,-1],fixedHeading=True)
    route(596,'sliding-gate',[[8,60.5],[49,60.5]])
    box(596,'ped',[43,49,6,20],[1,0],kind='pedestrian')
    moving_box(596,'ped',[77,60])
    actor(596,'ped')['color']='#3d59a1'
    steps(596,step('Xe của bạn giảm tốc, dừng trước đường sắt.','self'),step('Rào chắn đang trượt đóng; người gác đường đi về phía lề.','sliding-gate','ped',duration=8),step('Tiếp tục dừng chờ, không vượt qua rào chắn.','self',action='wait'))
    # Container family: every source motorcycle is a separate waiting actor.
    box(600,'moto',[18,75,9,15],[1,-.7])
    add(600,'moto-near','Mô tô sát lề','moto',[10,86,9,13],[1,-.7])
    add(600,'moto-far','Mô tô bên kia giao lộ','moto',[62,0,6,8],[-1,.7])
    actor(600,'container')['articulated']=True
    steps(600,step('Xe xanh và hai mô tô phía sau giảm tốc, chờ; không vượt hai bên container.','blue','moto','moto-near',action='wait'),step('Container rẽ phải, rơ-moóc đi theo khớp kéo.','container',duration=10),step('Container đã rẽ xong, xe xanh và mô tô mới tiếp tục.','blue','moto','moto-near'))
    moving_box(600,'moto',[91,30],[[50,60]])
    moving_box(600,'moto-near',[87,35],[[46,66]])
    steps(597,*scene(597)['steps'][:-1],step('Xe trên cao tốc tiếp tục đi; xe đỏ giữ nguyên vì đường nhập làn trong đề sai.','blue'))
    steps(598,step('Xe đỏ chờ, không vượt nối khi xe xanh đang vượt.','red',action='wait'),step('Xe xanh vượt xe tải; xe đỏ tiếp tục chờ.','blue','truck',duration=8))

    # Rechecked against the original source frames on 2026-11-01. Broad answer
    # hotspots are not the physical vehicle boxes (notably the four in Q531).
    for id,rect,heading in [
        ('truck',[50,13,24,33],[-1,.5]),('bus',[17,41,25,29],[-1,.5]),
        ('car',[62,32,12,15],[1,-.6]),('van',[80,15,17,23],[1,-.5])]:box(531,id,rect,heading)
    actor(557,'b')['heading']=[-1,-.35]
    actor(558,'a')['heading']=[-1,-.35]
    region(558,'sign',[68,39,7,12])
    actor(559,'car')['heading']=[0,-1]
    actor(569,'car')['color']='#39823f'
    actor(579,'parked')['heading']=[-1,-.25]
    box(587,'ahead-car',[48,49,4,7],[0,-1])
    box(592,'moto',[53,47,8,16],[.55,-1])
    scene(592)['foregroundRegions']=[[[58.8,58.5],[63.2,74.8],[52.7,72.5]]]

    # A vehicle approaching the camera passes beside it, rather than driving
    # through the dashboard. Its measured initial box remains the scale anchor.
    approaches={
        574:('bus',[-35,83],[[39,63],[20,72]],39,5),
        576:('opposite',[-35,76],[[38,59],[23,66]],43,7),
        580:('overtake',[-35,67],[[44,55],[35,59],[15,61]],44,7),
        586:('car',[-35,78],[[42,63],[20,70]],44,6),
        591:('truck',[-40,75],[[42,59],[20,68]],35,5),
        595:('opposite',[-35,80],[[33,63],[10,72]],42,6),
    }
    for n,(id,end,via,horizon,maximum) in approaches.items():
        moving_box(n,id,end,via);actor(n,id)['depthScale']=dict(horizon=horizon,max=maximum)
    moving_box(572,'cycle',[56,46],[[73,60],[60,50]])
    actor(572,'cycle')['depthScale']=dict(horizon=40,max=4)
    # Finish the merge on the visible carriageway. A fixed cockpit image has
    # its horizon near 49%; a route ending at y=23 made the truck fly into sky.
    moving_box(581,'truck',[48,43],[[59,44],[51,43.5]])
    actor(581,'truck')['depthScale']=dict(horizon=18,max=2)
    actor(595,'ahead')['depthScale']=dict(horizon=42,max=3)
    moving_box(596,'ped',[80,53])
    scene(596)['captionAvoidRects']=[[74,32,25,24]]
    # The officer in Q528 is right of the centre truck. Its old broad hotspot
    # restored the source truck after the animated truck had already left.
    region(528,'officer',[65,26,6,35])
    region(549,'sign',[54.7,36,11.2,15])
    # Q594's legal turn reaches the far corner; the near diagonal is direction 2.
    region(594,'one',[52.7,66.5,5.4,13.5])
    region(594,'two',[37,70.2,14,7.5])
    actor(594,'two')['path']=[[56,79],[43,75],[38,74],[44,69],[48,67]]
    ego(594,[[56,79],[55.5,69],[54,67],[48,67],[43,67]])
    actor(594,'self')['label']='Hướng 1 · rẽ trái'
    steps(594,dict(text='Hướng 1 đi đến giữa giao lộ rồi rẽ trái; hướng 2 cắt góc, không chọn.',duration=4,actions=[dict(actor='one',action='focus'),dict(actor='two',action='forbidden')]),step('Đi theo hướng 1, tới giao lộ rồi mới rẽ trái.','self'))

    # Keep foreground cockpit pixels in front of moving models. The common
    # steering-wheel family differs from the flat dashboard/mirror family.
    wheel=[[0,100],[0,74],[5,66],[12,61],[21,59],[30,62],[37,69],[43,78],[100,80],[100,100]]
    for n,s in [(int(k),v) for k,v in scenes.items() if v.get('perspective')=='driver' and v.get('motionVersion')==2]:
        if n in {583,584,588,589,590,591,593,594,595}:
            s['foregroundRegions']=[[[0,79],[15,79],[30,77],[70,77],[85,79],[100,79],[100,100],[0,100]]]
        elif n==586:s['foregroundRegions']=[[[0,72],[100,72],[100,100],[0,100]]]
        elif n!=559:s['foregroundRegions']=[wheel]
    for n,id,text in [(549,'sign','Đối chiếu biển nhường đường trước khi rẽ.'),(574,'stop','Dừng trước biển STOP, nhường các xe đi trước.'),(591,'light','Đối chiếu đủ ba đèn của tín hiệu giao thông.')]:
        steps(n,step(text,id,action='focus',duration=3),*scene(n)['steps'][:-1])
    for n,direction,at in [(511,1,[79,29]),(512,3,[26,31])]:
        scene(n)['note']=f'Câu hỏi yêu cầu tìm hướng KHÔNG được đi. Chỉ hướng {direction} bị cấm theo đáp án gạch chân; xe đứng yên, đường đỏ minh họa hướng bị cấm.'
        actor(n,'vehicle')['color']='#294c99'
        for st in scene(n)['steps']:
            for action in st['actions']:
                if action['action']=='forbidden':action.update(caption=f'Hướng {direction} · KHÔNG ĐƯỢC ĐI',captionAt=at)
    for n in [507,514,519,521,522,523,524,535,537,539]:
        scene(n)['note']='Minh họa từng hướng độc lập. Xe trở về vị trí đầu khi chuyển sang hướng kế tiếp; không phải các lượt xe chạy nối nhau.'
    # Exit fully before the next priority step, never stop in the conflict area.
    for key,s in scenes.items():
        if int(key) in APPROVED:continue
        if s.get('perspective')!='driver':
            for st in s['steps']:
                for action in st['actions']:
                    if action['action']!='move' or action.get('stopAt')==0:continue
                    a=actor(int(key),action['actor']);path=action.get('path',a['path'])
                    if len(path)<2:continue
                    x,y=path[-1];p=path[-2];dx,dy=x-p[0],y-p[1];length=math.hypot(dx,dy)
                    margin=max(18,a.get('width',0),max(a.get('rect',[0,0,0,0])[2:]))+8
                    if length and -margin<x<100+margin and -margin<y<100+margin and a['kind']!='marker':
                        ux,uy=dx/length,dy/length
                        ts=[(edge-value)/direction for edge,value,direction in [(-margin,x,ux),(100+margin,x,ux),(-margin,y,uy),(100+margin,y,uy)] if abs(direction)>1e-8 and (edge-value)/direction>0]
                        t=min(ts);path.append([round(x+ux*t,3),round(y+uy*t,3)])
                    if action.get('path'):action['guidePath']=path
                    else:a['guidePath']=path
        s['vehicleCount']=sum(a['kind']!='marker' for a in s['actors'])
        s['mode']='3d'
