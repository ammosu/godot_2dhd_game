"""Render a Blender-rigged character and register it as a SpriteFrames atlas.

Requires Blender 5.x and Pillow:
    python3 tools/art/build_blender_character.py wanderer [--blender PATH]

Runs tools/art/blender/render_character.py headless at the game's 352 px
canvas, maps every pixel onto a palette measured from the character's painted
sheets (tools/art/blender/characters/<name>.json), puts each frame's lowest
pixel on the y=316 baseline, and writes assets/generated/blender/<name>/
walk.png plus walk_frames.tres. Every frame carries the rig's measured contact
stride as metadata/step_length, which player.gd uses as the walk cadence.
Preview the wanderer in game with `-- --blender-hero`.
"""
import argparse
import json
import subprocess
import tempfile
from pathlib import Path

from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[2]
BLENDER_DIR = ROOT / "tools/art/blender"
CANVAS = 352
BASELINE = 316
FRAMES = 4
PALETTE_COLOURS = 32
# Animation order matches wanderer_steady_frames.tres.
DIRECTIONS = ["down", "up", "left", "right", "down_left", "down_right", "up_left", "up_right"]


def character_meta(name: str) -> dict:
    return json.loads((BLENDER_DIR / "characters" / f"{name}.json").read_text())


def out_dir(name: str) -> Path:
    return ROOT / "assets/generated/blender" / name


def opaque_box(image: Image.Image) -> tuple:
    # Matches the player sprite's alpha_scissor_threshold (0.25).
    return image.getchannel("A").point(lambda a: 255 if a >= 64 else 0).getbbox()


def painted_palette(name: str, colours: int = PALETTE_COLOURS) -> Image.Image:
    """Median-cut palette of the character's painted sheets (opaque pixels)."""
    pixels = []
    for sheet in character_meta(name)["style_sheets"]:
        pixels += [p[:3] for p in Image.open(ROOT / sheet).convert("RGBA").getdata() if p[3] >= 200]
    strip = Image.new("RGB", (len(pixels), 1))
    strip.putdata(pixels)
    return strip.quantize(colors=colours, method=Image.Quantize.MEDIANCUT)


def to_palette(image: Image.Image, palette: Image.Image) -> Image.Image:
    alpha = image.getchannel("A").point(lambda a: 255 if a >= 64 else 0)
    result = image.convert("RGB").quantize(palette=palette, dither=Image.Dither.NONE).convert("RGBA")
    result.putalpha(alpha)
    return result


def ground(frame: Image.Image, limit: int = 28) -> Image.Image:
    """The tilted camera draws the sole nearer the lens lower on screen;
    upright sprites treat the lowest pixel as ground."""
    shift = BASELINE - opaque_box(frame)[3]
    assert abs(shift) <= limit, f"sole {shift} px off the ground"
    return ImageChops.offset(frame, 0, shift)


def render_frames(name: str, blender: str) -> tuple:
    """({(direction, frame): 352 px RGBA}, metrics) from the rig, palette-mapped and grounded."""
    palette = painted_palette(name)
    frames = {}
    with tempfile.TemporaryDirectory() as temp:
        subprocess.run([blender, "-b", "--factory-startup", "-P", str(BLENDER_DIR / "render_character.py"),
                        "--", name, temp], check=True, stdout=subprocess.DEVNULL)
        metrics = json.loads((Path(temp) / "metrics.json").read_text())
        for direction in DIRECTIONS:
            for row in range(FRAMES):
                frame = Image.open(Path(temp) / f"{direction}_{row}.png").convert("RGBA")
                assert frame.size == (CANVAS, CANVAS)
                frames[direction, row] = ground(to_palette(frame, palette))
    return frames, metrics


def write_atlas(name: str, frames: dict, atlas: str, variant: str, step_length: float) -> int:
    """Write <atlas>.png and <atlas>_frames.tres; returns the shared stature (px)."""
    sheet = Image.new("RGBA", (CANVAS * len(DIRECTIONS), CANVAS * FRAMES))
    for column, direction in enumerate(DIRECTIONS):
        for row in range(FRAMES):
            sheet.alpha_composite(frames[direction, row], (column * CANVAS, row * CANVAS))
    target = out_dir(name)
    target.mkdir(parents=True, exist_ok=True)
    sheet.save(target / f"{atlas}.png", optimize=True)
    # Every facing shares one scale, so a single stature (the front view's,
    # hair included) keeps the sprite size steady on turns.
    stature = BASELINE - opaque_box(frames["down", 0])[1]
    subs, animations = [], []
    for column, direction in enumerate(DIRECTIONS):
        refs = []
        for row in range(FRAMES):
            sub_id = f"Frame_{column}_{row}"
            subs.append(f'''[sub_resource type="AtlasTexture" id="{sub_id}"]
atlas = ExtResource("1_atlas")
region = Rect2({column * CANVAS}, {row * CANVAS}, {CANVAS}, {CANVAS})
filter_clip = true
metadata/ground_y = {float(BASELINE)}
metadata/anchor_x = {CANVAS * 0.5}
metadata/body_height = {float(stature)}
metadata/width_scale = 1.0
metadata/step_length = {step_length}
metadata/direction = "{direction}"
metadata/variant = "{variant}"
''')
            refs.append(f'{{"duration": 1.0, "texture": SubResource("{sub_id}")}}')
        animations.append(f'''{{
"frames": [{", ".join(refs)}],
"loop": true,
"name": &"{direction}",
"speed": 8.0
}}''')
    text = f'''[gd_resource type="SpriteFrames" load_steps={len(subs) + 2} format=3]

[ext_resource type="Texture2D" path="res://assets/generated/blender/{name}/{atlas}.png" id="1_atlas"]

{chr(10).join(subs)}
[resource]
animations = [{", ".join(animations)}]
'''
    (target / f"{atlas}_frames.tres").write_text(text)
    (target / "metrics.json").write_text(json.dumps({"step_length": step_length, "stature": stature}) + "\n")
    return stature


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("character")
    parser.add_argument("--blender", default="/Applications/Blender.app/Contents/MacOS/Blender")
    args = parser.parse_args()
    frames, metrics = render_frames(args.character, args.blender)
    stature = write_atlas(args.character, frames, "walk", f"blender_{args.character}", metrics["step_length"])
    print(f"standing height {stature} px, step length {metrics['step_length']} m")


if __name__ == "__main__":
    main()
