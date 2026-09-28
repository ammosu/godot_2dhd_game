"""The traveler as an archer, empty-handed (assets/generated/town/archer.png)."""
from characters.wanderer import PALETTE as TRAVELER, build_head, build_legs

PALETTE = {
    **TRAVELER,
    "coat": (0.24, 0.38, 0.20), "coat_dark": (0.17, 0.28, 0.15), "glove": (0.56, 0.33, 0.16),
    "quiver": (0.58, 0.34, 0.16), "fletch": (0.93, 0.93, 0.90), "shaft": (0.45, 0.30, 0.18),
}


def build_arms(b):
    for side, sx in (("L", 1.0), ("R", -1.0)):
        # Short green sleeve, cream band on the upper arm, big gauntlet gloves.
        b.sphere(f"shoulder_{side}", f"upper_arm.{side}", "coat", (0.19 * sx, 0, 0.775), (0.085, 0.082, 0.078))
        b.segment(f"sleeve_{side}", f"upper_arm.{side}", "coat", (0.20 * sx, 0, 0.80), (0.214 * sx, 0, 0.715), 0.075, 0.073)
        b.segment(f"sleeve_band_{side}", f"upper_arm.{side}", "cream", (0.214 * sx, 0, 0.72), (0.219 * sx, 0, 0.67), 0.074, 0.072)
        b.segment(f"glove_cuff_{side}", f"forearm.{side}", "glove", (0.221 * sx, 0, 0.675), (0.225 * sx, -0.002, 0.63), 0.082, 0.078)
        b.segment(f"glove_{side}", f"forearm.{side}", "glove", (0.225 * sx, -0.002, 0.635), (0.232 * sx, -0.006, 0.54), 0.07, 0.066)
        b.segment(f"glove_strap_{side}", f"forearm.{side}", "leather_dark", (0.227 * sx, -0.003, 0.61), (0.228 * sx, -0.003, 0.595), 0.075, outline=0.5)
        b.sphere(f"fist_{side}", f"forearm.{side}", "glove", (0.236 * sx, -0.012, 0.49), (0.066, 0.066, 0.068))


def build_tunic(b):
    b.segment("neck", "chest", "skin", (0, 0, 0.84), (0, 0, 0.93), 0.06)
    b.segment("belly", "spine", "coat", (0, 0, 0.46), (0, 0, 0.71), 0.166, 0.176)
    b.sphere("chest", "chest", "coat", (0, 0, 0.72), (0.2, 0.155, 0.15))
    # Closed tunic skirt to mid-thigh with a cream hem.
    for side, sx in (("L", 1.0), ("R", -1.0)):
        front = (0.0, 92.0) if sx > 0 else (-92.0, 0.0)
        back = (88.0, 181.0) if sx > 0 else (-181.0, -88.0)
        for part, angles in (("front", front), ("back", back)):
            bone = f"skirt_{part}.{side}"
            b.panel(f"skirt_{part}_{side}", bone, "coat", angles, (0.53, 0.178), (0.33, 0.22))
            b.panel(f"skirt_hem_{part}_{side}", bone, "cream", angles, (0.35, 0.218), (0.328, 0.222), outline=0.6, thickness=0.014)
    b.segment("belt", "spine", "leather", (0, 0, 0.52), (0, 0, 0.48), 0.184, outline=0.8, segments=18)
    b.segment("buckle", "spine", "gold", (0, -0.186, 0.522), (0, -0.186, 0.478), 0.03, outline=0.7, segments=4)
    b.segment("buckle_hole", "spine", "leather_dark", (0, -0.191, 0.51), (0, -0.191, 0.49), 0.013, outline=0.0, segments=4)
    # Two straps crossing on the chest; the quiver strap runs down the back.
    b.segment("strap_a", "chest", "leather", (-0.14, -0.15, 0.80), (0.14, -0.172, 0.56), 0.018, outline=0.6, segments=4, scale_x=1.5)
    b.segment("strap_b", "chest", "leather", (0.14, -0.15, 0.80), (-0.14, -0.172, 0.56), 0.018, outline=0.6, segments=4, scale_x=1.5)
    # Short hooded capelet over the shoulders.
    b.panel("capelet", "chest", "coat", (-180.0, 180.0), (0.875, 0.13), (0.70, 0.24), thickness=0.02)
    b.panel("capelet_shade", "chest", "coat_dark", (-180.0, 180.0), (0.72, 0.232), (0.70, 0.242), outline=0.5, thickness=0.02)
    b.torus("cowl", "chest", "coat", (0, 0.0, 0.87), 0.11, 0.05, scale=(1.0, 0.95, 1.0))
    b.sphere("hood", "chest", "coat", (0, 0.14, 0.86), (0.17, 0.09, 0.11))
    # Quiver across the back: bottom at the left hip, arrows over the right shoulder.
    bottom, top = (0.13, 0.2, 0.46), (-0.14, 0.2, 0.98)
    b.segment("quiver", "chest", "quiver", bottom, top, 0.048, 0.052, segments=12)
    for i, z in enumerate((0.58, 0.86)):
        f = (z - bottom[2]) / (top[2] - bottom[2])
        at = tuple(bottom[k] + (top[k] - bottom[k]) * f for k in range(3))
        b.segment(f"quiver_band_{i}", "chest", "leather_dark", (at[0] + 0.01, at[1], at[2] - 0.012), (at[0] - 0.01, at[1], at[2] + 0.012), 0.054, outline=0.5, segments=12)
    for i, (dx, dy) in enumerate(((0.0, 0.0), (0.03, 0.02), (-0.025, 0.02), (0.01, -0.025))):
        root = (top[0] + dx, top[1] + dy, top[2] - 0.01)
        tip = (root[0] - 0.05, root[1], root[2] + 0.1)
        b.segment(f"arrow_{i}", "chest", "fletch", root, tip, 0.02, 0.012, outline=0.6, segments=6, scale_x=1.6)


def build(b):
    build_legs(b)
    build_arms(b)
    build_tunic(b)
    build_head(b)
