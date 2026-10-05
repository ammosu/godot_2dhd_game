"""Measure RGBA sprite sheets and write Godot resources; never change image pixels.

Usage: python3 tools/art/build_resident_frames.py [mira flo ...]
       python3 tools/art/build_resident_frames.py --action sia noah
Walk sheets are 4 x 8 (eight facings); action sheets are 4 x 2 (screen-left,
screen-right) and write <name>_action.tres for the companions' battle poses.
Requires Pillow and NumPy. Rows are measured from alpha, not assumed equal cells.
"""
from pathlib import Path
import json
import sys
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "assets/generated/residents"
IDENTITIES = ["mira", "flo", "sien", "locke", "ada", "rain", "seph", "owen", "sia", "noah"]
ROWS = ["down", "down_left", "left", "up_left", "up", "up_right", "right", "down_right"]
ACTION_ROWS = ["left", "right"]
CANVAS = 320
GROUND = 300


def measure(identity: str, sheet: str = "walk") -> None:
    rows = ACTION_ROWS if sheet == "action" else ROWS
    source = ART / f"{identity}_{sheet}.png"
    with Image.open(source) as image:
        assert image.mode == "RGBA", f"{identity}: missing transparency"
        width, height = image.size
        alpha = np.asarray(image)[:, :, 3]
    mask = alpha >= 64
    assert np.count_nonzero(alpha == 0) > width * height * 0.2
    horizontal = np.flatnonzero(np.diff(np.r_[False, mask.sum(axis=0) > 8, False]))
    spans = list(zip(horizontal[::2], horizontal[1::2]))
    assert len(spans) == 4, f"{identity}: expected four separated columns, got {spans}"
    boundaries = [0] + [int((spans[c-1][1] + spans[c][0]) / 2) for c in range(1, 4)] + [width]
    columns = []
    for column in range(4):
        x0, x1 = boundaries[column], boundaries[column+1]
        column_center = float(sum(spans[column])) / 2
        active = mask[:, x0:x1].sum(axis=1) > 2
        changes = np.flatnonzero(np.diff(np.r_[False, active, False]))
        runs = []
        for top, bottom in zip(changes[::2], changes[1::2]):
            if runs and top - runs[-1][1] <= 3:
                runs[-1][1] = int(bottom)
            else:
                runs.append([int(top), int(bottom)])
        runs = [run for run in runs if run[1] - run[0] > height / 20]
        assert len(runs) == len(rows), f"{identity} column {column}: expected {len(rows)} separate bodies, got {runs}"
        frames = []
        for row, (top, bottom) in enumerate(runs):
            # Split gutters between adjacent bodies to include detached pixels.
            band_top = 0 if row == 0 else (runs[row - 1][1] + top) // 2
            band_bottom = height if row == len(rows) - 1 else (bottom + runs[row + 1][0]) // 2
            yy, xx = np.nonzero(mask[band_top:band_bottom, x0:x1])
            left, right = int(xx.min()) + x0, int(xx.max()) + x0 + 1
            top, bottom = int(yy.min()) + band_top, int(yy.max()) + band_top + 1
            assert left > x0 and right < x1, f"{identity}: body crosses column boundary"
            foot_y, foot_x = np.nonzero(mask[max(top, bottom - 12):bottom, x0:x1])
            foot_center = x0 + (int(foot_x.min()) + int(foot_x.max()) + 1) / 2 - column_center
            region = [max(x0, left - 2), max(band_top, top - 2), min(x1, right + 2), min(band_bottom, bottom + 2)]
            frames.append(dict(region=region, bottom=bottom, visible_height=bottom-top, foot_center=foot_center, column_center=column_center))
        columns.append(frames)
    lines = [f'[gd_resource type="SpriteFrames" load_steps={len(rows) * 4 + 2} format=3]', '',
             f'[ext_resource type="Texture2D" path="res://assets/generated/residents/{identity}_{sheet}.png" id="1"]', '']
    measurements = []
    for row, direction in enumerate(rows):
        reference_height = float(np.median([column[row]["visible_height"] for column in columns]))
        # Fixed horizontal pivot across each direction's cycle preserves leg motion.
        foot_center = float(np.median([column[row]["foot_center"] for column in columns]))
        for column in range(4):
            measured = columns[column][row]
            x0, y0, x1, y1 = measured["region"]
            w, h = x1-x0, y1-y0
            assert w <= CANVAS and h < GROUND, f"{identity}: increase presentation canvas"
            margin_x = CANVAS / 2 - (measured["column_center"] + foot_center - x0)
            margin_y = GROUND - (measured["bottom"] - y0)
            lines += [f'[sub_resource type="AtlasTexture" id="Frame_{row}_{column}"]',
                      'atlas = ExtResource("1")', f'region = Rect2({x0}, {y0}, {w}, {h})',
                      f'margin = Rect2({margin_x}, {margin_y}, {CANVAS-w}, {CANVAS-h})',
                      'filter_clip = true', f'metadata/ground_y = {float(GROUND)}',
                      f'metadata/reference_height = {reference_height}',
                      f'metadata/visible_height = {float(measured["visible_height"])}', '']
            measurements.append(dict(direction=direction, frame=column, region=[x0,y0,w,h], reference_height=reference_height))
    lines += ['[resource]', 'animations = [']
    for row, direction in enumerate(rows):
        frames = ', '.join('{"duration": 1.0, "texture": SubResource("Frame_%d_%d")}' % (row, col) for col in range(4))
        lines += [f'{{"frames": [{frames}], "loop": true, "name": &"{direction}", "speed": 6.0}}' + (',' if row < len(rows) - 1 else '')]
    lines += [']', '']
    suffix = "" if sheet == "walk" else "_" + sheet
    (ART / f"{identity}_{sheet}.tres").write_text('\n'.join(lines))
    (ART / f"{identity}{suffix}_measurements.json").write_text(json.dumps(dict(source=source.name, size=[width,height], frames=measurements), indent=2)+'\n')
    print(f"{identity}: measured {len(rows) * 4} {sheet} frames, {width}x{height}, wrote SpriteFrames")


