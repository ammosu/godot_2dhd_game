# Companion layered art

Generated 2026-09-21 with built-in ImageGen edits. Original PNG outputs are retained unchanged. Each character has one body, two clothing sheets and two weapon sheets; each sheet contains idle, attack, hurt and guard. The generic coat/moonward/blade/saber filenames are internal layer slots, not the displayed equipment names.

Noah references: `assets/generated/noah_combat.png` and `assets/generated/equipment/noah_both_combat.png`. Elder references: `assets/generated/elder_combat.png` and `assets/generated/equipment/elder_both_combat.png`. These are existing project art, not newly downloaded third-party material.

`fitting.json` stores per-pose shared head/hand masks, clothing source/target control points, leg boundaries, weapon anchors and scales in logical 1280-pixel coordinates. Noah attack/guard use two grip anchors; Elder head masks follow the beard. Hands remain shared bare hands across both outfits. This is fitted equipment for each character, not a promise that any equipment sheet fits every body without adaptation.

The export include filter explicitly packs these JSON files. A shared cutout shader suppresses alpha below 0.02 (some generated empty pixels have alpha 4/255), without modifying the source PNGs. Grounding uses alpha >= 0.5.

## Exact generation prompts and outputs

### noah/base

Output: `exec-c1ad05d1-e0b5-4954-918b-1ed8f666d45b.png`, copied to `noah/base_combat.png`.

Use case: identity-preserve. Edit this exact Noah four-pose game sprite atlas into a modular BASE BODY. Preserve the original young adult guard face, short dark brown hair, expressions, proportions, poses, exact hand grip centers and feet positions, dark trousers and brown boots. Remove every spear pixel, silver shoulder/arm armor, blue tabard/scarf, belts and pouches. Replace torso with plain fitted charcoal short-sleeve undershirt; keep hands bare with identical gripping poses and reconstruct arms under armor. Preserve the four original positions: idle upper left, horizontal spear thrust upper right, hurt lower left, diagonal two-hand guard lower right. Do not reposition or enlarge figures. Original detailed shaded pixel art, same identity, no 3D, no new design. Genuine transparent RGBA outside figures, no shadows, scenery, text or checkerboard. Hands empty. Fully clothed modest base. Preserve source canvas layout exactly.

### elder/base

Output: `exec-da9c3157-bf4b-448a-ac0d-549210adcbda.png`, copied to `elder/base_combat.png`.

Use case: identity-preserve. Edit this exact Elder four-pose atlas into a modular BASE BODY. Keep the same elderly male face, long white beard, swept white hair, expressions, pose, body scale, hand centers and brown boot positions. Remove ALL wooden staffs, hooks, lanterns, blue/gold robes, cloak, belts and pouches. Reconstruct a modest fully clothed base in a simple fitted charcoal long-sleeve undershirt and plain charcoal trousers with original brown boots. Keep empty gripping hands and free casting/palm gestures exactly where they were. Four original cells idle upper left, spell attack upper right, hurt lower left, guard lower right. Do NOT enlarge or recenter figures. Preserve exact original shaded pixel art and identity, not a 3D rendering. Genuine transparent RGBA outside the body, no shadows, text, scenery or checkerboard. Beard is part of shared body and must remain complete. Keep original canvas layout and foot baselines.

### noah/coat

Output: `exec-980eedd3-3829-4fcd-9fd4-85deb9d6d528.png`, copied to `noah/coat_combat.png`.

Use case: background-extraction. Extract ONLY clothing from this four-pose Noah sprite atlas: blue padded tabard with cream gold emblem, blue scarf, silver shoulder and forearm armor, brown belt and pouch. Keep sleeve armor but remove the hands inside the cuffs. Remove every head, hair, face, neck skin, hand/finger/glove hand, trousers, boots and ALL spear parts to genuine alpha transparency. Reconstruct cloth hidden behind weapons. Keep exact original absolute pixel positions, scale, pose, cuffs, cell layout; do not recenter or enlarge garments. Four cells idle, attack, hurt, guard. No mannequin or body under clothes. Same crisp shaded pixel art. Transparent empty neck/wrist/leg openings, no background/text/grid/checkerboard. This is an aligned equipment overlay, not a new character.

### noah/moonward

Output: `exec-1b759564-8767-4d9c-90a2-666088a110b3.png`, copied to `noah/moonward_combat.png`.

Use case: background-extraction. Extract ONLY clothing from this four-pose Noah sprite atlas: ivory white gold-edged breastplate and pauldrons, red scarf, red split surcoat, sunburst emblem, dark forearm gauntlet cuffs, brown belt and pouch. Remove ALL fingers and hands, keep only cuffs. Remove every head, hair, face, neck skin, hand/finger/glove hand, trousers, boots and ALL spear parts to genuine alpha transparency. Reconstruct cloth hidden behind weapons. Keep exact original absolute pixel positions, scale, pose, cuffs, cell layout; do not recenter or enlarge garments. Four cells idle, attack, hurt, guard. No mannequin or body under clothes. Same crisp shaded pixel art. Transparent empty neck/wrist/leg openings, no background/text/grid/checkerboard. This is an aligned equipment overlay, not a new character.

