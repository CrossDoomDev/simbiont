from pathlib import Path
import json
import fitz
from PIL import Image, ImageOps, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'docs' / 'Симбионт-GDD.pdf'
OUT = ROOT / 'docs' / 'references'
OUT.mkdir(parents=True, exist_ok=True)
doc = fitz.open(SOURCE)
texts, images, thumbs = [], [], []
for index, page in enumerate(doc):
    texts.append(f'\n\n=== PAGE {index + 1} ===\n\n{page.get_text()}')
    pix = page.get_pixmap(matrix=fitz.Matrix(1.5, 1.5))
    page_file = OUT / f'page_{index + 1:02d}.png'
    pix.save(page_file)
    im = Image.open(page_file).convert('RGB')
    im.thumbnail((310, 430))
    thumb = Image.new('RGB', (330, 460), '#dddcd7')
    thumb.paste(im, ((330-im.width)//2, 10))
    ImageDraw.Draw(thumb).text((12,440), f'PAGE {index+1}', fill='black')
    thumbs.append(thumb)
    for n, data in enumerate(page.get_images(full=True)):
        image_data = doc.extract_image(data[0])
        name = f'ref_p{index + 1:02d}_{n:02d}.{image_data["ext"]}'
        (OUT / name).write_bytes(image_data['image'])
        images.append({'page':index+1,'file':name,'width':image_data['width'],'height':image_data['height']})
(ROOT / 'docs' / 'gdd_text.txt').write_text(''.join(texts), encoding='utf-8')
(OUT / 'index.json').write_text(json.dumps(images,ensure_ascii=False,indent=2),encoding='utf-8')
for batch in range(0,len(thumbs),12):
    group=thumbs[batch:batch+12]
    sheet=Image.new('RGB',(330*4,460*((len(group)+3)//4)),'#b8b8b8')
    for i,thumb in enumerate(group): sheet.paste(thumb,((i%4)*330,(i//4)*460))
    sheet.save(OUT / f'contact_{batch//12+1:02d}.jpg')
print(json.dumps({'pages':len(doc),'images':images},ensure_ascii=False,indent=2))