ACTION_CANVAS = (960, 480)
ACTION_GROUND = 460


def _components(mask: np.ndarray) -> list:
    """4-connected opaque blobs as (area, xs, ys); plain BFS, no SciPy needed."""
    from collections import deque
    height, width = mask.shape
    seen = np.zeros_like(mask, dtype=bool)
    blobs = []
    for start_y, start_x in zip(*np.nonzero(mask)):
        if seen[start_y, start_x]:
            continue
        queue = deque([(start_y, start_x)])
        seen[start_y, start_x] = True
        xs, ys = [], []
        while queue:
            y, x = queue.popleft()
            xs.append(x)
            ys.append(y)
            for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
                if 0 <= ny < height and 0 <= nx < width and mask[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    queue.append((ny, nx))
        blobs.append((len(xs), np.array(xs), np.array(ys)))
    return blobs


def measure_action(identity: str) -> None:
    """4 x 2 battle poses. Long weapons may overlap neighbouring columns, so each
    sprite is found as a connected blob instead of between column gutters, and
    copied alone into <name>_action_frames.png so no rectangle crop picks up a
    neighbour's spear tip. The generated source sheet itself is never changed."""
    source = ART / f"{identity}_action.png"
    with Image.open(source) as image:
        assert image.mode == "RGBA", f"{identity}: missing transparency"
        width, height = image.size
        pixels = np.asarray(image).copy()
        alpha = pixels[:, :, 3]
    blobs = sorted(_components(alpha >= 64), key=lambda blob: -blob[0])
    bodies = [blob for blob in blobs[:8]]
    assert len(bodies) == 8 and bodies[-1][0] > blobs[0][0] * 0.2, f"{identity}: expected 8 separate sprites"
    frames = [dict(xs=list(b[1]), ys=list(b[2])) for b in bodies]
    # Stray specks join the nearest sprite so detached highlights are kept.
    for area, xs, ys in blobs[8:]:
        cx, cy = xs.mean(), ys.mean()
        nearest = min(frames, key=lambda f: (np.mean(f["xs"]) - cx) ** 2 + (np.mean(f["ys"]) - cy) ** 2)
        nearest["xs"] += list(xs)
        nearest["ys"] += list(ys)
    for frame in frames:
        frame["cx"], frame["cy"] = float(np.mean(frame["xs"])), float(np.mean(frame["ys"]))
    frames.sort(key=lambda f: f["cy"])
    grid = [sorted(frames[:4], key=lambda f: f["cx"]), sorted(frames[4:], key=lambda f: f["cx"])]
    canvas_w, canvas_h = ACTION_CANVAS
    # Every opaque-ish pixel (including faint edges below the 64 mask) joins the
    # nearest sprite; each sprite is pasted alone into its own clean cell.
    owner = np.full(alpha.shape, -1, dtype=np.int16)
    flat = [frame for row in grid for frame in row]
    for index, frame in enumerate(flat):
        owner[np.array(frame["ys"]), np.array(frame["xs"])] = index
    # Soft edge pixels stay with a sprite only right beside its body; stray
    # haze elsewhere on the sheet is dropped.
    for index, frame in enumerate(flat):
        xs, ys = np.array(frame["xs"]), np.array(frame["ys"])
        x0, x1 = max(0, xs.min() - 3), min(width, xs.max() + 4)
        y0, y1 = max(0, ys.min() - 3), min(height, ys.max() + 4)
        window = (alpha[y0:y1, x0:x1] > 0) & (owner[y0:y1, x0:x1] < 0)
        owner[y0:y1, x0:x1][window] = index
    for index, frame in enumerate(flat):
        ys, xs = np.nonzero(owner == index)
        frame["xs"], frame["ys"] = list(xs), list(ys)
    cell_w = max(max(f["xs"]) - min(f["xs"]) + 1 for f in flat) + 8
    cell_h = max(max(f["ys"]) - min(f["ys"]) + 1 for f in flat) + 8
    clean = np.zeros((cell_h * 2, cell_w * 4, 4), dtype=np.uint8)
    for row in range(2):
        for column, frame in enumerate(grid[row]):
            xs, ys = np.array(frame["xs"]), np.array(frame["ys"])
            dx, dy = column * cell_w + 4 - xs.min(), row * cell_h + 4 - ys.min()
            clean[ys + dy, xs + dx] = pixels[ys, xs]
            frame["xs"], frame["ys"] = list(xs + dx), list(ys + dy)
    Image.fromarray(clean).save(ART / f"{identity}_action_frames.png")
    width, height = int(cell_w) * 4, int(cell_h) * 2
    lines = [f'[gd_resource type="SpriteFrames" load_steps={8 + 2} format=3]', '',
             f'[ext_resource type="Texture2D" path="res://assets/generated/residents/{identity}_action_frames.png" id="1"]', '']
    measurements = []
    for row, direction in enumerate(ACTION_ROWS):
        heights = []
        for frame in grid[row]:
            xs, ys = np.array(frame["xs"]), np.array(frame["ys"])
            frame["box"] = [int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1]
            feet = xs[ys >= ys.max() - 12]
            frame["foot_x"] = (int(feet.min()) + int(feet.max()) + 1) / 2
            heights.append(frame["box"][3] - frame["box"][1])
        reference_height = float(np.median(heights))
        for column, frame in enumerate(grid[row]):
            left, top, right, bottom = frame["box"]
            x0, y0 = max(0, left - 2), max(0, top - 2)
            x1, y1 = min(width, right + 2), min(height, bottom + 2)
            w, h = x1 - x0, y1 - y0
            margin_x = canvas_w / 2 - (frame["foot_x"] - x0)
            margin_y = ACTION_GROUND - (bottom - y0)
            assert 0 <= margin_x and margin_x + w <= canvas_w and margin_y >= 0, f"{identity}: increase action canvas {margin_x} {w} {margin_y} {h}"
            lines += [f'[sub_resource type="AtlasTexture" id="Frame_{row}_{column}"]',
                      'atlas = ExtResource("1")', f'region = Rect2({x0}, {y0}, {w}, {h})',
                      f'margin = Rect2({margin_x}, {margin_y}, {canvas_w - w}, {canvas_h - h})',
                      'filter_clip = true', f'metadata/ground_y = {float(ACTION_GROUND)}',
                      f'metadata/reference_height = {reference_height}',
                      f'metadata/visible_height = {float(bottom - top)}', '']
            measurements.append(dict(direction=direction, frame=column, region=[int(x0), int(y0), int(w), int(h)], reference_height=reference_height))
    lines += ['[resource]', 'animations = [']
    for row, direction in enumerate(ACTION_ROWS):
        entries = ', '.join('{"duration": 1.0, "texture": SubResource("Frame_%d_%d")}' % (row, col) for col in range(4))
        lines += [f'{{"frames": [{entries}], "loop": false, "name": &"{direction}", "speed": 6.0}}' + (',' if row == 0 else '')]
    lines += [']', '']
    (ART / f"{identity}_action.tres").write_text('\n'.join(lines))
    (ART / f"{identity}_action_measurements.json").write_text(json.dumps(dict(source=source.name, size=[width, height], frames=measurements), indent=2) + '\n')
    print(f"{identity}: measured 8 action frames, {width}x{height}, wrote SpriteFrames")


if __name__ == "__main__":
    names = [arg for arg in sys.argv[1:] if not arg.startswith("--")]
    kind = "action" if "--action" in sys.argv else "walk"
    for name in names or IDENTITIES:
        assert name in IDENTITIES
        measure_action(name) if kind == "action" else measure(name)
