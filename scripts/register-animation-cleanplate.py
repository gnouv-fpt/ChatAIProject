"""Export an imagegen result for the viewer; keep the original question immutable."""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--question',type=int,required=True)
parser.add_argument('--image',required=True)
parser.add_argument('--prompt',default='')
args=parser.parse_args()
jobs=json.loads((ROOT/'output/animation-cleanplates/jobs.json').read_text(encoding='utf8'))
job=next(j for j in jobs if j['number']==args.question)
source=Path(job['source']);assert hashlib.sha256(source.read_bytes()).hexdigest()==job['sourceSha256']
original=Image.open(source);plate=Image.open(args.image).convert('RGB')
ratio=(plate.width/plate.height)/(original.width/original.height)
if not .97<ratio<1.03:raise ValueError('Generated crop/aspect ratio differs from the question')
dest=ROOT/'content-animations/clean-plates';dest.mkdir(exist_ok=True)
asset=dest/f'q{args.question}-v1.webp'
# Export/downscale only. Object removal is performed by imagegen, not this script.
plate.resize(original.size,Image.Resampling.LANCZOS).save(asset,'WEBP',quality=95,method=6)
record={**job,'status':'generated','imagePath':str(Path(args.image).resolve()),'url':asset.relative_to(ROOT/'content-animations').as_posix(),
        'width':original.width,'height':original.height,'sha256':hashlib.sha256(asset.read_bytes()).hexdigest(),'bytes':asset.stat().st_size,
        'prompt':args.prompt,'method':'imagegen-edit'}
(ROOT/f'output/animation-cleanplates/job-{args.question}.json').write_text(json.dumps(record,ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps({'question':args.question,'questions':job['questions'],'url':record['url'],'bytes':record['bytes']}))
