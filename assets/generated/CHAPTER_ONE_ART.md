# 第一章美術（Codex ImageGen）

2026-10-04 以 Codex CLI 內建 imagegen（`codex exec`，每張一次呼叫）產生的原創素材，非第三方下載。呼叫方式統一為
`python3 tools/art/codex_image.py <prompt.md> <output.png> [reference.png ...]`，參考圖依序附上；原始輸出另存於 `~/.codex/generated_images/`。

| 檔案 | 用途 | 參考圖 | 後處理 |
| --- | --- | --- | --- |
| `residents/sia_walk.png` | 鐘守希雅八方向行走圖集（星灣城 NPC、同行隊友、對話頭像） | `residents/ada_walk.png`（格式與畫風）、`city_residents/city_residents.png`（星灣城畫風） | 無；`tools/art/build_resident_frames.py sia` 量測產生 `sia_walk.tres` |
| `residents/noah_walk.png` | 諾亞八方向行走圖集（同行隊友） | `noah_facings.png`（身分，取第一列裝束）、`residents/ada_walk.png`（格式） | 無；同上產生 `noah_walk.tres` |
| `lantern_bearer.png` | 第一章結尾：提燈人與雲海燈點插圖 | `fog_awakening.png`（畫風與色盤） | 無 |
| `crypt_bell_seal.png` | 灰燼墓窟入口的鐘紋封門青銅圓板 | `village_gate_plaque.png`（畫風） | 依 alpha 裁切後最近鄰縮為一半 |
| `residents/sia_action.png` | 希雅野外戰鬥姿勢（預備、舉槌、敲鈴、收勢），左右兩向 | `residents/sia_walk.png`（身分與畫風） | `build_resident_frames.py --action sia` 以連通區塊拆出八格，另存乾淨的 `sia_action_frames.png` 與 `sia_action.tres`；原圖不變 |
| `residents/noah_action.png` | 諾亞野外戰鬥姿勢（預備、後拉、突刺、架槍防禦），左右兩向 | `residents/noah_walk.png`（身分與畫風） | 同上；後拉格未畫槍頭，執行時以預備姿勢代替 |

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

### 希雅戰鬥姿勢（2026-10-05）

```text
Use case: stylized-concept. Production original HD-2D JRPG pixel-art battle action sprite sheet.
Image 1 is the IDENTITY AND STYLE reference: this game's walk atlas of Sia, a cheerful young bell-keeper (short dark chestnut bob with copper hair clip, deep-navy hooded capelet, cream shirt, rust-orange vest, dark teal skirt, brown boots, small copper bell-mallet in right hand, brass hand-bell on left hip). Preserve her exact face, hair, outfit, colours and proportions.
One wide transparent RGBA sprite sheet, exactly FOUR COLUMNS by TWO ROWS = 8 isolated full-body sprites of the SAME character, about 2048x1024 (2:1). Equally spaced cells with generous EMPTY transparent gutters between all sprites; complete heads, feet and held items inside each cell, nothing touching or overlapping a neighbouring cell. Same sprite scale, head size and outline/shading style as image 1. Feet on a common baseline in each row. No borders, labels, text, ground, shadows, effects, sound waves or other characters. Genuine transparent background.
ROW 1: the character in front three-quarter view turned toward image LEFT (body and face angled to screen-left).
ROW 2: the same four poses in front three-quarter view turned toward image RIGHT.
COLUMNS (same in both rows):
1 READY: alert battle stance, knees slightly bent, mallet held ready at chest height, other hand on the hip bell.
2 WINDUP: mallet raised high above the shoulder, hand-bell lifted up in the other hand, determined face.
3 RING: mallet swung down striking the hand-bell held out in front, body leaning into the strike, mouth open as if calling out.
4 RECOVER: mallet lowered, bell held to the side, light confident smile, weight settling back.
```

### 諾亞戰鬥姿勢（2026-10-05）

