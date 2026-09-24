# Female playable heroes

Original art generated 2026-09-24 with the built-in imagegen tool, using the
project's original archer atlas as the style/layout reference. No third-party
assets. PNGs are copied without modifying pixels; prompts (including iterations)
are recorded in `prompts.json`.

- `traveler.png`: navy adventurer coat, sword, silver ponytail.
- `archer.png`: green hunter tunic, longbow and quiver.
- `mage.png`: star robe and crystal staff.
- `thief.png`: violet leather armor and two curved daggers.
- `*_support.png`: supplementary right/back cast, release, dodge, hurt and fallen
  poses for traveler, mage and thief; generated separately to fix source layouts.

`tools/art/inspect_heroine_atlases.py` measures alpha bounds and creates the
reviewed 48-pose-per-class mapping in `regions.gd`. Main mage atlas has 42 cells;
other main atlases have 48. The mapping skips incorrectly oriented source cells,
uses the supplemental right/back frames, and mirrors mage's right support frames
for left support poses at runtime. Frame body-height metadata normalizes the
higher resolution supplement against standing art. No male character frames are
used for female heroes. Four cardinal directions are used for diagonal movement.

Both equipment tiers share the class's female silhouette, as with male class
wardrobes. Sex and palette are independent cosmetic selections stored in v9 saves;
gear restrictions, stats, skills and effects still depend on vocation.
