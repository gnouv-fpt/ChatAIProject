import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import crypto from 'node:crypto';
import {importReview} from '../content-animations/review-state.mjs';
import {worldPoses,worldPose} from '../content-animations/review-traffic.mjs';
import {report} from '../scripts/check-animation-traffic.mjs';
const read=p=>JSON.parse(fs.readFileSync(new URL('../content-animations/bank-review/'+p,import.meta.url),'utf8'));
// The v3 contract remains checked against its final archived recipes. V4 has
// separate live tests because the user requested new directions and all POVs.
const scenes=read('review-baseline-v4.json').scenes,before=read('review-baseline-v3.json').scenes,feedback=read('review-feedback-v3-input.json'),lock=read('review-approved-lock-v3.json');
const moving=n=>scenes[n].steps.flatMap(st=>st.actions.filter(a=>a.action==='move').map(a=>a.actor));

test('all 70 latest approvals keep exact recipes, revisions, backgrounds and renderer files',()=>{
 assert.equal(lock.approved.length,70);assert.equal(Object.values(scenes).filter(s=>s.rendererVersion===3).length,45);
 for(const n of lock.approved)assert.deepEqual(scenes[n],before[n],`Q${n}`);
 for(const [file,sha] of Object.entries(lock.files))assert.equal(crypto.createHash('sha256').update(fs.readFileSync(new URL('../content-animations/'+file,import.meta.url))).digest('hex'),sha,file);
 for(const r of feedback.records.filter(r=>r.status==='changes'))assert.notEqual(scenes[r.number].revision,r.revision);
});
test('the 17:27 review retains 70 approvals and all 45 notes/markers on pending repairs',()=>{
 assert.equal(feedback.records.filter(r=>r.status==='approved').length,70);const records=importReview(feedback,read('bank.json'),scenes);
 assert.equal(Object.values(records).filter(r=>r.status==='approved').length,70);
 assert.equal(Object.values(records).filter(r=>r.status==='pending').length,45);
 for(const r of feedback.records){assert.equal(records[r.number].notes,r.notes);assert.deepEqual(records[r.number].markers,r.markers);}
});
test('corrected branch choices keep the source answer priority rather than changing order to avoid collisions',()=>{
 assert.deepEqual(moving(489),['police','truck','bus','car']);assert.deepEqual(moving(504),['moto','truck','bus','car']);
 assert.deepEqual(moving(534),['bus','truck','car']);assert.deepEqual(moving(523),['vehicle']);
 assert.ok(scenes[523].steps.find(s=>s.actions.some(a=>a.action==='move')).text.includes('5'));
 assert.ok(scenes[489].actors.find(a=>a.id==='police').path.at(-1)[0]<0);
 assert.ok(scenes[504].actors.find(a=>a.id==='truck').path.at(-1)[1]<0);
});
test('the blue car waits for the pedestrian and only the container moves in question 600',()=>{
 const s=scenes[573],ped=s.steps.findIndex(st=>st.actions.some(a=>a.actor==='ped'&&a.action==='move')),car=s.steps.findIndex(st=>st.actions.some(a=>a.actor==='car'&&a.action==='move'));
 assert.ok(ped>=0&&car>ped);const state={index:ped,step:s.steps[ped],progress:.8};
 assert.deepEqual(worldPoses(s,state).get('car').point,worldPose(s.worldScene.participants.car.route,0).point);
 assert.deepEqual(moving(600),['container']);assert.equal(scenes[600].actors.find(a=>a.id==='moto-far').path.length,0);
});
test('POV paths, source sign faces, island and guide choices match the latest requests',()=>{
 assert.ok(scenes[544].worldScene.egoModel);assert.equal(moving(547).at(-1),'self');
 assert.ok(scenes[547].worldScene.egoRoute.at(-1)[0]<0);assert.deepEqual(scenes[551].worldScene.egoRoute,[[1.75,0],[1.75,-65]]);
 assert.ok(scenes[569].worldScene.island.length>=3);
 assert.deepEqual(scenes[545].worldScene.guides.map(g=>g.label),['1','2','3','4']);
 assert.deepEqual(scenes[550].worldScene.guides.map(g=>g.label),['A','B']);
 const turnZ=Math.min(...scenes[550].worldScene.egoRoute.map(p=>p[1]));
 assert.ok(turnZ<-22.5&&turnZ>-27,'turn beyond the near crossing (-19) and before the far crossing (-29), not on either zebra');
 assert.deepEqual(scenes[594].worldScene.guides.map(g=>g.label),['1','2']);
 for(const n of [549,550,575,582,584,585,586,587,588])assert.ok(scenes[n].worldScene.sourceSigns.length);
 assert.equal(scenes[584].worldScene.sourceSigns.length,2);assert.equal(scenes[585].worldScene.sourceSigns.length,2);
 const resume=scenes[580].steps.findIndex(st=>st.actions.some(a=>a.actor==='self'&&a.action==='move'&&a.worldPath));
 assert.ok(resume>scenes[580].steps.findIndex(st=>st.actions.some(a=>a.actor==='overtake'&&a.action==='move')));
 assert.ok(scenes[581].steps.slice(0,-1).every(st=>st.actions.some(a=>a.actor==='self'&&a.action==='move')));
 assert.equal(scenes[598].steps[0].actions.find(a=>a.actor==='blue').endAt,.65);
});
test('actual GLB footprints remain separate after the new lane and timing repairs',()=>{
 assert.deepEqual(report.errors,[]);assert.deepEqual(report.collisions,[]);assert.equal(report.samplesPerStep,41);
});
