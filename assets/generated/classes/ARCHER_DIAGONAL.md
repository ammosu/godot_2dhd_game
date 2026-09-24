# Male archer diagonal walking

Original project-owned artwork generated with the built-in imagegen tool on
2026-09-24, using `archer.png` as the male character reference. No third-party art.
`archer_diagonal_walk.png` retains the generated pixels and alpha unchanged.

Four columns: down-left, down-right, up-left, up-right. Three rows: neutral,
contact A, contact B. The runtime loop is neutral, A, neutral, B. Both male bow
tiers use this atlas in exploration and through the field/arena directional art
library. Female art, cardinal art, attacks and door gestures retain their
separate existing resources.

Rebuild metadata with `python3 tools/art/build_archer_diagonal_frames.py` (Pillow).
Crops are measured from connected alpha components; each column uses a fixed
source-space pivot and standing height across its three poses. Runtime class
presentation uses that metadata to keep the feet grounded and scale stable.

## Final back-foot correction prompt

> Use case: precise-object-edit. Edit ONLY the TWO BOTTOM-RIGHT sprites (row 3 columns 3 and 4) in this 4x3 transparent male archer sprite atlas. Keep ALL other ten sprites unchanged. Keep both edited sprites' heads, torsos, bows, capes, quivers, position and scale unchanged. We need their opposite walking phase. BOTTOM ROW COLUMN 3: the LEFT boot on the SCREEN must be the LARGE TRAILING boot lifted toward the viewer with its SOLE VISIBLE, at lower-left of the body. The RIGHT boot on SCREEN must be the SMALLER leading planted boot further away, higher and directly beneath the right hip, with NO sole visible. BOTTOM ROW COLUMN 4: the RIGHT boot on SCREEN must be the LARGE TRAILING boot lifted toward viewer with SOLE VISIBLE at lower-right. The LEFT boot on SCREEN must be SMALLER and planted further away, higher beneath left hip, with NO sole visible. In other words replace these two bottom sprites' entire legs from hips downward with the horizontally OPPOSITE leg phase, keeping torso orientation unchanged. The visible sole must move to the OPPOSITE SIDE of the silhouette. The two bottom back poses must be visibly different from the two middle-row back poses. Natural connected legs, exactly two legs/boots each. Do not rotate bodies. Preserve true transparent background, same canvas.

## Initial prompt

The first two generations repeated the rear contact poses. The final targeted
edit below moved the visible trailing sole to the other leg in both back views.

> Use case: stylized-concept. Asset type: production transparent RGBA JRPG male archer diagonal walking atlas. Reference image defines the exact existing MALE silver-haired forest archer identity, green hooded short cape/tunic, leather belt, brown boots, longbow held relaxed and quiver. Create ONE 4-column by 3-row sprite sheet, twelve full-body sprites, 1280x960 transparent canvas, generous clear gutters. Columns: front three-quarter facing screen-left/down-left, front three-quarter facing screen-right/down-right, BACK three-quarter facing screen-left/up-left, BACK three-quarter facing screen-right/up-right. True 45-degree view in every cell. Rows: 1 neutral narrow standing/passing, 2 anatomical LEFT leg reaches forward and RIGHT leg trails backward, 3 anatomical RIGHT leg reaches forward and LEFT leg trails backward. Critical animation constraint: rows 2 and 3 must have OPPOSITE leading legs with reversed knee overlap and boot positions, not two variations of the same leading leg. For each facing visibly track each boot to its own hip; near leg in front of far leg when they overlap, never cross or fuse legs. Modest natural heel-to-toe WALK, not running, kicking, jumping, crouching, or skating. Stable torso and head at same position/size across rows; subtle opposing free-arm swing. Carry bow relaxed at side in the same hand across frames, no aiming or combat stances. Keep small chibi body proportions, exact silver hair, male face, painterly crisp game-art style and palette of reference. Each sprite centered at its torso axis in equal 320-square cells, body about 270 pixels tall, feet baseline near cell y=300. BACK columns show back of hair, hood and quiver, not face or side profile. True transparent alpha, no floor, contact shadows, labels, grid, background or text.

## Opposite-foot correction prompt

> undefined
