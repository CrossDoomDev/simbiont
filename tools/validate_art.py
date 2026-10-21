"""Check native atlas dimensions, real alpha, and every gameplay sprite cell."""
from pathlib import Path
import json
from PIL import Image

art=Path(__file__).resolve().parents[1] / "assets" / "art"
manifest=json.loads((art / "manifest.json").read_text("utf-8"))
checked=0
for name,config in manifest["sheets"].items():
    im=Image.open(art/name)
    assert list(im.size)==config["size"],(name,im.size,config["size"])
    assert im.mode=="RGBA",(name,im.mode)
    if config.get("transparent", name != "tiles.png"): assert im.getchannel("A").getextrema()==(0,255),(name,"alpha")
    if "cell" in config:
        w,h=config["cell"]
        assert im.width%w==0 and im.height%h==0
        for y in range(im.height//h):
            for x in range(im.width//w):
                cell=im.crop((x*w,y*h,(x+1)*w,(y+1)*h))
                assert cell.getchannel("A").getbbox(),(name,"empty",x,y)
                checked+=1
    print(name,im.size,im.getchannel("A").getextrema())
print("ART_VALIDATION_OK",checked,"populated native atlas cells")

# Generated skill sheet uses 4 x 5 equal grid partitions, including odd edges.
skills=Image.open(art / "skills/effects.png").convert("RGBA")
assert skills.getchannel("A").getextrema()==(0,255), "skill effect alpha"
for row in range(5):
    previous=None
    for col in range(4):
        frame=skills.crop((col*skills.width//4,row*skills.height//5,(col+1)*skills.width//4,(row+1)*skills.height//5))
        assert frame.getchannel("A").getbbox(), ("empty skill frame",row,col)
        digest=frame.tobytes()
        assert previous != digest, ("duplicate skill animation frame",row,col)
        previous=digest
print("SKILL_ART_OK: 20 nonempty generated animation frames with transparency")

# Generated art stays byte-identical to its saved original. Only native atlas
# slicing/scaling is performed by the game; there is no procedural replacement.
import hashlib
import json
root = art.parents[1]
manifest = json.loads((root / "assets/art/evolution/manifest.json").read_text())
for entry in manifest["files"]:
    runtime = root / entry["file"]
    source = root / entry["source"]
    assert hashlib.sha256(runtime.read_bytes()).hexdigest() == entry["sha256"]
    assert runtime.read_bytes() == source.read_bytes()
    asset = Image.open(runtime).convert("RGBA")
    assert list(asset.size) == entry["size"]
    columns, rows = entry["grid"]
    for row in range(rows):
        for column in range(columns):
            cell = asset.crop((column*asset.width//columns,row*asset.height//rows,(column+1)*asset.width//columns,(row+1)*asset.height//rows))
            assert cell.getbbox() is not None
    if entry["key"] != "backdrop":
        assert asset.getchannel("A").getextrema() == (0,255)
print("EVOLUTION_ART_OK: original generated frames, background, three doors and twelve crop stages")
