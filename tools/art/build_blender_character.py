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
# Frame 0 stands; frames 1-8 are the walk cycle (rig_common.WALK).
FRAMES = 9
POSES = ["stand", "passing", "up", "contact", "down", "passing", "up", "contact", "down"]
PALETTE_COLOURS = 32
# Pixels a walking sole may dip below the ground line (see ground_cycle).
SOLE_SINK = 2
# Animation order matches wanderer_steady_frames.tres.
DIRECTIONS = ["down", "up", "left", "right", "down_left", "down_right", "up_left", "up_right"]


def character_meta(name: str) -> dict:
    return json.loads((BLENDER_DIR / "characters" / f"{name}.json").read_text())


def out_dir(name: str) -> Path:
    return ROOT / "assets/generated/blender" / name


def opaque_box(image: Image.Image) -> tuple:
    # Matches the player sprite's alpha_scissor_threshold (0.25).
    return image.getchannel("A").point(lambda a: 255 if a >= 64 else 0).getbbox()


def style_sheets(name: str) -> list:
    """Painted sheets named by the character's style_sheets (4 x 4 grids) or style_cells."""
    meta = character_meta(name)
    return list(meta.get("style_sheets", {})) or sorted({sheet for sheet, _ in meta["style_cells"].values()})


def painted_palette(name: str, colours: int = PALETTE_COLOURS) -> Image.Image:
    """Median-cut palette of the character's painted sheets (opaque pixels)."""
    pixels = []
    for sheet in style_sheets(name):
        pixels += [p[:3] for p in Image.open(ROOT / sheet).convert("RGBA").getdata() if p[3] >= 200]
    strip = Image.new("RGB", (len(pixels), 1))
    strip.putdata(pixels)
    return strip.quantize(colors=colours, method=Image.Quantize.MEDIANCUT)


def to_palette(image: Image.Image, palette: Image.Image) -> Image.Image:
    alpha = image.getchannel("A").point(lambda a: 255 if a >= 64 else 0)
    result = image.convert("RGB").quantize(palette=palette, dither=Image.Dither.NONE).convert("RGBA")
    result.putalpha(alpha)
    return result


def ground_cycle(frames: list, sink: int = SOLE_SINK, limit: int = 28) -> list:
    """Ground a facing's frames together on its standing frame (frame 0).

    Per-frame grounding on the lowest pixel erased the rig's body bob: in the
    up pose the lifted near foot projects lowest and pushed the whole body
    down. One shared shift keeps the rendered rise and fall; a frame whose
    near sole would sink more than `sink` px below the ground line (where the
    depth-tested billboard buries it) is lifted only that far."""
    shift = BASELINE - opaque_box(frames[0])[3]
    assert abs(shift) <= limit, f"standing sole {shift} px off the ground"
    result = []
    for frame in frames:
        below = opaque_box(frame)[3] + shift - BASELINE
        result.append(ImageChops.offset(frame, 0, shift - max(0, below - sink)))
    return result


def render_frames(name: str, blender: str) -> tuple:
    """({(direction, frame): 352 px RGBA}, metrics) from the rig, palette-mapped and grounded."""
    palette = painted_palette(name)
    frames = {}
    with tempfile.TemporaryDirectory() as temp:
        subprocess.run([blender, "-b", "--factory-startup", "-P", str(BLENDER_DIR / "render_character.py"),
                        "--", name, temp], check=True, stdout=subprocess.DEVNULL)
        metrics = json.loads((Path(temp) / "metrics.json").read_text())
        for direction in DIRECTIONS:
            cycle = []
            for row in range(FRAMES):
                frame = Image.open(Path(temp) / f"{direction}_{row}.png").convert("RGBA")
                assert frame.size == (CANVAS, CANVAS)
                cycle.append(to_palette(frame, palette))
            for row, frame in enumerate(ground_cycle(cycle)):
                frames[direction, row] = frame
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
metadata/pose = "{POSES[row]}"
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
