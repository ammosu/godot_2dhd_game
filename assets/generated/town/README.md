# Empty-handed town wardrobes

Original project-owned art generated 2026-09-24 using the built-in image_gen
tool. References are the corresponding `classes/` and `heroines/` atlases;
the male archer diagonal supplement references `classes/archer_diagonal_walk.png`.
Exact prompts and generation sources are recorded in `prompts.json`.
No third-party assets. Source PNG pixels and alpha are copied unchanged.

Seven atlases use five columns (idle, walk A, walk B, door reach, door contact)
and four rows (front, right, back, left). `archer_diagonal.png` uses four columns
(down-left, down-right, up-left, up-right) and three rows (idle, walk A, walk B).
Rebuild measured bounds with `python3 tools/art/inspect_town_atlases.py`.

`town_appearance.gd` selects these only in village, Starbay and house interiors.
Male traveler retains his existing unarmed exploration art. Other diagonals
retain the existing cardinal-facing fallback. Equipment stats, character
selection previews and combat atlases are unaffected. Bow quivers remain worn;
all hands are empty, including door gestures.
