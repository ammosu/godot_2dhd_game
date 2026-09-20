# Layered garden borders v1

Original generated asset, 2026-09-20. Built-in imagegen mode; no downloaded third-party art. File: `garden_borders_v1.png` (1536 × 1024 RGBA). Existing grass and flower art remains unchanged.

Three atlas regions: `(0,0,504,1024)`, `(504,0,516,1024)`, `(1024,0,512,1024)`. Opaque-alpha lower bounds: 696, 714, 697. RGB outside foliage contains colored haze but alpha is zero there; preserve alpha, use discard rather than displaying RGB as opaque. GDScript anchors the three silhouettes independently at ground height.

Initial prompt (reference: existing `.dream-loop/target.png`, style only):

> Use case: stylized-concept. Create a game-ready original transparent foliage sprite atlas for an HD-2D village. Input image is STYLE REFERENCE ONLY: match the dense small-leaf garden vegetation bordering its paths, not the buildings or scene. Output a 1536x1024 transparent PNG with exactly three isolated plant clumps in one horizontal row, each completely inside its own equal-width 512 pixel column with generous clear gutters. Left: low dense mixed meadow grass with tiny cream daisies. Center: rounded dense blue-green broadleaf shrub with irregular silhouette and a few trailing leaves. Right: low fern and lavender flower bank with tiny white blossoms. Grounded front-facing three-quarter elevated game view, finely clustered crisp pixel-painted leaves, dark teal interior shadows and muted moss-green tips; neutral diffuse lighting so game engine can shade. Each clump wider than tall, bottom root contacts aligned at y=850 pixels, foliage from about y=300 to850. GENUINE transparent alpha background, no checkerboard, no soil base, no cast shadow, no pot, no text, no border, no scenery. All three must remain separated and uncropped. Render assets, not a screenshot or mockup.

Final edit prompt:

> Edit this foliage atlas only: preserve all three plant designs and pixel art, but remove EVERY background glow, fog, haze and shadow. Background must be truly transparent alpha zero everywhere outside hard plant leaf silhouettes, including spaces between leaves. No soft green or purple halos. Keep plants comfortably inside their respective equal width third with clear transparent gutters of at least 24 pixels. No plant touches canvas edges. Maintain 1536x1024 canvas. Clean game sprite cutouts only, crisp opaque foliage interiors, transparent exterior. No new objects.

Generated source: `exec-eeb5c61b-cf26-40db-9178-d63f796223ec.png`. Actual regions/baselines measured from alpha, not assumed from the prompt.

Placement is deterministic and visual-only. Whole sprite width stays outside map-derived road/collider clearances and the animal pen. Village lighting changes are reset on map changes, leaving ruins and indoor lighting unchanged. Overall target fidelity remains under review, not accepted merely because the image exists.

The final layout uses connected jittered beds rather than the initial six islands. Narrow margins use smaller edge flowers. An additional single MultiMesh reuses the original `grass_low.tres` source region through material UV scale/offset, with upright billboarding and the measured alpha-root offset. Neither generated texture is overwritten or procedurally repainted.

Layer refinement: border placements now mix the three shrub regions with existing original `grass_seed.tres` and `flowers_ivory.tres` (approximately 40% shrubs, 40% upright grass, 20% flowers). A separate seeded RNG preserves placement sampling. Each atlas uses its own canvas height and measured root baseline (680 for seed grass, 620 for ivory flowers). Flowers are 30% smaller than the first mixed-layer draft. Current village counts are 681 border plants, 347 understory plants and 2067 batched low-grass instances; mixing does not add plants. Full sprite envelopes remain outside road/collision clearances. No bitmap was changed.

Door-apron follow-up: normal entrance screenshots revealed foliage filling walkable return spawns. All three added layers now also exclude the eight rotated door aprons, derived from HouseCatalog scale and return distance (1.4 m wide, extending 0.65 m past the spawn). Counts after this clearance correction are 646 borders, 312 understory and 1944 batched low-grass instances. The original 305 grass clumps and twelve flower clumps remain unchanged; independent local-space checks also verify their entrance clearance. No collisions or textures changed.
