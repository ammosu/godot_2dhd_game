# Guardian attack transitions

Original sprite atlas produced with the imagegen skill's built-in tool on 2026-09-20. Reference: `guardian_poses.png`. Final: `guardian_attack_transitions.png` (1774 × 887), preserved unchanged with transparent alpha. No third-party art was introduced.

Two AtlasTextures, `guardian_windup.tres` and `guardian_recover.tres`, add anticipation and recovery to the existing contact pose. Each has a 1120 × 736 canvas and `display_height = 201.25`, preserving the original 175/640 body pixel scale despite the raised weapon extending above the helmet. Boots share alpha baseline 700. Crops have a four-pixel border and stay on their own side of the atlas.

The first candidate had overlapping horizontal crop extents; a spacing-only edit separated the sprites. That candidate was not added to the project.

## Initial prompt

Use case: identity-preserve. Create an original HD-2D JRPG supplemental animation sprite atlas with TWO full-body poses side by side on true transparent RGBA background. Attached image is the exact identity/style reference for the ruin guardian: stocky animated slate-blue full plate armor, closed crested helmet, thin cyan T-shaped visor, silver trim, crescent moon shoulder emblems, brown belt, purple tattered moon tabard and one broad short heavy sword. Both sprites face LEFT in three-quarter view, identical body scale and ground baseline. LEFT HALF: attack anticipation, knees bent, weight on rear leg, sword hand pulled back toward right hip, broad blade pointing diagonally upward behind him to the right, ready to swing left. RIGHT HALF: recovery after a leftward slash, torso regaining upright posture, sword arm lowered toward the front left, blade tip remains above the boots, off-hand balancing. Keep helmet crest, two boots, one sword and all cloth visible within each half with generous transparent margins and gutter. Match reference crisp pixel-art clusters, neutral lighting, armor colors and chibi proportions, no blur. No effects, shadow, ground, scenery, labels, grids or extra characters. New distinct transition poses, not duplicates of reference.

## Gutter correction prompt

Edit this two-sprite transparent atlas only to create a clear vertical transparent gutter between the sprites. Preserve exactly both poses, every armor detail, colors, proportions and pixel-art style. Fit the complete left sprite (including its raised sword) fully inside the LEFT HALF with at least 70 pixels empty transparent margin before center. Fit the complete right sprite (including its lowered sword pointing left) fully inside the RIGHT HALF with at least 70 pixels empty transparent margin after center. Neither sprite may cross the center line at ANY height. Translate and uniformly scale BOTH sprites by the same amount if necessary, maintaining equal body scale and equal boot ground baseline. Preserve true transparent RGBA, no shadows or labels. Do not change the poses or add any elements.

## Verification

`tests/guardian_attack_art_test.gd` checks canvas size, in-bounds crops, gutter separation, unchanged body scale, and runtime feet alignment. With `-- --party-art-capture`, it saves static pose previews under `.dream-loop/guardian-*.png`; these are not live timing captures.

`tests/party_weapon_audio_test.gd` observes the guardian's actual windup → attack → recovery sequence during a six-actor round, single weapon contact cues, and final shadow restoration. Anticipation (60 ms) plus approach (70 ms) retains the nominal 130 ms contact time; recovery is 100 ms. Damage, MP, turn rules and audio selection are unchanged.
