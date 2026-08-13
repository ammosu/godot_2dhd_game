# HD-2D 開發路線

## Phase 1 — Vertical slice 基礎（目前）

- 角色在 3D 場景移動、鏡頭追蹤與旋轉
- 像素素材比例、最近鄰取樣、基本後製與燈光基線
- 原創佔位素材與清楚的第三方素材授權表

## Phase 2 — 探索系統

- 可互動 NPC、對話框、任務旗標與場景切換
- 分區地圖資料、入口／出口、存檔與讀檔
- 角色 AnimationTree、八方向 sprite sheet 與腳步事件

## Phase 3 — 戰鬥 vertical slice

- 獨立戰鬥場景、回合順序與指令 UI
- 弱點、破防、增幅等「同類型但原創規則與命名」的戰術核心
- 資料驅動的角色、技能、敵人與狀態效果 Resource

## Phase 4 — Production

- Chunk streaming、MultiMesh、LOD、遮擋剔除與畫質階層
- 控制器重綁、鍵盤／滑鼠、觸控與無障礙設定
- 單元測試、headless 場景 smoke test、匯出 preset 與 CI
- 音樂、美術、字型與第三方套件的 SPDX／授權盤點

## 建議架構界線

- `scenes/world/`：地圖區塊與可視物件
- `scenes/actors/`：玩家、NPC、敵人與 presentation
- `systems/`：對話、任務、戰鬥、存檔等純邏輯
- `data/`：自訂 Resource 與遊戲資料，不把規則硬寫在場景節點
- `ui/`：探索與戰鬥 UI；不直接持有世界邏輯
