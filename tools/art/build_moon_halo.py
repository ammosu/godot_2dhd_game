"""Original open lunar monument; run in an isolated Blender factory scene."""
import math
import runpy
from pathlib import Path
import bpy

PROJECT_ROOT = str(Path(__file__).resolve().parents[2])
base = runpy.run_path(str(Path(__file__).with_name("build_moon_lamp.py")), init_globals={"PROJECT_ROOT": PROJECT_ROOT})
# Reuse the authored stone tiers and mapped mineral, not the enclosed cage.
for name in ("MoonLampBronzework", "MoonLampPatinaPanels"):
    bpy.data.objects.remove(bpy.data.objects[name], do_unlink=True)
geometry = ([], [])
base["lathe"](geometry, [(0.32, .43), (.27, .55), (.19, 1.12), (.08, 1.48)], 5)
base["mesh_object"]("MoonLampPatinaPanels", geometry, base["stone"])
geometry = ([], [])
# Vertical ring faces the default diagonal camera, but has real depth at all angles.
direction = (math.sqrt(.5), math.sqrt(.5))
points = [(direction[0] * .56 * math.cos(i * math.tau / 64),
           direction[1] * .56 * math.cos(i * math.tau / 64),
           1.70 + .56 * math.sin(i * math.tau / 64)) for i in range(65)]
base["tube"](geometry, points, .023, 6)
base["mesh_object"]("MoonLampBronzework", geometry, base["bronze"])
core = bpy.data.objects["MoonLampCore"]
core.location.z = 1.64
core.scale = (1.7, 1.0, 1.65)
core.rotation_euler = (.5, -.75, .3)
base["export_moon_lamp"](Path(PROJECT_ROOT) / "assets/generated/moon_halo.glb")
