"""Import the Codex ImageGen art for the village rim into assets/generated.

Usage: python3 tools/art/build_village_rim_art.py <source-dir>
<source-dir> holds plaque.png, timber.png, shrubs.png and mountains.png as
saved by `codex exec` (prompts in assets/generated/VILLAGE_RIM_ART.md).
Pixel art is only ever halved with nearest-neighbour sampling.
"""
import sys
from pathlib import Path

from PIL import Image

OUT = Path(__file__).resolve().parents[2] / "assets" / "generated"


def halve(image: Image.Image) -> Image.Image:
    return image.resize((image.width // 2, image.height // 2), Image.Resampling.NEAREST)


def main() -> None:
    source = Path(sys.argv[1])
    plaque = Image.open(source / "plaque.png").convert("RGBA")
    halve(plaque.crop(plaque.getchannel("A").getbbox())).save(OUT / "village_gate_plaque.png")
    halve(Image.open(source / "timber.png").convert("RGB")).save(OUT / "village_gate_timber.png")
    # 4 x 3 atlas; tree_variants-style alpha bounds are measured at runtime.
    Image.open(source / "shrubs.png").convert("RGBA").save(OUT / "village_rim_foliage.png")
    mountains = Image.open(source / "mountains.png").convert("RGBA")
    top = max(0, mountains.getchannel("A").getbbox()[1] - 8)
    halve(mountains.crop((0, top, mountains.width, mountains.height))).save(OUT / "village_mountains.png")


if __name__ == "__main__":
    main()
