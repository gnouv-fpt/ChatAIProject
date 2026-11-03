"""Vehicle annotations inspected against the original question sheets.

Only explicit motion recipes move a vehicle. Parked cars, background participants,
and vehicles waiting for the camera car keep their source position.
"""

def apply_vehicle_catalog(scenes):
    driver_questions={544,545,547,549,550,551,552,555,556,557,558,559,564,567,568,569,570,571,572,573,574,575,576,577,578,579,580,581,582,583,584,585,586,587,588,589,590,591,593,594,595,596}
    special={'broken':'car','van':'van','opposite':'car','parking':'car','reverse':'van',
             'overtake':'car','yellow':'car','ahead':'car'}
    excluded={'self','mirrors','mirror','others','tow','cycles','all','approaches','signals'}
    direction_overrides={
        496:{'bus':[1,-.5],'truck':[-1,.5],'car':[1,.6]},526:{'car':[-.5,-1]},528:{'inside':[.6,1]},
        510:{'moto':[1,-.5]},513:{'car':[.3,-1],'bus':[.3,-1]},
        527:{'car':[-1,.5],'moto':[1,-.5],'bus':[1,-.5]},
        531:{'truck':[-1,.5],'bus':[-1,.5],'car':[-1,.5],'van':[1,-.5]},
        532:{'truck':[1,-.5],'fire':[-1,-.5]},
        544:{'car':[1,0]},547:{'bus':[0,1],'truck':[-1,0]},549:{'truck':[1,0]},
        551:{'car':[1,0],'truck':[-1,0]},557:{'a':[1,0],'b':[-.2,-1],'c':[0,-1]},
        558:{'a':[0,-1],'b':[0,-1]},564:{'broken':[-1,0]},
        567:{'moto':[1,0],'car':[-1,0]},568:{'car':[-1,0],'moto':[0,1]},569:{'car':[0,1]},
        572:{'truck':[1,0],'cycle':[0,-1]},574:{'cycle':[1,0],'bus':[0,1]},
        575:{'truck':[1,0],'car':[0,1]},576:{'opposite':[0,1]},
        578:{'parking':[0,-1]},580:{'overtake':[0,1],'yellow':[0,1]},
        583:{'moto':[-1,0],'cycle':[0,1]},584:{'car':[0,1],'truck':[-1,0]},
        585:{'car':[1,0]},586:{'car':[0,1]},588:{'car':[-1,0]},
        589:{'truck':[0,1],'car':[-1,0]},591:{'truck':[0,1]},
        592:{'car':[1,-.6],'moto':[1,-.6]},593:{'truck':[1,0],'cycle':[0,1]},
        595:{'opposite':[0,1]},
    }
    exact_kinds={510:{'moto':'tricycle'},531:{'van':'van'},557:{'a':'car','b':'car','c':'car'},
                 558:{'a':'car','b':'car'},574:{'bus':'bus'},
                 578:{'parking':'car','car':'car'},579:{'reverse':'van'},
                 580:{'overtake':'car','yellow':'car'},586:{'car':'bus'}}
    for key,s in scenes.items():
        n=int(key)
        for a in s['actors']:
            if a['kind']!='marker' or a['id'] in excluded:continue
            label=a['label'].lower();kind=exact_kinds.get(n,{}).get(a['id'])
            if not kind:
                if label.startswith(('xe con','xe ô tô con')):kind='car'
                elif label.startswith(('xe mô tô','mô tô')):kind='moto'
                elif label.startswith('xe tải'):kind='truck'
                elif label.startswith(('xe khách','xe buýt')):kind='bus'
                elif label.startswith('xe chữa cháy'):kind='fire'
                elif label.startswith('xe đạp'):kind='bicycle'
                elif n>=544 and label.startswith(('xe ','đèn pha xe')):kind=special.get(a['id'])
            if not kind:continue
            x,y,w,h=a['rect'];a.update(kind=kind,at=[x+w/2,y+h/2],width=w,
                anchor='box',heading=direction_overrides.get(n,{}).get(a['id'],[0,-1] if n in driver_questions else [1,-.5]))
            if kind=='car':a['color']='#294c99'

    def box(n,id,label,kind,rect,heading=(1,-.5),color=None):
        s=scenes[str(n)];x,y,w,h=rect
        if any(a['id']==id for a in s['actors']):return
        s['actors'].append(dict(id=id,label=label,kind=kind,rect=rect,at=[x+w/2,y+h/2],
            width=w,anchor='box',heading=list(heading),color=color or ('#294c99' if kind=='car' else None),path=[]))

    # Four-lane signal family: all participants, including vehicles not highlighted
    # by the selected answer, are represented independently.
    for n in [486,500,503,538,553,560,561,562,563,565]:
        for id,label,kind,rect,direction in [
            ('bus','Xe khách','bus',[0,62,26,33],(1,-.6)),
            ('truck','Xe tải','truck',[23,69,16,23],(1,-.6)),
            ('car','Xe con','car',[33,82,12,13],(1,-.6)),
            ('far-truck','Xe tải nhánh đối diện','truck',[63,13,9,11],(-1,.6)),
            ('far-car','Xe con nhánh đối diện','car',[67,17,7,8],(-1,.6)),
            ('moto','Xe mô tô','moto',[72,18,7,12],(-1,.6))]:box(n,id,label,kind,rect,direction)
        # Rectangles in the first draft were broad hotspots rather than vehicle boxes.
        boxes={'bus':[1,63,34,36],'truck':[23,70,16,23],'car':[33,83,12,12],'moto':[72,18,7,12]}
        for a in scenes[str(n)]['actors']:
            if a['id'] in boxes and a.get('anchor')=='box':
                x,y,w,h=boxes[a['id']];a.update(rect=[x,y,w,h],at=[x+w/2,y+h/2],width=w,heading=[1,-.6] if a['id']!='moto' else [-1,.6])

    # Individual additions and split groups; rectangles are normalized image coordinates.
    entries={
      513:[('front-left','Xe tải hình trái','truck',[27,19,16,30],(.3,-1)),('front-right','Xe tải hình phải','truck',[77,19,16,30],(.3,-1))],
      515:[('tow-1','Xe tải phía sau','truck',[2,49,31,37],(1,-.4)),('tow-2','Xe tải giữa','truck',[34,27,32,46],(1,-.4)),('tow-3','Xe tải phía trước','truck',[66,12,31,47],(1,-.4))],
      518:[('tractor','Đầu kéo và sơ-mi rơ-moóc','container',[5,29,66,58],(1,-.4)),('towed','Xe tải được kéo','truck',[69,22,28,32],(1,-.4))],
      528:[('bus','Xe khách','bus',[0,56,40,37],(1,-.2)),('truck-north','Xe tải nhánh trên','truck',[26,5,22,39],(.5,1)),('car','Xe con','car',[76,37,22,18],(-1,.3)),('moto','Xe mô tô','moto',[89,70,11,29],(-.7,-1))],
      542:[('truck','Xe tải','truck',[76,35,24,25],(-1,-.4))],
      543:[('a','Xe khách A','bus',[53,30,31,36],(1,-.5)),('b','Xe tải B','truck',[12,53,24,25],(1,-.5)),('d','Mô tô D','moto',[66,69,8,12],(1,-.5))],
      548:[('a','Xe con A','car',[48,31,12,12],(1,-.5)),('b','Xe con B','car',[61,24,12,12],(1,-.5)),('c','Mô tô C','moto',[33,64,9,12],(1,-.5))],
      554:[('b','Xe con B','car',[22,33,16,15],(1,-.4)),('d','Xe tải D','truck',[11,53,27,34],(1,-.4))],
      566:[('a','Xe con A','car',[44,21,17,16],(1,-.4)),('c','Xe con C','car',[1,45,17,18],(1,-.4)),('e','Xe con E','car',[54,35,16,19],(1,-.4)),('bus','Xe buýt G','bus',[71,24,28,35],(1,-.4))],
      577:[('cycle-1','Người đi xe đạp 1','bicycle',[48,44,8,17],(0,-1)),('cycle-2','Người đi xe đạp 2','bicycle',[56,45,9,20],(0,-1)),('cycle-3','Người đi xe đạp 3','bicycle',[64,49,10,25],(0,-1)),('car-context','Xe con ngược chiều','car',[31,49,10,10],(0,1))],
      578:[('park-2','Xe đỗ bên đường','car',[72,54,10,10],(0,-1)),('park-3','Xe đỗ phía trước','car',[66,52,8,8],(0,-1))],
      579:[('parked','Xe tải đỗ','truck',[63,40,23,28],(0,-1)),('right-car','Xe con bên phải','car',[74,56,25,29],(-1,0))],
      582:[('mirror-car','Xe phía sau trong gương','car',[49,5,9,8],(0,1))],
      583:[('opposite','Xe phía trước','car',[52,48,9,9],(0,1))],
      587:[('ahead-car','Xe phía xa','van',[50,48,5,7],(0,-1))],
      589:[('right-car','Xe phía sau trong gương','car',[49,3,10,11],(0,1))],
      595:[('near-car','Xe con bên phải','car',[88,77,12,23],(0,-1))],
      592:[('train','Tàu hỏa','train',[0,0,32,34],(1,.4))],
      597:[('ahead-car','Xe phía trước trên cao tốc','bus',[60,9,16,15],(1,-.6))],
      600:[('red-car','Xe con bên kia giao lộ','car',[86,35,11,10],(-1,-.5))],
    }
    for n,items in entries.items():
        for item in items:box(n,*item)
    # Similar signal images do not contain the same far-side participants.
    for n,remove in {486:['far-car'],503:['far-car'],561:['far-truck','far-car'],562:['far-truck','far-car'],563:['moto']}.items():
        scenes[str(n)]['actors']=[a for a in scenes[str(n)]['actors'] if a['id'] not in remove]
    box(561,'far-moto-2','Mô tô nhánh đối diện 2','moto',[62,20,7,12],(-1,.6))

    # Lettered lane diagrams use tight individual vehicle boxes rather than the
    # broader answer hotspots from the original photo-only draft.
    corrected={
        543:{'a':([47,38,26,30],None),'b':([11,65,19,22],None),'c':([13,88,7,9],None),'d':([66,67,5,10],None),'e':([28,82,14,17],'#294c99')},
        548:{'a':([47,47,10,13],'#2c9d55'),'b':([63,44,10,12],'#decf31'),'c':([37,69,6,9],None),'d':([55,77,6,10],None),'e':([27,84,15,15],'#294c99')},
        554:{'a':([50,28,10,10],'#2c9d55'),'b':([25,37,10,10],'#294c99'),'c':([6,51,12,11],'#decf31'),'d':([13,51,23,27],None),'e':([55,35,11,10],'#28a9b2'),'bus':([70,20,27,28],'#e0e5e4')},
        566:{'a':([50,28,10,10],'#2c9d55'),'b':([25,37,10,10],'#294c99'),'c':([6,51,12,11],'#decf31'),'truck':([13,51,23,27],None),'e':([55,35,11,10],'#28a9b2'),'bus':([70,20,27,28],'#e0e5e4')},
        528:{'inside':([50,43,19,32],None),'truck-north':([31,4,18,38],None),'car':([80,31,17,16],'#294c99')},
        551:{'car':([2,59,17,10],'#294c99'),'truck':([70,46,24,20],None)},
        557:{'b':([67,45,28,30],'#235584'),'c':([59,47,8,10],'#235584')},
        575:{'car':([44,49,7,8],'#b31b2a'),'truck':([0,40,22,19],None)},
        576:{'opposite':([40,50,7,8],'#b31b2a')},
        577:{'car-context':([38,51,8,7],'#b31b2a')},
        578:{'car':([34,54,13,16],'#e6c930'),'parking':([67,51,29,31],'#226338'),'park-2':([59,51,12,15],'#294c99'),'park-3':([51,50,9,11],'#c2a230')},
        584:{'car':([32,47,8,10],'#b31b2a')},
        586:{'car':([43,50,11,12],'#b31b2a')},
        589:{'truck':([29,48,8,15],None),'car':([77,52,14,11],'#dbb65c')},
        527:{'car':([30,23,16,16],'#294c99'),'moto':([25,66,13,20],None),'bus':([55,23,41,47],None)},
    }
    for n,changes in corrected.items():
        for id,(rect,color) in changes.items():
            a=next(a for a in scenes[str(n)]['actors'] if a['id']==id);x,y,w,h=rect
            a.update(rect=rect,at=[x+w/2,y+h/2],width=w,anchor='box')
            if color:a['color']=color

    # These are separate alternative-lane illustrations, not simultaneous movements.
    # Show the inferred vehicle kind at a source-marked position, keeping the cue region.
    for n in [557,558]:
        for a in scenes[str(n)]['actors']:
            if a['id'] in ['a','b','c'] and a['kind']=='marker':
                x,y,w,h=a['rect'];a.update(kind='car',anchor='box',heading=[0,-1],at=[x+w/2,y+h/2],color='#235584')

    for n in driver_questions:
        scenes[str(n)]['perspective']='driver'
    for s in scenes.values():
        s['mode']='3d' if any(a['kind']!='marker' for a in s['actors']) else 'photo'
        s['vehicleCount']=sum(a['kind']!='marker' for a in s['actors'])
        if s.get('perspective')=='driver':
            s['note']=(s['note']+' ' if s['note'] else '')+'Góc nhìn người lái: xe của bạn được thể hiện bằng khoang lái trong ảnh. Chỉ dựng mô hình cho xe bên ngoài; xe chờ/đỗ giữ nguyên vị trí.'
