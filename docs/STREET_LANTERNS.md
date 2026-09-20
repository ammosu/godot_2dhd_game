# Village street lanterns

The ten existing village lights now use original procedural geometry from
`scripts/gameplay/street_lantern.gd`: stepped octagonal foot, tapered post,
four corner bars, lower rails, pyramidal roof and finial. Each instance shares
two mesh batches and materials. Metal reuses the project's original
`moon_lamp_aged_bronze_albedo.png`; no additional third-party assets were added.

`shaders/lantern_glass.gdshader` provides opaque frosted amber panes with dark
edges and a restrained warm center. These are not transparent glass or a
simulated internal flame. This replaces the overexposed single emissive box.

All ten positions and the existing road light remain unchanged: local height
1.42 m, color `ffb968`, energy 3.2, range 4.5 m. No collision or interaction
was added. Both Forward+ and Compatibility village captures were inspected.

Run `godot --headless --path . --script tests/street_lantern_test.gd` to check
shared meshes, ground contact, pane normals and lighting values. This structural
test does not replace visual inspection of emission and bloom.
