import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import crypto from 'node:crypto';
import {importReview} from '../content-animations/review-state.mjs';
import {worldPoses} from '../content-animations/review-traffic.mjs';
import {report} from '../scripts/check-animation-traffic.mjs';
import {POV_COCKPIT_VERSION} from '../content-animations/review-pov-v4.js';
const read=p=>JSON.parse(fs.readFileSync(new URL('../content-animations/bank-review/'+p,import.meta.url),'utf8'));
const scenes=read('scenes.json').scenes,before=read('review-baseline-v4.json').scenes,input=read('review-feedback-v4-input.json'),lock=read('review-approved-lock-v4.json');
const moves=n=>scenes[n].steps.flatMap(st=>st.actions.filter(a=>a.action==='move').map(a=>a.actor));

test('the 18:37 review changes only the 13 marked questions and the 42 POVs',()=>{
 const marked=new Set(input.records.filter(r=>r.status==='changes').map(r=>r.number));assert.equal(marked.size,13);
 const pov=Object.values(scenes).filter(s=>s.perspective==='driver');assert.equal(pov.length,42);
 const expected=new Set([...marked,...pov.map(s=>s.number)]);
 const actual=Object.values(scenes).filter(s=>s.revision!==before[s.number].revision).map(s=>s.number);
 assert.deepEqual(new Set(actual),expected);assert.equal(actual.length,52);
 assert.equal(lock.approved.length,63);for(const n of lock.approved)assert.deepEqual(scenes[n],before[n],`Q${n}`);
 for(const [name,sha] of Object.entries(lock.files))assert.equal(crypto.createHash('sha256').update(fs.readFileSync(new URL('../content-animations/'+name,import.meta.url))).digest('hex'),sha,name);
});
test('all 42 POVs use exactly one real-car cockpit, including the eleven previous photo cabins',()=>{
 for(const s of Object.values(scenes).filter(s=>s.perspective==='driver')){
  assert.equal(s.rendererVersion,4);assert.ok(s.worldScene.egoModel);assert.equal(s.worldScene.cockpitVersion,POV_COCKPIT_VERSION);
  for(const [i,step] of s.steps.entries())for(const progress of [0,.5,1]){
   const poses=worldPoses(s,{index:i,step,progress});for(const p of poses.values())assert.ok([p.point.x,p.point.y,p.point.z,p.yaw].every(Number.isFinite));
  }
 }
});
test('approval migration honestly distinguishes 13 rejected repairs from 39 accepted cockpit upgrades',()=>{
 const records=importReview(input,read('bank.json'),scenes);
 assert.equal(Object.values(records).filter(r=>r.status==='approved').length,63);
 assert.equal(Object.values(records).filter(r=>r.status==='pending'&&r.previousStatus==='changes').length,13);
 assert.equal(Object.values(records).filter(r=>r.status==='pending'&&r.previousStatus==='approved').length,39);
 for(const r of input.records){assert.equal(records[r.number].notes,r.notes);assert.deepEqual(records[r.number].markers,r.markers);}
});
test('new notes restore both 523 examples, remove 531 overlay, hold 538/560 and merge 597 once',()=>{
 const examples=scenes[523].steps.filter(st=>st.actions.some(a=>a.action==='move'));assert.equal(examples.length,2);
 assert.ok(examples[0].text.includes('1'));assert.ok(examples[1].text.includes('5'));assert.notDeepEqual(examples[0].actions[0].path,examples[1].actions[0].path);
 assert.equal(scenes[531].sourceGuides,undefined);assert.ok(!moves(538).includes('moto'));
 for(const id of ['bus','moto'])assert.ok(!moves(560).includes(id));
 assert.deepEqual(scenes[562].actors.find(a=>a.id==='moto').at,[68.8,25.2]);
 const red=scenes[597].actors.find(a=>a.id==='red').path;assert.equal(red.length,4);assert.deepEqual(red.slice(-2),[[48,44],[138,-13]]);
 const straight=scenes[599].actors.find(a=>a.id==='red').path;assert.equal(straight.length,2);assert.ok(Math.abs((straight[1][1]-straight[0][1])/(straight[1][0]-straight[0][0])+.9)<1e-9);
 assert.equal(scenes[544].worldScene.sideJunction,'left');assert.ok(scenes[569].worldScene.islandGrass);
});
test('the live geometry audit covers 42 POVs and keeps the full vehicle footprints separate',()=>{
 assert.equal(report.worldScenes.length,42);assert.equal(report.samplesPerStep,41);assert.deepEqual(report.errors,[]);assert.deepEqual(report.collisions,[]);
});
test('the final exported review accepts all 115 exact current revisions',()=>{
 const accepted=read('review-feedback-accepted-2026-11-01.json'),receipt=read('accepted-release.json');
 assert.deepEqual(read('review-feedback.json'),accepted);assert.equal(accepted.records.length,115);
 const records=importReview(accepted,read('bank.json'),scenes);
 assert.equal(Object.values(records).filter(r=>r.status==='approved').length,115);
 for(const r of accepted.records){assert.equal(r.status,'approved');assert.equal(r.revision,scenes[r.number].revision);assert.equal(receipt.approvedRevisions[r.number],r.revision);}
 assert.equal(crypto.createHash('sha256').update(fs.readFileSync(new URL('../content-animations/bank-review/scenes.json',import.meta.url))).digest('hex'),receipt.scenesSha256);
});
