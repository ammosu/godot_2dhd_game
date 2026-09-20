# Enemy character pack — 2026-09-20

Original art generated with built-in ImageGen, not third-party downloads. The existing original `guardian_poses.png` was a style reference only.

- `moss_wolf_poses.png`: 苔背狼 / Moss Wolf, 1254 × 1254 RGBA.
- `eclipse_mage_poses.png`: 月蝕術士 / Eclipse Mage, 1254 × 1254 RGBA.
- Each has `_front.tres`, `_idle.tres`, `_attack.tres`, `_hurt.tres`. Front is for future exploration; the other three face left for enemy combat presentation.
- Original PNGs remain unchanged. Measured AtlasTexture crops include four-pixel gutters and normalize to an 800 × 640 canvas with a y=620 baseline. Generated faint alpha specks outside the visible artwork are excluded by crops; these are key poses, not complete animation cycles.
- Preview: `godot --path . scenes/enemy_art_gallery.tscn`. The gallery uses the bundled project font and nearest sampling. These poses now also appear alongside the guardian in the main party battle; original atlas pixels and guardian assets remain unchanged.
- Verification: `godot --headless --path . --script tests/enemy_roster_art_test.gd`.

## Final generation prompts

### Moss Wolf

> Use case: stylized-concept. Create original game-ready transparent pixel-art JRPG enemy sprite atlas. Reference is STYLE ONLY: same deliberate fine pixel clusters, restrained shading and crisp dark outline, not same character. Square 2x2 layout with huge clear gutters and fully transparent RGBA background. Exactly FOUR full-body poses same identity scale: top left front exploration idle; top right facing screen LEFT battle idle; bottom left facing LEFT attacking; bottom right facing LEFT recoiling hurt. All extremities entirely within each equal quadrant, feet on common baseline within each row. No text, labels, ground, shadows, glow clouds, grid, checkerboard or environment. Subject: stocky four-legged woodland wolf, shaggy desaturated slate-teal fur, moss green back tufts, ivory muzzle and paws, amber eyes, small normal ears, no armor, no horns. Attack a forward low pounce with open jaws, hurt recoils backward. Clear canine anatomy and four legs. Keep design readable at 128 pixels tall.

### Eclipse Mage

> Use case: stylized-concept. Create original game-ready transparent pixel-art JRPG enemy sprite atlas. Reference is STYLE ONLY: same deliberate fine pixel clusters, restrained shading and crisp dark outline, not same character. Square 2x2 layout with huge clear gutters and fully transparent RGBA background. Exactly FOUR full-body poses same identity scale: top left front exploration idle; top right facing screen LEFT battle idle; bottom left facing LEFT attacking; bottom right facing LEFT recoiling hurt. All extremities entirely within each equal quadrant, feet on common baseline within each row. No text, labels, ground, shadows, glow clouds, grid, checkerboard or environment. Subject: adult slender masked moon cultist, dark plum hooded robes, muted burgundy sash, pale bone crescent mask covering face, dark boots visibly grounded, holding a crooked dark wooden staff with a small dull violet stone. No wings or floating. Attack leans forward pointing staff LEFT, hurt leans back clutching chest while holding staff. Four-head-tall proportions, distinct from armored guardian.
