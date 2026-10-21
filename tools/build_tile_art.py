"""Build the native 32px TileMap atlas, using a repeatable dark organic palette.

These are individual editable game tiles, not an image of a level. Source art
spritelists from imagegen are normalized separately by assemble_art.py.
"""
from pathlib import Path
import math
import random
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "art"
OUT.mkdir(parents=True, exist_ok=True)
N = 32

def color(c, change):
    return tuple(max(0, min(255, int(v + change))) for v in c)

def terrain(kind, variant):
    rng = random.Random(1600 + kind * 87 + variant)
    bases = [(23, 43, 42), (39, 28, 41), (43, 46, 43), (22, 32, 35), (42, 23, 34)]
    base = bases[kind]
    im = Image.new("RGB", (N, N), base)
    p = im.load()
    # Periodic multiscale noise has no black or light rectangular tile border.
    a = rng.random()*6.28
    b = rng.random()*6.28
    for y in range(N):
        for x in range(N):
            n = (math.sin(x*math.tau/N+a)*math.cos(y*math.tau/N+b)*2.8 +
                 math.sin((x+y)*math.tau*3/N)*1.5 + rng.choice([-2, -1, 0, 0, 1, 2]))
            p[x,y] = color(base, n)
    d = ImageDraw.Draw(im)
    def line(points, fill, width=1):
        for ox in (-N,0,N):
            for oy in (-N,0,N):
                d.line([(x+ox,y+oy) for x,y in points], fill=fill, width=width)
    if kind == 0:  # compact moss, slate chips, tiny alien spores
        for _ in range(50):
            x,y=rng.randrange(N),rng.randrange(N)
            tone=rng.choice([(31,57,49),(36,62,54),(29,51,48),(17,34,36),(45,65,58)])
            d.line((x,y,x+rng.randrange(1,4),y),fill=tone)
            if rng.random()<.3: d.point((x,y-1),fill=color(tone,4))
        for _ in range(4):
            x,y=rng.randrange(N),rng.randrange(N)
            pts=[(x,y),(x+3,y+2),(x+1,y+4),(x-2,y+3)]
            d.polygon(pts,fill=(27,39,41)); d.line(pts[:2],fill=(48,65,63))
        if variant in (2,5):
            line([(0,22),(5,23),(8,20),(15,21),(19,17),(25,18),(32,22)],(12,27,29))
            line([(1,23),(5,24),(9,21),(15,22)],(40,58,52))
        if variant in (3,7):
            for _ in range(3):
                x,y=rng.randrange(3,29),rng.randrange(3,29)
                d.point((x,y),fill=(57,116,105));d.point((x-1,y),fill=(32,68,61))
    elif kind == 1:  # quiet maroon tissue; large arteries belong to the level
        # Small overlapping chitin/tissue facets avoid an aligned decorative
        # motif at every 32px tile boundary. All marks wrap and stay subdued.
        for _ in range(19):
            x,y=rng.randrange(N),rng.randrange(N)
            w,h=rng.randrange(3,9),rng.randrange(2,6)
            tone=rng.choice([(43,29,40),(46,30,42),(35,25,37),(40,28,39),(48,32,43)])
            pts=[(x,y),(x+w//2,y-1),(x+w,y+1),(x+w-1,y+h),(x+1,y+h-1)]
            for ox in (-N,0,N):
                for oy in (-N,0,N):
                    d.polygon([(xx+ox,yy+oy) for xx,yy in pts],fill=tone)
                    d.line([(x+1+ox,y+oy),(x+w//2+ox,y+oy)],fill=color(tone,4))
        # Sparse hairline cracks are small and point in varied directions.
        for _ in range(5):
            x,y=rng.randrange(N),rng.randrange(N)
            dx,dy=rng.choice([(3,5),(-4,3),(5,1),(1,-5),(-3,-4)])
            points=[(x,y),(x+dx//2,y+dy//2),(x+dx,y+dy),(x+dx+1,y+dy+2)]
            line(points,(25,21,31))
            if rng.random()<.4:
                line([(x+dx//2,y+dy//2),(x+dx//2-2,y+dy//2+1)],(27,22,32))
        for _ in range(35):
            x,y=rng.randrange(N),rng.randrange(N)
            d.point((x,y),fill=rng.choice([(46,31,42),(36,26,37),(50,33,43),(31,24,35)]))
        if variant==4:
            d.point((22,7),fill=(77,39,51));d.point((23,7),fill=(58,32,45))
        if variant==5:
            d.point((7,23),fill=(39,65,68));d.point((8,23),fill=(31,47,53))
    elif kind == 2:  # trodden alien dirt and muted chips
        for _ in range(70):
            x,y=rng.randrange(N),rng.randrange(N)
            c=rng.choice([(51,54,47),(36,41,39),(57,58,48),(40,44,41)])
            d.line((x,y,x+rng.randrange(1,4),y), fill=c)
        line([(0,9),(7,12),(13,10),(17,15),(24,16),(32,9)],(28,33,34))
        line([(13,10),(13,4),(17,0)],(31,36,35))
        if variant==3:
            for _ in range(14):
                x,y=rng.randrange(N),rng.randrange(N)
                d.line((x,y,x+3,y),fill=(34,53,44))
    elif kind == 3:  # forest boundary rock, top-down slab with chipped rim
        d.polygon([(0,2),(9,0),(21,2),(31,0),(31,30),(24,31),(13,29),(1,31)],fill=(25,37,40))
        for i in range(4):
            x=i*8
            d.polygon([(x,3),(x+5,1),(x+9,8),(x+7,21),(x+2,30),(x-1,18)],fill=color((33,47,49),rng.randrange(-4,5)))
            d.line((x,4,x+4,3,x+7,9),fill=(52,70,68))
            d.line((x+1,19,x+4,27),fill=(17,26,30),width=2)
        for _ in range(8):
            x,y=rng.randrange(N),rng.randrange(N)
            d.line((x,y,x+2,y),fill=(28,55,43))
    else:  # black-burgundy ribbed organic ship wall
        d.rectangle((0,0,31,31),fill=(21,17,29))
        for i in range(-1,4):
            x=i*11 + (variant%2)*3
            pts=[(x-2,0),(x+3,9),(x+4,18),(x+1,31)]
            line(pts,(9,13,23),9);line(pts,(66,31,47),7)
            line([(x-1,0),(x+4,9),(x+5,18),(x+2,31)],(107,45,59),2)
            line([(x-3,1),(x+1,10),(x+2,18),(x-1,31)],(38,24,38),2)
        if variant%2:
            d.ellipse((11,12,17,19),fill=(43,22,35));d.ellipse((12,13,16,18),fill=(128,47,48))
            d.point((14,14),fill=(223,108,62))
    return im.convert("RGBA")

atlas = Image.new("RGBA",(256,96))
for col in range(8): atlas.alpha_composite(terrain(0,col),(col*32,0))
for col in range(6): atlas.alpha_composite(terrain(1,col),(col*32,32))
for col in range(6,8): atlas.alpha_composite(terrain(4,col),(col*32,32))
for col in range(4): atlas.alpha_composite(terrain(2,col),(col*32,64))
for col in range(4,6): atlas.alpha_composite(terrain(3,col),(col*32,64))
for col in range(6,8): atlas.alpha_composite(terrain(4,col+2),(col*32,64))
atlas.save(OUT / "tiles.png")
atlas.resize((1024,384),Image.Resampling.NEAREST).save(OUT / "tiles_preview.png")
print("TILE_ART_OK", OUT / "tiles.png", atlas.size)
