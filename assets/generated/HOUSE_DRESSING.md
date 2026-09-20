# House interior prints and arrangements

Original texture atlas generated with the imagegen skill's built-in tool on 2026-09-20. `house_prints.png` is an unchanged 1254 × 1254 opaque PNG, containing botanical study, moon chart, fantasy travel map and geometric sampler. No third-party artwork was introduced.

The generated divider is not exactly centered vertically. `scripts/gameplay/house_dressing.gd` therefore uses four explicit UV crop rectangles rather than assuming equal quadrants; meshes sample the original PNG with nearest-neighbor filtering. Important decorative motifs stay within their crop. The fantasy map is household artwork, not an authoritative navigational map of the game.

## Prompt

Use case: stylized-concept. Production texture atlas for original cozy moonlit HD-2D JRPG house interiors. A perfectly flat front-facing SQUARE atlas divided into FOUR EXACT equal square quadrants, 2 by 2, no perspective, no frame, no gaps. Each quadrant is a separate rectangular warm ivory parchment illustration filling the cell, its important design inset from the cell edges. Top-left: botanical field study, large sage-green herb sprig with small blue flowers, leaves and seed silhouettes, no text. Top-right: hand-drawn moon and star chart, large muted indigo crescent, concentric orbital arcs and small gold stars, no text. Bottom-left: simple fantasy travel map, winding indigo river, brown footpath, tiny woodland and hill symbols, no real locations, no text. Bottom-right: rustic geometric sampler, ochre and muted teal interlocking diamonds, small crescent moons and border bands, no letters. Cohesive warm parchment palette, restrained pigment, visibly crisp pixel-art clusters with broad readable shapes designed to remain legible when reduced to 64 pixels per cell. Gentle irregular paper grain, no photographic noise, no shading gradients, no baked light, no shadows, no 3D objects, no mockup, no logos, no labels. Opaque image.

## Integration

All eight existing house IDs receive stable decorative arrangements, defined by `ARRANGEMENTS`: woven craft, botanical study, moon records, pottery patterns, pattern collection, travel planning, field notes and astronomy library. Each combines one framed wall print, one tabletop sheet, and varying counts of modeled bound books, rolled scrolls and the existing original earthenware jar. The former single tabletop jar is replaced by these arrangements rather than duplicated.

Book covers, pages, binding ribs, scroll rolls/endcaps/ties and wooden frames are original procedural geometry using existing project wood and linen textures. The print hangs on the west plaster panel clear of the central timber post and inherits wall cutaway visibility. Paper sits 2 mm above the table; books and scroll endcaps meet the tabletop. All additions are decorative and have no colliders or new interactions. Furniture layout, doors, paths, map IDs and save schema are unchanged. Rugs still have the existing two color variants. This does not claim eight unique floor plans or complete interior art acceptance.

## Validation

The earlier bright-purple Compatibility backdrop is now corrected with a dedicated layer -10 canvas background, active only indoors. Glow, room lighting and the desktop renderer remain unchanged. Pixel sampling and resize checks are in `tests/interior_backdrop_test.gd`; diagnosis and measured limits are in `docs/INTERIOR_BACKDROP.md`. This resolves the backdrop discrepancy, not complete room lighting/material acceptance.

`tests/house_dressing_test.gd` checks all eight themes, prop counts, valid texture crops/filter/UV, parent-wall cutaway, table contact and absence of new collisions. Optional `-- --house-art-capture` saves garden/potter/traveler/library screenshots under `.dream-loop/dressing-house_*.png`; static captures explicitly put the player on the floor because physics is disabled. `tests/house_interior_test.gd` separately covers entering/leaving all eight homes, furniture collisions, save/load and camera/minimap behavior.
