# Action combat art

Original project-owned images generated with the built-in ImageGen tool on 2026-09-22. No new third-party assets. Reference art is the existing original `assets/generated` cast. Source PNGs are preserved with genuine alpha; Python only measures regions and never edits the images.

Six base sheets and nine current equipment variants, each containing 48 key poses (four cardinal facings × twelve poses). This is the four-facing combat key-pose set. Enemy idle and locomotion now use the separate eight-direction atlases in `../enemy_movement/`; attacks, hits, and defeat still use this set. Exploration retains its existing eight-direction traveler walking.

Pose order per facing: idle, walk A, walk B, windup, contact, recovery, casting gather, casting release, dodge crouch, dodge step, hurt, defeated. Facing order: front, right, back, left. Wolf right-facing uses a horizontal flip of its side row. Several attacking/recoiling poses twist the torso or head, while feet retain the selected facing.

`regions.json` is the measured review data, `regions.gd` is its runtime counterpart. Regenerate both with `python3 tools/art/inspect_action_atlases.py` (Pillow required). The measurement tool rejects atlases without 48 separate main alpha components; it measures foot contact centers to avoid weapon reach shifting the actor's ground position. Runtime normalizes scale using the standing frame per facing, so crouching and defeat never become standing-height sprites. No fixed-grid cropping assumptions.

`action_sprite_library.gd` selects equipment and facing from the actual camera, then animation from the model timers. Walking cycles A → idle → B → idle. Attacks play windup → contact → recovery; hits and defeat interrupt presentation. Support skills retain their existing instant gameplay semantics and show release immediately. Reserved gather/howl poses are supplied even for actors without a current magic ability. Combat rules and save format are unchanged.

`world_combat_effect.gd` reuses the original frost, moon bolt, moon slash, sword, spear, claw, healing and ward assets. Ranged windup shows gathering/bolt travel; impact starts its burst on the model's single damage event. Effects are depth-tested, nearest-filtered, controlled by the combat clock, freeze on pause, and clean up on completion. Ward rings retain the authoritative three-second buff duration; the decorative ward burst is shorter. Effects never apply damage.

Existing turn-based and exploration art remains intact. The new atlases are used in both manual and automatic world combat. Equipment replacement remains whole-atlas selection, never an overlay that leaves duplicate old weapons underneath.

## Accepted gutter correction prompts

The first equipment edits left a few raised weapon tips touching the previous row. The accepted final `saber`, `noah_both`, and `elder_both` images were regenerated with wider gutters using these prompts. Rejected intermediate attempts remain outside the project. Source PNGs were not edited with Python.

### saber.png

Edit target: this original silver-haired teal-coated traveler with curved silver-blue saber sprite atlas. Keep exactly 48 sprites in 6 columns by 8 rows and same order, identical poses, faces, direction, gear, art style and genuinely transparent alpha background. Technical correction: increase the transparent gutters so NO TWO SPRITES TOUCH, vertically or horizontally. Make EACH individual sprite 20 percent smaller around its own center inside its existing cell, retaining all weapon tips, feet, clothing and details. Do not scale the entire atlas as one object; reduce each of the 48 characters separately. At least 15 transparent pixels clear between any neighboring sprites or extended weapons, especially raised weapons touching feet of the row above. No cropping, no opaque background, no text or lines.

### noah_both.png

Edit target: this original brown-haired armored spear guard sprite atlas. Keep exactly 48 sprites in 6 columns by 8 rows and same order, identical poses, faces, direction, gear, art style and genuinely transparent alpha background. Technical correction: increase the transparent gutters so NO TWO SPRITES TOUCH, vertically or horizontally. Make EACH individual sprite 20 percent smaller around its own center inside its existing cell, retaining all weapon tips, feet, clothing and details. Do not scale the entire atlas as one object; reduce each of the 48 characters separately. At least 15 transparent pixels clear between any neighboring sprites or extended weapons, especially raised weapons touching feet of the row above. No cropping, no opaque background, no text or lines.

### elder_both.png

Edit target: this original white-bearded silver/plum-robed mage sprite atlas. Keep exactly 48 sprites in 6 columns by 8 rows and same order, identical poses, faces, direction, gear, art style and genuinely transparent alpha background. Technical correction: increase the transparent gutters so NO TWO SPRITES TOUCH, vertically or horizontally. Make EACH individual sprite 20 percent smaller around its own center inside its existing cell, retaining all weapon tips, feet, clothing and details. Do not scale the entire atlas as one object; reduce each of the 48 characters separately. At least 15 transparent pixels clear between any neighboring sprites or extended weapons, especially raised weapons touching feet of the row above. No cropping, no opaque background, no text or lines.

## Base generation prompts

