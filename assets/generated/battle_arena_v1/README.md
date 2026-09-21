# 月夜遺跡立體對戰：第一批素材

生成日期：2026-09-21。使用內建 ImageGen，原創生成，沒有下載第三方素材。PNG 保留生成原始像素。本次只完成視覺設計與圖片素材；尚未建立 3D 模型、場景或替換現有對戰。

## 檔案

| 檔案 | 用途 |
| --- | --- |
| concept.png | 16:9 場景概念；供石台厚度、階梯、構圖與光線參考，不能當作 3D 模型 |
| flagstone_albedo.png | 正上方石板地面色彩材質；供真正的地面網格使用 |
| distant_backdrop.png | 3:1 不透明遠景；貼在遠方背景平面，非環景天空或透明分層圖 |

地材以可平鋪為生成目標，尚未完成重複鋪設接縫驗收；必要時再修邊。概念圖的城堡、湖面與燈籠為生成的構圖細節，不是新增遊戲世界設定或必做模型。遠景採獨立的山林版本。

實際尺寸：概念圖 1672 × 941、地材 1254 × 1254、遠景 2172 × 724。原圖已目視檢查用途、構圖與無文字；這不等同 3D 場景視覺驗收。

## 立體場景搭建規格（下一階段）

- 真正的 3D 石台約 14 × 8 公尺，厚約 0.6 公尺；階梯在前緣，不穿過戰鬥站位。中央走道與雙方三人站位保持平坦。
- 雙方沿 X 軸面向彼此，三名角色在 Z 軸錯開。將 PartyBattle 的邏輯位置映射到 X/Z；保留原有範圍命中規則，避免把畫面透視距離當成戰鬥距離。
- 相機初始採正交、俯角約 23 度，以既有角色側向戰鬥姿勢可讀性為優先；先保持固定方位。低幅推近須另外檢查裁切。
- 近景：角落少量真實石塊，避開角色。中景：石台、低牆與殘柱使用真實幾何。遠景：低對比山林平面。霧先以遠景本身層次呈現。
- 可沿用既有 weathered_pillar_v2.glb、石灰岩材質與角色戰鬥圖集；新石台、階梯、矮牆與破拱需另建模型。中央月紋可用獨立薄網格，兼容 Web；本批未生成月紋透明貼圖。
- 角色沿用像素 Sprite3D／AnimatedSprite3D，固定 Y 軸 billboard、腳底對齊及接觸陰影；HUD 留在 CanvasLayer，3D 顯示由獨立 Node3D／SubViewport 負責，GameState 與 PartyBattle 繼續管理狀態。
- 地板採 nearest + mipmaps，粗糙度建議 0.9；由引擎提供方向光。遠景 unshaded、停用陰影，不將它誤用為可環繞的 sky panorama。
- Desktop 維持 Forward+；Web 使用 Compatibility，避免依賴景深、體積霧或專屬 Decal 功能。正式接入後需雙 renderer 實景檢查及六角色演出驗收。
- 現有戰鬥區域約 1120 × 380；概念圖是 16:9，接入時需重新調整相機與 HUD 空間，不能直接裁切概念圖當作完成的立體戰場。

## 最終生成提示詞

驗證：Godot 素材匯入、Forward+／Compatibility headless 主線測試及 Web release 匯出通過；日誌無 `ERROR:`／`SCRIPT ERROR:`，兩次主線均出現 `PLAYTHROUGH_TEST_PASS dialogue quest maps save battle`。這些檢查覆蓋匯入與既有遊戲回歸，不代表尚未接入的 3D 場景已通過驗收。

### concept.png

Use case: stylized-concept. Asset type: environment concept art for Wanderlight Moon Shard original HD-2D JRPG, a future real 3D turn-based battle arena. Wide 16:9 composition. Moonlit ancient temple courtyard, spacious rectangular stone battle platform with physically thick chipped edges and two shallow steps visible along front and sides, elevated three-quarter camera at about 23 degrees downward, mostly side-on so two three-person teams could face each other left to right. No characters. Left and right thirds each have room for three staggered combatants in depth, center clear for attack movement. Uneven broken pillars and a short collapsed arch frame rear corners only, low rubble at extreme foreground corners, open low rear wall, distant layered pine forest, indigo mountain silhouettes, soft silver moon upper left and sparse clouds. Restrained weathered crescent inlay in center paving, muted slate blue, gray limestone, desaturated teal moss. Beautiful readable handcrafted low-poly 3D volumes with finely detailed crisp pixel-art material clusters, strong depth separation, cool moon rimlight and gentle neutral fill, subtle atmospheric distance. Platform occupies lower 60 percent, scenery does not intrude into standing lanes. Original design, no UI, text, logo, border, diagram, combat grid, people or monsters. This is a cohesive visual target, not an asset sheet.

### flagstone_albedo.png

Use case: stylized-concept. Asset type: seamless square albedo texture for the actual 3D battle-platform floor of an original HD-2D JRPG. Full-frame orthographic top-down view of weathered blue-gray stone flagstones, broad irregular rectangular slabs in staggered courses, thin muted dark grout, restrained chips and hairline cracks, very sparse gray-teal lichen in joints. Neutral moderately light desaturated slate gray base, so Godot can supply blue moon lighting later. Crisp deliberate fine pixel-art clusters, medium-scale readable slabs, low contrast material detail. Perfectly flat overhead texture, uniform scale and illumination, seamless repeating edges both axes. No directional lighting, ambient occlusion shadows, highlights, perspective, vignette, border, crescent motifs, large hero cracks, objects, vegetation clumps, words or watermarks. Entire square opaque canvas is usable material. No depicted platform or rendered sample object.

### distant_backdrop.png

Use case: stylized-concept. Asset type: distant opaque panoramic scenery texture for a layered 3D HD-2D JRPG moon-temple battle arena. Ultra-wide 3:1 landscape. ONLY distant scenery: desaturated indigo midnight sky with wispy pixel-art clouds, small restrained pale moon toward upper left, successive layered mountain ridges and a far-away pine forest with muted blue-gray mist between ridges. Forest silhouette occupies lowest 25 percent, quiet atmospheric mountains occupy middle 35 percent, sky upper 40 percent. Horizon level, viewpoint from an elevated ruin courtyard. Detailed deliberate crisp pixel-art clusters, coherent with slate-blue moonlit ruins, painterly composition but no photographic or blurred detail. Low contrast so combat characters will remain prominent. No foreground, ground platform, paving, pillars, architecture, people, monsters, bright stars, text, labels, UI, borders or watermark. Full opaque canvas. This is a distant backdrop layer, not a full battle scene.
