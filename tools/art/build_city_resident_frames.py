"""Measure the original NPC atlas and write resources without editing image pixels.

Run: python3 tools/art/build_city_resident_frames.py (Pillow and NumPy required).
"""
from pathlib import Path
import numpy as np
from PIL import Image

ART = Path(__file__).resolve().parents[2] / "assets/generated/city_residents"
IDENTITIES = ["tea_master", "ronin", "shrine_keeper", "shinobi",
              "lantern_maker", "musician", "pilgrim", "silk_merchant",
              "spice_merchant", "astronomer", "sailor", "blacksmith",
              "scholar", "apothecary", "clockmaker", "ranger"]


def build() -> None:
    with Image.open(ART / "city_residents.png") as source:
        assert source.mode == "RGBA"
        width, height = source.size
        alpha = np.asarray(source)[:, :, 3]
    assert np.count_nonzero(alpha == 0) > width * height * 0.4
    mask = alpha >= 64
    for col in range(4):
        left, right = col * width // 4, (col + 1) * width // 4
        active = mask[:, left:right].sum(axis=1) > 2
        edges = np.flatnonzero(np.diff(np.r_[False, active, False]))
        runs = list(zip(edges[::2], edges[1::2]))
        assert len(runs) == 4, f"Column {col}: expected four separate bodies"
        for row, (top, bottom) in enumerate(runs):
            band_top = 0 if row == 0 else (runs[row-1][1] + top) // 2
            band_bottom = height if row == 3 else (bottom + runs[row+1][0]) // 2
            yy, xx = np.nonzero(mask[band_top:band_bottom, left:right])
            x0, x1 = left + int(xx.min()) - 2, left + int(xx.max()) + 3
            y0, y1 = band_top + int(yy.min()) - 2, band_top + int(yy.max()) + 3
            assert left < x0 < x1 < right and band_top <= y0 < y1 <= band_bottom
            w, h = x1 - x0, y1 - y0
            feet = np.nonzero(mask[bottom-8:bottom, left:right])[1]
            pivot = left + (int(feet.min()) + int(feet.max()) + 1) / 2
            name = IDENTITIES[row * 4 + col]
            resource = f'''[gd_resource type="AtlasTexture" load_steps=2 format=3]

[ext_resource type="Texture2D" path="res://assets/generated/city_residents/city_residents.png" id="1"]

[resource]
atlas = ExtResource("1")
region = Rect2({x0}, {y0}, {w}, {h})
margin = Rect2({256 - (pivot - x0)}, {490 - (bottom - y0)}, {512-w}, {512-h})
filter_clip = true
metadata/ground_y = 490.0
metadata/reference_height = {float(bottom-top)}
'''
            (ART / f"{name}.tres").write_text(resource)
            print(f"{name}: {w}x{h}, grounded at 490")


if __name__ == "__main__":
    build()
