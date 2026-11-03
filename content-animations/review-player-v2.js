import * as THREE from './vendor/three/three.module.min.js';
import {ReviewPlayer} from './review-player.js';
import {makeReviewVehicleV2,TowConnections} from './review-vehicles-v2.js';
import {PovScene} from './review-pov.js';
import {actionProgress} from './review-traffic.mjs';
const NS='http://www.w3.org/2000/svg';
const svg=(tag,attributes)=>{const n=document.createElementNS(NS,tag);for(const [k,v] of Object.entries(attributes))n.setAttribute(k,v);return n;};

export class ReviewPlayerV2 extends ReviewPlayer {
 async ensureModels(token,modeToken=this.modeToken){
  if(this.mode!=='3d')return;
  if(this.recipe.worldScene){
   if(this.pov)return;
   this.pov=new PovScene(this.canvas,this.host,this.recipe);await this.pov.load();
   this.renderer=this.pov.renderer;this.scene=this.pov.scene;this.camera=this.pov.camera;this.models=this.pov.models;return;
  }
  this.initRenderer();this.projectCamera();
  for(const actor of this.recipe.actors.filter(a=>a.kind!=='marker')){
   if(this.models.has(actor.id))continue;
   const model=await makeReviewVehicleV2(actor.kind,actor.color,actor);
   if(token!==this.token||modeToken!==this.modeToken)return;
   const initial=this.pose(actor,actor.path,0),yaw=initial.yaw+(model.yawOffset||0),box=model.fitBounds;model.localBounds=box.clone();
   const points=[];for(const x of [box.min.x,box.max.x])for(const y of [box.min.y,box.max.y])for(const z of [box.min.z,box.max.z]){const p=new THREE.Vector3(x,y,z).applyAxisAngle(new THREE.Vector3(0,1,0),yaw).project(this.camera);points.push([(p.x+1)*this.width/2,(1-p.y)*this.height/2]);}
   const xs=points.map(p=>p[0]),ys=points.map(p=>p[1]),left=Math.min(...xs),right=Math.max(...xs),top=Math.min(...ys),bottom=Math.max(...ys);
   model.scale=actor.width/100*this.width/(right-left);model.offset=new THREE.Vector3();
   if(actor.anchor==='box'){
    model.scale=Math.min(model.scale,actor.rect[3]/100*this.height/(bottom-top));
    const center=[50+((left+right)/2-this.width/2)*model.scale/this.width*100,50+(bottom-this.height/2)*model.scale/this.height*100-actor.rect[3]/2];
    model.offset.copy(this.toGround([50,50])).sub(this.toGround(center));
   }else model.scale=THREE.MathUtils.clamp(model.scale,.18,1.3);
   model.root.scale.setScalar(model.scale);model.initialYaw=initial.yaw;this.models.set(actor.id,model);this.scene.add(model.root);
  }
  if(this.recipe.connections?.length)this.towing=new TowConnections(this.scene,this.models,this.recipe.connections);
 }
 applyMode(){super.applyMode();this.host.classList.add('revision2');this.host.classList.toggle('pov-3d',Boolean(this.recipe.worldScene&&this.mode==='3d'));}
 actorPoses(state){
  const poses=new Map(this.recipe.actors.map(a=>[a.id,this.pose(a,a.path,0)]));
  let first=this.recipe.learningMode==='alternatives'?state.index:0;
  if(first&&!state.step.actions.length)while(first>0&&!this.recipe.steps[first].actions.some(a=>a.action==='move'))first--;
  for(let i=first;i<=state.index;i++)for(const action of this.recipe.steps[i].actions){
   if(action.action!=='move')continue;const actor=this.recipe.actors.find(a=>a.id===action.actor);
   poses.set(actor.id,this.pose(actor,this.pathFor(action,actor),i<state.index?(action.stopAt??1):actionProgress(action,state.progress)));
  }return poses;
 }
 draw(){
  if(!this.recipe)return;
  if(!this.pov||this.mode!=='3d'){
   const connections=this.recipe.connections;this.recipe.connections=[];super.draw();this.recipe.connections=connections;
   if(this.towing&&this.mode==='3d'){this.towing.update();this.renderer.render(this.scene,this.camera);}return;
  }
  const state=this.atTime();this.pov.draw(state,this.time);this.overlay.replaceChildren();this.captionNodes=[];
  for(const action of state.step.actions){
   const actor=this.recipe.actors.find(a=>a.id===action.actor),model=this.models.get(action.actor);
   let point;
   if(model){point=model.root.getWorldPosition(new THREE.Vector3());point.y+=(model.fitBounds.max.y-model.fitBounds.min.y)*model.scale+.3;}
   else if(action.actor==='self')continue;
   else{const landmark=this.recipe.worldScene.markers?.[action.actor];if(landmark)point=new THREE.Vector3(landmark[0],landmark[1]??2.5,landmark[2]);}
   if(!point)continue;const [x,y,z]=this.pov.project(point);if(z<0||z>1||x<0||x>100||y<0||y>100)continue;
   const invalid=action.action==='forbidden',color=invalid?'#b62e32':action.action==='wait'?'#93620f':'#215744';
   this.overlay.append(this.label(x,y,actor.label+(action.action==='wait'?' · CHỜ':''),{fill:color,stroke:'white','stroke-width':.5,'paint-order':'stroke'}));
   this.overlay.append(svg('circle',{cx:x,cy:y+2,r:.6,fill:color}));
  }
  this.placeCaptions();this.onFrame({time:this.time,total:this.total(),index:state.index,step:state.step,playing:this.playing||false});
 }
}
