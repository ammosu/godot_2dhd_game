# 第一章美術（Codex ImageGen）

2026-10-04 以 Codex CLI 內建 imagegen（`codex exec`，每張一次呼叫）產生的原創素材，非第三方下載。呼叫方式統一為
`python3 tools/art/codex_image.py <prompt.md> <output.png> [reference.png ...]`，參考圖依序附上；原始輸出另存於 `~/.codex/generated_images/`。

| 檔案 | 用途 | 參考圖 | 後處理 |
| --- | --- | --- | --- |
| `residents/sia_walk.png` | 鐘守希雅八方向行走圖集（星灣城 NPC、同行隊友、對話頭像） | `residents/ada_walk.png`（格式與畫風）、`city_residents/city_residents.png`（星灣城畫風） | 無；`tools/art/build_resident_frames.py sia` 量測產生 `sia_walk.tres` |
| `residents/noah_walk.png` | 諾亞八方向行走圖集（同行隊友） | `noah_facings.png`（身分，取第一列裝束）、`residents/ada_walk.png`（格式） | 無；同上產生 `noah_walk.tres` |
| `lantern_bearer.png` | 第一章結尾：提燈人與雲海燈點插圖 | `fog_awakening.png`（畫風與色盤） | 無 |
| `crypt_bell_seal.png` | 灰燼墓窟入口的鐘紋封門青銅圓板 | `village_gate_plaque.png`（畫風） | 依 alpha 裁切後最近鄰縮為一半 |

`residents/sia.tres` 為行走圖集第一格的站姿 AtlasTexture；頭像由 `scripts/ui/portrait_faces.gd` 從同一圖集裁切。

## 提示詞

### 希雅行走圖集

```text
Use case: stylized-concept. Production original HD-2D JRPG pixel-art movement sprite sheet.
Image 1 is the LAYOUT AND STYLE reference: an existing 4x8 walk atlas from this game (another character). Match its exact grid layout, sprite scale, crisp detailed pixel outlines, chunky clustered shading and 3-head-tall chibi adult proportions. Do NOT copy that character's identity.
Image 2 is a style reference of the harbour town's residents; the new character belongs to that town.
Generate ONLY this NEW original character: Sia, a cheerful young woman (about 18), apprentice bell-keeper of a foggy harbour town. Short dark chestnut bob with a small copper hair clip, warm brown eyes, friendly open expression. Short deep-navy hooded capelet over a cream shirt and a rust-orange vest, dark teal knee-length skirt over brown leggings, sturdy brown lace-up boots. Holds a small copper bell-mallet (short wooden handle, round copper head) in her right hand, pointed down. A small brass hand-bell hangs from her left hip on a leather belt. Practical, not armoured, no sword.
One tall transparent RGBA atlas, exactly FOUR COLUMNS by EIGHT ROWS = 32 isolated full body sprites. 1024x2048 or higher, 1:2 aspect ratio. Equally spaced cells with generous EMPTY gutters, especially between rows; complete heads and feet. No borders, labels, text, ground, shadows, or other characters. Genuine transparent background.
Each ROW faces one direction:
1 DOWN straight toward viewer;
2 DOWN-LEFT front three-quarter toward image left;
3 LEFT strict side profile;
4 UP-LEFT back three-quarter toward image upper left;
5 UP full back view, NO face;
6 UP-RIGHT back three-quarter toward image upper right;
7 RIGHT strict side profile;
8 DOWN-RIGHT front three-quarter toward image right.
All four figures within a row face the SAME direction.
Four COLUMNS per row:
1 neutral idle feet together;
2 clear left-foot-forward/right-foot-back walking contact stride;
3 passing stride feet near together slight body lift;
4 opposite right-foot-forward/left-foot-back walking contact stride.
Actual distinct leg and shoe positions, subtle natural arm swing, held items stable. Constant head size and height across all 32, including the last row. Accessories stay on anatomically consistent sides; do not mirror sprites. Full bodies inside cells, no overlap. Exact row order, all 8 directions accurate.
```

