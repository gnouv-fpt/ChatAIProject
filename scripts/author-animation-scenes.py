"""Manually authored draft cues for all 115 source images; no generated image edits."""
import hashlib
import json
import math
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
DEST=ROOT/'content-animations/bank-review'
bank=json.loads((DEST/'bank.json').read_text(encoding='utf-8'))
questions={q['number']:q for q in bank['questions']}
scenes={}

def V(id,label,kind,x,y,w=10,color=None,path=None):
    return dict(id=id,label=label,kind=kind,at=[x,y],width=w,color=color,path=path or [])
def H(id,label,rect):
    x,y,w,h=rect
    return dict(id=id,label=label,kind='marker',at=[x+w/2,y+h/2],rect=rect,width=w,path=[])
def cue(text,*ids,action='focus',paths=None,duration=4):
    actions=[]
    for i in ids:
        item=dict(actor=i,action=action)
        if paths and i in paths:item['path']=paths[i]
        actions.append(item)
    return dict(text=text,actions=actions,duration=duration)
def move(text,*ids,paths=None,duration=5):return cue(text,*ids,action='move',paths=paths,duration=duration)
def block(text,*ids):return cue(text,*ids,action='forbidden')
def wait(text,*ids):return cue(text,*ids,action='wait')
def P(n,actors,steps,mode='3d',note=''):
    q=questions[n]
    correct=next(o['text'] for o in q['options'] if o['id']==q['correctOptionIds'][0])
    steps.append(cue('Đáp án gạch chân trong PDF: '+correct,duration=3))
    scenes[str(n)]=dict(number=n,mode=mode,actors=actors,steps=steps,note=note,status='draft')

# The first intersections share a camera family, but each actor/path is entered for its image.
P(486,[
    V('car','Xe con','car',39,92,12,'#294c99',[[39,92],[49,76],[56,68],[66,71],[90,93]]),
    V('bus','Xe khách','bus',17,92,33,path=[[17,92],[31,73],[44,54],[47,40],[40,31],[35,26]]),
    V('truck','Xe tải','truck',31,91,17,path=[[31,91],[43,70],[56,47],[74,20]]),
    V('moto','Xe mô tô','moto',75,26.5,8,path=[[75,26.5],[65,40],[54,53],[46,71],[42,84]]),
    V('far-truck','Xe tải nhánh đối diện','truck',65,23,11,path=[[65,23],[61,25.5],[57.2,33.8],[56.4,41.5],[58.2,50],[62.3,58.8],[70,70.3],[85.7,84.8]]),
    H('lights','Đèn theo hướng đi',[27,43,25,30]),
    H('far-lights','Đèn ở nhánh đối diện',[60,0,16,15])],
    [cue('Đọc đèn và mũi tên trong ảnh. Đây là câu xét đúng/sai từng xe, không phải thứ tự đi trước.','lights','far-lights'),
     move('Xét riêng xe con: minh họa đường đi chấp hành đúng theo đáp án nguồn.','car'),
     move('Xét riêng xe khách: đường dự định thuộc nhóm không chấp hành. Giữ xe tại vị trí đầu, chỉ vẽ đường sai bằng nét đỏ.','bus'),
     move('Xét riêng hai xe tải: đường dự định thuộc nhóm không chấp hành. Giữ xe đứng yên để đối chiếu đèn và đường màu đỏ.','truck','far-truck'),
     move('Xét riêng mô tô: đường dự định thuộc nhóm không chấp hành. Giữ xe đứng yên, không phát chuyển động sai.','moto'),
     cue('Kết luận: chỉ xe con. Trình tự xem từng xe không biểu thị quyền ưu tiên.','car')],
    note='So sánh độc lập: mỗi lượt trả các xe về vị trí ban đầu. Đường nét đứt là lớp biên soạn, đèn và mũi tên đỏ sẵn có trong ảnh không bị sửa.')
scenes['486']['learningMode']='compliance'
for index in [1,2,3,4]:
    for action in scenes['486']['steps'][index]['actions']:
        action['verdict']='valid' if index==1 else 'invalid'
        if index>1:action['stopAt']=0
P(487,[V('truck','Xe tải','truck',94,76,23,path=[[94,76],[66,61],[39,44],[13,28]]),V('moto','Xe mô tô','moto',28,28,9,path=[[28,28],[42,43],[64,61],[86,78]]),V('bus','Xe khách','bus',82,24,22,path=[[82,24],[63,39],[36,59],[8,80]]),V('car','Xe con','car',10,76,13,'#244b9a',[[10,76],[32,61],[54,43],[62,30],[49,19]])],[move('Lượt 1: xe tải.','truck'),move('Lượt 2: xe mô tô.','moto'),move('Lượt 3: xe khách.','bus'),move('Lượt 4: xe con.','car')])
P(488,[V('police','Xe công an','police',25,27,14,path=[[25,27],[44,44],[63,62],[85,81]]),V('car','Xe con','car',89,76,14,'#244b9a',[[89,76],[67,61],[46,43],[24,25]]),V('truck','Xe tải','truck',83,25,22,path=[[83,25],[63,41],[36,61],[9,82]]),V('bus','Xe khách','bus',9,79,23,path=[[9,79],[30,62],[53,43],[74,25]])],[move('Lượt 1: xe công an đang làm nhiệm vụ khẩn cấp.','police'),move('Lượt 2: xe con.','car'),move('Lượt 3: xe tải.','truck'),move('Lượt 4: xe khách.','bus')])
P(489,[V('police','Xe công an','police',86,77,15,path=[[86,77],[66,62],[45,45],[24,26]]),V('truck','Xe tải','truck',81,24,23,path=[[81,24],[63,39],[37,60],[8,81]]),V('bus','Xe khách','bus',11,80,23,path=[[11,80],[34,62],[53,44],[61,30],[50,19]]),V('car','Xe con','car',22,27,14,'#244b9a',[[22,27],[43,45],[63,62],[84,81]])],[move('Lượt 1: xe công an.','police'),move('Lượt 2: xe tải.','truck'),move('Lượt 3: xe khách.','bus'),move('Lượt 4: xe con.','car')])
P(490,[V('moto','Xe mô tô','moto',6,35,10,path=[[6,35],[22,42],[40,51],[51,49],[59,40],[66,26],[83,3]]),V('car','Xe con','car',52,23,12,'#af1725',[[52,23],[32,45],[12,67],[-12,91]]),V('truck','Xe tải','truck',88,56,25,path=[[88,56],[70,49],[52,42],[43,42],[33,52],[10,79],[-15,105]])],[move('Lượt 1: mô tô đi trước.','moto'),move('Lượt 2: xe con đi thẳng.','car'),move('Lượt 3: xe tải đi sau cùng.','truck')])
P(491,[V('car','Xe con','car',78,76,12,'#21754b',[[78,76],[70,55],[69,36],[66,14]]),V('truck','Xe tải','truck',60,69,20,path=[[60,69],[66,55],[65,35],[64,12]])],[wait('Xe con ở nhánh vào phải nhường đường.','car'),move('Xe tải đang lưu thông trong vòng xuyến đi qua trước.','truck'),move('Khi đã có khoảng trống, xe con mới đi vào.','car')])
P(492,[V('car','Xe con','car',14,29,14,'#244b9a',[[14,29],[36,46],[56,63],[80,82]]),V('moto','Xe mô tô','moto',91,79,11,path=[[91,79],[71,64],[52,48],[53,32],[73,15]]),H('stop','Biển STOP',[84,26,15,26])],[cue('Quan sát biển STOP ở nhánh xe mô tô.','stop'),wait('Xe mô tô chờ tại nhánh của mình.','moto'),move('Xe con được đi trước.','car'),move('Sau đó mô tô mới thực hiện lượt đi.','moto')])
P(493,[V('a','Xe con A','car',22,62,13,'#b21c2c',[[22,62],[43,49],[66,35],[87,21]]),V('ambulance','Xe cứu thương','ambulance',77,22,19,path=[[77,22],[61,35],[40,52],[15,75]]),V('b','Xe con B','car',87,77,13,'#244b9a',[[87,77],[64,61],[45,45],[28,27]])],[move('Lượt 1 theo đáp án: xe con A.','a'),move('Lượt 2: xe cứu thương đang làm nhiệm vụ cấp cứu.','ambulance'),move('Lượt 3: xe con B.','b')])
P(494,[V('fire','Xe chữa cháy','fire',87,66,29,path=[[87,66],[65,53],[44,40],[25,24]]),V('ambulance','Xe cứu thương','ambulance',72,19,18,path=[[72,19],[54,34],[34,51],[10,72]]),V('car','Xe con','car',10,75,13,'#244b9a',[[10,75],[32,58],[54,39],[73,21]])],[move('Lượt 1: xe chữa cháy đang làm nhiệm vụ.','fire'),move('Lượt 2: xe cứu thương đang làm nhiệm vụ.','ambulance'),move('Lượt 3: xe con.','car')])
P(495,[V('ambulance','Xe cứu thương','ambulance',89,72,22,path=[[89,72],[65,57],[42,42],[20,26]]),V('moto','Xe mô tô','moto',18,69,11,path=[[18,69],[42,54],[66,35],[85,20]])],[wait('Xe mô tô chờ.','moto'),move('Xe cứu thương đang làm nhiệm vụ cấp cứu được đi trước.','ambulance'),move('Mô tô đi sau khi giao lộ trống.','moto')])
P(496,[H('bus','Xe khách',[0,65,24,28]),H('truck','Xe tải',[69,17,29,24]),H('car','Xe con',[9,17,19,20])],[cue('Xác định ba xe và hướng đi trong ảnh.','truck','car'),wait('Xe khách là xe phải nhường đường, đi cuối cùng.','bus'),cue('Đề chỉ yêu cầu chọn xe đi cuối; không áp thêm thứ tự giữa hai xe còn lại.','bus')],mode='photo')
P(497,[V('truck','Xe tải','truck',86,70,26,path=[[86,70],[62,53],[42,36],[25,21]]),V('car','Xe con','car',12,81,13,'#244b9a',[[12,81],[33,65],[55,46],[76,27]])],[wait('Xe con là xe phải nhường đường.','car'),move('Xe tải đi qua trước.','truck'),move('Xe con đi sau khi đường đã trống.','car')])
P(498,[V('fire','Xe chữa cháy','fire',88,70,30,path=[[88,70],[62,53],[37,35],[12,18]]),V('police','Xe công an','police',15,82,16,path=[[15,82],[36,64],[57,44],[81,22]])],[wait('Xe công an đang làm nhiệm vụ chờ lượt.','police'),move('Xe chữa cháy đang làm nhiệm vụ chữa cháy đi trước.','fire'),move('Xe công an đi sau.','police')])
P(499,[V('car','Xe con','car',19,81,13,'#244b9a',[[19,81],[43,63],[63,45],[56,31],[34,16]]),V('bus','Xe khách','bus',6,75,22,path=[[6,75],[29,58],[54,39],[80,19]]),V('moto','Xe mô tô','moto',91,77,10,path=[[91,77],[65,59],[39,38],[17,17]]),H('red','Đèn đỏ phía mô tô',[80,34,10,24])],[cue('Đối chiếu tín hiệu đèn phía mô tô.','red'),wait('Xe mô tô phải chờ.','moto'),move('Xe con và xe khách được phép đi theo tín hiệu.','car','bus')])
P(500,[H('car','Xe con',[17,73,15,17]),H('truck','Xe tải',[20,61,16,20]),H('lights','Đèn tín hiệu',[26,55,21,25]),H('bus','Xe khách',[0,62,23,26]),H('moto','Xe mô tô',[69,16,12,17])],[cue('Quan sát đèn và các đường mũi tên.','lights'),cue('Hai xe được nêu trong đáp án đúng là xe con và xe tải.','car','truck'),block('Xe khách và mô tô không thuộc phương án đúng của câu này.','bus','moto')],mode='photo')
P(501,[V('army','Xe quân sự','army',86,75,25,path=[[86,75],[65,58],[42,40],[19,22]]),V('police','Xe công an','police',14,82,16,path=[[14,82],[35,64],[56,44],[78,24]])],[wait('Xe công an chờ lượt.','police'),move('Xe quân sự đang làm nhiệm vụ khẩn cấp được đi trước.','army'),move('Xe công an đi sau.','police')])

