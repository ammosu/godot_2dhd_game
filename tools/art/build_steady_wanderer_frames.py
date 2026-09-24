"""Register the steady-head traveler atlas; source PNG pixels are never edited.

Requires Pillow. Keeps the existing diagonal frames and the legacy atlas used by
equipment variants. Cardinal frames align on the head, not swinging arms/feet.
"""
from pathlib import Path
import re

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "assets/generated"
CANVAS = 352
BASELINE = 316


def main():
    image = Image.open(ART / "wanderer_steady_walk.png").convert("RGBA")
    assert image.size == (1254, 1254)
    text = (ART / "wanderer_frames.tres").read_text()
    text = text.replace('path="res://assets/generated/wanderer_walk.png"',
                        'path="res://assets/generated/wanderer_steady_walk.png"')
    columns = [0, 313, 627, 940, 1254]
    rows = [0, 331, 645, 951, 1254]
    for column in range(4):
        for row in range(4):
            points = [(x, y) for y in range(rows[row], rows[row + 1])
                      for x in range(columns[column], columns[column + 1])
                      if image.getpixel((x, y))[3] >= 64]
            left = min(x for x, _ in points) - 2
            right = max(x for x, _ in points) + 3
            top = min(y for _, y in points) - 2
            baseline = max(y for _, y in points) + 1
            bottom = baseline + 2
            width, height = right - left, bottom - top
            assert columns[column] <= left < right <= columns[column + 1]
            assert rows[row] <= top < bottom <= rows[row + 1]
            # This band contains only the head in all four cardinal facings.
            # Alpha centroid avoids the sword, pouch, scarf and moving hands.
            head = [x for x, y in points
                    if top + height * 0.08 <= y < top + height * 0.25]
            head_center = sum(head) / len(head) - left
            margin_x = round(CANVAS * 0.5 - head_center, 3)
            margin_y = BASELINE - (baseline - top)
            replacement = f'''[sub_resource type="AtlasTexture" id="Frame_{column}_{row}"]
atlas = ExtResource("1_atlas")
region = Rect2({left}, {top}, {width}, {height})
margin = Rect2({margin_x}, {margin_y}, {CANVAS - width}, {CANVAS - height})
filter_clip = true
metadata/ground_y = {float(BASELINE)}

'''
            text = re.sub(rf'\[sub_resource type="AtlasTexture" id="Frame_{column}_{row}"\]\n.*?(?=\[)',
                          replacement, text, flags=re.S)
    (ART / "wanderer_steady_frames.tres").write_text(text)
    print("Registered 16 steady-head traveler frames; original diagonal poses retained")


if __name__ == "__main__":
    main()
