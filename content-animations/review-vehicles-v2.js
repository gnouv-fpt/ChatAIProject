import * as THREE from './vendor/three/three.module.min.js';
import {makeReviewVehicle} from './review-vehicles.js';

// Bounding-box corners include mirrors and riders, rather than body surfaces.
export function bodyMount(root,front,side,height) {
  root.updateWorldMatrix(true,true);
  const bounds=new THREE.Box3().setFromObject(root),size=bounds.getSize(new THREE.Vector3()),meshes=[];
  root.traverse(n=>{if(n.isMesh&&!n.userData.attachment)meshes.push(n);});
  const x=front?bounds.max.x+1:bounds.min.x-1,z=side*size.z*.28;
  for(const dy of [0,.06,-.06,.15,-.15,.3,-.3]) {
    const ray=new THREE.Raycaster(new THREE.Vector3(x,bounds.min.y+height+dy,z),new THREE.Vector3(front?-1:1,0,0));
    const hit=ray.intersectObjects(meshes,false)[0];
    if(hit)return hit.point.add(new THREE.Vector3(front?.012:-.012,0,0));
  }
  throw new Error('Không tìm thấy bề mặt gắn đèn/móc xe');
}
export async function makeReviewVehicleV2(kind,color,options={}) {
  const model=await makeReviewVehicle(kind,color,{...options,signal:null,headlights:false});
  const lamps=[],rider=['moto','tricycle'].includes(kind),large=['truck','bus','container','van','fire','army'].includes(kind);
  if(options.signal)for(const front of [false,true]) {
    const at=bodyMount(model.root,front,options.signal==='left'?-1:1,rider?(front?.9:.68):large?.86:.58);
    const lamp=new THREE.Mesh(new THREE.BoxGeometry(.032,.085,rider?.085:.13),new THREE.MeshStandardMaterial({color:'#ffa70b',emissive:'#ff9c00',emissiveIntensity:0}));
    lamp.name=front?'MountedFrontIndicator':'MountedRearIndicator';lamp.userData.attachment=true;lamp.userData.front=front;lamp.userData.mount=at.toArray();lamp.position.copy(at);model.root.add(lamp);lamps.push(lamp);
  }
  if(options.headlights)for(const side of [-1,1]) {
    const at=bodyMount(model.root,true,side,.62);
    const lamp=new THREE.Mesh(new THREE.SphereGeometry(.09,12,8),new THREE.MeshStandardMaterial({color:'#fff8db',emissive:'#fff2ba',emissiveIntensity:5}));
    lamp.name='MountedHeadlight';lamp.userData.attachment=true;lamp.position.copy(at);model.root.add(lamp);
    const beam=new THREE.Mesh(new THREE.ConeGeometry(.8,8,24,1,true),new THREE.MeshBasicMaterial({color:'#fff6d1',transparent:true,opacity:.12,depthWrite:false,side:THREE.DoubleSide}));
    beam.name='HeadlightBeam';beam.userData.attachment=true;beam.rotation.z=Math.PI/2;beam.position.copy(at).add(new THREE.Vector3(4,0,0));model.root.add(beam);
  }
  const animate=model.animate;model.indicators=lamps;
  model.animate=state=>{animate?.(state);for(const lamp of lamps){const on=state.time%.9<.45;lamp.material.emissiveIntensity=on?4:0;lamp.material.color.set(on?'#ffb120':'#865912');}};
  return model;
}
export class TowConnections {
  constructor(scene,models,connections) {
    this.models=models;this.entries=connections.map(([from,to])=>{
      const mesh=new THREE.Mesh(new THREE.CylinderGeometry(.045,.045,1,10),new THREE.MeshStandardMaterial({color:'#e8b73d',roughness:.8}));
      mesh.name=`TowCable-${from}-${to}`;mesh.frustumCulled=false;scene.add(mesh);return {from,to,mesh};
    });
  }
  update() {
    for(const {from,to,mesh} of this.entries){
      const a=this.models.get(from),b=this.models.get(to);if(!a||!b)continue;
      const endpoint=(m,other)=>{
        const target=m.root.worldToLocal(other.root.getWorldPosition(new THREE.Vector3())),bounds=m.localBounds||m.fitBounds;
        return m.root.localToWorld(new THREE.Vector3(target.x>0?bounds.max.x:bounds.min.x,bounds.min.y+.38,0));
      };
      a.root.updateWorldMatrix(true,true);b.root.updateWorldMatrix(true,true);
      const p=endpoint(a,b),q=endpoint(b,a),delta=q.clone().sub(p);
      mesh.position.copy(p).add(q).multiplyScalar(.5);mesh.scale.set(1,delta.length(),1);mesh.quaternion.setFromUnitVectors(new THREE.Vector3(0,1,0),delta.normalize());
      mesh.userData.endpoints=[p.toArray(),q.toArray()];
    }
  }
}
