export function groundFrame(recipe,width) {
  if(recipe.perspective==='driver')return {xx:24,xz:0,yx:0,yz:1.8,height:24,scale:width/496};
  const angles=recipe.roadCalibration?.angles||[-29,29],r=Math.PI/180;
  return {xx:28*Math.cos(angles[0]*r),xz:28*Math.cos(angles[1]*r),yx:28*Math.sin(angles[0]*r),yz:28*Math.sin(angles[1]*r),height:24,scale:width/496};
}
export function groundPoint([x,y],frame,width,height) {
  const dx=(x/100-.5)*width/frame.scale,dy=(y/100-.5)*height/frame.scale,det=frame.xx*frame.yz-frame.xz*frame.yx;
  return {x:(frame.yz*dx-frame.xz*dy)/det,z:(-frame.yx*dx+frame.xx*dy)/det};
}
export function imagePoint(point,frame,width,height) {
  return [50+(frame.xx*point.x+frame.xz*point.z)*frame.scale/width*100,50+(frame.yx*point.x+frame.yz*point.z-frame.height*(point.y||0))*frame.scale/height*100];
}
export function laneHeading(heading,frame) {
  const length=Math.hypot(...heading),candidates=[[frame.xx,frame.yx],[frame.xz,frame.yz],[-frame.xx,-frame.yx],[-frame.xz,-frame.yz]];
  return candidates.sort((a,b)=>(b[0]*heading[0]+b[1]*heading[1])/Math.hypot(...b)/length-(a[0]*heading[0]+a[1]*heading[1])/Math.hypot(...a)/length)[0];
}
