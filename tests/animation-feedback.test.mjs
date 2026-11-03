import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { roadCurve,travelProgress } from '../content-animations/review-motion.mjs';
import { ReviewPlayer } from '../content-animations/review-player.js';
import { groundFrame,imagePoint } from '../content-animations/review-ground.mjs';
import { importReview } from '../content-animations/review-state.mjs';
import {worldPose} from '../content-animations/review-traffic.mjs';
import * as THREE from '../content-animations/vendor/three/three.module.min.js';
const read=p=>JSON.parse(fs.readFileSync(new URL(p,import.meta.url),'utf8'));
const bank=read('../content-animations/bank-review/bank.json');
const scenes=read('../content-animations/bank-review/scenes.json').scenes;
const feedback=read('../output/animation-review/user-feedback-2026-10-31.json');
const playerFor=n=>{
  const player=Object.create(ReviewPlayer.prototype),q=bank.questions.find(q=>q.number===n);
  Object.assign(player,{recipe:scenes[n],width:q.images[0].width,height:q.images[0].height,curves:new Map(),time:0});
  player.groundFrame=groundFrame(player.recipe,player.width);return player;
};

test('the complete user review survives changed revisions and repeated imports',()=>{
  assert.equal(feedback.records.length,115);
  assert.equal(feedback.records.filter(r=>r.status==='approved').length,12);
  const first=importReview(feedback,bank,scenes);
  const again=importReview({...feedback,records:Object.values(first)},bank,scenes);
  for(const original of feedback.records){
    for(const actual of [first[original.number],again[original.number]]){
      assert.equal(actual.notes,original.notes);assert.deepEqual(actual.markers,original.markers);
      if(actual.previousRevision)assert.equal(actual.previousStatus,original.status);
    }
  }
});

test('non-POV recipes from the original 44 approvals retain their accepted content',()=>{
  const before=read('../output/animation-review/scenes-before-feedback-2026-11-01.json').scenes;
  const latest=read('../output/animation-review/user-feedback-2026-11-01.json');
  assert.equal(latest.records.filter(r=>r.status==='approved').length,44);
  for(const r of latest.records.filter(r=>r.status==='approved'&&scenes[r.number].perspective!=='driver')){
    for(const field of ['actors','steps','note','roadCalibration','learningMode','perspective','cleanBackground']){
      assert.deepEqual(scenes[r.number][field],before[r.number][field],`Q${r.number} ${field}`);
    }
  }
});

test('straight roads stay straight and corner tangents are continuous',()=>{
  const curve=roadCurve([[10,20],[40,50],[70,80]],100,100,p=>new THREE.Vector3(...p,0));
  for(let i=0;i<=100;i++){const p=curve.getPointAt(i/100);assert.ok(Math.abs(p.y-p.x-10)<1e-7);}
  const turn=roadCurve([[0,0],[50,0],[50,50]],100,100,p=>new THREE.Vector3(...p,0));
  let previous=turn.getTangentAt(0);
  for(let i=1;i<=1000;i++){const tangent=turn.getTangentAt(i/1000);assert.ok(previous.dot(tangent)>.99);previous=tangent;}
  assert.equal(travelProgress(0),0);assert.equal(travelProgress(1),1);
  for(let i=1;i<=1000;i++)assert.ok(travelProgress(i/1000)>travelProgress((i-1)/1000));
});

test('all authored moves stay finite, seek deterministically and finish their routes',()=>{
  for(const q of bank.questions){
    const p=playerFor(q.number);let start=0;
    for(const [index,step] of p.recipe.steps.entries()){
      for(const progress of [0,.001,.1,.25,.5,.75,.999,1]){
        const state={index,step,progress,start},poses=p.actorPoses(state);
        for(const pose of poses.values())assert.ok([pose.point.x,pose.point.y,pose.point.z,pose.yaw,pose.distance].every(Number.isFinite),`Q${q.number} step ${index}`);
        for(const a of step.actions.filter(a=>a.action==='move')){
          const actor=p.recipe.actors.find(v=>v.id===a.actor),pose=poses.get(a.actor);
          if(progress===1){const expected=p.pose(actor,a.path||actor.path,a.stopAt??1);assert.ok(pose.point.distanceTo(expected.point)<1e-7);}
        }
        assert.deepEqual(p.actorPoses(state),poses);
      }
      start+=step.duration;
    }
  }
});

test('517 yields to motorcycle; 525 continues the car; 600 waits for trailer',()=>{
  const moves=n=>scenes[n].steps.flatMap(s=>s.actions.filter(a=>a.action==='move').map(a=>a.actor));
  assert.deepEqual(moves(517),['moto','car']);assert.deepEqual(moves(525),['moto','car']);
  assert.equal(scenes[600].actors.filter(a=>a.kind==='moto').length,3);
  assert.equal(moves(600)[0],'container');
  assert.deepEqual(moves(600),['container'],'the latest review asks every other vehicle to stay still');
  assert.ok(scenes[600].actors.find(a=>a.id==='container').articulated);
});

