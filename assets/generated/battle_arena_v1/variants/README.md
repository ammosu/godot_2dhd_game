# 可重組戰鬥場景設計

2026-09-21，內建 ImageGen 原創生成。此批四張圖為構圖／氣氛參考與完整背景候選，原始像素未修改；不是已拆層的模組素材、模型或已實作的隨機場景。

## 三種基本場景，五種美術主題

| 基本場景 | 主題 | 固定結構 | 可配置裝飾 |
| --- | --- | --- | --- |
| 村莊廣場 | 暮光村 | 石板廣場、側邊屋群、後方月燈 | 木箱、陶罐、草花、側邊燈籠 |
| 林間空地 | 林間古道 | 平坦土路、林緣、後方出口 | 蕨草、倒木、岩石、路標 |
| 遺跡石台 | 月夜遺跡（上一批） | 石台、邊緣階梯、矮牆 | 殘柱、碎石、苔蘚、旗布 |
| 遺跡石台 | 月泉石岸 | 共用石台，後方加入固定水池 | 蘆葦、花草、岸邊石塊 |
| 遺跡石台 | 月蝕神殿 | 共用石台，後方固定破拱與月蝕天空 | 殘柱、青銅飾件、碎石 |

月蝕神殿為提案主題，尚無對應新地圖／遭遇。概念圖內城堡、村落規模、湖泊、柱式、月燈造型與遠景建築僅作視覺參考；建置時以現有世界設定與已完成資產為準。月泉圖生成為較寬湖岸，實作縮為後方水池，不照圖擴充探索地圖。

## 隨機排列規則（待實作）

1. 先選 biome / theme，再從每種基本場景預先設計的 3–4 組裝飾配置中選一組。角色站位、地面與中央攻擊通道固定，隨機變化只影响美術。
2. 配置包含有類型限制的擺放點：後景高物件、側景中物件、前景低物件。每點有允許模型、權重、最大尺寸、旋轉範圍與可留空機率；不是在全場任意撒物件。
3. 先放大型地標，再選中型裝飾，最後補少量草石。用佔地半徑排除物件重疊；用相機投影檢查裝飾是否蓋住六個站位、受擊退後範圍、突進路徑、倒地姿勢、頭頂提示及技能特效範圍。
4. 3D 模型可小幅旋轉／等比縮放；billboard 只能換圖或在適合的對稱素材上鏡像，不能靠任意水平旋轉假裝有側面。模型站在真正地面高度，不新增遊戲碰撞。
5. 主題有明確裝飾池，村莊陶罐不隨機出現在神殿；草石可共用。大型地標與劇情必需物件固定，不能抽掉。密度、光色和明暗只在主題預設的小範圍變化。
6. 使用獨立 RandomNumberGenerator 和明確 visual_seed；不可消耗命中、暴擊或掉落所用 RNG。同一 theme、layout_version、visual_seed 重建同配置。重抽只在戰鬥建立時發生。
7. GameState 持有本次遭遇的視覺描述，UI 不另存一份權威狀態。若將來需要中途存檔恢復，需把 seed、theme、layout_version 納入正式存檔版本遷移；本次未改存檔。
8. 相機先保持固定、景物稀疏優先。避免連續兩場同配置可在遭遇建立時選取其他 layout，再記下結果；重載不可再次抽選。
9. 抽樣配置若不通過遮擋／間距檢查，限制重試次數並回退到已驗收的空曠配置，避免無限重抽。

## 素材生產順序

- 已有可重用來源：weathered_pillar_v2.glb、supply_crate.glb、earthenware_jar.glb、moon_halo.glb、草花圖集、石灰岩與石板材質。各來源沿用原有生成／授權記錄。
- 下一批應做：共用石台／階梯／矮牆網格、林地材質、樹幹／倒木／路標，以及必要的透明遠景分層；先查現有資源能否重用再新增。
- 村莊／森林／遺跡各完成一個可運作的基本場景後，才加月泉水池與神殿破拱等主題模組。
- 不將整張背景隨機翻轉或改色當成模組排列。整圖有固定光線、透視與地標；真正的隨機化須依靠獨立網格或透明圖層。
- 正式接入時沿用 GameState／PartyBattle 的戰鬥規則，獨立 BattleArena3D 負責顯示；現有 UI 顯示輸入與數值。
- 繼續遵循 nearest 像素風格、Forward+ 與 Compatibility、Web 單執行緒。生成圖中的景深／水反射是美術參考，不保證即時效果跨 renderer 相同。

## 本批檔案與提示詞

四張皆為 1672 × 941 PNG。已目視確認空曠站位、完整構圖、無人物／介面。尚未做角色疊合、裁切、遮擋或 3D 實機驗收。既有戰鬥窗口約 1120 × 380，直接 cover 會裁掉上下方；整合時需重設鏡頭／畫面配置。

### 暮光村廣場 — village_dusk.png

