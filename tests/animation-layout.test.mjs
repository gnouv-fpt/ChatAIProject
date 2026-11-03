import test from 'node:test';
import assert from 'node:assert/strict';
import { captionPositions,driverDepthScale,foregroundMask } from '../content-animations/review-layout.mjs';

test('clustered mobile captions remain separate and inside the scene',()=>{
  for(const width of [310,1024]){
    const input=[{x:5,y:140,width:145,height:15},{x:8,y:145,width:160,height:15},{x:10,y:150,width:130,height:15}];
    const actual=captionPositions(input,width,180,[{x:220,y:60,width:35,height:60}]);
    for(const [i,r] of actual.entries()){
      assert.ok(r.x>=0&&r.y>=0&&r.x+r.width<=width&&r.y+r.height<=180);
      for(const s of actual.slice(0,i))assert.ok(r.x>=s.x+s.width||r.x+r.width<=s.x||r.y>=s.y+s.height||r.y+r.height<=s.y);
    }
    assert.deepEqual(captionPositions(input,width,180),captionPositions(input,width,180));
  }
});

test('approaching objects grow smoothly from their calibrated source size',()=>{
  const actor={at:[47.5,51.5],depthScale:{horizon:44,max:7}};
  assert.equal(driverDepthScale(actor,actor.at),1);
  let previous=0;
  for(let y=44;y<=70;y+=.1){const s=driverDepthScale(actor,[40,y]);assert.ok(Number.isFinite(s)&&s>=previous);previous=s;}
  assert.ok(driverDepthScale(actor,[35,60])>2);
  assert.equal(driverDepthScale({},[40,60]),1);
});

test('cockpit masks leave the source foreground in front of moving models',()=>{
  assert.equal(foregroundMask(null,500,300),'none');
  const xml=decodeURIComponent(foregroundMask([[[0,80],[100,80],[100,100],[0,100]]],500,300));
  assert.match(xml,/0,240 500,240 500,300 0,300/);
  assert.match(xml,/fill="black"/);assert.match(xml,/mask="url\(#window\)"/);
});
