# Vocation wardrobe atlases

Created 2026-09-24 with the built-in imagegen tool. Original project-owned art,
not third-party assets. Source/reference: `assets/generated/action/wanderer.png`.
Generated PNGs are copied without editing pixels; `regions.gd` only measures
alpha bounds using `tools/art/inspect_action_atlases.py` (`measure`, 48 sprites).
Each image is six columns by eight rows, twelve poses per facing: front, right,
back, left. Poses: idle, walk A/B, windup, attack, recover, cast, release, dodge
A/B, hurt, defeated. Diagonal movement currently chooses the nearest cardinal
wardrobe frame. Door interaction reuses cast/release arm gestures.

- `archer.png`: forest hunter outfit, longbow and quiver.
- `mage.png`: indigo star robe and ice crystal staff.
- `thief.png`: charcoal/violet leathers and twin curved daggers.

Both equipment tiers within a vocation currently share its wardrobe silhouette;
their names and attack/defense bonuses are separate. Class wardrobe replaces
traveler art in exploration, field combat, arena combat and equipment preview.
Prompts are recorded in `prompts.json`. Icons and skill glyphs in
`assets/icons/classes/` are original project-authored SVGs. Projectile movement,
piercing trail, frost burst/chill ring and shadow slash are runtime effects.
