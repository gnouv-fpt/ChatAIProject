"""Extract the 115 sa-hinh source questions without modifying their images."""
import argparse
import hashlib
import io
import json
import re
import sys
import tempfile
import unicodedata
from pathlib import Path

sys.path.insert(0, str(Path(tempfile.gettempdir()) / 'prn_pdf_tools'))
import pymupdf as fitz
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'content-animations' / 'bank-review'
REPORT = ROOT / 'output' / 'animation-review'
SOURCE = 'https://khodulieu.sohoa.tuyenquang.gov.vn/congthongtin/media/edb12a6ad8ecfde537ec02cbb7e2a1b1.pdf'

def clean(text):
    return re.sub(r'\s+', ' ', unicodedata.normalize('NFC', text)).strip()

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('pdf', type=Path)
    args = parser.parse_args()
    doc = fitz.open(args.pdf)
    OUT.mkdir(parents=True, exist_ok=True)
    REPORT.mkdir(parents=True, exist_ok=True)
    pages = []
    starts = []
    for index, page in enumerate(doc):
        lines = []
        for block in page.get_text('dict')['blocks']:
            if block['type'] != 0:
                continue
            for line in block['lines']:
                text = clean(''.join(s['text'] for s in line['spans']))
                if not text:
                    continue
                item = dict(text=text, bbox=list(line['bbox']), baseline=line['spans'][0]['origin'][1])
                lines.append(item)
                match = re.match(r'^Câu\s+(\d+)\s*[.:]', text)
                if match:
                    starts.append(dict(number=int(match[1]), page=index, y=line['bbox'][1]))
        pages.append(dict(lines=sorted(lines,key=lambda l:(l['bbox'][1],l['bbox'][0])), images=page.get_image_info(xrefs=True), drawings=page.get_drawings()))
    starts.sort(key=lambda item:(item['page'],item['y']))
    questions = []
    warnings = []
    for start_index, start in enumerate(starts):
        n = start['number']
        if not 486 <= n <= 600:
            continue
        end = starts[start_index+1] if start_index+1 < len(starts) else dict(page=len(doc)-1,y=doc[-1].rect.height-35)
        folder = OUT / str(n)
        folder.mkdir(exist_ok=True)
        lines, images, underlines, snippets = [], [], [], []
        for p in range(start['page'],end['page']+1):
            top = start['y']-1 if p == start['page'] else 40
            bottom = end['y']-3 if p == end['page'] else doc[p].rect.height-40
            if bottom <= top:
                continue
            for line in pages[p]['lines']:
                if top <= line['bbox'][1] < bottom and not re.fullmatch(r'\d+', line['text']):
                    lines.append({**line,'page':p})
            for img in pages[p]['images']:
                if top <= img['bbox'][1] < bottom and img['width'] > 60:
                    images.append({**img,'page':p})
            for drawing in pages[p]['drawings']:
                rect=drawing['rect']
                if top <= rect.y0 < bottom and rect.height<2 and rect.width>10:
                    underlines.append(dict(page=p,rect=list(rect)))
            clip=fitz.Rect(76,top,552,bottom)
            pix=doc[p].get_pixmap(matrix=fitz.Matrix(1.65,1.65),clip=clip)
            snippets.append(Image.open(io.BytesIO(pix.tobytes('png'))).convert('RGB'))
        merged=Image.new('RGB',(max(s.width for s in snippets),sum(s.height for s in snippets)), 'white')
        cursor=0
        for snippet in snippets:
            merged.paste(snippet,(0,cursor));cursor+=snippet.height
        merged.save(folder/'question.webp','WEBP',quality=92)
        image_entries=[]
        for i,img in enumerate(images):
            data=doc.extract_image(img['xref'])
            filename=f'image-{i+1}.{data["ext"]}'
            (folder/filename).write_bytes(data['image'])
            image_entries.append(dict(url=f'bank-review/{n}/{filename}',width=img['width'],height=img['height'],pdfPage=img['page']+1,pdfBBox=list(img['bbox']),sha256=hashlib.sha256(data['image']).hexdigest()))
        prompt=[];options=[];current=None
        for line in lines:
            text=line['text']
            text=re.sub(r'^Câu\s+\d+\s*[.:]\s*','',text)
            match=re.match(r'^([1-4])\.\s*(.*)',text)
            if match:
                current=dict(id=int(match[1]),text=match[2],underlined=False)
                options.append(current)
            elif current:
                current['text']=clean(current['text']+' '+text)
            else:
                prompt.append(text)
            if current:
                for underline in underlines:
                    x0,y0,x1,y1=underline['rect']
                    if underline['page']==line['page'] and -0.7 <= y0-line['baseline'] <= 3.3 and min(x1,line['bbox'][2])-max(x0,line['bbox'][0])>10:
                        current['underlined']=True
        correct=[option['id'] for option in options if option['underlined']]
        if len(correct)!=1 or not 2<=len(options)<=4 or not images:
            warnings.append(dict(number=n,correct=correct,optionCount=len(options),images=len(images)))
        questions.append(dict(number=n,prompt=clean(' '.join(prompt)),options=options,correctOptionIds=correct,images=image_entries,sourceQuestionUrl=f'bank-review/{n}/question.webp',sourceUrl=f'{SOURCE}#page={start["page"]+1}',pdfPage=start['page']+1,status='draft'))
    assert [q['number'] for q in questions] == list(range(486,601)), 'Question range is incomplete or duplicated'
    manifest=dict(id='csgt-600-2025-sa-hinh-review-v1',title='115 câu sa hình · Bản nháp để duyệt',sourceUrl=SOURCE,sourceSha256=hashlib.sha256(args.pdf.read_bytes()).hexdigest(),questions=questions)
    (OUT/'bank.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    (REPORT/'extraction-report.json').write_text(json.dumps(dict(count=len(questions),warnings=warnings),ensure_ascii=False,indent=2),encoding='utf-8')
    (REPORT/'question-summary.txt').write_text('\n'.join(f'{q["number"]}: {q["prompt"]}\n  Đáp án {q["correctOptionIds"]}: '+ ' | '.join(f'{o["id"]}. {o["text"]}' for o in q['options']) for q in questions),encoding='utf-8')
    font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',16)
    small=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',13)
    for offset in range(0,len(questions),20):
        sheet=Image.new('RGB',(1400,1200),'#eff2ec');draw=ImageDraw.Draw(sheet)
        for i,q in enumerate(questions[offset:offset+20]):
            x=(i%4)*350;y=(i//4)*240
            draw.text((x+8,y+6),f'Câu {q["number"]} · Đáp án {q["correctOptionIds"]}',font=font,fill='#183c31')
            if q['images']:
                im=Image.open(ROOT/'content-animations'/q['images'][0]['url']).convert('RGB');im.thumbnail((334,175));sheet.paste(im,(x+8,y+32))
            prompt=q['prompt']
            draw.text((x+8,y+210),prompt[:47],font=small,fill='#183c31')
        sheet.save(REPORT/f'contact-{offset//20+1}.jpg',quality=90)
    print(json.dumps(dict(count=len(questions),warnings=warnings),ensure_ascii=False))

if __name__ == '__main__':
    main()