### wanderer.png

Use case: stylized-concept. Production sprite atlas for Godot HD-2D RPG. Reference image defines the SAME silver-haired traveler with teal coat, cream scarf, brown boots, straight sword. Create a NEW transparent PNG atlas, exactly 6 columns and 8 rows, 48 separate full-body pixel-art sprites, equal rectangular cells, no labels, no grid lines, no shadows on floor. Two rows per direction: rows 1-2 face SOUTH/front, rows 3-4 face EAST/right, rows 5-6 face NORTH/back, rows 7-8 face WEST/left. In each direction pair: first row columns 1-6 = idle, walk left foot forward, walk right foot forward, sword windup, sword striking, sword recovery; second row columns 1-6 = casting gather with free hand, casting release with free hand, dodge crouch, dodge extended step, hurt recoil, collapsed defeated. Maintain identical character scale and identity throughout; actual back view for NORTH. Every cell has generous empty gutters and complete unclipped sword/body. Feet aligned at 88% cell height except collapsed pose at same floor. Crisp pixel-art matching reference, no motion trails or magical effects painted onto character, no text. True transparent background. Tall atlas 1536x2048 if possible.

### noah.png

Use case: stylized-concept. Production sprite atlas for Godot HD-2D RPG. Reference image defines the SAME brown-haired guard Noah with blue tunic, silver pauldrons, cream/gold fleur insignia, brown boots, long spear. Create a NEW transparent PNG atlas, exactly 6 columns and 8 rows, 48 separate full-body pixel-art sprites, equal rectangular cells, no labels, no grid lines, no shadows on floor. Two rows per direction: rows 1-2 face SOUTH/front, rows 3-4 face EAST/right, rows 5-6 face NORTH/back, rows 7-8 face WEST/left. In each direction pair: first row columns 1-6 = idle, walk left foot forward, walk right foot forward, spear windup, spear striking, spear recovery; second row columns 1-6 = casting gather with free hand, casting release with free hand, dodge crouch, dodge extended step, hurt recoil, collapsed defeated. Maintain identical character scale and identity throughout; actual back view for NORTH. Every cell has generous empty gutters and complete unclipped spear/body. Feet aligned at 88% cell height except collapsed pose at same floor. Crisp pixel-art matching reference, no motion trails or magical effects painted onto character, no text. True transparent background. Tall atlas 1536x2048 if possible.

### elder.png

Use case: stylized-concept. Production sprite atlas for Godot HD-2D RPG. Reference image defines the SAME elderly white-bearded village elder with blue robe, gold mantle, ivory front panel, brown boots, curved wooden lantern staff. Create a NEW transparent PNG atlas, exactly 6 columns and 8 rows, 48 separate full-body pixel-art sprites, equal rectangular cells, no labels, no grid lines, no shadows on floor. Two rows per direction: rows 1-2 face SOUTH/front, rows 3-4 face EAST/right, rows 5-6 face NORTH/back, rows 7-8 face WEST/left. In each direction pair: first row columns 1-6 = idle, walk left foot forward, walk right foot forward, staff windup, staff pointing forward casting bolt, staff recovery; second row columns 1-6 = casting gather with free hand, casting release with free hand, dodge crouch, dodge extended step, hurt recoil, collapsed defeated. Maintain identical character scale and identity throughout; actual back view for NORTH. Every cell has generous empty gutters and complete unclipped staff/body. Feet aligned at 88% cell height except collapsed pose at same floor. Crisp pixel-art matching reference, no motion trails or magical effects painted onto character, no text. True transparent background. Tall atlas 1536x2048 if possible.

### guardian.png

Use case: stylized-concept. Production sprite atlas for Godot HD-2D RPG. Reference image defines the SAME massive fully armored moon guardian with closed silver helmet cyan visor, purple tabard, crescent moon pauldrons and heavy short sword. Create a NEW transparent PNG atlas, exactly 6 columns and 8 rows, 48 separate full-body pixel-art sprites, equal rectangular cells, no labels, no grid lines, no shadows on floor. Two rows per direction: rows 1-2 face SOUTH/front, rows 3-4 face EAST/right, rows 5-6 face NORTH/back, rows 7-8 face WEST/left. In each direction pair: first row columns 1-6 = idle, walk left foot forward, walk right foot forward, sword windup, sword striking, sword recovery; second row columns 1-6 = casting gather with free hand, casting release with free hand, dodge crouch, dodge extended step, hurt recoil, collapsed defeated. Maintain identical character scale and identity throughout; actual back view for NORTH. Every cell has generous empty gutters and complete unclipped sword/body. Feet aligned at 88% cell height except collapsed pose at same floor. Crisp pixel-art matching reference, no motion trails or magical effects painted onto character, no text. True transparent background. Tall atlas 1536x2048 if possible.

