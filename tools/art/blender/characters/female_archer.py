"""The heroine archer, empty-handed (assets/generated/town/female_archer.png)."""
from characters import archer, heroine
from characters.wanderer import build_legs

PALETTE = {**archer.PALETTE, "tie": (0.2, 0.34, 0.18)}


def build(b):
    build_legs(b)
    archer.build_arms(b)
    archer.build_tunic(b)
    heroine.build_head(b)
