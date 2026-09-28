"""The traveler as a mage, empty-handed (assets/generated/town/mage.png)."""
import math

from characters.wanderer import PALETTE as TRAVELER, build_head, build_legs

PALETTE = {
    **TRAVELER,
    "coat": (0.17, 0.21, 0.46), "coat_dark": (0.12, 0.15, 0.34), "cream": (0.90, 0.90, 0.93),
    "scarf": (0.86, 0.87, 0.91), "glove": (0.22, 0.20, 0.25), "boot": (0.15, 0.18, 0.38),
    "leather": (0.20, 0.23, 0.45), "ice": (0.62, 0.86, 0.96),
}


def build_arms(b):
    for side, sx in (("L", 1.0), ("R", -1.0)):
        # Wide robe sleeves flaring toward white cuffs; dark gloves.
        b.sphere(f"shoulder_{side}", f"upper_arm.{side}", "coat", (0.19 * sx, 0, 0.775), (0.088, 0.085, 0.08))
        b.segment(f"sleeve_{side}", f"upper_arm.{side}", "coat", (0.20 * sx, 0, 0.80), (0.222 * sx, 0, 0.645), 0.077, 0.08)
        b.segment(f"sleeve_flare_{side}", f"forearm.{side}", "coat", (0.222 * sx, 0, 0.66), (0.232 * sx, -0.006, 0.555), 0.082, 0.1)
        b.segment(f"cuff_{side}", f"forearm.{side}", "cream", (0.232 * sx, -0.006, 0.565), (0.233 * sx, -0.007, 0.54), 0.102, outline=0.6)
        b.sphere(f"fist_{side}", f"forearm.{side}", "glove", (0.236 * sx, -0.012, 0.495), (0.058, 0.058, 0.06))


def build_robe(b, hem=0.1, hem_radius=0.26):
    b.segment("neck", "chest", "skin", (0, 0, 0.84), (0, 0, 0.93), 0.06)
    b.segment("belly", "spine", "coat", (0, 0, 0.46), (0, 0, 0.71), 0.166, 0.176)
    b.sphere("chest", "chest", "coat", (0, 0, 0.72), (0.205, 0.158, 0.15))
    for side, sx in (("L", 1.0), ("R", -1.0)):
        b.segment(f"robe_trim_{side}", "chest", "cream", (0.035 * sx, -0.156, 0.82), (0.045 * sx, -0.182, 0.47), 0.014, outline=0.5, segments=4)
        # Robe quarters to the ankles; the front pair parts a little for the stride.
        front = (6.0, 92.0) if sx > 0 else (-92.0, -6.0)
        back = (88.0, 181.0) if sx > 0 else (-181.0, -88.0)
        for part, angles in (("front", front), ("back", back)):
            bone = f"skirt_{part}.{side}"
            b.panel(f"robe_{part}_{side}", bone, "coat", angles, (0.53, 0.178), (hem, hem_radius))
            b.panel(f"robe_hem_{part}_{side}", bone, "cream", angles, (hem + 0.03, hem_radius - 0.004), (hem, hem_radius + 0.002), outline=0.6, thickness=0.014)
            # Gold stars embroidered above the hem.
            a = sum(angles) * 0.5
            r, z = hem_radius - 0.01, hem + 0.09
            b.sphere(f"star_{part}_{side}", bone, "gold", (math.sin(math.radians(a)) * (r + 0.012), -math.cos(math.radians(a)) * (r + 0.012), z),
                     (0.02, 0.02, 0.02), outline=0.0, segments=8)
        b.panel(f"robe_edge_{side}", f"skirt_front.{side}", "cream", (6.0 * sx, 13.0 * sx), (0.53, 0.18), (hem, hem_radius + 0.002), outline=0.5, thickness=0.014)
        b.panel(f"robe_inner_{side}", f"skirt_front.{side}", "coat_dark", (0.0, 8.0 * sx), (0.5, 0.17), (hem + 0.02, hem_radius - 0.03), outline=0.3, thickness=0.01)
    b.segment("belt", "spine", "leather", (0, 0, 0.52), (0, 0, 0.485), 0.184, outline=0.8, segments=18)
    b.sphere("brooch", "chest", "ice", (0, -0.165, 0.77), (0.035, 0.012, 0.035), outline=0.6, segments=10)
    # Pale hooded scarf wrapped at the neck, hood lying on the back.
    b.torus("scarf_low", "chest", "scarf", (0, -0.005, 0.815), 0.13, 0.064, scale=(1.0, 0.95, 1.1))
    b.torus("scarf_high", "chest", "scarf", (0, 0.0, 0.87), 0.105, 0.05)
    b.sphere("hood", "chest", "scarf", (0, 0.14, 0.85), (0.18, 0.1, 0.11))


def build(b):
    build_legs(b)
    build_arms(b)
    build_robe(b)
    build_head(b)
