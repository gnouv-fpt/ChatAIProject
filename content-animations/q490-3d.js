import * as THREE from './vendor/three/three.module.min.js';
import { ground, screenToGround } from './q490-ground.mjs';
import { loadDetailedVehicles } from './q490-detailed-models.js?v=city-1';
import { loadFleetVehicle } from './review-detailed-fleet.js';
import { RoomEnvironment } from './vendor/three/RoomEnvironment.js';

const $ = id => document.getElementById(id);
const items = [
  { id: 'moto', name: 'xe mô tô', duration: 8, wheelbase: 1.45, scale: 0.75 },
  { id: 'car', name: 'xe con', duration: 8, wheelbase: 2.28, scale: 0.55 },
  { id: 'truck', name: 'xe tải', duration: 10, wheelbase: 4.65, scale: 0.65 }
];
const scene = new THREE.Scene();
const camera = new THREE.OrthographicCamera(-20, 20, 20, -20, 0.1, 500);
camera.position.set(52.8, 49.4, 57.6);
camera.lookAt(0, 0, 0);
camera.updateMatrixWorld(true);
// Oblique orthographic projection keeps ground contact on the source-image road.
// Vehicle orientation changes in world space, so the visible sides change during turns.
const projection = new THREE.Matrix4().set(
  ground.xx / 248, 0, ground.xz / 248, 0,
  -ground.yx / 140, ground.height / 140, -ground.yz / 140, 0,
  -0.0057, -0.0053, -0.0062, 0,
  0, 0, 0, 1
);
camera.projectionMatrix.copy(projection).multiply(camera.matrixWorld);
camera.projectionMatrixInverse.copy(camera.projectionMatrix).invert();

scene.add(new THREE.HemisphereLight(0xe8f4ff, 0x71685b, 2.8));
const sun = new THREE.DirectionalLight(0xfff4de, 3);
sun.position.set(-15, 26, 10);
sun.castShadow = true;
sun.shadow.mapSize.set(2048, 2048);
Object.assign(sun.shadow.camera, { left: -32, right: 32, top: 32, bottom: -32, near: 1, far: 100 });
sun.shadow.bias = -0.0002;
sun.shadow.normalBias = 0.025;
scene.add(sun);
const roadShadow = new THREE.Mesh(new THREE.PlaneGeometry(150, 150), new THREE.ShadowMaterial({ opacity: 0.23 }));
roadShadow.rotation.x = -Math.PI / 2;
roadShadow.position.y = -0.012;
roadShadow.receiveShadow = true;
scene.add(roadShadow);

