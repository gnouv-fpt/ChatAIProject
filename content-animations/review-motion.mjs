import * as THREE from './vendor/three/three.module.min.js';

// Straight lane segments stay straight; only the immediate corner is rounded.
// Pixel tracing follows arrowheads/line crossings and must not drive a vehicle.
export function roadCurve(path,width,height,toGround) {
  const points=path.map(([x,y])=>new THREE.Vector3(x*width/100,y*height/100,0));
  const source=new THREE.CurvePath();let previous=points[0];
  for(let i=1;i<points.length-1;i++) {
    const p=points[i],before=points[i-1],after=points[i+1];
    const radius=Math.min(p.distanceTo(before)*.3,p.distanceTo(after)*.3,22);
    const entry=p.clone().lerp(before,radius/(p.distanceTo(before)||1));
    const exit=p.clone().lerp(after,radius/(p.distanceTo(after)||1));
    if(previous.distanceTo(entry)>1e-6)source.add(new THREE.LineCurve3(previous,entry));
    source.add(new THREE.QuadraticBezierCurve3(entry,p,exit));previous=exit;
  }
  source.add(new THREE.LineCurve3(previous,points.at(-1)));
  const curve=new THREE.Curve();
  curve.getPoint=(t,target=new THREE.Vector3())=>{const p=source.getPoint(t);return target.copy(toGround([p.x/width*100,p.y/height*100]));};
  curve.arcLengthDivisions=1200;return curve;
}

// Short acceleration/deceleration ramps, constant cruise through the intersection.
export function travelProgress(t) {
  t=Math.max(0,Math.min(1,t));const ramp=.12,total=1-ramp;
  if(t<ramp)return t*t/(2*ramp*total);
  if(t>1-ramp)return 1-(1-t)*(1-t)/(2*ramp*total);
  return (t-ramp/2)/total;
}
