# Ruin ground material

The surrounding `RuinGround` previously used a uniform purple-gray material.
`shaders/ruin_soil.gdshader` now combines fixed world-space dust variation,
fine grit and sparse clustered angular chips. It samples the project's existing
original limestone albedo for subtle mineral variation. No new third-party
asset or raster image was introduced.

The first visual iteration produced overly regular bright dots. The accepted
iteration lowers their contrast and density, varies their size and groups them
with a larger noise field. World-space sampling is quantized at 64 samples per
meter; there is no animated noise, alpha transparency or added mesh geometry.

The 34 × 0.7 × 32 m ground box, collision top, dirt footsteps, raised court
dimensions, paths and map transitions are unchanged. The three courts now use
`ruin_court.gdshader` for irregular soil accumulation along their edges. Both
materials share `ruin_soil_common.gdshaderinc`, so their soil pixels agree in
world space and retain the same renderer color-space handling. Court stone
textures retain their previous UV scale. Neighbor footprints come from the
actual meshes via `RuinSurfaces`, reducing false soil seams at overlaps.

Thin court slabs no longer cast a sharp perimeter shadow; their tiny side faces
use an upward shading normal to read as a soil-covered lip. Heights and collision
remain untouched. This is a material transition, not broken-edge geometry or
terrain deformation. Sparse ruin dressing and full composition remain pending.
The quest shard now has a dedicated reward display
(see `docs/MOON_SHARD.md`), but the ruins are not fully accepted.

Verification: `godot --headless --path . --script tests/ruin_soil_test.gd` checks
actual map material routing, court footprints/neighbors, dimensions, collision,
stone texture scales and untouched village material. Both renderer screenshots were inspected separately; this
structural test alone does not establish visual quality or GPU performance.
Running the same test without `--headless` also samples an exposed ground patch
in the real ruins view and rejects near-black / overbright rendering. Run this
on both renderers; it is a luminance regression guard, not full visual approval.

Fixed pigment values are authored in linear space. The shader converts them
to sRGB for Compatibility and normalizes the mineral sample before mixing,
using the renderer's `OUTPUT_IS_SRGB` flag. Without this, actual Compatibility
captures rendered the new soil almost black. See the official
[Godot spatial shader reference](https://docs.godotengine.org/en/4.6/tutorials/shaders/shader_reference/spatial_shader.html).
