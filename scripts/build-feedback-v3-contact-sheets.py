"""Compose source and real browser captures for the 01-Nov feedback round."""
import json
import textwrap
from pathlib import Path
from PIL import Image,ImageOps,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[1]
folder=ROOT/'output/playwright/feedback-v3'
data=json.loads((ROOT/'output/animation-review/v3-desktop-final.json').read_text(encoding='utf-8-sig'))
scenes=json.loads((ROOT/'content-animations/bank-review/scenes.json').read_text(encoding='utf8'))['scenes']
feedback=json.loads((ROOT/'content-animations/bank-review/review-feedback-v3-input.json').read_text(encoding='utf8'))
notes={r['number']:r['notes'] for r in feedback['records']}
font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',14)
def paste(canvas,path,x,y,w,h):
    im=ImageOps.contain(Image.open(path).convert('RGB'),(w,h));canvas.paste(im,(x+(w-im.width)//2,y+(h-im.height)//2))
for r in data['records']:
    n=r['number'];count=len(r['times'])+1;sheet=Image.new('RGB',(1840,300*((count+3)//4)),'#f1f4ed');d=ImageDraw.Draw(sheet)
    for i in range(count):
        x=i%4*460;y=i//4*300
        path=folder/f'q{n}-source.png' if i==0 else folder/f'q{n}-{i-1}.png'
        paste(sheet,path,x,y+26,452,270)
        d.text((x+6,y+4),f'Q{n} '+('source' if i==0 else f"t={r['times'][i-1]:.2f}s"),font=font,fill='#19372c')
    sheet.save(folder/f'question-{n}.jpg',quality=94)
for first in range(0,len(data['records']),6):
    rows=data['records'][first:first+6];sheet=Image.new('RGB',(2000,len(rows)*285),'#f1f4ed');d=ImageDraw.Draw(sheet)
    for row,r in enumerate(rows):
        n=r['number'];s=scenes[str(n)];moves=[i+1 for i,st in enumerate(s['steps']) if any(a['action']=='move' for a in st['actions'])]
        indices=['source',0,moves[0] if moves else 1,moves[-1] if moves else len(r['times'])-2,len(r['times'])-1]
        d.text((8,row*285+2),(f'Q{n}: '+notes[n].replace('\n',' / '))[:220],font=font,fill='#19372c')
        for col,index in enumerate(indices):paste(sheet,folder/f'q{n}-{index}.png',col*400,row*285+28,394,252)
    sheet.save(folder/f'overview-{first//6:02}.jpg',quality=94)
continuous=ROOT/'output/animation-review/v3-continuous.json'
if continuous.exists() and continuous.stat().st_size>3:
    for r in json.loads(continuous.read_text(encoding='utf-8-sig'))['records']:
        sheet=Image.new('RGB',(1840,300*((len(r['frames'])+3)//4)),'#f1f4ed');d=ImageDraw.Draw(sheet)
        for i,f in enumerate(r['frames']):
            x=i%4*460;y=i//4*300;paste(sheet,folder/f"continuous-q{r['number']}-{i}.png",x,y+26,452,270);d.text((x+5,y+4),f"Q{r['number']} playing {f['actual']:.2f}s",font=font,fill='#19372c')
        sheet.save(folder/f"continuous-q{r['number']}.jpg",quality=94)
print('Contact sheets for',len(data['records']),'reviewed candidates')