const materials = {};
function material(color, metalness = 0.05, roughness = 0.45) {
  const key = `${color}/${metalness}/${roughness}`;
  return materials[key] ||= new THREE.MeshStandardMaterial({ color, metalness, roughness });
}
const rubber = material('#1d2427', 0, 0.9), metal = material('#b1b9bd', 0.65, 0.3);
const glass = material('#16242e', 0.4, 0.16), red = material('#94151e', 0.32, 0.28);
const dark = material('#242c32', 0.08, 0.7), white = material('#e2e4dd', 0.15, 0.45);
function mesh(parent, geometry, mat, x = 0, y = 0, z = 0) {
  const object = new THREE.Mesh(geometry, mat);
  object.position.set(x, y, z);
  object.castShadow = true;
  object.receiveShadow = true;
  parent.add(object);
  return object;
}
function box(parent, size, pos, mat) { return mesh(parent, new THREE.BoxGeometry(...size), mat, ...pos); }
function roundedBox(parent, size, pos, mat, radius = 0.1) {
  const geometry = new THREE.BoxGeometry(...size, 6, 6, 6);
  const positions = geometry.attributes.position, normals = geometry.attributes.normal;
  const half = new THREE.Vector3(...size).multiplyScalar(0.5);
  const inner = half.clone().subScalar(radius), p = new THREE.Vector3(), core = new THREE.Vector3();
  for (let i=0;i<positions.count;i++) {
    p.fromBufferAttribute(positions,i);
    core.copy(p).clamp(inner.clone().negate(),inner);
    const normal=p.sub(core).normalize();
    p.copy(core).addScaledVector(normal,radius);
    positions.setXYZ(i,p.x,p.y,p.z); normals.setXYZ(i,normal.x,normal.y,normal.z);
  }
  return mesh(parent,geometry,mat,...pos);
}
function sideShell(parent, profile, depth, mat, bevel = 0.04) {
  const geometry = new THREE.ExtrudeGeometry(profile, {depth,bevelEnabled:true,bevelSize:bevel,bevelThickness:bevel,bevelSegments:4,curveSegments:16,steps:1});
  geometry.translate(0,0,-depth/2);
  return mesh(parent,geometry,mat);
}
function sphere(parent, radius, pos, mat, scale = [1, 1, 1]) {
  const object = mesh(parent, new THREE.SphereGeometry(radius, 20, 12), mat, ...pos);
  object.scale.set(...scale);
  return object;
}
function rod(parent, from, to, radius, mat) {
  const a = new THREE.Vector3(...from), b = new THREE.Vector3(...to);
  const object = mesh(parent, new THREE.CylinderGeometry(radius, radius, a.distanceTo(b), 12), mat);
  object.position.copy(a).add(b).multiplyScalar(0.5);
  object.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), b.sub(a).normalize());
  return object;
}
function panel(parent, points, mat) {
  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute('position', new THREE.Float32BufferAttribute(points.flat(), 3));
  geometry.setIndex([0, 1, 2, 0, 2, 3]);
  geometry.computeVertexNormals();
  const face = mesh(parent, geometry, mat);
  face.material = mat.clone();
  face.material.side = THREE.DoubleSide;
  return face;
}
function curvedGlass(parent, start, control, end, halfWidth, offset = 0.11) {
  const curve=new THREE.QuadraticBezierCurve(new THREE.Vector2(...start),new THREE.Vector2(...control),new THREE.Vector2(...end));
  const edge=t=>{
    const p=curve.getPoint(t),tangent=curve.getTangent(t);
    p.add(new THREE.Vector2(-tangent.y,tangent.x).multiplyScalar(offset));
    return [[p.x,p.y,-halfWidth],[p.x,p.y,halfWidth]];
  };
  for(let i=0;i<12;i++) {
    const a=edge(0.08+i/12*0.82),b=edge(0.08+(i+1)/12*0.82);
    panel(parent,[a[0],a[1],b[1],b[0]],glass);
  }
}
function wheels(parent, wheelList, axles, halfWidth, radius, width) {
  for (const x of axles) for (const side of halfWidth ? [-1, 1] : [0]) {
    const pivot = new THREE.Group();
    pivot.position.set(x, radius, side * halfWidth);
    const spin = new THREE.Group();
    pivot.add(spin); parent.add(pivot);
    const tire = mesh(spin, new THREE.CylinderGeometry(radius, radius, width, 24), rubber);
    tire.rotation.x = Math.PI / 2;
    for (const sign of [-1, 1]) {
      const hub = mesh(spin, new THREE.CylinderGeometry(radius * 0.58, radius * 0.58, 0.025, 16), metal, 0, 0, sign * (width / 2 + 0.015));
      hub.rotation.x = Math.PI / 2;
      for (let n = 0; n < 5; n++) {
        const spoke = box(spin, [radius * 0.82, 0.045, 0.03], [0, 0, sign * (width / 2 + 0.035)], dark);
        spoke.rotation.z = n * Math.PI / 5;
      }
    }
    wheelList.push({ pivot, spin, radius, front: x === axles[axles.length - 1] });
  }
}
function truck() {
  const root = new THREE.Group(), wheelList = [], turquoise = material('#087f87',0.22,0.4);
  box(root,[6.8,0.25,1.9],[0,0.6,0],dark);
  const cargoSide=material('#a6a8a8',0.03,0.95),cargoRoof=material('#c9cccc',0.03,0.95);
  roundedBox(root,[4.65,2.25,2.08],[-1,1.92,0],[cargoSide,cargoSide,cargoRoof,cargoSide,cargoSide,cargoSide],0.065);
  for (const z of [-1.055,1.055]) {
    box(root,[4.6,0.09,0.035],[-1,0.9,z],metal);
    box(root,[4.6,0.06,0.035],[-1,2.99,z],metal);
  }
  const cab=new THREE.Shape();
  cab.moveTo(1.44,0.72);cab.lineTo(3.34,0.72);cab.lineTo(3.34,1.58);
  cab.quadraticCurveTo(3.25,2.04,2.95,2.27);cab.quadraticCurveTo(2.58,2.57,1.44,2.58);cab.closePath();
  sideShell(root,cab,1.77,turquoise,0.11);
  const fairing=new THREE.Shape();
  fairing.moveTo(1.43,2.55);fairing.lineTo(2.75,2.55);fairing.quadraticCurveTo(2.24,2.89,1.43,3.05);fairing.closePath();
  sideShell(root,fairing,1.69,turquoise,0.05);
  curvedGlass(root,[2.95,2.27],[3.25,2.04],[3.34,1.58],0.77,0.13);
  roundedBox(root,[0.13,0.17,1.82],[3.37,0.94,0],dark,0.055);
  for (const z of [-0.997,0.997]) {
    panel(root,[[1.73,1.6,z],[1.73,2.42,z],[2.85,2.21,z],[3.25,1.6,z]],glass);
    box(root,[0.3,0.05,0.03],[1.96,1.45,z],metal);
    rod(root,[3.02,2.05,z],[3.2,2.1,z*1.24],0.035,dark);
    box(root,[0.13,0.35,0.22],[3.2,1.96,z*1.24],dark);
    roundedBox(root,[0.035,0.19,0.36],[3.46,1.19,z*0.68],material('#e9e4ce'),0.015);
  }
  roundedBox(root,[0.08,0.27,1.2],[3.43,1.35,0],dark,0.025);
  for (let y=1.28;y<1.47;y+=0.07)box(root,[0.01,0.018,1.04],[3.478,y,0],metal);
  for (const z of [-0.55,0.55]) {
    box(root,[0.04,1.91,0.035],[-3.34,1.9,z],metal);
    box(root,[0.05,0.13,0.34],[-3.35,0.88,z],material('#e6362c'));
  }
  wheels(root,wheelList,[-2.3,2.35],1.01,0.49,0.3);
  return {root,wheelList};
}
function rider() {
  const root=new THREE.Group();
  sphere(root,0.24,[0.25,1.52,0],white);
  sphere(root,0.23,[0.37,1.53,0],glass,[0.65,0.44,0.97]);
  rod(root,[-0.4,1.02,0],[0.06,1.32,0],0.19,material('#e3ded0',0,0.9));
  for (const side of [-1,1]) {
    rod(root,[0.02,1.31,side*0.17],[0.35,1.08,side*0.28],0.08,white);
    rod(root,[0.35,1.08,side*0.28],[0.65,1.12,side*0.27],0.065,white);
    rod(root,[-0.35,1.01,side*0.18],[0.05,0.64,side*0.3],0.1,material('#31435a'));
    rod(root,[0.05,0.64,side*0.3],[-0.28,0.33,side*0.27],0.08,material('#31435a'));
    box(root,[0.32,0.13,0.17],[-0.2,0.27,side*0.27],dark);
  }
  return root;
}

