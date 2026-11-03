import * as THREE from './vendor/three/three.module.min.js';
import {ReviewPlayerV2} from './review-player-v2.js';
import {PovSceneV3} from './review-pov-v3.js';

const NS='http://www.w3.org/2000/svg';
export class ReviewPlayerV3 extends ReviewPlayerV2 {
 async ensureModels(token,modeToken=this.modeToken){
  if(this.mode!=='3d')return;
  if(this.recipe.worldScene){
   if(this.pov)return;
   this.pov=new PovSceneV3(this.canvas,this.host,this.recipe);await this.pov.load();
   this.renderer=this.pov.renderer;this.scene=this.pov.scene;this.camera=this.pov.camera;this.models=this.pov.models;return;
  }
  await super.ensureModels(token,modeToken);
  // An image bounding-box centre is above the tyre contact plane. Moving its
  // offset along the route pushed vehicles into the next lane at every turn.
  // V3 routes are measured contact centres, so keep model origins on them.
  if(!this.recipe.preserveBoxOffset)for(const model of this.models.values())model.offset.set(0,0,0);
 }
 draw(){
  super.draw();if(!this.recipe||this.mode!=='3d')return;
  if(this.pov){
   for(const guide of this.recipe.worldScene.guides||[]){
    const at=guide.labelAt||guide.path[Math.min(2,guide.path.length-1)],p=new THREE.Vector3(at[0],.25,at[1]),[x,y,z]=this.pov.project(p);
    if(z>=0&&z<=1&&x>2&&x<98&&y>4&&y<96)this.overlay.append(this.label(x,y,guide.label,{fill:'#b7242e',stroke:'white','stroke-width':.5,'paint-order':'stroke'}));
   }
   this.placeCaptions();return;
  }
  for(const guide of this.recipe.sourceGuides||[]){
   const curve=this.curve(guide.path),points=Array.from({length:241},(_,i)=>this.toScreen(curve.getPointAt(i/240)));
   const line=document.createElementNS(NS,'polyline');line.setAttribute('points',points.map(p=>p.join(',')).join(' '));line.setAttribute('fill','none');line.setAttribute('stroke','#df252c');line.setAttribute('stroke-width','.45');line.setAttribute('stroke-linecap','round');line.setAttribute('stroke-linejoin','round');this.overlay.prepend(line);
  }
 }
}
