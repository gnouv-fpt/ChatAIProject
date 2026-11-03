import * as THREE from './vendor/three/three.module.min.js';
import { GLTFLoader } from './vendor/three/GLTFLoader.js';
import { finishMaterials,mergeStatic } from './q490-detailed-models.js';

const definitions={
  truck:['box-truck',Math.PI],bus:['city-bus',Math.PI],van:['delivery-van',Math.PI],
  ambulance:['ambulance',0],fire:['fire-engine',0],army:['military-truck',Math.PI/2],
  container:['semi-trailer',Math.PI/2],bicycle:['city-bicycle',Math.PI/2],train:['locomotive',Math.PI/2]
};
export const detailedKinds=Object.keys(definitions);
export function isRollingTyreName(name) {
  return /rounded.tyre.carcass|commercial.tire.formed.sidewalls|sculpted.tyre|profiled.closed.tire.casing|wheel.tire|^(Front|Rear).tire$/i.test(name);
}
const pending=new Map();
export function loadFleetVehicle(kind) {
  if(!definitions[kind])throw new Error('Missing detailed vehicle asset: '+kind);
  if(!pending.has(kind))pending.set(kind,load(kind).catch(error=>{pending.delete(kind);throw error;}));
  return pending.get(kind);
}
async function load(kind) {
  const [file,yaw]=definitions[kind],gltf=await new GLTFLoader().loadAsync(new URL(`./models/${file}.glb`,import.meta.url).href);
  const source=gltf.scene;source.updateMatrixWorld(true);
  const rotation=new THREE.Matrix4().makeRotationY(yaw),root=new THREE.Group();
  source.traverse(node=>{
    if(!node.isMesh)return;
    if(kind==='train'&&/sleepers|ballast|steel.rails|rail.fastener/i.test(node.name))return;
    // Bake source transforms once. All vehicles then face +X, stand on Y=0,
    // and use Z as the axle direction; clones share this immutable geometry.
    const geometry=node.geometry.clone().applyMatrix4(new THREE.Matrix4().multiplyMatrices(rotation,node.matrixWorld));
    const mesh=new THREE.Mesh(geometry,node.material);mesh.name=node.name;root.add(mesh);
  });
  const bounds=new THREE.Box3().setFromObject(root),offset=new THREE.Vector3(-(bounds.min.x+bounds.max.x)/2,-bounds.min.y,-(bounds.min.z+bounds.max.z)/2);
  root.traverse(node=>{if(node.isMesh)node.geometry.translate(offset.x,offset.y,offset.z);});
  finishMaterials(root,false);
  const centres=[];
  root.traverse(node=>{
    if(!node.isMesh||!isRollingTyreName(node.name))return;
    const box=new THREE.Box3().setFromObject(node),center=box.getCenter(new THREE.Vector3()),size=box.getSize(new THREE.Vector3()),radius=size.y/2;
    if(center.y>radius*1.7)return; // A mounted spare is not a rolling wheel.
    if(centres.some(w=>w.center.distanceTo(center)<.07))return;
    centres.push({center,radius});
  });
  const wheelList=[],frontX=Math.max(...centres.map(w=>w.center.x));
  if(kind!=='train'&&centres.length<2)throw new Error('Không tìm thấy cụm bánh trong GLB '+file);
  for(const {center,radius} of centres) {
    const parts=[];
    root.traverse(node=>{
      if(!node.isMesh||!/wheel|tyre|tire|rim|lug|brake|cassette|spoke|valve/i.test(node.name)||/arch|house|fifth|steering|frame/i.test(node.name))return;
      const box=new THREE.Box3().setFromObject(node),at=box.getCenter(new THREE.Vector3()),size=box.getSize(new THREE.Vector3());
      if(Math.abs(at.x-center.x)<radius*1.15&&Math.abs(at.y-center.y)<radius*1.15&&Math.abs(at.z-center.z)<.3&&size.x<radius*2.6&&size.y<radius*2.6)parts.push(node);
    });
    if(!parts.length)continue;
    const pivot=new THREE.Group(),spin=new THREE.Group();pivot.userData.wheelRig=true;pivot.position.copy(center);pivot.add(spin);root.add(pivot);root.updateMatrixWorld(true);parts.forEach(part=>spin.attach(part));
    mergeStatic(spin);wheelList.push({pivot,spin,radius,front:Math.abs(center.x-frontX)<.2,direction:1});
  }
  let trailerPivot=null;
  if(kind==='container') {
    const hitch=root.children.find(n=>/Fifth.wheel/i.test(n.name));
    const point=hitch?new THREE.Box3().setFromObject(hitch).getCenter(new THREE.Vector3()):new THREE.Vector3(2,1,0);
    trailerPivot=new THREE.Group();trailerPivot.name='articulated-trailer';trailerPivot.position.copy(point);trailerPivot.userData.wheelRig=true;
    const parts=root.children.filter(n=>n.isMesh&&/trailer|rear.door|door.lock|landing|rear.lamp|rear.underrun/i.test(n.name));
    root.add(trailerPivot);root.updateMatrixWorld(true);parts.forEach(p=>trailerPivot.attach(p));
    for(const wheel of wheelList)if(wheel.pivot.position.x<point.x-2)trailerPivot.attach(wheel.pivot);
    mergeStatic(trailerPivot);
  }
  let crankPivot=null;const pedalPivots=[];
  if(kind==='bicycle') {
    crankPivot=new THREE.Group();crankPivot.name='bicycle-crank';crankPivot.userData.wheelRig=true;crankPivot.position.set(-.08,.29,0);
    const cranks=root.children.filter(n=>n.isMesh&&/Crank.arm|48.tooth.chainring/i.test(n.name));
    const pedals=root.children.filter(n=>n.isMesh&&/^Pedal(?:[_.\d]|$)/i.test(n.name));
    root.add(crankPivot);root.updateMatrixWorld(true);cranks.forEach(p=>crankPivot.attach(p));
    for(const mesh of pedals) {
      const pivot=new THREE.Group();pivot.userData.wheelRig=true;pivot.position.copy(new THREE.Box3().setFromObject(mesh).getCenter(new THREE.Vector3()));
      root.add(pivot);root.updateMatrixWorld(true);pivot.attach(mesh);crankPivot.attach(pivot);mergeStatic(pivot);pedalPivots.push(pivot);
    }
    if(pedalPivots.length!==2)throw new Error('Không tìm thấy hai bàn đạp xe đạp.');
    mergeStatic(crankPivot);
  }
  mergeStatic(root);
  root.userData.asset=file;root.userData.detailed=true;
  return {root,wheelList,trailerPivot,crankPivot,pedalPivots,wheelbase:centres.length?Math.max(...centres.map(w=>w.center.x))-Math.min(...centres.map(w=>w.center.x)):0,beacons:[],asset:file};
}
