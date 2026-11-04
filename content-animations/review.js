import { ReviewPlayer } from './review-player.js';
import {ReviewPlayerV2} from './review-player-v2.js';
import {ReviewPlayerV3} from './review-player-v3.js';
import {ReviewPlayerV4} from './review-player-v4.js';
import {releaseReviewVehicle} from './review-vehicles.js';
import { emptyReview,exportReview,importReview } from './review-state.mjs';

const $=id=>document.getElementById(id),KEY='csgt-sa-hinh-review-v1';
const names={pending:'Chưa duyệt',approved:'Đã duyệt',changes:'Cần sửa'};
let bank,scenes,records={},current=486,saveTimer,marking=false,lastStep=-1,storageWritable=true;
function notice(text,error=false){$('notice').textContent=text;$('notice').classList.toggle('error',error);}
function record(){return records[current]||=emptyReview(current,scenes[String(current)].revision);}
function save() {
  clearTimeout(saveTimer);saveTimer=null;if(!bank)return;
  const r=record();r.notes=$('notes').value;r.updatedAt=new Date().toISOString();
  if(storageWritable)try{localStorage.setItem(KEY,JSON.stringify(exportReview(bank,scenes,records)));$('saved-at').textContent='Đã lưu trên trình duyệt';}catch{storageWritable=false;notice('Không lưu được trên trình duyệt. Hãy xuất JSON để giữ kết quả duyệt.',true);}
  else $('saved-at').textContent='Đang giữ trong bộ nhớ · cần xuất JSON';
  updateCounts();updateGrid();
}
function flush(){if(saveTimer)save();saveTimer=null;}
function updateCounts(){const counts={pending:0,approved:0,changes:0};for(const q of bank.questions)counts[records[q.number]?.status||'pending']++;for(const key of Object.keys(counts))$(key+'-count').textContent=counts[key];}
function updateGrid(){
  const search=$('search').value.toLocaleLowerCase('vi').trim(),filter=$('filter').value;
  const list=bank.questions.filter(q=>(filter==='all'||(records[q.number]?.status||'pending')===filter)&&(!search||String(q.number).includes(search)||q.prompt.toLocaleLowerCase('vi').includes(search)));
  $('question-grid').replaceChildren();$('list-count').textContent=`· ${list.length} câu`;
  for(const q of list){const button=document.createElement('button');button.type='button';button.textContent=q.number;button.title=`Câu ${q.number}: ${q.prompt}`;button.className=(records[q.number]?.status||'pending')+(q.number===current?' current':'');button.dataset.question=q.number;if(q.number===current)button.setAttribute('aria-current','page');button.onclick=()=>selectQuestion(q.number);$('question-grid').append(button);}
}
function applyStatus(){
  const r=record();$('review-status').textContent=names[r.status];$('review-status').className='status-badge '+r.status;
  $('notes').value=r.notes;$('marker-count').textContent=`${r.markers.length} dấu`;
  $('saved-at').textContent=r.updatedAt?'Đã lưu trên trình duyệt':'';
  if(r.previousRevision)notice('Animation đã đổi so với bản duyệt cũ ('+(names[r.previousStatus]||'đã có nhận xét')+'). Ghi chú được giữ; câu này cần duyệt lại.');
}
function controls(ready){for(const id of ['play','previous-step','next-step','reset','timeline','approve'])$(id).disabled=!ready||player.mode==='original';$('steps').querySelectorAll('button').forEach(b=>b.disabled=!ready);$('mode-3d').disabled=false;}
function createPlayer(Type=ReviewPlayer){return new Type($('scene'),frame=>{
  if(!bank||player.recipe?.number!==current)return;
  $('timeline').max=frame.total;$('timeline').value=frame.time;
  const time=n=>`${Math.floor(n/60)}:${String(Math.floor(n%60)).padStart(2,'0')}`;
  $('time-output').textContent=`${time(frame.time)} / ${time(frame.total)}`;
  $('step-position').textContent=`Bước ${frame.index+1} / ${player.recipe.steps.length}`;
  $('play').textContent=frame.playing?'Tạm dừng':'▶ Phát';
  if(frame.index!==lastStep){lastStep=frame.index;if(player.ready)$('player-message').textContent=frame.step.text;$('steps').querySelectorAll('button').forEach((b,i)=>b.classList.toggle('active',i===frame.index));}
},state=>{
  controls(state.ready);
  if(state.error){$('player-message').textContent='Không mở được mô hình: '+state.error+'. Có thể chọn Chỉ dẫn trên ảnh để xem phần ảnh nguồn.';$('player-message').classList.add('error');return;}
  $('player-message').classList.remove('error');
  if(!state.ready){$('player-message').textContent='Đang tải ảnh và mô hình…';return;}
  $('player-message').textContent=player.atTime().step.text;
  document.querySelectorAll('[data-mode]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.mode===player.mode)));
  $('mode-note').textContent=player.mode==='3d'?`Dựng ${player.recipe.vehicleCount} mô hình 3D. Xe chờ/đỗ đứng yên; chỉ xe có lượt đi mới chạy.  Chỉ tô thêm đoạn đường đã bám được ảnh nguồn.`+(!player.recipe.vehicleCount?' Góc nhìn người lái: chỉ dẫn hướng xe của bạn; không thêm xe vào khoang lái.':state.background==='ready'?' Nền đã xóa xe gốc trong vùng phương tiện; phần bị che được tái tạo để minh họa. Chọn Ảnh gốc để đối chiếu.':' Chưa tải được nền đã xóa xe; ảnh gốc còn bên dưới mô hình. Chọn lại 3D để thử tải lại.'):player.mode==='original'?'Ảnh gốc trích nguyên từ PDF, không có lớp chỉ dẫn.':'Chỉ dẫn theo bước trên ảnh nguồn. Khung màu và nét tô đường là lớp minh họa, không phải nét trong đề; không tô tiếp những đoạn chưa bám được nét nguồn.';
  if(player.recipe.worldScene)$('mode-note').textContent=player.mode==='original'?'Ảnh gốc trong đề.':'Cảnh 3D dựng lại để minh họa: camera gắn vào xe của bạn, xe chạy trên cùng mặt đường. Chọn Ảnh gốc để đối chiếu đề.';
});}
let player=createPlayer();
function replacePlayer(recipe){
 player.pause();player.token++;player.modeToken++;player.resizeObserver.disconnect();
 for(const model of player.models.values())releaseReviewVehicle(model);
 player.renderer?.dispose();player.pov?.mirrorTarget?.dispose();
 $('scene').classList.remove('revision2','pov-3d');
 for(const key of ['cameraX','cameraZ','cameraYaw','worldModels','guardGripError','egoModel','cockpitVersion'])delete $('scene').dataset[key];
 $('scene').dataset.rendererVersion=String(recipe.rendererVersion||1);
 player=createPlayer(recipe.rendererVersion===4?ReviewPlayerV4:recipe.rendererVersion===3?ReviewPlayerV3:recipe.rendererVersion===2?ReviewPlayerV2:ReviewPlayer);
}

async function selectQuestion(number,push=true){
  if(!bank||!scenes[String(number)])return;flush();current=number;lastStep=-1;marking=false;$('scene').classList.remove('marking');$('mark').setAttribute('aria-pressed','false');$('marker-help').hidden=true;
  const q=bank.questions.find(q=>q.number===number),recipe=scenes[String(number)];
  replacePlayer(recipe);
  const view=requestedMode();if(push)history.pushState(null,'',`#q=${number}${view?'&view='+view:''}`);
  $('position').textContent=`${number-485} / 115`;$('question-number').textContent=`Câu ${number}`;$('prompt').textContent=q.prompt;
  $('source-link').href=q.sourceUrl;$('source-page').textContent=`Trang PDF ${q.pdfPage}`;$('source-question').src=q.sourceQuestionUrl;$('dialog-title').textContent=`Câu ${number} · nguyên câu trong PDF`;
  $('recipe-note').textContent=recipe.note;$('recipe-note').hidden=!recipe.note;
  $('options').replaceChildren();q.options.forEach(option=>{const li=document.createElement('li'),n=document.createElement('span'),text=document.createElement('span');li.className=option.underlined?'correct':'';n.className='option-number';n.textContent=option.id+'.';text.textContent=option.text;li.append(n,text);$('options').append(li);});
  $('steps').replaceChildren();let elapsed=0;recipe.steps.forEach((step,i)=>{const li=document.createElement('li'),button=document.createElement('button'),start=elapsed;button.type='button';button.textContent=`Bước ${i+1}`;button.title=step.text;button.onclick=()=>player.seek(start);li.append(button);$('steps').append(li);elapsed+=step.duration;});
  applyStatus();updateGrid();$('previous-question').disabled=number===486;$('next-question').disabled=number===600;
  if(push)document.querySelector('.question-card').scrollIntoView({block:'start',behavior:'instant'});
  for(const id of ['notes','show-source','request-changes','set-pending','next-pending','mark','clear-marks'])$(id).disabled=false;
  await player.setQuestion(q,recipe,view);if(current===number)player.setMarkers(record().markers);
}
function setStatus(status){flush();const r=record();r.status=status;r.revision=scenes[String(current)].revision;r.previousRevision=null;r.previousStatus=null;save();applyStatus();notice(`Đã lưu Câu ${current}: ${names[status]}.`);}
function nextPending(){for(let offset=1;offset<=115;offset++){const number=486+(current-486+offset)%115;if((records[number]?.status||'pending')==='pending'){selectQuestion(number);return;}}notice('Không còn câu chưa duyệt. Bạn có thể xem lại nhóm Cần sửa.');}
$('notes').oninput=()=>{clearTimeout(saveTimer);saveTimer=setTimeout(save,350);};$('notes').onblur=flush;
$('approve').onclick=()=>{setStatus('approved');if(current<600)selectQuestion(current+1);};
$('request-changes').onclick=()=>setStatus('changes');$('set-pending').onclick=()=>setStatus('pending');$('next-pending').onclick=nextPending;
$('previous-question').onclick=()=>selectQuestion(current-1);$('next-question').onclick=()=>selectQuestion(current+1);
$('search').oninput=()=>bank&&updateGrid();$('filter').onchange=()=>bank&&updateGrid();
$('play').onclick=()=>{if(player.playing)player.pause();else{$('scene').scrollIntoView({block:'start',behavior:'instant'});player.play();}};$('previous-step').onclick=()=>player.step(-1);$('next-step').onclick=()=>player.step(1);$('reset').onclick=()=>player.reset();$('timeline').oninput=()=>player.seek(Number($('timeline').value));$('speed').onchange=()=>player.speed=Number($('speed').value);
$('guides').onchange=()=>{player.guides=$('guides').checked;player.draw();};
document.querySelectorAll('[data-mode]').forEach(button=>button.onclick=async()=>{const mode=button.dataset.mode;history.replaceState(null,'',`#q=${current}&view=${mode}`);await player.setMode(mode);});
$('show-source').onclick=()=>$('source-dialog').showModal();$('close-source').onclick=()=>$('source-dialog').close();
$('mark').onclick=async()=>{if(player.mode==='original')await player.setMode('photo');marking=!marking;player.pause();$('mark').setAttribute('aria-pressed',String(marking));$('scene').classList.toggle('marking',marking);$('marker-help').hidden=!marking;};
$('scene').onclick=event=>{if(!marking||!bank)return;const r=record();if(r.markers.length>=20){notice('Tối đa 20 dấu cho một câu.',true);return;}const box=$('scene').getBoundingClientRect();r.markers.push({x:Math.max(0,Math.min(100,(event.clientX-box.left)/box.width*100)),y:Math.max(0,Math.min(100,(event.clientY-box.top)/box.height*100))});$('marker-count').textContent=`${r.markers.length} dấu`;player.setMarkers(r.markers);save();};
$('clear-marks').onclick=()=>{record().markers=[];player.setMarkers([]);$('marker-count').textContent='0 dấu';save();};
$('export').onclick=()=>{flush();const blob=new Blob([JSON.stringify(exportReview(bank,scenes,records),null,2)],{type:'application/json'}),url=URL.createObjectURL(blob),a=document.createElement('a');a.href=url;a.download=`duyet-sa-hinh-486-600-${new Date().toISOString().slice(0,10)}.json`;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);notice('Đã xuất bản duyệt JSON. Giữ file này để sao lưu hoặc gửi lại kết quả.');};
$('import').onchange=async event=>{const file=event.target.files?.[0];if(!file||!bank)return;try{if(file.size>1024*1024)throw new Error('File duyệt quá lớn.');const imported=importReview(JSON.parse(await file.text()),bank,scenes);flush();records={...records,...imported};storageWritable=true;applyStatus();save();player.setMarkers(record().markers);updateCounts();updateGrid();notice(`Đã nhập kết quả cho ${Object.keys(imported).length} câu.`);}catch(error){notice('Không nhập được: '+error.message,true);}event.target.value='';};
function requestedQuestion(){const n=Number(new URLSearchParams(location.hash.slice(1)).get('q'));return Number.isInteger(n)&&n>=486&&n<=600?n:486;}
function requestedMode(){const mode=new URLSearchParams(location.hash.slice(1)).get('view');return mode==='2d'?'3d':['original','photo','3d'].includes(mode)?mode:'3d';}
window.addEventListener('popstate',()=>bank&&selectQuestion(requestedQuestion(),false));
window.addEventListener('beforeunload',flush);
window.addEventListener('keydown',event=>{if(!bank||/INPUT|TEXTAREA|SELECT|BUTTON/.test(document.activeElement.tagName)||$('source-dialog').open)return;if(event.key==='ArrowLeft'&&current>486){event.preventDefault();selectQuestion(current-1);}if(event.key==='ArrowRight'&&current<600){event.preventDefault();selectQuestion(current+1);}});
window.addEventListener('storage',event=>{if(event.key===KEY&&bank)notice('Bản duyệt đã thay đổi ở tab khác. Xuất kết quả hiện tại trước khi tải lại trang để tránh ghi đè.');});
async function load(){
  $('load-error').hidden=true;
  try {
    const [bankResponse,sceneResponse]=await Promise.all([fetch('bank-review/bank.json',{cache:'no-store'}),fetch('bank-review/scenes.json',{cache:'no-store'})]);
    if(!bankResponse.ok||!sceneResponse.ok)throw new Error('Không tải được dữ liệu.');bank=await bankResponse.json();const data=await sceneResponse.json();scenes=data.scenes;
    if(bank.questions.length!==115||Object.keys(scenes).length!==115||data.sourceSha256!==bank.sourceSha256)throw new Error('Bộ câu hỏi và animation không cùng phiên bản.');
    const seedResponse=await fetch('bank-review/review-feedback.json',{cache:'no-store'});if(seedResponse.ok)records=importReview(await seedResponse.json(),bank,scenes);
    try{const raw=localStorage.getItem(KEY);if(raw){const stored=importReview(JSON.parse(raw),bank,scenes);for(const [n,r] of Object.entries(stored))if(!records[n]||(r.updatedAt||'')>(records[n].updatedAt||''))records[n]=r;}}catch{storageWritable=false;notice('Không đọc được bản duyệt cũ hoặc bộ nhớ trình duyệt bị chặn. Kết quả mới được giữ trong bộ nhớ; hãy xuất JSON để lưu lại.',true);}
    $('export').disabled=false;$('import').disabled=false;updateCounts();
    if(matchMedia('(max-width:760px)').matches)$('question-list').open=false;
    await selectQuestion(requestedQuestion(),false);
  }catch(error){$('load-error').hidden=false;$('load-error').querySelector('p').textContent=error.message;}
}
$('retry').onclick=load;
load();
