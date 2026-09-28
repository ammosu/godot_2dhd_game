"""The silver-haired traveler (assets/generated/wanderer_steady_walk.png)."""
import math
import random

from mathutils import Vector

PALETTE = {
    "skin": (0.98, 0.78, 0.62), "blush": (0.98, 0.70, 0.60), "hair": (0.70, 0.68, 0.71),
    "coat": (0.20, 0.33, 0.39), "cream": (0.91, 0.85, 0.70), "tunic": (0.90, 0.86, 0.74),
    "leather": (0.52, 0.30, 0.15), "leather_dark": (0.33, 0.19, 0.10), "boot": (0.60, 0.37, 0.19),
    "pants": (0.19, 0.18, 0.20), "iris": (0.60, 0.33, 0.12), "pupil": (0.22, 0.10, 0.05),
    "lash": (0.16, 0.09, 0.07), "white": (1.0, 0.98, 0.94), "gold": (0.88, 0.66, 0.24),
    "sheath": (0.16, 0.17, 0.21), "brow": (0.42, 0.39, 0.42), "mouth": (0.62, 0.34, 0.28),
}

def build_limbs(b):
    for side, sx in (("L", 1.0), ("R", -1.0)):
        x = 0.085 * sx
        b.segment(f"thigh_{side}", f"thigh.{side}", "pants", (x, 0, 0.47), (x, 0, 0.27), 0.07, 0.06)
        b.segment(f"shin_{side}", f"shin.{side}", "pants", (x, 0, 0.28), (x, 0, 0.21), 0.057)
        # Tall boot with a fold-over cuff and a darker sole.
        b.segment(f"boot_shaft_{side}", f"shin.{side}", "boot", (x, 0, 0.215), (x, 0, 0.05), 0.066, 0.063)
        b.segment(f"boot_cuff_{side}", f"shin.{side}", "leather", (x, 0, 0.245), (x, 0, 0.195), 0.078, 0.075)
        b.sphere(f"boot_foot_{side}", f"foot.{side}", "boot", (x, -0.04, 0.05), (0.072, 0.115, 0.052))
        b.sphere(f"boot_sole_{side}", f"foot.{side}", "leather_dark", (x, -0.04, 0.016), (0.074, 0.118, 0.018), outline=0.7)
        # Puffed teal sleeve, thick cream band, leather bracer, bare fist.
        b.sphere(f"shoulder_{side}", f"upper_arm.{side}", "coat", (0.19 * sx, 0, 0.775), (0.088, 0.085, 0.08))
        b.segment(f"sleeve_{side}", f"upper_arm.{side}", "coat", (0.20 * sx, 0, 0.80), (0.222 * sx, 0, 0.645), 0.077, 0.074)
        b.segment(f"sleeve_band_{side}", f"forearm.{side}", "cream", (0.222 * sx, 0, 0.66), (0.226 * sx, 0, 0.598), 0.084, 0.082)
        b.segment(f"bracer_{side}", f"forearm.{side}", "leather", (0.226 * sx, 0, 0.60), (0.232 * sx, -0.004, 0.53), 0.07, 0.064)
        b.segment(f"bracer_strap_{side}", f"forearm.{side}", "leather_dark", (0.229 * sx, -0.002, 0.575), (0.23 * sx, -0.003, 0.56), 0.073, outline=0.5)
        b.sphere(f"fist_{side}", f"forearm.{side}", "skin", (0.236 * sx, -0.012, 0.49), (0.062, 0.062, 0.064))


