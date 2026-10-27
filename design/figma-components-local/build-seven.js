// Standard Figma Plugin API. No network calls or credentials.
// Variant construction follows figma-generate-library/scripts/createComponentWithVariants.js.
async function buildSeven() {
  const page = await figma.getNodeByIdAsync('0:1');
  if (!page || page.type !== 'PAGE' || page.name !== '03 Final UI') throw new Error('Open the original FLM file. Expected page 0:1 / 03 Final UI.');
  await figma.setCurrentPageAsync(page);
  const prior = page.findOne(n => n.name === 'FLM · Seven components · Review');
  if (prior) throw new Error('Review already exists: ' + prior.id + '. Inspect it before running again.');
  const vars = new Map((await figma.variables.getLocalVariablesAsync()).map(v => [v.name, v]));
  const styles = new Map((await figma.getLocalTextStylesAsync()).map(s => [s.name, s]));
  for (const name of ['color/primary','color/primary-dark','color/primary-light','color/card','color/surface','color/text','color/text-muted','color/border','color/disabled','color/error','spacing/8','spacing/16','spacing/24','radius/10','radius/14']) if (!vars.has(name)) throw new Error('Missing token: ' + name);
  for (const name of ['FLM/Title','FLM/Section','FLM/Body','FLM/Label']) if (!styles.has(name)) throw new Error('Missing text style: ' + name);
  const fonts = new Map();
  for (const s of styles.values()) fonts.set(JSON.stringify(s.fontName), s.fontName);
  await Promise.all([...fonts.values()].map(f => figma.loadFontAsync(f)));
  const button = await figma.getNodeByIdAsync('8:69');
  if (!button || button.type !== 'COMPONENT') throw new Error('Missing existing Button/Default component 8:69.');
  const created = [], roots = [], sets = [], mutated = [];
  const track = n => { created.push(n.id); return n; };
  function paint(name) { return figma.variables.setBoundVariableForPaint({ type:'SOLID', color:{r:0,g:0,b:0} }, 'color', vars.get(name)); }
  function box(n, fill='color/card', radius='radius/14', pad=16) {
    n.fills = [paint(fill)]; n.clipsContent = false;
    if (radius) for (const k of ['topLeftRadius','topRightRadius','bottomLeftRadius','bottomRightRadius']) n.setBoundVariable(k, vars.get(radius));
    if (pad) for (const k of ['paddingTop','paddingBottom','paddingLeft','paddingRight']) n.setBoundVariable(k, vars.get('spacing/'+pad));
    n.setBoundVariable('itemSpacing', vars.get('spacing/8'));
  }
  function auto(parent, direction='VERTICAL', width=328, fill=null) {
    const f = track(figma.createFrame()); f.layoutMode=direction; f.resize(width,48);
    f.primaryAxisSizingMode='AUTO'; f.counterAxisSizingMode='FIXED'; f.fills=[]; f.clipsContent=false;
    parent.appendChild(f); f.setBoundVariable('itemSpacing',vars.get('spacing/8')); if(fill)f.fills=[paint(fill)]; return f;
  }
  async function text(parent, value, role='FLM/Body', color='color/text', width=328) {
    const t=track(figma.createText()); t.fontName={family:'Roboto',style:'Regular'}; t.characters=value;
    await t.setTextStyleIdAsync(styles.get(role).id); t.fills=[paint(color)]; t.textAutoResize='HEIGHT'; t.resize(width,t.height); parent.appendChild(t); return t;
  }
  function icon(parent,name,color='color/primary',size=24) {
    const svg=ICONS[name]; if(!svg)throw new Error('Missing bundled icon '+name);
    const n=track(figma.createNodeFromSvg(svg)); created.push(...n.findAll().map(x=>x.id)); n.name='Icon/'+name; n.resize(size,size); parent.appendChild(n);
    for(const v of n.findAll(x=>x.type==='VECTOR')) { if(v.strokes.length)v.strokes=[paint(color)]; if(v.fills.length)v.fills=[paint(color)]; }
    return n;
  }
  async function action(parent,label,secondary=false) {
    const b=track(button.createInstance()); created.push(...b.findAll().map(x=>x.id)); parent.appendChild(b); b.resize(144,48); b.name=label;
    const t=b.findOne(x=>x.type==='TEXT'); t.characters=label; t.resize(112,20); t.textAlignHorizontal='CENTER';
    if(secondary){b.fills=[paint('color/card')];b.strokes=[paint('color/border')];b.strokeWeight=1;t.fills=[paint('color/primary')];}return b;
  }
  function expose(comp,t,name,value) { const key=comp.addComponentProperty(name,'TEXT',value);t.componentPropertyReferences={characters:key}; }
  const definitions=[
    {name:'Card',states:['Default','Pressed','Selected','Disabled'],width:360,description:'Course summary card. State gives press/selection feedback; disabled has text label. Flutter Card + InkWell.'},
    {name:'Navigation',axis:'Active',states:['Home','Roadmap','Assistant','Transcript','Settings'],width:360,description:'Five Android top-level destinations, always one selected. Icons plus labels. Flutter NavigationBar.'},
    {name:'App bar',axis:'Variant',states:['Root','Back'],width:360,description:'Root or child header. Back action and trailing action have 48 dp targets. Flutter AppBar.'},
    {name:'Dialog',axis:'Variant',states:['Confirm','Error'],width:320,description:'Confirmation or recoverable error. Explicit cancel/confirm. Used as overlay; component itself does not delete data. Flutter AlertDialog.'},
    {name:'Loading',axis:'Variant',states:['Inline','Screen'],width:360,description:'Progress with visible explanatory label. Inline or panel presentation. Flutter CircularProgressIndicator.'},
    {name:'Empty',axis:'Variant',states:['Search','Transcript'],width:360,description:'No results or no transcript, with concrete next action. Never creates a GPA from missing marks.'},
    {name:'Error',axis:'Variant',states:['Network','Quota','Import'],width:360,description:'Error reason and recovery. Retry, Back or manual entry. No raw exception or stack trace.'}
  ];
  const maxX=Math.max(0,...page.children.map(n=>n.x+n.width));
  try {
    const source=track(figma.createSection());page.appendChild(source);roots.push(source);source.name='FLM · Seven component sources';source.x=maxX+1440;source.y=1000;source.resizeWithoutConstraints(1200,100);
    const review=auto(page,'VERTICAL',1160,'color/surface');roots.push(review);review.name='FLM · Seven components · Review';review.x=maxX+160;review.y=1000;box(review,'color/surface',null,24);review.itemSpacing=32;
    await text(review,'FLM / Android components','FLM/Title','color/text',1112);
    await text(review,'Editable component instances · Roboto · bound tokens · states for Android','FLM/Body','color/text-muted',1112);
    let sourceY=32;const families=[];
    for(const def of definitions){
      const components=[];
      for(const state of def.states){
        const c=track(figma.createComponent());page.appendChild(c);roots.push(c);c.name=(def.axis||'State')+'='+state;c.layoutMode='VERTICAL';c.resize(def.width,48);c.primaryAxisSizingMode='AUTO';c.counterAxisSizingMode='FIXED';box(c);c.strokes=[paint('color/border')];c.strokeWeight=1;
        if(def.name==='Card'){
          c.fills=[paint(state==='Pressed'||state==='Selected'?'color/primary-light':state==='Disabled'?'color/disabled':'color/card')];
          if(state==='Selected'){c.strokes=[paint('color/primary')];c.strokeWeight=2;}
          const title=await text(c,'Mã môn · Tên môn','FLM/Section');expose(c,title,'Title','Mã môn · Tên môn');
          const body=await text(c,'Tín chỉ và tiên quyết lấy từ danh mục FLM.','FLM/Body','color/text-muted');expose(c,body,'Description','Tín chỉ và tiên quyết lấy từ danh mục FLM.');
          await text(c,state==='Disabled'?'Chưa có dữ liệu · chưa thể mở':state==='Selected'?'Đang chọn · xem chi tiết':'Xem điều kiện môn học','FLM/Label',state==='Disabled'?'color/text-muted':'color/primary');
        } else if(def.name==='Navigation'){
          c.layoutMode='HORIZONTAL';c.resize(360,80);c.primaryAxisSizingMode='FIXED';c.counterAxisSizingMode='FIXED';for(const p of ['paddingTop','paddingBottom','paddingLeft','paddingRight','itemSpacing']){c.setBoundVariable(p,null);c[p]=0;}c.strokes=[];
          const names=['Trang chủ','Lộ trình','Trợ lý','Bảng điểm','Cài đặt'], icons=['house','route','bot','clipboard-list','settings'];
          for(let i=0;i<5;i++){const selected=def.states[i]===state;const item=auto(c,'VERTICAL',72);item.resize(72,80);item.primaryAxisSizingMode='FIXED';item.counterAxisSizingMode='FIXED';item.primaryAxisAlignItems='CENTER';item.counterAxisAlignItems='CENTER';item.itemSpacing=4;item.name='Destination/'+def.states[i];const pill=auto(item,'HORIZONTAL',48,selected?'color/primary-light':null);pill.resize(48,32);pill.primaryAxisSizingMode='FIXED';pill.counterAxisSizingMode='FIXED';pill.primaryAxisAlignItems='CENTER';pill.counterAxisAlignItems='CENTER';pill.cornerRadius=16;icon(pill,icons[i],selected?'color/primary':'color/text-muted');const t=await text(item,names[i],'FLM/Body',selected?'color/primary':'color/text-muted',72);t.textAlignHorizontal='CENTER';}
        } else if(def.name==='App bar'){
          c.layoutMode='HORIZONTAL';c.resize(360,64);c.primaryAxisSizingMode='FIXED';c.counterAxisSizingMode='FIXED';c.counterAxisAlignItems='CENTER';for(const p of ['paddingLeft','paddingRight']){c.setBoundVariable(p,null);c[p]=8;}for(const p of ['paddingTop','paddingBottom']){c.setBoundVariable(p,null);c[p]=8;}c.strokes=[];
          if(state==='Back'){const target=auto(c,'HORIZONTAL',48);target.resize(48,48);target.primaryAxisSizingMode='FIXED';target.counterAxisSizingMode='FIXED';target.primaryAxisAlignItems='CENTER';target.counterAxisAlignItems='CENTER';target.name='Back / 48dp';icon(target,'arrow-left','color/text');}
          const title=await text(c,state==='Back'?'Chi tiết môn học':'Cố vấn học tập FLM','FLM/Section','color/text',state==='Back'?232:288);expose(c,title,'Title',title.characters);title.layoutSizingHorizontal='FILL';
          const target=auto(c,'HORIZONTAL',48);target.resize(48,48);target.primaryAxisSizingMode='FIXED';target.counterAxisSizingMode='FIXED';target.primaryAxisAlignItems='CENTER';target.counterAxisAlignItems='CENTER';target.name='More / 48dp';icon(target,'ellipsis','color/text');
        } else if(def.name==='Dialog'){
          const title=await text(c,state==='Confirm'?'Xóa bảng điểm?':'Chưa lưu được','FLM/Section','color/text',288);expose(c,title,'Title',title.characters);
          const body=await text(c,state==='Confirm'?'Dữ liệu đã lưu trên thiết bị sẽ bị xóa. Bạn có muốn tiếp tục?':'Kiểm tra dữ liệu đã nhập rồi thử lưu lại. Thay đổi của bạn vẫn còn trong biểu mẫu.','FLM/Body','color/text-muted',288);expose(c,body,'Message',body.characters);
          const row=auto(c,'HORIZONTAL',288);row.itemSpacing=8;await action(row,state==='Confirm'?'Hủy':'Quay lại',true);const confirm=await action(row,state==='Confirm'?'Xóa':'Thử lại');confirm.resize(136,48);confirm.findOne(n=>n.type==='TEXT').resize(104,20);
        } else if(def.name==='Loading'){
          if(state==='Inline'){c.layoutMode='HORIZONTAL';c.counterAxisAlignItems='CENTER';c.resize(360,56);c.primaryAxisSizingMode='FIXED';c.counterAxisSizingMode='FIXED';}else{c.counterAxisAlignItems='CENTER';c.paddingTop=24;c.paddingBottom=24;}
          const ring=track(figma.createEllipse());ring.name='Progress indicator';ring.resize(24,24);ring.fills=[];ring.strokes=[paint('color/primary')];ring.strokeWeight=3;ring.arcData={startingAngle:0,endingAngle:Math.PI*1.5,innerRadius:0};c.appendChild(ring);
          const t=await text(c,'Đang tải dữ liệu…','FLM/Body','color/text-muted',state==='Inline'?296:328);if(state==='Screen')t.textAlignHorizontal='CENTER';
        } else {
          icon(c,def.name==='Empty'?(state==='Search'?'search':'file-text'):'circle-alert',def.name==='Empty'?'color/primary':'color/error',32);
          let title,body,primary,secondary;
          if(def.name==='Empty'){title=state==='Search'?'Không tìm thấy môn':'Chưa có bảng điểm';body=state==='Search'?'Thử mã môn khác hoặc xóa bộ lọc để xem lại danh sách.':'Nhập kết quả để xem GPA. Bạn có thể bắt đầu bằng nhập tay.';primary=state==='Search'?'Xóa bộ lọc':'Nhập tay';}
          else {title=state==='Network'?'Không thể kết nối':state==='Quota'?'AI đang giới hạn yêu cầu':'Chưa đọc được ảnh';body=state==='Network'?'Kiểm tra mạng rồi thử lại. Nội dung bạn nhập vẫn được giữ.':state==='Quota'?'Thử lại sau ít phút hoặc quay lại xem dữ liệu môn học.':'Chọn ảnh rõ hơn để thử lại, hoặc nhập kết quả bằng tay.';primary=state==='Import'?'Chọn lại ảnh':'Thử lại';secondary=state==='Import'?'Nhập tay':'Quay lại';}
          const t=await text(c,title,'FLM/Section');expose(c,t,'Title',title);const b=await text(c,body,'FLM/Body','color/text-muted');expose(c,b,'Message',body);
          const row=auto(c,'HORIZONTAL',328);const a=await action(row,primary);const visible=c.addComponentProperty('Show action','BOOLEAN',true);a.componentPropertyReferences={visible};if(secondary)await action(row,secondary,true);
        }
        components.push(c);
      }
      const set=track(figma.combineAsVariants(components,source));set.name='FLM/'+def.name;set.description=def.description;set.layoutMode='NONE';set.fills=[];set.strokes=[paint('color/border')];set.strokeWeight=1;
      const gap=24, maxH=Math.max(...components.map(n=>n.height));components.forEach((n,i)=>{n.x=24+(i%2)*(def.width+gap);n.y=24+Math.floor(i/2)*(maxH+gap);});set.resize(48+def.width*2+gap,48+Math.ceil(components.length/2)*(maxH+gap)-gap);set.x=24;set.y=sourceY;sourceY+=set.height+48;sets.push(set);
      const group=auto(review,'VERTICAL',1112);group.name='Review/'+def.name;await text(group,def.name,'FLM/Section','color/text',1112);
      let row;
      for(let i=0;i<components.length;i++){if(i%2===0){row=auto(group,'HORIZONTAL',1112);row.itemSpacing=24;}const cell=auto(row,'VERTICAL',544);await text(cell,components[i].name,'FLM/Label','color/text-muted',544);const inst=track(components[i].createInstance());created.push(...inst.findAll().map(n=>n.id));cell.appendChild(inst);}
      families.push({name:def.name,setId:set.id,reviewId:group.id,variants:components.map(c=>({id:c.id,name:c.name,width:c.width,height:c.height}))});
    }
    source.resizeWithoutConstraints(1200,sourceY+24);
    figma.currentPage.selection=[review];figma.viewport.scrollAndZoomIntoView([review]);
    return {status:'created',createdNodeIds:created,mutatedNodeIds:mutated,reviewId:review.id,sourceId:source.id,families,variantCount:families.reduce((a,f)=>a+f.variants.length,0),legacy:'Existing placeholders retained; migrate instances after visual review.'};
  } catch(e) {
    for(const r of roots.reverse())if(!r.removed)r.remove();throw e;
  }
}