### moss_wolf.png

Use case: stylized-concept. Production sprite atlas for Godot HD-2D RPG. Reference image defines the SAME four-legged moss wolf, gray fur cream muzzle and paws golden eyes and moss-green mane, no clothes or weapons. Create a NEW transparent PNG atlas, exactly 6 columns and 8 rows, 48 separate full-body pixel-art sprites, equal rectangular cells, no labels, no grid lines, no shadows on floor. Two rows per direction: rows 1-2 face SOUTH/front, rows 3-4 face EAST/right, rows 5-6 face NORTH/back, rows 7-8 face WEST/left. In each direction pair: first row columns 1-6 = idle, walk left foot forward, walk right foot forward, crouching bite windup, lunging bite, landing recovery; second row columns 1-6 = howl windup head rising, howling head high, dodge crouch, dodge extended step, hurt recoil, collapsed defeated. Maintain identical character scale and identity throughout; actual back view for NORTH. Every cell has generous empty gutters and complete unclipped tail/body. Paws aligned at 88% cell height except collapsed pose at same floor. Crisp pixel-art matching reference, no motion trails or magical effects painted onto character, no text. True transparent background. Tall atlas 1536x2048 if possible.

### eclipse_mage.png

Use case: stylized-concept. Production sprite atlas for Godot HD-2D RPG. Reference image defines the SAME hooded eclipse mage, purple robes, ivory pointed crescent mask, brown boots, twisted wooden staff with violet crystal. Create a NEW transparent PNG atlas, exactly 6 columns and 8 rows, 48 separate full-body pixel-art sprites, equal rectangular cells, no labels, no grid lines, no shadows on floor. Two rows per direction: rows 1-2 face SOUTH/front, rows 3-4 face EAST/right, rows 5-6 face NORTH/back, rows 7-8 face WEST/left. In each direction pair: first row columns 1-6 = idle, walk left foot forward, walk right foot forward, staff windup, staff pointing to release bolt, staff recovery; second row columns 1-6 = casting gather with free hand, casting release with free hand, dodge crouch, dodge extended step, hurt recoil, collapsed defeated. Maintain identical character scale and identity throughout; actual back view for NORTH. Every cell has generous empty gutters and complete unclipped staff/body. Feet aligned at 88% cell height except collapsed pose at same floor. Crisp pixel-art matching reference, no motion trails or magical effects painted onto character, no text. True transparent background. Tall atlas 1536x2048 if possible.


## Equipment edit prompts

Files in this directory: `wanderer.png`, `noah.png`, `elder.png`, `guardian.png`, `moss_wolf.png`, `eclipse_mage.png`; traveler variants `moonward.png`, `saber.png`, `moonward_saber.png`; companion variants `{noah,elder}_{weapon,armor,both}.png`.

All final variant PNGs are consumed by the same animation library. The original base art and previous equipment atlases outside this directory are unchanged. Validation covers all twelve current allied equipment combinations, including back-facing casting.

### moonward.png

Edit target: original project character atlas. Preserve EXACT 6-column 8-row layout, all 48 poses, directions, character face and silver hair, body scale, feet, hand positions and transparent background. Replace all teal coat/cream scarf with midnight-indigo tunic, dark-violet moon-embroidered cloak, silver crescent shoulder armor, cool-gray collar and teal moonstone clasp. Keep original straight sword. Complete replacements with none of old selected equipment left underneath. Maintain shaded crisp JRPG pixel art. No text, no gridlines, no extra sprites. Keep all cell positions unchanged.

### saber.png

Edit target: original project character atlas. Preserve EXACT 6-column 8-row layout, all 48 poses, directions, character face and silver hair, body scale, feet, hand positions and transparent background. Replace only straight sword and sheath with curved silver-blue Moonsteel saber, etched moon runes, silver crescent guard, teal gemstone, navy grip and matching curved navy scabbard. Keep original teal coat and cream scarf. Complete replacements with none of old selected equipment left underneath. Maintain shaded crisp JRPG pixel art. No text, no gridlines, no extra sprites. Keep all cell positions unchanged.

### moonward_saber.png

Edit target: original project character atlas. Preserve EXACT 6-column 8-row layout, all 48 poses, directions, character face and silver hair, body scale, feet, hand positions and transparent background. Replace teal coat/cream scarf with midnight-indigo tunic, dark-violet moon cloak, silver crescent shoulders, gray collar and teal moonstone clasp. Replace straight sword with curved silver-blue Moonsteel saber, silver crescent guard, teal gemstone, navy grip and matching curved navy scabbard. Complete replacements with none of old selected equipment left underneath. Maintain shaded crisp JRPG pixel art. No text, no gridlines, no extra sprites. Keep all cell positions unchanged.