def routes(n,kind,at,width,route_map,selected,negative=False,color=None,regions=None):
    actor=V('vehicle',{'car':'Xe con','truck':'Xe tải','moto':'Xe mô tô'}[kind],kind,*at,width,color,path=route_map[str(selected[0])])
    actors=[actor]+[H(k,label,rect) for k,label,rect in (regions or [])]
    steps=[]
    if regions:steps.append(cue('Quan sát biển báo, đèn hoặc vị trí làn trong ảnh.',*[x[0] for x in regions]))
    for route_id in selected:
        path=route_map[str(route_id)]
        if negative:steps.append(cue(f'Hướng {route_id} là hướng không được phép trong đáp án nguồn.','vehicle',action='forbidden',paths={'vehicle':path}))
        else:steps.append(move(f'Minh họa hướng {route_id} được phép theo đáp án nguồn.','vehicle',paths={'vehicle':path}))
    P(n,actors,steps)

routes(502,'truck',(23,80),25,{'1':[[23,80],[38,69],[58,70],[78,76]],'2':[[23,80],[43,55],[70,35],[96,14]],'3':[[23,80],[41,56],[43,38],[29,18]],'4':[[23,80],[39,59],[51,55],[48,70],[30,92]]},[1],regions=[('light','Đèn tín hiệu',[36,42,17,31])])
P(503,[H('bus','Xe khách',[0,62,23,25]),H('truck','Xe tải',[19,60,15,19]),H('moto','Xe mô tô',[68,15,12,16]),H('car','Xe con',[16,77,14,15])],[cue('Đối chiếu từng đường mũi tên với đèn tín hiệu.','bus','truck','moto'),block('Xe khách, xe tải và mô tô là các xe vi phạm trong đáp án.','bus','truck','moto'),cue('Xe con không nằm trong nhóm vi phạm được chọn.','car')],mode='photo')
P(504,[V('moto','Xe mô tô','moto',88,85,9,path=[[88,85],[77,66],[62,54],[40,56],[25,65],[15,59],[25,47],[49,39],[64,18]]),V('truck','Xe tải','truck',9,81,21,path=[[9,81],[25,68],[52,60],[72,61],[92,55]]),V('bus','Xe khách','bus',19,21,22,path=[[19,21],[32,36],[35,51],[25,65],[17,76]]),V('car','Xe con','car',64,9,9,'#244b9a',[[64,9],[58,30],[44,40],[25,47],[12,62]])],[move('Lượt 1: xe mô tô.','moto'),move('Lượt 2: xe tải.','truck'),move('Lượt 3: xe khách.','bus'),move('Lượt 4: xe con.','car')])
P(505,[H('truck','Xe tải',[64,17,32,34]),H('car','Xe con',[18,52,26,25]),H('moto','Mô tô',[46,39,15,23]),H('sign','Biển cấm đỗ',[0,29,15,36])],[cue('Quan sát biển và vị trí các xe.','sign'),block('Xe tải đỗ vi phạm theo đáp án nguồn.','truck'),cue('Đối chiếu vị trí xe con và mô tô trong ảnh.','car','moto')],mode='photo')
P(506,[V('b','Xe con B','car',87,78,13,'#244b9a',[[87,78],[65,60],[40,41],[17,22]]),V('a','Xe con A','car',12,67,13,'#b21c2c',[[12,67],[36,52],[59,35],[80,20]]),V('truck','Xe tải','truck',83,24,24,path=[[83,24],[59,42],[36,62],[12,83]])],[move('Xe con B được quyền đi trước.','b'),cue('Hai xe còn lại chờ lượt; câu hỏi chỉ yêu cầu xác định xe đi trước.','a','truck')])
routes(507,'moto',(12,78),12,{'1':[[12,78],[38,54],[61,54],[89,81]],'2':[[12,78],[42,56],[65,42],[89,27]],'3':[[12,78],[39,56],[52,43],[43,30],[24,22]]},[1,2,3],regions=[('signs','Biển báo ở hai nhánh',[43,0,55,37])])
P(508,[H('truck','Xe tải',[12,29,43,45]),H('moto','Xe mô tô',[73,30,19,24]),H('sign','Biển cấm đỗ',[56,7,16,41])],[cue('Quan sát biển và vị trí hai xe.','sign'),block('Cả xe tải và mô tô đều đỗ vi phạm.','truck','moto')],mode='photo')
P(509,[H('car','Xe con',[8,54,26,25]),H('moto','Mô tô',[35,45,18,23]),H('truck','Xe tải',[54,22,38,41]),H('crossing','Vị trí đường giao nhau',[14,4,33,50])],[cue('Xác định vị trí các xe so với đường giao nhau.','crossing'),block('Cả ba xe đều đỗ vi phạm.','car','moto','truck')],mode='photo')
P(510,[H('truck','Xe tải kéo',[57,9,24,30]),H('moto','Xe mô tô ba bánh',[42,33,11,23]),H('sign','Biển báo',[79,22,14,41])],[cue('Quan sát xe tải đang kéo mô tô ba bánh.','truck','moto'),block('Cách kéo xe trong hình không đúng quy tắc giao thông theo đáp án.','truck','moto')],mode='photo')
round_paths={'1':[[31,86],[44,69],[62,64],[74,52],[70,34],[61,13]],'2':[[31,86],[46,69],[62,63],[91,59]],'3':[[31,86],[46,68],[64,65],[74,79],[88,91]],'4':[[31,86],[46,67],[62,64],[72,49],[65,35],[44,35],[27,50],[17,74]],'5':[[31,86],[46,67],[62,63],[72,49],[65,35],[43,35],[27,45],[17,34]]}
routes(511,'car',(31,86),14,round_paths,[1],negative=True,regions=[('sign','Biển cấm',[55,0,14,24])])
cross_right={'1':[[81,79],[61,64],[52,45],[75,31],[93,29]],'2':[[81,79],[61,64],[51,59],[53,73],[70,84]],'3':[[81,79],[61,61],[40,53],[9,55]],'4':[[81,79],[60,61],[52,48],[52,27],[42,9]]}
routes(512,'car',(81,79),15,cross_right,[3],negative=True,regions=[('sign','Biển báo',[84,18,16,31])])
P(513,[H('car','Xe con vượt',[1,54,23,39]),H('bus','Xe khách vượt',[53,46,25,43]),H('signs','Các biển cấm vượt',[9,61,22,28])],[cue('Đối chiếu hai hình và loại xe trên biển cấm vượt.','signs'),cue('Cả hai xe đều vượt đúng theo đáp án nguồn.','car','bus')],mode='photo')
routes(514,'car',(81,80),15,{**cross_right,'2':cross_right['4']},[2,3],regions=[('sign','Hướng đi phải theo',[82,25,17,31])])
P(515,[H('tow','Tổ hợp xe kéo',[7,8,91,76])],[cue('Quan sát số xe trong tổ hợp kéo nhau.','tow'),block('Tổ hợp kéo xe trong hình vi phạm theo đáp án.','tow')],mode='photo')
P(516,[V('bus','Xe khách','bus',85,80,29,path=[[85,80],[64,57],[51,39],[43,18]]),V('truck','Xe tải','truck',41,21,14,path=[[41,21],[48,38],[62,60],[85,83]]),H('bridge','Cầu hẹp và biển báo',[39,20,18,38])],[cue('Quan sát cầu hẹp và biển hai phía.','bridge'),wait('Xe khách phải nhường đường.','bus'),move('Xe tải qua cầu trước.','truck'),move('Xe khách đi khi cầu đã trống.','bus')])
P(517,[V('car','Xe con','car',88,69,15,'#b21c2c',[[88,69],[63,56],[43,54],[14,67]]),V('moto','Xe mô tô','moto',22,28,11,path=[[22,28],[42,43],[49,57],[40,67],[18,80]])],[wait('Xe mô tô chờ.','moto'),move('Xe con được quyền đi trước.','car'),move('Mô tô đi sau.','moto')])
P(518,[H('tow','Đầu kéo và xe được kéo',[0,15,96,72])],[cue('Quan sát kết nối giữa đầu kéo và xe phía sau.','tow'),block('Cách kéo xe này không đúng quy định theo đáp án nguồn.','tow')],mode='photo')
routes(519,'car',(81,80),15,{**cross_right,'4':cross_right['2']},[1,3,4],regions=[('signs','Biển ở nhánh vào và nhánh ra',[48,0,50,50])])
P(520,[V('moto','Xe mô tô','moto',75,23,9,path=[[75,23],[56,40],[33,59],[12,78]]),V('cycle','Xe đạp','bicycle',88,32,8,path=[[88,32],[64,51],[44,69],[27,85]]),V('a','Xe con A','car',87,80,14,'#b21c2c',[[87,80],[65,62],[45,46],[25,26]]),V('b','Xe con B','car',10,77,14,'#244b9a',[[10,77],[35,58],[57,40],[77,22]])],[move('Lượt 1: xe mô tô và xe đạp cùng đi.','moto','cycle'),move('Lượt 2: xe con A.','a'),move('Lượt 3: xe con B.','b')])
routes(521,'truck',(82,81),25,cross_right,[1],regions=[('sign','Biển hướng đi phải theo',[80,22,18,32])])
routes(522,'truck',(83,81),25,{**cross_right,'2':cross_right['4']},[2,3],regions=[('sign','Biển cấm tại nhánh',[80,18,18,34])])
routes(523,'truck',(18,79),26,{'1':[[18,79],[39,58],[60,55],[88,70]],'2':[[18,79],[38,56],[65,42],[88,28]],'3':[[18,79],[40,54],[58,36],[70,14]],'4':[[18,79],[39,58],[48,39],[32,29]],'5':[[18,79],[40,57],[53,49],[49,65],[26,81]]},[1,5],regions=[('sign','Biển cấm xe tải',[61,27,18,25])])
routes(524,'truck',(83,81),25,{**cross_right,'4':cross_right['2']},[1,3,4],regions=[('sign','Biển cấm',[48,0,17,25])])
P(525,[V('moto','Xe mô tô','moto',13,80,10,path=[[13,80],[35,61],[58,43],[81,24]]),V('car','Xe con','car',82,24,14,'#244b9a',[[82,24],[60,42],[36,62],[11,82]])],[wait('Xe con chờ lượt.','car'),move('Xe mô tô được đi trước.','moto'),cue('Đối chiếu biển báo và đáp án gạch chân trong PDF.','car')])
P(526,[H('car','Xe con',[53,53,24,29]),H('sign','Biển hướng đi phải theo',[74,21,18,37]),H('route','Đường rẽ của xe',[34,16,42,46])],[cue('Quan sát biển hướng đi phải theo.','sign'),cue('Đối chiếu đường xe con rẽ theo mũi tên.','route'),block('Xe con đi theo hướng trong hình là vi phạm.','car')],mode='photo')
P(527,[H('car','Xe con',[34,12,25,22]),H('moto','Mô tô',[25,47,19,26]),H('bus','Xe khách',[58,34,41,36]),H('works','Khu vực có chướng ngại vật',[32,27,27,29])],[cue('Quan sát chướng ngại vật và phần đường xe đi.','works'),block('Xe con là xe vi phạm theo đáp án.','car'),cue('Xe mô tô và xe khách không được chọn là xe vi phạm.','moto','bus')],mode='photo')
P(528,[H('officer','Người điều khiển giao thông',[48,26,15,41]),H('inside','Xe tải đã ở trong ngã tư',[41,29,23,37]),H('approaches','Các nhánh đang đến',[0,0,100,93])],[cue('Quan sát tư thế của người điều khiển giao thông.','officer'),wait('Các xe đang tới phải dừng trước ngã tư.','approaches'),cue('Xe đã ở trong ngã tư được tiếp tục đi theo đáp án.','inside')],mode='photo')
P(529,[V('moto','Xe mô tô','moto',13,26,10,path=[[13,26],[34,44],[39,59],[19,77]]),V('truck','Xe tải','truck',91,57,25,path=[[91,57],[64,43],[43,36],[30,40],[16,51]]),V('car','Xe con','car',15,84,14,'#244b9a',[[15,84],[36,65],[61,55],[88,64]]),H('officer','Người điều khiển giao thông',[44,0,16,41])],[cue('Đối chiếu tín hiệu của người điều khiển giao thông.','officer'),wait('Xe con chờ.','car'),move('Xe mô tô và xe tải được phép đi.','moto','truck')])
P(530,[V('car','Xe con','car',14,79,14,'#244b9a',[[14,79],[31,67],[43,50],[56,34],[68,24],[91,20]]),V('truck','Xe tải','truck',25,61,25,path=[[25,61],[44,46],[53,31],[43,20],[27,13]])],[cue('Quan sát xe tải rẽ và đường vượt của xe con.','truck','car'),move('Minh họa đường xe con vượt theo mũi tên của hình.','car'),cue('Đáp án nguồn xác nhận tình huống này là đúng.','car')])
P(531,[H('car','Xe con vượt',[34,35,25,28]),H('truck','Xe tải vượt',[31,8,36,41]),H('bus','Xe khách',[0,56,33,31]),H('van','Xe phía trước',[63,24,27,25])],[cue('Đối chiếu hai đường vượt trong ảnh.','truck','car'),cue('Chỉ xe con vượt đúng theo đáp án nguồn.','car'),block('Xe tải không thuộc phương án vượt đúng.','truck')],mode='photo')
P(532,[H('truck','Xe tải',[4,48,31,29]),H('fire','Xe chữa cháy',[71,27,28,33]),H('sign','Biển báo',[35,28,18,38])],[cue('Quan sát biển báo và hướng xe tải.','sign'),block('Xe tải là xe vi phạm trong tình huống này.','truck'),cue('Xe chữa cháy đang làm nhiệm vụ không thuộc đáp án vi phạm.','fire')],mode='photo')
P(533,[V('truck','Xe tải','truck',87,73,25,path=[[87,73],[66,56],[44,39],[21,19]]),V('bus','Xe khách','bus',12,75,25,path=[[12,75],[35,57],[56,40],[81,21]]),V('car','Xe con','car',72,14,10,'#244b9a',[[72,14],[55,32],[47,47],[59,62],[85,78]])],[move('Lượt 1: xe tải.','truck'),move('Lượt 2: xe khách.','bus'),move('Lượt 3: xe con.','car')])
P(534,[V('bus','Xe khách','bus',11,76,25,path=[[11,76],[35,58],[59,40],[83,20]]),V('truck','Xe tải','truck',87,72,25,path=[[87,72],[64,56],[43,40],[20,21]]),V('car','Xe con','car',72,14,10,'#244b9a',[[72,14],[55,33],[47,48],[59,62],[85,77]])],[move('Lượt 1: xe khách và xe tải.','bus','truck'),move('Lượt 2: xe con.','car')])
routes(535,'truck',(81,80),26,{'1':cross_right['1'],'2':[[81,80],[62,63],[38,54],[10,54]],'3':[[81,80],[61,63],[54,55],[54,72],[70,88]],'4':cross_right['4']},[1,2,3],regions=[('sign','Biển cấm đi vào',[50,0,17,27])])
P(536,[V('police','Xe công an','police',83,23,15,path=[[83,23],[61,41],[38,59],[12,80]]),V('car','Xe con','car',87,77,14,'#244b9a',[[87,77],[65,60],[43,43],[22,25]]),V('truck','Xe tải','truck',24,26,22,path=[[24,26],[44,43],[66,60],[87,79]]),V('bus','Xe khách','bus',10,80,25,path=[[10,80],[34,61],[56,42],[79,23]])],[move('Lượt 1: xe công an làm nhiệm vụ khẩn cấp.','police'),move('Lượt 2: xe con.','car'),move('Lượt 3: xe tải.','truck'),move('Lượt 4: xe khách.','bus')])
routes(537,'truck',(82,80),26,{'1':cross_right['1'],'2':[[82,80],[60,62],[52,44],[50,17]],'3':[[82,80],[61,63],[53,55],[54,72],[69,88]],'4':[[82,80],[60,62],[36,54],[8,53]]},[1,3,4],regions=[('signs','Các biển cấm',[45,0,54,56])])
P(538,[H('all','Các xe đi theo mũi tên',[0,0,100,100]),H('lights','Tín hiệu đèn',[27,50,24,30])],[cue('Đối chiếu đèn và từng đường đi trong hình.','lights'),cue('Tất cả các loại xe trên chấp hành đúng theo đáp án nguồn.','all')],mode='photo')
routes(539,'moto',(18,75),12,{'1':[[18,75],[40,57],[63,56],[87,77]],'2':[[18,75],[40,56],[66,40],[89,28]],'3':[[18,75],[40,55],[50,40],[41,28],[23,20]]},[1,3],regions=[('signs','Biển báo các nhánh',[46,0,52,40])])
P(540,[V('army','Xe quân sự','army',86,77,26,path=[[86,77],[64,59],[43,42],[20,23]]),V('police','Xe công an','police',12,81,15,path=[[12,81],[34,63],[57,44],[80,24]]),V('car','Xe con','car',82,24,14,'#244b9a',[[82,24],[61,42],[37,61],[12,82]]),V('moto','Xe mô tô','moto',73,16,9,path=[[73,16],[56,32],[33,50],[9,69]])],[move('Lượt 1: xe quân sự làm nhiệm vụ khẩn cấp.','army'),move('Lượt 2: xe công an làm nhiệm vụ khẩn cấp.','police'),move('Lượt 3: xe con và mô tô cùng đi.','car','moto')])
P(541,[V('a','Xe A','car',28,41,16,'#b7a73b',[[28,41],[48,58],[73,78]]),V('b','Xe B','car',79,80,20,'#244b9a',[[79,80],[56,59],[32,38]])],[wait('Xe A nhường đường theo đáp án.','a'),move('Xe B đi qua đoạn đường hẹp trước.','b'),move('Xe A đi sau khi đường đã trống.','a')])
P(542,[H('car','Xe con',[12,66,24,24]),H('turn','Đường quay đầu',[40,22,28,34]),H('light','Đèn tín hiệu',[16,52,10,30])],[cue('Đối chiếu tín hiệu đèn và đường quay đầu.','light','turn'),block('Xe con quay đầu như hình là vi phạm.','car','turn')],mode='photo')

