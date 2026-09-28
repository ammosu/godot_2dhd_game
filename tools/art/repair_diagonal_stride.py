"""Measure opposite-foot contact art and update atlas resources; no pixel edits.

Run after saving diagonal_contact_b.png. Existing art remains unchanged.
register_walk_cycle() is imported by build_steady_wanderer_frames.py to register
the default traveler's walk frames on their neutral head (metadata only).
"""
from pathlib import Path
import re
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / 'assets/generated'
SOURCE = ART / 'diagonal_contact_b.png'

# Walk-cycle registration (metadata only). Contact frames are rescaled about
# the feet and re-centred on the neutral head, so the head bobs down evenly on
# both steps instead of limping or popping. Values are canvas pixels.
CANVAS = 352
GROUND = 316.0
CONTACT_DIP = 2.5          # both foot contacts sit this far below neutral
PASSING_DIP = 0.0          # a separate passing drawing matches neutral
HEAD_ALPHA = 128           # opaque hair/face, ignoring antialiased wisps
HEAD_MIN_RUN = 6           # first row this wide is the crown
HEAD_BAND = (0.06, 0.18)   # head rows as a fraction of crown-to-ground
WIDTH_TOLERANCE = 1.5      # px; closer head widths keep uniform scaling
WIDTH_RATIO_LIMITS = (0.9, 1.06)
STANDING_REFERENCE = 290.0  # player.gd default standing body_height


def _widest_run(row):
    padded = np.r_[False, row, False].astype(np.int8)
    edges = np.flatnonzero(np.diff(padded))
    return int((edges[1::2] - edges[::2]).max()) if edges.size else 0


def _crop(alphas, frame):
    x, y, w, h = (int(v) for v in frame['region'])
    return alphas[frame['atlas']][y:y+h, x:x+w]


def standing_profile(alpha, margin, ground=GROUND, reference=STANDING_REFERENCE):
    """Port of character_proportions.gd profile(): (body height, width scale)."""
    center = CANVAS * 0.5 - margin[0]
    first = max(0, int(ground - margin[1] - reference))
    bottom = min(alpha.shape[0], int(ground - margin[1]))
    x0 = max(0, int(center - reference * 0.16))
    x1 = min(alpha.shape[1], int(center + reference * 0.16))
    top = first
    for y in range(first, bottom):
        if (alpha[y, x0:x1] >= 128).sum() >= max(2, int(reference * 0.12)):
            top = y
            break
    height = min(max(float(bottom - top), reference * 0.8), reference)
    widths = sorted(_widest_run(alpha[y] >= 128)
                    for y in range(top + int(height * 0.08), min(bottom, top + int(height * 0.28))))
    head_width = float(widths[int(len(widths) * 0.7)])
    return height, min(max(height * 0.40 / max(head_width, 1.0), 0.85), 1.2)


def head_metrics(alpha, margin_y):
    """Crown y (canvas), head width and head centroid x (crop) of one drawing."""
    solid = alpha >= HEAD_ALPHA
    rows = np.flatnonzero(solid.sum(axis=1) >= HEAD_MIN_RUN)
    top = int(rows[0])
    span = GROUND - margin_y - top
    band = range(top + int(span * HEAD_BAND[0]), top + int(span * HEAD_BAND[1]))
    widths = sorted(_widest_run(solid[y]) for y in band)
    ys, xs = np.nonzero(solid[band.start:band.stop])
    return top + margin_y, float(widths[int(len(widths) * 0.7)]), float(xs.mean())


