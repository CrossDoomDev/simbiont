"""Slice generated transparent source atlases into exact native Godot cells.

No missing game art is synthesized here. The full original generated PNGs stay
in assets/source; this step only crops, uniformly resizes and packs sprites.
"""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets" / "source"
OUT = ROOT / "assets" / "art"
OUT.mkdir(parents=True, exist_ok=True)

def clean_detached(cell):
    """Discard isolated fragments of a neighboring cell, preserving nearby sparks."""
    alpha=cell.getchannel("A")
    px=alpha.load()
    seen=set()
    groups=[]
    for y in range(cell.height):
        for x in range(cell.width):
            if (x,y) in seen or px[x,y]<20: continue
            todo=[(x,y)];seen.add((x,y));group=[]
            while todo:
                xx,yy=todo.pop();group.append((xx,yy))
                for nx,ny in ((xx-1,yy),(xx+1,yy),(xx,yy-1),(xx,yy+1),
                              (xx-1,yy-1),(xx+1,yy-1),(xx-1,yy+1),(xx+1,yy+1)):
                    if 0<=nx<cell.width and 0<=ny<cell.height and (nx,ny) not in seen and px[nx,ny]>=20:
                        seen.add((nx,ny));todo.append((nx,ny))
            groups.append(group)
    if not groups:return cell
    groups.sort(key=len,reverse=True)
    main=groups[0]
    mx0=min(p[0] for p in main);mx1=max(p[0] for p in main)
    my0=min(p[1] for p in main);my1=max(p[1] for p in main)
    keep=Image.new("L",cell.size)
    draw=ImageDraw.Draw(keep)
    for group in groups:
        x0=min(p[0] for p in group);x1=max(p[0] for p in group)
        y0=min(p[1] for p in group);y1=max(p[1] for p in group)
        gap=max(mx0-x1,x0-mx1,my0-y1,y0-my1,0)
        if gap<=18 and (group is main or len(group)>=max(24,len(main)*.025)):
            draw.rectangle((x0-2,y0-2,x1+2,y1+2),fill=255)
    # Preserve the original semitransparent edges within accepted bounds.
    from PIL import ImageChops
    cell.putalpha(ImageChops.multiply(alpha,keep))
    return cell

def source_cells(path, columns, rows, rowcuts=None):
    im = Image.open(SRC / path).convert("RGBA")
    cells=[]
    for y in range(rows):
        row=[]
        for x in range(columns):
            cell=im.crop((round(x*im.width/columns),rowcuts[y] if rowcuts else round(y*im.height/rows),
                          round((x+1)*im.width/columns),rowcuts[y+1] if rowcuts else round((y+1)*im.height/rows)))
            cell=clean_detached(cell)
            # Ignore practically invisible edge specks when centering an object.
            bbox=cell.getchannel("A").point(lambda a:255 if a>36 else 0).getbbox()
            row.append(cell.crop(bbox) if bbox else cell)
        cells.append(row)
    return cells

def fit(im, width, height):
    # Downscale with area resampling to retain shaded pixel clusters and alpha.
    factor=min(width/im.width,height/im.height)
    size=(max(1,round(im.width*factor)),max(1,round(im.height*factor)))
    return im.resize(size,Image.Resampling.LANCZOS)

def isolated_horizontal(path, cuts):
    im=Image.open(SRC / path).convert("RGBA")
    cells=[]
    for a,b in zip(cuts,cuts[1:]):
        crop=im.crop((a,0,b,im.height))
        box=crop.getchannel("A").point(lambda a:255 if a>36 else 0).getbbox()
        cells.append(crop.crop(box))
    return [cells]

