# Equipment replacement art

Original project assets generated with the built-in ImageGen tool on 2026-09-21.
These are complete replacement sprite sheets, not overlays on top of old gear.
No third-party art was added. Existing project-owned traveler sheets served as
edit targets; original images remain unchanged.

## Files and combinations

- `moonward_{walk,combat,transitions,defeated}.png`: Moonward clothing with the original short blade.
- `saber_{walk,combat,transitions,defeated}.png`: original traveler clothing with the Moonsteel saber.
- `moonward_saber_{walk,combat,transitions,defeated}.png`: both replacement items.
- `equipment_icons.png`: four inventory icons, short blade / saber / coat / Moonward outfit in a 2×2 grid.

Walking has four directions × four frames; combat covers idle, attack, hurt,
guard; transitions covers windup/recover; defeated uses only the traveler's
top row. Companions now have the following independent variants as well.

- `{noah,elder}_{weapon,armor,both}_{combat,transitions}.png`: each companion's
  weapon-only, clothing-only and combined sets; original sets stay unchanged.
- `party_{weapon,armor,both}_{npc,defeated}.png`: shared village/defeated sheets.
  Each actor selects its own cell and variant independently. The middle village
  girl and top defeated traveler are not consumed from these replacement sheets.
- `party_icons.png`: four columns (base weapon, new weapon, base armor, new
  armor), two rows (Noah, elder), standalone inventory objects.

## Companion prompt set

All were made with the built-in ImageGen editor using the existing project
character sheets as edit targets. Preserve canvas, cell positions, body scale,
face, hair, beard, pose, feet and grip points; replace the selected equipment
entirely with no original item left behind. Genuine transparent alpha, shaded
JRPG pixel style, no text/checkerboard/background/floor shadows.

Noah weapon: long crimson lacquer shaft, gold ferrules, silver central spear
tip with gold side wings and ruby socket; replace the old wood/steel spear.
Noah armor: ivory-white gold-edged breastplate and pauldrons, crimson split
surcoat, red neckcloth, gold sunburst emblem, dark metal gauntlets. No old blue
tabard/scarf remains. Preserve brown boots, identity and poses.

Elder weapon: indigo straight staff, silver fittings, open silver crescent
cradling violet crystal orb. Remove wooden hook and hanging lantern completely.
Elder armor: plum/charcoal layered robe, silver constellation embroidery,
pearl-gray mantle with violet lining and silver moon brooch. No old blue/gold
robe remains; white beard/hair and face unchanged.

Combat edits established costume/weapon references. Transition, village and
defeated edits used their original sheet as target plus these approved reference
sheets, preserving each target's layout. Weapon-only edits preserve original
clothing; armor-only edits preserve original weapons; combined edits retain
both approved replacements. The other characters' cells are left untouched.

Icons use a 4×2 layout with the above exact equipment designs, isolated complete
objects with padding, no mannequin/body/head/hands or text. No third-party art.

## Extending styles

Names/stats/descriptions need no new image. A genuinely different silhouette or
costume requires replacement art for affected poses and combinations. This is
a finite full-atlas system, not an arbitrary layered wardrobe generator.
Travelers have 16 walking frames + 7 combat poses; each companion currently has
7 combat poses + a village standing pose. New weapons must be class-compatible.
For a much larger catalog, first author clean unequipped body sheets plus layered
garments/weapons with occlusion masks; simply overlaying current sheets would
leave the original equipment visible and is not a valid substitute.

## Prompt set

Outfit edits: preserve canvas, identity, face, hair, expression, poses, hands,
boots, feet, frame locations and weapons. Replace the blue coat and cream scarf
with a midnight-indigo tunic, dark-violet moon-embroidered cloak, silver crescent
shoulder armor, cool-gray collar and teal moonstone fastening. Entire wardrobe
replacement; none of the original coat/scarf remains. Detailed shaded pixel
JRPG art, genuine transparent alpha, no text, checkerboard or floor shadows.
The approved `moonward_combat.png` was the costume reference for other sheets.

Weapon edits: preserve the target's clothing, identity, poses and grip points.
Replace the original straight steel blade, brass bar guard, brown grip and
brown sheath with a slender curved silver-blue Moonsteel saber, etched moon
runes, crescent silver guard with teal gemstone, navy grip, silver pommel and
matching curved navy scabbard with silver throat/chape. Remove the old weapon
entirely; no duplicate sword or sheath. Preserve approximately the attack reach
and exact hand placement. Match original shaded pixel art, transparent alpha,
no text. Walking sheets show sheathed weapons. The approved
`saber_combat.png` was the weapon reference for every remaining sheet.

For defeated sheets only the top traveler was changed. For transition sheets
the original two-pose layout was preserved. For walking sheets the original
4×4 frame layout was preserved.

Icons: four standalone objects in equal quadrants on transparent background.
No hands, characters, mannequin, text or frame. Match the approved short blade,
Moonsteel saber, traveler coat/scarf and complete Moonward outfit designs.

## Integration

With explicit user approval, `party_both_npc.png` and
`party_both_defeated.png` were completed by deterministic Pillow composition of
the already approved `party_armor_*` and `party_weapon_*` images after ImageGen
quota exhaustion. Reproduce with `python3 tests/compose_party_equipment.py`.
Hand-shaped masks retain armored grips, remove original weapons/lanterns, and
preserve original pixel size/alpha. These two final composites were not newly
generated by ImageGen. Original source sheets remain untouched.

`equipment_appearance.gd` selects the entire texture by the two item IDs,
expands atlas bounds into empty cell space and preserves the original canvas
origin, body scale and grounding metadata. Preview, exploration and battle
share the same selection. The earlier procedural cyan weapon/cloak decals
are removed. Source sheets are not composited over the old equipment.
