"""The traveler as a thief, empty-handed (assets/generated/town/thief.png)."""
from characters.wanderer import PALETTE as TRAVELER, build_head, build_legs

PALETTE = {
    **TRAVELER,
    "coat": (0.31, 0.27, 0.28), "coat_dark": (0.22, 0.19, 0.20), "steel": (0.74, 0.74, 0.78),
    "scarf": (0.38, 0.23, 0.44), "glove": (0.26, 0.20, 0.19), "boot": (0.37, 0.23, 0.26),
    "leather": (0.46, 0.30, 0.20),
}


def build_arms(b):
    for side, sx in (("L", 1.0), ("R", -1.0)):
        # Leather sleeves with steel bands at the shoulder and forearm; dark gloves.
        b.sphere(f"pauldron_{side}", f"upper_arm.{side}", "steel", (0.19 * sx, 0, 0.785), (0.09, 0.087, 0.075))
        b.segment(f"sleeve_{side}", f"upper_arm.{side}", "coat", (0.20 * sx, 0, 0.78), (0.222 * sx, 0, 0.645), 0.072, 0.07)
        b.segment(f"elbow_band_{side}", f"forearm.{side}", "steel", (0.222 * sx, 0, 0.655), (0.225 * sx, 0, 0.62), 0.076)
        b.segment(f"vambrace_{side}", f"forearm.{side}", "coat_dark", (0.225 * sx, 0, 0.625), (0.232 * sx, -0.004, 0.54), 0.068, 0.064)
        b.segment(f"wrist_band_{side}", f"forearm.{side}", "steel", (0.231 * sx, -0.004, 0.565), (0.232 * sx, -0.004, 0.548), 0.07, outline=0.5)
        b.sphere(f"fist_{side}", f"forearm.{side}", "glove", (0.236 * sx, -0.012, 0.49), (0.064, 0.064, 0.066))


def build_jerkin(b, skirt_hem=0.38):
    b.segment("neck", "chest", "skin", (0, 0, 0.84), (0, 0, 0.93), 0.06)
    b.segment("belly", "spine", "coat", (0, 0, 0.46), (0, 0, 0.71), 0.164, 0.174)
    b.sphere("chest", "chest", "coat", (0, 0, 0.72), (0.2, 0.155, 0.15))
    b.segment("chest_seam", "chest", "coat_dark", (0, -0.155, 0.82), (0, -0.178, 0.5), 0.012, outline=0.4, segments=4)
    for side, sx in (("L", 1.0), ("R", -1.0)):
        front = (0.0, 92.0) if sx > 0 else (-92.0, 0.0)
        back = (88.0, 181.0) if sx > 0 else (-181.0, -88.0)
        for part, angles in (("front", front), ("back", back)):
            bone = f"skirt_{part}.{side}"
            b.panel(f"skirt_{part}_{side}", bone, "coat", angles, (0.53, 0.176), (skirt_hem, 0.21))
            b.panel(f"skirt_hem_{part}_{side}", bone, "steel", angles, (skirt_hem + 0.018, 0.209), (skirt_hem, 0.211), outline=0.5, thickness=0.012)
    b.segment("belt", "spine", "leather", (0, 0, 0.52), (0, 0, 0.48), 0.184, outline=0.8, segments=18)
    b.segment("buckle", "spine", "steel", (0, -0.186, 0.522), (0, -0.186, 0.478), 0.028, outline=0.7, segments=4)
    for side, sx in (("L", 1.0), ("R", -1.0)):
        b.sphere(f"pouch_{side}", "spine", "leather", (0.13 * sx, -0.13, 0.47), (0.04, 0.03, 0.045), segments=10)
    # Purple scarf high on the neck and a short cape behind the shoulders.
    b.torus("scarf_low", "chest", "scarf", (0, -0.005, 0.815), 0.13, 0.062, scale=(1.0, 0.95, 1.1))
    b.torus("scarf_high", "chest", "scarf", (0, 0.0, 0.87), 0.105, 0.05)
    b.panel("cape", "chest", "scarf", (95.0, 265.0), (0.85, 0.17), (0.5, 0.25), thickness=0.016)


def build(b):
    build_legs(b)
    build_arms(b)
    build_jerkin(b)
    build_head(b)