def build_coat(b):
    b.segment("neck", "chest", "skin", (0, 0, 0.84), (0, 0, 0.93), 0.06)
    b.segment("belly", "spine", "coat", (0, 0, 0.46), (0, 0, 0.71), 0.166, 0.176)
    b.sphere("chest", "chest", "coat", (0, 0, 0.72), (0.205, 0.158, 0.15))
    # Open front: the cream tunic shows between the coat edges.
    b.segment("tunic_upper", "chest", "tunic", (0, -0.152, 0.82), (0, -0.176, 0.60), 0.06, 0.064, outline=0.6, segments=4, scale_x=0.8)
    b.segment("tunic_lower", "spine", "tunic", (0, -0.176, 0.60), (0, -0.182, 0.46), 0.07, outline=0.6, segments=4, scale_x=0.8)
    for side, sx in (("L", 1.0), ("R", -1.0)):
        # Quarter skirts; the front pair leaves the tunic visible.
        front = (13.0, 92.0) if sx > 0 else (-92.0, -13.0)
        back = (88.0, 181.0) if sx > 0 else (-181.0, -88.0)
        for part, angles in (("front", front), ("back", back)):
            bone = f"skirt_{part}.{side}"
            b.panel(f"skirt_{part}_{side}", bone, "coat", angles, (0.53, 0.178), (0.30, 0.228))
            b.panel(f"skirt_hem_{part}_{side}", bone, "cream", angles, (0.325, 0.226), (0.298, 0.231), outline=0.6, thickness=0.014)
        edge = 13.0 * sx
        b.panel(f"skirt_edge_{side}", f"skirt_front.{side}", "cream", (edge, edge + 9.0 * sx), (0.53, 0.18), (0.30, 0.231), outline=0.5, thickness=0.014)
        b.panel(f"tunic_skirt_{side}", f"skirt_front.{side}", "tunic", (0.0, 14.0 * sx), (0.46, 0.174), (0.33, 0.2), outline=0.4, thickness=0.01)
    b.segment("belt", "spine", "leather", (0, 0, 0.52), (0, 0, 0.48), 0.184, outline=0.8, segments=18)
    b.segment("buckle", "spine", "gold", (0, -0.186, 0.522), (0, -0.186, 0.478), 0.03, outline=0.7, segments=4)
    b.segment("buckle_hole", "spine", "leather_dark", (0, -0.191, 0.51), (0, -0.191, 0.49), 0.013, outline=0.0, segments=4)
    b.segment("strap_front", "chest", "leather", (-0.14, -0.152, 0.81), (0.15, -0.17, 0.52), 0.02, outline=0.6, segments=4, scale_x=1.5)
    b.segment("strap_back", "chest", "leather", (-0.14, 0.152, 0.81), (0.15, 0.17, 0.52), 0.02, outline=0.6, segments=4, scale_x=1.5)
    b.sphere("hood", "chest", "coat", (0, 0.12, 0.84), (0.2, 0.1, 0.1))
    b.sphere("hood_lining", "chest", "cream", (0, 0.105, 0.87), (0.16, 0.07, 0.06), outline=0.5)
    # Bulky scarf: two wraps high on the neck, tails at the front and back.
    b.torus("scarf_low", "chest", "cream", (0, -0.005, 0.81), 0.13, 0.066, scale=(1.0, 0.95, 1.1))
    b.torus("scarf_high", "chest", "cream", (0, 0.0, 0.865), 0.105, 0.05, scale=(1.0, 0.95, 1.0))
    b.sphere("scarf_knot", "chest", "cream", (-0.045, -0.175, 0.79), (0.06, 0.04, 0.05), segments=12)
    b.sphere("scarf_tail", "chest", "cream", (-0.055, -0.19, 0.69), (0.058, 0.026, 0.1), segments=12)
    b.segment("scarf_fringe", "chest", "tunic", (-0.055, -0.196, 0.61), (-0.058, -0.2, 0.585), 0.05, outline=0.5, segments=4, scale_x=0.5)
    b.segment("scarf_back", "chest", "cream", (-0.08, 0.16, 0.86), (-0.1, 0.19, 0.64), 0.06, 0.066, outline=0.8, segments=4, scale_x=0.35)
    # Satchel behind the left hip, sword at the left hip with the hilt forward.
    b.sphere("satchel", "hips", "leather", (0.12, 0.21, 0.46), (0.09, 0.05, 0.08), segments=10)
    b.segment("satchel_flap", "hips", "boot", (0.12, 0.255, 0.53), (0.12, 0.262, 0.46), 0.064, outline=0.6, segments=4, scale_x=1.4)
    b.sphere("satchel_clasp", "hips", "gold", (0.12, 0.268, 0.47), (0.016, 0.008, 0.016), outline=0.5, segments=8)
    b.segment("sheath", "hips", "sheath", (0.175, -0.12, 0.50), (0.255, 0.07, 0.19), 0.026, 0.023, segments=8)
    b.segment("chape", "hips", "gold", (0.251, 0.061, 0.205), (0.258, 0.077, 0.178), 0.028, segments=8)
    b.segment("guard", "hips", "gold", (0.145, -0.13, 0.51), (0.205, -0.112, 0.50), 0.017, segments=6)
    b.segment("grip", "hips", "leather", (0.172, -0.123, 0.505), (0.158, -0.185, 0.585), 0.019, segments=6)
    b.sphere("pommel", "hips", "gold", (0.155, -0.19, 0.595), (0.028, 0.028, 0.028), segments=10)


