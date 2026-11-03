"""Build labelled QA contact sheets from real browser screenshots only."""
import json,sys,textwrap
from pathlib import Path
from PIL import Image,ImageOps,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[1]
stage=sys.argv[1] if len(sys.argv)>1 else 'before'
folder=ROOT/'output/playwright/feedback-full'/stage
scenes=json.loads((ROOT/'content-animations/bank-review/scenes.json').read_text(encoding='utf8'))['scenes']
audit_path=ROOT/f'output/animation-review/full-audit-{stage}.json'
audit=json.loads(audit_path.read_text(encoding='utf-8-sig')) if audit_path.exists() and audit_path.stat().st_size>3 else None
if audit:scenes={str(r['number']):r for r in audit['records']}
feedback=json.loads((ROOT/'output/animation-review/user-feedback-2026-10-31.json').read_text(encoding='utf8'))
notes={r['number']:r['notes'] for r in feedback['records']}
font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',15)
small=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',13)
available=[]
for n in range(486,601):
    s=scenes[str(n)];times=s.get('times')
    if times is None:
        times=[0];start=0
        for st in s['steps']:times.append(start+st['duration']/2);start+=st['duration']
        times.append(start-.01)
    paths=[folder/f'q{n}-source.png']+[folder/f'q{n}-{i}.png' for i in range(len(times))]
    if not all(p.exists() for p in paths):continue
    available.append(n)
    image=Image.new('RGB',(1840,300*((len(paths)+3)//4)),'#f4f5f2');draw=ImageDraw.Draw(image)
    for i,path in enumerate(paths):
        x=i%4*460;y=i//4*300
        tile=ImageOps.contain(Image.open(path).convert('RGB'),(452,270))
        image.paste(tile,(x+(460-tile.width)//2,y+26))
        draw.text((x+6,y+5),f'Q{n} - '+('source' if i==0 else f't={times[i-1]:.2f}s'),font=font,fill='#1d3128')
    image.save(folder/f'question-{n}.jpg',quality=94)
for first in range(486,601,6):
    nums=[n for n in range(first,min(first+6,601)) if n in available]
    if not nums:continue
    sheet=Image.new('RGB',(2000,285*len(nums)),'#f4f5f2');draw=ImageDraw.Draw(sheet)
    for row,n in enumerate(nums):
        s=scenes[str(n)];moves=[i+1 for i,st in enumerate(s['steps']) if any(a['action']=='move' for a in st['actions'])]
        count=len(s['steps'])+2
        indices=['source',0,moves[0] if moves else 1,moves[-1] if moves else max(1,count-3),count-1]
        line=f"Q{n}: "+(notes[n].replace('\n',' / ') or 'Đã được người dùng duyệt trước feedback')
        draw.text((8,row*285+2),line[:235],font=small,fill='#132e21')
        for col,index in enumerate(indices):
            path=folder/f'q{n}-{index}.png'
            tile=ImageOps.contain(Image.open(path).convert('RGB'),(392,240))
            sheet.paste(tile,(col*400+(400-tile.width)//2,row*285+42))
            draw.text((col*400+8,row*285+23),str(index),font=small,fill='#42594b')
    sheet.save(folder/f'overview-{first}-{min(first+5,600)}.jpg',quality=94)
print(stage,'complete questions',len(available),'last',available[-1] if available else None)
playback_path=ROOT/'output/animation-review/continuous-playback-audit.json'
if stage=='after' and playback_path.exists():
    target=folder.parent/'targeted'
    for r in json.loads(playback_path.read_text(encoding='utf-8-sig'))['records']:
        sheet=Image.new('RGB',(1840,300*((len(r['frames'])+3)//4)),'#f4f5f2');draw=ImageDraw.Draw(sheet)
        for i,f in enumerate(r['frames']):
            tile=ImageOps.contain(Image.open(target/f"continuous-q{r['number']}-t{f['requested']}.png").convert('RGB'),(452,270))
            x=i%4*460;y=i//4*300;sheet.paste(tile,(x+(460-tile.width)//2,y+26))
            draw.text((x+6,y+5),f"Q{r['number']} playing at {f['actual']:.2f}s",font=font,fill='#132e21')
        sheet.save(target/f"continuous-q{r['number']}.jpg",quality=94)
