"""Render one character's walk frames. Run inside Blender 5.x (headless):
    Blender -b --factory-startup -P tools/art/blender/render_character.py -- <character> <out_dir> [scene.blend]

<character> names a module in characters/. See rig_common.render().
"""
import importlib
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import rig_common  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:]
rig_common.render(importlib.import_module(f"characters.{argv[0]}"), Path(argv[1]), argv[2] if len(argv) > 2 else "")
