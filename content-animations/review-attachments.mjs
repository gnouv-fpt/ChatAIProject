import * as THREE from './vendor/three/three.module.min.js';
const worldPosition=b=>b.getWorldPosition(new THREE.Vector3());
function aim(bone,child,target){
 const origin=worldPosition(bone),current=worldPosition(child).sub(origin).normalize(),desired=target.clone().sub(origin).normalize();
 const rotation=new THREE.Quaternion().setFromUnitVectors(current,desired).multiply(bone.getWorldQuaternion(new THREE.Quaternion()));
 bone.quaternion.copy(bone.parent.getWorldQuaternion(new THREE.Quaternion()).invert().multiply(rotation));bone.updateWorldMatrix(false,true);
}
export function gripGate(model,target){
 const upper=model.root.getObjectByName('UpperArmR'),lower=model.root.getObjectByName('LowerArmR'),palm=model.root.getObjectByName('PalmR');
 if(!upper||!lower||!palm)throw new Error('Thiếu khớp tay của người gác đường');
 model.root.updateWorldMatrix(true,true);
 const s=worldPosition(upper),e=worldPosition(lower),h=worldPosition(palm),l1=s.distanceTo(e),l2=e.distanceTo(h),direction=target.clone().sub(s),distance=Math.min(direction.length(),l1+l2-.0001);direction.normalize();
 const along=(l1*l1-l2*l2+distance*distance)/(2*distance),height=Math.sqrt(Math.max(0,l1*l1-along*along));
 const bend=e.clone().sub(s);bend.addScaledVector(direction,-bend.dot(direction));if(bend.lengthSq()<1e-8)bend.set(0,0,1);bend.normalize();
 const elbow=s.clone().addScaledVector(direction,along).addScaledVector(bend,height);
 aim(upper,lower,elbow);aim(lower,palm,target);model.root.updateWorldMatrix(true,true);
 model.root.userData.handTargetError=worldPosition(palm).distanceTo(target);
 return model.root.userData.handTargetError;
}
