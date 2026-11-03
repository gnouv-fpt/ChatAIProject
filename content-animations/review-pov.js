import * as THREE from './vendor/three/three.module.min.js';
import {makeReviewVehicleV2} from './review-vehicles-v2.js';
import {worldPoses,worldPose} from './review-traffic.mjs';
import {mergeStatic} from './q490-detailed-models.js';
import {gripGate} from './review-attachments.mjs';

const palette=new Map();
const mat=(color,roughness=.85)=>{const key=color+roughness;if(!palette.has(key))palette.set(key,new THREE.MeshStandardMaterial({color,roughness}));return palette.get(key);};
function box(parent,size,at,color){const m=new THREE.Mesh(new THREE.BoxGeometry(...size),typeof color==='string'?mat(color):color);m.position.set(...at);m.castShadow=true;m.receiveShadow=true;parent.add(m);return m;}
function road(parent,width,length,x,z,color='#676c6d',y=.015){return box(parent,[width,.025,length],[x,y,z],color);}
function pole(parent,x,z,height=3){return box(parent,[.075,height,.075],[x,height/2,z],'#777f7c');}
function signTexture(type){
 const c=document.createElement('canvas');c.width=c.height=256;const g=c.getContext('2d');g.clearRect(0,0,256,256);g.lineWidth=17;g.strokeStyle='#c4362c';g.fillStyle='#fff9dd';
 if(type==='yield'||type==='warning'||type==='railwayWarning'){
  g.beginPath();if(type==='yield'){g.moveTo(25,30);g.lineTo(231,30);g.lineTo(128,228);}else{g.moveTo(128,24);g.lineTo(236,223);g.lineTo(20,223);}g.closePath();g.fill();g.stroke();
  if(type==='warning'){g.fillStyle='#242d29';g.fillRect(117,94,23,92);g.fillRect(86,126,85,23);}
  if(type==='railwayWarning'){g.fillStyle='#242d29';g.fillRect(73,135,110,13);g.fillRect(73,172,110,13);for(let x=81;x<180;x+=24)g.fillRect(x,121,10,80);}
 }else if(type==='stop'){
  g.fillStyle='#bf322e';g.beginPath();for(let i=0;i<8;i++){const a=(i+.5)*Math.PI/4,x=128+112*Math.cos(a),y=128+112*Math.sin(a);i?g.lineTo(x,y):g.moveTo(x,y);}g.closePath();g.fill();g.strokeStyle='white';g.lineWidth=5;g.stroke();g.fillStyle='white';g.font='bold 62px Arial';g.textAlign='center';g.fillText('STOP',128,149);
 }else if(type==='priority'){
  g.fillStyle='#f3ce47';g.strokeStyle='white';g.beginPath();g.moveTo(128,20);g.lineTo(236,128);g.lineTo(128,236);g.lineTo(20,128);g.closePath();g.fill();g.stroke();
 }else{
  if(type==='noentry')g.fillStyle='#bf322e';g.beginPath();g.arc(128,128,105,0,Math.PI*2);g.fill();g.stroke();g.fillStyle=type==='noentry'?'white':'#273431';g.font='bold 126px Arial';g.textAlign='center';g.fillText(type==='noentry'?'−':type==='noUTurn'?'↶':type==='noRight'?'↱':'!',128,173);
  if(type!=='noentry'){g.beginPath();g.moveTo(56,56);g.lineTo(200,200);g.stroke();}
 }
 const t=new THREE.CanvasTexture(c);t.colorSpace=THREE.SRGBColorSpace;return t;
}
function sign(parent,spec){
 const group=new THREE.Group();group.position.set(spec.at[0],0,spec.at[1]);group.rotation.y=spec.yaw||0;parent.add(group);pole(group,0,0,2.7);
 const face=new THREE.Mesh(new THREE.PlaneGeometry(1.1,1.1),new THREE.MeshStandardMaterial({map:signTexture(spec.type),transparent:true,side:THREE.DoubleSide,roughness:.8}));face.position.set(0,2.4,.05);group.add(face);return group;
}
function trafficLight(parent,spec){
 const group=new THREE.Group();group.position.set(...[spec.at[0],0,spec.at[1]]);parent.add(group);pole(group,0,0,3.4);box(group,[.46,1.3,.28],[0,3.2,0],'#252e2c');
 for(const [i,color] of ['#d3322c','#e5af2a','#2ba663'].entries()){
  const active=spec.state===['red','amber','green'][i],lamp=new THREE.Mesh(new THREE.CircleGeometry(.14,24),new THREE.MeshStandardMaterial({color:active?color:'#303b35',emissive:active?color:'#000000',emissiveIntensity:active?1:0}));lamp.position.set(0,3.58-i*.37,.15);group.add(lamp);
 }return group;
}
function buildRoad(scene,config){
 const J=config.junction??-24,w=config.roadWidth??7.4,night=config.night;
 box(scene,[600,.1,600],[0,-.1,-60],night?'#25332f':'#8a9e75');
 road(scene,w,600,0,-70);
 if(config.type!=='straight'&&config.type!=='narrow'&&config.type!=='railway')road(scene,400,w,0,J);
 for(const side of [-1,1]){
  if(config.type==='junction'){
   for(const [a,b] of [[-370,J-w/2],[J+w/2,230]])road(scene,2.2,b-a,side*(w/2+1.1),(a+b)/2,'#b6b7ad',.09);
  }else road(scene,2.2,600,side*(w/2+1.1),-70,'#b6b7ad',.09);
  for(let z=-240;z<192;z+=12){
   if(Math.abs(z-J)<17&&config.type==='junction')continue;
   const height=5+((Math.abs(z)*3+config.seed)%7),tone=['#b6b5a5','#c2b5a4','#9caaa1','#c0b5ae'][(Math.abs(z)+config.seed)%4|0];
   const building=box(scene,[8,height,9],[side*(w/2+8),height/2,z],tone);
   for(let y=1.5;y<height-1;y+=1.8)for(let k=-1;k<=1;k++)box(building,[.03,.9,.8],[-side*4.02,y-height/2,k*2.1],'#536967');
   const tree=new THREE.Group();tree.position.set(side*(w/2+1.4),0,z-5);scene.add(tree);box(tree,[.18,2.7,.18],[0,1.35,0],'#6c6250');
   const crown=new THREE.Mesh(new THREE.IcosahedronGeometry(1.3,1),mat('#607f52'));crown.position.y=3.2;tree.add(crown);
  }
 }
 if(config.type==='junction'){
  for(const side of [-1,1]){
   for(const [a,b] of [[-200,-w/2],[w/2,200]])road(scene,b-a,2.2,(a+b)/2,J+side*(w/2+1.1),'#b6b7ad',.09);
   for(let x=-180;x<=180;x+=12){
    if(Math.abs(x)<18)continue;
    const height=5+(Math.abs(x)+config.seed)%7,building=box(scene,[9,height,8],[x,height/2,J+side*(w/2+8)],'#b6b5a5');
    for(let y=1.5;y<height-1;y+=1.8)for(let k=-1;k<=1;k++)box(building,[.8,.9,.03],[k*2.1,y-height/2,-side*4.02],'#536967');
    const tree=new THREE.Group();tree.position.set(x-5,0,J+side*(w/2+1.4));scene.add(tree);box(tree,[.18,2.7,.18],[0,1.35,0],'#6c6250');const crown=new THREE.Mesh(new THREE.IcosahedronGeometry(1.3,1),mat('#607f52'));crown.position.y=3.2;tree.add(crown);
   }
  }
  for(let x=-190;x<200;x+=6)if(Math.abs(x)>w/2+1)road(scene,2.8,.11,x,J,'#eee8d4',.05);
 }
 for(let z=-340;z<220;z+=6){
  if(config.type==='junction'&&Math.abs(z-J)<w/2+1)continue;
  road(scene,.11,2.8,0,z,'#eee8d4',.045);
 }
 for(const x of [-w/2+.25,w/2-.25])road(scene,.11,580,x,-70,'#e6e5d8',.05);
 if(config.endAhead){box(scene,[w+5,6,8],[0,3,J-w/2-5],'#c3b8aa');}
 if(config.sameDirection)for(const x of [-1.75,1.75])for(const z of [-12,-36,-60]){
  const arrow=new THREE.Group();arrow.position.set(x,.06,z);scene.add(arrow);box(arrow,[.14,.02,1.8],[0,0,.3],'#f2eee3');
  const l=box(arrow,[.14,.02,.85],[-.22,0,-.4],'#f2eee3'),r=box(arrow,[.14,.02,.85],[.22,0,-.4],'#f2eee3');l.rotation.y=-.6;r.rotation.y=.6;
 }
 if(config.type==='junction'){
  for(const x of [-w/2,w/2])for(let k=-4;k<=4;k++)road(scene,.45,3.4,k*.65,J+x+(x>0?1.4:-1.4),'#eee9de',.05);
  road(scene,w/2-.5,.22,w/4,J+w/2+4,'#f7f0df',.05);
 }
 if(config.crossing){for(let k=-5;k<=5;k++)road(scene,.42,2.8,k*.62,config.crossing,'#f1eee1',.06);}
 if(config.type==='narrow'){
  for(const x of [-w/2,w/2])box(scene,[.3,3,12],[x,1.5,J],'#a18f80');
  box(scene,[w+.3,.35,12],[0,3.1,J],'#8d9690');
 }
 if(config.type==='railway'){
  for(const z of [J-1,J+1])road(scene,100,.09,0,z,'#aab1af',.075);
  for(let x=-35;x<35;x+=.65)road(scene,.14,3.3,x,J,'#827566',.06);
  road(scene,w,.25,0,J+6,'#fff7df',.09);
 }
 if(config.median){road(scene,.65,83,0,-58.5,'#96a47b',.17);road(scene,.65,38,0,11,'#96a47b',.17);}
 for(const s of config.signs||[])sign(scene,s);
 for(const s of config.lights||[])trafficLight(scene,s);
}
function cockpit(camera){
 const group=new THREE.Group();group.name='EgoCockpit';camera.add(group);
 box(group,[2.3,.28,.36],[0,-.67,-.85],'#27332f');
 box(group,[1.95,.05,1.2],[0,-.77,-1.7],'#73877d');
 const rim=new THREE.Mesh(new THREE.TorusGeometry(.22,.025,12,48),mat('#1e2926'));rim.position.set(-.34,-.51,-.67);group.add(rim);
 for(const angle of [0,Math.PI*2/3,Math.PI*4/3]){const spoke=box(group,[.015,.21,.02],[-.34+Math.sin(angle)*.1,-.51+Math.cos(angle)*.1,-.67],'#87948a');spoke.rotation.z=-angle;}
}
export class PovScene {
 constructor(canvas,host,recipe){
  this.host=host;this.recipe=recipe;this.config=recipe.worldScene;this.models=new Map();
  this.renderer=new THREE.WebGLRenderer({canvas,alpha:false,antialias:true});this.renderer.setPixelRatio(Math.min(devicePixelRatio,2));this.renderer.outputColorSpace=THREE.SRGBColorSpace;this.renderer.toneMapping=THREE.ACESFilmicToneMapping;
  this.renderer.shadowMap.enabled=true;this.renderer.shadowMap.type=THREE.PCFSoftShadowMap;
  this.scene=new THREE.Scene();this.scene.background=new THREE.Color(this.config.night?'#15263f':'#bdd3d9');this.scene.fog=new THREE.Fog(this.scene.background,85,210);
  this.camera=new THREE.PerspectiveCamera(58,1,.08,300);this.scene.add(this.camera);cockpit(this.camera);
  this.mirrorTarget=new THREE.WebGLRenderTarget(256,80);this.rearCamera=new THREE.PerspectiveCamera(46,3.2,.1,220);
  this.mirror=new THREE.Mesh(new THREE.PlaneGeometry(.65,.2),new THREE.MeshBasicMaterial({map:this.mirrorTarget.texture}));this.mirror.position.set(0,.37,-.9);this.camera.add(this.mirror);
  box(this.camera,[.69,.24,.025],[0,.37,-.92],'#25312d');
  this.scene.add(new THREE.HemisphereLight(0xe8f1f3,0x717865,this.config.night?1:2.7));
  const sun=new THREE.DirectionalLight(0xfff5dc,this.config.night?.5:3);sun.position.set(-15,32,12);sun.castShadow=true;sun.shadow.mapSize.set(1024,1024);sun.shadow.camera.left=-60;sun.shadow.camera.right=60;sun.shadow.camera.top=60;sun.shadow.camera.bottom=-60;sun.shadow.bias=-.0005;this.scene.add(sun);
  const environment=new THREE.Group();this.scene.add(environment);buildRoad(environment,this.config);mergeStatic(environment);
 }
 async load(){
  for(const [id,spec] of Object.entries(this.config.participants)){
   const actor=this.recipe.actors.find(a=>a.id===id);if(!actor||actor.kind==='marker')continue;
   const model=await makeReviewVehicleV2(actor.kind,actor.color,actor);model.localBounds=model.fitBounds.clone();model.scale=spec.scale??1;model.root.scale.setScalar(model.scale);model.groundOffset=-model.fitBounds.min.y*model.scale;
   model.length=(model.fitBounds.max.x-model.fitBounds.min.x)*model.scale;model.width=(model.fitBounds.max.z-model.fitBounds.min.z)*model.scale;
   this.models.set(id,model);this.scene.add(model.root);
  }
 }
 draw(state,time){
  const poses=worldPoses(this.recipe,state),ego=poses.get('self');
  this.camera.position.set(ego.point.x,1.45,ego.point.z);this.camera.rotation.set(0,ego.yaw-Math.PI/2,0);
  this.camera.aspect=this.host.clientWidth/this.host.clientHeight;this.camera.updateProjectionMatrix();this.camera.updateMatrixWorld(true);
  this.renderer.setSize(this.host.clientWidth,this.host.clientHeight,false);
  for(const [id,model] of this.models){
   const pose=poses.get(id);model.root.position.copy(pose.point);model.root.position.y=model.groundOffset;model.root.rotation.y=pose.yaw+(model.yawOffset||0);
   const moving=state.step.actions.some(a=>a.actor===id&&a.action==='move');model.animate?.({time,distance:pose.distance,scale:model.scale,moving});
   for(const wheel of model.wheelList){wheel.spin.rotation.z=-pose.distance/(wheel.radius*model.scale)*(wheel.direction||1);}
   model.root.updateWorldMatrix(true,true);
  }
  if(this.recipe.number===596){
   const gate=poses.get('sliding-gate'),guard=this.models.get('ped'),target=gate.point.clone().add(new THREE.Vector3(3.5,1.3125,.075));
   this.host.dataset.guardGripError=String(gripGate(guard,target));
  }
  this.rearCamera.position.copy(this.camera.position);this.rearCamera.rotation.set(0,this.camera.rotation.y+Math.PI,0);this.rearCamera.updateMatrixWorld(true);
  this.camera.visible=false;this.renderer.setRenderTarget(this.mirrorTarget);this.renderer.render(this.scene,this.rearCamera);this.renderer.setRenderTarget(null);this.camera.visible=true;
  this.host.dataset.cameraX=String(ego.point.x);this.host.dataset.cameraZ=String(ego.point.z);this.host.dataset.cameraYaw=String(this.camera.rotation.y);
  this.host.dataset.worldModels=String(this.models.size);this.renderer.render(this.scene,this.camera);return poses;
 }
 project(point){const p=point.clone().project(this.camera);return [50+p.x*50,50-p.y*50,p.z];}
}
