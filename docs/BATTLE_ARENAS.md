# 可重組立體戰鬥場景

2026-09-21：已接入第一版模組與配置系統。戰鬥環境使用獨立 3D SubViewport，既有六名角色、技能特效與操作 UI 依固定鏡頭投影到舞台；角色目前仍是 2D 圖集，並非骨架模型。這是可運作的第一版，概念圖不是即時畫質的驗收證據。

## 三種基礎結構、五種主題

| 主題 ID | 場景 | 固定結構 | 隨機裝飾池 |
| --- | --- | --- | --- |
| `village` | 村莊廣場 | 廣場、後排房屋、月環 | 木箱、陶罐、路標、草、花、碎石 |
| `forest` | 林間空地 | 林地地面、後方樹林 | 樹、倒木、路標、草、花、碎石 |
| `ruins` | 月夜遺跡 | 石台、階梯、矮牆、後方殘柱 | 殘柱、路標、草、碎石 |
| `moon_spring` | 月泉石岸 | 遺跡基座、後方水池 | 殘柱、蘆葦、花、碎石 |
| `eclipse` | 月蝕神殿 | 遺跡基座、後方石拱 | 殘柱、路標、碎石 |

月泉水面重用既有 `water_feature.gd` 動態水面 shader；沒有跨 renderer 的即時反射或景深承諾。森林與村莊輪廓採程序式幾何，殘柱、木箱與陶罐重用既有原創 GLB，地面與遠景重用已生成素材。整張概念背景不參與隨機翻轉或換色。五種場景可供預覽，但目前主線遭遇仍在遺跡；不新增探索地圖、敵人或掉落。

## 狀態與重現

`GameState.begin_party_battle(enemy)` 建立權威暫存 `battle_visual`；村莊與室內地圖預設 `village`，其他現有地圖預設 `ruins`。測試或明確指定遭遇可傳 `arena_theme`、整數 `visual_seed`。離開戰鬥、開新遊戲或讀檔會清理戰鬥描述。一般遭遇記錄各主題上次的配置編號，避免連續相同；明確指定種子則優先精確重現。

純函式位於 `scripts/systems/battle_arena_layout.gd`：

```gdscript
var descriptor: Dictionary = Layout.generate("forest", 42)
# 可选的第三參數 0..3 指定構圖；預設 -1 由種子選擇。
# 無效主題回退 ruins，無效構圖回退由種子選擇。
```

描述包含 `theme`、`visual_seed`、`layout_version = 1`、`layout_index` 與 `props`。每個裝飾保存 `kind`、`position: Vector3`、`rotation`（弧度）與等比 `scale`。同版演算法與相同主題／種子可重現一般遭遇；若明確覆寫第三參數，重建時也要提供該構圖編號。純生成器和 GameState 使用私有 `RandomNumberGenerator`，不消耗遊戲全域 RNG。

描述不寫入存檔，`SAVE_VERSION` 仍為 3；目前沒有中途存檔恢復战鬥的功能。未來若需要，必須正式遷移存檔並保存版本／種子／主題／構圖，不能只在 UI 保留副本。

## 配置限制

四套預設後景插槽決定主要疏密，再隨機選裝飾、微調旋轉、尺度與位置。大型地標固定。地面為 18 × 8，角色及中央攻擊通道保留 `x = -7..7, z = -2.5..2.5`；高物件只在 `z <= -3.5` 的後景，前景低物件只在兩端 `abs(x) >= 8, z >= 3.5`。每個物件以保守平面半徑加間距檢查，最多嘗試六次，失敗就保留空插槽，沒有無限重抽，也不建立遊戲碰撞。

兩隊分別向外移動 1 個世界單位，最近兩名角色的腳點間距由 4 增為 6，最外側腳點仍位於 `x = -7`／`7`。隊內間距、角色尺寸與技能實際命中規則保持不變。

這是平面安全區與間距保護，不等同所有攻擊姿勢／鏡頭投影遮擋的完整驗證。鏡頭目前固定；若加入旋轉、改角色站位、放大模型或修改投影，須重新檢查六個腳點、倒地姿勢、突進、頭頂提示與特效。

