# Eight-direction resident movement

Original art generated with **built-in ImageGen**, 2026-09-21. All eight `*_walk.png` files preserve the generated RGBA pixels and alpha without resizing, repainting, recoloring, or mirroring. Each sheet is 887 × 1774 pixels. Reference: the original `residents.png` identity atlas documented in [PROMPT.md](PROMPT.md). These are generated original assets, not acquired third-party art.

| Identity | Role | Source and exact prompt |
| --- | --- | --- |
| mira | 織工・米菈 | [atlas](mira_walk.png), [prompt](mira_walk_prompt.md) |
| flo | 園丁・芙蘿 | [atlas](flo_walk.png), [prompt](flo_walk_prompt.md) |
| sien | 觀月人・席恩 | [atlas](sien_walk.png), [prompt](sien_walk_prompt.md) |
| locke | 陶匠・洛克 | [atlas](locke_walk.png), [prompt](locke_walk_prompt.md) |
| ada | 裁縫・艾妲 | [atlas](ada_walk.png), [prompt and back-left correction](ada_walk_prompt.md) |
| rain | 旅人・雷恩 | [atlas](rain_walk.png), [prompt](rain_walk_prompt.md) |
| seph | 藥師・賽芙 | [atlas](seph_walk.png), [prompt](seph_walk_prompt.md) |
| owen | 藏書人・歐文 | [atlas](owen_walk.png), [prompt](owen_walk_prompt.md) |

Rows: down, down-left, left, up-left, up, up-right, right, down-right. Columns: idle, contact A, passing, contact B. Animation plays drawings 1 → 2 → 3 → 2 at six drawings per second and returns to drawing 0 when stopped or input is locked. Actual silhouettes and strides vary naturally by outfit; long dresses have smaller visible steps.

The generated gutters are not an exact grid. `python3 tools/art/build_resident_frames.py` reads alpha only, measures separated columns and rows, and writes each `*_walk.tres` plus `*_measurements.json`. It does not modify PNGs. Requirements: Pillow and NumPy. AtlasTexture margins normalize each drawing to 320 × 320 with a measured foot baseline at y=300. A fixed pivot and reference height per direction prevent frame-by-frame scale changes; nearest filtering and alpha discard retain crisp edges. Head/foot geometry must still be visually reviewed after regeneration.

Runtime: `scripts/gameplay/resident_art.gd` selects the view relative to camera orientation and world heading. Indoor residents stay upright and face the player during dialogue, then resume their idle heading. Patrols use the same art, advance their own walking clock, yield to the player, and keep the existing routes. Every village load chooses three distinct identities from the eight; this ambient selection is transient and does not alter save data.

Verification: `tests/resident_motion_test.gd`, `tests/wandering_villager_test.gd`, `tests/house_interior_test.gd`, and the actual-renderer diagnostic gallery `tests/resident_motion_capture.gd`. See `tests/README.md` for commands.
