# Fallen masonry around ruin columns

`scripts/gameplay/ruin_rubble.gd` creates an original chipped six-sided masonry
fragment with a sloped, uneven top (20 triangles). Scaled/yaw-rotated instances
share one MultiMesh and the existing original limestone texture. There are no
new imported images or third-party assets.

Placement uses a fixed local seed and the existing eight column positions.
Fragments sit on the real ground/court height, avoid court height discontinuities
by 0.30 m, and keep 1.2 m clear around the tablet and spring. Their maximum local
height is 0.136 m. They are decorative: no new collision, loot or gameplay state.
Explicit batch bounds are built from the authored transforms, not asynchronous
renderer state. The village is unchanged.

Run `godot --headless --path . --script tests/ruin_rubble_test.gd` for outward
normals, base height, clearance, repeatable placement, batch bounds and map cleanup.
Actual ruins captures on both renderers supplement those structural checks.
This small dressing pass does not establish complete ruin composition or
performance acceptance.
