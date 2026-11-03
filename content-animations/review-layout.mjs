const clamp=(n,a,b)=>Math.max(a,Math.min(b,n));

export function driverDepthScale(actor,at) {
  if(!actor.depthScale)return 1;
  const {horizon,max=6}=actor.depthScale;
  return clamp((at[1]-horizon)/Math.max(1,actor.at[1]-horizon),.18,max);
}

export function foregroundMask(polygons,width,height) {
  if(!polygons?.length)return 'none';
  const paths=polygons.map(p=>`<polygon fill="black" points="${p.map(([x,y])=>`${x*width/100},${y*height/100}`).join(' ')}"/>`).join('');
  const xml=`<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}"><mask id="window"><rect width="100%" height="100%" fill="white"/>${paths}</mask><rect width="100%" height="100%" fill="white" mask="url(#window)"/></svg>`;
  return `url("data:image/svg+xml,${encodeURIComponent(xml)}")`;
}

export function captionPositions(rectangles,width,height,obstacles=[]) {
  const placed=[],result=[],pad=3;
  const overlap=(a,b)=>Math.max(0,Math.min(a.x+a.width,b.x+b.width)-Math.max(a.x,b.x))*Math.max(0,Math.min(a.y+a.height,b.y+b.height)-Math.max(a.y,b.y));
  for(const original of rectangles) {
    let best=null,bestScore=Infinity;
    const row=original.height+pad;
    for(let i=0;i<=Math.ceil(height/row);i++)for(const direction of i?[1,-1]:[1])for(const dx of [0,-original.width/2,original.width/2,-original.width,original.width]) {
      const candidate={...original,x:clamp(original.x+dx,pad,Math.max(pad,width-original.width-pad)),y:clamp(original.y+i*direction*row,pad,Math.max(pad,height-original.height-pad))};
      const collision=[...placed,...obstacles].reduce((sum,r)=>sum+overlap({...candidate,x:candidate.x-pad/2,y:candidate.y-pad/2,width:candidate.width+pad,height:candidate.height+pad},r),0);
      const score=collision*10000+Math.hypot(candidate.x-original.x,candidate.y-original.y);
      if(score<bestScore){bestScore=score;best=candidate;}
    }
    placed.push(best);result.push(best);
  }
  return result;
}
