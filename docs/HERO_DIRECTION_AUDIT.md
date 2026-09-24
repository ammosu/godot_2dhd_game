# Playable hero directional-art audit — 2026-09-24

Eight input directions are available for every playable hero, but **independent
art for all eight directions is not complete**. Counts below describe distinct
source-frame sequences, not input bindings or animation names. A count of 4
means diagonal inputs share cardinal art. No missing artwork is synthesized by
this audit.

| Hero | Town idle/walk | Town door | Field idle/walk | Combat actions |
| --- | --- | --- | --- | --- |
| Male warrior (traveler) | 8 | 8 | 4 | 4 |
| Male archer | 8 | 4 | 8 | 4 |
| Male mage | 4 | 4 | 4 | 4 |
| Male thief | 4 | 4 | 4 | 4 |
| Female warrior | 4 | 4 | 4 | 4 |
| Female archer | 4 | 4 | 4 | 4 |
| Female mage | 4 | 4 | 4 | 4 |
| Female thief | 4 | 4 | 4 | 4 |

Combat actions include windup, attack, recover, cast, release, both dodge poses,
hurt and defeated. Field art is also used by action battles. Male warrior has
separate eight-direction non-combat exploration art; his armed field art has
four directions. Town wardrobes are empty-handed and do not change equipment.

Run `godot --headless --path . --script tests/hero_direction_audit.gd` to exercise
the actual player, town-door path and directional combat selector for both sexes
and all four starting classes. It checks valid atlas bounds and frame availability
for every direction and prints the distinct source counts. A PASS means frames
are available for all input directions, **not** that eight distinct facings exist.
The original and new town atlases were also visually inspected; frame identity
counts alone cannot prove that a drawing faces its intended direction.

Remaining art work: four diagonal sequences for the six town wardrobes showing
4 above; diagonal door gestures for seven wardrobes; diagonal armed locomotion
for seven wardrobes; diagonal combat actions for all eight wardrobes. These
require new character artwork and visual review, not just additional animation
names or mirrored cardinal frames.
