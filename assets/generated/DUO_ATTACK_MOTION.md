# Noah and moss wolf attack transitions

Original images generated with the built-in imagegen tool on 2026-09-20, using
`noah_combat.png` and `moss_wolf_poses.png` as identity references respectively.
No third-party artwork was introduced. PNGs are preserved unchanged with alpha.

- `noah_attack_transitions.png`: anticipation / recovery, 1774 × 887.
- `moss_wolf_attack_transitions.png`: anticipation / recovery, 1774 × 887.
- Four sibling AtlasTextures provide padded crops; Noah uses a 1200 × 840
  canvas with a body-centered horizontal anchor, wolf uses 1000 × 800.
- Existing attack/contact poses remain unchanged. Both actors reuse the
  traveler's 60 ms anticipation, 70 ms approach, contact, and 100 ms recovery.
  Damage and weapon contact cues remain at 130 ms; no combat rules change.

## Generation prompts

Shared prompt:

> Use case: identity-preserve. Original HD-2D JRPG supplemental animation atlas, TWO full-body sprites side by side in equal left/right halves on TRUE transparent RGBA background. Attached atlas is exact character identity/style reference. Left half is attack anticipation, right half is recovery after attack. Both have identical body scale and ground baseline, every body part and weapon tip fully inside its half with generous clear gutters. Crisp detailed pixel-art clusters, clean dark outlines, neutral reference lighting. No motion effects, scenery, ground plane, cast shadow, labels, grid, checkerboard or extra characters. New distinct transition poses, not duplicates of reference.

Noah suffix:

> Same young brown-haired Noah, blue tunic/cream tabard gold emblem, silver shoulder plates, brown belt gloves boots, ONE long wood spear steel tip, facing RIGHT. Left: brace bent knees, weight back, both hands pulling horizontal spear back across waist ready to thrust right. Right: after thrust, retract spear toward waist, front knee easing upright, spear gently angled upward toward right. Keep spear below head height in both poses, whole shaft and tip visible.

Wolf suffix:

> Same moss-backed gray wolf with cream muzzle/chest/paws, muted moss-green layered mane, amber eyes, facing LEFT. Left: crouching to spring, hind legs coiled under hips, forepaws planted and head low, tail extended behind to right. Right: landing after pounce with all paws back on ground, shoulders low and hindquarters settling, head lifting slightly left. Four anatomically clear legs, no extra limbs. Preserve gray/cream fur markings and moss mane, no accessories.

## Validation

`tests/party_weapon_audio_test.gd` observes the actual Noah and wolf phase order
during a full six-actor round and checks that their shadows return home. It also
checks six contact cues and the unchanged bounded audio voice pool.
