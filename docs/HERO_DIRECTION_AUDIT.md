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

## Other characters — follow-up audit

Audited after gameplay version `531354d` was pushed. No missing directional
art was generated during this inspection.

| Character | Idle / movement | Combat actions | Notes |
| --- | --- | --- | --- |
| Noah / 諾亞 | Town standing: 8; battle movement: 4 | 4 | All four town equipment variants have eight turnarounds. |
| Elder / 長老 | Town standing: 8; battle movement: 4 | 4 | All four town equipment variants have eight turnarounds. |
| Rumi / 露米 | Town standing: 8 | Not a combat actor | No walking cycle is used. |
| Mira / 米菈 | 8, four poses per facing | Not a combat actor | Indoor and patrol presentation share frames. |
| Flo / 芙蘿 | 8, four poses per facing | Not a combat actor | Same shared presentation. |
| Sien / 席恩 | 8, four poses per facing | Not a combat actor | Same shared presentation. |
| Locke / 洛克 | 8, four poses per facing | Not a combat actor | Same shared presentation. |
| Ada / 艾妲 | 8, four poses per facing | Not a combat actor | Same shared presentation. |
| Rain / 雷恩 | 8, four poses per facing | Not a combat actor | Same shared presentation. |
| Seph / 賽芙 | 8, four poses per facing | Not a combat actor | Same shared presentation. |
| Owen / 歐文 | 8, four poses per facing | Not a combat actor | Same shared presentation. |
| Moss wolf / 苔背狼 | 8, three poses per facing | 4 | Dedicated diagonal locomotion. |
| Eclipse mage / 月蝕術士 | 8, three poses per facing | 4 | Dedicated diagonal locomotion. |
| Dusk bat / 暮翼蝙蝠 | 8, three wing poses per facing | 4 | Corrected rear diagonals are selected at runtime. |
| Guardian / 遺跡守衛 | 8 in combat locomotion | 4 | Stationary world encounter uses its separate static image. |
| Ash warden / 灰燼 Boss | 8, three poses per facing | 1 (front) | Boss adapter uses frontal windup/attack/cast/hurt/defeat. |
| Road traveler / 驛路旅人 | 1 static image | Not a combat actor | Reuses Noah's static image, without the turnaround controller. |
| Village pig | 1 facing, two idle frames | Not a combat actor | No locomotion controller. |

Starbay's 16 authored identities each have **one front-facing static image**:
tea master, ronin, shrine keeper, shinobi, lantern maker, musician, pilgrim,
silk merchant, spice merchant, astronomer, sailor, blacksmith, scholar,
apothecary, clockmaker and ranger. The 26 houses currently use 14 identities;
musician and spice merchant have no house assignment after shop overrides.
This is distinct from missing texture files: all 16 textures load correctly.

Verification: `enemy_movement_test.gd`, `resident_motion_test.gd`,
`ally_combat_art_test.gd`, `party_equipment_test.gd`, and `pig_art_test.gd` pass.
All eight resident contact sheets were rendered with Forward+ and visually
reviewed (256 direction/pose combinations). Runtime source-frame enumeration
also confirmed the companion, enemy and NPC counts above; source identity alone
is not a visual quality verdict for every combat frame.

`city_resident_art_test.gd` currently fails five assertions: four introductions
at shop addresses 01/03/07/25 and its expectation that all 16 designs are assigned.
The test still expects the original household introductions/roster, while
`CityShops` deliberately supplies shop-specific owners and dialogue. Its texture,
scale and conversation-opening checks passed. This inspection records the stale
expectations without changing gameplay or silently treating the suite as green.
