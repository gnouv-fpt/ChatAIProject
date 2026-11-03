import * as THREE from './vendor/three/three.module.min.js';
import {PovScene} from './review-pov.js';
import {makeReviewVehicleV2} from './review-vehicles-v2.js';
import {worldRoute} from './review-traffic.mjs';

function sourceTexture(image,spec){
 const c=document.createElement('canvas');c.width=c.height=256;const g=c.getContext('2d');g.beginPath();
 if(spec.shape==='triangle-down'){g.moveTo(0,0);g.lineTo(256,0);g.lineTo(128,256);}
 else if(spec.shape==='triangle-up'){g.moveTo(128,0);g.lineTo(256,256);g.lineTo(0,256);}
 else if(spec.shape==='diamond'){g.moveTo(128,0);g.lineTo(256,128);g.lineTo(128,256);g.lineTo(0,128);}
 else if(spec.shape==='circle')g.arc(128,128,128,0,Math.PI*2);
 else g.rect(0,0,256,256);
 g.closePath();g.clip();const [x,y,w,h]=spec.crop;
 g.drawImage(image,x/100*image.width,y/100*image.height,w/100*image.width,h/100*image.height,0,0,256,256);
 const texture=new THREE.CanvasTexture(c);texture.colorSpace=THREE.SRGBColorSpace;return texture;
}
export class PovSceneV3 extends PovScene {
 constructor(canvas,host,recipe){
  // Source sign faces replace the generic v2 glyphs only in changed scenes.
  super(canvas,host,{...recipe,worldScene:{...recipe.worldScene,signs:recipe.worldScene.sourceSigns?[]:recipe.worldScene.signs}});
  this.recipe=recipe;this.config=recipe.worldScene;
  for(const guide of this.config.guides||[]){
   const curve=worldRoute(guide.path),geometry=new THREE.TubeGeometry(curve,140,.045,6,false);
   geometry.translate(0,.095,0);const mesh=new THREE.Mesh(geometry,new THREE.MeshBasicMaterial({color:'#d52b32'}));mesh.name='SourceDirection-'+guide.label;this.scene.add(mesh);
   const arrow=new THREE.Mesh(new THREE.ConeGeometry(.17,.6,12),mesh.material);arrow.position.copy(curve.getPointAt(1));arrow.position.y=.11;arrow.quaternion.setFromUnitVectors(new THREE.Vector3(0,1,0),curve.getTangentAt(1));this.scene.add(arrow);
  }
  if(this.config.island){
   const shape=new THREE.Shape();this.config.island.forEach(([x,z],i)=>i?shape.lineTo(x,-z):shape.moveTo(x,-z));shape.closePath();
   const geometry=new THREE.ExtrudeGeometry(shape,{depth:.18,bevelEnabled:false});geometry.rotateX(-Math.PI/2);
   const island=new THREE.Mesh(geometry,new THREE.MeshStandardMaterial({color:'#b9bfaf'}));island.name='TrafficIsland';this.scene.add(island);
  }
 }
 async load(){
  await super.load();
  if(this.config.sourceSigns?.length){
   const source=new Image();source.src=new URL(`./bank-review/${this.recipe.number}/image-1.jpeg`,import.meta.url).href;await source.decode();
   for(const spec of this.config.sourceSigns){
    const group=new THREE.Group();group.position.set(spec.at[0],0,spec.at[1]);group.name='SourceSign';
    const size=spec.size??1.15,height=spec.height??2.4;
    if(spec.pole!==false){const pole=new THREE.Mesh(new THREE.CylinderGeometry(.035,.035,2.7,8),new THREE.MeshStandardMaterial({color:'#d8d8cd'}));pole.position.y=1.35;group.add(pole);}
    const face=new THREE.Mesh(new THREE.PlaneGeometry(size,size),new THREE.MeshStandardMaterial({map:sourceTexture(source,spec),transparent:true,side:THREE.DoubleSide,roughness:.8}));face.position.set(0,height,.05);group.add(face);this.scene.add(group);
   }
  }
  if(this.config.egoModel){
   this.egoModel=await makeReviewVehicleV2('car','#526a8d');this.scene.add(this.egoModel.root);this.renderer.localClippingEnabled=true;
   this.egoModel.root.traverse(n=>{if(n.isMesh){for(const m of Array.isArray(n.material)?n.material:[n.material])m.clippingPlanes=[new THREE.Plane(new THREE.Vector3(0,-1,0),1.04)];}});
   const cockpit=this.camera.getObjectByName('EgoCockpit');if(cockpit)cockpit.children[1].visible=false;
  }
 }
 draw(state,time){
  if(this.egoModel)this.egoModel.root.visible=false;
  const poses=super.draw(state,time);
  if(this.egoModel){
   const ego=poses.get('self');this.egoModel.root.position.copy(ego.point);this.egoModel.root.rotation.y=ego.yaw;this.egoModel.root.visible=true;this.egoModel.root.updateMatrixWorld(true);this.host.dataset.egoModel='car';this.renderer.render(this.scene,this.camera);
  }
  return poses;
 }
}
