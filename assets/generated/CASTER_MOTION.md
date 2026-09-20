# Caster anticipation and recovery

Original HD-2D animation atlases generated with the imagegen skill, built-in tool mode, on 2026-09-20. Both 1774 × 887 RGBA images are preserved unchanged; no third-party artwork was added.

- `elder_attack_transitions.png`, reference `elder_combat.png`.
- `eclipse_mage_attack_transitions.png`, reference `eclipse_mage_poses.png`.
- Left cell = preparation; right cell = recovery. Four sibling AtlasTextures use 1120 × 840 canvases with four-pixel crop borders. Body-centered margins preserve the ground plane; alpha foot baseline is 780. Elder display height is 192, mage 175, compensating for source body scale independently of staff height.

## Runtime integration

All six current combatants now have physical anticipation/contact/recovery presentation. Existing contact artwork remains in use. Casters also prepare before magic, release at impact, and spend 100 ms recovering after the effect ends. Input remains locked throughout recovery. AoE/heal impact remains at the effect's 160 ms signal. Moon bolt splits its original 220 ms pre-impact flight window into 60 ms preparation and 160 ms flight; the impact effect then resolves at 160 ms as before. Damage, healing, MP, targeting and turn rules are unchanged; overall magic presentation adds the 100 ms recovery.

## Prompts

### elder

Reference image: `elder_combat.png`.

Use case: identity-preserve. Original HD-2D JRPG supplemental sprite atlas: TWO distinct full-body animation poses side by side on TRUE transparent RGBA. Attached image is exact character identity reference. Left half preparation/anticipation, right half recovery after casting. Preserve identical body scale, foot baseline, character proportions and colors. Every weapon tip, boot and garment must fit entirely inside its own half; wide transparent center gutter, generous outer margins. Crisp detailed pixel-art clusters matching reference, neutral lighting. No magic effects, glow clouds, scenery, floor, cast shadow, text, grid or extra characters. Same elderly man with swept-back white hair and long white beard, blue robe with cream front panel and gold embroidery, ochre shoulder cape, brown belt pouch and boots, one crooked wooden staff with small hanging blue-and-gold lantern. Both poses face RIGHT. Left: focused anticipation, knees slightly bent, staff held diagonally close across torso and free hand cupped near chest, ready to release spell or make a staff jab. Right: easing upright after casting, free hand drawing back from forward gesture, staff returning close to body with tip above boots. Preserve face, lantern and robe emblems.

### eclipse_mage

Reference image: `eclipse_mage_poses.png`.

Use case: identity-preserve. Original HD-2D JRPG supplemental sprite atlas: TWO distinct full-body animation poses side by side on TRUE transparent RGBA. Attached image is exact character identity reference. Left half preparation/anticipation, right half recovery after casting. Preserve identical body scale, foot baseline, character proportions and colors. Every weapon tip, boot and garment must fit entirely inside its own half; wide transparent center gutter, generous outer margins. Crisp detailed pixel-art clusters matching reference, neutral lighting. No magic effects, glow clouds, scenery, floor, cast shadow, text, grid or extra characters. Same hooded moon cult mage in muted plum/purple layered robes and scarf, ivory beaked crescent-marked mask, black gloves, brown boots, rope belt and crescent buckle, one dark twisted staff with purple crystal. Both poses face LEFT. Left: focused anticipation, knees slightly bent, staff pulled back diagonally close to torso with crystal near shoulder, free hand curled near chest, preparing to cast or jab left. Right: easing upright after casting, staff retracting toward body and free hand lowering. Preserve mask, hood silhouette, crescent emblems and tattered cloth.

## Verification

`tests/caster_motion_test.gd` validates both atlases/crops/grounding and live preparation → release → recovery for elder AoE, moon bolt, healing and enemy AoE. It checks no early resolution, exact MP and target HP, locked input and return to the next player round. `-- --party-art-capture` produces static pose previews separately from timing checks. `tests/party_weapon_audio_test.gd` now checks phase order for all six normal attacks; `tests/party_battle_ui_test.gd` covers normal player selection, enemy AI and effect cleanup.
