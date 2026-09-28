"""Repaint a Blender-rigged character with Codex ImageGen and register the result.

Requires Pillow and the Codex CLI. Run after build_blender_character.py:
    python3 tools/art/paint_blender_character.py wanderer [--repaint down,up] [--jobs 4]

For each facing, the four rendered walk frames (assets/generated/blender/
<name>/walk.png) go to Codex as a 2 x 2 pose guide, together with the painted
standing sprite of that facing from the character's style sheets
(tools/art/blender/characters/<name>.json). One call per facing keeps a
facing's four frames consistent with each other. Unmodified outputs are kept
in source/<facing>.png and reused unless listed in --repaint.

Painted sprites drift in size and position, so each cell is fitted to its
rendered frame, which carries the rig's exact stature, bob and footing: same
crown-to-sole height, head centred over the rendered head, sole on y=316.
Writes painted.png and painted_frames.tres; preview the wanderer with
`-- --blender-hero=painted`.
"""
import argparse
import json
import shutil
import subprocess
import tempfile
from collections import deque
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from PIL import Image

from build_blender_character import (BASELINE, CANVAS, DIRECTIONS, FRAMES, ROOT, character_meta, opaque_box,
                                     out_dir, painted_palette, to_palette, write_atlas)

FACING_TEXT = {
    "down": "front view, facing the viewer",
    "up": "back view, facing directly away from the viewer (no face visible)",
    "left": "side profile facing screen-left (face in profile on the left side of the head)",
    "right": "side profile facing screen-right (face in profile on the right side of the head)",
    "down_left": "front three-quarter view turned toward screen-left",
    "down_right": "front three-quarter view turned toward screen-right",
    "up_left": "back three-quarter view walking away toward screen-left (only a sliver of cheek visible)",
    "up_right": "back three-quarter view walking away toward screen-right (only a sliver of cheek visible)",
}
PROMPT = """Use your built-in image generation tool to create ONE image, then save the resulting PNG file into the current working directory as painted.png (copy it from wherever the tool writes it). Do not write code to draw or edit the image; it must come from the image generation tool. Reply only with the saved path.

Image generation prompt (pass both attached images as references: image 1 = pose guide, image 2 = identity and style):

Use case: pose-locked repaint of a game walking animation. Image 1 is the POSE GUIDE: a 2x2 sheet of four 3D-rendered frames of one chibi character, all in the same facing: {facing}. Top-left: passing pose, left foot planted, right leg lifting slightly. Top-right: contact pose, right foot forward on its heel, left foot behind on its toes. Bottom-left: passing pose, right foot planted, left leg lifting slightly. Bottom-right: contact pose, left foot forward on its heel, right foot behind on its toes. Arms swing opposite to the legs. Image 2 is the IDENTITY AND STYLE reference: the game's existing hand-painted pixel-art sprite of the SAME character standing in this same facing.

Repaint all four frames of image 1 as finished sprites of {identity}, in exactly the painted pixel-art style of image 2: same face, hair shape and hair highlights, outfit details, colour palette, dark brown outlines and soft painterly shading lit from the upper left. All four frames must show the identical character with the identical face, hair silhouette and outfit; only the legs, arms and a slight body bob change between frames.

Keep from image 1 for every frame: the exact facing angle, the exact leg and arm positions (which foot is forward), the head position, the silhouette size and the feet position, and the 2x2 placement. The 3D guide's blocky hair and simplified shapes are only placeholders: replace them with the hair and cloth of image 2, but never change pose, facing or size, and never add knots, buns or tails of hair that image 2 does not have. Each sprite stays centred in its own quadrant with generous transparent margins, feet on the same baseline.

Genuine transparent RGBA background. Square output. No floor, no ground shadow, no text, no labels, no grid lines, no checkerboard, no extra characters."""
# Opaque ImageGen output: pixels this close to the corner colour are background.
KEY_TOLERANCE = 48
MIN_BLOB = 400


def cell(image: Image.Image, column: int, row: int, columns: int, rows: int) -> Image.Image:
    width, height = image.width / columns, image.height / rows
    return image.crop((round(column * width), round(row * height), round((column + 1) * width), round((row + 1) * height)))


def style_cells(name: str) -> dict:
    """Painted standing sprite per facing (row 0 of each 4 x 4 style sheet)."""
    cells = {}
    for sheet, facings in character_meta(name)["style_sheets"].items():
        image = Image.open(ROOT / sheet).convert("RGBA")
        for column, facing in enumerate(facings):
            cells[facing] = cell(image, column, 0, 4, 4)
    return cells


