# rain: eight-direction walk atlas

Generated with built-in ImageGen on 2026-09-21. Reference: residents.png (original NPC identity atlas). Source pixels and alpha are preserved. Atlas regions are measured by tools/art/build_resident_frames.py.

Use case: stylized-concept. Production original HD-2D JRPG pixel-art movement sprite sheet.
Input image: identity and style reference of eight villagers. Generate ONLY the specified villager preserving exact face, age, silhouette, hair, colors, clothing, accessories. Crisp detailed pixel outlines and chunky shading, 3-head-tall proportions.
One tall transparent RGBA atlas, exactly FOUR COLUMNS by EIGHT ROWS =32 isolated full body sprites. 1024x2048 or higher 1:2 aspect ratio. Equally spaced cells with generous EMPTY gutters, especially between rows; complete heads and feet. No borders, labels, text, ground, shadows, or other characters. Genuine transparent background.
Each ROW faces one direction:
1 DOWN straight toward viewer;
2 DOWN-LEFT front three-quarter toward image left;
3 LEFT strict side profile;
4 UP-LEFT back three-quarter toward image upper left;
5 UP full back view, NO face;
6 UP-RIGHT back three-quarter toward image upper right;
7 RIGHT strict side profile;
8 DOWN-RIGHT front three-quarter toward image right.
All four figures within a row face the SAME direction.
Four COLUMNS per row:
1 neutral idle feet together;
2 clear left-foot-forward/right-foot-back walking contact stride;
3 passing stride feet near together slight body lift;
4 opposite right-foot-forward/left-foot-back walking contact stride.
Actual distinct leg and shoe positions (also under robes), subtle natural arm swing, held tools stable. Constant head size and height across all32, including last row. Accessories stay on anatomically consistent sides; do not mirror sprites. Full bodies inside cells, no overlap. Exact row order, all8 directions accurate.
Specified villager: bottom row second character: Rain, sandy-blond young adult male traveler, olive cape, tan hiking outfit, backpack with rolled blanket
