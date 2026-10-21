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
