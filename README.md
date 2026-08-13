# Wanderlight HD-2D Prototype

這是一個以 Godot 4.7 建立的原創 HD-2D 技術基線，參考
[SimpleHD2D](https://github.com/GSansigolo/SimpleHD2D) 的核心方向：把清晰的 2D 角色放進有光影、透視與景深的 3D 世界。

目前可直接執行的內容：

- CC0 四方向像素角色、行走動畫與相機相對移動
- 可平滑旋轉、縮放並追蹤玩家的透視相機
- 程序化 3D 測試場景、碰撞、燈光、薄霧、發光物件與微量景深
- CC0 像素場景裝飾／HUD、最近鄰取樣與輕量色調／暗角 shader
- 鍵盤操作：`WASD`／方向鍵移動、`Q`／`E` 旋轉、`R`／`F` 縮放

## 執行

用 Godot 4.7.x 開啟此資料夾後執行主場景，或在終端執行：

```bash
godot --path .
```

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

更完整的製作方向與里程碑見 [docs/ROADMAP.md](docs/ROADMAP.md)。
