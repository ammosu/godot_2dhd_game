# Foreground house cutaway

`scripts/gameplay/foreground_cutaway.gd` is attached to each village house after
its geometry is built. Five camera-to-player segments sample feet, torso, head
and torso width. Fully billboarded character art adds five matching samples in
the camera-facing plane: its tilted head can intersect a facade behind the
vertical collision body. A house-local aggregate AABB rejects distant houses, then
cached per-part AABBs identify possible occluders. These conservative bounds
are not triangle-accurate silhouette tests.

When obstructing, geometry above 0.45 m changes to shadows-only rendering.
Originally non-shadow-casting geometry is instead hidden, without creating new
shadows. Low foundations and thresholds remain visible; all colliders and
entrances are untouched. This is an immediate architectural cutaway, not an
alpha fade or an exterior view of the separately loaded furnished interior.
Low foundations can still cover the very bottom of the player's feet.

Restoration waits for 0.22 seconds of continuously clear sightline, avoiding
rapid on/off changes at an edge. Obstruction clears that timer immediately.
Original shadow/visibility settings are restored when clear or when the
controller exits the tree. Controllers are map-owned and disappear indoors.
Only houses participate; trees and other scenery are outside this pass.

`HouseDetails` explicitly assigns the roof MultiMesh's custom AABB from the
authored tile transforms. Renderer-derived bounds and instance-buffer reads can
be empty/identity during construction, so they are unsuitable for this cache.
The custom bounds also make the roof's culling extent explicit.

## Verification

- `godot --headless --path . --script tests/foreground_cutaway_test.gd`
  checks restoration delay, original shadow settings, retained base, all 192
  combinations of eight house entrances / eight angles / three zoom distances,
  roof-tile cutaway state, entrance monitoring and map cleanup.
  It also repeats twelve interrupted clear-sight intervals to verify that the
  restore timer resets, and removes the camera while occluded to verify that
  original visibility and shadow settings recover during teardown.
  A fixed regression places the player at house 07's return spawn at 45 degrees
  and requires house 04's facade to be detected. This assertion failed before
  adding billboard-plane rays; hiding trees did not remove the visible face
  triangle, while hiding the neighboring house did. Final Forward+ and
  Compatibility entrance captures confirm the face is unobstructed, with the
  low foundation and scenery shadows preserved.
- Run `tests/house_exterior_test.gd` without headless, with
  `-- --emblem-capture --mute-audio`, on both renderers for actual images.
  House 01 and 07 reproduce the previously obstructed angles.
- The 192-view sweep is a structural test, not 192 visually accepted screenshots.
  Actual captures confirm removal of the tall foreground house silhouettes,
  while the foundation and original building shadow remain visible.
- `tests/house_interior_test.gd` separately covers all eight visit/return flows.

No camera controls, movement, save schema, renderer selection or materials are
replaced. Broader environment visual acceptance is still pending.
