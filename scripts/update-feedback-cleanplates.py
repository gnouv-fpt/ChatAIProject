"""Update masks against source annotations, retaining original background assets.

This only exports an imagegen result and updates polygon metadata. It does not
perform inpainting or edit the bank's immutable original images.
"""
import hashlib
import json
import math
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
SITE=ROOT/'content-animations'
manifest_path=SITE/'clean-plates/manifest.json'
manifest=json.loads(manifest_path.read_text(encoding='utf8'))
scenes=json.loads((SITE/'bank-review/scenes.json').read_text(encoding='utf8'))['scenes']
backup=ROOT/'output/animation-review/clean-manifest-before-feedback.json'
if not backup.exists():backup.write_bytes(manifest_path.read_bytes())
baseline=json.loads(backup.read_text(encoding='utf8'))
def rect_polygon(rect,pad=0):
    x,y,w,h=rect
    return [[max(0,x-pad),max(0,y-pad)],[min(100,x+w+pad),max(0,y-pad)],[min(100,x+w+pad),min(100,y+h+pad)],[max(0,x-pad),min(100,y+h+pad)]]

for number,bg in manifest['questions'].items():
    if scenes[number].get('motionVersion')!=2:continue
    if number not in baseline['questions']:continue
    bg['regions']=baseline['questions'][number]['regions'][:]
    bg['protectedRegions']=baseline['questions'][number]['protectedRegions'][:]
    for actor in scenes[number]['actors']:
        if actor.get('sourceRect'):bg['regions'].append(rect_polygon(actor['sourceRect'],.6))
        # Signal boards are evidence; do not erase them with a broad vehicle mask.
        if actor['kind']=='marker' and actor.get('rect') and any(word in actor['label'].lower() for word in ['biển','đèn tín hiệu','đèn đỏ','người điều khiển']):
            bg['protectedRegions'].append(rect_polygon(actor['rect'],.3))

# The small supplementary sign under the no-parking sign is absent in the
# generated plate. Preserve its exact original pixels, including the pole.
manifest['questions']['508']['protectedRegions'].append(rect_polygon([60,16,8,43],.3))
# Q513's old rectangular sign protection also restored part of the original
# car after the model moved away. Trace the two sign faces and their poles.
manifest['questions']['513']['protectedRegions']=[
    [[12.5,71.6],[16.1,70.8],[20.4,72.8],[23.8,78],[24.5,84.4],[22.9,88],[17.9,89.6],[13.6,87.2],[11.6,82.8],[11.1,77.2]],
    [[20,88],[21.2,88],[22.6,98.5],[21.4,98.5]],
    [[70.3,71.6],[73.9,70.8],[78.2,72.8],[81.6,78],[82.3,84.4],[80.7,88],[75.7,89.6],[71.4,87.2],[69.4,82.8],[68.9,77.2]],
    [[77.8,88],[79,88],[80.4,98.5],[79.2,98.5]],
]
manifest['questions']['561']['regions'].append(rect_polygon([60,15,19,17],.5))
# Keep only Q528's officer/staff, never the adjacent turquoise truck. The old
# marker box lay over the truck and exposed it again after the 3D model moved.
manifest['questions']['528']['protectedRegions']=[
    [[65,26],[65.7,26],[67.3,39],[66.8,39]],
    [[67.9,35.7],[69.8,35.7],[70.6,38],[70,40.5],[71,44],[70.7,49],[70,51],[70.2,57.5],[69.7,61],[68.2,61],[67.6,58],[67.3,51],[67.3,47],[66.7,45],[66.7,41],[67.4,40]],
]
# The old sign hotspot also punched the original Q558 car roof back through
# the clean plate. Keep the circular face and its thin pole, not the car below.
manifest['questions']['558']['protectedRegions']=[
    [[71.5+3.5*math.cos(i*math.tau/32),45+6*math.sin(i*math.tau/32)] for i in range(32)],
    rect_polygon([71,51,1,4]),
]
manifest['questions']['593']['regions'].append(rect_polygon([53,47,7,17],.5))
manifest['questions']['600']['regions'] += [rect_polygon([9,84,11,16],.5),rect_polygon([61,0,8,9],.5)]

generated=Path(r'C:\Users\LEGION\.codex\generated_images\01a18bdc-22c5-7693-8811-8d26e7940f7e\exec-8f80353c-8059-4db5-9f10-c0595101e401.png')
bg=manifest['questions']['573'];dest=SITE/'clean-plates/q573-v2.webp'
if generated.exists():
    im=Image.open(generated).convert('RGB')
    assert abs((im.width/im.height)/(bg['width']/bg['height'])-1)<.03
    im.resize((bg['width'],bg['height']),Image.Resampling.LANCZOS).save(dest,'WEBP',quality=95,method=6)
assert dest.exists()
bg['url']='clean-plates/q573-v2.webp';bg['sha256']=hashlib.sha256(dest.read_bytes()).hexdigest()
bg['regions'].append(rect_polygon([66,44,7,20],.4))
bg['editNote']='Remove only the white-shirt crossing pedestrian; preserve the sidewalk pedestrian, road, dashboard, crop and signs. Built-in imagegen edit.'
bank=json.loads((SITE/'bank-review/bank.json').read_text(encoding='utf8'))
source=next(q for q in bank['questions'] if q['number']==596)['images'][0]
gate_source=Path(r'C:\Users\LEGION\.codex\generated_images\01a18bdc-22c5-7693-8811-8d26e7940f7e\exec-87c79c19-97ac-4619-bf98-120bfc933f38.png')
gate_dest=SITE/'clean-plates/q596-v1.webp'
if gate_source.exists():
    im=Image.open(gate_source).convert('RGB')
    assert abs((im.width/im.height)/(source['width']/source['height'])-1)<.03
    im.resize((source['width'],source['height']),Image.Resampling.LANCZOS).save(gate_dest,'WEBP',quality=95,method=6)
assert gate_dest.exists()
manifest['questions']['596']=dict(url='clean-plates/q596-v1.webp',sha256=hashlib.sha256(gate_dest.read_bytes()).hexdigest(),sourceSha256=source['sha256'],width=source['width'],height=source['height'],method='imagegen-edit',status='draft',regions=[rect_polygon([20,53,58,15],.4),rect_polygon([42,48,8,22],.4)],protectedRegions=[],editNote='Remove only the moving white railway gate and crossing guard; preserve fixed sidewalk fences, road markings, signs and cabin. Built-in imagegen edit.')
manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf8')
print('Updated mask metadata; exported q573-v2.webp and q596-v1.webp')
