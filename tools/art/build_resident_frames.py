"""Measure RGBA sprite sheets and write Godot resources; never change image pixels.

Usage: python3 tools/art/build_resident_frames.py [mira flo ...]
Requires Pillow and NumPy. Rows are measured from alpha, not assumed equal cells.
"""
from pathlib import Path
import json
import sys
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "assets/generated/residents"
IDENTITIES = ["mira", "flo", "sien", "locke", "ada", "rain", "seph", "owen"]
ROWS = ["down", "down_left", "left", "up_left", "up", "up_right", "right", "down_right"]
CANVAS = 320
GROUND = 300


def measure(identity: str) -> None:
    source = ART / f"{identity}_walk.png"
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
        assert len(runs) == 8, f"{identity} column {column}: expected 8 separate bodies, got {runs}"
        frames = []
        for row, (top, bottom) in enumerate(runs):
            # Split gutters between adjacent bodies to include detached pixels.
            band_top = 0 if row == 0 else (runs[row - 1][1] + top) // 2
            band_bottom = height if row == 7 else (bottom + runs[row + 1][0]) // 2
            yy, xx = np.nonzero(mask[band_top:band_bottom, x0:x1])
            left, right = int(xx.min()) + x0, int(xx.max()) + x0 + 1
            top, bottom = int(yy.min()) + band_top, int(yy.max()) + band_top + 1
            assert left > x0 and right < x1, f"{identity}: body crosses column boundary"
            foot_y, foot_x = np.nonzero(mask[max(top, bottom - 12):bottom, x0:x1])
            foot_center = x0 + (int(foot_x.min()) + int(foot_x.max()) + 1) / 2 - column_center
            region = [max(x0, left - 2), max(band_top, top - 2), min(x1, right + 2), min(band_bottom, bottom + 2)]
            frames.append(dict(region=region, bottom=bottom, visible_height=bottom-top, foot_center=foot_center, column_center=column_center))
        columns.append(frames)
    lines = ['[gd_resource type="SpriteFrames" load_steps=34 format=3]', '',
             f'[ext_resource type="Texture2D" path="res://assets/generated/residents/{identity}_walk.png" id="1"]', '']
    measurements = []
    for row, direction in enumerate(ROWS):
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
    for row, direction in enumerate(ROWS):
        frames = ', '.join('{"duration": 1.0, "texture": SubResource("Frame_%d_%d")}' % (row, col) for col in range(4))
        lines += [f'{{"frames": [{frames}], "loop": true, "name": &"{direction}", "speed": 6.0}}' + (',' if row < 7 else '')]
    lines += [']', '']
    (ART / f"{identity}_walk.tres").write_text('\n'.join(lines))
    (ART / f"{identity}_measurements.json").write_text(json.dumps(dict(source=source.name, size=[width,height], frames=measurements), indent=2)+'\n')
    print(f"{identity}: measured 32 frames, {width}x{height}, wrote SpriteFrames")


if __name__ == "__main__":
    for name in sys.argv[1:] or IDENTITIES:
        assert name in IDENTITIES
        measure(name)
