# Empty-handed town wardrobes

Original project-owned art generated 2026-09-24 using the built-in image_gen
tool. References are the corresponding `classes/` and `heroines/` atlases;
the male archer diagonal supplement references `classes/archer_diagonal_walk.png`.
Exact prompts and generation sources are recorded in `prompts.json`.
No third-party assets. Source PNG pixels and alpha are copied unchanged.

Seven atlases use five columns (idle, walk A, walk B, door reach, door contact)
and four rows (front, right, back, left). `archer_diagonal.png` and the other
`<id>_diagonal.png` sheets use four columns (down-left, down-right, up-left,
up-right) and three rows (idle, walk A, walk B).
Rebuild measured bounds with `python3 tools/art/inspect_town_atlases.py`.

## Diagonal walk sheets (2026-09-28)

`thief_diagonal.png`, `female_traveler_diagonal.png` and `female_thief_diagonal.png`
are original project-owned art generated through `codex exec` (built-in image_gen).
Each sheet follows the `archer_diagonal.png` layout: four columns (down-left,
down-right, up-left, up-right) in true 3/4 view, three rows (neutral passing,
contact A, contact B with the opposite leading leg), both hands empty. Inputs were
`town/<id>.png` (identity) and `archer_diagonal.png` (layout only). Every first
generation repeated the same leading leg in both contact rows, so each accepted
sheet is a second image_gen edit that redraws row 3 in the opposite phase. The
prompts and source paths are in `prompts.json` under `diagonal_walk`. PNG pixels
are copied unchanged. No third-party assets.

Acceptance was measured on the alpha boxes in `regions.gd`, where the sprites are
about 330 px tall. Contact A and B differ by 5 px or less (no limp). Contacts sit
at most 15 px below the neutral pose, a natural walking dip, and never more than
4 px above it. Feet share a baseline in every row. `tests/town_diagonal_art_test.gd`
enforces these limits. Mage, female mage and female archer were dropped after
repeated attempts, and the rejection reasons are recorded in `prompts.json`.
Those three use the side-profile diagonal fallback.

`town_appearance.gd` selects these on every exploration map (towns, interiors,
field and dungeon maps); drawn weapons appear only on combat actors. Male
traveler retains his existing unarmed exploration art. Diagonal supplements are
data-driven: when `regions.gd` has an `<id>_diagonal` entry and
`<id>_diagonal.png` exists (same 4x3 layout as `archer_diagonal.png`), it drives
the four diagonals; otherwise diagonals reuse the side profile (up/down-left use
left, up/down-right use right), never the back view. Equipment stats, character
selection previews and combat atlases are unaffected. Bow quivers remain worn;
all hands are empty, including door gestures.
