import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { exportReview,importReview,emptyReview } from '../content-animations/review-state.mjs';
import { groundFrame,groundPoint,imagePoint,laneHeading } from '../content-animations/review-ground.mjs';
import { isRollingTyreName } from '../content-animations/review-detailed-fleet.js';
import { cleanPlateMask } from '../content-animations/review-clean-background.mjs';

const root=path.resolve(import.meta.dirname,'../content-animations');
const bank=JSON.parse(fs.readFileSync(path.join(root,'bank-review/bank.json'),'utf8'));
const data=JSON.parse(fs.readFileSync(path.join(root,'bank-review/scenes.json'),'utf8'));
const scenes=data.scenes;

test('clean backgrounds reference immutable sources and intact separate assets',()=>{
  const manifest=JSON.parse(fs.readFileSync(path.join(root,'clean-plates/manifest.json'),'utf8'));
  assert.equal(manifest.sourceSha256,bank.sourceSha256);
  assert.equal(Object.keys(manifest.questions).length,109);
  for(const [number,bg] of Object.entries(manifest.questions)){
    const source=bank.questions.find(q=>q.number===Number(number)).images[0];
    assert.equal(bg.sourceSha256,source.sha256);assert.equal(bg.width,source.width);assert.equal(bg.height,source.height);
    assert.notEqual(bg.url,source.url);assert.equal(crypto.createHash('sha256').update(fs.readFileSync(path.join(root,bg.url))).digest('hex'),bg.sha256);
    assert.deepEqual(scenes[number].cleanBackground,bg);assert.equal(bg.status,'draft');
    assert.ok(bg.regions.length>0);for(const polygon of [...bg.regions,...bg.protectedRegions]){assert.ok(polygon.length>=3);for(const p of polygon)assert.ok(p.length===2&&p.every(n=>Number.isFinite(n)&&n>=0&&n<=100));}
  }
  assert.equal(scenes[486].cleanBackground.url,scenes[503].cleanBackground.url);
  assert.equal(scenes[554].cleanBackground.url,scenes[566].cleanBackground.url);
  assert.ok(!scenes[570].cleanBackground);
});

test('CSS clean mask exposes only vehicle regions and cuts protected traffic signals back out',()=>{
  const value=cleanPlateMask({regions:[[[10,20],[30,20],[30,40],[10,40]]],protectedRegions:[[[11,21],[12,21],[12,22]]]},500,300);
  const xml=decodeURIComponent(value.slice('url("data:image/svg+xml,'.length,-2));
  assert.match(xml,/points="50,60 150,60 150,120 50,120"/);
  assert.match(xml,/<mask id="keep">/);assert.match(xml,/<g fill="black"><polygon/);assert.match(xml,/mask="url\(#keep\)"/);
  // Outside the polygons the SVG stays transparent, exposing the original image.
  assert.equal((xml.match(/<rect/g)||[]).length,1);
});

test('all 115 source questions have original images, one underlined option and source proof',()=>{
  assert.deepEqual(bank.questions.map(q=>q.number),Array.from({length:115},(_,i)=>486+i));
  assert.equal(data.sourceSha256,bank.sourceSha256);
  for(const q of bank.questions){
    assert.equal(q.correctOptionIds.length,1,`Q${q.number}`);assert.equal(q.options.filter(o=>o.underlined).length,1);
    assert.ok(fs.statSync(path.join(root,q.sourceQuestionUrl)).size>1000);
    for(const image of q.images){const bytes=fs.readFileSync(path.join(root,image.url));assert.equal(crypto.createHash('sha256').update(bytes).digest('hex'),image.sha256);}
    assert.match(q.sourceUrl,new RegExp('#page='+q.pdfPage+'$'));
  }
  assert.deepEqual(bank.questions.find(q=>q.number===490).correctOptionIds,[3]);
  assert.deepEqual(bank.questions.find(q=>q.number===507).correctOptionIds,[1]);
  assert.deepEqual(bank.questions.find(q=>q.number===600).correctOptionIds,[2]);
});

