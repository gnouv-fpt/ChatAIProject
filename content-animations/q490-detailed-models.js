import * as THREE from './vendor/three/three.module.min.js';
import { GLTFLoader } from './vendor/three/GLTFLoader.js';
import { mergeGeometries } from './vendor/three/BufferGeometryUtils.js';

export function finishMaterials(scene, car) {
  const visited=new Set();
  scene.traverse(node=>{
    if(!node.isMesh)return;
    node.castShadow=true;node.receiveShadow=true;
    for(const mat of Array.isArray(node.material)?node.material:[node.material]) {
      if(visited.has(mat))continue;visited.add(mat);
      if(car&&mat.name==='paint') {
        mat.color.set('#b31524');mat.metalness=0.4;mat.roughness=0.27;mat.clearcoat=0.7;
      }
      // Transmission would refract an empty WebGL background, since the road is an SVG layer.
      if(mat.transmission>0) {
        mat.transmission=0;
        if(/glass|glazing/i.test(mat.name)) {
          mat.map=null;mat.color.set('#233843');mat.metalness=0.25;mat.roughness=0.13;
        }
        mat.needsUpdate=true;
      }
    }
  });
}

function rigWheel(scene, meshes, center, front, radius, direction=1) {
  if(meshes.length===0)throw new Error('Vehicle wheel parts missing');
  const pivot=new THREE.Group(),spin=new THREE.Group();
  pivot.userData.wheelRig=true;
  pivot.position.set(...center);pivot.add(spin);scene.add(pivot);
  scene.updateMatrixWorld(true);
  meshes.forEach(mesh=>spin.attach(mesh));
  return {pivot,spin,front,radius,direction};
}

// The source bike has hundreds of separate fasteners. Merge only static parts sharing
// a material, then merge each wheel independently so steering and rolling remain possible.
export function mergeStatic(root) {
  root.updateWorldMatrix(true,true);
  const inverse=root.matrixWorld.clone().invert(),buckets=new Map();
  function collect(node) {
    if(node!==root&&node.userData.wheelRig)return;
    if(node.isMesh&&!Array.isArray(node.material)) {
      const geo=node.geometry.clone().applyMatrix4(new THREE.Matrix4().multiplyMatrices(inverse,node.matrixWorld));
      const key=node.material.uuid+'/'+Object.keys(geo.attributes).sort().join(',')+'/'+Boolean(geo.index);
      const bucket=buckets.get(key)||{material:node.material,geometries:[],nodes:[]};
      bucket.geometries.push(geo);bucket.nodes.push(node);buckets.set(key,bucket);
    }
    [...node.children].forEach(collect);
  }
  collect(root);
  for(const bucket of buckets.values()) {
    const geometry=mergeGeometries(bucket.geometries,false);
    if(!geometry)throw new Error('Vehicle geometry merge failed');
    bucket.nodes.forEach(node=>node.removeFromParent());
    bucket.geometries.forEach(geo=>geo.dispose());
    const mesh=new THREE.Mesh(geometry,bucket.material);
    mesh.castShadow=true;mesh.receiveShadow=true;root.add(mesh);
  }
}

function compactCityBody(scene) {
  scene.updateMatrixWorld(true);
  // Preserve a rigid 0.84 m region around each wheel so shortening the shell
  // does not turn the circular tyres and wheel arches into ellipses.
  const before=[-2.15,-1.6521166,-0.8121166,0.9305234,1.7705234,2.15];
  const after=[-1.79,-1.56,-0.72,0.72,1.56,1.79];
  function shorten(x) {
    let index=0;
    while(index<before.length-2&&x>before[index+1])index++;
    return THREE.MathUtils.lerp(after[index],after[index+1],(x-before[index])/(before[index+1]-before[index]));
  }
  scene.traverse(node=>{
    if(!node.isMesh)return;
    const geometry=node.geometry.clone().applyMatrix4(node.matrixWorld);
    const positions=geometry.attributes.position;
    for(let i=0;i<positions.count;i++) {
      positions.setXYZ(i,shorten(positions.getX(i)),positions.getY(i),positions.getZ(i)*0.93);
    }
    geometry.computeVertexNormals();
    geometry.applyMatrix4(node.matrixWorld.clone().invert());
    node.geometry=geometry;
  });
}

function prepareCar(scene) {
  compactCityBody(scene);
  finishMaterials(scene,true);
  const rolling=[];
  scene.traverse(node=>{if(node.isMesh&&/reused.*(Alloy_five_spoke_rim|Center_cap|Lug_|Sculpted_tyre|Valve_stem)/i.test(node.name))rolling.push(node);});
  scene.updateMatrixWorld(true);
  const wheelList=[];
  for(const x of [-1.14,1.14])for(const side of [-1,1]) {
    const candidates=rolling.filter(mesh=>{
      const center=new THREE.Box3().setFromObject(mesh).getCenter(new THREE.Vector3());
      return Math.abs(center.x-x)<0.4&&Math.sign(center.z)===side;
    });
    wheelList.push(rigWheel(scene,candidates,[x,0.319,side*0.72075],x<0,0.312,-1));
  }
  wheelList.forEach(wheel=>mergeStatic(wheel.spin));mergeStatic(scene);
  const root=new THREE.Group();
  scene.rotation.y=Math.PI;scene.position.set(0,-0.006914,0);root.add(scene);
  return {root,wheelList};
}

function prepareMotorcycle(scene) {
  finishMaterials(scene,false);
  const wheelList=[];
  for(const front of [false,true]) {
    const prefix=front?'Front':'Rear',parts=[];
    scene.traverse(node=>{
      if(node.isMesh&&node.name.startsWith(prefix)&&/rounded.tyre|sculpted.alloy.spoke|turned.rim|finite.brake.rotor|rotor.fixing/.test(node.name))parts.push(node);
    });
    wheelList.push(rigWheel(scene,parts,[front?0.7421067:-0.7078933,front?0.3:0.322,0],front,front?0.3:0.322));
  }
  wheelList.forEach(wheel=>mergeStatic(wheel.spin));mergeStatic(scene);
  const root=new THREE.Group();scene.position.x=-0.0171067;root.add(scene);
  return {root,wheelList};
}

export async function loadDetailedVehicles() {
  const loader=new GLTFLoader();
  const [car,bike]=await Promise.all([
    loader.loadAsync(new URL('./models/hatchback.glb',import.meta.url).href),
    loader.loadAsync(new URL('./models/sport-motorcycle.glb',import.meta.url).href)
  ]);
  return {car:prepareCar(car.scene),moto:prepareMotorcycle(bike.scene)};
}