def photo(n,regions,steps,note=''):
    P(n,[H(*region) for region in regions],steps,mode='photo',note=note)

photo(543,[('e','Xe con E',[37,73,15,14]),('c','Mô tô C',[27,66,11,14]),('lanes','Biển phân làn',[63,1,35,31])],[cue('Quan sát biển phân làn và chữ ký hiệu trên xe.','lanes'),block('Xe con E và mô tô C là hai xe vi phạm.','e','c')])
photo(544,[('car','Xe con rẽ trái',[13,45,20,15]),('self','Hướng đi thẳng của bạn',[46,66,12,25])],[wait('Xe của bạn chờ để nhường xe con rẽ trái.','self'),cue('Cho xe con rẽ trái đi trước.','car'),cue('Sau đó bạn mới tiếp tục đi thẳng.','self')])
photo(545,[('one','Hướng 1',[12,60,20,18]),('two','Hướng 2',[44,56,16,27]),('signs','Biển báo ở ngã tư',[51,35,46,30])],[cue('Quan sát biển báo tại các nhánh.','signs'),cue('Hướng 1 được phép theo đáp án nguồn.','one'),cue('Hướng 2 cũng được phép.','two')])
P(546,[V('a','Xe con A','car',28,64,17,'#c86a2b',[[28,64],[22,73],[10,79]]),V('b','Xe con B','car',46,61,13,'#244b9a',[[46,61],[35,74],[13,81]])],[wait('Xe con B phải nhường đường theo đáp án.','b'),move('Xe con A đi trước.','a'),move('Xe con B đi sau.','b')])
photo(547,[('bus','Xe buýt',[42,41,17,22]),('truck','Xe tải',[69,44,22,18]),('self','Hướng rẽ trái của bạn',[12,63,41,24])],[wait('Chưa rẽ trái trước hai xe đang tới.','self'),cue('Nhường đường cho xe buýt.','bus'),cue('Tiếp tục nhường xe tải, chỉ rẽ khi đường trống.','truck')])
photo(548,[('e','Xe con E',[35,73,16,17]),('d','Mô tô D',[57,56,12,14]),('lanes','Biển phân làn',[65,0,33,33])],[cue('Quan sát biển phân làn.','lanes'),block('Xe con E và mô tô D là hai xe vi phạm.','e','d')])
photo(549,[('truck','Xe tải',[5,40,20,21]),('sign','Biển nhường đường',[65,29,17,26]),('self','Vị trí xe của bạn',[43,66,16,21])],[cue('Quan sát biển nhường đường của bạn.','sign'),wait('Xe của bạn chờ.','self'),cue('Xe tải đi trước theo đáp án.','truck')])
photo(550,[('a','Đường quay đầu A',[23,59,30,12]),('b','Đường quay đầu B',[23,70,31,13]),('sign','Biển cấm',[57,38,18,23])],[cue('Quan sát đường A và B trong ảnh.','a','b'),cue('Chọn đường quay đầu A theo đáp án nguồn.','a'),block('Không chọn đường B cho thao tác quay đầu này.','b')])
photo(551,[('self','Xe của bạn',[30,66,22,19]),('car','Xe con',[16,48,15,14]),('truck','Xe tải',[71,35,25,29])],[cue('Lượt 1: xe của bạn và xe con.','self','car'),wait('Xe tải chờ lượt.','truck'),cue('Lượt 2: xe tải đi qua.','truck')])
photo(552,[('truck','Xe tải phía trước',[45,33,26,42]),('ahead','Phần đường phía trước',[24,43,23,30]),('mirrors','Quan sát phía sau',[42,9,36,14])],[cue('Quan sát trước và sau, chỉ vượt khi đủ điều kiện an toàn.','ahead','mirrors'),cue('Báo hiệu bằng đèn hoặc còi trước khi vượt.','truck'),cue('Khi đã đủ điều kiện an toàn mới tăng tốc để vượt.','ahead')])
photo(553,[('car','Xe con',[16,75,17,19]),('truck','Xe tải',[20,61,18,21]),('lights','Tín hiệu đèn',[27,54,24,27])],[cue('Quan sát tín hiệu đèn cho từng làn.','lights'),wait('Xe con và xe tải phải dừng lại theo đáp án.','car','truck')])
photo(554,[('a','Xe con A',[44,20,17,20]),('c','Xe con C',[1,46,17,20]),('e','Xe con E',[52,34,17,21]),('bus','Xe buýt G',[72,22,26,43])],[cue('Đối chiếu ký hiệu chữ trên từng xe.','a','c'),cue('Xe A, C, E và xe buýt G chấp hành đúng.','a','c','e','bus')])
photo(555,[('truck','Xe tải',[43,31,28,43]),('cross','Khu vực giao nhau',[13,55,78,20])],[cue('Quan sát vị trí xe tải trước khu vực giao nhau.','truck','cross'),block('Không vượt xe tải để đi thẳng trong tình huống này.','truck')])
photo(556,[('moto','Xe mô tô',[58,54,14,23]),('sign','Biển nhường đường',[66,38,17,25]),('cross','Khu vực giao nhau',[21,57,48,17])],[cue('Quan sát mô tô và khu vực giao nhau phía trước.','moto','cross'),block('Không được vượt xe mô tô trong tình huống này.','moto')])
photo(557,[('a','Vị trí A',[10,48,15,19]),('b','Vị trí B',[81,46,15,19]),('c','Vị trí C',[64,31,18,23])],[cue('Đối chiếu ba vị trí A, B và C.','a','b','c'),cue('Vị trí B và C là các vị trí dừng đúng theo đáp án.','b','c'),block('Vị trí A không thuộc lựa chọn đúng.','a')])
photo(558,[('a','Vị trí A',[67,55,28,29]),('b','Vị trí B',[56,51,18,21]),('sign','Biển cấm dừng, đỗ',[66,35,14,26])],[cue('Quan sát biển và hai vị trí A/B.','sign'),block('Không được dừng ở vị trí A.','a'),block('Cũng không được dừng ở vị trí B.','b')])
photo(559,[('car','Xe ô tô con',[51,52,25,33]),('moto','Xe mô tô',[18,49,16,18]),('signals','Tín hiệu đèn xe',[52,57,22,14])],[cue('Quan sát tín hiệu đèn của các xe.','signals'),block('Cả xe mô tô và ô tô con đều vi phạm theo đáp án.','car','moto')])
photo(560,[('truck','Xe tải',[21,61,15,20]),('car','Xe con',[16,76,17,18]),('paths','Các mũi tên hướng đi',[29,33,40,41])],[cue('Đối chiếu đường mũi tên và làn xe.','paths'),block('Xe tải là xe vi phạm trong câu này.','truck'),cue('Xe con không thuộc đáp án vi phạm.','car')])
photo(561,[('bus','Xe khách',[0,60,23,27]),('truck','Xe tải',[21,60,15,20]),('car','Xe con',[16,76,17,18]),('paths','Các mũi tên',[29,32,48,46])],[cue('Quan sát đường đi của từng xe.','paths'),block('Xe khách và xe tải là hai xe vi phạm.','bus','truck'),cue('Xe con không thuộc nhóm vi phạm được chọn.','car')])
photo(562,[('bus','Xe khách',[0,61,23,28]),('truck','Xe tải',[21,60,15,20]),('moto','Mô tô',[68,15,14,20]),('car','Xe con',[16,77,17,17])],[cue('Đối chiếu bốn đường đi trong ảnh.','bus','truck','moto','car'),block('Xe tải, xe khách và mô tô vi phạm.','truck','bus','moto'),cue('Xe con không nằm trong đáp án vi phạm.','car')])
photo(563,[('bus','Xe khách',[0,61,23,28]),('truck','Xe tải',[21,60,15,20]),('paths','Các mũi tên',[29,29,45,46])],[cue('Đối chiếu tín hiệu và đường đi từng xe.','paths'),block('Xe khách và xe tải vi phạm theo đáp án.','bus','truck')])
photo(564,[('broken','Xe bị hỏng',[48,50,20,21]),('ahead','Khoảng đường phía trước',[26,43,25,28]),('mirrors','Quan sát phía sau',[41,8,39,14])],[cue('Quan sát phía trước và phía sau.','ahead','mirrors'),wait('Chỉ chuyển hướng khi đã đủ điều kiện an toàn.','broken'),cue('Báo hiệu bằng đèn hoặc còi rồi mới cho xe vượt qua.','ahead')])
photo(565,[('bus','Xe khách',[0,60,23,28]),('moto','Mô tô',[68,14,14,19]),('truck','Xe tải',[21,60,15,20]),('car','Xe con',[16,77,16,17])],[cue('Đối chiếu các mũi tên trong ảnh.','truck','car'),cue('Xe khách và mô tô là các xe chấp hành đúng theo đáp án.','bus','moto')])
photo(566,[('truck','Xe tải D',[13,51,27,39]),('b','Xe con B',[21,32,17,19]),('others','Các xe còn lại',[41,14,58,56])],[cue('Đối chiếu chữ ký hiệu trên các xe.','truck','b'),block('Xe tải D và xe con B vi phạm.','truck','b'),cue('Các xe còn lại không được chọn trong đáp án.','others')])
photo(567,[('moto','Xe mô tô',[10,43,15,18]),('car','Xe con',[70,46,17,15]),('self','Xe của bạn',[48,64,14,17])],[cue('Lượt 1: xe mô tô đi trước.','moto'),cue('Lượt 2: xe con đi.','car'),cue('Lượt 3: xe của bạn.','self')])
photo(568,[('car','Xe con',[78,44,19,17]),('self','Xe của bạn',[47,65,16,17]),('moto','Xe mô tô',[42,42,10,18])],[cue('Lượt 1: xe con đi trước.','car'),cue('Lượt 2: xe của bạn.','self'),cue('Lượt 3: xe mô tô.','moto')])
photo(569,[('car','Xe con',[49,39,16,20]),('self','Xe của bạn',[49,65,25,17])],[wait('Xe con phải dừng lại theo đáp án.','car'),cue('Đối chiếu hướng rẽ của xe bạn trong ảnh.','self')])
photo(570,[('straight','Hướng đi thẳng',[46,59,11,24]),('left','Hướng rẽ trái',[28,61,21,13]),('right','Làn bên phải',[64,59,26,24])],[cue('Đối chiếu vị trí xe bạn và vạch chỉ hướng trên làn.','straight','left'),cue('Xe của bạn được đi thẳng hoặc rẽ trái.','straight','left'),block('Không chọn hướng rẽ phải từ làn hiện tại.','right')])
photo(571,[('stop','Vạch dừng',[28,55,54,12]),('light','Đèn đỏ',[75,20,15,27]),('arrows','Hướng đi trên làn',[30,65,35,18])],[cue('Đèn hiện tại là đỏ.','light'),wait('Dừng trước vạch dừng.','stop'),cue('Khi đèn xanh, đi thẳng hoặc rẽ trái theo làn.','arrows')])
photo(572,[('truck','Xe tải',[1,33,31,30]),('cycle','Xe đạp',[75,57,17,28]),('turn','Hướng rẽ phải của bạn',[49,64,29,19])],[wait('Giảm tốc độ, chưa rẽ phải.','turn'),cue('Nhường xe tải và xe đạp đi qua.','truck','cycle'),cue('Sau đó mới rẽ phải.','turn')])
photo(573,[('ped','Người đi bộ',[68,38,14,27]),('car','Xe con xanh',[56,49,21,18]),('turn','Hướng rẽ của bạn',[42,64,20,19])],[wait('Giảm tốc độ trước khi rẽ.','turn'),cue('Để người đi bộ qua đường trước.','ped'),cue('Rẽ phải sau xe con màu xanh.','car')])
photo(574,[('cycle','Xe đạp',[29,49,12,21]),('bus','Xe khách',[48,41,17,22]),('stop','Biển STOP',[73,38,14,26])],[cue('Quan sát biển STOP.','stop'),wait('Nhường đường cho xe đạp.','cycle'),wait('Đồng thời nhường xe khách; chưa đi trước các xe này.','bus')])
photo(575,[('car','Xe con',[55,47,15,17]),('truck','Xe tải',[7,39,31,30]),('self','Xe của bạn',[45,66,14,19])],[cue('Quan sát ba xe và biển trong hình.','self','car'),wait('Xe tải phải nhường đường theo đáp án nguồn.','truck')])
photo(576,[('van','Xe đang vượt phía trước',[54,49,20,27]),('opposite','Xe ngược chiều',[29,46,14,18]),('self','Xe của bạn',[44,70,18,15])],[cue('Quan sát xe đang vượt và xe ngược chiều.','van','opposite'),wait('Xe của bạn phải nhường đường trong tình huống này.','self')])
photo(577,[('cycles','Đoàn người đi xe đạp',[45,43,43,40]),('self','Xe của bạn',[43,70,14,15])],[cue('Nhận diện đoàn người đi xe đạp có tổ chức.','cycles'),block('Không vượt đoàn người đi xe đạp theo đáp án.','self','cycles')])
photo(578,[('parking','Xe đang lùi vào chỗ đỗ',[67,53,24,27]),('car','Xe trước chuyển làn',[49,49,16,21]),('mirror','Quan sát phía sau',[44,6,33,16]),('left','Làn bên trái',[30,63,18,22])],[cue('Quan sát xe đang lùi và xe trước chuyển làn.','parking','car'),cue('Kiểm tra phía sau: nếu không có xe xin vượt, chuyển sang làn trái.','mirror','left'),wait('Nếu phía sau có xe xin vượt, giảm tốc, giữ làn và dừng khi cần.','mirror')])
photo(579,[('reverse','Xe phía trước đang lùi',[49,48,29,30]),('self','Xe của bạn',[41,69,18,16])],[cue('Phát hiện xe phía trước đang lùi ra khỏi chỗ đỗ.','reverse'),wait('Giảm tốc độ, dừng lại nhường đường.','self')])
photo(580,[('overtake','Xe xanh đang vượt',[43,49,13,17]),('yellow','Xe màu vàng',[39,49,11,15]),('right','Phần đường sát lề phải',[65,65,28,18])],[cue('Phát hiện xe ngược chiều đang lấn sang làn của bạn để vượt.','overtake','yellow'),wait('Phanh giảm tốc độ.','overtake'),cue('Cho xe đi sát lề bên phải theo đáp án.','right')])
photo(581,[('truck','Xe tải xin chuyển làn',[53,35,36,41]),('self','Xe của bạn',[43,69,21,15])],[cue('Quan sát tín hiệu xin chuyển làn của xe tải.','truck'),wait('Phanh giảm tốc, chờ xe tải chuyển làn.','self')])
photo(582,[('mirror','Xe phía sau trong gương',[26,1,42,19]),('sign','Biển nhường đường',[69,13,18,37]),('straight','Hướng đi thẳng',[46,58,17,16])],[cue('Quan sát gương và biển báo.','mirror','sign'),wait('Giảm tốc độ trước ngã tư.','straight'),cue('Đi thẳng qua ngã tư theo đáp án, tiếp tục quan sát.','straight')])
photo(583,[('cycle','Xe đạp',[71,45,16,20]),('moto','Xe mô tô',[24,44,13,20]),('self','Xe của bạn',[43,61,14,15])],[cue('Lượt 1: xe đạp đi trước.','cycle'),cue('Lượt 2: xe mô tô.','moto'),cue('Lượt 3: xe của bạn.','self')])
photo(584,[('self','Xe của bạn',[43,61,16,16]),('car','Xe con',[45,45,14,17]),('truck','Xe tải',[79,33,21,33])],[cue('Lượt 1: xe của bạn.','self'),cue('Lượt 2: xe con.','car'),cue('Lượt 3: xe tải.','truck')])
photo(585,[('car','Xe con',[9,47,19,15]),('self','Xe của bạn',[47,61,16,15]),('sign','Biển nhường đường',[64,32,18,27])],[cue('Quan sát biển nhường đường.','sign'),wait('Xe của bạn phải nhường đường.','self'),cue('Xe con đi trước theo đáp án.','car')])
photo(586,[('car','Xe con đối diện',[44,40,18,21]),('self','Xe của bạn',[42,61,18,15]),('narrow','Đoạn đường hẹp',[28,19,39,45])],[cue('Quan sát đoạn đường hẹp và xe đối diện.','narrow','car'),wait('Xe của bạn phải nhường đường theo đáp án.','self')])
photo(587,[('ped','Người đi bộ',[43,42,11,23]),('cross','Vạch qua đường',[24,50,51,16])],[cue('Quan sát người đi bộ tại vạch sang đường.','ped','cross'),wait('Giảm tốc độ và để người đi bộ qua trước.','cross'),cue('Chỉ cho xe đi qua sau khi người đi bộ đã qua.','cross')])
photo(588,[('car','Xe con',[73,46,21,16]),('self','Xe của bạn',[39,59,21,20]),('sign','Biển báo',[60,25,18,28])],[cue('Đối chiếu biển báo và hướng đi hai xe.','sign','car'),cue('Xe của bạn được đi trước trong tình huống này.','self')])
photo(589,[('truck','Xe tải',[45,39,15,23]),('car','Xe con',[70,44,19,17]),('self','Xe của bạn',[35,61,30,18])],[cue('Lượt 1: xe tải đi trước.','truck'),cue('Lượt 2: xe con.','car'),cue('Lượt 3: xe của bạn.','self')])
photo(590,[('curve','Khúc cua phía trước',[31,38,39,23]),('right','Phần đường bên phải',[60,57,29,20])],[cue('Quan sát khúc cua phía trước.','curve'),wait('Giảm tốc độ.','curve'),cue('Giữ xe đi sát phần đường bên phải.','right')])
photo(591,[('truck','Xe tải đối diện',[44,37,15,25]),('self','Xe của bạn',[41,61,19,16]),('light','Đèn tín hiệu',[73,1,14,35])],[cue('Quan sát tín hiệu đèn và hướng rẽ.','light'),wait('Xe của bạn nhường lượt.','self'),cue('Xe tải đi trước theo đáp án nguồn.','truck')])
photo(592,[('car','Xe con',[10,56,29,31]),('moto','Mô tô',[38,52,20,29]),('rail','Đường sắt và khoảng cách',[19,28,58,43])],[cue('Đối chiếu vị trí hai xe với đường sắt và khoảng cách ghi trong ảnh.','rail'),cue('Xe con dừng đúng theo đáp án nguồn.','car'),block('Xe mô tô không dừng đúng.','moto')])
photo(593,[('self','Xe của bạn',[46,64,16,16]),('truck','Xe tải',[0,38,33,26]),('cycle','Xe đạp',[50,45,12,18])],[cue('Lượt 1: xe của bạn.','self'),cue('Lượt 2: xe tải.','truck'),cue('Lượt 3: xe đạp.','cycle')])
photo(594,[('one','Hướng 1',[35,57,18,23]),('two','Hướng 2',[19,53,21,19])],[cue('Quan sát hai đường rẽ trái được đánh số.','one','two'),cue('Chọn hướng 1 theo đáp án nguồn.','one'),block('Không chọn hướng 2.','two')])
photo(595,[('opposite','Đèn pha xe đối diện',[32,42,27,24]),('ahead','Xe phía trước',[58,51,16,15]),('dash','Chế độ đèn chiếu gần',[71,77,15,13])],[cue('Nhận diện ánh đèn pha từ xe ngược chiều.','opposite'),cue('Giữ nguyên đèn chiếu gần.','dash'),wait('Giảm tốc độ và đi sau xe phía trước.','ahead')])
photo(596,[('gate','Rào chắn đường sắt',[13,56,79,14]),('ped','Người qua đường',[48,40,15,29]),('self','Xe của bạn',[41,68,20,14])],[cue('Quan sát rào chắn đang dịch chuyển.','gate'),wait('Dừng lại trước rào chắn ở khoảng cách an toàn.','self'),cue('Tiếp tục chờ, không vượt qua rào chắn.','gate')])
P(597,[V('red','Xe đỏ nhập làn','car',42,81,15,'#b31b2a',[[42,81],[52,60],[61,40],[72,22]]),V('blue','Xe trên cao tốc','car',18,61,14,'#4673a8',[[18,61],[43,44],[69,26]]),H('merge','Phần đường nhập làn',[53,21,23,45])],[cue('Quan sát đoạn nhập làn và xe trên đường cao tốc.','merge','blue'),cue('Đường nhập làn được vẽ trong đề là đường cần đánh giá.','red',action='forbidden',paths={'red':[[42,81],[52,60],[61,40],[72,22]]}),block('Xe đỏ nhập làn theo mũi tên trong hình là sai.','red')])
P(598,[V('red','Xe đỏ','car',14,79,13,'#b31b2a',[[14,79],[35,64],[54,49],[73,30]]),V('blue','Xe xanh đang vượt','car',39,65,13,'#45b7d4',[[39,65],[57,48],[75,32]]),V('truck','Xe tải','truck',78,31,25,path=[[78,31],[58,48],[36,66]])],[cue('Xe xanh đang thực hiện vượt xe tải.','blue','truck'),wait('Xe đỏ phải chờ, không được vượt trong tình huống này.','red'),block('Không thực hiện đường vượt theo mũi tên của xe đỏ.','red')])
P(599,[V('yellow','Xe vàng','car',49,49,15,'#dfad27',[[49,49],[61,40],[74,24],[88,20]]),V('red','Xe đỏ','car',20,79,14,'#b31b2a',[[20,79],[41,64],[64,46]]),V('blue','Xe xanh','car',85,23,13,'#45b7d4',[[85,23],[64,41],[43,58]])],[cue('Đối chiếu đường vượt của xe vàng so với hai xe còn lại.','yellow','red','blue'),move('Minh họa xe vàng đi theo đường mũi tên được cho trong đề.','yellow'),cue('Đáp án nguồn xác định đường vượt này là đúng.','yellow')])
P(600,[V('container','Xe container','container',46,50,47,path=[[46,50],[56,58],[65,70],[81,80]]),V('blue','Xe con xanh','car',19,88,15,'#244b9a',[[19,88],[38,71],[58,56]]),V('moto','Xe mô tô','moto',30,89,10,path=[[30,89],[45,72],[61,57]])],[wait('Xe con và mô tô giảm tốc độ, chờ phía sau.','blue','moto'),move('Xe container hoàn thành lượt rẽ phải trước.','container',duration=7),cue('Chỉ đi tiếp sau khi container đã rẽ xong; không vượt hai bên.','blue','moto')],note='Bản nháp: mô hình container đi theo đường tâm; khớp xoay rơ-moóc cần được duyệt riêng.')

