import * as THREE from './vendor/three/three.module.min.js';
import { OrbitControls } from './vendor/three/OrbitControls.js';
import { RoomEnvironment } from './vendor/three/RoomEnvironment.js';
import { loadDetailedVehicles } from './q490-detailed-models.js?v=city-1';

const $=id=>document.getElementById(id);
let renderer,controls,vehicles,active='car';
const scene=new THREE.Scene();scene.background=new THREE.Color('#eef2ee');
const camera=new THREE.PerspectiveCamera(35,1,0.01,100);
scene.add(new THREE.HemisphereLight(0xffffff,0x777e73,2));
const light=new THREE.DirectionalLight(0xfff4df,3);light.position.set(4,8,5);scene.add(light);
light.castShadow=true;light.shadow.mapSize.set(1024,1024);Object.assign(light.shadow.camera,{left:-6,right:6,top:6,bottom:-6,near:1,far:30});light.shadow.normalBias=0.02;
const floor=new THREE.Mesh(new THREE.PlaneGeometry(200,200),new THREE.MeshStandardMaterial({color:'#e6ece5',roughness:1}));
floor.rotation.x=-Math.PI/2;floor.position.y=-0.015;floor.receiveShadow=true;scene.add(floor);
function frame() {if(renderer){controls.update();renderer.render(scene,camera);}requestAnimationFrame(frame);}
function select(id) {
  if(!vehicles)return;active=id;
  Object.entries(vehicles).forEach(([name,model])=>model.root.visible=name===id);
  const bounds=new THREE.Box3().setFromObject(vehicles[id].root),size=bounds.getSize(new THREE.Vector3()),center=bounds.getCenter(new THREE.Vector3());
  const span=Math.max(size.x,size.y,size.z);
  controls.target.copy(center);camera.position.copy(center).add(new THREE.Vector3(span*1.1,span*0.7,span*1.15));
  camera.lookAt(center);controls.minDistance=span*0.55;controls.maxDistance=span*4;controls.update();
  $('car').setAttribute('aria-pressed',String(id==='car'));$('moto').setAttribute('aria-pressed',String(id==='moto'));
  $('title').textContent=id==='car'?'Xe đô thị thân ngắn':'Mô tô thể thao';
  $('caption').textContent=id==='car'?'Thân ngắn, đuôi gọn, cabin cao — dáng xe đô thị 5 cửa.':'Dàn áo đỏ, phanh đĩa, bánh hợp kim, máy và hệ thống xả.';
}
$('car').onclick=()=>select('car');$('moto').onclick=()=>select('moto');$('reset').onclick=()=>select(active);
$('spin').onclick=()=>{controls.autoRotate=!controls.autoRotate;$('spin').textContent=controls.autoRotate?'Dừng xoay':'Tự xoay';};
document.addEventListener('visibilitychange',()=>{if(document.hidden&&controls){controls.autoRotate=false;$('spin').textContent='Tự xoay';}});
try {
  renderer=new THREE.WebGLRenderer({canvas:$('viewer'),antialias:true});renderer.setPixelRatio(Math.min(devicePixelRatio,2));
  renderer.shadowMap.enabled=true;renderer.shadowMap.type=THREE.PCFSoftShadowMap;
  renderer.toneMapping=THREE.ACESFilmicToneMapping;renderer.toneMappingExposure=1.1;
  controls=new OrbitControls(camera,renderer.domElement);controls.enableDamping=true;controls.enablePan=false;controls.autoRotateSpeed=1.5;
  const env=new RoomEnvironment(),pmrem=new THREE.PMREMGenerator(renderer);
  scene.environment=pmrem.fromScene(env,0.04).texture;scene.environmentIntensity=0.8;env.dispose();pmrem.dispose();
  new ResizeObserver(()=>{const host=$('viewer').parentElement;renderer.setSize(host.clientWidth,host.clientHeight,false);camera.aspect=host.clientWidth/host.clientHeight;camera.updateProjectionMatrix();}).observe($('viewer').parentElement);
  frame();vehicles=await loadDetailedVehicles();Object.values(vehicles).forEach(model=>scene.add(model.root));
  select('car');$('loading').hidden=true;$('spin').disabled=false;$('reset').disabled=false;
} catch(error) {$('loading').hidden=true;$('error').hidden=false;console.error('Vehicle viewer failed',error);}