### 諾亞行走圖集

```text
Use case: stylized-concept. Production original HD-2D JRPG pixel-art movement sprite sheet.
Image 1 is the IDENTITY reference: this game's gatekeeper Noah standing in eight facings (use ONLY the TOP ROW outfit: steel pauldrons and arm guards, blue tabard with a pale emblem, blue scarf, brown belt with pouch, brown boots, short curly brown hair, plain steel-tipped wooden spear). Preserve his exact face, hair, colours, outfit and spear.
Image 2 is the LAYOUT AND STYLE reference: an existing 4x8 walk atlas from this game (another character). Match its exact grid layout, sprite scale, outlines and shading. Do NOT copy that character's identity.
Generate ONLY Noah walking, spear held upright in his right hand and stable across frames.
One tall transparent RGBA atlas, exactly FOUR COLUMNS by EIGHT ROWS = 32 isolated full body sprites. 1024x2048 or higher, 1:2 aspect ratio. Equally spaced cells with generous EMPTY gutters, especially between rows; complete heads and feet. No borders, labels, text, ground, shadows, or other characters. Genuine transparent background.
Each ROW faces one direction:
1 DOWN straight toward viewer;
2 DOWN-LEFT front three-quarter toward image left;
3 LEFT strict side profile;
4 UP-LEFT back three-quarter toward image upper left;
5 UP full back view, NO face;
6 UP-RIGHT back three-quarter toward image upper right;
7 RIGHT strict side profile;
8 DOWN-RIGHT front three-quarter toward image right.
All four figures within a row face the SAME direction.
Four COLUMNS per row:
1 neutral idle feet together;
2 clear left-foot-forward/right-foot-back walking contact stride;
3 passing stride feet near together slight body lift;
4 opposite right-foot-forward/left-foot-back walking contact stride.
Actual distinct leg and shoe positions, subtle natural arm swing, held items stable. Constant head size and height across all 32, including the last row. Accessories stay on anatomically consistent sides; do not mirror sprites. Full bodies inside cells, no overlap. Exact row order, all 8 directions accurate.
```

### 提燈人插圖

```text
Use case: illustration-story. Asset type: original HD-2D pixel-art JRPG chapter-ending vignette, landscape 16:9 (about 1672x941). Image 1 is the STYLE reference (an existing ending illustration of this game: dithered night fog, indigo / muted teal / soft silver palette, rich deliberate pixel clusters). Match its style and palette, not its composition.
Scene: a high mountain lookout above a sea of clouds at night under a large pale moon. In the middle distance, a tall robed figure walks out of the drifting fog holding up an old iron lantern on a staff; the lantern glows soft silver-white, not orange. The figure is seen from a respectful distance, face hidden in the shadow of a deep hood, only the lantern light touching the hood edge and a long travel-worn cloak. Calm, ancient, kind but unknowable; not a monster, not menacing, no visible eyes. Far below in the cloud sea, a few tiny faint lights glow at scattered distant points like lost villages. Foreground: worn flat stones of the lookout and a little wind-bent grass at the bottom edge. Melancholy wonder. No text, no UI, no logos, no watermark. Original world, no existing game characters.
```

### 鐘紋封門

```text
Use case: stylized-concept. Asset type: original HD-2D JRPG pixel-art game texture, square 1024x1024, front-on, flat lighting. Image 1 is a style reference (this game's carved wooden gate plaque art); match its painterly pixel style.
A heavy round bronze seal plate that will be mounted on an ancient stone crypt door: weathered greenish bronze disc, a raised relief of a temple bell in the centre with concentric sound-wave rings around it, a thin ring of small notches near the rim, faint ash-grey soot in the recesses, four iron rivets. Fill the canvas with the disc, centered, with a genuine transparent background outside the disc. No text, no letters, no logos.
```