def pack(cells, size, name, limits=None):
    sheet=Image.new("RGBA",(len(cells[0])*size,len(cells)*size))
    for y,row in enumerate(cells):
        for x,cell in enumerate(row):
            padding=limits[y] if limits else .88
            sprite=fit(cell,round(size*padding),round(size*padding))
            sheet.alpha_composite(sprite,(x*size+(size-sprite.width)//2,
                                          y*size+(size-sprite.height)//2))
    sheet.save(OUT / name)
    return sheet

def main():
    sheets={}
    if (SRC / "hero-generated.png").exists():
        cells=source_cells("hero-generated.png",4,4)
        original=Image.open(SRC / "hero-generated.png").convert("RGBA")
        # Up-attack glow projects into the regular grid gutter. Use measured
        # attack cell bounds instead of cutting that light into adjacent rows.
        for row,a,b in [(1,313,598),(2,628,895),(3,897,1254)]:
            attack=original.crop((941,a,1254,b))
            box=attack.getchannel("A").point(lambda a:255 if a>36 else 0).getbbox()
            cells[row][3]=attack.crop(box)
        # The generated left attack looked right. Reuse the correct right-facing
        # pose mirrored; retain the front-facing sprite for down attacks because
        # Godot renders the biopulse flash and projectile in the actual aim direction.
        cells[1][3]=ImageOps.mirror(cells[2][3])
        cells[0][3]=cells[0][0].copy()
        sheets["hero"]=pack(cells,64,"hero.png")
        sheets["hero"].save(OUT / "hero_base.png")
    if (SRC / "enemies-generated.png").exists():
        cells=source_cells("enemies-generated.png",4,4,[0,302,594,872,1254])
        pack(cells,64,"enemies_compact.png",[.80,.84,.82,.96])
        # Arthropods use one strictly overhead directional silhouette per species.
        # Four cardinal rotations preserve the anatomy and avoid mirrored lighting.
        # Idle / two gait phases / attack are explicit SpriteFrames atlas columns.
        expanded=[]
        for row in cells:
            base=row[0]
            frames=[base,base.rotate(-3,Image.Resampling.BICUBIC,expand=True),
                    base.rotate(3,Image.Resampling.BICUBIC,expand=True),base]
            for angle in (0,-90,90,180):
                expanded.append([f.rotate(angle,expand=True) for f in frames])
        pack(expanded,64,"enemies.png",[v for s in (.80,.84,.82,.96) for v in [s]*4])
        # Keep the contact sheet compact and show all the generated design poses.
        sheets["enemies_compact"]=Image.open(OUT / "enemies_compact.png").convert("RGBA")
    if (SRC / "organs-generated.png").exists():
        # The generator honored order but used unequal spacing. Measured alpha
        # silhouette gutters preserve all five roots without crossing cell edges.
        organs=isolated_horizontal("organs-generated.png",[0,345,725,1252,1687,1983])
        sheets["organs"]=pack(organs,128,"organs.png",[.95])
    if (SRC / "props-generated.png").exists():
        cells=source_cells("props-generated.png",4,3)
        sheets["props"]=pack([cells[0]+cells[1]],64,"props.png")
        sheets["resources"]=pack([cells[2]],32,"resources.png",[.82])
    if (SRC / "nest-generated.png").exists():
        nest=Image.open(SRC / "nest-generated.png").convert("RGBA")
        box=nest.getchannel("A").point(lambda a:255 if a>36 else 0).getbbox()
        sheets["nest"]=pack([[nest.crop(box)]],128,"nest.png",[.94])
    if (OUT / "tiles.png").exists(): sheets["tiles"]=Image.open(OUT / "tiles.png").convert("RGBA")
    if not sheets: return
    width=1360
    height=110+sum(im.height*2+72 for im in sheets.values())
    contact=Image.new("RGB",(width,height),(9,16,23))
    draw=ImageDraw.Draw(contact)
    font=ImageFont.truetype(str(ROOT / "assets" / "fonts" / "Manrope.ttf"),20)
    draw.text((24,18),"SYMBIONT / GAME ART / NATIVE ATLAS CELLS",font=font,fill=(196,226,226))
    y=64
    for key,im in sheets.items():
        preview=im.resize((im.width*2,im.height*2),Image.Resampling.NEAREST)
        draw.text((24,y),f"{key}.png  {im.width}x{im.height}",font=font,fill=(122,184,192))
        y+=32
        # Checkerboard helps inspect genuine transparent silhouettes.
        for yy in range(y,y+preview.height,16):
            for xx in range(24,min(width,24+preview.width),16):
                tone=(17,25,32) if ((xx//16+yy//16)%2) else (22,32,40)
                draw.rectangle((xx,yy,min(xx+15,24+preview.width),min(yy+15,y+preview.height)),fill=tone)
        contact.paste(preview,(24,y),preview)
        y+=preview.height+40
    contact.save(OUT / "contact_sheet.png")
    print("ART_PACK_OK", {k:v.size for k,v in sheets.items()})

if __name__=="__main__":main()
