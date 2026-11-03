import {ReviewPlayer} from './review-player.js';
import {ReviewPlayerV2} from './review-player-v2.js';
import {ReviewPlayerV3} from './review-player-v3.js';
import {ReviewPlayerV4} from './review-player-v4.js';

const $=id=>document.getElementById(id);
const number=Number(new URLSearchParams(location.hash.slice(1)).get('q')||document.body.dataset.question);
const urlFor=n=>`q${n}.html`;
const clock=n=>`${Math.floor(n/60)}:${String(Math.floor(n%60)).padStart(2,'0')}`;
let player,lastStep=-1,loading=false;

function controls(ready){
  const enabled=ready&&player?.mode==='3d';
  for(const id of ['play','previous-step','next-step','reset','timeline'])$(id).disabled=!enabled;
  $('steps').querySelectorAll('button').forEach(b=>b.disabled=!enabled);
}
function frameChanged(frame){
  $('timeline').max=frame.total;$('timeline').value=frame.time;
  $('time-output').textContent=`${clock(frame.time)} / ${clock(frame.total)}`;
  $('step-position').textContent=`Bước ${frame.index+1} / ${player.recipe.steps.length}`;
  $('play').textContent=frame.playing?'Tạm dừng':'▶ Phát';
  if(frame.index!==lastStep){
    lastStep=frame.index;
    if(player.ready&&player.mode==='3d')$('player-message').textContent=frame.step.text;
    $('steps').querySelectorAll('button').forEach((b,i)=>{b.classList.toggle('active',i===frame.index);if(i===frame.index)b.setAttribute('aria-current','step');else b.removeAttribute('aria-current');});
  }
}
function stateChanged(state){
  controls(state.ready);
  $('retry-model').hidden=!state.error;
  $('player-message').classList.toggle('error',Boolean(state.error));
  if(state.error){$('player-message').textContent='Không tải được mô phỏng. Bạn có thể chọn Ảnh gốc hoặc thử tải lại.';return;}
  if(!state.ready){$('player-message').textContent='Đang tải ảnh và mô hình…';return;}
  $('player-message').textContent=state.mode==='original'?'Ảnh gốc trong đề. Chọn Mô phỏng 3D để xem từng bước.':player.atTime().step.text;
  document.querySelectorAll('[data-mode]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.mode===state.mode)));
}
async function json(path){
  const response=await fetch(path,{cache:'no-store'});
  if(!response.ok)throw new Error('Không tải được dữ liệu câu hỏi.');
  return response.json();
}
async function load(){
  if(loading)return;
  loading=true;$('retry').disabled=true;$('load-error').hidden=true;$('loading').hidden=false;
  try{
    const [bank,data,accepted]=await Promise.all([json('bank-review/bank.json'),json('bank-review/scenes.json'),json('bank-review/accepted-release.json')]);
    const question=bank.questions.find(q=>q.number===number),recipe=data.scenes[String(number)];
    if(!question||!recipe)throw new Error('Không tìm thấy câu hỏi này. Bộ sa hình gồm câu 486–600.');
    if(accepted.approvedRevisions[String(number)]!==recipe.revision)throw new Error('Mô phỏng câu này đã thay đổi và cần được duyệt lại trước khi sử dụng.');
    document.title=`Câu ${number} · Minh họa sa hình · lộ trình`;
    $('question-number').textContent=`Lời giải sa hình · Câu ${number}`;$('prompt').textContent=question.prompt;
    $('scene').setAttribute('aria-label',`Minh họa câu ${number}: ${question.prompt}`);
    $('question-choice').replaceChildren(...bank.questions.map(q=>new Option(`Câu ${q.number}`,q.number,false,q.number===number)));
    $('question-choice').disabled=false;
    for(const [id,n] of [['previous-question',number-1],['next-question',number+1]]){
      if(data.scenes[String(n)])$(id).href=urlFor(n);else{$(id).removeAttribute('href');$(id).setAttribute('aria-disabled','true');}
    }
    $('options').replaceChildren();
    for(const option of question.options){
      const li=document.createElement('li'),id=document.createElement('span'),text=document.createElement('span');
      id.className='option-number';id.textContent=`${option.id}.`;text.textContent=option.text;li.append(id,text);
      if(question.correctOptionIds.includes(option.id)){li.className='correct';const tag=document.createElement('span');tag.className='answer-tag';tag.textContent='Đáp án đúng';li.append(tag);}
      $('options').append(li);
    }
    $('source-link').href=question.sourceUrl;
    $('steps').replaceChildren();let elapsed=0;
    recipe.steps.forEach((step,i)=>{
      const li=document.createElement('li'),button=document.createElement('button'),start=elapsed;
      button.type='button';button.textContent=`Bước ${i+1}`;button.title=step.text;button.disabled=true;
      button.onclick=()=>player.seek(start);li.append(button);$('steps').append(li);elapsed+=step.duration;
    });
    const Type=recipe.rendererVersion===4?ReviewPlayerV4:recipe.rendererVersion===3?ReviewPlayerV3:recipe.rendererVersion===2?ReviewPlayerV2:ReviewPlayer;
    player=new Type($('scene'),frameChanged,stateChanged);
    $('scene').dataset.rendererVersion=String(recipe.rendererVersion||1);
    $('lesson').hidden=false;$('loading').hidden=true;
    await player.setQuestion(question,recipe,'3d');
  }catch(error){$('error-text').textContent=error.message;$('load-error').hidden=false;$('loading').hidden=true;}
  finally{loading=false;$('retry').disabled=false;}
}
$('retry').onclick=load;
$('retry-model').onclick=()=>player.setMode('3d');
$('question-choice').onchange=()=>location.assign(urlFor(Number($('question-choice').value)));
$('play').onclick=()=>player.playing?player.pause():player.play();
$('previous-step').onclick=()=>player.step(-1);$('next-step').onclick=()=>player.step(1);$('reset').onclick=()=>player.reset();
$('timeline').oninput=()=>player.seek(Number($('timeline').value));
$('speed').onchange=()=>{if(player)player.speed=Number($('speed').value);};
$('guides').onchange=()=>{if(player){player.guides=$('guides').checked;player.draw();}};
document.querySelectorAll('[data-mode]').forEach(button=>button.onclick=()=>player?.setMode(button.dataset.mode));
window.addEventListener('pagehide',()=>player?.pause());
// Each question has a real HTML path for ExplanationAnimationUrl (which disallows query/fragment).
// A hash entry is supported for local previews; a changed hash reloads into the requested lesson.
window.addEventListener('hashchange',()=>location.reload());
load();
