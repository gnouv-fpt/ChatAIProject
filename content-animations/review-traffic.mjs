import * as THREE from './vendor/three/three.module.min.js';
import {roadCurve,travelProgress} from './review-motion.mjs';
export function actionProgress(action,progress) {
  const from=action.startAt??0,to=action.endAt??1;
  return travelProgress(THREE.MathUtils.clamp((progress-from)/(to-from),0,1))*(action.stopAt??1);
}
export function worldRoute(path) {
  return roadCurve(path,100,100,([x,z])=>new THREE.Vector3(x,0,z));
}
export function worldPose(path,progress,heading) {
  if(path.length<2)return {point:new THREE.Vector3(path[0][0],0,path[0][1]),yaw:heading??Math.PI/2,distance:0};
  const curve=worldRoute(path),u=THREE.MathUtils.clamp(progress,0,1),direction=curve.getTangentAt(u);
  return {point:curve.getPointAt(u),yaw:heading??-Math.atan2(direction.z,direction.x),distance:curve.getLength()*u};
}
export function worldPoses(recipe,state) {
  const config=recipe.worldScene,poses=new Map();
  for(const [id,a] of Object.entries(config.participants))poses.set(id,worldPose(a.route||[a.at],0,a.heading));
  poses.set('self',worldPose(config.egoRoute,0));
  let first=recipe.learningMode==='alternatives'?state.index:0;
  if(first&&!state.step.actions.length)while(first>0&&!recipe.steps[first].actions.some(a=>a.action==='move'))first--;
  for(let i=first;i<=state.index;i++)for(const action of recipe.steps[i].actions){
    if(action.action!=='move')continue;
    const spec=action.actor==='self'?{route:config.egoRoute}:config.participants[action.actor];if(!spec)continue;
    const path=action.worldPath||spec.route;if(!path?.length)continue;
    poses.set(action.actor,worldPose(path,i<state.index?(action.stopAt??1):actionProgress(action,state.progress),spec.heading));
  }
  return poses;
}
export function footprintsIntersect(a,b,padding=0) {
  return [...a.axes,...b.axes].every(axis=>{
    const distance=Math.abs(b.center.clone().sub(a.center).dot(axis));
    const radius=f=>f.half[0]*Math.abs(f.axes[0].dot(axis))+f.half[1]*Math.abs(f.axes[1].dot(axis));
    return distance<radius(a)+radius(b)+padding;
  });
}
export function footprint(point,yaw,length,width) {
  return {center:new THREE.Vector2(point.x,point.z),half:[length/2,width/2],axes:[new THREE.Vector2(Math.cos(yaw),-Math.sin(yaw)),new THREE.Vector2(Math.sin(yaw),Math.cos(yaw))]};
}
