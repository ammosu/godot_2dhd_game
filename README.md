# Wanderlight: Moon Shard

這是一個以 Godot 4.7 建立的原創 HD-2D 技術基線，參考
[SimpleHD2D](https://github.com/GSansigolo/SimpleHD2D) 的核心方向：把清晰的 2D 角色放進有光影、透視與景深的 3D 世界。

目前是一個可以從頭玩完序章〈熄滅的月燈〉的 HD-2D JRPG vertical slice：

- CC0 四方向像素角色、行走動畫與相機相對移動
- 可平滑旋轉、縮放並追蹤玩家的透視相機
- 約 35×30 世界單位的暮光村與北境遺跡探索區；村莊含八棟房屋、街區、水域，以及碰撞、燈光、薄霧與景深
- CC0 像素場景裝飾／HUD、最近鄰取樣與輕量色調／暗角 shader
- 長老、守門人與村童的狀態式對話、主線任務、遺跡線索與完成獎勵
- 主線角色以金黃色「！」、可選內容以青藍色「！」標示，並依進度自動顯示或消失
- 右側即時小地圖會顯示區域地形、玩家朝向、出口及目前任務目標
- 會隨劇情從微弱轉為明亮的中央月燈，以及可恢復 HP／MP 的遺跡月泉
- 電影式側視回合戰鬥：角色前衝、攻擊／月影斬、受擊與傷害數字演出，以及藥水、防禦、勝敗流程
- JSON 存檔／讀檔，保存地圖、位置、任務、旗標、道具、HP 與 MP

## 遊玩流程

1. 調查暮光村中央逐漸熄滅的月燈，並向村童露米、守門人諾亞了解村莊近況。
2. 與廣場左側的艾爾長老交談，接受尋找「月光碎片」的任務。
3. 取得月印、開啟北方月紋雙扇門後，直接穿過門框前往北境遺跡；途中可閱讀風化石碑並在月泉恢復 HP／MP。
4. 接受遺跡守衛的試煉，運用攻擊、月影斬、藥水與防禦贏得戰鬥。
5. 直接穿過南方門扉返回村莊，將月光碎片交給長老並點亮月燈。

序章完成後仍可探索兩張地圖。遺跡石碑上的環形紋章會在結尾留下後續故事線索。

## 操作

- `WASD`／方向鍵：移動
- `Space`／`Enter`：互動、繼續對話
- `Q`／`E`：旋轉鏡頭
- `R`／`F`：縮放鏡頭
- `F5`：儲存遊戲
- `F9`：讀取遊戲
- 戰鬥中按 `1`～`4`：攻擊、月影斬、藥水、防禦

### 手機瀏覽器

GitHub Pages Web 版會在 Android／iOS 瀏覽器自動顯示觸控操作，行動版預設使用橫向畫面：

- 左下搖桿：移動
- 右下「互動」：調查、交談；對話中點一下畫面即可繼續
- `↶`／`↷`：旋轉鏡頭
- 右上「存檔」／「讀檔」：保存或繼續進度
- 戰鬥指令可直接點選

原生 Android／iOS 版會鎖定為感應式橫向，可隨手機左右翻轉；PWA 匯出的方向偏好也預設為橫向。一般手機瀏覽器在直向時，點一下畫面會嘗試進入全螢幕並切換橫向；若瀏覽器不允許強制方向，畫面會繼續顯示旋轉提示。

桌面測試觸控介面時可加上 `--mobile-controls`：

```bash
godot --path . -- --mobile-controls
```

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

快速檢查地圖構圖時可使用 `-- --village-preview` 或 `-- --ruins-preview` 跳過開場對話。

## Web 版與 GitHub Pages

專案保留桌面版的 Forward+ renderer，Web 匯出會自動改用 Compatibility renderer，並使用不需要跨來源隔離標頭的單執行緒版本。

推送到 `main` 後，GitHub Actions 會執行 smoke test、匯出 Web 版並部署至：

<https://ammosu.github.io/godot_2dhd_game/>

首次部署前，請在 GitHub repository 的 **Settings → Pages → Build and deployment → Source** 選擇 **GitHub Actions**。

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
