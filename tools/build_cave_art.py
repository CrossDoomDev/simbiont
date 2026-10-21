"""Pack the generated cave cutout into a native, transparent 256px game asset."""
from pathlib import Path
import json
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]
source = ROOT / 'assets/source/cave-entrance-generated.png'
image = Image.open(source).convert('RGBA')
box = image.getchannel('A').point(lambda alpha: 255 if alpha > 32 else 0).getbbox()
if not box:
    raise ValueError('Cave source has no visible pixels')
image = ImageOps.contain(image.crop(box), (248, 208), Image.Resampling.LANCZOS)
packed = Image.new('RGBA', (256, 224))
packed.alpha_composite(image, ((256 - image.width) // 2, (224 - image.height) // 2))
packed.save(ROOT / 'assets/art/cave_entrance.png')
print('CAVE_ART_OK: transparent 256x224 cave entrance')