test('115 individually authored recipes have valid targets and complete motion paths',()=>{
  assert.equal(Object.keys(scenes).length,115);let three=0,steps=0;
  for(const q of bank.questions){
    const s=scenes[q.number];assert.ok(s);assert.equal(s.status,'draft');assert.ok(s.steps.length>=2);steps+=s.steps.length;
    assert.match(s.revision,/^[a-f0-9]{16}$/);assert.ok(['photo','3d'].includes(s.mode));if(s.mode==='3d')three++;
    const actors=new Map(s.actors.map(a=>[a.id,a]));assert.equal(actors.size,s.actors.length);
    // Short instructions such as "Giảm tốc độ." are valid; require content, not a word quota.
    for(const step of s.steps){assert.ok(typeof step.text==='string'&&step.text.trim().length>0);assert.ok(step.duration>=2&&step.duration<=10);for(const action of step.actions){assert.ok(actors.has(action.actor));if(action.action==='move'){
      const actor=actors.get(action.actor),route=action.path||actor.path;
      // A 48%-wide trailer needs more clearance than the old fixed [-35,140]
      // centre-point range. Keep bounded finite coordinates relative to its size.
      const extent=Math.max(40,actor.width||0,...(actor.rect?.slice(2)||[0]))+12;
      assert.ok(route.length>=2);assert.ok(route.every(p=>p.length===2&&p.every(n=>Number.isFinite(n)&&n>=-extent&&n<=100+extent)));
    }}}
  }
  // Cue count changes when source-only highlights become real camera moves;
  // validity is enforced per question/action, rather than an old total of 444.
  assert.equal(three,115);assert.ok(Object.values(scenes).some(s=>s.worldScene));
});

test('compliance question 486 compares independently and never drives a prohibited route',()=>{
  const s=scenes[486];assert.equal(s.learningMode,'compliance');
  assert.equal(s.vehicleCount,5);
  const moves=s.steps.flatMap(step=>step.actions).filter(action=>action.action==='move');
  assert.equal(moves.filter(a=>a.verdict==='valid').length,1);
  assert.equal(moves.find(a=>a.verdict==='valid').actor,'car');
  for(const invalid of moves.filter(a=>a.verdict==='invalid'))assert.equal(invalid.stopAt,0);
});

test('parked participants have models without invented movement and camera car stays a viewpoint',()=>{
  const supported=new Set(['car','moto','truck','bus','police','ambulance','fire','army','bicycle','container','van','train','tricycle','pedestrian','barrier']);
  const found=new Set();
  for(const scene of Object.values(scenes)) {
    const vehicles=scene.actors.filter(a=>a.kind!=='marker');assert.equal(vehicles.length,scene.vehicleCount);
    for(const a of vehicles){assert.ok(supported.has(a.kind));found.add(a.kind);if(a.anchor==='box'){assert.equal(a.rect.length,4);assert.ok(a.heading.every(Number.isFinite));}}
    assert.ok(scene.actors.filter(a=>a.id==='self').every(a=>a.kind==='marker'));
  }
  assert.deepEqual([...found].sort(),[...supported].sort());
  assert.ok(scenes[505].actors.some(a=>a.id==='truck'&&a.kind==='truck'));
  assert.ok(!scenes[505].steps.flatMap(s=>s.actions).some(a=>a.action==='move'));
  assert.ok(scenes[592].actors.some(a=>a.kind==='train'));
  assert.equal(scenes[570].vehicleCount,0);
  assert.equal(scenes[552].actors.find(a=>a.id==='ahead').kind,'car');
  assert.ok(scenes[552].worldScene.participants.ahead);
  assert.equal(scenes[564].actors.find(a=>a.id==='ahead').kind,'marker');
});

test('review export/import retains notes, markers and approvals for the same revision',()=>{
  const r={...emptyReview(490,scenes[490].revision),status:'approved',notes:'Đường rẽ đã ổn.',markers:[{x:32.5,y:57.2}],updatedAt:'2026-10-31T02:00:00Z'};
  const exported=exportReview(bank,scenes,{490:r});assert.equal(exported.records.length,115);
  const restored=importReview(exported,bank,scenes);assert.equal(restored[490].status,'approved');assert.equal(restored[490].notes,r.notes);assert.deepEqual(restored[490].markers,r.markers);
});

test('changed animation revision invalidates old approval but retains feedback',()=>{
  const payload=exportReview(bank,scenes,{490:{...emptyReview(490,'previous'),status:'approved',notes:'Cần đối chiếu lại.',markers:[{x:10,y:20}]}});
  const restored=importReview(payload,bank,scenes);assert.equal(restored[490].status,'pending');assert.equal(restored[490].revision,scenes[490].revision);assert.equal(restored[490].previousRevision,'previous');assert.equal(restored[490].notes,'Cần đối chiếu lại.');
});