`BattleArena3D.build(descriptor)` 只負責渲染，重新建立時釋放舊節點。模組工廠在 `scripts/gameplay/battle_arena/modules.gd`。`PartyBattleUI` 沿用既有戰鬥規則，將角色基準點與技能範圍投影到同一固定鏡頭；結束時停止 SubViewport 更新。

## 預覽與驗證

開啟互動圖庫：

```bash
godot --path . scenes/battle_arena_gallery.tscn
```

可選五種主題、輸入種子、重現配置或隨機換景。圖庫使用本地 PartyBattle 展示模型，不建立 GameState 戰鬥、不修改任務／道具、不存檔。

配置與狀態回歸：

```bash
godot --headless --path . --script tests/battle_arena_layout_test.gd
```

成功標記：`BATTLE_ARENA_LAYOUT_TEST_PASS reproducible variation themes clearance spacing rng lifecycle`。涵蓋 640 個種子／主題組合、間距、保留區、種子重現、全域 RNG 隔離、連續配置去重、非法參數回退與狀態清理；不寫入任何存檔。

真實 renderer 擷取五主題 × 兩種子：

```bash
godot --path . --rendering-method forward_plus scenes/battle_arena_gallery.tscn -- --capture-dir=/tmp/wanderlight-arena-forward
godot --path . --rendering-method gl_compatibility scenes/battle_arena_gallery.tscn -- --capture-dir=/tmp/wanderlight-arena-compatibility
```

擷取成功標記只代表檔案產生，仍需目視检查。另依 repository 的 AGENTS.md 跑雙 renderer 主線 playthrough、Web 匯出、`git diff --check`，並檢查所有輸出沒有 `ERROR:`／`SCRIPT ERROR:`。主線回歸不能取代五主題的實際畫面與操作驗收。


### 2026-09-21 完成驗證

下列命令均通過，且輸出沒有 `ERROR:`／`SCRIPT ERROR:`：

```bash
godot --headless --path . --rendering-method forward_plus --script tests/battle_arena_integration_test.gd
godot --headless --path . --rendering-method gl_compatibility --script tests/battle_arena_integration_test.gd
godot --headless --path . --rendering-method gl_compatibility --script tests/party_battle_ui_test.gd
godot --headless --path . --rendering-method gl_compatibility --script tests/caster_motion_test.gd
godot --headless --path . --rendering-method gl_compatibility --script tests/traveler_attack_motion_test.gd
godot --headless --path . --rendering-method gl_compatibility --script tests/party_equipment_test.gd
godot --headless --path . --rendering-method forward_plus -- --playthrough-test
godot --headless --path . --rendering-method gl_compatibility -- --playthrough-test
mkdir -p build/web
godot --headless --path . --export-release Web build/web/index.html
git diff --check
```

整合測試涵蓋五主題、獨立 3D 世界、六人腳點與圖集上緣、地面範圍投影、預覽不變更 GameState、攻擊特效圖層、結束後停止渲染。雙 renderer 主線均出現 `PLAYTHROUGH_TEST_PASS dialogue quest maps save battle`；既有裝備測試覆蓋 84 個戰鬥姿勢。

真實 Forward+／Compatibility 各擷取五主題 × 兩種子，共 20 張有六名角色的即時畫面。最新素材位於忽略版控的 `.dream-loop/battle-arena-gallery-forward/` 與 `.dream-loop/battle-arena-gallery/`；沒有將擷取檔或 Web 匯出加入版本控制。

Web 匯出另在全新 Chrome／Playwright context，以 `--battle-preview --mute-audio` 啟動並實際操作旅人攻擊、諾亞攻擊、長老範圍技能。確認 WebGL2 未遺失 context、1280 × 720 畫布、無 console／script errors，並檢視攻擊後與橢圓範圍預覽／命中畫面。這是一般遺跡戰鬥的 Web smoke，並非五主題所有設備／瀏覽器效能保證。

目前角色仍是投影到 3D 地面的 2D 裝備圖集；預览不支援自由旋轉鏡頭。一般地圖的預設主題為 `village`／`ruins`，其他三主題須使用圖庫或遭遇 `arena_theme` 覆寫，不會自動新增主線遭遇。
