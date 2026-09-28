"""Shared head for the heroines: the traveler's face with a high silver ponytail.

Characters set PALETTE["tie"] to their hair-tie colour."""
import math
import random

from mathutils import Vector

from characters.wanderer import build_face


def build_head(b):
    build_face(b, lashes=1.25)
    b.sphere("hair_cap", "head", "hair", (0, 0.04, 1.16), (0.255, 0.24, 0.195), segments=24)
    rng = random.Random(23)

    def lock(name, root, direction, length, width, bone="head"):
        d = Vector(direction).normalized()
        b.segment(name, bone, "hair", root, root + d * length, width, width * 0.15,
                  segments=10, scale_x=1.5, outline=0.7)

    # Smooth crown swept back into the tie; locks lie flatter than the boys'.
    centre = Vector((0, 0.04, 1.16))
    for i in range(16):
        angle = math.radians(-110.0 + i * (220.0 / 15))
        out = Vector((math.sin(angle), math.cos(angle), 0.0))
        root = centre + Vector((out.x * 0.2, out.y * 0.19, 0.09 + rng.uniform(-0.02, 0.02)))
        lock(f"swept_{i}", root, out * 0.4 + Vector((0, 0.6, 0.25)), rng.uniform(0.1, 0.13), 0.05)
    # Bangs parted a little to the character's right, and long side locks.
    for i, x in enumerate((0.15, 0.08, 0.01, -0.06, -0.13)):
        root = Vector((x + 0.04, -0.17 - 0.03 * math.cos(x * 5), 1.28))
        lock(f"bang_{i}", root, (-0.4, -0.3, -1.0), rng.uniform(0.12, 0.14) - abs(x) * 0.15, 0.05)
    for side, sx in (("L", 1.0), ("R", -1.0)):
        lock(f"side_lock_{side}", Vector((0.2 * sx, -0.09, 1.16)), (0.06 * sx, -0.12, -1.0), 0.24, 0.05)
    # High ponytail: the tie at the back of the crown, a long tail falling
    # down the back with its tip curling out.
    b.sphere("tie", "head", "tie", (0, 0.2, 1.3), (0.05, 0.045, 0.045), segments=12)
    points = [Vector((0, 0.24, 1.3)), Vector((0, 0.33, 1.26)), Vector((0.02, 0.38, 1.14)),
              Vector((0.03, 0.38, 1.0)), Vector((0.01, 0.34, 0.88))]
    widths = [0.075, 0.085, 0.08, 0.065, 0.04]
    for i in range(len(points) - 1):
        b.segment(f"ponytail_{i}", "head", "hair", points[i], points[i + 1], widths[i], widths[i + 1],
                  segments=12, scale_x=1.3, outline=0.8)
    lock("ponytail_tip", points[-1], (0.1, -0.2, -1.0), 0.08, 0.04)
