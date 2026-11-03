import * as THREE from './vendor/three/three.module.min.js';
import { makeReviewVehicle } from './review-vehicles.js';
const entries=[];let playing=true,time=0,last=performance.now();
const play=document.querySelector('#play'),angle=document.querySelector('#angle');
play.onclick=()=>{playing=!playing;play.textContent=playing?'Tạm dừng':'Tiếp tục';};
document.querySelector('#reset').onclick=()=>{time=0;draw();};
angle.onchange=()=>draw();
function draw(){
  for(const {renderer,scene,camera,model,kind,host} of entries){
    const distance=time*(kind==='pedestrian'?.9:2);
    model.animate({time,distance,scale:1,moving:true});
    for(const wheel of model.wheelList)wheel.spin.rotation.z=-distance/wheel.radius*(wheel.direction||1);
    const centre=new THREE.Vector3(0,.95,0),view=angle.value==='side'?new THREE.Vector3(0,1.5,5):angle.value==='front'?new THREE.Vector3(5,1.5,0):new THREE.Vector3(3.8,2.4,5);
    camera.position.copy(view);camera.lookAt(centre);camera.updateMatrixWorld(true);
    const w=host.clientWidth,h=host.clientHeight;renderer.setSize(w,h,false);const aspect=w/h;camera.left=-1.25*aspect;camera.right=1.25*aspect;camera.top=1.25;camera.bottom=-1.25;camera.updateProjectionMatrix();
    renderer.render(scene,camera);
  }
}
async function load(){
  try{
    for(const host of document.querySelectorAll('.viewport')){
      const kind=host.dataset.kind,model=await makeReviewVehicle(kind),scene=new THREE.Scene();scene.background=new THREE.Color('#eef2ed');scene.add(model.root);
      scene.add(new THREE.HemisphereLight(0xffffff,0x777363,2.7));const light=new THREE.DirectionalLight(0xffffff,3.5);light.position.set(3,6,4);scene.add(light);
      const camera=new THREE.OrthographicCamera(-1.25,1.25,1.25,-1.25,.01,100),renderer=new THREE.WebGLRenderer({antialias:true});renderer.setPixelRatio(Math.min(devicePixelRatio,2));renderer.outputColorSpace=THREE.SRGBColorSpace;renderer.toneMapping=THREE.ACESFilmicToneMapping;host.append(renderer.domElement);
      entries.push({renderer,scene,camera,model,kind,host});new ResizeObserver(draw).observe(host);
    }
    document.querySelector('#status').textContent='Đã tải đủ ba model. Bản xem thử chưa thay trạng thái duyệt sa hình.';
    draw();requestAnimationFrame(tick);
  }catch(error){document.querySelector('#status').textContent='Không tải được model: '+error.message;}
}
function tick(now){const delta=Math.min((now-last)/1000,.1);last=now;if(playing&&!document.hidden){time+=delta;draw();}requestAnimationFrame(tick);}
load();
