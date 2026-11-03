"""Validate imagegen plates and publish metadata for masked CSS compositing.

No inpainting here. Bounds are measured from initial GLB poses by
output/playwright/collect-cleanplate-bounds.cjs; manual silhouettes override them.
"""
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
SITE=ROOT/'content-animations'
WORK=ROOT/'output/animation-cleanplates'
DEST=SITE/'clean-plates'
bank=json.loads((SITE/'bank-review/bank.json').read_text(encoding='utf8'))
bounds=json.loads((WORK/'model-bounds.json').read_text(encoding='utf8'))
scenes=json.loads((SITE/'bank-review/scenes.json').read_text(encoding='utf8'))['scenes']
overrides_path=DEST/'mask-overrides.json'
overrides=json.loads(overrides_path.read_text(encoding='utf8')) if overrides_path.exists() else {}
questions={q['number']:q for q in bank['questions']}
manifest={'version':1,'sourceSha256':bank['sourceSha256'],'questions':{}}
prompts={}
for file in sorted(WORK.glob('job-*.json')):
    job=json.loads(file.read_text(encoding='utf8'))
    if job['status']!='generated':continue
    asset=SITE/job['url'];image=Image.open(asset)
    assert image.size==(job['width'],job['height']),job['number']
    assert hashlib.sha256(asset.read_bytes()).hexdigest()==job['sha256'],job['number']
    prompts[str(job['number'])]={'questions':job['questions'],'asset':job['url'],'method':job['method'],'prompt':job['prompt']}
    for n in job['questions']:
        source=questions[n]['images'][0]
        assert source['sha256']==job['sourceSha256']
        assert hashlib.sha256((SITE/source['url']).read_bytes()).hexdigest()==job['sourceSha256']
        regions=[]
        measured={a['id']:a for a in bounds[str(n)]}
        for actor in scenes[str(n)]['actors']:
            if actor['kind']=='marker':continue
            if actor.get('rect'):
                x,y,w,h=actor['rect'];left,top,right,bottom=x,y,x+w,y+h
            else:left,top,right,bottom=measured[actor['id']]['bounds']
            # Source art and GLB silhouettes differ; include rider and contact shadow.
            px=max(1.8,(right-left)*(.28 if actor.get('rect') else .45))
            # The source drawings exaggerate roofs/riders above their ground
            # anchor; GLB bounds alone otherwise leave the top half behind.
            py=max(2,(bottom-top)*(.15 if actor.get('rect') else .65))
            x1,y1=max(0,left-px),max(0,top-py)
            x2,y2=min(100,right+px),min(100,bottom+max(2,(bottom-top)*.28))
            regions.append([[round(x1,3),round(y1,3)],[round(x2,3),round(y1,3)],[round(x2,3),round(y2,3)],[round(x1,3),round(y2,3)]])
        override=overrides.get(str(n),{})
        if 'inherit' in override:override=overrides[override['inherit']]
        for x,y,w,h in override.get('extraRects',[]):
            regions.append([[x,y],[x+w,y],[x+w,y+h],[x,y+h]])
        manifest['questions'][str(n)]={
            'url':job['url'],'sha256':job['sha256'],'sourceSha256':job['sourceSha256'],
            'width':job['width'],'height':job['height'],'method':job['method'],'status':'draft',
            'regions':override.get('regions',regions),'protectedRegions':override.get('protectedRegions',[]),
        }
DEST.mkdir(exist_ok=True)
(DEST/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf8')
(WORK/'prompts.json').write_text(json.dumps(prompts,ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps({'uniquePlates':len(prompts),'questions':len(manifest['questions']),'remaining':108-len(manifest['questions'])}))
