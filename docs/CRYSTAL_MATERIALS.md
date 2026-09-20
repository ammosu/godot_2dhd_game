# 裝飾晶體的材質可讀性

## 問題與修正

村莊門前實景中，既有晶簇顯得像大片青綠填色。讀取實際匯入材質確認：
切面有原創礦紋 albedo，但 emission_texture 為 null，發光為均勻色。
這不是缺少模型；GLB 已有切面、四株晶體與獨立岩座。

`scripts/gameplay/crystal_materials.gd` 為切面準備一份跨實例共用的材質副本，
將原 albedo 同時用作 emission texture，最近鄰取樣。第一次乘算版本在
獨立評審中被指出太暗、碎裂紋過重；最終採相加發光，青色底光 `3d7773`、
能量 0.55，保留亮暗礦紋，但不讓深色紋路完全失去發光感。

不改原 GLB／PNG、網格、岩座材質、位置、旋轉、尺度、碰撞或任務狀態。
不影響中央月燈及任務碎片的独立材質。所有村莊與遺跡的 `_add_crystal`
實例共用此設定；原始 Blender 建模來源與授權紀錄保留。

## 證據

- 前版：`/tmp/wanderlight-billboard.Wl90tA`。
- 乘算草稿：`/tmp/wanderlight-crystal.KBFiNE`。
- 最終底光版：`/tmp/wanderlight-crystal-final.Wj8nGP`。
- 固定比較：`forward_plus-house_01-225.png` 與
  `gl_compatibility-house_01-225.png`，角色、相機與場景一致。
- `crystal_material_test.gd` 確認貼圖發光、底光設定、共用副本、原材質未改、
  岩座與網格 identity 不變及無新增碰撞，已加入整體清單。

這是局部材質改善，不是全村構圖改版。門前鏡頭與原目標圖的廣場鏡頭不同，
不能把此畫面的整體評分直接與既有 7.8／10 村莊評分比較。

最終獨立評審建議保留，認為此局部材質沒有主要阻礙；仍比目標的白青色
強光核心／光暈克制，未提高全景評分。不同相機下的整體分數僅為
Forward+ 6.5、Compatibility 6.3，不能當作村莊相似度退步或進步。
