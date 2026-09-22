"""Measure alpha components without altering ImageGen source PNGs.

Run from repository root with Python + Pillow. Writes reproducible atlas metadata;
no images are resized, cropped, synthesized, or edited by this tool.
"""
from pathlib import Path
import json
import hashlib
from PIL import Image

ROOT = Path(__file__).resolve().parents[2] / 'assets/generated/action'


def measure(path):
    image = Image.open(path).convert('RGBA')
    width, height = image.size
    alpha = image.getchannel('A').tobytes()
    mask = bytearray(value > 80 for value in alpha)
    boxes = []
    for start in range(width * height):
        if not mask[start]:
            continue
        mask[start] = 0
        stack = [start]
        count = 0
        x0, y0, x1, y1 = width, height, 0, 0
        while stack:
            value = stack.pop()
            y, x = divmod(value, width)
            count += 1
            x0, y0 = min(x0, x), min(y0, y)
            x1, y1 = max(x1, x), max(y1, y)
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < width and 0 <= yy < height:
                        neighbor = yy * width + xx
                        if mask[neighbor]:
                            mask[neighbor] = 0
                            stack.append(neighbor)
        if count > 500:
            boxes.append([x0, y0, x1 - x0 + 1, y1 - y0 + 1])
    if len(boxes) != 48:
        raise ValueError(f'{path.name}: expected 48 separate sprites, found {len(boxes)}; inspect before accepting')
    boxes.sort(key=lambda box: box[1] + box[3])
    frames = []
    for row in range(8):
        entries = sorted(boxes[row * 6:(row + 1) * 6], key=lambda box: box[0] + box[2] / 2)
        for box in entries:
            x, y, w, h = box
            # Ground contact center from the lowest body pixels, rather than
            # the whole silhouette (which includes an extended weapon).
            feet = [xx for yy in range(y + h - max(2, int(h * .09)), y + h)
                    for xx in range(x, x + w) if alpha[yy * width + xx] > 100]
            anchor_x = round((min(feet) + max(feet)) / 2 - x, 2)
            frames.append(box + [anchor_x])
    return {'size': [width, height], 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'frames': frames}


def main():
    data = {}
    for path in sorted(ROOT.glob('*.png')):
        data[path.stem] = measure(path)
        print(f'{path.name}: 48 transparent sprite regions')
    serialized = json.dumps(data, indent=2)
    (ROOT / 'regions.json').write_text(serialized + '\n')
    (ROOT / 'regions.gd').write_text('extends RefCounted\n## Generated alpha bounds; PNG pixels are unchanged.\nconst DATA: Dictionary = ' + serialized + '\n')


if __name__ == '__main__':
    main()