def build_head(b):
    b.sphere("head", "head", "skin", (0, 0, 1.08), (0.235, 0.215, 0.215), segments=20)
    for side, sx in (("L", 1.0), ("R", -1.0)):
        b.sphere(f"ear_{side}", "head", "skin", (0.228 * sx, 0.0, 1.05), (0.03, 0.045, 0.055), outline=0.7)
        # Large round eyes: iris, pupil, glint and a heavy upper lash line.
        b.sphere(f"iris_{side}", "head", "iris", (0.085 * sx, -0.198, 1.035), (0.038, 0.014, 0.05), outline=0.0, segments=12)
        b.sphere(f"pupil_{side}", "head", "pupil", (0.085 * sx, -0.203, 1.03), (0.022, 0.012, 0.03), outline=0.0, segments=10)
        b.sphere(f"glint_{side}", "head", "white", (0.074 * sx, -0.212, 1.05), (0.012, 0.006, 0.014), outline=0.0, segments=8)
        b.segment(f"lash_{side}", "head", "lash", (0.042 * sx, -0.208, 1.08), (0.13 * sx, -0.186, 1.072), 0.011, outline=0.0, segments=4, scale_x=1.6)
        b.segment(f"brow_{side}", "head", "brow", (0.05 * sx, -0.205, 1.14), (0.125 * sx, -0.19, 1.135), 0.007, outline=0.0, segments=4, scale_x=1.7)
        b.sphere(f"blush_{side}", "head", "blush", (0.13 * sx, -0.178, 0.99), (0.022, 0.008, 0.009), outline=0.0, segments=8)
    b.segment("mouth", "head", "mouth", (-0.018, -0.214, 0.955), (0.018, -0.214, 0.955), 0.006, outline=0.0, segments=4, scale_x=1.4)
    # Hair: a cap set high and back so the face stays clear, then messy locks.
    # Hair: a full rounded volume set high and back so the face stays clear,
    # with pointed locks lying on it that make the jagged painted silhouette.
    b.sphere("hair_cap", "head", "hair", (0, 0.045, 1.165), (0.262, 0.248, 0.2), segments=24)
    rng = random.Random(11)
    centre = Vector((0, 0.045, 1.165))

    def lock(name, root, direction, length, width):
        d = Vector(direction).normalized()
        b.segment(name, "head", "hair", root, root + d * length, width, width * 0.12,
                  segments=10, scale_x=1.5, outline=0.7)

    # Rim locks around the sides and back, pointing down and out.
    for i in range(22):
        angle = math.radians(-100.0 + i * (200.0 / 21))  # 0 = back, +-100 = temples
        out = Vector((math.sin(angle), math.cos(angle), 0.0))
        root = centre + Vector((out.x * 0.23, out.y * 0.215, rng.uniform(-0.03, 0.03)))
        lock(f"rim_{i}", root, out * 0.55 + Vector((0, 0.1, -1.0)) + Vector((rng.uniform(-0.2, 0.2), 0, 0)),
             rng.uniform(0.1, 0.14), rng.uniform(0.045, 0.06))
    # Upper layer and crown: shorter locks lifting up and back.
    for i in range(14):
        angle = math.radians(-120.0 + i * (240.0 / 13))
        out = Vector((math.sin(angle), math.cos(angle), 0.0))
        root = centre + Vector((out.x * 0.17, out.y * 0.16 + 0.02, 0.13 + rng.uniform(-0.02, 0.02)))
        lock(f"upper_{i}", root, out * 0.9 + Vector((0, 0.2, 0.35)), rng.uniform(0.09, 0.12), rng.uniform(0.045, 0.055))
    for i, (x, y) in enumerate(((-0.09, 0.0), (0.03, -0.05), (0.11, 0.04), (-0.02, 0.1))):
        lock(f"crown_{i}", Vector((x, y + 0.045, 1.33)), (x * 3.0, y * 2.0 + 0.3, 1.0), rng.uniform(0.07, 0.1), 0.045)
    # Fringe swept to the character's right (screen left in the front view);
    # the tips stop above the brows.
    for i, x in enumerate((0.16, 0.09, 0.02, -0.05, -0.12)):
        root = Vector((x + 0.05, -0.165 - 0.035 * math.cos(x * 5), 1.285))
        lock(f"fringe_{i}", root, (-0.55, -0.3, -1.0), rng.uniform(0.12, 0.14) - abs(x) * 0.15, 0.05)
    for side, sx in (("L", 1.0), ("R", -1.0)):
        lock(f"sideburn_{side}", Vector((0.205 * sx, -0.08, 1.17)), (0.08 * sx, -0.15, -1.0), 0.14, 0.045)


def build(b):
    build_limbs(b)
    build_coat(b)
    build_head(b)
