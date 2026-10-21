"""Resize generated UI sources for native nine-patch and background textures."""
from pathlib import Path
from PIL import Image, ImageOps
ROOT = Path(__file__).resolve().parents[1]
for name, size in [('panel', (128, 128)), ('button', (384, 96))]:
    image = Image.open(ROOT / f'assets/source/ui-{name}-generated.png').convert('RGBA')
    box = image.getchannel('A').point(lambda alpha: 255 if alpha > 32 else 0).getbbox()
    if not box:
        raise ValueError(f'{name} has no visible image')
    # Borders are packed to the exact 9-patch dimensions; the generated source
    # remains untouched and all runtime expansion preserves these corner pixels.
    image.crop(box).resize(size, Image.Resampling.LANCZOS).save(ROOT / f'assets/art/ui/{name}.png')
background = Image.open(ROOT / 'assets/source/ui-backdrop-generated.png').convert('RGBA')
ImageOps.fit(background, (1600, 900), Image.Resampling.LANCZOS).save(ROOT / 'assets/art/ui/backdrop.png')
print('UI_ART_OK: panel 128x128, button 384x96, backdrop 1600x900')
