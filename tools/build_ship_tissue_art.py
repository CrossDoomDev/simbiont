"""Pack the generated transparent living-ship art into native 256px atlas cells.

Source image and exact imagegen prompt remain in the repository. This tool only
slices, trims transparent gutters, uniformly scales and packs the generated art;
it does not paint replacement details or change the existing shared atlas.
"""
from pathlib import Path
import hashlib
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/source/ship-tissue-generated.png"
OUTPUT = ROOT / "assets/art/ship_tissue.png"
MANIFEST = ROOT / "assets/art/ship_tissue_manifest.json"
PROMPT = "Create a production-ready 2D game environmental sprite sheet for a living alien organic spaceship, dark detailed pixel-art-compatible hand painted style, with richly textured flesh, sinew, wet highlights, chitin and bioluminescent veins. STRICT orthographic TOP-DOWN view, like looking straight down at the cut-open cross section of a biological spaceship. NO perspective, NO isometric, NO side-view walls. Exactly SIX isolated sprites in a regular THREE-COLUMN TWO-ROW grid with large even transparent gutters, each object entirely inside its own square cell, no overlaps between cells. Transparent background everywhere except the objects. Palette deep burgundy, black plum, dried rose with selective glowing colored veins. Every sprite has an irregular tangled silhouette with lots of small flesh wrinkles and fine branching fibers. Strong shaded material detail, not vector art, not outlines, no regular repeated patterns. Sprite row1 col1: long curved burgundy structural rib and membrane segment, woven layered bone-like sinew plates, approximately horizontal and occupying 85 percent cell width, irregular tapered tips. Row1 col2: dense tangled organic structural ROOT MASS with interwoven maroon sinew tendrils, asymmetrical irregular shape with a few roots reaching downwards. Row1 col3: a cluster of dark purple living shell and fleshy bladder nodules with dim violet blood vessels, no central circular platform, asymmetrical cluster. Row2 col1: orange-red pulsing vascular wall cluster composed of fleshy heart-like chambers and wrinkled membranes connected by gnarled red veins, irregular spread. Row2 col2: cyan bioluminescent living membrane and dark teal rib cluster with small translucent sacs and winding thin blue tendrils, irregular spread. Row2 col3: green bioluminescent RESOURCE SAC cluster of several translucent dark-green pods filled with glowing granular material, joined by brown tendons. No characters, no people, no human body, no creatures with faces, no computer, no terminal, no portal, no UI, no text, no icons, no floor tiles, no flat colored shadows or background. Detailed organic game art that can be densely overlapped along the contour of rooms to build richly textured living walls, each 256x256 destination cell. Emphasize tangibly textured richly shaded sinew and membrane material and avoid slick procedural schematic appearance."
CELL = 256
NAMES = [
    ["rib_membrane", "root_mass", "purple_nodules"],
    ["orange_vascular", "cyan_membrane", "green_resource_sacs"],
]
# Measured transparent gutters preserve the rib's tapered right tip and the
# root's longest lower tendrils; the generator did not use exact grid thirds.
SOURCE_BOUNDS = [
    [(0, 0, 568, 512), (568, 0, 1034, 530), (1034, 0, 1536, 512)],
    [(0, 512, 588, 1024), (588, 530, 1034, 1024), (1034, 512, 1536, 1024)],
]

def main():
    source = Image.open(SOURCE).convert("RGBA")
    alpha_min, alpha_max = source.getchannel("A").getextrema()
    if alpha_min != 0 or alpha_max < 240:
        raise ValueError("Generated tissue source must retain genuine transparency")
    atlas = Image.new("RGBA", (CELL * 3, CELL * 2))
    sprites = {}
    for y in range(2):
        for x in range(3):
            bounds = SOURCE_BOUNDS[y][x]
            cell = source.crop(bounds)
            visible = cell.getchannel("A").point(lambda a: 255 if a > 24 else 0).getbbox()
            if not visible:
                raise ValueError(f"Empty generated tissue cell {x},{y}")
            sprite = cell.crop(visible)
            factor = min(244 / sprite.width, 244 / sprite.height)
            size = (max(1, round(sprite.width * factor)), max(1, round(sprite.height * factor)))
            sprite = sprite.resize(size, Image.Resampling.LANCZOS)
            atlas.alpha_composite(sprite, (
                x * CELL + (CELL - sprite.width) // 2,
                y * CELL + (CELL - sprite.height) // 2,
            ))
            sprites[NAMES[y][x]] = {"cell": [x, y], "source_bounds": list(bounds)}
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    previous = Image.open(OUTPUT).convert("RGBA") if OUTPUT.exists() else None
    if previous is None or previous.size != atlas.size or previous.tobytes() != atlas.tobytes():
        atlas.save(OUTPUT)
    data = {
        "source": "assets/source/ship-tissue-generated.png",
        "source_sha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        "atlas": "assets/art/ship_tissue.png",
        "atlas_sha256": hashlib.sha256(OUTPUT.read_bytes()).hexdigest(),
        "size": list(atlas.size),
        "cell_size": [CELL, CELL],
        "view": "strict orthographic top-down",
        "generation_tool": "image_gen.imagegen",
        "transparent_background": True,
        "prompt": PROMPT,
        "assembly": "python tools/build_ship_tissue_art.py",
        "sprites": sprites,
    }
    MANIFEST.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("SHIP_TISSUE_ART_OK", atlas.size, "6 transparent cells")

if __name__ == "__main__":
    main()
