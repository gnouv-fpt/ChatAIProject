import urllib.request,re,json,hashlib,concurrent.futures,struct
from pathlib import Path
root=Path('content-animations/models');base='https://www.innerscene.com'
items={'box-truck':'7-5-t-class-box-truck-with-roll-up-door-12baea66','city-bus':'12-m-low-floor-city-bus-8e3c7229','delivery-van':'high-roof-cargo-panel-van-c4d5145f','ambulance':'box-body-ambulance-dc8d7b19','fire-engine':'fire-engine-pumper-ad69949b','military-truck':'generic-1940s-2-5-t-cargo-truck-6e78cb4a','semi-trailer':'semi-tractor-and-box-trailer-bc0bdac8','city-bicycle':'city-bicycle-58a2a324','locomotive':'small-diesel-shunting-locomotive-d53d1994'}
def fetch(url):return urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0'}),timeout=90)
def get(item):
 name,slug=item;url=base+'/tools/library/3d-parts/'+slug
 s=fetch(url).read().decode();part=json.loads(re.search(r'<script id="__NEXT_DATA__"[^>]*>(.*?)</script>',s,re.S)[1])['props']['pageProps']['part'];assert part['license']=='CC0-1.0'
 href=next(x for x in re.findall(r'href="([^"]+)"',s) if '/download' in x and '/api/library/' in x)
 with fetch(base+href) as r: content=r.read();download=r.url
 # The download adds CC0 copyright metadata to the original upload, so its
 # bytes/hash differ from the upload's fileHash. Verify the delivered GLB itself.
 assert content[:4]==b'glTF' and struct.unpack_from('<I',content,8)[0]==len(content)
 header=json.loads(content[20:20+struct.unpack_from('<I',content,12)[0]])
 assert 'CC0' in header['asset'].get('copyright',''),name
 digest=hashlib.sha256(content).hexdigest()
 (root/(name+'.glb')).write_bytes(content)
 print(name,len(content),'CC0',flush=True)
 return dict(name=name,file=name+'.glb',source=url,download=download,sha256=digest,bytes=len(content),license=part['license'],description=part['description'])
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:manifest=list(pool.map(get,items.items()))
(root/'vehicles-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf8')