test('foreign sources, duplicate questions and invalid markers cannot corrupt review state',()=>{
  const original=exportReview(bank,scenes,{});
  assert.throws(()=>importReview({...original,sourceSha256:'wrong'},bank,scenes));
  assert.throws(()=>importReview({...original,records:[original.records[0],original.records[0]]},bank,scenes));
  assert.throws(()=>importReview({...original,records:[{...original.records[0],number:999}]},bank,scenes));
  assert.throws(()=>importReview({...original,records:[{...original.records[0],markers:[{x:-1,y:10}]}]},bank,scenes));
  assert.throws(()=>importReview({...original,records:[{...original.records[0],status:'published'}]},bank,scenes));
});

test('road projection round-trips and longitudinal headings stay parallel to image lanes',()=>{
  for(const q of bank.questions) {
    const recipe=scenes[q.number],{width,height}=q.images[0],f=groundFrame(recipe,width);
    for(const p of [[0,0],[100,100],[23.5,87.2],[50,50]]) {
      const projected=imagePoint(groundPoint(p,f,width,height),f,width,height);
      assert.ok(Math.hypot(projected[0]-p[0],projected[1]-p[1])<1e-9);
    }
    for(const a of recipe.actors.filter(a=>a.kind!=='marker')) {
      const heading=laneHeading(a.heading||[1,-.5],f);
      const origin=groundPoint([50,50],f,width,height),end=groundPoint([50+heading[0]*100/width,50+heading[1]*100/height],f,width,height);
      const yaw=-Math.atan2(end.z-origin.z,end.x-origin.x);
      const start=imagePoint({x:0,z:0},f,width,height),nose=imagePoint({x:Math.cos(yaw),z:-Math.sin(yaw)},f,width,height);
      const dx=(nose[0]-start[0])*width,dy=(nose[1]-start[1])*height;
      assert.ok(Math.abs(dx*heading[1]-dy*heading[0])/(Math.hypot(dx,dy)*Math.hypot(...heading))<1e-9,`Q${q.number} ${a.id}`);
    }
  }
});

test('the detailed fleet is delivered as intact CC0 GLB meshes, with recorded download hashes',()=>{
  const manifest=JSON.parse(fs.readFileSync(path.join(root,'models/vehicles-manifest.json'),'utf8'));
  assert.equal(manifest.length,9);
  for(const asset of manifest){
    const bytes=fs.readFileSync(path.join(root,'models',asset.file));assert.equal(bytes.toString('ascii',0,4),'glTF');assert.equal(bytes.readUInt32LE(8),bytes.length);
    assert.equal(crypto.createHash('sha256').update(bytes).digest('hex'),asset.sha256);assert.equal(asset.license,'CC0-1.0');
    const gltf=JSON.parse(bytes.toString('utf8',20,20+bytes.readUInt32LE(12)));assert.match(gltf.asset.copyright,/CC0/);assert.ok(gltf.meshes.length>=10);
    assert.ok(gltf.accessors.filter(a=>a.type==='VEC3').reduce((sum,a)=>sum+a.count,0)>1000);
    // GLTFLoader replaces spaces in names with underscores. Rigging must still
    // detect the tires, or a wheelbase-based heading degenerates to atan2(0,0).
    if(asset.name!=='locomotive')assert.ok(gltf.nodes.filter(n=>isRollingTyreName((n.name||'').replaceAll(' ','_'))).length>=2,asset.name);
  }
});

test('source-arrow tracing cannot truncate the destination of a vehicle movement',()=>{
  const traced=JSON.parse(fs.readFileSync(path.join(root,'bank-review/source-routes.json'),'utf8'));
  for(const [number,entry] of Object.entries(traced.questions)) {
    // The new review explicitly replaces pixel traces; its routes are checked
    // for continuous movement and complete exits in animation-feedback.test.mjs.
    if(scenes[number].motionVersion===2)continue;
    for(const [id,route] of Object.entries(entry.actors))if(route.originalEnd){
      const actor=scenes[number].actors.find(a=>a.id===id);if(actor)assert.deepEqual(actor.path.at(-1),route.originalEnd,`Q${number} ${id}`);
    }
    for(const [key,route] of Object.entries(entry.actions))if(route.originalEnd){
      const [index,id]=key.split(':');const action=scenes[number].steps[Number(index)].actions.find(a=>a.actor===id);assert.deepEqual(action.path.at(-1),route.originalEnd);
    }
  }
});
