# Layered party, generation and runtime notes

Created 2026-09-21 with the built-in ImageGen editor (imagegen skill). Fifteen
original project-owned output sheets across three actors; no downloaded third-party art.
Companion inputs, exact prompts and fitting details are in [COMPANIONS.md](COMPANIONS.md).
The 3D character experiment was rejected for style mismatch and is archived
under ignored `build/abandoned_blender/`. It is not a dependency of this system.

## Assets

| File | Input edit target | Content |
| --- | --- | --- |
| `base_combat.png` | `assets/generated/wanderer_combat.png` | Same traveler in neutral underclothes, no equipment |
| `coat_combat.png` | `assets/generated/wanderer_combat.png` | Coat, scarf, sleeves, bracers, belt, pouch |
| `moonward_combat.png` | `assets/generated/equipment/moonward_combat.png` | Tunic, cape, pauldrons, cuffs, clasp, belt |
| `blade_combat.png` | `assets/generated/wanderer_combat.png` | Four complete short swords without hands |
| `saber_combat.png` | `assets/generated/equipment/saber_combat.png` | Four complete Moonsteel sabers without hands/scabbards |

Original generated RGBA PNGs are retained unchanged at 1254×1254. Prompts asked
for the reference's 1280 coordinate layout; generated files returned 1254 square.
The runtime explicitly converts authored 1280-space UVs to native image pixels.
Cells are idle / attack / hurt / guard. No combination-specific PNG is produced.

## Actual layering

`scripts/gameplay/layered_combat_actor.gd` draws independently selected textures
with nearest filtering. Unequipped mode displays the complete base body.
Equipped mode uses the same legs, face and hand pixels for both outfits; covered
torso/arm regions are hidden so neutral underclothes cannot stick out of sleeves.
Clothing renders between legs and head. Weapons render above clothing, followed
by fingers from polygons sampling the same base. No new face or hand is generated
when changing equipment. Guard uses a second hand polygon for occlusion.

Generation does not preserve pixel alignment perfectly. Clothing has per-pose
collar, cuff, waist and hem control points, applied as an inverse-distance mesh
deformation. Weapons use grip anchors and per-pose scale. A new item needs one
posed equipment sheet and fitting coordinates, not every outfit×weapon pairing.
The generated clothing must be complete behind the body because those pixels
are deliberately hidden by shared head/hand layers. Left/right cape crops split
at x=575 rather than blindly at x=640 to avoid neighboring cape fragments.

## How to use

```sh
godot --headless --path . --editor --import --quit
godot --path . scenes/layered_equipment_lab.tscn
godot --path . -- --equipment-preview --layered-equipment
godot --headless --path . --script tests/layered_equipment_test.gd -- --layered-equipment
```

Gallery: 1/2/3 select traveler/Noah/Elder; E separates layers; B shows base body;
W toggles weapons; H toggles foreground hand masks; Space changes background;
Esc closes. Each actor's sixteen composites reuse five source PNGs (48 total).
Normal viewing draws child layers live, without baking.

The `--layered-equipment` flag enables the same actor inside EquipmentPortrait,
shared by real equipment preview and party battle. A transparent layout texture
retains existing canvas metadata; visible pixels come from its child layer nodes.
Pose canvases are cached to avoid unbounded battle baseline-cache entries.
Foot grounding is measured from the new weapon-free base rather than a sword tip.
GameState still owns loadouts, stats, preview confirmation and save data.

Scope: all three actors' idle/attack/hurt/guard only. Walking, windup, recover and
defeated still use existing complete atlases. This is an opt-in working
layered system, not a claim that the entire game's animation library is migrated.
Transitions can therefore show art differences. The remaining art work is
authoring those pose families, refining cuffs/hand masks at high zoom, and
validating all viewing directions before making layers the default.

Verification: real Forward+ and Compatibility runs of
`tests/layered_equipment_test.gd -- --layered-equipment --layers-ui-capture`
check 48 combinations, source identity sharing, independent equipment, hand
draw order, empty slots, cross-actor portrait caching, fallback, actual try-on/cancel and
party battle integration. Captures are inspected at both gallery and UI sizes.
The original compressed walking atlas exposed a pre-existing alpha sampling
error during fallback; `sprite_grounding.gd` now decompresses its CPU image copy
before reading alpha, preserving the user's import settings.

## Prompt set used (specifications)

All calls used built-in ImageGen edits with the listed local reference paths,
not API/CLI fallback. Original generated files were copied from
`/Users/cwchang/.codex/generated_images/01a0bfd5-3f88-7121-9267-e7383123961e/`.

1. **Base / identity-preserve:** Keep exact silver-haired young adult male face,
   expressions, hair, proportions, poses, hand/grip locations, boots, charcoal
   trousers, four cell positions and foot baselines. Remove swords, scabbards,
   belts, pouches, blue coat, scarf, hood, gloves/bracers. Reconstruct covered
   body with fitted charcoal short-sleeve undershirt and neutral waist garment;
   preserve empty gripping hands. Modest fully clothed base. Original finely
   clustered shaded pixel illustration, genuine transparent RGBA, no floor,
   shadow, checkerboard, text or redesign.
   Output: `exec-a3a04c1f-5735-49a9-9851-2b021364ebf3.png`.
2. **Coat / background-extraction:** Retain only blue long coat/hood, ivory scarf,
   brown belt/strap/pouch, sleeves and leather bracers. Erase head/hair/face/neck,
   hands, trousers, boots, all sword parts and scabbard to alpha zero. Reconstruct
   clothing beneath swords. Preserve exact original canvas, scale, poses and
   absolute pixel positions. No mannequin, filled holes, flat-lay, text or icons.
   Output: `exec-10833496-06e6-4858-bec8-37a47eba5c2e.png`.
3. **Moonward / background-extraction:** Retain indigo tunic, violet moon cape,
   silver shoulders, gray collar, teal clasp, belt/straps, cuffs/bracers. Erase
   all body/head/hands/legs/boots and sword/scabbard pixels; reconstruct clothing
   underneath. Preserve exact cell layout, pose, scale and wrist cuff positions.
   Transparent openings and background; crisp original pixel illustration.
   Output: `exec-1242e499-8c51-4387-bc7a-86e5009a92fd.png`.
4. **Blade / background-extraction:** Extract four complete short swords only,
   restoring grips under fingers. Retain blade, brass guard, brown grip/pommel.
   Remove every body/clothing pixel. Preserve original positions, sizes and
   orientations: down-right idle/hurt, horizontal-right attack, upright guard.
   Do not center/rearrange weapons or fill intentionally empty character space.
   Genuine alpha, shaded pixel art, no labels/shadows/background/other objects.
   Output: `exec-c7bb9c61-5b57-430b-a03f-17bf4e4bad06.png`.
5. **Saber / background-extraction:** Extract four complete silver-blue curved
   Moonsteel sabers, crescent guards, turquoise gems, navy grips, pommels and
   runes. Restore grips; remove all people, hands, clothes and scabbards.
   Preserve original absolute positions, angles and size for all four poses;
   no recentering, other objects, shadows, background, labels or checkerboard.
   Output: `exec-b5d0dac8-275b-4a8a-bb52-81a8ce6f8d47.png`.
