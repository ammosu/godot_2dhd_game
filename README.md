# Wanderlight: Moon Shard

這是一個以 Godot 4.7 建立的原創 HD-2D 技術基線，參考
[SimpleHD2D](https://github.com/GSansigolo/SimpleHD2D) 的核心方向：把清晰的 2D 角色放進有光影、透視與景深的 3D 世界。

目前是一個可以從頭玩到任務完成的 HD-2D JRPG vertical slice：

- CC0 四方向像素角色、行走動畫與相機相對移動
- 可平滑旋轉、縮放並追蹤玩家的透視相機
- 暮光村與北境遺跡兩張地圖、碰撞、燈光、薄霧、發光物件與景深
- CC0 像素場景裝飾／HUD、最近鄰取樣與輕量色調／暗角 shader
- NPC 對話、主線任務、任務目標與完成獎勵
- 回合制戰鬥：攻擊、技能、藥水、防禦、勝利與戰敗流程
- JSON 存檔／讀檔，保存地圖、位置、任務、旗標、道具、HP 與 MP

## 遊玩流程

1. 在暮光村與廣場左側的長老交談。
2. 接受「月光碎片」任務，從北方藍色門扉前往北境遺跡。
3. 與遺跡守衛互動並贏得戰鬥。
4. 從南方門扉返回村莊，將月光碎片交給長老。

## 操作

- `WASD`／方向鍵：移動
- `Space`／`Enter`：互動、繼續對話
- `Q`／`E`：旋轉鏡頭
- `R`／`F`：縮放鏡頭
- `F5`：儲存遊戲
- `F9`：讀取遊戲
- 戰鬥中按 `1`～`4`：攻擊、月影斬、藥水、防禦

## 執行

用 Godot 4.7.x 開啟此資料夾後執行主場景，或在終端執行：

```bash
godot --path .
```

完整 playthrough smoke test：

```bash
godot --headless --path . -- --playthrough-test
```

通過時會輸出：`PLAYTHROUGH_TEST_PASS dialogue quest maps save battle`。

## 系統結構

- `scripts/systems/game_state.gd`：任務、玩家數值、道具、地圖狀態及 JSON 存讀檔
- `scripts/ui/dialogue_ui.gd`：多段式對話與輸入鎖定
- `scripts/ui/battle_ui.gd`：回合制指令、敵方回合與勝敗處理
- `scripts/gameplay/interactable_3d.gd`：NPC、門扉與敵人的統一互動介面
- `scripts/world.gd`：兩張地圖、事件配置及完整主線流程

目前桌面預設使用 Forward+，以呈現景深、進階光影與高品質 bloom；行動裝置預設使用 Mobile。若目標包含 Web／舊硬體，需另做 Compatibility 畫質配置，並停用不支援的景深效果。正式製作應建立低／中／高三組畫質設定。

## 為何沒有直接複製參考專案

截至本專案建立時，SimpleHD2D 倉庫沒有宣告 LICENSE；其中的角色圖也來自商業遊戲《Final Fantasy VI》。因此本專案只參考構成方式，沒有複製其程式碼或素材。程式與原始 SVG 佔位圖皆為本專案重新製作；後續引入的第三方像素素材則逐項記錄於 [THIRD_PARTY_ASSETS.md](THIRD_PARTY_ASSETS.md)。

## 從 Godot 4.1 參考案升級時要調整

1. **版本與 renderer**：參考案鎖定 4.1／Forward+。本機目前是 4.7.1；正式製作應固定同一個 4.7 patch 版本並檢查每一版 migration guide。Forward+ 適合桌面，Mobile 適合新款手機，Web／舊硬體則需 Compatibility，三者畫面不能假設完全一致。
2. **DOF 歸屬**：Godot 4 的景深與曝光屬於 `CameraAttributes`，不是 `Environment`。本專案把它掛在目前相機，避免非當前相機也套用。
3. **角色素材**：像素角色須用最近鄰取樣、billboard、透明裁切及一致的 pixels-per-unit。正式素材不應使用 FF6／歧路旅人角色或拆圖。
4. **輸入與移動**：參考案的腳本未型別化、鏡頭旋轉時會重複建立 tween，且減速沒有乘 `delta`。目前版本改為型別化 GDScript、相機狀態插值與 frame-rate independent acceleration。
5. **場景資料**：參考案把城堡幾乎全部序列化成單一巨大 `GridMap`。小型原型可接受；正式地圖應拆成區塊、可重用場景與資料資源，遠景再使用 MultiMesh、遮擋剔除與 LOD。
6. **後製預算**：Glow、SSAO、SSIL、景深、陰影與體積霧不能一次全部拉滿。透明 Sprite3D 也容易遇到排序、景深邊緣與陰影不一致，應在每個目標平台做 GPU profile。
7. **專案衛生**：不提交 `.godot/` 匯入快取與 `.DS_Store`；CI 至少執行 headless import／啟動測試，避免升級後場景或 shader 靜默失效。

後續 production 方向見 [docs/ROADMAP.md](docs/ROADMAP.md)。