```text
Use case: stylized-concept. Production original HD-2D JRPG pixel-art battle action sprite sheet.
Image 1 is the IDENTITY AND STYLE reference: this game's walk atlas of Noah, a young gatekeeper (short curly brown hair, steel pauldrons and arm guards, blue tabard with pale emblem, blue scarf, brown belt with pouch, brown boots, plain steel-tipped wooden spear). Preserve his exact face, hair, outfit, colours and proportions.
One wide transparent RGBA sprite sheet, exactly FOUR COLUMNS by TWO ROWS = 8 isolated full-body sprites of the SAME character, about 2048x1024 (2:1). Equally spaced cells with generous EMPTY transparent gutters between all sprites; complete heads, feet and held items inside each cell, nothing touching or overlapping a neighbouring cell. Same sprite scale, head size and outline/shading style as image 1. Feet on a common baseline in each row. No borders, labels, text, ground, shadows, effects, sound waves or other characters. Genuine transparent background.
ROW 1: the character in front three-quarter view turned toward image LEFT (body and face angled to screen-left).
ROW 2: the same four poses in front three-quarter view turned toward image RIGHT.
COLUMNS (same in both rows):
1 READY: low guard stance, spear held diagonally across the body with both hands, tip forward.
2 WINDUP: spear drawn back at waist height with both hands, front foot planted, body coiled.
3 THRUST: full forward spear thrust with arms extended toward the faced direction, lunging step.
4 GUARD: braced defensive stance, spear shaft held horizontally in front of the chest with both hands to block, feet wide.
```

長兵器會跨進相鄰欄位，因此動作圖不以欄間空白切格，而以 4 連通區塊辨識八個角色；貼邊的半透明像素歸給緊鄰的角色，其餘雜點捨棄，每格單獨貼入 `<名>_action_frames.png`，避免矩形裁切帶到鄰格的槍頭。

## 第一章演出補強（2026-10-05）

同樣以 `tools/art/codex_image.py` 產生的原創素材，均存於 `chapter_one/`：

| 檔案 | 用途 | 參考圖 | 後處理 |
| --- | --- | --- | --- |
| `chapter_one/elder.png`、`bell.png`、`throne.png`、`campfire.png` | 長老坦白、鐘樓庭、空王座、峽道營火的對話插圖 | `fog_awakening.png` 或 `moon_spring_memory.png`（畫風）；鐘樓與營火另附 `sia_walk.png`／`noah_walk.png` 以維持角色外觀 | 無 |
| `chapter_one/cloud_sea.png` | 風切峽道與月冠高地的雲海環景（`panorama_ring.gd`） | `village_mountains.png`、`lantern_bearer.png` | 依 alpha 裁上緣後最近鄰縮半；左右可無縫拼接 |
| `chapter_one/moon.png` | 高地天空的月亮與遠方藍燈（`sky_moon.gd`，藍燈為同圖染色） | `lantern_bearer.png` | 依 alpha 裁切後最近鄰縮半 |
| `chapter_one/lantern_bearer_sprite.png` | 章末山路上走近的提燈人 | `lantern_bearer.png`、`residents/noah_walk.png` | 依 alpha 裁切後最近鄰縮半 |
| `chapter_one/folk_girl.png`、`folk_boy.png`、`bell_master.png` | 星灣城鐘樓的孩子與師父 | `city_residents/city_residents.png`、`residents/sia_walk.png` | 由一張三人圖依三等分與 alpha 裁出 |

### 插圖提示詞共同前綴

```text
Use case: illustration-story. Asset type: original HD-2D pixel-art JRPG story vignette, landscape 16:9 (about 1672x941), shown full-screen behind dialogue text, so keep the lower fifth calm and darker. Image 1 is the STYLE reference (an existing illustration of this game: rich deliberate pixel clusters, dithered atmosphere, restrained palette, painterly HD-2D pixel art). Match its style, not its composition. No text, no UI, no logos, no watermark. Original world, no existing game characters.
```

各插圖場景描述：