def adjust(n,id,path,width=None):
    actor=next(a for a in scenes[str(n)]['actors'] if a['id']==id)
    actor['at']=path[0];actor['path']=path
    if width:actor['width']=width

# Refined against the individual original JPEGs, not a shared intersection template.
adjust(487,'truck',[[92,76],[74,61],[56,44],[41,26]],27)
adjust(487,'moto',[[27,26],[39,39],[51,46],[64,44],[84,34]],12)
adjust(487,'bus',[[83,23],[67,33],[43,45],[14,58]],24)
adjust(487,'car',[[10,74],[29,64],[49,53],[54,44],[49,37],[37,28]],18)
adjust(488,'police',[[21,33],[35,46],[53,66],[71,86]],17)
adjust(488,'car',[[89,79],[70,64],[52,47],[35,32]],18)
adjust(488,'truck',[[74,32],[56,44],[34,57],[11,69]],24)
adjust(488,'bus',[[9,89],[27,76],[45,60],[49,47],[42,40],[31,35]],25)
adjust(489,'police',[[86,85],[66,64],[48,44],[32,28]],18)
adjust(489,'truck',[[74,29],[55,42],[34,54],[12,65]],25)
adjust(489,'bus',[[10,87],[29,75],[45,64],[49,53],[44,47],[32,52],[16,67]],25)
adjust(489,'car',[[22,31],[36,44],[48,53],[61,48],[77,37]],17)
adjust(491,'truck',[[61,65],[70,53],[73,43],[68,34],[59,28],[45,24],[25,26],[8,23]],21)
adjust(491,'car',[[82,73],[78,57],[78,44],[72,34],[62,25],[56,17],[56,9]],14)
adjust(492,'car',[[14,29],[26,39],[40,50],[54,51],[67,44],[79,37]],17)
adjust(492,'moto',[[91,78],[72,66],[50,45],[31,29]],13)
adjust(493,'a',[[23,62],[42,51],[63,40],[83,31]],17)
adjust(493,'ambulance',[[74,21],[59,32],[40,43],[35,52],[42,63],[65,87]],21)
adjust(493,'b',[[88,75],[67,57],[49,40],[30,24]],18)
adjust(494,'fire',[[86,64],[65,49],[43,34],[20,26]],31)
adjust(494,'ambulance',[[56,16],[43,30],[25,47],[3,60]],18)
adjust(494,'car',[[10,82],[26,68],[39,51],[39,40],[31,31],[23,25]],16)
adjust(495,'ambulance',[[87,72],[66,56],[47,41],[30,24]],24)
adjust(495,'moto',[[14,70],[29,58],[41,49],[43,41],[36,34],[25,26]],14)
adjust(497,'truck',[[84,71],[63,55],[46,41],[29,27]],28)
adjust(497,'car',[[11,79],[30,64],[50,49],[70,34]],18)
adjust(498,'fire',[[85,62],[69,51],[57,43],[55,34],[60,26],[64,22]],32)
adjust(498,'police',[[11,72],[29,55],[45,36],[61,19]],18)
adjust(499,'car',[[18,81],[37,67],[61,51],[83,35]],17)
adjust(499,'bus',[[8,74],[28,62],[46,51],[51,42],[45,33],[33,22]],25)
adjust(499,'moto',[[92,70],[70,53],[53,38],[37,21]],12)
adjust(501,'army',[[85,68],[66,55],[47,39],[32,25]],29)
adjust(501,'police',[[11,72],[28,60],[40,50],[43,42],[37,33],[28,26]],18)
adjust(504,'moto',[[82,87],[77,74],[75,64],[78,53],[87,46],[99,43]],10)
adjust(504,'truck',[[7,76],[24,65],[45,60],[59,56],[68,46],[69,38],[64,29],[59,20],[59,12]],23)
adjust(504,'bus',[[11,22],[22,31],[27,44],[29,53],[40,62],[58,66],[70,62],[75,53],[74,42],[67,30],[61,20],[61,12]],24)
adjust(504,'car',[[54,11],[48,22],[36,32],[31,42],[34,51],[45,58],[60,61],[73,59],[83,49],[99,42]],11)
adjust(506,'b',[[88,69],[66,52],[49,38],[34,24]],18)
adjust(506,'a',[[12,71],[31,60],[46,48],[49,39],[42,32],[30,26]],17)
adjust(506,'truck',[[74,23],[55,37],[34,47],[8,59]],25)
adjust(516,'bus',[[80,80],[66,59],[49,38],[35,15],[26,-8]],30)
adjust(516,'truck',[[36,17],[47,36],[62,58],[86,92]],14)
adjust(517,'car',[[90,65],[69,52],[49,43],[36,43],[19,52],[3,62]],18)
adjust(517,'moto',[[15,29],[23,36],[26,43],[22,50],[7,65]],13)
adjust(525,'moto',[[89,75],[69,58],[49,40],[28,24]],13)
adjust(525,'car',[[73,25],[55,39],[32,51],[2,65]],16)
adjust(529,'moto',[[8,28],[19,35],[22,43],[18,50],[3,63]],12)
adjust(529,'truck',[[90,57],[75,51],[51,40]],27)
adjust(529,'car',[[15,76],[31,62],[43,54],[56,55],[73,64]],18)
adjust(530,'car',[[18,80],[41,61],[67,41],[92,24]],18)
adjust(530,'truck',[[37,56],[54,45],[62,34],[57,23],[43,11]],26)
adjust(533,'truck',[[90,64],[73,51],[65,42],[66,34],[75,26]],26)
adjust(533,'bus',[[15,69],[36,52],[54,37],[71,25]],30)
adjust(533,'car',[[68,17],[56,27],[48,34],[49,43],[59,53],[74,67]],11)
adjust(534,'bus',[[17,66],[34,54],[45,46],[53,45],[64,50],[73,61]],30)
adjust(534,'truck',[[89,47],[72,36],[63,30],[63,25],[70,23]],26)
adjust(534,'car',[[62,17],[49,26],[45,33],[49,40],[59,47],[75,57]],11)
adjust(536,'police',[[74,23],[55,36],[35,50],[10,65]],16)
adjust(536,'car',[[90,77],[70,60],[49,42],[34,22]],18)
adjust(536,'truck',[[26,27],[38,41],[50,50],[62,46],[83,33]],24)
adjust(536,'bus',[[11,85],[29,71],[45,60],[50,49],[44,42],[31,50],[12,72]],28)
adjust(540,'army',[[85,66],[65,53],[48,38],[33,26]],28)
adjust(540,'police',[[13,77],[29,64],[42,52],[45,44],[40,36],[29,27]],17)
adjust(540,'car',[[67,28],[48,39],[28,51],[7,60]],15)
adjust(540,'moto',[[59,23],[44,37],[26,51],[10,65]],10)
adjust(541,'a',[[11,59],[20,69],[27,78]],23)
adjust(541,'b',[[60,85],[47,72],[33,61]],29)
adjust(546,'a',[[26,65],[19,71],[8,77]],15)
adjust(546,'b',[[44,65],[39,73],[28,78],[14,81]],13)
adjust(597,'red',[[34,78],[41,56],[48,39],[50,33]],16)
adjust(597,'blue',[[15,50],[40,33],[69,19]],18)
for step in scenes['597']['steps']:
    for action in step['actions']:
        if action['actor']=='red' and action.get('path'):action['path']=[[34,78],[41,56],[48,39],[50,33]]
