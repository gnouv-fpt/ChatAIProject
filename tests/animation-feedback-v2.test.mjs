import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import crypto from 'node:crypto';
import * as THREE from '../content-animations/vendor/three/three.module.min.js';
import {report,withGeometryTextures} from '../scripts/check-animation-traffic.mjs';
import {makeReviewVehicleV2,TowConnections} from '../content-animations/review-vehicles-v2.js';
import {gripGate} from '../content-animations/review-attachments.mjs';
import {worldPoses,worldPose} from '../content-animations/review-traffic.mjs';
import {importReview} from '../content-animations/review-state.mjs';
const read=p=>JSON.parse(fs.readFileSync(new URL('../'+p,import.meta.url),'utf8'));
// Historical v2 acceptance contract, before the user's later cockpit upgrade.
const scenes=read('content-animations/bank-review/review-baseline-v4.json').scenes,feedback=read('content-animations/bank-review/review-feedback-v2-input.json'),bank=read('content-animations/bank-review/bank.json');

test('44 approvals keep complete recipes/revisions and the original renderer bytes',()=>{
 const before=read('content-animations/bank-review/review-approved-2026-11-01.json').scenes,lock=read('content-animations/bank-review/review-approved-lock-2026-11-01.json');
 for(const n of lock.approved)assert.deepEqual(scenes[n],before[n],`Q${n}: do not invalidate an accepted scene`);
 for(const [file,sha] of Object.entries(lock.files))assert.equal(crypto.createHash('sha256').update(fs.readFileSync(new URL('../content-animations/'+file,import.meta.url))).digest('hex'),sha,file);
 assert.equal(Object.values(scenes).filter(s=>s.rendererVersion>=2).length,71);
});
test('the latest user review seeds 44 approvals and preserves all 71 revision-linked notes',()=>{
 assert.deepEqual(read('content-animations/bank-review/review-feedback-v2-input.json'),feedback);
 const imported=importReview(feedback,bank,scenes);
 assert.equal(Object.values(imported).filter(r=>r.status==='approved').length,44);
 for(const r of feedback.records){assert.equal(imported[r.number].notes,r.notes);assert.deepEqual(imported[r.number].markers,r.markers);if(r.status==='changes'){assert.equal(imported[r.number].status,'pending');assert.equal(imported[r.number].previousStatus,'changes');}}
});
test('real model footprints remain separate throughout the current 42 POV and 38 overview scenes',()=>{
 assert.equal(report.worldScenes.length,42);assert.equal(report.overviewScenes.length,38);assert.equal(report.samplesPerStep,41);
 assert.deepEqual(report.errors,[]);assert.deepEqual(report.collisions,[]);
});
test('POV movement and turning are physical metre-space poses; the railway ego stays stopped',()=>{
 for(const s of Object.values(scenes).filter(s=>s.worldScene)){
  const positions=[];
  for(const [index,step] of s.steps.entries())for(const progress of [0,.25,.5,.75,1]){
   const poses=worldPoses(s,{index,step,progress});for(const p of poses.values())assert.ok([p.point.x,p.point.y,p.point.z,p.yaw].every(Number.isFinite));
   const ego=poses.get('self');assert.equal(ego.point.y,0);positions.push(ego.point);
   assert.deepEqual(worldPoses(s,{index,step,progress}),poses,'scrubbing must reproduce positions');
  }
  const distance=Math.max(...positions.map(p=>p.distanceTo(positions[0])));
  if(s.number===596)assert.equal(distance,0);else assert.ok(distance>=3,`Q${s.number}: camera must move with ego`);
 }
 const path=scenes[544].worldScene.participants.car.route;
 assert.ok(Math.abs(worldPose(path,0).yaw-worldPose(path,1).yaw)>1,'the waiting car really turns left');
});
test('new indicators are attached within 2cm of the actual GLB body surface',async()=>withGeometryTextures(async()=>{
 for(const kind of ['car','truck','moto']){
  const m=await makeReviewVehicleV2(kind,null,{signal:'left'});assert.equal(m.indicators.length,2);m.root.updateMatrixWorld(true);
  const body=[];m.root.traverse(n=>{if(n.isMesh&&!n.userData.attachment)body.push(n);});
  for(const lamp of m.indicators){
   const point=lamp.getWorldPosition(new THREE.Vector3()),direction=new THREE.Vector3(lamp.userData.front?-1:1,0,0);
   const hit=new THREE.Raycaster(point,direction,0,.03).intersectObjects(body,false)[0];assert.ok(hit&&hit.distance<.021,`${kind} ${point.toArray()}: lamp must touch body geometry; distance=${hit?.distance}`);
  }
  m.animate({time:.2,distance:0,scale:1,moving:false});assert.equal(m.indicators[0].material.emissiveIntensity,4);
  m.animate({time:.65,distance:0,scale:1,moving:false});assert.equal(m.indicators[0].material.emissiveIntensity,0);
 }
}));
test('tow cable endpoints follow both transformed vehicles rather than fixed image coordinates',async()=>withGeometryTextures(async()=>{
 const a=await makeReviewVehicleV2('truck'),b=await makeReviewVehicleV2('tricycle');a.localBounds=a.fitBounds;b.localBounds=b.fitBounds;
 a.root.position.set(5,0,0);b.root.position.set(-5,0,0);const scene=new THREE.Scene();scene.add(a.root,b.root);
 const rig=new TowConnections(scene,new Map([['a',a],['b',b]]),[['a','b']]);rig.update();const before=rig.entries[0].mesh.userData.endpoints;
 a.root.position.z=2;b.root.position.z=2;rig.update();const after=rig.entries[0].mesh.userData.endpoints;
 for(let i=0;i<2;i++)assert.ok(Math.abs(after[i][2]-before[i][2]-2)<1e-8);assert.ok(rig.entries[0].mesh.scale.y>0);
}));
test('railway guard grips the moving gate while walking parallel to its rails',async()=>withGeometryTextures(async()=>{
 const guard=await makeReviewVehicleV2('pedestrian'),s=scenes[596];
 for(let i=0;i<=20;i++){
  const state={index:1,step:s.steps[1],progress:i/20},poses=worldPoses(s,state),g=poses.get('sliding-gate'),p=poses.get('ped');
  guard.animate({time:i/20,distance:p.distance,scale:1,moving:true});guard.root.position.copy(p.point);guard.root.rotation.y=p.yaw;guard.root.updateMatrixWorld(true);
  const target=g.point.clone().add(new THREE.Vector3(3.5,1.3125,.075));assert.ok(gripGate(guard,target)<.03,'the hand must stay on the gate');
  assert.ok(p.point.z>s.worldScene.junction+4,'guard must stay beside gate, away from the railway tracks');
 }
}));
