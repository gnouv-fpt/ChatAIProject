// Parametric SVG vehicles. No bitmap crops, WebGL, or downloaded sprite sheets.
const NS='http://www.w3.org/2000/svg';
const cache=new Map();
const shade=(hex,f)=>'#'+[1,3,5].map(i=>Math.min(255,Math.round(parseInt(hex.slice(i,i+2),16)*f)).toString(16).padStart(2,'0')).join('');
function geometry(kind,color) {
  const key=kind+color;if(cache.has(key))return cache.get(key);
  const faces=[];
  function polygon(points,fill){faces.push({points,fill});}
  function box(size,at,fill) {
    const [l,h,w]=size,[x,y,z]=at;
    const p=(a,b,c)=>[x+a*l/2,y+b*h/2,z+c*w/2];
    for(const [indices,factor] of [
      [[[-1,-1,-1],[1,-1,-1],[1,1,-1],[-1,1,-1]],.83],
      [[[-1,-1,1],[1,-1,1],[1,1,1],[-1,1,1]],.94],
      [[[1,-1,-1],[1,-1,1],[1,1,1],[1,1,-1]],1.05],
      [[[-1,-1,-1],[-1,-1,1],[-1,1,1],[-1,1,-1]],.72],
      [[[-1,1,-1],[1,1,-1],[1,1,1],[-1,1,1]],1.15]])polygon(indices.map(v=>p(...v)),shade(fill,factor));
  }
  function wheel(x,z,r=.36) {
    const points=Array.from({length:18},(_,i)=>[x+Math.cos(i/18*Math.PI*2)*r,r+Math.sin(i/18*Math.PI*2)*r,z]);
    polygon(points,'#25343c');polygon(points.map(p=>[x+(p[0]-x)*.51,r+(p[1]-r)*.51,z+.012]),'#bec9cd');
  }
  const paint=color||({bus:'#c6b333',fire:'#d33c36',army:'#697c3c',ambulance:'#f0f0e5',truck:'#288e9b',container:'#c3b16b',train:'#397fb4',van:'#b9c7d0'}[kind])||'#3168a1';
  if(['moto','bicycle','tricycle'].includes(kind)) {
    const bike=kind==='bicycle',trike=kind==='tricycle';
    for(const x of [-.75,.75])for(const z of trike&&x<0?[-.45,.45]:[0])wheel(x,z,.34);
    box([1.15,.18,.24],[-.1,.65,0],bike?'#b13137':paint);
    box([.5,.14,.3],[-.3,.88,0],'#26363b');box([.65,.16,.34],[.45,.82,0],bike?'#b13137':'#d73a32');
    box([.34,.65,.45],[-.05,1.21,0],'#dfe8df');box([.36,.31,.37],[.1,1.67,0],'#f0f3e9');box([.06,.12,.34],[.3,1.68,0],'#243d48');
    if(trike)box([.9,.3,1],[-.8,.68,0],'#8e9d9e');
  } else if(['car','police'].includes(kind)) {
    box([3.55,.54,1.58],[0,.64,0],kind==='police'?'#e8eced':paint);
    box([1.85,.64,1.43],[-.1,1.22,0],kind==='police'?'#e8eced':paint);
    for(const z of [-.724,.724]) {box([1.45,.38,.015],[-.05,1.29,z],'#315261');box([.045,.5,.025],[-.1,1.24,z],paint);}
    box([.025,.43,1.26],[.84,1.27,0],'#315261');box([.025,.39,1.26],[-1.04,1.27,0],'#315261');
    for(const z of [-.81,.81])for(const x of [-1.12,1.16])wheel(x,z,.34);
    for(const z of [-.55,.55])box([.025,.12,.32],[1.79,.74,z],'#fff3bd');
    if(kind==='police')for(const z of [-.3,.3])box([.45,.14,.3],[0,1.63,z],z<0?'#d33743':'#286bcb');
  } else {
    const bus=kind==='bus',train=kind==='train',ambulance=kind==='ambulance',van=kind==='van';
    const length=bus?8.4:train?9:kind==='container'?11:ambulance||van?4.8:6.8;
    box([length,.25,1.95],[0,.58,0],'#36464b');
    if(bus||train||ambulance||van) {
      box([length,bus||train?2.2:1.9,2.05],[0,1.78,0],paint);
      box([.025,.8,1.75],[length/2+.02,2.05,0],'#284956');
      for(const z of [-1.04,1.04])for(let x=-length/2+.65;x<length/2-.3;x+=.85)box([.65,.74,.02],[x,2.12,z],'#284956');
      if(ambulance)for(const z of [-1.065,1.065]) {box([.65,.16,.02],[-.4,1.9,z],'#d13839');box([.16,.65,.02],[-.4,1.9,z],'#d13839');}
    } else {
      const cab=kind==='container'?4.4:2.35;
      box([1.8,1.8,1.98],[cab,1.55,0],paint);box([.025,.73,1.7],[cab+.92,1.99,0],'#294b57');
      for(const z of [-1.005,1.005])box([1.25,.65,.025],[cab+.1,1.99,z],'#294b57');
      box([kind==='container'?8.8:4.65,2.15,2.1],[kind==='container'?-.85:-1,1.91,0],['fire','army'].includes(kind)?paint:'#d4dddc');
      const rear=kind==='container'?-5.27:-3.35;
      box([.03,1.95,.025],[rear,1.91,0],'#43565b');
      for(const z of [-.75,.75]){box([.05,1.7,.035],[rear-.02,1.94,z],'#92a4a8');box([.05,.18,.3],[rear-.04,.67,z],'#c9343e');}
      box([.1,.13,2],[rear-.07,.45,0],'#9bacae');
    }
    const axles=bus||train?[-length*.34,length*.34]:kind==='container'?[-4.2,3.95]:ambulance||van?[-1.5,1.5]:[-2.3,2.35];
    for(const z of [-1.08,1.08])for(const x of axles)wheel(x,z,.43);
    if(ambulance||kind==='fire')for(const z of [-.5,.5])box([.3,.18,.4],[ambulance?1.2:2.1,2.8,z],z<0?'#d02b3d':'#2c6dc9');
  }
  cache.set(key,faces);return faces;
}
export function vehicleSprite(actor,pose,{width,height,center,frame}) {
  const faces=geometry(actor.kind,actor.color),c=Math.cos(pose.yaw),s=Math.sin(pose.yaw);
  const rotate=([x,y,z])=>[x*c+z*s,y,-x*s+z*c];
  const f=frame,det=f.xx*f.yz-f.xz*f.yx;
  const project=([x,y,z])=>[(f.xx*x+f.xz*z)/496*100,(f.yx*x+f.yz*z-f.height*y)/496*width/height*100];
  const transformed=faces.map(face=>{const p=face.points.map(rotate);return {points:p.map(project),fill:face.fill,depth:p.reduce((sum,[x,y,z])=>sum-f.xz*f.height*x+det*y+f.xx*f.height*z,0)/p.length};});
  const points=transformed.flatMap(f=>f.points),xs=points.map(p=>p[0]),ys=points.map(p=>p[1]);
  const bounds=[Math.min(...xs),Math.min(...ys),Math.max(...xs),Math.max(...ys)];
  let scale=actor.width/(bounds[2]-bounds[0]);
  if(actor.anchor==='box')scale=Math.min(scale,actor.rect[3]/(bounds[3]-bounds[1]));
  const offset=actor.anchor==='box'?[(bounds[0]+bounds[2])/2,(bounds[1]+bounds[3])/2]:[0,0];
  const group=document.createElementNS(NS,'g');group.setAttribute('data-vehicle',actor.id);group.setAttribute('transform',`translate(${center[0]} ${center[1]}) scale(${scale}) translate(${-offset[0]} ${-offset[1]})`);
  for(const face of transformed.sort((a,b)=>a.depth-b.depth)) {
    const node=document.createElementNS(NS,'polygon');node.setAttribute('points',face.points.map(p=>p.join(',')).join(' '));node.setAttribute('fill',face.fill);node.setAttribute('stroke','#173a3b');node.setAttribute('stroke-width','0.035');node.setAttribute('stroke-linejoin','round');group.append(node);
  }
  return group;
}
