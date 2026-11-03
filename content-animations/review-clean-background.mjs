// The generated plate is exposed only inside authored vehicle silhouettes.
// The question's original pixels remain the reference everywhere else.
export function cleanPlateMask(background,width,height) {
  const points=polygon=>polygon.map(([x,y])=>`${x*width/100},${y*height/100}`).join(' ');
  const polygons=(background.regions||[]).map(p=>`<polygon points="${points(p)}"/>`).join('');
  const protectedPolygons=(background.protectedRegions||[]).map(p=>`<polygon points="${points(p)}"/>`).join('');
  const svg=`<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}"><defs><filter id="edge" x="-10%" y="-10%" width="120%" height="120%"><feGaussianBlur stdDeviation="0.65"/></filter><mask id="keep"><rect width="100%" height="100%" fill="white"/><g fill="black">${protectedPolygons}</g></mask></defs><g mask="url(#keep)"><g fill="white" filter="url(#edge)">${polygons}</g></g></svg>`;
  return `url("data:image/svg+xml,${encodeURIComponent(svg)}")`;
}

export class CleanBackground {
  constructor(host) {
    this.host=host;this.token=0;this.status='none';
    this.image=document.createElement('img');this.image.className='clean-background';
    this.image.alt='';this.image.setAttribute('aria-hidden','true');this.image.draggable=false;this.image.hidden=true;
  }
  reset(background,width,height) {
    this.token++;this.background=background;this.width=width;this.height=height;
    this.status=background?'pending':'none';this.image.hidden=true;this.image.removeAttribute('src');
    this.host.classList.remove('has-clean-background');
    this.image.style.maskImage=background?cleanPlateMask(background,width,height):'none';
    this.image.style.webkitMaskImage=this.image.style.maskImage;
  }
  async load() {
    if(!this.background||this.status==='ready')return;
    const token=++this.token;this.status='loading';
    const image=new Image();image.src=this.background.url;
    try {
      await image.decode();if(token!==this.token)return;
      if(image.naturalWidth!==this.width||image.naturalHeight!==this.height)throw new Error('Sai kích thước nền');
      this.image.src=image.src;await this.image.decode();if(token!==this.token)return;
      this.status='ready';
    } catch {if(token===this.token)this.status='error';}
  }
  show(mode) {
    const visible=mode==='3d'&&this.status==='ready';
    this.image.hidden=!visible;this.host.classList.toggle('has-clean-background',visible);
  }
}