buildSeven().then(async receipt=>{
  const previews=[];
  receipt.exportErrors=[];
  for(const f of receipt.families){try{const n=await figma.getNodeByIdAsync(f.reviewId);previews.push({name:f.name,png:figma.base64Encode(await n.exportAsync({format:'PNG',constraint:{type:'SCALE',value:1}}))});}catch(e){receipt.exportErrors.push({family:f.name,message:e.message});}}
  const json=JSON.stringify(receipt,null,2);
  figma.showUI('<html><body style="font:14px system-ui;padding:16px"><h2>FLM component build completed</h2><p>Seven component families created. Inspect these real Figma exports before marking QA passed.</p><button id="save">Download receipt</button><div id="previews"></div><details><summary>Receipt</summary><pre id="receipt" style="white-space:pre-wrap"></pre></details><script>const receipt='+JSON.stringify(json)+';const previews='+JSON.stringify(previews)+';document.getElementById("receipt").textContent=receipt;document.getElementById("save").onclick=()=>{const a=document.createElement("a");a.href=URL.createObjectURL(new Blob([receipt],{type:"application/json"}));a.download="figma-seven-components-receipt.json";a.click();};for(const p of previews){const h=document.createElement("h3");h.textContent=p.name;const a=document.createElement("a");a.textContent="Download PNG";a.download="figma-"+p.name.replaceAll(" ","-")+".png";a.href="data:image/png;base64,"+p.png;const image=document.createElement("img");image.src=a.href;image.style.width="100%";document.getElementById("previews").append(h,a,image);}</script></body></html>',{width:600,height:700});
}).catch(e=>figma.closePlugin('FLM build stopped: '+e.message));