function route(id) {
  const path = $('drive-' + id), length = path.getTotalLength(), points = [], distances = [0];
  for (let i=0;i<=600;i++) {
    const p = path.getPointAtLength(length*i/600), world=screenToGround(p.x,p.y);
    points.push(new THREE.Vector3(world.x,0,world.z));
    if(i) distances.push(distances[i-1]+points[i].distanceTo(points[i-1]));
  }
  const total = distances.at(-1);
  function at(distance) {
    if(distance<0) return points[0].clone().addScaledVector(points[1].clone().sub(points[0]).normalize(),distance);
    if(distance>total) return points.at(-1).clone().addScaledVector(points.at(-1).clone().sub(points.at(-2)).normalize(),distance-total);
    let lo=0,hi=distances.length-1;
    while(hi-lo>1) { const mid=(lo+hi)>>1; if(distances[mid]<distance)lo=mid;else hi=mid; }
    return points[lo].clone().lerp(points[hi],(distance-distances[lo])/(distances[hi]-distances[lo]||1));
  }
  return {at,total};
}
items.forEach(item=>{item.route=route(item.id);item.progress=0;});
let renderer, ready=false, active=0, mode='single', running=false, raf=0, last=0, hold=0;
function updateModel(item) {
  const {root,wheelList}=item.model, distance=item.progress*item.route.total;
  const wheelbase=item.wheelbase*item.scale;
  const rear=item.route.at(distance-wheelbase/2),front=item.route.at(distance+wheelbase/2);
  root.position.copy(rear).add(front).multiplyScalar(0.5);
  const forward=front.clone().sub(rear);
  const yaw=-Math.atan2(forward.z,forward.x);
  root.rotation.y=yaw;
  const ahead=item.route.at(distance+wheelbase/2+0.6).sub(front);
  let steer=-Math.atan2(ahead.z,ahead.x)-yaw;
  steer=Math.atan2(Math.sin(steer),Math.cos(steer));
  for(const wheel of wheelList) {
    wheel.spin.rotation.z=-distance/(wheel.radius*item.scale)*(wheel.direction||1);
    wheel.pivot.rotation.y=wheel.front?THREE.MathUtils.clamp(steer,-0.6,0.6):0;
  }
}
function draw() {
  if(!ready)return;
  items.forEach(updateModel);
  renderer.render(scene,camera);
  const percent=Math.round(items[active].progress*1000)/10;
  $('progress').value=percent; $('progress-value').textContent=`${Math.round(percent)}%`;
}
function select(index) {
  active=index;
  document.querySelectorAll('[data-vehicle]').forEach(b=>b.classList.toggle('active',b.dataset.vehicle===items[active].id));
  document.querySelectorAll('[data-order]').forEach(b=>b.classList.toggle('active',b.dataset.order===items[active].id));
  document.querySelectorAll('.guide').forEach(g=>g.classList.toggle('active',g.id==='guide-'+items[active].id));
  $('scrub-label').textContent=`Vị trí ${items[active].name}`;
  $('scene-badge').textContent=`Lượt ${active+1} · ${items[active].name}`;
  $('status').textContent=`Lượt ${active+1}: ${items[active].name} qua giao lộ.`;
}
function stop() { cancelAnimationFrame(raf); running=false; $('pause').textContent='Tiếp tục'; }
function reset() {
  stop(); items.forEach(item=>item.progress=0); hold=0; select(0); draw();
  $('pause').disabled=true; $('status').textContent='Bấm Phát thứ tự hoặc chọn một xe.';
  $('scene-badge').textContent='Sẵn sàng';
}
function normalView() { $('stage').classList.remove('show-original'); $('compare').setAttribute('aria-pressed','false'); }
function tick(now) {
  if(!running)return;
  const dt=Math.min((now-last)/1000,0.1)*Number($('speed').value); last=now;
  if(hold>0) {
    hold-=dt;
    if(hold<=0) {select(active+1);}
  } else {
    const item=items[active]; item.progress=Math.min(1,item.progress+dt/item.duration); draw();
    if(item.progress===1) {
      if(mode==='sequence'&&active<items.length-1)hold=0.8;
      else {stop(); $('pause').disabled=true; $('scene-badge').textContent='Đã qua giao lộ'; $('status').textContent=mode==='sequence'?'Đã xem hết: mô tô → xe con → xe tải.':`${item.name} đã đi qua giao lộ. Kéo thanh vị trí để xem lại.`;return;}
    }
  }
  raf=requestAnimationFrame(tick);
}
function start() { normalView(); running=true;last=performance.now();$('pause').disabled=false;$('pause').textContent='Tạm dừng';raf=requestAnimationFrame(tick); }
$('play').onclick=()=>{ if(!ready)return;reset();mode='sequence';select(0);$('stage').scrollIntoView({block:'start',behavior:'instant'});start(); };
$('pause').onclick=()=>running?stop():start();
$('reset').onclick=reset;
$('progress').oninput=()=>{stop();hold=0;mode='single';items[active].progress=Number($('progress').value)/100;normalView();draw();$('pause').disabled=items[active].progress===1;};
document.querySelectorAll('[data-vehicle]').forEach(button=>button.onclick=()=>{if(!ready)return;reset();select(items.findIndex(item=>item.id===button.dataset.vehicle));mode='single';$('stage').scrollIntoView({block:'start',behavior:'instant'});start();});
$('guides').onchange=()=>$('stage').classList.toggle('hide-guides',!$('guides').checked);
$('compare').onclick=()=>{if(running)stop();const showing=$('stage').classList.toggle('show-original');$('compare').setAttribute('aria-pressed',String(showing));};
document.addEventListener('visibilitychange',()=>{if(document.hidden&&running)stop();});
async function initialize() {
try {
  $('stage').classList.add('show-original');
  $('compare').disabled=true;
  $('status').textContent='Đang tải model ô tô, mô tô và xe tải chi tiết…';
  $('scene-badge').textContent='Đang tải model…';
  renderer=new THREE.WebGLRenderer({canvas:$('vehicles'),alpha:true,antialias:true});
  renderer.setPixelRatio(Math.min(devicePixelRatio,2));
  renderer.shadowMap.enabled=true;renderer.shadowMap.type=THREE.PCFSoftShadowMap;
  renderer.toneMapping=THREE.ACESFilmicToneMapping;renderer.toneMappingExposure=1.1;
  renderer.setClearColor(0,0);
  const detailed=await loadDetailedVehicles();
  items[0].model=detailed.moto;items[0].model.root.add(rider());
  items[1].model=detailed.car;items[2].model=await loadFleetVehicle('truck');items[2].wheelbase=items[2].model.wheelbase;
  items.forEach(item=>{item.model.root.scale.setScalar(item.scale);scene.add(item.model.root);});
  const environment=new RoomEnvironment();
  const pmrem=new THREE.PMREMGenerator(renderer);
  scene.environment=pmrem.fromScene(environment,0.04).texture;
  scene.environmentIntensity=0.65;
  environment.dispose();pmrem.dispose();
  ready=true;
  new ResizeObserver(()=>{const width=$('stage').clientWidth;renderer.setSize(width,width*280/496,false);draw();}).observe($('stage'));
  $('compare').disabled=false;$('play').disabled=false;normalView();reset();
} catch(error) {
  $('error').hidden=false;$('error').textContent='Không tải được model hoặc bộ dựng 3D. Kiểm tra kết nối rồi tải lại trang bằng trình duyệt hỗ trợ WebGL.';
  $('status').textContent='Chưa tải được model chi tiết.';$('scene-badge').textContent='Không tải được model';
  console.error('Q490 renderer initialization failed',error);
}
}
initialize();
