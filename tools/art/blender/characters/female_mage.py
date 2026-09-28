"""The heroine mage, empty-handed (assets/generated/town/female_mage.png)."""
from characters import heroine, mage
from characters.wanderer import build_legs

PALETTE = {**mage.PALETTE, "boot": (0.2, 0.18, 0.24), "tie": (0.3, 0.45, 0.85)}


def build(b):
    build_legs(b)
    mage.build_arms(b)
    mage.build_robe(b, hem=0.27, hem_radius=0.235)
    heroine.build_head(b)