### elder/coat

Output: `exec-41a0cc16-7ce4-440b-9733-7e183d541597.png`, copied to `elder/coat_combat.png`.

Use case: background-extraction. Extract ONLY the clothing of this elderly mage four-pose atlas: blue full-length robe with ivory front panel and gold patterns, ochre gold hood-down mantle, wide sleeves/cuffs, belt and pouch. Remove ALL head/hair/face/BEARD, hands/fingers, trousers/boots and wooden staff/hook/lantern pixels. Reconstruct robe behind beard, hands and staff. Preserve exact original absolute positions, scale, poses, wrist opening positions and hem height, no recentering or enlargement. Empty neck and wrist holes, no mannequin. Four original cells idle, spell attack, hurt, guard. Genuine transparent RGBA outside garments, original fine shaded pixel art, no text/checkerboard/shadow/background. This is an aligned clothing-only game layer.

### elder/moonward

Output: `exec-3ab935aa-5c46-4dad-acb1-fbc28b6a8183.png`, copied to `elder/moonward_combat.png`.

Use case: background-extraction. Extract ONLY the clothing of this elderly mage four-pose atlas: plum/charcoal full-length astral robe with silver constellation embroidery, pearl-gray mantle with violet lining and moon brooch, wide sleeves/cuffs, belt and pouch. Remove ALL head/hair/face/BEARD, hands/fingers, trousers/boots and ALL silver crescent staff/orb pixels. Reconstruct robe behind beard, hands and staff. Preserve exact original absolute positions, scale, poses, wrist opening positions and hem height, no recentering or enlargement. Empty neck and wrist holes, no mannequin. Four original cells idle, spell attack, hurt, guard. Genuine transparent RGBA outside garments, original fine shaded pixel art, no text/checkerboard/shadow/background. This is an aligned clothing-only game layer.

### noah/blade

Output: `exec-02cc2080-387e-47a9-aeb6-89ba1fe5c953.png`, copied to `noah/blade_combat.png`.

Use case: background-extraction. Extract ONLY the four complete wooden-shaft steel-tipped spears from this exact Noah sprite atlas. Remove every character, hand, finger, glove, clothing and armor pixel to genuine transparent alpha. Reconstruct continuous shaft where hands covered it. Preserve exact original absolute spear positions, size and orientation: idle upright at left, upper right attack horizontal, lower left hurt tilted up-left, lower right guard diagonal up-right. Keep complete tips and ferrules, original shaded pixel art. Do not recenter, enlarge or rearrange weapons; large empty transparent spaces are intentional. No extra objects, shadows, text, grid, background or checkerboard. Transparent RGBA equipment-only layer.

### noah/saber

Output: `exec-a0b91821-4233-4244-9fd7-43078f047856.png`, copied to `noah/saber_combat.png`.

Use case: background-extraction. Extract ONLY the four complete Dawn Partisan spears: crimson shaft, gold ferrules and side wings, steel tip with ruby socket, gold butt cap. Remove all characters, gloves/hands, clothes and armor. Reconstruct continuous shafts beneath hands. Preserve original absolute positions, lengths, angles and cell layout: upper left upright, upper right horizontal thrust, lower left tilted up-left, lower right diagonal up-right. Do not center/enlarge/rearrange isolated weapons. Keep tips fully inside canvas. Original finely shaded pixel art, genuine alpha transparency, no background/shadow/text/grid/checkerboard or extra objects.

### elder/blade

Output: `exec-6824a2c2-cbc8-4d66-8985-11a7cdee76b0.png`, copied to `elder/blade_combat.png`.

Use case: background-extraction. Extract ONLY the four wooden lantern staffs from this exact Elder four-pose sprite atlas. Include complete curved hook, wood shaft and tiny hanging lantern chain/light fixture. Remove every character, beard, hand, finger, clothing, boot pixel to alpha zero. Restore continuous wood under fingers. Preserve original absolute positions, sizes and angles for idle upper left upright, attack upper right tilted, hurt lower left tilted, guard lower right upright. Do not recenter or enlarge staffs. Original crisp shaded pixel art, transparent RGBA, no glow cloud, extra objects, text, shadow, background or checkerboard.

### elder/saber

Output: `exec-75397489-06c1-43e6-9337-e74ee82898cd.png`, copied to `elder/saber_combat.png`.

Use case: background-extraction. Extract ONLY the four complete astral staffs from this exact Elder four-pose sprite atlas: indigo shafts, silver fittings, open silver crescents cradling violet crystal orbs, silver butt caps. Remove ALL character, beard, hand, finger, clothing and boot pixels to genuine transparent alpha. Restore shafts under grips. Preserve exact absolute positions, lengths, angles and original cell layout: idle upper left upright, attack upper right tilted, hurt lower left tilted, guard lower right upright. Do not recenter/rearrange/enlarge. No floating glows beyond hard staff/orb silhouettes. Original shaded pixel art, transparent RGBA, no other objects/text/shadows/checkerboard/background.
