# Diagonal walking art

Created 2026-09-21 with the built-in ImageGen tool, using existing original project artwork as references. No third-party assets added. Source RGBA PNGs are preserved unmodified.

- `wanderer_diagonal_walk.png`: base outfit.
- `equipment/{saber,moonward,moonward_saber}_diagonal_walk.png`: three equipment combinations.
- Columns: down-left, down-right, up-left, up-right. Rows: standing, left step, passing, right step.
- Independently measured AtlasTexture crops retain a transparent gutter. Diagonal canvases are 352 × 352, foot baseline y=316; the existing 140 px sprite offset and 0.005 m/px scale remain valid. Cardinal art remains 320 × 320, baseline y=300. Each equipment sheet has its own measured regions.

## Prompts

### diagonal

Use case: stylized-concept. Asset type: production transparent RGBA JRPG character walking sprite atlas. Reference image 1 defines exact character identity, proportions, painterly pixel-art style and base outfit. Create a NEW companion sheet showing FOUR DIAGONAL facings, 4 columns by 4 rows, 16 full-body sprites, evenly spaced on a transparent background. Columns LEFT to RIGHT: down-left (front three-quarter facing viewer's left), down-right (front three-quarter facing viewer's right), up-left (BACK three-quarter facing away toward viewer's left), up-right (BACK three-quarter facing away toward viewer's right). Rows TOP to BOTTOM: neutral standing feet together, left foot forward walk, passing feet close, right foot forward walk. All heads and torsos really rotate 45 degrees: back columns show back of silver hair, back hood and satchel, very little face. Preserve silver hair, cream scarf, dark teal coat, brown gloves/boots/satchel, sheathed straight sword. Do NOT draw cardinal front/back/profile views. Square 1280x1280 image with sixteen 320x320 cells; each sprite about 280 pixels tall, baseline 300 pixels in each cell, generous transparent margins. No labels, no grid lines, no floor, no shadows, no checkerboard. True transparent alpha outside silhouettes.

### saber

Use case: precise-object-edit. Reference image 1 is the edit target: a transparent 4-column 4-row diagonal walking sprite sheet. Reference image 2 defines ONLY equipment appearance. Change ONLY the outfit and/or sheathed sword of ALL SIXTEEN sprites in image 1 to match image 2. Variant: saber. Keep the cream scarf and teal coat exactly, replace only sword with blue sheathed curved moonsteel saber and silver circular guard. Keep EXACT diagonal facings, face identity, silver hair, body proportions, foot locations, four poses, spacing and 4x4 layout of image 1. Columns remain front-left, front-right, back-left, back-right at 45 degrees; do not copy cardinal views from image 2. Keep every full silhouette isolated inside its cell. True transparent RGBA background. No floor, shadows, text or grids. Same canvas size as image 1.

### moonward

Use case: precise-object-edit. Reference image 1 is the edit target: a transparent 4-column 4-row diagonal walking sprite sheet. Reference image 2 defines ONLY equipment appearance. Change ONLY the outfit and/or sheathed sword of ALL SIXTEEN sprites in image 1 to match image 2. Variant: moonward. Replace teal coat/scarf with navy-purple Moonward cloak with gold crescent decorations, silver shoulder plates and turquoise brooch; retain original straight brown-and-gold sheathed sword. Keep EXACT diagonal facings, face identity, silver hair, body proportions, foot locations, four poses, spacing and 4x4 layout of image 1. Columns remain front-left, front-right, back-left, back-right at 45 degrees; do not copy cardinal views from image 2. Keep every full silhouette isolated inside its cell. True transparent RGBA background. No floor, shadows, text or grids. Same canvas size as image 1.

### moonward_saber

Use case: precise-object-edit. Reference image 1 is the edit target: a transparent 4-column 4-row diagonal walking sprite sheet. Reference image 2 defines ONLY equipment appearance. Change ONLY the outfit and/or sheathed sword of ALL SIXTEEN sprites in image 1 to match image 2. Variant: moonward_saber. Use navy-purple Moonward cloak with gold crescent decorations, silver shoulder plates and turquoise brooch, plus blue sheathed curved moonsteel saber and silver circular guard. Keep EXACT diagonal facings, face identity, silver hair, body proportions, foot locations, four poses, spacing and 4x4 layout of image 1. Columns remain front-left, front-right, back-left, back-right at 45 degrees; do not copy cardinal views from image 2. Keep every full silhouette isolated inside its cell. True transparent RGBA background. No floor, shadows, text or grids. Same canvas size as image 1.
