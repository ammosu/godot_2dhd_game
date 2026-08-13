# HD-2D 開發路線

## Phase 1 — Vertical slice 基礎（已完成）

- 角色在 3D 場景移動、鏡頭追蹤與旋轉
- 像素素材比例、最近鄰取樣、基本後製與燈光基線
- 原創佔位素材與清楚的第三方素材授權表

## Phase 2 — 探索系統（基本版已完成）

- [x] 可互動 NPC、多段對話、任務旗標與輸入鎖定
- [x] 暮光村／北境遺跡、入口／出口、位置與狀態存讀檔
- [x] 四方向 sprite sheet 行走動畫
- [ ] AnimationTree、八方向動作與腳步事件

## Phase 3 — 戰鬥 vertical slice（基本版已完成）

- [x] 獨立戰鬥 UI、玩家／敵人回合、勝利與戰敗
- [x] 攻擊、消耗 MP 的技能、藥水與防禦
- [x] 戰鬥結果與任務、道具、地圖流程串接
- [ ] 弱點、破防、增幅等原創戰術核心
- [ ] 資料驅動的角色、技能、敵人與狀態效果 Resource

## Phase 4 — Production

- Chunk streaming、MultiMesh、LOD、遮擋剔除與畫質階層
- 控制器重綁、鍵盤／滑鼠、觸控與無障礙設定
- 已有 headless 完整 playthrough smoke test；下一步加入單元測試、匯出 preset 與 CI
- 音樂、美術、字型與第三方套件的 SPDX／授權盤點

## 建議架構界線

- `scenes/world/`：地圖區塊與可視物件
- `scenes/actors/`：玩家、NPC、敵人與 presentation
- `systems/`：對話、任務、戰鬥、存檔等純邏輯
- `data/`：自訂 Resource 與遊戲資料，不把規則硬寫在場景節點
- `ui/`：探索與戰鬥 UI；不直接持有世界邏輯