adjust(599,'yellow',[[54,42],[65,36],[81,29]],16)
adjust(599,'red',[[36,75],[51,60],[65,49]],18)
adjust(599,'blue',[[88,24],[74,35],[62,44]],16)
adjust(600,'container',[[44,53],[56,41],[65,40],[75,45],[84,50]],48)
adjust(600,'blue',[[11,89],[30,74],[50,56]],18)
adjust(600,'moto',[[23,86],[40,70],[58,54]],12)

def refine_routes(n,paths,width=None):
    scene=scenes[str(n)];actor=scene['actors'][0];first=True
    for step in scene['steps']:
        match=__import__('re').search(r'hướng (\d+)',step['text'],__import__('re').IGNORECASE)
        if not match:continue
        key=int(match[1])
        if key not in paths:continue
        for action in step['actions']:
            if action['actor']==actor['id']:
                action['path']=paths[key]
                if first:actor['at']=paths[key][0];actor['path']=paths[key];first=False
    if width:actor['width']=width

refine_routes(502,{1:[[23,80],[38,60],[49,49],[67,52],[87,62]]},28)
refine_routes(507,{1:[[8,76],[31,61],[47,58],[61,63],[85,83]],2:[[8,76],[35,60],[60,47],[84,31]],3:[[8,76],[32,61],[47,49],[51,40],[44,32],[31,25]]},16)
refine_routes(511,{1:[[14,86],[29,74],[49,64],[65,57],[73,46],[69,34],[62,25],[61,10]]},23)
refine_routes(512,{3:[[83,81],[66,60],[54,44],[42,37],[25,39],[5,46]]},18)
refine_routes(514,{2:[[83,81],[63,56],[39,20]],3:[[83,81],[64,57],[51,43],[35,37],[5,45]]},18)
common_origin=[82,81]
one=[common_origin,[66,59],[61,45],[65,36],[82,32]]
west=[common_origin,[65,58],[51,43],[34,37],[5,45]]
uturn=[common_origin,[65,58],[53,45],[47,45],[47,50],[50,55]]
north=[common_origin,[64,57],[43,20]]
refine_routes(519,{1:one,3:west,4:uturn},18)
refine_routes(521,{1:one},27)
refine_routes(522,{2:north,3:west},27)
refine_routes(523,{1:[[20,81],[36,58],[48,52],[61,57],[78,67]],5:[[20,81],[36,54],[51,39],[47,35],[43,36],[42,40]]},27)
refine_routes(524,{1:one,3:west,4:uturn},27)
refine_routes(535,{1:one,2:west,3:uturn},27)
refine_routes(537,{1:one,3:uturn,4:north},27)
refine_routes(539,{1:[[11,68],[33,59],[49,59],[61,67],[78,84]],3:[[11,68],[32,58],[47,46],[54,40],[51,34],[39,27]]},15)

