"""Check the asymmetric host's anatomy in the actual runtime atlas cells.

South-facing anatomical right is screen-left; north-facing right is screen-right.
The source defect swapped the purple weapon arm on the second south gait frame.
Checking those pixels catches an art regression that a no-flip_h code check misses.
"""
from pathlib import Path
from PIL import Image, ImageChops, ImageOps

ROOT = Path(__file__).resolve().parents[1]


def arm_pixels(cell: Image.Image) -> tuple[int, int]:
    counts = [0, 0]
    # Exclude visor/tendrils above the shoulders and the boot area; inspect the
    # characteristic purple weapon forearm rather than the symmetrical head.
    for y in range(15, 51):
        for x in range(64):
            red, green, blue, alpha = cell.getpixel((x, y))
            if alpha > 70 and blue > green * 1.3 and red > green * 1.2 and red + blue > 60:
                counts[x >= 32] += 1
    return counts[0], counts[1]


def different(first: Image.Image, second: Image.Image) -> bool:
    return ImageChops.difference(first, second).convert("RGB").getbbox() is not None


def main() -> None:
    frames_checked = 0
    for name in ("hero.png", "hero_base.png"):
        sheet = Image.open(ROOT / "assets" / "art" / name).convert("RGBA")
        assert sheet.size == (256, 256), (name, "unexpected atlas grid")
        south = [sheet.crop((col * 64, 0, (col + 1) * 64, 64)) for col in range(4)]
        north = [sheet.crop((col * 64, 192, (col + 1) * 64, 256)) for col in range(3)]
        for col, cell in enumerate(south):
            left, right = arm_pixels(cell)
            assert left >= right * 1.5 and left >= 70, (name, "south arm changed sides", col, left, right)
            frames_checked += 1
        for col, cell in enumerate(north):
            left, right = arm_pixels(cell)
            assert right > left * 1.2, (name, "north arm changed sides", col, left, right)
            frames_checked += 1
        assert different(south[1], south[2]), (name, "identical south gait frames")
        assert different(ImageOps.mirror(south[1]), south[2]), (name, "mirrored south gait frame")
        assert different(south[0], south[3]), (name, "south attack duplicates idle")
        # A firing pose needs a bright magenta muzzle burst below the right
        # forearm, not just differently placed feet or a runtime projectile.
        def muzzle_pixels(cell: Image.Image) -> int:
            return sum(1 for y in range(32, 58) for x in range(4, 32)
                       if (lambda p: p[3] > 100 and p[0] > 180 and p[2] > 150
                           and p[1] < p[0] * 0.85)(cell.getpixel((x, y))))
        assert muzzle_pixels(south[3]) >= muzzle_pixels(south[0]) + 8, (name, "south attack has no muzzle flash")
        print(name, "south arm left/right:", [arm_pixels(frame) for frame in south])
    print(f"HOST_ANIMATION_OK: {frames_checked} anatomical-arm frames; two distinct unmirrored south gait poses")


if __name__ == "__main__":
    main()
