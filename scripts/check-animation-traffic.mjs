import fs from 'node:fs/promises';
import * as THREE from '../content-animations/vendor/three/three.module.min.js';
import {GLTFLoader} from '../content-animations/vendor/three/GLTFLoader.js';
import {makeReviewVehicleV2} from '../content-animations/review-vehicles-v2.js';
import {ReviewPlayerV2} from '../content-animations/review-player-v2.js';
import {ReviewPlayerV3} from '../content-animations/review-player-v3.js';
import {ReviewPlayerV4} from '../content-animations/review-player-v4.js';
import {groundFrame} from '../content-animations/review-ground.mjs';
import {driverDepthScale} from '../content-animations/review-layout.mjs';
import {worldPoses,footprint,footprintsIntersect} from '../content-animations/review-traffic.mjs';
const originalLoad=GLTFLoader.prototype.loadAsync;
const geometryLoad=async function(url){const b=await fs.readFile(new URL(url));this.register(()=>({name:'GEOMETRY_ONLY',loadTexture:async()=>new THREE.DataTexture(new Uint8Array([255,255,255,255]),1,1)}));return this.parseAsync(b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength),'');};
GLTFLoader.prototype.loadAsync=geometryLoad;
export async function withGeometryTextures(fn){const previous=GLTFLoader.prototype.loadAsync;GLTFLoader.prototype.loadAsync=geometryLoad;try{return await fn();}finally{GLTFLoader.prototype.loadAsync=previous;}}
const bank=JSON.parse(await fs.readFile(new URL('../content-animations/bank-review/bank.json',import.meta.url),'utf8'));
const scenes=JSON.parse(await fs.readFile(new URL('../content-animations/bank-review/scenes.json',import.meta.url),'utf8')).scenes;
const dimensions={},collisions=[],errors=[];
for(const s of Object.values(scenes).filter(s=>s.rendererVersion>=2)){
 try{
  const models=new Map();
  for(const a of s.actors.filter(a=>a.kind!=='marker')){
   const m=await makeReviewVehicleV2(a.kind,a.color,a),size=m.fitBounds.getSize(new THREE.Vector3());models.set(a.id,m);dimensions[a.kind]=size.toArray();
  }
  if(!s.worldScene&&s.perspective!=='driver'){
   const q=bank.questions.find(q=>q.number===s.number),p=Object.create((s.rendererVersion===4?ReviewPlayerV4:s.rendererVersion===3?ReviewPlayerV3:ReviewPlayerV2).prototype);
   Object.assign(p,{recipe:s,width:q.images[0].width,height:q.images[0].height,groundFrame:groundFrame(s,q.images[0].width),curves:new Map(),models:new Map(),mode:'3d',token:1,modeToken:1,renderer:{setSize(){}},host:{clientWidth:1024},camera:new THREE.OrthographicCamera(),scene:new THREE.Scene()});
   await p.ensureModels(1,1);
   const coupled=new Set((s.connections||[]).map(pair=>pair.sort().join('/')));
   for(const [stepIndex,step] of s.steps.entries())for(let sample=0;sample<=40;sample++){
    const poses=p.actorPoses({index:stepIndex,step,progress:sample/40}),feet=[];
    for(const [id,m] of p.models){
     const pose=poses.get(id),actor=s.actors.find(a=>a.id===id),depth=driverDepthScale(actor,p.toScreen(pose.point)),scale=m.scale*depth,size=m.localBounds.getSize(new THREE.Vector3()),center=m.localBounds.getCenter(new THREE.Vector3()).multiplyScalar(scale).applyAxisAngle(new THREE.Vector3(0,1,0),pose.yaw);center.add(pose.point).addScaledVector(m.offset,depth);
     m.root.scale.setScalar(scale);m.root.position.copy(pose.point).addScaledVector(m.offset,depth);m.root.rotation.y=pose.yaw;m.root.updateWorldMatrix(true,true);
     const projected=[];for(const x of [m.localBounds.min.x,m.localBounds.max.x])for(const y of [m.localBounds.min.y,m.localBounds.max.y])for(const z of [m.localBounds.min.z,m.localBounds.max.z])projected.push(p.toScreen(new THREE.Vector3(x,y,z).applyMatrix4(m.root.matrixWorld)));
     const xs=projected.map(v=>v[0]),ys=projected.map(v=>v[1]);if(Math.max(...xs)<0||Math.min(...xs)>100||Math.max(...ys)<0||Math.min(...ys)>100)continue;
     feet.push({id,foot:footprint(center,pose.yaw,size.x*scale,size.z*scale)});
    }
    for(let i=0;i<feet.length;i++)for(let j=0;j<i;j++){
     const a=feet[i],b=feet[j],pair=[a.id,b.id].sort().join('/');if(coupled.has(pair))continue;
     if(footprintsIntersect(a.foot,b.foot,0)){
      const key=`${s.number}-${stepIndex}-${pair}`;
      if(!collisions.some(c=>c.key===key))collisions.push({key,number:s.number,step:stepIndex,progress:sample/40,pair:[a.id,b.id],overview:true});
     }
    }
   }
  }
  if(s.worldScene){
   for(const [stepIndex,step] of s.steps.entries())for(let sample=0;sample<=40;sample++){
    const poses=worldPoses(s,{index:stepIndex,step,progress:sample/40}),footprints=[];
    for(const [id,m] of models){const spec=s.worldScene.participants[id],pose=poses.get(id);if(!spec||!pose)continue;const size=m.fitBounds.getSize(new THREE.Vector3()),scale=spec.scale??1;footprints.push({id,foot:footprint(pose.point,pose.yaw,size.x*scale,size.z*scale)});}
    const ego=poses.get('self');footprints.push({id:'self',foot:footprint(ego.point,ego.yaw,3.6,1.65)});
    for(let i=0;i<footprints.length;i++)for(let j=0;j<i;j++){
     const a=footprints[i],b=footprints[j];if(s.number===596&&[a.id,b.id].includes('ped')&&[a.id,b.id].includes('sliding-gate'))continue;
     if(footprintsIntersect(a.foot,b.foot,.08)){
      const key=`${s.number}-${stepIndex}-${[a.id,b.id].sort().join('/')}`;
      if(!collisions.some(c=>c.key===key))collisions.push({key,number:s.number,step:stepIndex,progress:sample/40,pair:[a.id,b.id]});
     }
    }
   }
  }
 }catch(e){errors.push({number:s.number,message:e.message});}
}
GLTFLoader.prototype.loadAsync=originalLoad;
export const report={dimensions,collisions,errors,worldScenes:Object.values(scenes).filter(s=>s.worldScene).map(s=>s.number),overviewScenes:Object.values(scenes).filter(s=>s.rendererVersion>=2&&!s.worldScene&&s.perspective!=='driver').map(s=>s.number),samplesPerStep:41};
if(process.argv[1]?.endsWith('check-animation-traffic.mjs'))console.log(JSON.stringify(report,null,2));
