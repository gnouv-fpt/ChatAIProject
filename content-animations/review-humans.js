import * as THREE from './vendor/three/three.module.min.js';
import { GLTFLoader } from './vendor/three/GLTFLoader.js';

// Same distance drives the baked legs and the bicycle crank, including seeking.
export const PEDAL_METRES_PER_TURN=5.5;
export async function makeReviewHuman(profile) {
  const gltf=await new GLTFLoader().loadAsync(new URL(`./models/people/traffic-${profile}.glb`,import.meta.url).href);
  const root=gltf.scene;root.name=`traffic-${profile}`;root.userData.reviewHuman=profile;
  const mixer=new THREE.AnimationMixer(root),actions=new Map();
  for(const clip of gltf.animations)actions.set(clip.name,{clip,action:mixer.clipAction(clip).play()});
  const required=profile==='pedestrian'?['Idle','Walk']:[profile==='cyclist'?'Pedal':'Ride'];
  for(const name of required)if(!actions.has(name))throw new Error('Thiếu animation nhân vật: '+name);
  function animate({time=0,distance=0,scale=1,moving=false}) {
    const metres=distance/Math.max(scale,1e-6);
    if(profile==='pedestrian') {
      actions.get('Walk').action.enabled=moving;actions.get('Idle').action.enabled=!moving;
      const clip=actions.get(moving?'Walk':'Idle').clip;
      mixer.setTime(moving?metres/.95*clip.duration:time%clip.duration);
    } else mixer.setTime(profile==='cyclist'?metres/PEDAL_METRES_PER_TURN*actions.get('Pedal').clip.duration:0);
    root.updateMatrixWorld(true);
  }
  animate({});
  // The imported bind pose is a T pose. Fit against the actual initial pose.
  root.traverse(node=>{if(node.isSkinnedMesh){node.computeBoundingBox();node.computeBoundingSphere();}});
  return {root,animate};
}