def register_walk_cycle(text, alphas):
    """Register every walk frame to the neutral frame 0 of its animation.

    alphas maps ext_resource ids to alpha arrays. Only margin.x and metadata
    change: pixels, regions and the y=316 foot baseline stay as drawn. Scaled
    frames carry body_height/width_scale, which player.gd applies about the feet.
    """
    frames = {}
    for match in re.finditer(r'\[sub_resource type="AtlasTexture" id="([^"]+)"\]\n(.*?)(?=\n\[)', text, re.S):
        body = match[2]
        frames[match[1]] = {
            'atlas': re.search(r'ExtResource\("([^"]+)"\)', body)[1],
            'region': [float(v) for v in re.search(r'region = Rect2\(([^)]*)\)', body)[1].split(',')],
            'margin': [float(v) for v in re.search(r'margin = Rect2\(([^)]*)\)', body)[1].split(',')],
        }
    done = set()
    for match in re.finditer(r'"frames": \[(.*?)\],\n"loop": \w+,\n"name": &"(\w+)"', text, re.S):
        cycle = re.findall(r'SubResource\("([^"]+)"\)', match[1])
        neutral = frames[cycle[0]]
        base_alpha = _crop(alphas, neutral)
        standing_height, standing_width = standing_profile(base_alpha, neutral['margin'])
        top0, width0, center0 = head_metrics(base_alpha, neutral['margin'][1])
        center0 += neutral['margin'][0]
        for index, frame_id in enumerate(cycle):
            if frame_id == cycle[0] or frame_id in done:
                continue
            done.add(frame_id)
            frame = frames[frame_id]
            alpha = _crop(alphas, frame)
            top, width, center = head_metrics(alpha, frame['margin'][1])
            target = top0 + (PASSING_DIP if index == 2 else CONTACT_DIP)
            scale_y = (GROUND - target) / (GROUND - top)
            ratio = 1.0
            if abs(width * scale_y - width0) > WIDTH_TOLERANCE:
                ratio = min(max(width0 / (width * scale_y), WIDTH_RATIO_LIMITS[0]), WIDTH_RATIO_LIMITS[1])
            scale_x = scale_y * ratio
            # Horizontal scaling pivots on the canvas centre (sprite offset.x 0).
            margin_x = round(CANVAS * 0.5 + (center0 - CANVAS * 0.5) / scale_x - center, 3)
            width_px = frame['region'][2]
            assert 0.0 <= margin_x and margin_x + width_px <= CANVAS, (frame_id, margin_x)
            margin = frame['margin']
            block = re.search(rf'\[sub_resource type="AtlasTexture" id="{frame_id}"\]\n.*?(?=\n\[)', text, re.S)[0]
            updated = re.sub(r'margin = Rect2\([^)]*\)',
                             f'margin = Rect2({margin_x}, {margin[1]:g}, {margin[2]:g}, {margin[3]:g})', block)
            updated = re.sub(r'\nmetadata/(body_height|width_scale|walk_registration) = [^\n]*', '', updated)
            updated = updated.rstrip('\n') + (f'\nmetadata/body_height = {round(standing_height / scale_y, 3)}'
                        f'\nmetadata/width_scale = {round(standing_width * ratio, 4)}'
                        f'\nmetadata/walk_registration = Vector2({round(scale_x, 4)}, {round(scale_y, 4)})\n')
            text = text.replace(block, updated)
    return text


def main():
    image = Image.open(SOURCE)
    assert image.mode == 'RGBA'
    alpha = np.asarray(image)[:, :, 3]
    mask = alpha >= 64
    height, width = mask.shape
    paths = [ART / 'wanderer_frames.tres'] + [
        ART / f'equipment/{name}_diagonal_frames.tres'
        for name in ['saber', 'moonward', 'moonward_saber']]
    for row, path in enumerate(paths):
        text = path.read_text()
        if 'id="3_contact"' not in text:
            text = re.sub(r'load_steps=(\d+)', lambda m: f'load_steps={int(m[1])+1}', text, count=1)
            at = text.index('[sub_resource')
            text = text[:at] + '[ext_resource type="Texture2D" path="res://assets/generated/diagonal_contact_b.png" id="3_contact"]\n\n' + text[at:]
        for col in range(4):
            x0, x1 = col*width//4, (col+1)*width//4
            active = (alpha[:, x0:x1] >= 128).sum(axis=1) > 2
            edges = np.flatnonzero(np.diff(np.r_[False, active, False]))
            runs = []
            for a, b in zip(edges[::2], edges[1::2]):
                if runs and a - runs[-1][1] <= 3:
                    runs[-1][1] = int(b)
                else:
                    runs.append([int(a), int(b)])
            runs = [r for r in runs if r[1]-r[0] > height/8]
            assert len(runs) == 4, runs
            y0 = 0 if row == 0 else (runs[row-1][1]+runs[row][0])//2
            y1 = height if row == 3 else (runs[row][1]+runs[row+1][0])//2
            yy, xx = np.nonzero(mask[y0:y1, x0:x1])
            left, right = int(xx.min())+x0-2, int(xx.max())+x0+3
            visible_bottom = int(yy.max())+y0+1
            top, bottom = max(y0, int(yy.min())+y0-2), min(y1, visible_bottom+2)
            assert x0 <= left < right <= x1 and y0 <= top < bottom <= y1
            w, h = right-left, bottom-top
            assert w < 352 and h < 316, (row,col,w,h)
            replacement = f'''[sub_resource type="AtlasTexture" id="Diagonal_{col}_3"]
atlas = ExtResource("3_contact")
region = Rect2({left}, {top}, {w}, {h})
margin = Rect2({(352-w)/2}, {316-(visible_bottom-top)}, {352-w}, {352-h})
filter_clip = true
metadata/diagonal_frame = 3
metadata/ground_y = 316.0
metadata/contact_variant = "{['base','saber','moonward','moonward_saber'][row]}"

'''
            text = re.sub(rf'\[sub_resource type="AtlasTexture" id="Diagonal_{col}_3"\]\n.*?(?=\[)', replacement, text, flags=re.S)
            # Use neutral passing between the two contacts. The old row 2
            # still held the same leg forward and caused a second hitch.
            text = text.replace(f'SubResource("Diagonal_{col}_2")', f'SubResource("Diagonal_{col}_0")')
        path.write_text(text)
        print(path.relative_to(ROOT))


if __name__ == '__main__':
    main()
