import * as THREE from './vendor/three/three.module.min.js';
import { makeReviewHuman,PEDAL_METRES_PER_TURN } from './review-humans.js';
import { loadDetailedVehicles } from './q490-detailed-models.js?v=city-1';
import { loadFleetVehicle } from './review-detailed-fleet.js';

const material=(color,metalness=0.1)=>new THREE.MeshStandardMaterial({color,metalness,roughness:0.5});
const glass=material('#24404c',0.35);
function part(root,size,at,mat) {const mesh=new THREE.Mesh(new THREE.BoxGeometry(...size),mat);mesh.position.set(...at);mesh.castShadow=true;mesh.receiveShadow=true;root.add(mesh);return mesh;}
function sphere(root,r,at,mat) {const mesh=new THREE.Mesh(new THREE.SphereGeometry(r,16,10),mat);mesh.position.set(...at);mesh.castShadow=true;root.add(mesh);return mesh;}
function rod(root,a,b,r,mat) {const from=new THREE.Vector3(...a),to=new THREE.Vector3(...b);const mesh=new THREE.Mesh(new THREE.CylinderGeometry(r,r,from.distanceTo(to),10),mat);mesh.position.copy(from).add(to).multiplyScalar(0.5);mesh.quaternion.setFromUnitVectors(new THREE.Vector3(0,1,0),to.sub(from).normalize());mesh.castShadow=true;root.add(mesh);return mesh;}
let basePromise;
async function prototype(kind) {
  if(kind==='barrier') {
    const root=new THREE.Group(),steel=material('#e7ebdf'),red=material('#d83b32');
    // The arm runs across the road (local Z); the post and hinge sit at one end.
    for(let i=0;i<12;i++)part(root,[.15,.18,.5],[0,1.05,-2.75+i*.5],i%2?steel:red);
    part(root,[.32,1.1,.32],[0,.55,3.05],steel);
    return {root,wheelList:[],wheelbase:0,beacons:[]};
  }
  if(kind==='pedestrian') {
    const human=await makeReviewHuman('pedestrian');
    return {root:human.root,animateHuman:human.animate,wheelList:[],wheelbase:0,beacons:[],yawOffset:0};
  }
  if(['car','moto','police','tricycle'].includes(kind)) {
    if(!basePromise)basePromise=loadDetailedVehicles().catch(error=>{basePromise=null;throw error;});
    const detail=await basePromise;
    if(kind==='car'||kind==='police')return {...detail.car,wheelbase:2.28,beacons:[]};
    return {...detail.moto,wheelbase:1.45,beacons:[]};
  }
  if(kind==='bicycle') {
    return loadFleetVehicle(kind);
  }
  return loadFleetVehicle(kind);
}
export async function makeReviewVehicle(kind,color,options={}) {
  color=color||(kind==='bus'?'#96962b':null);
  const source=await prototype(kind);
  if(!source)throw new Error('Unknown review vehicle: '+kind);
  const root=kind==='pedestrian'?source.root:source.root.clone(true),before=[],after=[],map=new Map(),materials=new Map();
  source.root.traverse(node=>before.push(node));root.traverse(node=>after.push(node));before.forEach((node,i)=>map.set(node,after[i]));
  root.traverse(node=>{
    if(!node.isMesh)return;
    const clone=mat=>{if(!materials.has(mat)) {const next=mat.clone();if(color&&(mat.name==='paint'||/red.outdoor.paint|body paint/i.test(mat.name))){next.color.set(color);if(kind==='bus'){next.map=null;next.metalness=.28;next.roughness=.36;next.needsUpdate=true;}}if(kind==='police'&&mat.name==='paint')next.color.set('#e4e7e8');materials.set(mat,next);}return materials.get(mat);};
    node.material=Array.isArray(node.material)?node.material.map(clone):clone(node.material);
  });
  if(kind==='tricycle'){
    const rear=source.wheelList.find(w=>!w.front);if(rear){const wheel=map.get(rear.pivot);wheel.position.z=-.32;const second=wheel.clone(true);second.position.z=.32;root.add(second);}
  }
  const beacons=source.beacons.map(node=>map.get(node));
  let animateHuman=source.animateHuman;
  if(kind==='bicycle'||kind==='moto'||kind==='tricycle') {
    const human=await makeReviewHuman(kind==='bicycle'?'cyclist':'motorcyclist');
    root.add(human.root);animateHuman=human.animate;
  }
  const signals=[];
  const bounds=new THREE.Box3().setFromObject(root),size=bounds.getSize(new THREE.Vector3());
  if(options.signal)for(const x of [bounds.min.x+.04,bounds.max.x-.04]) {
    const lamp=sphere(root,.09,[x,size.y*.45,(options.signal==='left'?-1:1)*size.z*.51],material('#ffac13'));
    lamp.material.emissive.set('#ff8c00');signals.push(lamp);
  }
  if(options.headlights)for(const z of [-1,1]) {
    const lamp=sphere(root,.1,[bounds.max.x,size.y*.4,z*size.z*.3],material('#fff4ce'));lamp.material.emissive.set('#fff1bc');lamp.material.emissiveIntensity=4;
    const beam=new THREE.Mesh(new THREE.ConeGeometry(.65,5,24,1,true),new THREE.MeshBasicMaterial({color:'#fff3cf',transparent:true,opacity:.18,depthWrite:false,side:THREE.DoubleSide}));
    beam.rotation.z=Math.PI/2;beam.position.set(bounds.max.x+2.5,size.y*.4,z*size.z*.3);root.add(beam);
  }
  if(options.openRearDoors) {
    // The source GLB has a single closed shell. Cover only its rear door inset
    // with the cargo opening, leaving the roof, pillars and bumper intact.
    part(root,[.025,size.y*.64,size.z*.82],[bounds.min.x-.025,size.y*.5,0],material('#18222a'));
    for(const z of [-1,1]) {
      const hinge=new THREE.Group();hinge.position.set(bounds.min.x-.06,size.y*.5,z*size.z*.43);root.add(hinge);
      part(hinge,[.055,size.y*.65,size.z*.42],[0,0,-z*size.z*.21],material('#6682a7'));
      part(hinge,[.065,size.y*.22,size.z*.28],[-.01,size.y*.15,-z*size.z*.21],glass);
      rod(hinge,[-.04,-size.y*.05,-z*size.z*.34],[-.04,-size.y*.18,-z*size.z*.34],.018,material('#ccd0d4'));
      hinge.rotation.y=z*1.75;
    }
  }
  if(kind==='police')for(const sign of [-1,1])beacons.push(part(root,[0.38,0.13,0.25],[0,1.62,sign*0.35],material(sign>0?'#c42b36':'#195bd2')));
  const crankPivot=source.crankPivot?map.get(source.crankPivot):null,pedalPivots=(source.pedalPivots||[]).map(p=>map.get(p));
  return {root,fitBounds:bounds,wheelbase:source.wheelbase,wheelList:source.wheelList.map(w=>({...w,pivot:map.get(w.pivot),spin:map.get(w.spin)})),beacons,trailerPivot:source.trailerPivot?map.get(source.trailerPivot):null,yawOffset:source.yawOffset||0,
    crankPivot,pedalPivots,
    animate:state=>{animateHuman?.(state);if(crankPivot){const phase=state.distance/Math.max(state.scale,1e-6)/PEDAL_METRES_PER_TURN*Math.PI*2;crankPivot.rotation.z=-phase;for(const pedal of pedalPivots)pedal.rotation.z=phase;}for(const lamp of signals){lamp.visible=Math.sin(state.time*7)>0;lamp.material.emissiveIntensity=lamp.visible?3:0;}}};
}
export function releaseReviewVehicle(model) {
  const mats=new Set();model.root.traverse(node=>{if(node.isMesh)(Array.isArray(node.material)?node.material:[node.material]).forEach(mat=>mats.add(mat));});mats.forEach(mat=>mat.dispose());
}