Use case: stylized-concept. Create an original polished environment-only battle background and 3D environment visual target for Wanderlight Moon Shard, an HD-2D JRPG. Wide 16:9 full opaque image. Consistent elevated three-quarter camera looking down about 23 degrees, mostly side-on left-to-right battlefield, restrained perspective. Beautiful substantial low-poly 3D architecture and terrain with crisp finely detailed pixel-art surface clusters, not a flat cartoon and not photorealistic. Walkable arena fills lower 55 percent, spacious flat contiguous surface with room for three heroes on the left and three enemies on the right at staggered depths; center entirely clear for charges. No characters, creatures, UI, text, watermark, grids, markers or bright effects. Keep foreground occluders only at extreme corners, low contrast behind actor positions. Distinct near/middle/far depth layers. Scene: a cozy rustic village square at violet dusk, warm amber windows and small lanterns, ivory plaster and dark timber houses with blue slate roofs arranged along the rear and side edges. Broad muted gray-beige cobblestone plaza with worn curbs and visible thickness at foreground, small grass patches at perimeter. A small aged bronze open moon-ring lantern monument stands well behind the battle plane slightly left of center, never obstructing actor standing zones. Distant hills beyond a village lane, lavender blue sky. No large central well, stalls, carts, or objects in the fighting area. Palette: muted amber, dusty mauve, gray-blue slate, restrained sage. Peaceful village architecture staged for a tense encounter.

### 林間古道 — forest_old_road.png

Use case: stylized-concept. Create an original polished environment-only battle background and 3D environment visual target for Wanderlight Moon Shard, an HD-2D JRPG. Wide 16:9 full opaque image. Consistent elevated three-quarter camera looking down about 23 degrees, mostly side-on left-to-right battlefield, restrained perspective. Beautiful substantial low-poly 3D architecture and terrain with crisp finely detailed pixel-art surface clusters, not a flat cartoon and not photorealistic. Walkable arena fills lower 55 percent, spacious flat contiguous surface with room for three heroes on the left and three enemies on the right at staggered depths; center entirely clear for charges. No characters, creatures, UI, text, watermark, grids, markers or bright effects. Keep foreground occluders only at extreme corners, low contrast behind actor positions. Distinct near/middle/far depth layers. Scene: ancient abandoned road widening into a forest clearing. Broad level packed-earth fighting surface interspersed with low worn flush stone paving, no raised stones in actor lanes. Tall aged pines and twisted roots confined to side edges and rear, broken low stone roadside markers, sparse ferns, overhead canopy creating cool dappled moonlight. A weathered road recedes diagonally through mist behind the clearing. Foreground ground edge and low roots establish volume without hiding the arena. Palette: deep desaturated forest teal, soft moss green, earthy gray brown and silver moonlight. Natural asymmetry and strong depth, readable quiet battle floor, no river, no bridge, no giant centerpiece.

### 月泉石岸 — moon_spring.png

Use case: stylized-concept. Create an original polished environment-only battle background and 3D environment visual target for Wanderlight Moon Shard, an HD-2D JRPG. Wide 16:9 full opaque image. Consistent elevated three-quarter camera looking down about 23 degrees, mostly side-on left-to-right battlefield, restrained perspective. Beautiful substantial low-poly 3D architecture and terrain with crisp finely detailed pixel-art surface clusters, not a flat cartoon and not photorealistic. Walkable arena fills lower 55 percent, spacious flat contiguous surface with room for three heroes on the left and three enemies on the right at staggered depths; center entirely clear for charges. No characters, creatures, UI, text, watermark, grids, markers or bright effects. Keep foreground occluders only at extreme corners, low contrast behind actor positions. Distinct near/middle/far depth layers. Scene: sanctuary beside an ancient moonlit spring. The battle happens entirely on a wide DRY pale limestone terrace in foreground; its chipped thick edge is visible at very bottom. Water exists ONLY BEHIND the arena in a calm crescent-shaped pool edged with weathered blocks. Sparse blue-green reeds and tiny pale flowers confined to pool perimeter, delicate old pillars far rear sides, distant rocky wall and night forest. Gentle silver moon reflected in rear pool, dim turquoise mineral water, subtle mist above rear water only. Center and both teams' standing areas dry, flat, contiguous, no water gaps or stairs under fighters. Palette: pearl limestone, subdued cyan, slate and moonlit silver; magical but restrained, no giant crystal or fountain centerpiece.

### 月蝕神殿 — eclipse_sanctum.png

Use case: stylized-concept. Create an original polished environment-only battle background and 3D environment visual target for Wanderlight Moon Shard, an HD-2D JRPG. Wide 16:9 full opaque image. Consistent elevated three-quarter camera looking down about 23 degrees, mostly side-on left-to-right battlefield, restrained perspective. Beautiful substantial low-poly 3D architecture and terrain with crisp finely detailed pixel-art surface clusters, not a flat cartoon and not photorealistic. Walkable arena fills lower 55 percent, spacious flat contiguous surface with room for three heroes on the left and three enemies on the right at staggered depths; center entirely clear for charges. No characters, creatures, UI, text, watermark, grids, markers or bright effects. Keep foreground occluders only at extreme corners, low contrast behind actor positions. Distinct near/middle/far depth layers. Scene: a ruined roofless lunar temple inner sanctum designed as a proposed boss-arena variant. Vast flat dark slate floor with restrained worn bronze arcs inset flush in stone; physically thick raised floor edge visible at front. Massive broken columns and arches at rear and outer corners, carved stone rear doorway framing a SMALL distant eclipsed moon in violet night sky. Subtle muted plum reflected light, sparse old bronze fittings, fractured masonry around perimeter only. Imposing tall architectural volumes, deep layered recesses, readable open foreground. Palette: charcoal indigo, dusty plum, tarnished bronze, soft silver. No red lava, no flaming altar, no throne, no centered obstruction, no ritual text, no blinding beams; quiet ominous grandeur.