```text
Scene: a village plaza at night beside a tall glowing stone moon-lamp with a silver flame. An old village elder with a white beard and long dark robe stands in the lamp light, looking down at the bronze seal ring in his open palm; on the seal a fresh burn mark glows faintly in the shape of a ring with a gap (a broken circle). His face shows quiet guilt. Around the base of the lamp, thin lines of silver light run through the paving stones toward the right edge of the image (east). Cottages and a pig asleep in the background, soft mist. Palette: silver moonlight, deep indigo, warm lamp edges.

Scene: a stone bell-tower courtyard of a harbour town at dusk, warm lantern light and faint sea mist. A cheerful young woman (short dark chestnut bob with a small copper hair clip, deep-navy hooded capelet, rust-orange vest, dark teal skirt; see image 2 for her exact look) kneels beside a large old bronze bell that has been lowered onto a wooden frame, holding a small copper mallet and listening closely. A long dark crack runs through the bell's bronze, curving into a ring shape with a gap, like a broken circle. Tools, rope coils and a small brass hand-bell on the flagstones; above, the empty bell tower arch against an amber-and-indigo sky.

Scene: the deepest hall of an ancient ash-choked crypt. A huge empty stone throne on a stepped dais, its seat and armrests buried under drifts of grey ash; a broken iron crown-shaped crest above it. Before the dais a small stone altar holds a single crystal shard completely coated in dull ash, giving no light. Thin smoke and faint ember motes float in the dark; cold blue light from a high crack falls across the throne. Nobody sits on the throne; a sense of a voice lingering. Palette: charcoal, ash grey, dim ember red, cold blue.

Scene: night in a narrow windy mountain gorge, a small campfire sheltered behind a boulder. Three travellers sit around the fire, seen from a gentle three-quarter distance: on the left a young gatekeeper in steel pauldrons and a blue tabard with short curly brown hair, his spear leaning on the rock (image 2 shows him); on the right a cheerful young woman with a dark chestnut bob and a deep-navy capelet holding a bowl of soup (image 3 shows her); in the foreground centre a third traveller seen from BEHIND with a travel cloak and hood up, face and body hidden. Warm orange firelight against cold blue rock and drifting cloud, sparks rising, a tin pot over the fire.
```

### 雲海、月亮、提燈人、鐘樓人物

```text
Use case: stylized-concept. Asset type: original HD-2D pixel-art JRPG background panorama strip, very wide 4:1 (about 2048x512), horizontally SEAMLESS (left and right edges must tile perfectly), front-on, for a ring backdrop seen from a high mountain lookout at night.
Image 1 is the STYLE reference (this game's distant mountain panorama); match its painterly pixel style. Image 2 is the mood reference (moonlit cloud sea).
Content, bottom to top: a dense rolling sea of moonlit clouds filling the lower half, soft silver-white tops with blue-indigo shadows; several distant dark mountain peaks rising out of the clouds at different distances along the strip; a few tiny warm lights of far-away settlements glowing faintly between cloud gaps; the upper part above the peaks is genuinely TRANSPARENT (alpha 0) so the game's own sky shows through. No moon, no sky colour band, no text, no frame. Genuine transparent RGBA background above the peaks.
```

```text
Use case: stylized-concept. Asset type: original HD-2D pixel-art game sky sprite, square 1024x1024, a single large full moon for a night sky. Image 1 is the STYLE reference (this game's moonlit illustration); match its pixel-art moon rendering and palette.
A pale silver-white full moon with soft grey maria, slightly cool tint, crisp pixel clusters, centred, with a soft wide glow halo that fades smoothly to fully transparent at the edges. Genuine transparent RGBA background outside the glow. No clouds, no stars, no text.
```

```text
Use case: stylized-concept. Asset type: original HD-2D JRPG pixel-art character sprite, single full-body figure, tall portrait canvas about 512x1024. Image 1 is the identity and style reference (this game's lantern-bearer illustration): match that figure — a tall robed traveller in a long travel-worn grey cloak, deep hood hiding the face completely in shadow, holding up an old iron lantern on a staff with a soft silver-white glow.
Three-quarter front view walking toward the viewer, one step forward, staff in the right hand with the lantern hanging at the top beside the hood. Crisp pixel outlines and chunky shading like this game's sprites, 3-head-tall chibi proportions like image 2 (the game's walk sprites). No face visible, no eyes. Genuine transparent RGBA background, no ground, no shadow, no text.
```

```text
Use case: stylized-concept. Production original HD-2D JRPG pixel-art NPC sprite sheet. Image 1 is the STYLE reference (this game's harbour-town residents atlas): match its crisp pixel outlines, chunky shading and 3-head-tall chibi proportions. Image 2 shows Sia (the bell-keeper apprentice) for costume consistency of the bell tower household.
ONE transparent RGBA sheet, exactly THREE full-body FRONT-FACING idle characters in a single row, equally spaced with wide empty transparent gutters, same baseline, about 1536x768. No text, ground, shadows or borders.
1 A small girl (about 8) of the harbour town: two short dark braids, oversized navy knit sweater, brown shorts, holding a folded paper letter in both hands, eager smile.
2 A small boy (about 9): messy sandy hair, rust-orange scarf, patched grey tunic, holding a tiny brass hand-bell, curious face.
3 An old bell-tower master: tall, white close-cropped beard, deep-navy long coat with copper buttons like Sia's capelet, leather apron with tools, holding a large wooden bell mallet resting on his shoulder, kind stern face.
Children clearly shorter (about two-thirds of the adult's height).
```
