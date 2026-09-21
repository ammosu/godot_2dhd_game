# Village tree species

Original art generated with the built-in imagegen tool on 2026-09-21, using
`village_oak.png` as a style reference. No new third-party source assets.

Final asset: `village_tree_species.png`, transparent RGBA, 1254 × 1254.
Four 627 × 627 AtlasTexture cells: birch, spruce, willow, rowan (row-major).
Consumed by `scripts/gameplay/tree_variants.gd` alongside the existing oak.
Stable position-based species, scale and mirroring; pond-side willows; measured
alpha baselines keep the roots grounded. Nearest-neighbor filtering retained.

Generation prompt: Four distinct whole-tree game sprites: silver birch, blue-green
spruce, sage willow and warm russet rowan. Match the existing oak's detailed HD-2D
pixel art, muted moonlit palette, clustered leaves and bark. Full roots, separate
silhouettes, transparent background, no ground, shadows, labels or text.

Final edit prompt: Repack into a two-by-two transparent atlas, birch upper left,
spruce upper right, willow lower left, rowan lower right. Keep each complete tree
inside its cell with empty padding, roots horizontally centered. Preserve species
and pixel-art style; remove all background haze and glow.

## Same-species silhouettes (2026-09-21)

`village_tree_variants.png` is an additional original, built-in imagegen atlas
(971 × 1620 RGBA). It contains two new anatomically different trees per species,
ordered oak, birch, spruce, willow, rowan, left/right within each row. Together
with the originals this supplies 15 silhouettes, three per species. Exact
alpha-inspected crop rectangles are in `tree_variants.gd`; generated packing is
not treated as a mathematically uniform grid.

Generation prompt: Create one transparent two-column, five-row production tree
atlas matching the existing detailed HD-2D pixel-art references. Oaks: stout
forked trunk with wide low gapped crown; younger leaning trunk with high
lopsided crown. Birches: three white stems with sparse leaf tufts; single crooked
white trunk with wind-swept crown. Spruces: squat broad dense uneven tiers; tall
lean sparse staggered branches with exposed trunk. Willows: massive leaning
trunk and low drooping umbrella; young twin trunk with separated airy hanging
foliage. Rowans: upright compact asymmetrical russet tufts with berries; low
spreading multi-stem tree with separated orange foliage masses. Whole roots,
centered base, transparent gutters, no overlap, ground, shadows, text or labels.
Each pair must have visibly different anatomy, crown proportions and silhouette,
not mirrored copies of the references.

Final edit prompt: Preserve the ten designs and row/column order. Shrink each
tree to 65% and center it inside its cell, leaving large fully transparent gutters
on all sides. Keep roots/crowns contained and separate; preserve pixel art and
colors, with no background, glow, grid or labels.

Runtime selection is deterministic. It prefers a silhouette not used by nearby
same-species neighbors (within 10 m); when all three are represented, it maximizes
distance to the nearest repeated silhouette. Height uses visible alpha bounds,
not atlas padding. Root-center offsets align asymmetric trees to their existing
trunk collisions. Small stature differences and mirroring supplement the actual
silhouette changes; no persistent save schema change is required.