assert set(scenes)=={str(n) for n in range(486,601)}, sorted({str(n) for n in range(486,601)}-set(scenes))
from animation_vehicle_catalog import apply_vehicle_catalog
apply_vehicle_catalog(scenes)
from animation_feedback_repairs import apply_feedback_repairs
apply_feedback_repairs(scenes)
road_calibrations=json.loads((DEST/'road-calibration.json').read_text(encoding='utf8'))
for number,scene in scenes.items():
    if number in road_calibrations and scene.get('perspective')!='driver':
        scene['roadCalibration']=road_calibrations[number]
source_routes=json.loads((DEST/'source-routes.json').read_text(encoding='utf8'))
assert source_routes['sourceSha256']==bank['sourceSha256']
if '--trace-base' in sys.argv:source_routes={**source_routes,'questions':{}}
for number,scene in scenes.items():
    if scene.get('motionVersion')==2:continue
    routes=source_routes['questions'].get(number,{})
    for actor in scene['actors']:
        traced=routes.get('actors',{}).get(actor['id'])
        if traced:
            actor['path']=[actor['at']]+traced['path'][1:]
            actor['guidePath']=traced['guidePath'];actor['routeSource']=traced.get('method','source-pixel-trace')
        elif actor['path']:
            actor['guidePath']=[]
    for index,step in enumerate(scene['steps']):
        for action in step['actions']:
            if action.get('path'):
                traced=routes.get('actions',{}).get(str(index)+':'+action['actor'])
                if traced:action['path']=traced['path'];action['guidePath']=traced['guidePath']
                else:action['guidePath']=[]
    # Vehicles initially occupy a straight lane. An explicit short entry segment
    # prevents a spline from rotating the nose toward a later turn while parked.
    if scene.get('roadCalibration'):
        image=questions[int(number)]['images'][0];w,h=image['width'],image['height']
        axes=[(math.cos(math.radians(a)),math.sin(math.radians(a))) for a in scene['roadCalibration']['angles']]
        axes+= [(-x,-y) for x,y in list(axes)]
        def lane_entry(path):
            if len(path)<2:return path
            x,y=path[0];dx=(path[1][0]-x)*w/100;dy=(path[1][1]-y)*h/100;length=math.hypot(dx,dy)
            if length<4:return path
            ux,uy=max(axes,key=lambda a:(a[0]*dx+a[1]*dy)/length)
            entry=min(12,length*.35)
            return [path[0],[round(x+ux*entry/w*100,4),round(y+uy*entry/h*100,4)]]+path[1:]
        for actor in scene['actors']:
            if actor['path']:actor['path']=lane_entry(actor['path'])
        for step in scene['steps']:
            for action in step['actions']:
                if action.get('path'):action['path']=lane_entry(action['path'])
