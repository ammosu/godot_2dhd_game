# Outdoor cliff and stair materials

Created 2026-09-22 with the built-in imagegen tool. Original generated PNGs are copied unchanged into this directory. No external game assets or third-party material sources were used. Seamless repeat was requested; image edges are not mathematically guaranteed to match.

- `stratified_moss_cliff.png`: layered, eroded rock with moss and earth seams. Used by the terrace wall, stair foundation and south bank.
- `worn_sandstone.png`: worn stone surface for individual stair treads, landing fragments and cliff-foot rubble.

The geometry is authored in `scripts/gameplay/field_terrain.gd`. Six irregular wall rings, 16 shallow stair rows with three chipped slabs per row, small broken stones, and existing original grass sprites provide shape variation. `shaders/field_turf.gdshader` blends grass into exposed earth around the cliff edge and along a worn upper trail. Collision retains the original platform and smooth ramp; the visible tread surface differs from its collision plane by less than 7 cm. Groundcover is visual-only and keeps the central combat lane clear.

## Final prompts

### Cliff

Use case: stylized-concept. Asset type: original seamless tileable albedo material for a 3D terrain cliff in an HD-2D pixel-art JRPG. Square 1024x1024. Front-facing orthographic flat material scan, fills whole image edge to edge. Natural weathered sedimentary rock, irregular broad horizontal layers of warm gray sandstone and muted brown earth, branching cracks, softened eroded edges, occasional subdued olive moss in cracks, fine mineral grain. Broad readable rock forms, hand-painted pixel clusters, modest contrast, natural outdoor forest palette. Not constructed bricks, not a masonry wall, no regular grid. Flat neutral diffuse albedo lighting, no cast shadows, no directional sunlight, no perspective, no objects, no grass silhouettes, no text, no borders. Repeat seamlessly on both axes. Entire image is usable material.

### Stair stone

Use case: stylized-concept. Asset type: original seamlessly tileable stone albedo texture for individual outdoor stair slabs and scattered stepping stones in an HD-2D JRPG. Square 1024x1024. Strict straight-down orthographic material scan, one continuous surface filling entire image. Weathered pale warm gray sandstone with subtle sage lichen, tiny worn pits and sparse hairline cracks, faint cloudy mineral variation. Fine controlled hand-painted pixel clusters, low saturation, moderate-low contrast. This is the surface of solid stone, NOT separate pavers, NOT a brick wall, no mortar grid, no objects, no grass tufts. Flat neutral diffuse lighting, no baked shadows, no perspective, no gradient, no text or border. Seamless repeat on all four edges. Lichen sparse and irregular, mostly bare readable stone.

### Trail soil

`trampled_gravel.png` is an existing original built-in imagegen output reused for the exposed earth on this terrace. Its final prompt is:

Use case: stylized-concept. Original seamless tileable ground albedo texture for an HD-2D JRPG, square 1024x1024. Strict straight-down orthographic material scan, fills entire image edge to edge, no perspective, no horizon, no lighting gradient, no cast shadows, no objects, no border, no text. Worn rural footpath: compacted muted warm gray-brown earth with irregular tiny gravel embedded in it, sparse uneven dust patches, faint overlapping foot wear, a few shallow dry ruts, scattered small dull stones. Medium-fine deliberate pixel-art clusters, handcrafted natural game texture, restrained contrast, matte, earthy and lived-in rather than clean decorative paving. No large rocks, no grass, no puddles, no regular pattern. Seamlessly repeat in both axes. Neutral diffuse albedo lighting.