### noah_weapon.png

Edit target: original project character atlas. Preserve EXACT 6-column 8-row layout, all 48 poses, directions, character face/hair/beard, body scale, feet, hand positions and transparent background. Replace spear with crimson lacquer shaft, gold ferrules, silver spear tip with gold side wings and ruby socket. Keep blue clothing. Complete replacements with none of old selected equipment left underneath. Maintain shaded crisp JRPG pixel art. No text, no gridlines, no extra sprites. Keep all cell positions unchanged.

### noah_armor.png

Edit target: original project character atlas. Preserve EXACT 6-column 8-row layout, all 48 poses, directions, character face/hair/beard, body scale, feet, hand positions and transparent background. Replace blue clothing with ivory-white gold-edged breastplate and pauldrons, crimson split surcoat, red neckcloth, gold sunburst emblem, dark metal gauntlets. Keep original spear. Complete replacements with none of old selected equipment left underneath. Maintain shaded crisp JRPG pixel art. No text, no gridlines, no extra sprites. Keep all cell positions unchanged.

### noah_both.png

Edit target: original project character atlas. Preserve EXACT 6-column 8-row layout, all 48 poses, directions, character face/hair/beard, body scale, feet, hand positions and transparent background. Replace spear with crimson lacquer shaft, gold ferrules, silver winged spear tip and ruby socket. Replace blue clothing with ivory-white gold-edged breastplate and pauldrons, crimson split surcoat, red neckcloth, gold sunburst emblem, dark gauntlets. Complete replacements with none of old selected equipment left underneath. Maintain shaded crisp JRPG pixel art. No text, no gridlines, no extra sprites. Keep all cell positions unchanged.

### elder_weapon.png

Edit target: original project character atlas. Preserve EXACT 6-column 8-row layout, all 48 poses, directions, character face/hair/beard, body scale, feet, hand positions and transparent background. Replace wooden hook staff and lantern entirely with indigo straight staff, silver fittings, open silver crescent cradling violet crystal orb. Keep blue and gold clothing. Complete replacements with none of old selected equipment left underneath. Maintain shaded crisp JRPG pixel art. No text, no gridlines, no extra sprites. Keep all cell positions unchanged.

### elder_armor.png

Edit target: original project character atlas. Preserve EXACT 6-column 8-row layout, all 48 poses, directions, character face/hair/beard, body scale, feet, hand positions and transparent background. Replace blue and gold robe with plum/charcoal layered robe, silver constellation embroidery, pearl-gray mantle with violet lining and silver moon brooch. Keep original wooden lantern staff. Complete replacements with none of old selected equipment left underneath. Maintain shaded crisp JRPG pixel art. No text, no gridlines, no extra sprites. Keep all cell positions unchanged.

### elder_both.png

Edit target: original project character atlas. Preserve EXACT 6-column 8-row layout, all 48 poses, directions, character face/hair/beard, body scale, feet, hand positions and transparent background. Replace wooden hook staff and lantern entirely with indigo straight staff, silver fittings, open silver crescent cradling violet crystal orb. Replace blue and gold robe with plum/charcoal layered robe, silver constellation embroidery, pearl-gray mantle with violet lining and silver moon brooch. Complete replacements with none of old selected equipment left underneath. Maintain shaded crisp JRPG pixel art. No text, no gridlines, no extra sprites. Keep all cell positions unchanged.

## Duskwing bat (2026-09-23)

`dusk_bat.png` is original project art generated with built-in ImageGen, with genuine alpha preserved unchanged. No third-party asset or attribution requirement. Four facings × six unique poses: hover, upstroke, downstroke, bite, hurt, defeated. The measurement script maps these 24 poses onto the shared 48-entry animation interface; casting/dodge aliases are reserved, not extra abilities. Living bats hover visually above their collision anchor and flap even at rest; defeated bats are grounded. The original image is never modified by the metadata tool.

Generation prompt: Create an original transparent RGBA game sprite atlas for Wanderlight Moon Shard HD-2D JRPG: duskwing bat monster, compact furry indigo body, big pointed ears, broad violet leathery bat wings with dusty rose membranes, tiny amber eyes and ivory fangs. Beautiful detailed pixel art with crisp pixel clusters, softly shaded like a modern HD2D JRPG sprite. Exactly 24 separated sprites in six columns × four rows, 1536×1024. Rows front, right, back, left. Columns hovering wings level, upstroke, downstroke, open-mouth attack dive, hit recoil, defeated lying flat. Same body scale, defeated shorter not enlarged, generous transparent gutters, no ground shadows, glow particles, text, grid, backdrop, or commercial game design.
