import * as THREE from './vendor/three/three.module.min.js';
import {ReviewPlayerV3} from './review-player-v3.js';
import {PovSceneV4} from './review-pov-v4.js';
export class ReviewPlayerV4 extends ReviewPlayerV3 {
 placeCaptions(){
  // V3 adds guide labels after V2 has already arranged actor labels. Reset to
  // their authored anchors before a repeated layout, so it is idempotent.
  for(const {node,x,y} of this.captionNodes||[])node.setAttribute('transform',`translate(${x} ${y}) scale(${this.height/this.width} 1)`);
  this.overlay.querySelectorAll('line[stroke="#476d59"]').forEach(n=>n.remove());
  super.placeCaptions();
 }
 async ensureModels(token,modeToken=this.modeToken){
  if(this.mode!=='3d')return;
  if(this.recipe.worldScene){
   if(this.pov)return;
   this.pov=new PovSceneV4(this.canvas,this.host,this.recipe);await this.pov.load();
   this.renderer=this.pov.renderer;this.scene=this.pov.scene;this.camera=this.pov.camera;this.models=this.pov.models;return;
  }
  await super.ensureModels(token,modeToken);
 }
 pose(actor,path,progress){
  const pose=super.pose(actor,path,progress),model=this.models?.get(actor.id);
  // The source trace leaves the front of a vehicle. Follow it at that axle,
  // keeping the centre and rear of a long bus behind the trace on the corner.
  if(actor.routeAnchor==='front-axle'&&model){
   const axle=(model.localBounds.max.x-.5)*model.scale;
   pose.point.add(new THREE.Vector3(-Math.cos(pose.yaw)*axle,0,Math.sin(pose.yaw)*axle));
  }
  return pose;
 }
}
