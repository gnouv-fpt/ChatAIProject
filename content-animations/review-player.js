import * as THREE from './vendor/three/three.module.min.js';
import { RoomEnvironment } from './vendor/three/RoomEnvironment.js';
import { makeReviewVehicle, releaseReviewVehicle } from './review-vehicles.js';
import { roadCurve,travelProgress } from './review-motion.mjs';
import { groundFrame,groundPoint,imagePoint,laneHeading } from './review-ground.mjs';
import { CleanBackground } from './review-clean-background.mjs';
import { driverDepthScale,foregroundMask,captionPositions } from './review-layout.mjs';

const NS='http://www.w3.org/2000/svg';
function svg(tag,attributes,text) {const node=document.createElementNS(NS,tag);for(const [key,value] of Object.entries(attributes))node.setAttribute(key,value);if(text)node.textContent=text;return node;}
const clamp=(n,a,b)=>Math.max(a,Math.min(b,n));

export class ReviewPlayer {
  constructor(host,onFrame,onState) {
    this.host=host;this.onFrame=onFrame;this.onState=onState;this.models=new Map();this.mode='photo';this.markers=[];this.guides=true;this.speed=1;this.time=0;this.token=0;this.ready=false;
    this.image=document.createElement('img');this.image.alt='Ảnh sa hình nguyên bản trong bộ câu hỏi';this.image.draggable=false;
    this.overlay=svg('svg',{viewBox:'0 0 100 100',preserveAspectRatio:'none','aria-hidden':'true'});
    this.canvas=document.createElement('canvas');this.canvas.setAttribute('aria-hidden','true');
    this.cleanBackground=new CleanBackground(host);
    host.replaceChildren(this.image,this.cleanBackground.image,this.overlay,this.canvas);
    this.resizeObserver=new ResizeObserver(()=>{if(this.renderer){const width=host.clientWidth;this.renderer.setSize(width,width*this.height/this.width,false);}this.draw();});this.resizeObserver.observe(host);
    document.addEventListener('visibilitychange',()=>{if(document.hidden)this.pause();});
  }
  async setQuestion(question,recipe,preferredMode) {
    this.pause();const token=++this.token,modeToken=this.modeToken=(this.modeToken||0)+1;this.ready=false;this.canvas.hidden=true;this.overlay.hidden=true;this.onState({ready:false});
    this.question=question;this.recipe=recipe;this.width=question.images[0].width;this.height=question.images[0].height;
    this.cleanBackground.reset(recipe.cleanBackground,this.width,this.height);
    this.canvas.style.maskImage=foregroundMask(recipe.foregroundRegions,this.width,this.height);
    this.canvas.style.webkitMaskImage=this.canvas.style.maskImage;
    this.groundFrame=groundFrame(recipe,this.width);
    this.host.style.aspectRatio=`${this.width} / ${this.height}`;this.time=0;this.curves=new Map();this.markers=[];
    for(const model of this.models.values()){model.root.removeFromParent();releaseReviewVehicle(model);}this.models.clear();
    this.image.src=question.images[0].url;
    this.mode=preferredMode||recipe.mode;
    try {
      await this.image.decode();if(token!==this.token||modeToken!==this.modeToken)return;
      await this.ensureModels(token,modeToken);if(token!==this.token||modeToken!==this.modeToken)return;
      if(this.mode==='3d')await this.cleanBackground.load();if(token!==this.token||modeToken!==this.modeToken)return;
      this.ready=true;this.applyMode();this.draw();this.onState({ready:true,mode:this.mode,background:this.cleanBackground.status});
    } catch(error) {if(token===this.token&&modeToken===this.modeToken){this.mode='photo';this.applyMode();this.draw();this.onState({ready:false,error:error.message});}}
  }
  total() {return this.recipe?.steps.reduce((sum,s)=>sum+s.duration,0)||0;}
  atTime() {
    if(!this.recipe)return null;
    let start=0;
    for(let index=0;index<this.recipe.steps.length;index++) {const step=this.recipe.steps[index];if(this.time<start+step.duration||index===this.recipe.steps.length-1)return {index,step,start,progress:clamp((this.time-start)/step.duration,0,1)};start+=step.duration;}
  }
  toGround(point) {const p=groundPoint(point,this.groundFrame,this.width,this.height);return new THREE.Vector3(p.x,0,p.z);}
  toScreen(point) {return imagePoint(point,this.groundFrame,this.width,this.height);}
  curve(path) {
    const key=JSON.stringify(path);if(this.curves.has(key))return this.curves.get(key);
    if(this.recipe.motionVersion===2){const curve=roadCurve(path,this.width,this.height,p=>this.toGround(p));this.curves.set(key,curve);return curve;}
    // Author the shape in source pixels, then map it onto the calibrated road.
    // Changing the camera must never bend a route away from its source arrow.
    const points=path.map(([x,y])=>new THREE.Vector3(x*this.width/100,y*this.height/100,0));
    const source=points.length===2?new THREE.LineCurve3(...points):new THREE.CatmullRomCurve3(points,false,'centripetal');
    const curve=new THREE.Curve();curve.getPoint=(t,target=new THREE.Vector3())=>{const p=source.getPoint(t);return target.copy(this.toGround([p.x/this.width*100,p.y/this.height*100]));};
    curve.arcLengthDivisions=420;this.curves.set(key,curve);return curve;
  }
  pathFor(action,actor) {return action.path||actor.path;}
  pose(actor,path,progress) {
    const fixedHeadingYaw=()=>{
      const heading=actor.heading||[1,-.5];
      const direction=this.toGround([50+heading[0]*100/this.width,50+heading[1]*100/this.height]).sub(this.toGround([50,50]));
      return -Math.atan2(direction.z,direction.x);
    };
    if(!path||path.length<2) {
      let heading=actor.heading||[1,-.5];if(this.recipe.perspective!=='driver'&&!actor.exactHeading)heading=laneHeading(heading,this.groundFrame);
      const direction=this.toGround([50+heading[0]*100/this.width,50+heading[1]*100/this.height]).sub(this.toGround([50,50]));
      return {point:this.toGround(actor.at),yaw:actor.path.length>1?this.pose(actor,actor.path,0).yaw:-Math.atan2(direction.z,direction.x),distance:0};
    }
    const curve=this.curve(path),u=clamp(progress,0,1),point=curve.getPointAt(u),direction=curve.getTangentAt(u);
    return {point,yaw:actor.fixedHeading?fixedHeadingYaw():-Math.atan2(direction.z,direction.x),distance:curve.getLength()*u};
  }
  actorPoses(state) {
    const poses=new Map(this.recipe.actors.map(actor=>[actor.id,this.pose(actor,actor.path,0)]));
    let first=['compliance','alternatives'].includes(this.recipe.learningMode)?state.index:0;
    if(this.recipe.learningMode==='alternatives'&&this.recipe.motionVersion===2&&!state.step.actions.length)while(first>0&&!this.recipe.steps[first].actions.some(a=>a.action==='move'))first--;
    for(let i=first;i<=state.index;i++)for(const action of this.recipe.steps[i].actions) {
      if(action.action!=='move')continue;
      const actor=this.recipe.actors.find(a=>a.id===action.actor);
      const progress=i<state.index?1:this.recipe.motionVersion===2?travelProgress(state.progress):state.progress;
      poses.set(actor.id,this.pose(actor,this.pathFor(action,actor),progress*(action.stopAt??1)));
    }
    return poses;
  }
  initRenderer() {
    if(this.renderer)return;
    this.scene=new THREE.Scene();this.camera=new THREE.OrthographicCamera(-20,20,20,-20,0.1,500);this.camera.position.set(52.8,49.4,57.6);this.camera.lookAt(0,0,0);this.camera.updateMatrixWorld(true);
    this.renderer=new THREE.WebGLRenderer({canvas:this.canvas,alpha:true,antialias:true});this.renderer.setPixelRatio(Math.min(devicePixelRatio,2));this.renderer.setClearColor(0,0);this.renderer.toneMapping=THREE.ACESFilmicToneMapping;this.renderer.toneMappingExposure=1.1;
    this.scene.add(new THREE.HemisphereLight(0xe8f4ff,0x71685b,2.8));const sun=new THREE.DirectionalLight(0xfff4de,3);sun.position.set(-15,26,10);this.scene.add(sun);
    const env=new RoomEnvironment(),pmrem=new THREE.PMREMGenerator(this.renderer);this.scene.environment=pmrem.fromScene(env,0.04).texture;this.scene.environmentIntensity=0.65;env.dispose();pmrem.dispose();
  }
  projectCamera() {
    const f=this.groundFrame,s=f.scale,det=f.xx*f.yz-f.xz*f.yx;
    const view=new THREE.Vector3(-f.xz*f.height,det,f.xx*f.height).normalize();
    this.camera.position.copy(view).multiplyScalar(100);this.camera.lookAt(0,0,0);this.camera.updateMatrixWorld(true);
    const depth=this.recipe.perspective==='driver'?.0007:.006;
    const matrix=new THREE.Matrix4().set(f.xx*s/(this.width/2),0,f.xz*s/(this.width/2),0,-f.yx*s/(this.height/2),f.height*s/(this.height/2),-f.yz*s/(this.height/2),0,-view.x*depth,-view.y*depth,-view.z*depth,0,0,0,0,1);
    this.camera.projectionMatrix.copy(matrix).multiply(this.camera.matrixWorld);this.camera.projectionMatrixInverse.copy(this.camera.projectionMatrix).invert();
    const width=this.host.clientWidth;this.renderer.setSize(width,width*this.height/this.width,false);
  }
  async ensureModels(token,modeToken=this.modeToken) {
    if(this.mode!=='3d')return;
    this.initRenderer();this.projectCamera();
    for(const actor of this.recipe.actors.filter(a=>a.kind!=='marker')) {
      if(this.models.has(actor.id))continue;
      const model=await makeReviewVehicle(actor.kind,actor.color,actor);
      if(token!==this.token||modeToken!==this.modeToken){releaseReviewVehicle(model);return;}
      const initial=this.pose(actor,actor.path,0),initialYaw=initial.yaw+(model.yawOffset||0);model.root.rotation.y=0;model.root.updateMatrixWorld(true);
      const box=model.fitBounds||new THREE.Box3().setFromObject(model.root),points=[];
      model.localBounds=box.clone();
      for(const x of [box.min.x,box.max.x])for(const y of [box.min.y,box.max.y])for(const z of [box.min.z,box.max.z]) {const p=new THREE.Vector3(x,y,z).applyAxisAngle(new THREE.Vector3(0,1,0),initialYaw).project(this.camera);points.push([(p.x+1)*this.width/2,(1-p.y)*this.height/2]);}
      model.root.rotation.y=initialYaw;
      const xs=points.map(p=>p[0]),ys=points.map(p=>p[1]);
      const left=Math.min(...xs),right=Math.max(...xs),top=Math.min(...ys),bottom=Math.max(...ys);
      model.scale=actor.width/100*this.width/(right-left);
      model.offset=new THREE.Vector3();
      if(actor.anchor==='box') {
        model.scale=Math.min(model.scale,actor.rect[3]/100*this.height/(bottom-top));
        // A different mesh may be shorter than its source box. Align its tyres
        // (or feet) to the original bottom, rather than leaving it floating.
        const y=this.recipe.motionVersion===2?(bottom-this.height/2)*model.scale/this.height*100-actor.rect[3]/2:((top+bottom)/2-this.height/2)*model.scale/this.height*100;
        const center=[50+((left+right)/2-this.width/2)*model.scale/this.width*100,50+y];
        model.offset.copy(this.toGround([50,50])).sub(this.toGround(center));
      } else model.scale=clamp(model.scale,0.18,1.3);
      model.root.scale.setScalar(model.scale);model.initialYaw=initial.yaw;this.models.set(actor.id,model);this.scene.add(model.root);
    }
  }
  applyMode() {this.host.classList.toggle('mode-3d',this.mode==='3d');this.host.classList.toggle('no-vehicles',this.models.size===0);this.overlay.hidden=this.mode==='original';this.canvas.hidden=this.mode!=='3d';this.cleanBackground.show(this.mode);}
  async setMode(mode) {
    this.pause();this.mode=mode;this.ready=false;this.onState({ready:false});
    const token=this.token,modeToken=this.modeToken=(this.modeToken||0)+1;
    try {await this.image.decode();if(token!==this.token||modeToken!==this.modeToken)return;await this.ensureModels(token,modeToken);if(token!==this.token||modeToken!==this.modeToken)return;if(mode==='3d')await this.cleanBackground.load();if(token!==this.token||modeToken!==this.modeToken)return;this.ready=true;this.applyMode();this.draw();this.onState({ready:true,mode,background:this.cleanBackground.status});}
    catch(error){if(token!==this.token||modeToken!==this.modeToken)return;this.mode='photo';this.applyMode();this.onState({ready:false,error:error.message});}
  }
  actorRect(actor) {if(actor.rect)return [...actor.rect];const h=actor.width*this.width/this.height*0.67;return [actor.at[0]-actor.width/2,actor.at[1]-h,actor.width,h+2];}
  label(x,y,text,attributes={}) {
    // Normalized image coordinates stretch SVG text unless its aspect ratio is restored.
    const fontSize=Math.max(2.4,13/(this.host.clientHeight||300)*100);
    const halfWidth=Math.min(49,text.length*fontSize*this.height/this.width*0.3+1);
    x=clamp(x,halfWidth,100-halfWidth);
    const node=svg('text',{x:0,y:0,transform:`translate(${x} ${y}) scale(${this.height/this.width} 1)`,'font-size':fontSize,'text-anchor':'middle','font-weight':700,...attributes},text);
    if(attributes.fill!=='white')this.captionNodes.push({node,x,y});
    return node;
  }
  placeCaptions() {
    const host=this.host.getBoundingClientRect();if(!host.width||!host.height)return;
    for(const {node} of this.captionNodes){const b=node.getBoundingClientRect();if(b.width>host.width-8)node.setAttribute('font-size',Number(node.getAttribute('font-size'))*(host.width-8)/b.width);}
    const original=this.captionNodes.map(({node})=>{const b=node.getBoundingClientRect();return {x:b.left-host.left,y:b.top-host.top,width:b.width,height:b.height};});
    const obstacles=(this.recipe.cleanBackground?.protectedRegions||[]).map(p=>{const xs=p.map(a=>a[0]/100*host.width),ys=p.map(a=>a[1]/100*host.height);return {x:Math.min(...xs),y:Math.min(...ys),width:Math.max(...xs)-Math.min(...xs),height:Math.max(...ys)-Math.min(...ys)};});
    for(const [x,y,w,h] of this.recipe.captionAvoidRects||[])obstacles.push({x:x/100*host.width,y:y/100*host.height,width:w/100*host.width,height:h/100*host.height});
    const placed=captionPositions(original,host.width,host.height,obstacles);
    this.captionNodes.forEach(({node,x,y},i)=>{
      const dx=(placed[i].x-original[i].x)/host.width*100,dy=(placed[i].y-original[i].y)/host.height*100;
      node.setAttribute('transform',`translate(${x+dx} ${y+dy}) scale(${this.height/this.width} 1)`);
      node.setAttribute('data-caption','true');
      if(Math.hypot(dx*host.width/100,dy*host.height/100)>10)this.overlay.insertBefore(svg('line',{x1:x,y1:y,x2:x+dx,y2:y+dy,stroke:'#476d59','stroke-width':.16}),node);
    });
  }
  draw() {
    if(!this.recipe)return;
    const state=this.atTime(),poses=this.actorPoses(state);this.captionNodes=[];
    if(this.renderer&&this.mode==='3d') {
      for(const actor of this.recipe.actors) {
        const model=this.models.get(actor.id);if(!model)continue;
        const pose=poses.get(actor.id),depthScale=driverDepthScale(actor,this.toScreen(pose.point));
        model.root.scale.setScalar(model.scale*depthScale);model.root.position.copy(pose.point).addScaledVector(model.offset,depthScale);model.root.rotation.y=pose.yaw+(model.yawOffset||0);
        const action=state.step.actions.find(a=>a.actor===actor.id&&a.action==='move');
        if(model.animate)model.animate({time:this.time,distance:pose.distance,scale:model.scale,moving:Boolean(action)});
        for(const wheel of model.wheelList){wheel.spin.rotation.z=-pose.distance/(wheel.radius*model.scale)*(wheel.direction||1);wheel.pivot.rotation.y=0;}
        if(model.trailerPivot&&actor.articulated) {
          // Recompute from route distance so scrubbing/backwards seeking is deterministic.
          const progress=action?travelProgress(state.progress):pose.distance?1:0,curve=this.curve(actor.path);
          const lag=Math.max(.01,model.wheelbase*model.scale*.48/curve.getLength());
          const a=curve.getPointAt(Math.max(0,progress-lag)),b=curve.getPointAt(progress);
          const direction=b.clone().sub(a);let trailerYaw=direction.lengthSq()>1e-8?-Math.atan2(direction.z,direction.x):model.initialYaw;
          let angle=trailerYaw-pose.yaw;model.trailerPivot.rotation.y=Math.atan2(Math.sin(angle),Math.cos(angle));
        }
        if(action) {const curve=this.curve(this.pathFor(action,actor)),progress=this.recipe.motionVersion===2?travelProgress(state.progress):state.progress,tangent=curve.getTangentAt(clamp(progress+0.035,0,1));let steer=-Math.atan2(tangent.z,tangent.x)-pose.yaw;steer=Math.atan2(Math.sin(steer),Math.cos(steer));for(const wheel of model.wheelList)if(wheel.front)wheel.pivot.rotation.y=clamp(steer,-0.6,0.6);}
        model.root.updateWorldMatrix(true,true);
        const points=[];for(const x of [model.localBounds.min.x,model.localBounds.max.x])for(const y of [model.localBounds.min.y,model.localBounds.max.y])for(const z of [model.localBounds.min.z,model.localBounds.max.z])points.push(this.toScreen(new THREE.Vector3(x,y,z).applyMatrix4(model.root.matrixWorld)));
        const xs=points.map(p=>p[0]),ys=points.map(p=>p[1]);model.screenRect=[Math.min(...xs),Math.min(...ys),Math.max(...xs)-Math.min(...xs),Math.max(...ys)-Math.min(...ys)];
      }
      this.renderer.render(this.scene,this.camera);
    }
    this.overlay.replaceChildren();
    for(const [from,to] of this.recipe.connections||[]) {
      const a=this.models.get(from),b=this.models.get(to);if(!a||!b||this.mode!=='3d')continue;
      const endpoint=(model,other)=>{
        const toward=other.root.position.clone();model.root.worldToLocal(toward);
        const b=model.localBounds,point=new THREE.Vector3(toward.x>0?b.max.x:b.min.x,Math.min(b.max.y*.25,.5),0);
        return this.toScreen(model.root.localToWorld(point));
      };
      const p=endpoint(a,b),q=endpoint(b,a);
      this.overlay.append(svg('line',{x1:p[0],y1:p[1],x2:q[0],y2:q[1],stroke:'#ffd341','stroke-width':.6,'stroke-dasharray':'1 .3'}));
    }
    for(const action of state.step.actions) {
      const actor=this.recipe.actors.find(a=>a.id===action.actor),invalid=action.action==='forbidden'||action.verdict==='invalid',color=invalid?'#dc3545':action.action==='wait'?'#e3a51f':'#16835d';
      const rect=this.mode==='3d'&&this.models.get(actor.id)?.screenRect?this.models.get(actor.id).screenRect:this.actorRect(actor);
      if(['focus','wait','forbidden'].includes(action.action)||invalid) {
        const opacity=this.playing?0.62+0.3*Math.sin(state.progress*Math.PI*4):0.85;
        this.overlay.append(svg('rect',{x:rect[0],y:rect[1],width:rect[2],height:rect[3],rx:1,fill:color,'fill-opacity':0.08,stroke:color,'stroke-width':0.65,'stroke-dasharray':'2 1',opacity}));
      }
      const path=this.pathFor(action,actor);
      const guidePath=action.guidePath??actor.guidePath??path;
      if(this.guides&&['move','forbidden'].includes(action.action)&&guidePath.length>1) {
        const curve=this.curve(guidePath),points=Array.from({length:181},(_,i)=>this.toScreen(curve.getPointAt(i/180)));
        const visible=points.slice(0,Math.max(2,Math.round((0.25+state.progress*0.75)*181)));
        this.overlay.append(svg('polyline',{points:visible.map(p=>p.join(',')).join(' '),fill:'none',stroke:invalid?color:action.verdict==='valid'?'#16835d':'#f2c84b','stroke-width':0.7,'stroke-linecap':'round','stroke-linejoin':'round','stroke-dasharray':'1.6 1'}));
        const progress=this.recipe.motionVersion===2?travelProgress(state.progress):state.progress;
        const point=this.toScreen(this.curve(path).getPointAt(progress*(action.stopAt??1)));this.overlay.append(svg('circle',{cx:point[0],cy:point[1],r:0.8,fill:color,stroke:'white','stroke-width':0.25}));
      }
      if(invalid) {const x=rect[0]+rect[2]/2,y=rect[1]+rect[3]/2;this.overlay.append(svg('path',{d:`M${x-1.5},${y-1.5}L${x+1.5},${y+1.5}M${x+1.5},${y-1.5}L${x-1.5},${y+1.5}`,stroke:color,'stroke-width':0.8}));}
      if(action.caption&&action.captionAt)this.overlay.append(this.label(...action.captionAt,action.caption,{fill:color,stroke:'white','stroke-width':.65,'paint-order':'stroke'}));
      const position=this.mode==='3d'&&actor.kind!=='marker'?this.toScreen(poses.get(actor.id).point):[actor.at[0],Math.max(4,rect[1])];
      if(position.every(v=>v>=0&&v<=100)) {
        this.overlay.append(this.label(clamp(position[0],8,92),Math.max(3,position[1]-3),actor.label+(action.action==='wait'?' · CHỜ':''),{fill:'#143e33',stroke:'white','stroke-width':0.65,'paint-order':'stroke'}));
      }
    }
    this.markers.forEach((p,i)=>{this.overlay.append(svg('circle',{cx:p.x,cy:p.y,r:1.7,fill:'#7751ba',stroke:'white','stroke-width':0.4}));this.overlay.append(this.label(p.x,p.y+0.75,String(i+1),{fill:'white'}));});
    this.placeCaptions();
    this.onFrame({time:this.time,total:this.total(),index:state.index,step:state.step,playing:this.playing||false});
  }
  play() {
    if(!this.ready||this.mode==='original')return;
    if(this.time>=this.total())this.time=0;this.playing=true;let previous=performance.now();
    const frame=now=>{if(!this.playing)return;this.time=Math.min(this.total(),this.time+Math.min((now-previous)/1000,0.1)*this.speed);previous=now;this.draw();if(this.time>=this.total()){this.pause();return;}this.raf=requestAnimationFrame(frame);};this.raf=requestAnimationFrame(frame);
  }
  pause() {this.playing=false;cancelAnimationFrame(this.raf);if(this.recipe)this.draw();}
  seek(time) {this.pause();this.time=clamp(time,0,this.total());this.draw();}
  step(delta) {const current=this.atTime();const index=clamp(current.index+delta,0,this.recipe.steps.length-1);this.seek(this.recipe.steps.slice(0,index).reduce((sum,s)=>sum+s.duration,0));}
  reset() {this.seek(0);}
  setMarkers(markers) {this.markers=markers;this.draw();}
}
