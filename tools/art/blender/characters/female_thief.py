"""The heroine thief, empty-handed (assets/generated/town/female_thief.png)."""
from characters import heroine, thief
from characters.wanderer import build_legs

PALETTE = {**thief.PALETTE, "tie": (0.5, 0.14, 0.16)}


def build(b):
    build_legs(b)
    thief.build_arms(b)
    thief.build_jerkin(b)
    heroine.build_head(b)
