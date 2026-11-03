import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import * as THREE from '../content-animations/vendor/three/three.module.min.js';
import { GLTFLoader } from '../content-animations/vendor/three/GLTFLoader.js';
import { makeReviewVehicle,releaseReviewVehicle } from '../content-animations/review-vehicles.js';
import { ReviewPlayer } from '../content-animations/review-player.js';
import {ReviewPlayerV2} from '../content-animations/review-player-v2.js';
import {ReviewPlayerV3} from '../content-animations/review-player-v3.js';
import {ReviewPlayerV4} from '../content-animations/review-player-v4.js';
import { groundFrame } from '../content-animations/review-ground.mjs';
import { driverDepthScale } from '../content-animations/review-layout.mjs';

test('actual fleet meshes rig, clone and articulate without invalid geometry',async()=>{
  // Geometry test only: browser texture decoding and WebGL remain a separate
  // visual check. Real GLB meshes/material parameters are parsed from disk.
  const original=GLTFLoader.prototype.loadAsync;
  GLTFLoader.prototype.loadAsync=async function(url){
    const bytes=await fs.readFile(new URL(url));
    this.register(()=>({name:'TEST_TEXTURE_DECODE',loadTexture:async()=>new THREE.DataTexture(new Uint8Array([255,255,255,255]),1,1)}));
    return this.parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'');
  };
  try{
    for(const kind of ['car','moto','truck','bus','police','ambulance','fire','army','bicycle','container','van','train','tricycle','pedestrian','barrier']){
      const model=await makeReviewVehicle(kind,null,{headlights:kind==='car',openRearDoors:kind==='van',signal:kind==='truck'?'left':null});
      model.animate({time:1,distance:2,scale:.5});
      if(kind==='bicycle'){
        assert.equal(model.pedalPivots.length,2);
        const feet=['FootL','FootR'].map(name=>model.root.getObjectByName(name));assert.ok(feet.every(Boolean));
        for(let sample=0;sample<=40;sample++){
          const distance=sample/40*5.5;model.animate({time:1,distance,scale:1,moving:true});model.root.updateMatrixWorld(true);
          for(const foot of feet){
            const at=foot.getWorldPosition(new THREE.Vector3());
            const pedal=model.pedalPivots.find(p=>Math.sign(p.getWorldPosition(new THREE.Vector3()).z)===Math.sign(at.z));
            const expected=pedal.getWorldPosition(new THREE.Vector3()).add(new THREE.Vector3(-.065,.065,0));
            assert.ok(at.distanceTo(expected)<.003,'ankles must follow the actual moving pedals throughout the cycle');
          }
        }
        model.animate({time:1,distance:1.2,scale:1,moving:true});model.root.updateMatrixWorld(true);const first=feet[0].getWorldPosition(new THREE.Vector3());
        model.animate({time:9,distance:4,scale:1,moving:true});model.animate({time:1,distance:1.2,scale:1,moving:true});model.root.updateMatrixWorld(true);
        assert.ok(first.distanceTo(feet[0].getWorldPosition(new THREE.Vector3()))<1e-6,'backwards seeking must reproduce the same riding pose');
        const second=await makeReviewVehicle('bicycle');second.animate({time:1,distance:1,scale:1,moving:true});second.root.updateMatrixWorld(true);
        const secondFoot=second.root.getObjectByName('FootL'),before=secondFoot.getWorldPosition(new THREE.Vector3());
        model.animate({time:2,distance:2.8,scale:1,moving:true});second.root.updateMatrixWorld(true);
        assert.ok(before.distanceTo(secondFoot.getWorldPosition(new THREE.Vector3()))<1e-8,'cyclists in a group must have independent skeletons');releaseReviewVehicle(second);
      }
      if(kind==='pedestrian'){
        const foot=model.root.getObjectByName('FootL');assert.ok(foot);
        const at=(distance,moving)=>{model.animate({time:1,distance,scale:1,moving});model.root.updateMatrixWorld(true);return foot.getWorldPosition(new THREE.Vector3());};
        assert.ok(at(0,true).distanceTo(at(.475,true))>.1,'walking must move the separately parented foot targets');
        assert.ok(at(0,false).distanceTo(at(3,false))<1e-8,'waiting must use Idle rather than walking in place');
      }
      if(kind==='moto'){
        assert.ok(model.root.getObjectByName('MotorcycleHelmet'));
        assert.ok(model.root.getObjectByName('FullFaceVisor'));
        assert.ok(model.root.getObjectByName('HelmetChinVent'));
        for(const side of ['L','R'])assert.ok(model.root.getObjectByName('Palm'+side),'rider must retain a real skinned hand rig');
      }
      if(kind==='container'){
        assert.ok(model.trailerPivot);assert.ok(model.trailerPivot.children.length>0);
        const wheel=model.wheelList.find(w=>w.pivot.parent===model.trailerPivot);assert.ok(wheel,'trailer wheels must follow the articulated trailer');
        model.root.updateMatrixWorld(true);const before=wheel.pivot.getWorldPosition(new THREE.Vector3());
        model.trailerPivot.rotation.y=.3;model.root.updateMatrixWorld(true);assert.ok(before.distanceTo(wheel.pivot.getWorldPosition(new THREE.Vector3()))>.1);
      }
      const b=new THREE.Box3().setFromObject(model.root);
      assert.ok(!b.isEmpty());assert.ok([...b.min.toArray(),...b.max.toArray()].every(Number.isFinite),kind);
      assert.ok(model.fitBounds.max.y>0,kind);
      if(kind==='car')assert.ok(b.max.x>model.fitBounds.max.x+2,'headlight beam must not shrink the car when sizing it');
      for(const wheel of model.wheelList){assert.ok(wheel.radius>0);assert.ok(wheel.pivot&&wheel.spin);}
      releaseReviewVehicle(model);
    }
    const bank=JSON.parse(await fs.readFile(new URL('../content-animations/bank-review/bank.json',import.meta.url),'utf8'));
    const scenes=JSON.parse(await fs.readFile(new URL('../content-animations/bank-review/scenes.json',import.meta.url),'utf8')).scenes;
    for(const n of Object.keys(scenes).map(Number).filter(n=>scenes[n].motionVersion===2&&!scenes[n].worldScene&&scenes[n].perspective!=='driver')){
      const q=bank.questions.find(q=>q.number===n),p=Object.create((scenes[n].rendererVersion===4?ReviewPlayerV4:scenes[n].rendererVersion===3?ReviewPlayerV3:scenes[n].rendererVersion===2?ReviewPlayerV2:ReviewPlayer).prototype);
      Object.assign(p,{recipe:scenes[n],width:q.images[0].width,height:q.images[0].height,groundFrame:groundFrame(scenes[n],q.images[0].width),curves:new Map(),models:new Map(),mode:'3d',token:1,modeToken:1,renderer:{setSize(){}},host:{clientWidth:1024},camera:new THREE.OrthographicCamera(),scene:new THREE.Scene()});
      await p.ensureModels(1,1);
      for(const action of p.recipe.steps.flatMap(s=>s.actions).filter(a=>a.action==='move')){
        const actor=p.recipe.actors.find(a=>a.id===action.actor),model=p.models.get(actor.id);if(!model||actor.stayInFrame)continue;
        const pose=p.pose(actor,p.pathFor(action,actor),1);
        const depth=driverDepthScale(actor,p.toScreen(pose.point));model.root.scale.setScalar(model.scale*depth);
        model.root.position.copy(pose.point).addScaledVector(model.offset,depth);model.root.rotation.y=pose.yaw+(model.yawOffset||0);model.root.updateWorldMatrix(true,true);
        const points=[];for(const x of [model.localBounds.min.x,model.localBounds.max.x])for(const y of [model.localBounds.min.y,model.localBounds.max.y])for(const z of [model.localBounds.min.z,model.localBounds.max.z])points.push(p.toScreen(new THREE.Vector3(x,y,z).applyMatrix4(model.root.matrixWorld)));
        const xs=points.map(p=>p[0]),ys=points.map(p=>p[1]);
        if(n===581)assert.ok(Math.max(...ys)>=49&&Math.max(...ys)<70,'Q581: tyre contact must remain on the visible highway below its horizon');
        else assert.ok(Math.max(...xs)<0||Math.min(...xs)>100||Math.max(...ys)<0||Math.min(...ys)>100,`Q${n} ${actor.id}: the whole projected vehicle must leave the frame, including its tail`);
      }
      for(const model of p.models.values())releaseReviewVehicle(model);
    }
  }finally{GLTFLoader.prototype.loadAsync=original;}
});
