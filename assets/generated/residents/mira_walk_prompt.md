# mira: eight-direction walk atlas

Generated with built-in ImageGen on 2026-09-21. Reference: residents.png (original NPC identity atlas). Source pixels and alpha are preserved. Atlas regions are measured by tools/art/build_resident_frames.py.

Use case: stylized-concept. Production ORIGINAL HD-2D JRPG pixel-art movement sprite sheet.
Input image: identity and style reference containing eight villagers. Generate ONLY the specified villager, preserving their exact face, age, silhouette, hair, colors, clothing and accessories. Detailed crisp pixel outlines, chunky shading, 3-head-tall proportions, no smooth vector.
One tall transparent RGBA atlas, exactly FOUR COLUMNS by EIGHT ROWS =32 isolated full body sprites. Prefer 1024x2048 or higher 1:2 aspect ratio. Regular equally sized cells, wide clear transparent gutters on every side, no borders, no labels, no text, no floor, no shadows, no other characters. Genuine transparent background.
Each row shows ONE direction, all four figures in that row face the SAME direction:
row 1 facing DOWN toward viewer, both eyes visible;
row 2 facing DOWN-LEFT 45 degrees, front three-quarter toward image left;
row 3 facing LEFT, strict left side profile;
row 4 facing UP-LEFT, back three-quarter pointing image upper left;
row 5 facing UP, back of head and back of clothing only, NO face;
row 6 facing UP-RIGHT, back three-quarter pointing image upper right;
row 7 facing RIGHT, strict right side profile;
row 8 facing DOWN-RIGHT, front three-quarter toward image right.
Four columns are a coherent walk cycle:
column 1 neutral idle with feet together;
column 2 clear left-foot-forward/right-foot-back contact stride;
column 3 passing stride feet near together with slight body lift;
column 4 opposite clear right-foot-forward/left-foot-back contact stride.
Show real opposite leg positions even in robes using visible shoes and hem movement; subtle arm swing if hands free, keep held tools stable. Constant head size and character height across ALL 32 cells. Accessories remain attached on anatomically consistent sides, never simply mirrored. Every cell contains entire head, feet, hands, tools with generous margins. All 8 directions must be different and accurate; maintain row order exactly.
Specified villager: top row first character: Mira, woman weaver, long dark plum braid, lavender dress, cream patterned apron, spindle and folded woven cloth