allowed={'car','moto','truck','bus','police','ambulance','fire','army','bicycle','container','van','train','tricycle','pedestrian','barrier','marker'}
background_path=ROOT/'content-animations/clean-plates/manifest.json'
backgrounds=json.loads(background_path.read_text(encoding='utf8')) if background_path.exists() else {'questions':{}}
if backgrounds['questions']:assert backgrounds['sourceSha256']==bank['sourceSha256']
renderer_hash=hashlib.sha256()
for filename in ['review-player.js','review-motion.mjs','review-clean-background.mjs','review-vehicles.js','review-humans.js','review-layout.mjs','review-detailed-fleet.js','review-ground.mjs','q490-detailed-models.js','review.css']+[str(p.relative_to(ROOT/'content-animations')).replace('\\','/') for p in sorted((ROOT/'content-animations/models').rglob('*.glb'))]:
    renderer_hash.update(filename.encode())
    renderer_hash.update((ROOT/'content-animations'/filename).read_bytes())
renderer_revision=renderer_hash.hexdigest()[:16]
for key,scene in scenes.items():
    scene['mode']='3d'
    scene['rendererRevision']=renderer_revision
    if scene.get('vehicleCount') and key in backgrounds['questions']:
        scene['cleanBackground']=backgrounds['questions'][key]
    ids={a['id'] for a in scene['actors']}
    assert len(ids)==len(scene['actors'])
    assert all(a['kind'] in allowed for a in scene['actors'])
    for step in scene['steps']:
        for action in step['actions']:
            assert action['actor'] in ids
            actor=next(a for a in scene['actors'] if a['id']==action['actor'])
            if action['action']=='move':assert len(action.get('path',actor['path']))>=2,(key,action)
    scene['revision']=hashlib.sha256(json.dumps(scene,ensure_ascii=False,sort_keys=True).encode()).hexdigest()[:16]
from animation_feedback_repairs_v2 import apply_feedback_v2
apply_feedback_v2(scenes,ROOT)
from animation_feedback_repairs_v3 import apply_feedback_v3
apply_feedback_v3(scenes,ROOT)
from animation_feedback_repairs_v4 import apply_feedback_v4
apply_feedback_v4(scenes,ROOT)
(DEST/'scenes.json').write_text(json.dumps(dict(version=1,sourceSha256=bank['sourceSha256'],scenes=scenes),ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(dict(count=len(scenes),three=sum(s['mode']=='3d' for s in scenes.values()),photo=sum(s['mode']=='photo' for s in scenes.values()),steps=sum(len(s['steps']) for s in scenes.values()))))
