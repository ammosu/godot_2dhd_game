# Terrain material variants

Generated 2026-09-22 with the built-in imagegen tool. Original generated images are copied unchanged; no third-party assets were introduced. Shared world-space shader blending controls scale and patchiness, with nearest sampling. Seamless tiling was requested; generated edges are not mathematically guaranteed to match.

- `trampled_gravel.png`: compacted earth and gravel for rural/forest/caravan routes.
- `weathered_stone.png`: broken, soil-filled paving for minor streets and garden walks.
- `meadow_dry.png`: irregular olive turf with sparse straw and soil, mixed gently with the existing meadow.

## Prompts

### dirt

Use case: stylized-concept. Original seamless tileable ground albedo texture for an HD-2D JRPG, square 1024x1024. Strict straight-down orthographic material scan, fills entire image edge to edge, no perspective, no horizon, no lighting gradient, no cast shadows, no objects, no border, no text. Worn rural footpath: compacted muted warm gray-brown earth with irregular tiny gravel embedded in it, sparse uneven dust patches, faint overlapping foot wear, a few shallow dry ruts, scattered small dull stones. Medium-fine deliberate pixel-art clusters, handcrafted natural game texture, restrained contrast, matte, earthy and lived-in rather than clean decorative paving. No large rocks, no grass, no puddles, no regular pattern. Seamlessly repeat in both axes. Neutral diffuse albedo lighting.

### stone

Use case: stylized-concept. Original seamless tileable ground albedo texture for an HD-2D JRPG, square 1024x1024. Strict straight-down orthographic material scan, fills entire image edge to edge, no perspective, no lighting gradient, no cast shadows, no border, no text. An old neglected small stone footpath surface: irregular broken flat gray-beige stones of different sizes, partially buried in muted brown dirt, missing stones exposing soil, tiny gravel between stones, sparse dull moss in crevices. No pristine paving, no regular brick grid, no large rocks, no grass tufts or objects. Detailed restrained pixel-art clusters with natural handcrafted game texture. Earthy low saturation and moderate-low contrast, flat neutral diffuse albedo lighting. Seamless repeat in both axes, uniform detail and brightness across edges.

### grass

Use case: stylized-concept. Original seamless tileable meadow ground albedo texture for an HD-2D JRPG, square 1024x1024. Strict straight-down orthographic material scan, entire image edge to edge, no perspective, horizon, cast shadow, lighting gradient, border or text. Natural slightly dry meadow turf with small uneven clumps of short muted olive and sage grass, occasional straw-colored dead blades, tiny irregular bare soil gaps. Still mostly green grass, not yellow desert. Fine deliberate pixel art clusters, modest detail and low contrast, natural restrained forest palette. No flowers, tall plants, rocks, distinct paths, circular central feature, large isolated objects or lawn stripes. Flat neutral diffuse albedo lighting. Seamless repeat both axes and consistent density across all edges.
