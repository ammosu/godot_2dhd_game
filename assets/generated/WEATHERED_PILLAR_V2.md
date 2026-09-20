# Fractured limestone pillar v2

Original asset, 2026-09-20. Replaces the active village/ruin column model while
preserving `weathered_pillar.glb` and its old texture. The new files are:

- `weathered_pillar_v2.glb`: original Blender 5.2.1 mesh, one material/mesh,
  284 triangles after edge chamfers, ground origin, less than 0.49 m radial
  envelope, shallow asymmetric crown reaching approximately 1.94 m.
- `pillar_lichen_albedo.png`: original built-in imagegen output.
- `weathered_pillar_v2_pillar_lichen_albedo.png`: Godot's extracted GLB texture.
- `tools/art/build_weathered_pillar_v2.py`: reproducible Blender source.

Asset sourcing followed dream-loop: external assets were not authorized;
`FAL_KEY` was absent; local Blender was available. A separate background
Blender process was used, leaving the user's live scene untouched. No downloaded
third-party model or texture was added.

```bash
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python tools/art/build_weathered_pillar_v2.py
```

The script exports only its own selected objects. It creates an irregular
twelve-sided limestone mass with tapered/chipped sides, a shallow fractured
crown and dominant-axis UV projection. The first eight-sided deep-crown draft
looked like a concrete slab in-game; independent review led to the rounder
section, shallow break and larger texture patches. This is not a scan or
individual masonry reconstruction.

## Image generation prompt

Mode: built-in imagegen. Existing `.dream-loop/target.png` was a style reference,
not an edit target. Final source: `exec-1c3d4319-a3a7-4fec-a081-7ab7908d6320.png`.

> Use case: stylized-concept. Asset: original seamless stone albedo texture for the weathered upright stone pillars in this HD2D village. Image 1 is STYLE REFERENCE ONLY. Produce a square opaque 1024x1024 tileable material texture, perfectly flat front-on, filling entire frame. Cool medium gray aged limestone, broken mineral flecks and subtle cracks, chipped mottled surfaces, irregular patches of subdued moss and lichen covering about 20 percent. Chunky crisp pixel-painted color clusters matching the reference's stone pillars. No masonry grid, no individual cobblestones, no brick outlines, no sculpted object or pillar silhouette, no horizon, no ground, no directional light, no cast shadows, no glow, no text. Neutral albedo only for game-engine lighting. Moderate contrast; moss restrained muted olive/blue green, stone medium gray with pale chipped flecks, not bright white.

## Integration and limits

Four village and eight ruin columns use deterministic rotations, nearest
texture filtering and the existing separate cylinder collider (radius 0.5 m,
height 2.0 m). The low footing and foreground cutaway remain unchanged. Four
small original grass sprites soften each base without new collision; their
entire canvas stays below the upper-geometry cutaway threshold.

`pillar_art_test.gd` checks textured import, finite vertices, collider envelope,
ground/height, non-degenerate triangles, varied crown, both map counts,
rotation variation, nearest filtering and cleanup. The existing foreground
test checks occlusion, restoration and the persistent low footing.

Independent whole-village review moved 6.7 → 6.8 → 7.0/10. The deep V/slab
problem was resolved without material regression. Remaining gaps include a
clean exposed base edge, finer silhouette variation, broader village lighting
and layout; this is not whole-scene approval.