def guide(walk: Image.Image, direction: str) -> Image.Image:
    column = DIRECTIONS.index(direction)
    sheet = Image.new("RGBA", (CANVAS * 2, CANVAS * 2))
    for row in range(FRAMES):
        frame = walk.crop((column * CANVAS, row * CANVAS, (column + 1) * CANVAS, (row + 1) * CANVAS))
        sheet.alpha_composite(frame, ((row % 2) * CANVAS, (row // 2) * CANVAS))
    return sheet


def repaint(name: str, direction: str, walk: Image.Image, style: Image.Image, target: Path) -> str:
    with tempfile.TemporaryDirectory() as temp:
        work = Path(temp)
        guide(walk, direction).save(work / "guide.png")
        style.save(work / "style.png")
        prompt = PROMPT.format(facing=FACING_TEXT[direction], identity=character_meta(name)["identity"])
        result = subprocess.run(["codex", "exec", "--skip-git-repo-check", "-s", "workspace-write", "-C", temp,
                                 "-i", str(work / "guide.png"), "-i", str(work / "style.png"), "-"],
                                input=prompt, text=True, capture_output=True)
        output = work / "painted.png"
        if result.returncode != 0 or not output.exists():
            return f"{direction}: FAILED ({result.returncode}) {result.stdout[-400:]}{result.stderr[-400:]}"
        shutil.copy(output, target)
    return f"{direction}: painted"


def keyed(sheet: Image.Image) -> Image.Image:
    """Genuine alpha passes through; otherwise flood-fill the border colour away."""
    sheet = sheet.convert("RGBA")
    if sheet.getchannel("A").getextrema()[0] < 255:
        return sheet
    width, height = sheet.size
    pixels = sheet.load()
    key = pixels[0, 0][:3]
    near = lambda p: sum(abs(a - b) for a, b in zip(p[:3], key)) <= KEY_TOLERANCE
    queue = deque((x, y) for x in range(width) for y in (0, height - 1))
    queue.extend((x, y) for y in range(height) for x in (0, width - 1))
    seen = set()
    while queue:
        x, y = queue.popleft()
        if (x, y) in seen or not (0 <= x < width and 0 <= y < height) or not near(pixels[x, y]):
            continue
        seen.add((x, y))
        pixels[x, y] = (0, 0, 0, 0)
        queue.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    return sheet


def sprite(image: Image.Image) -> Image.Image:
    """Crop to the figure, dropping specks smaller than MIN_BLOB pixels."""
    alpha = image.getchannel("A").point(lambda a: 255 if a >= 64 else 0)
    width, height = alpha.size
    mask = alpha.load()
    seen = set()
    keep = Image.new("L", alpha.size, 0)
    for start in ((x, y) for y in range(height) for x in range(width)):
        if start in seen or not mask[start]:
            continue
        blob, queue = [], deque([start])
        seen.add(start)
        while queue:
            x, y = queue.popleft()
            blob.append((x, y))
            for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if n not in seen and 0 <= n[0] < width and 0 <= n[1] < height and mask[n]:
                    seen.add(n)
                    queue.append(n)
        if len(blob) >= MIN_BLOB:
            for point in blob:
                keep.putpixel(point, 255)
    box = keep.getbbox()
    assert box, "empty painted cell"
    result = Image.new("RGBA", image.size)
    result.paste(image, mask=keep)
    return result.crop(box)


def head_centre(image: Image.Image) -> float:
    """Alpha centroid of the crown band; ignores swinging arms, sword and feet."""
    box = opaque_box(image)
    top, height = box[1], box[3] - box[1]
    alpha = image.load()
    xs = [x for y in range(top, top + int(height * 0.22)) for x in range(box[0], box[2]) if alpha[x, y][3] >= 64]
    return sum(xs) / len(xs)


def fit(painted: Image.Image, rendered: Image.Image) -> Image.Image:
    box = opaque_box(rendered)
    scale = (box[3] - box[1]) / painted.height
    resized = painted.resize((max(1, round(painted.width * scale)), box[3] - box[1]), Image.LANCZOS)
    frame = Image.new("RGBA", (CANVAS, CANVAS))
    left = round(head_centre(rendered) - head_centre(resized))
    frame.alpha_composite(resized, (left, BASELINE - resized.height))
    return frame


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("character")
    parser.add_argument("--repaint", default="", help="comma-separated facings to regenerate, or 'all'")
    parser.add_argument("--jobs", type=int, default=4)
    args = parser.parse_args()
    target = out_dir(args.character)
    source = target / "source"
    source.mkdir(parents=True, exist_ok=True)
    walk = Image.open(target / "walk.png").convert("RGBA")
    styles = style_cells(args.character)
    forced = set(DIRECTIONS if args.repaint == "all" else filter(None, args.repaint.split(",")))
    todo = [d for d in DIRECTIONS if d in forced or not (source / f"{d}.png").exists()]
    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        for line in pool.map(lambda d: repaint(args.character, d, walk, styles[d], source / f"{d}.png"), todo):
            print(line, flush=True)
    missing = [d for d in DIRECTIONS if not (source / f"{d}.png").exists()]
    if missing:
        raise SystemExit(f"missing repaints: {', '.join(missing)}")
    palette = painted_palette(args.character)
    frames = {}
    for direction in DIRECTIONS:
        sheet = keyed(Image.open(source / f"{direction}.png"))
        column = DIRECTIONS.index(direction)
        for row in range(FRAMES):
            rendered = walk.crop((column * CANVAS, row * CANVAS, (column + 1) * CANVAS, (row + 1) * CANVAS))
            painted = sprite(cell(sheet, row % 2, row // 2, 2, 2))
            frames[direction, row] = to_palette(fit(painted, rendered), palette)
    step = float(json.loads((target / "metrics.json").read_text())["step_length"])
    stature = write_atlas(args.character, frames, "painted", f"blender_{args.character}_painted", step)
    print(f"standing height {stature} px")


if __name__ == "__main__":
    main()
