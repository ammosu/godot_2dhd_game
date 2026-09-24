"""Measure opposite-foot contact art and update atlas resources; no pixel edits.

Run after saving diagonal_contact_b.png. Existing art remains unchanged.
"""
from pathlib import Path
import re
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / 'assets/generated'
SOURCE = ART / 'diagonal_contact_b.png'


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
