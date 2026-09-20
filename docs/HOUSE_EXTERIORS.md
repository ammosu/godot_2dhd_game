# House-specific exterior dressing

The garden house (`house_02`) now has two original timber window boxes with
six flower clusters using the existing original `flowers_mauve.tres` atlas.
The pottery house (`house_04`) has two wall-mounted timber shelves with six
scaled instances of the existing original earthenware jar model.
The traveler's home (`house_06`) has an octagonal compass plaque, and the north
library (`house_08`) has an open-book relief with separate page blocks, spine,
raised text-line strips and bookmark. Both are original procedural meshes built by
`scripts/gameplay/house_emblem.gd`, mounted at 2.43 m on the front gable. These
are decorative identity markers, not interactive shops or navigation controls.

The remaining original reliefs are built by `scripts/gameplay/craft_emblems.gd`:

| Home | Exterior theme | Geometry |
| --- | --- | --- |
| house_01 | Weaving | Small loom with seven warp threads and alternating raised weft |
| house_03 | Moon records | Full moon and two opposing tapered crescents |
| house_05 | Textile patterns | Four colored cloth blocks and raised stitch strips |
| house_07 | Field notes | Stem and six low-poly leaf reliefs |

All six gable emblems use the same mounting height and existing timber backing.
They introduce no new image assets. Moon tips omit degenerate triangles; tests
check front-facing normals and mesh bounds above the doorway canopy.

`scripts/gameplay/house_exterior.gd` owns this reusable presentation. Shelf tops
are at 0.76 m, with supports against the wall. Low decorations stay to either
side of the central entrance; gable emblems sit above the door canopy.
No new interaction, collider, save field, texture
or third-party asset is introduced. All eight houses now have theme dressing,
but their main architecture still shares one form; dressing alone does not
complete the village architecture pass.

Run `godot --headless --path . --script tests/house_exterior_test.gd` for theme,
instance-count and entrance-clearance checks. Actual renderer captures and the
eight-house visit test complement these structural checks.

For all six gable-emblem screenshots, run the test without `--headless` and append
`-- --emblem-capture --mute-audio`. Images are written to ignored
`.dream-loop/emblem-house_{01,03,05,06,07,08}-{renderer}.png`. Run with both `forward_plus`
and `gl_compatibility`; structural assertions check both book halves and all
16 outward-facing compass relief triangles but do not prove visual quality.

## Foreground visibility follow-up

Earlier captures showed neighboring roofs occluding the player near house_01
and house_07. The runtime foreground cutaway now removes tall obstructing house
geometry while preserving foundations, shadows and interactions. See
`docs/FOREGROUND_CUTAWAY.md` for tests and limits. Captures use the runtime rule,
not manually hidden houses. Overall environment acceptance remains pending.
