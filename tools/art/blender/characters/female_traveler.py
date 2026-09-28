"""The heroine traveler (assets/generated/town/female_traveler.png)."""
from characters import heroine
from characters.wanderer import PALETTE as TRAVELER, build_arms, build_coat, build_legs

PALETTE = {**TRAVELER, "coat": (0.19, 0.25, 0.44), "tie": (0.16, 0.2, 0.42)}


def build(b):
    build_legs(b)
    build_arms(b)
    build_coat(b, scarf=False, gear=False)
    heroine.build_head(b)
