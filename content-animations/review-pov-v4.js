import * as THREE from './vendor/three/three.module.min.js';
import {PovSceneV3} from './review-pov-v3.js';
import {worldRoute} from './review-traffic.mjs';
export const POV_COCKPIT_VERSION='blue-hatchback-v1';
function box(scene,size,at,color){const m=new THREE.Mesh(new THREE.BoxGeometry(...size),new THREE.MeshStandardMaterial({color,roughness:.85}));m.position.set(...at);scene.add(m);return m;}
function strip(scene,path,inner,outer,color){
 const curve=worldRoute(path),positions=[];
 for(let i=0;i<180;i++){
  const vertices=[];
  for(const t of [i/180,(i+1)/180]){const p=curve.getPointAt(t),v=curve.getTangentAt(t),normal=new THREE.Vector3(-v.z,0,v.x);for(const offset of [inner,outer])vertices.push(p.clone().addScaledVector(normal,offset));}
  const y=outer-inner<.25?.035:.015;
  for(const k of [0,2,1,1,2,3])positions.push(vertices[k].x,y,vertices[k].z);
 }
 const g=new THREE.BufferGeometry();g.setAttribute('position',new THREE.Float32BufferAttribute(positions,3));g.computeVertexNormals();const mesh=new THREE.Mesh(g,new THREE.MeshStandardMaterial({color,roughness:.9,side:THREE.DoubleSide}));scene.add(mesh);
}
export class PovSceneV4 extends PovSceneV3 {
 constructor(canvas,host,recipe){
  super(canvas,host,{...recipe,worldScene:{...recipe.worldScene,egoModel:true,cockpitVersion:POV_COCKPIT_VERSION}});
  this.host.dataset.cockpitVersion=POV_COCKPIT_VERSION;
  if(this.config.sideJunction==='left'){
   const J=this.config.junction??-24;
   box(this.scene,[180,.08,9],[94,.02,J],'#8a9e75');box(this.scene,[2.2,.14,11],[4.8,.08,J],'#b6b7ad');box(this.scene,[8,7,14],[12,3.5,J],'#b6b5a5');
  }
  if(this.config.islandGrass){
   const polygon=this.config.island,cx=polygon.reduce((s,p)=>s+p[0],0)/polygon.length,cz=polygon.reduce((s,p)=>s+p[1],0)/polygon.length,shape=new THREE.Shape();
   polygon.forEach(([x,z],i)=>{const p=[cx+(x-cx)*.84,-(cz+(z-cz)*.84)];i?shape.lineTo(...p):shape.moveTo(...p);});shape.closePath();const g=new THREE.ExtrudeGeometry(shape,{depth:.025,bevelEnabled:false});g.rotateX(-Math.PI/2);const grass=new THREE.Mesh(g,new THREE.MeshStandardMaterial({color:'#80965b'}));grass.position.y=.185;this.scene.add(grass);
  }
  if(this.config.curvedRoad){
   // Replace the generic straight environment only for the rural bend source.
   for(const child of this.scene.children)if(child.type==='Group')child.visible=false;
   box(this.scene,[500,.1,500],[0,-.12,-60],'#8a9e75');const path=this.config.curvedRoad;
   strip(this.scene,path,-3.7,3.7,'#696e6d');strip(this.scene,path,-5.2,-3.7,'#a9ad9e');strip(this.scene,path,3.7,5.2,'#a9ad9e');
   for(const [a,b,c] of [[-.05,.05,'#e6c952'],[-3.45,-3.36,'#f2eee1'],[3.36,3.45,'#f2eee1']])strip(this.scene,path,a,b,c);
   const curve=worldRoute(path);for(let i=0;i<20;i++){const p=curve.getPointAt(i/20),side=i%2?1:-1;box(this.scene,[.22,2,.22],[p.x+side*8,1,p.z],'#6c6250');const crown=new THREE.Mesh(new THREE.IcosahedronGeometry(1.6,1),new THREE.MeshStandardMaterial({color:'#607f52'}));crown.position.set(p.x+side*8,3,p.z);this.scene.add(crown);}
  }
  if(this.config.laneChoices){
   for(const [x,dx] of [[-1.75,-1.1],[1.75,1.1]]){
    const c=worldRoute([[x,-10],[x,-12],[x+dx,-13]]),m=new THREE.Mesh(new THREE.TubeGeometry(c,24,.065,6,false),new THREE.MeshBasicMaterial({color:'#f5eee0'}));m.position.y=.08;this.scene.add(m);
   }
  }
  if(this.config.rightGreen){
   const c=document.createElement('canvas');c.width=c.height=128;const g=c.getContext('2d');g.fillStyle='#26312d';g.fillRect(0,0,128,128);g.fillStyle='#36dd66';g.font='bold 110px Arial';g.textAlign='center';g.fillText('→',64,95);
   const t=new THREE.CanvasTexture(c);t.colorSpace=THREE.SRGBColorSpace;const arrow=new THREE.Mesh(new THREE.PlaneGeometry(.45,.45),new THREE.MeshBasicMaterial({map:t}));arrow.position.set(5,2.35,-19.8);this.scene.add(arrow);
  }
 }
}