test('pedestrians finish clear of the driving corridor before the camera car proceeds',()=>{
  for(const n of [573,587]){
    const p=playerFor(n),ped=p.recipe.actors.find(a=>a.id==='ped'),ego=p.recipe.actors.find(a=>a.id==='self');
    const pedestrianStep=p.recipe.steps.findIndex(s=>s.actions.some(a=>a.actor==='ped'&&a.action==='move'));
    const drivingStep=p.recipe.steps.findIndex(s=>s.actions.some(a=>a.actor==='self'&&a.action==='move'));
    assert.ok(pedestrianStep>=0&&pedestrianStep<drivingStep);
    const end=imagePoint(p.pose(ped,ped.path,1).point,p.groundFrame,p.width,p.height);
    for(let i=0;i<=100;i++){
      const point=imagePoint(p.pose(ego,ego.path,i/100).point,p.groundFrame,p.width,p.height);
      assert.ok(Math.hypot(point[0]-end[0],point[1]-end[1])>25,`Q${n}: pedestrian remains in the driving corridor`);
    }
  }
});

test('protected source details do not restore neighbouring original vehicles',()=>{
  const inside=([x,y],polygon)=>{
    let result=false;
    for(let i=0,j=polygon.length-1;i<polygon.length;j=i++){
      const [a,b]=polygon[i],[c,d]=polygon[j];
      if((b>y)!==(d>y)&&x<(c-a)*(y-b)/(d-b)+a)result=!result;
    }
    return result;
  };
  const protectedAt=point=>scenes[513].cleanBackground.protectedRegions.some(p=>inside(point,p));
  for(const point of [[18,81],[75.8,81]])assert.ok(protectedAt(point),'sign face must retain source pixels');
  for(const point of [[10,65],[10,75],[10,85]])assert.ok(!protectedAt(point),'original car must stay masked');
  const keep=(n,point)=>scenes[n].cleanBackground.protectedRegions.some(p=>inside(point,p));
  assert.ok(keep(528,[69,45]),'the traffic officer must retain source pixels');
  for(const point of [[55,50],[60,55],[62,65]])assert.ok(!keep(528,point),'the centre truck must disappear when its model leaves');
  assert.ok(keep(558,[71.5,45]));assert.ok(!keep(558,[75,55]),'the sign must not restore the old car roof');
});

test('594 follows direction 1 to the far junction corner before turning left',()=>{
  const config=scenes[594].worldScene;
  for(let i=0;i<=100;i++){
    const {x,z}=worldPose(config.egoRoute,i/100).point;
    if(z>config.junction-1)assert.ok(x>0,'keep the right lane until the far junction corner');
  }
  const {x,z}=worldPose(config.egoRoute,1).point;
  assert.ok(x<-10&&z<config.junction,'finish the turn in the right lane of the westbound exit');
});

test('red lights and forbidden movements do not become moving actors',()=>{
  const moves=n=>new Set(scenes[n].steps.flatMap(s=>s.actions.filter(a=>a.action==='move').map(a=>a.actor)));
  for(const id of ['car','truck'])assert.ok(!moves(553).has(id));
  for(const id of ['bus','truck','moto'])assert.ok(!moves(562).has(id));
  assert.ok(moves(562).has('car'));
  for(const n of [511,512])assert.ok(!moves(n).has('vehicle'));
  assert.ok(moves(597).has('red'),'the latest review requests a separate lawful merge after the main-lane gap');
  // A prohibition on overtaking is not a prohibition on following slowly.
  assert.ok(moves(598).has('red'));assert.equal(scenes[598].actors.find(a=>a.id==='red').path.length,3);
});

test('non-driver movements clear the frame before the next priority turn',()=>{
  for(const s of Object.values(scenes).filter(s=>s.motionVersion===2&&s.perspective!=='driver')){
    for(const action of s.steps.flatMap(st=>st.actions).filter(a=>a.action==='move'&&a.stopAt!==0)){
      const actor=s.actors.find(a=>a.id===action.actor);if(actor.kind==='marker'||actor.stayInFrame)continue;
      const end=(action.path||actor.path).at(-1);
      assert.ok(end.some(v=>v<=0||v>=100),`Q${s.number} ${actor.id} stops inside the image`);
    }
  }
});

test('the answer after independent direction examples keeps the last completed route',()=>{
  for(const n of [507,514,519,521,522,523,524,535,537,539]){
    const p=playerFor(n),index=p.recipe.steps.length-1,step=p.recipe.steps[index];
    const poses=p.actorPoses({index,step,progress:.5});
    const previous=p.recipe.steps.slice(0,index).findLast(s=>s.actions.some(a=>a.action==='move'));
    for(const action of previous.actions.filter(a=>a.action==='move')){
      const actor=p.recipe.actors.find(a=>a.id===action.actor),expected=p.pose(actor,action.path||actor.path,1);
      assert.ok(poses.get(actor.id).point.distanceTo(expected.point)<1e-8);
    }
  }
});

test('2D has no active UI or renderer, old links resolve to 3D',()=>{
  const root=new URL('../content-animations/',import.meta.url);
  assert.doesNotMatch(fs.readFileSync(new URL('review.html',root),'utf8'),/mode-2d|data-mode="2d"/);
  assert.doesNotMatch(fs.readFileSync(new URL('review-player.js',root),'utf8'),/vehicleSprite|review-sprites/);
  assert.doesNotMatch(fs.readFileSync(new URL('index.html',root),'utf8'),/view=2d/);
  assert.match(fs.readFileSync(new URL('review.js',root),'utf8'),/mode==='2d'\?'3d'/);
});
