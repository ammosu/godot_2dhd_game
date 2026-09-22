# Playthrough smoke test

故事操作回歸需涵蓋讀過與未讀石碑兩種路徑；兩者都是同一結局的資訊差異，不新增任務分支：

```bash
godot --headless --path . --rendering-method forward_plus -- --playthrough-test
godot --headless --path . --rendering-method gl_compatibility -- --playthrough-test
godot --headless --path . --rendering-method forward_plus -- --playthrough-test --skip-tablet
godot --headless --path . --rendering-method gl_compatibility -- --playthrough-test --skip-tablet
```

測試從封閉北門、長老實際接任務對話開始，驗證對話不能被另一互動覆蓋、滿血／受傷月泉教學、戰敗回村與重新進入試煉、戰前存讀檔、守衛對話分流、戰鬥勝利、交付碎片及結尾回收。每次使用含 process ID 的獨立 `user://wanderlight_playthrough_test_*.json` 並於成功後刪除，不覆寫一般存檔。成功標記仍是 `PLAYTHROUGH_TEST_PASS dialogue quest maps save battle`；亦須檢查沒有 `ERROR:` 或 `SCRIPT ERROR:`。這是場景與流程測試，不代表已人工驗收所有鍵盤、觸控或畫面尺寸。

## 可重組戰鬥場景

配置回歸：`godot --headless --path . --script tests/battle_arena_layout_test.gd`。
成功標記 `BATTLE_ARENA_LAYOUT_TEST_PASS reproducible variation themes clearance spacing rng lifecycle`；涵蓋五主題各 128 種種子、平面保留區／間距、重現／變化、裝飾池、全域 RNG 隔離、連續構圖去重、非法覆寫與戰鬥／新遊戲／讀檔清理，不寫任何存檔。

互動預覽：`godot --path . scenes/battle_arena_gallery.tscn`，可換主題／種子、重現配置與隨機換景。加 `-- --capture-dir=/tmp/wanderlight-arena-forward` 可擷取五主題各兩種子；分別使用 `--rendering-method forward_plus` 與 `gl_compatibility` 並選不同輸出目錄。擷取需要實際顯示，不能加 `--headless`；成功標記 `BATTLE_ARENA_GALLERY_CAPTURE_PASS five_themes two_seeds six_actors` 不代表美術驗收。

架構、API、範圍與限制見 [BATTLE_ARENAS.md](../docs/BATTLE_ARENAS.md)。此批回歸不併入下方歷史資產清單計數。

## 故事物件專項

在專案根目錄執行 `godot --headless --path . --script tests/spring_memory_test.gd`，
驗證月泉插圖在受傷／滿血時均顯示、HP／MP 恢復，以及翻頁和換圖清理。
成功標記為 `SPRING_MEMORY_TEST_PASS injured full_health page_cleanup map_cleanup`。
實機移除 `--headless` 並加 `-- --memory-capture`，輸出 `/tmp/wanderlight-memory-<renderer>.png`。
古道光紋、月印與碎片專項命令和限制見 `docs/STORY_OBJECTS.md`；新增三項已納入下方整體清單。

## 裝備系統

分層角色測試：`godot --headless --path . --script tests/layered_equipment_test.gd -- --layered-equipment`。
檢查三角色共 48 組的共用身體／手掌、獨立衣物／武器、遮擋順序、空欄、跨角色肖像快取、試穿取消、隊伍戰鬥與舊姿勢回退，不改存檔。
互動圖層檢視：`godot --path . scenes/layered_equipment_lab.tscn`；1／2／3 切角色，E 拆層、B 底圖、W 武器、H 手掌、空白底色。
加 `-- --layers-capture` 可截圖至 `/tmp/wanderlight-layers-<renderer>.png`，分別以 Forward+ 與 Compatibility 驗證。
加 `--layers-actor=noah` 或 `--layers-actor=elder` 可指定角色；截圖檔名會加入角色名稱。整合測試加 `--layers-ui-capture` 會輸出三角色 × 四姿勢裝備預覽與四張全隊戰鬥截圖。
遊戲測試：`godot --path . -- --equipment-preview --layered-equipment`，選擇三角色的待機／攻擊／受傷／防禦姿勢。
目前只有這四個姿勢使用分層；行走、蓄力、收招、倒地仍回退完整圖集，未宣稱全量遷移。
舊 Blender 小樣已停止使用並移至忽略的 `build/abandoned_blender/`，可復原。

最後兩張援軍混搭圖可用 `python3 tests/compose_party_equipment.py` 重建（需要 Pillow）。此步驟以既有素材及固定遮罩合成，不呼叫生圖服務、不覆寫來源圖集。

隊伍整合：`godot --headless --path . --script tests/party_equipment_test.gd`。驗證三人十二搭配、84 戰鬥姿勢選擇、NPC 外觀、角色相容性、原子穿戴、獨立試穿草稿、存讀檔、戰鬥數值与鎖定。視覺截圖使用 `godot --path . --rendering-method forward_plus --script tests/party_equipment_test.gd -- --equipment-capture`，以及 `gl_compatibility`；輸出 `/tmp/wanderlight-party-equipment-*.png`。

完整替換素材：`godot --headless --path . --script tests/equipment_replacement_test.gd`。驗證四種搭配、128 個行走畫格、28 個戰鬥姿勢、原裝還原、透明背景、裁切邊界、比例與接地資訊；亦檢查行走畫格不會被紋理快取合併。

執行 `godot --headless --path . --script tests/equipment_system_test.gd`。成功標記為 `EQUIPMENT_SYSTEM_TEST_PASS catalog slots stats validation save migration`，驗證分類、能力重算、非法物品拒絕、version 3 存讀檔與 version 1／2 遷移。

可視化整合：`godot --headless --path . --script tests/equipment_visual_test.gd`，驗證試穿不污染狀態、取消／重新開啟、確認、存讀檔外觀恢復、探索 16 畫格、戰鬥 7 姿勢、實際攻擊蓄力到收招的圖層與傷害，以及戰鬥換裝鎖定。成功標記：`EQUIPMENT_VISUAL_TEST_PASS preview cancel confirm world_16_frames battle_7_poses locks`。

雙渲染器視覺驗收使用 `godot --path . --rendering-method forward_plus --script tests/equipment_visual_test.gd -- --equipment-capture`，再改為 `gl_compatibility`。會輸出 `/tmp/wanderlight-equipment-*.png`，含原裝、試穿、探索、戰鬥及七姿勢／16 行走畫格總覽。測試存檔使用獨立 user:// 路徑，不碰正式存檔。

## 序章資產整體回歸

最新清單為 **59 項（51 CPU／8 GPU）**，新增古道光紋、月印展示及月泉記憶三項。既有 `mini_map_rotation_test.gd`（旋轉、相機同步與擴建地面）與晶體材質測試，
驗證裝飾晶體的礦紋發光、跨實例材質共用、原匯入材質／岩座／幾何未改動。
下方 54 項數字保留為先前批次歷程。單項命令：
`godot --headless --path . --script tests/crystal_material_test.gd`。
此測試不等同材質美術驗收；來源與視覺比對見 `docs/CRYSTAL_MATERIALS.md`。

村莊比例改版：八屋進出測試另覆蓋放大房屋後的舊存檔落點修正，以及所有返村點不進入相鄰住宅；屋頂測試的碰撞尺寸取自 HouseCatalog，物理節點不使用非等比縮放。花草測試另驗證廣場與兩條東西道路保持相交。參見 `docs/VILLAGE_LAYOUT.md`，整體清單仍為 54 項。

戰鬥特效四階段檢視：`godot --path . --rendering-method forward_plus --script tests/party_effect_capture.gd -- --capture-dir=/absolute/existing/directory`，再以 `gl_compatibility` 重跑。實際執行六個敵我位置的霜星爆、單體治療與月光彈，依同一個特效實例的自然播放時間各拍四階段；每種 renderer 輸出 32 張完整畫面及 8 張由上到下排列的舞台對照圖。測試只設定施法者／目標並提高 HP 保留六名角色，不強制姿勢、特效時間或結算。完成後等待敵方回合及特效清理，不寫存檔。對照图裁出舞台方便檢視，HUD 必須看完整畫面；成功標記只代表捕捉／清理完成，仍需人工檢視，也不是連續動畫錄影。此診斷不納入 54 項清單。

新版石柱：`pillar_art_test.gd` 已加入清單，檢查原創 GLB 的材質、284 三角形網格、脚底／破損冠部、半徑 0.49 m 內的輪廓、村莊 4 柱／遺跡 8 柱、既有碰撞與清理。與原 `foreground_cutaway_test.gd` 搭配驗證，整體清單現為 54 項（46 CPU、8 GPU）。

探索主角姿勢對照：以兩種真實 renderer 執行 `tests/player_motion_capture.gd -- --capture-dir=/absolute/existing/directory`，各輸出四方向 × 四幀的實際玩家場景對照圖。這是固定姿勢檢查，不是連續動畫或一般遊玩截圖，不納入 54 項清單。既有 `player_art_test.gd` 現在另檢查八個鏡頭方位的畫面方向，以及 0°／225° 下四方向真實輸入、完整四幀循環、地面高度與停止後朝向；不寫正常存檔。

住宅外牆近看：`tests/house_facade_capture.gd` 使用真實 renderer，要求 `-- --capture-dir=/absolute/existing/directory`，輸出花園／陶匠／旅人住宅各正背兩面。此為刻意隱藏周圍物件並停用遮擋剖開的隔離美術檢查，不是一般遊玩畫面，也不納入 54 項回歸。結構／根部高度由 `house_exterior_test.gd` 檢查，正常遮擋行為另跑 `foreground_cutaway_test.gd`。

村莊植被：`garden_art_test.gd` 另檢查五種邊界植物（三種灌木、穗草、白花）的 alpha 腳底，依 atlas region／margin 換算 canvas 基線，檢查花床完整寬度與道路／碰撞淨空、批次低草的材質與數量。另以 `godot --path . --rendering-method forward_plus --script tests/garden_art_test.gd` 及 `gl_compatibility` 執行，可驗證真實 MultiMesh transforms；headless 不讀取 dummy renderer 的 instance transforms。這兩個額外 GPU 檢查不納入既有 54 項清單。

六角色姿勢對照：建立暫存目錄後執行 `godot --path . --rendering-method gl_compatibility --script tests/party_motion_capture.gd -- --capture-dir=/absolute/existing/directory`，再改用 `forward_plus`。輸出四張實際戰鬥 UI 截圖，六角色分別同時顯示待機／蓄力／攻擊／收招；不使用 headless、不寫正常存檔。`PARTY_MOTION_CAPTURE_PASS` 只表示截图成功，不是自動美術判定，也不代表實際同時攻擊或完整演出時序；時序沿用 traveler／caster motion 回歸。此工具不納入 54 項清單。

石柱回歸另檢查 `ColumnFooting`：柱體遮擋時柱身與石座都保持可見／投影，底部貼齊柱根且半徑不超出原 0.5 m 碰撞，避免看不見的障礙物。沿用 `foreground_cutaway_test.gd`，不新增清單項目。

`foreground_cutaway_test.gd` 除原有房屋 192 視角外，亦逐一檢查遺跡石柱的遮擋、清晰角度恢復、碰撞維持有效，以及進屋後 `column_cutaways` 清空；房屋與家具仍使用原 `foreground_cutaways` 群組。遮擋控制器現在只提供粗略判定，物件始終可見；角色剪影再以逐像素深度判斷，只顯示被遮住的部分。

獨立音訊執行緒擷取：同一個 4187 本地伺服器，以 Playwright MCP 執行 `tests/web_audio_capture_test.js`（約 70 秒）。兩個隔離 Chrome context 比較正常 Sample 與診斷 Stream，26 秒後首次進屋再出屋；回傳每個 AudioContext 的樣本數、取樣率、峰值、連續近零輸出最長時間及發生時間，並保存屋內截圖。使用 AudioWorklet 逐樣本處理，觀察分支輸出零，不修改原音量或一般存檔。近零條件是所有輸入聲道絕對值均低於 0.00001，不能檢出被其他聲音蓋住的單一音軌間隙，也不能取代主觀聽感。不納入本地 54 項清單；出現錯誤、空擷取或樣本不足時不能作通過證據。

混音比較的村莊路線從花園屋門口開始，加入 26 秒循環觀察及首次進出屋。各聲道另回傳 `windows`／`silentWindows`（該 2048 樣本窗全部低於 0.00001 才算靜音）。主執行緒卡住時輪詢也會停止，零靜音窗不能證明沒有音訊 underrun；不得將這個診斷當成無縫播放的自動通過門檻。

循環後端比較：`web_mix_test.js` 現依序跑預設及 Stream 診斷模式的村莊／戰鬥，共四個隔離 context，以 `streamLoops` 區分。只有診斷組透過匯出 HTML 引數加入 `--stream-loop-audio`，讓 Web 的 Music／Ambience 使用 Stream；SFX、桌面及一般 Web 啟動都不變。短路線只比較輸出存在與幅度，不代表循環無縫或高負載穩定；`web_audio_test.js` 仍專測正常 Sample 後端。

`web_audio_test.js` 另回傳 `loopScheduling`：同 PCM／固定播放倍率的循環間，下一次開始時間減前一次預期結束時間；正值代表晚接、負值代表重疊。後端可能重建 AudioBuffer，因此在取樣完成後比對完整 PCM，而非僅比較物件 identity 或長度。`loopSchedulingObserved` 只要求捕捉到可比較的接點，不要求零間隔；整體 `pass` 不代表無縫循環。這是 AudioContext 排程觀察，非聲波錄音或主觀驗收。

`python3 tests/audio_asset_test.py` 現涵蓋六段循環音訊的格式／長度、逐聲道削波與 DC、首尾樣本跳變及 100 ms 邊緣 RMS 檢查。2% 跳變與 2 倍 RMS 比值僅防止明顯回歸，不是無縫聽感門檻，也不驗證播放後端是否漏接循環。此擴充沿用既有 `audio_pcm` 清單項目。

Web 混音診斷：同樣啟動 4187 本地伺服器，以 Playwright MCP 執行 `tests/web_mix_test.js`。獨立 Chrome context 分別跑村莊背景／腳步與戰鬥背景／兩次普通攻擊／三目標霜星爆及敵方回合；不靜音、不更動正常玩家設定。觀察分支匯總送往同一 AudioDestination 的訊號，再分別取左右聲道，原聲音路徑不變，觀察輸出為零音量。回傳各階段 peak、RMS 與接近滿刻度樣本數及結果截圖。2048 樣本窗每 10 ms 讀取，窗口重疊、計時器可能漏樣，RMS 不是 LUFS，也不證明無削波、主觀混音平衡或無縫循環；必須另看圖確認技能與回合確實執行。不納入 54 項本地清單。

室內家具遮擋：`godot --headless --path . --script tests/furniture_cutaway_test.gd`，標記 `FURNITURE_CUTAWAY_TEST_PASS`。逐屋驗證實際遮擋、恢復延遲、陰影模式恢復、碰撞／互動保留，以及返回村莊後清理。已納入統一清單；實景使用 `house_visual_capture.gd --inspect-furniture`（放在 `--` 後）另行檢查。

八屋行走回歸：`godot --headless --path . --script tests/house_circulation_test.gd`。以實際 Player 碰撞體及 `move_and_slide` 逐屋走十個世界座標路點（家具前、中央、床與壁爐之間、返回入口），檢查抵達與接地；不寫存檔。標記 `HOUSE_CIRCULATION_TEST_PASS`，已納入統一清單。它不模擬鍵盤／相機相對輸入，也不涵蓋房內所有位置。

側向近距離截圖：在 `house_visual_capture.gd` 的 `--` 後加 `--inspect-furniture`，角色定位家具前，改拍 135／315 度，與入口 45／225 度檔名分開。這個模式是定位取景，不是行走證據；行走由上述測試另行驗證。

`house_interior_test.gd` 現在同時涵蓋八屋專用家具的房屋 ID、主要物件數量、無新增碰撞，以及新增織布／育苗／藏書／月相／布料／旅人／草藥家具的平面邊界；原有八屋进出、桌面碰撞、出口通行、存讀檔及鏡頭測試保留。這些結構檢查不取代實景畫面驗收。

八屋視覺證據：先建立暫存輸出目錄，執行 `godot --path . --rendering-method gl_compatibility --resolution 1280x720 --script tests/house_visual_capture.gd -- --capture-dir=/absolute/existing/directory`；再以 `forward_plus` 重跑。每屋從入口位置拍攝 45／225 度兩個視角，檔名包含渲染器、房屋 ID 與角度。不使用 headless，不寫存檔；`HOUSE_VISUAL_CAPTURE_PASS` 只證明 16 張截圖寫出，必須人工看圖，不納入自動美術判定。

桌面 Chrome 四場景 Web 驗收：重新匯出後以 `python3 -m http.server 4187 --bind 127.0.0.1 --directory build/web` 啟動本地伺服器，再由 Playwright MCP `browser_run_code_unsafe` 的 `filename` 執行 `tests/web_scene_test.js` 絕對路徑。每場景使用獨立瀏覽器 context，在攔截的 HTML 回應加入 preview 參數，不修改匯出檔或一般玩家存檔。結果含四張 `/tmp` 截圖、載入時間、錯誤、WebGL 裝置與 3 秒 requestAnimationFrame 間隔；必須另行看圖，程式 `pass` 不會辨識缺字或美術問題。回呼間隔不是 GPU 渲染耗時，也不是完整遊玩效能驗收。

戰鬥內建字型覆蓋：`godot --headless --path . --script tests/battle_font_test.gd`，成功標記 `BATTLE_FONT_TEST_PASS`；停用系統 fallback，檢查三隊友全部指令的實際 Label／Button 文字。已納入整體清單。

地圖資源快取：`godot --headless --path . --script tests/map_resource_cache_test.gd`，成功標記 `MAP_RESOURCE_CACHE_TEST_PASS`；十張地圖重建三輪，檢查材質／貼圖 identity 穩定、材質集合不增加、舊地圖立即釋放、節點數與任務旗標保持一致。測試不寫入存檔，不代表 GPU 記憶體峰值或切圖效能達標。

Web 實際操作回歸：使用同一個本地伺服器與 Playwright 執行 `tests/web_interaction_test.js`。以鍵盤在花園小屋往返走動、返回村莊再進屋；另以鍵盤／滑鼠完成旅人與諾亞普通攻擊、長老三目標霜星爆及敵方回合。每階段截圖放在 `/tmp`，回傳執行錯誤與操作期間 rAF 間隔（含最大值）。`runtimeClean` 只表示日誌沒有錯誤，必須看圖確認地圖／姿勢／回合／HP／MP 結果，不能視為自動判讀遊戲成功。座標只適用固定 1280 × 720 測試畫面，不是多尺寸驗收。瀏覽器 context 隔離並於結束關閉，不改寫一般玩家存檔。

操作測量依序執行 house-route baseline、室內 baseline、室內 diagnostic、戰鬥 baseline 四個獨立 context。`--house-route-preview` 只跳過開場對話並把角色放到花園小屋門外，保持正常鏡頭與村莊可見；先以 Space 進屋，再走相同往返路線。它不預先建立室內、不讀写存檔，用來區別實際進出屋與直接室內預覽的首次渲染。baseline 不包裝任何 WebGL API；diagnostic 才攔截呼叫並計時，`instrumentGL` 區分結果，截圖名稱也分開。`cadence.byPhase` 提供每段操作的樣本數、P95 與最大間隔。各測量依序執行，仍可能共享瀏覽器／驅動快取；不能直接相減推算工具成本。室內 preview 首次出屋是村莊首次可見渲染，並非一般回村的代表值；需另看 house-route 及 `warm-exit-to-village`。所有測量仍有自動操作與截圖成本，未涵蓋屋內存檔冷啟動。

`map_resource_cache_test.gd` 另以 WeakRef 探針檢查 MultiMesh 的覆寫、表面及疊加材質：切圖後保留、世界釋放後銷毀。這涵蓋一般 MeshInstance3D 以外的批次材質生命週期，不是 GPU 記憶體峰值測量。

室內地板批次的位置驗證需實際 renderer（headless 的 dummy renderer 不保存 MultiMesh transform）：分別執行 `godot --path . --rendering-method forward_plus --script tests/interior_textiles_test.gd` 與 `godot --path . --rendering-method gl_compatibility --script tests/interior_textiles_test.gd`。除既有織物檢查外，驗證 20 片木板的位置、方向、尺寸、木紋比例及原碰撞；headless 仍檢查非 transform 項目。這兩次 GPU 執行已納入統一清單。

```bash
python3 tests/run_asset_checks.py --group all
python3 tests/asset_runner_test.py
```

共 54 項：45 項 Godot headless 結構／行為測試、1 項 Python PCM 測試，以及屋頂／水面／室內背景／室內織物與地板在兩種實際渲染器下的 8 項測試。`--group cpu`（預設）只跑前 46 項；`--group gpu` 只跑需要桌面顯示的 8 項。家具遮擋與八屋十路點行走已納入 CPU 清單，地板位置檢查納入 GPU 清單。測試依序執行，每項預設 90 秒上限，需零退出碼、正確成功標記、無 Godot 錯誤及退出物件洩漏；完整日誌與 `results.json` 保存在印出的系統暫存目錄。

這份清單使用明確的成功標記與渲染需求，避免將屋頂測試誤放到 headless，或誤認 `PARTY_BALANCE_TEST_PASS` 為失敗。它不包含完整主線、Web 匯出／瀏覽器實機、主觀混音、畫面構圖或效能驗收；那些門檻仍須分別完成。

## 環境資產回歸入口

```bash
python3 tests/run_environment_checks.py
python3 tests/environment_runner_test.py
```

依序檢查住宅、主題陳設、外觀、窗框、前景遮擋、室內背景、路燈、腳步、遺跡地面／碎石、月光碎片及水池石沿，共 12 項。每項預設 90 秒上限；必須同時有成功標記、零退出碼且沒有 `ERROR:`／`SCRIPT ERROR:`。個別失敗仍繼續其餘項目，最後回傳非零退出碼；完整輸出保存在系統暫存目錄並印出路徑，不覆寫玩家存檔。可用 `--case ruin_rubble` 選擇項目，或用 `--godot /path/to/godot`、`--timeout 120` 調整執行設定。

這是 headless 結構／行為回歸，不代替雙渲染器實機畫面、主觀聽感、效能與 Web 驗收；下方完整主線測試仍須執行。

水面實際 GPU 動畫回歸（不可加 `--headless`）：

```bash
godot --path . --rendering-method forward_plus --script tests/water_render_test.gd
godot --path . --rendering-method gl_compatibility --script tests/water_render_test.gd
```

成功標記 `WATER_RENDER_TEST_PASS`。以獨立視窗材質取樣確認水色、對比與跨時間像素變化；不會載入主線或改寫存檔。這不是效能或瀏覽器 GPU 驗收。

正式主線已使用 3 對 3 隊伍戰鬥：

月紋門／村界材質回歸：`godot --headless --path . --script tests/gate_art_test.gd`，成功標記 `GATE_ART_TEST_PASS`。涵蓋雙面門扉裝飾、分段村界材質與碰撞一致、封印朝向及任務開門後隱藏，不覆寫存檔。

角色姿勢測試檢查八個 AtlasTexture 的裁切、畫布與透明輪廓腳底基準。節奏測試是固定初始數值的確定性模擬，不代表完整難度評估：目前普通攻擊與全員零 MP 都在第 4 回合勝利（20 次角色行動），使用職業技能的策略在第 3 回合勝利（12 次行動）；仍需後續多場遭遇與玩家試玩。

```bash
godot --headless --path . --script tests/party_battle_test.gd
godot --headless --path . --script tests/party_battle_ui_test.gd
godot --headless --path . --script tests/ally_combat_art_test.gd
godot --headless --path . --script tests/party_battle_balance_test.gd
python3 tests/audio_asset_test.py
godot --headless --path . --script tests/magic_burst_test.gd
godot --headless --path . --script tests/party_ward_test.gd
godot --headless --path . --script tests/physical_hit_art_test.gd
godot --headless --path . --script tests/party_weapon_audio_test.gd
godot --headless --path . --script tests/party_defeated_art_test.gd
godot --headless --path . --script tests/traveler_attack_motion_test.gd
godot --path . -- --battle-preview
```

音訊資產測試檢查九個新角色／武器音效的 PCM 格式、長度、峰值、非靜音及首尾零值；隊伍 UI 測試覆蓋六個技能音效的實際觸發，並確認三人 AoE 只有一次蓄力與一次爆發聲。武器音效測試另跑完六角色普通攻擊回合，核對劍、槍、爪、杖各自次數及八聲道限制。這些不是主觀聽感或混音驗收。

魔法特效測試涵蓋冰霜與獨立治療演出的透明圖集、一次結算訊號、持續時間及釋放；隊伍 UI 測試另外確認治療時使用專用特效，結束後沒有殘留。

月光彈亦驗證獨立彈體／命中圖集、飛行期間不扣 MP、命中只扣一次、抵達後釋放彈體與演出結束清理；桌面截圖選項另輸出 `.dream-loop/party-bolt-flight.png` 和 `party-bolt-impact.png`。

守護光環測試檢查透明中心、不攔截輸入、施術者／受護者倒下時隱藏、結算與新戰鬥不殘留；實際隊伍 UI 測試另驗證正常施放與下次諾亞行動時的到期。

武器命中特效測試檢查六個角色與月影斬的素材對應、四個透明裁切；隊伍 UI 測試確認諾亞實際播放長槍特效、中心對齊目標且回合後釋放，截圖選項輸出 `.dream-loop/party-spear-impact.png`。

倒地素材測試覆蓋六名角色的透明裁切、身體接地線、陰影恢復與旅人倒下後隊友取勝的 1 HP 起身畫面；隊伍 UI 測試驗證三名敵人戰敗後皆使用倒地圖。桌面加 `-- --party-art-capture` 可輸出素材列展示與實際勝利畫面。

主角攻擊動畫測試依序等待蓄力、出劍、收招及待機，驗證普通攻擊／月影斬各一次傷害與 MP、蓄力不提早結算、連按鎖定、陰影回位與下一角色回合。桌面截圖選項另在正式測試前靜態展示各姿勢，輸出 `.dream-loop/traveler-attack-windup.png` 等預覽；不以截圖取代實際時序測試。

模型測試驗證三對三、角色限定技能、中央／邊側 AoE、MP 扣一次、無效目標、倒地跳過、防禦、守護減傷／不疊加／到期／施術者倒下、治療上限與不可復活、敵方魔法、勝利與藥水／旅人狀態回寫。UI 測試操作實際確認按鈕，核對友方選取、預覽與爆發時傷害、連按鎖定、三位隊友及敵方回合、敵方 AoE、特效清理。完整 playthrough 已改為隊伍全勝／全滅，不再假設三次單人技能結束戰鬥。舊 `battle_ui.gd` 與其姿勢／音效測試保留為舊版單挑回歸，不是新隊伍流程的驗收依據。

戰場選取標記：目前行動者使用金色托線與「行動」，受影響者使用菱形與「目標／治療／守護／自身」。角色原本的接地陰影不再染成選取色。UI 測試驗證單體／三人 AoE／治療標記與模型一致，演出及勝利時全部隱藏；此改動不增加點擊角色選取功能，仍由下方卡片操作。

魔法特效及獨立範圍判定的底層測試：

```bash
godot --headless --path . --script tests/area_skill_test.gd
godot --headless --path . --script tests/magic_burst_test.gd
```

驗證半徑邊界、排除隊友與倒地目標、非法座標、判定不修改狀態，以及特效透明度、命中訊號僅一次和播放後清理。這些測試不代表多人回合制或連線對戰已完成。

新增敵人素材（苔背狼／月蝕術士）：

```bash
godot --headless --path . --script tests/enemy_roster_art_test.gd
godot --path . scenes/enemy_art_gallery.tscn
```

成功標記 `ENEMY_ROSTER_ART_TEST_PASS two_enemies eight_poses alpha crops baseline`；檢查兩角色共八姿勢、透明背景、裁切邊緣與共同腳底基準。預覽場景只展示素材，不新增遭遇戰；尚非完整逐格動畫。

中央月燈模型、匯入材質與任務狀態：

```bash
godot --headless --path . --script tests/moon_lamp_art_test.gd
```

成功標記為 `MOON_LAMP_ART_TEST_PASS meshes textures open_halo pivot interaction restored cleanup triangles=1144`。驗證四個貼圖網格、三角形預算、底座接地、開放月環結構、旋轉中心、頂點色明暗範圍、互動範圍、修復後發光與換圖清理；不取代實機畫面的視覺檢查。

背景音樂循環、場景切換與淡入淡出：

```bash
godot --headless --path . --script tests/music_test.gd
godot --path . --rendering-method gl_compatibility --script tests/music_test.gd -- --mute-audio
```

成功標記：`MUSIC_TEST_PASS imports loops routing no_restart crossfade outcome cleanup`。涵蓋三首音樂的格式／循環範圍、村莊與室內共用曲、遺跡／戰鬥切換、重複狀態更新不重播、兩播放器交叉淡化、勝敗留白與清理。第二條命令驗證真正播放路徑；不代表主觀聽感驗收。

環境音測試：

桌面 Chrome 音訊端到端驗收使用 `tests/web_audio_test.js`：先匯出 Web，執行 `python3 -m http.server 4187 --bind 127.0.0.1 --directory build/web`，再以 Playwright MCP `browser_run_code_unsafe` 的 `filename` 傳入該 JS 絕對路徑。需已安裝 Google Chrome；測試會建立並關閉獨立 headless 瀏覽器，回傳 JSON 的 `pass` 必須為 `true`。約需 35 秒，檢查首次手勢前暫停／零輸出、點擊後有波形、M 靜音及恢復、Space 產生新的對話音效，以及 24 秒音樂和 11.5 秒環境音的實際再次播放。用 CDP `userGesture: false` 讀取探針，避免測試腳本本身解鎖音訊；不修改一般玩家偏好或存檔。這是 Chrome Web Audio 輸出驗證，不是主觀聽感或所有瀏覽器驗收。參考 [Chromium 自動播放政策](https://www.chromium.org/audio-video/autoplay/)。

```bash
godot --headless --path . --script tests/ambience_test.gd
godot --path . --rendering-method gl_compatibility --script tests/ambience_test.gd -- --mute-audio
```

成功標記：`AMBIENCE_TEST_PASS imports loops maps battle rapid_switch cleanup`。檢查三段循環、地圖切換、戰鬥靜音、快速切換與清理；第二條驗證實際播放器啟動，不代表聽感驗收。

壁爐素材測試：`godot --headless --path . --script tests/hearth_art_test.gd`。成功標記：`HEARTH_ART_TEST_PASS frames alpha baseline animation logs light collision`，檢查四幀透明火焰、固定底部、動畫推進、爐框內高度、三根木柴、小幅火光與不新增碰撞。實機檢查仍需使用 `-- --interior-preview` 並旋轉鏡頭。

室內織物素材測試：

```bash
godot --headless --path . --script tests/interior_textiles_test.gd
```

成功標記：`INTERIOR_TEXTILES_TEST_PASS linen drape normals cushion fringe`。檢查布料貼圖、nearest 取樣、被子下垂幅度／法線、弧面枕頭及 28 條批次地毯流蘇；不新增碰撞或改動遊戲狀態。

住宅參觀整合測試：

```bash
godot --headless --path . --script tests/house_interior_test.gd
```

成功標記：`HOUSE_INTERIOR_TEST_PASS eight_entrances furniture collision return_spawns save_load camera minimap`。逐棟由實際互動偵測進入、檢查基本家具與碰撞／出口通道、近牆隱藏但保留碰撞、室內存讀檔位置、前後景人物投影大小一致、住戶直立及跨圖片腳底快取隔離、出屋恢復透視、小地圖及返回原屋門口；存檔使用獨立測試路徑並於結束刪除。視覺預覽：`godot --path . -- --interior-preview`。

音量偏好與快捷鍵測試：

```bash
godot --headless --path . --script tests/audio_preferences_test.gd
```

成功標記：`AUDIO_PREFERENCES_TEST_PASS persistence mute clamp validation input isolated_save`。使用唯一暫存設定檔測試讀寫、靜音、零音量、範圍限制、無效值及快捷鍵；刪除暫存檔，不覆寫玩家偏好或劇情存檔。`--mute-audio` 是執行期強制靜音，不會寫入偏好。

角色接地回歸測試：

```bash
godot --headless --path . --script tests/grounding_test.gd
```

成功標記：`GROUNDING_TEST_PASS feet_pivots all_walk_frames npc guardian plaza_collision`。檢查透明圖集實際腳底等於 billboard 旋轉支點、主角全部行走幀不額外升降、村民／守衛具有接觸陰影，以及物理模擬後主角腳底高度與可見廣場一致。另以雙 renderer 旋轉視角實機檢查。

音效資源與實際對話／戰鬥觸發測試（不寫入存檔）：

```bash
godot --headless --path . --script tests/audio_test.gd
godot --path . --rendering-method gl_compatibility --script tests/audio_test.gd -- --mute-audio
```

成功標記：`AUDIO_TEST_PASS imports dialogue combat outcomes voice_limit`。驗證八段音效格式／時長、對話每頁一次、普通攻擊／技能／防禦／治療播放請求、勝敗提示及八個固定播放聲道。Headless 僅驗證事件，不向 dummy mixer 排入播放；第二條命令使用真正桌面播放路徑並靜音。此測試不代表實際聽感或瀏覽器音訊解鎖驗收；試聽時移除 `--mute-audio`。

屋頂瓦片測試（需要實際 renderer；headless dummy renderer 無法回讀 MultiMesh transforms）：

```bash
godot --path . --rendering-method gl_compatibility --script tests/roof_art_test.gd
```

成功標記：`ROOF_ART_TEST_PASS batching relief texture slopes`。驗證八棟房屋各 192 片瓦、真實厚度、石板材質、nearest sampling、兩側向下搭接方向與屋面位置，並檢查雙面山牆、薄屋面及原有碰撞尺寸；不寫入存檔。外觀仍須搭配實機截圖驗收。

陶罐匯入與開口幾何測試（不寫入存檔）：

```bash
godot --headless --path . --script tests/jar_art_test.gd
```

成功標記：`JAR_ART_TEST_PASS geometry texture hollow_rim grounding clearance`（另附三角形數）。驗證材質與尺寸、向下射線穿過罐口到達內底／命中罐沿、無碰撞裝飾行為、與露米的間距及換圖移除。

村莊豬隻素材測試（不寫入存檔）：

```bash
godot --headless --path . --script tests/pig_art_test.gd
```

成功標記：`PIG_ART_TEST_PASS atlas alpha baseline playback map_lifecycle`。檢查兩姿勢透明裁切／腳底、共同畫布、待機時長、真實播放到兩幀，以及進出遺跡時豬隻正確移除與重建。

木箱匯入與場景整合測試（不寫入存檔）：

```bash
godot --headless --path . --script tests/crate_art_test.gd
```

成功標記：`CRATE_ART_TEST_PASS geometry texture grounding village ruins`（另附三角形數）。檢查兩個匯入 mesh、嵌入木紋、地面原點／尺寸、倒角後面數、最近鄰、無碰撞，以及村莊兩只／遺跡五只木箱的換圖整合。

花圃素材測試（不讀寫玩家存檔）：

```bash
godot --headless --path . --script tests/garden_art_test.gd
```

成功標記：`GARDEN_ART_TEST_PASS atlas alpha baseline variants grounding grass`。檢查三種花叢與三種草叢的透明裁切、共同根部基準，以及實際村莊十二處花叢／305 處草叢的材質設定與接地高度；朝向、實際輪廓與周遭比例仍需雙 renderer 實機及旋轉鏡頭檢查。

同一測試也驗證村莊地表 shader 的四條道路／廣場邊界取自實際 BoxMesh、視覺鋪面高度、路緣陰影關閉及廣場碰撞厚度不變；shader 的實際編譯與視覺過渡另以 Forward+ 和 Compatibility 實機截圖檢查。

新增低矮植被另檢查：固定 seed 的取樣可重現、實際实例數等於取樣數、位置避開地圖衍生的道路／碰撞範圍，並維持固定 Y 軸、最近鄰與根部高度。測試輸出 `UNDERSTORY_INSTANCES` 診斷數量；不將截圖或桌面短測當成行動裝置效能證明。

八屋門前補驗證：`garden_art_test.gd` 以獨立房屋局部座標檢查全部地面植物輪廓不得侵入寬 1.4 m、從門前延伸至返村落點外 0.65 m 的區域；GPU 模式另檢查批次低草。`village_entrance_capture.gd` 保留真實村莊、HUD、景深與前景遮擋，在八個返村落點各拍 45／225 度，不隱藏其他房屋；不等同實際行走或所有角度驗收。

```bash
godot --path . --rendering-method forward_plus --script tests/village_entrance_capture.gd -- --capture-dir=/existing/output/directory
```

輸出目錄須先建立；改用 `gl_compatibility` 可取得另一套 16 張畫面。成功標記為 `VILLAGE_ENTRANCE_CAPTURE_PASS 16 views; manual review required`。此手動看圖工具不納入 54 項自動清單，不讀寫存檔。

`garden_art_test.gd` 的 GPU 模式也逐一檢查四段裝飾圍欄的 MultiMesh 木條、柱帽及扣件，將實際零件 bounds 轉至各房屋局部座標，確認不與門前淨空區域相交。Headless 不讀取 dummy renderer 的批次 transforms，不能替代此檢查。

主角戰鬥素材與防禦回歸測試（不寫入存檔）：

```bash
godot --headless --path . --script tests/player_combat_art_test.gd
```

成功標記：`PLAYER_COMBAT_ART_TEST_PASS atlas alpha baseline attack hurt guard reset damage`。檢查四種戰鬥姿勢的共同來源、裁切、腳底基準，以及攻擊／受擊／防禦／回待機切換；以「攻擊→防禦→攻擊」確認防禦只減傷一次。專用戰鬥圖集不再使用探索站姿的裁切資源。

同時確認回合中確實建立帶貼圖的劍光；守衛測試另確認背景位於角色後方、等比例覆蓋且不攔截輸入。背景構圖、文字對比與特效透明邊緣仍須實機檢查。

守衛素材與戰鬥姿勢測試（不寫入存檔）：

```bash
godot --headless --path . --script tests/guardian_art_test.gd
```

成功標記：`GUARDIAN_ART_TEST_PASS atlas alpha baseline hit counterattack idle`。檢查四個 AtlasTexture 共用來源、透明裁切／腳底對齊，以及真實 BattleUI 的受擊、反擊、回待機與無舊染色狀態。此測試不代表戰鬥平衡或完整演出已完成。

主角素材獨立測試（不寫入存檔）：

```bash
godot --headless --path . --script tests/player_art_test.gd
```

成功標記為 `PLAYER_ART_TEST_PASS atlas alpha directions walk idle`。檢查八方向各四幀、正向 320 × 320／斜向 352 × 352 對齊畫布、可見輪廓未被裁切、共同腳底基準與實際玩家程式的幀選擇。它不取代行走動畫的實機視覺檢查；戰鬥圖集由獨立測試驗證。

戰鬥測試等待可接受指令與勝敗完成狀態，每次等待上限 10 秒；不依賴固定動畫秒數。若動畫卡住或狀態未轉移，會明確回報逾時失敗。

從專案根目錄執行：

```bash
godot --headless --path . -- --playthrough-test
```

測試會在隔離的暫存存檔中驗證：

1. 新遊戲時月燈微弱、小地圖與主線／可選內容標記、村民劇情對話及接受任務。
2. 穿過門框後，暮光村自動切換至北境遺跡並更新小地圖。
3. 閱讀遺跡石碑後保存故事旗標，以及月泉完整恢復 HP／MP。
4. 戰鬥開始、玩家勝利與任務道具發放。
5. 對話結束後回到探索、穿過門框自動返回村莊、交付任務並點亮月燈。
6. 戰敗狀態及回村恢復。
7. JSON 存檔寫入、狀態破壞、讀檔還原、地圖位置與石碑線索恢復。

成功標記：

```text
PLAYTHROUGH_TEST_PASS dialogue quest maps save battle
```

需要在桌面上檢查手機介面是否能正確排版時，可用強制開關啟動：

```bash
godot --path . -- --mobile-controls
```

正式 Web 版會依 `web_android`／`web_ios` feature tag 自動啟用；直向畫面的第一次觸控會嘗試進入全螢幕並鎖定橫向。若瀏覽器不允許強制方向，畫面會繼續提示玩家旋轉手機。

### 室內主題陳設

室內背景色回歸：`godot --path . --rendering-method gl_compatibility --script tests/interior_backdrop_test.gd -- --mute-audio --backdrop-capture`，再以 `forward_plus` 執行一次。測試兩種尺寸的實際深色背景像素、圖層順序、泛光保留及進出房屋切換；headless 只驗結構，不能代替像素檢查。詳見 `docs/INTERIOR_BACKDROP.md`。

室內主題陳設：`godot --headless --path . --script tests/house_dressing_test.gd` 檢查八種配置、圖集裁切、最近鄰取樣、壁掛隨牆隱藏、桌面接觸與無新增碰撞。實機加上 `-- --house-art-capture --mute-audio`（不使用 `--headless`）可輸出花園、陶匠、旅人及書屋畫面；原有八屋進出與存讀檔另由 `house_interior_test.gd` 驗證。

### 探索腳步

執行 `python3 tests/audio_asset_test.py` 檢查原創腳步 PCM；`godot --headless --path . --script tests/footsteps_test.gd` 驗證三種材質、非碰撞道路、地圖切換、交替音色、實際移動、撞牆／停下／對話鎖定／傳送重置及清理。桌面音訊啟動檢查用 `godot --path . --rendering-method gl_compatibility --script tests/footsteps_test.gd -- --mute-audio`，不寫入音量偏好或正常存檔。這不是主觀聽感驗收。

### 戰鬥動作銜接

施法者銜接驗證：`godot --headless --path . --script tests/caster_motion_test.gd`。涵蓋長老的範圍魔法、月光彈、治療及月蝕術士範圍魔法，檢查準備／釋放／收招、扣魔力和傷害／治療各一次、輸入鎖定與回合完成。拿掉 `--headless` 並加上 `-- --party-art-capture` 可另存靜態姿勢預覽。六人普通攻擊的銜接順序均由 `party_weapon_audio_test.gd` 驗證。

遺跡守衛也已納入相同的實際回合動作順序檢查。額外執行 `godot --headless --path . --script tests/guardian_attack_art_test.gd` 可驗證舉劍圖集的裁切間距、身體縮放與腳底位置；拿掉 `--headless` 並加上 `-- --party-art-capture` 可輸出靜態姿勢預覽。

`godot --headless --path . --script tests/party_weapon_audio_test.gd` 現在也會在完整六人回合中驗證諾亞與苔背狼的 `windup → attack → recover` 順序與收招後陰影位置。命中音效仍每次攻擊一次，沒有增加技能或改動傷害規則。圖集與提示詞見 `assets/generated/DUO_ATTACK_MOTION.md`。
# Street lantern geometry

## Story Web previews

Ending motion: `godot --path . --rendering-method gl_compatibility --script tests/ending_motion_capture.gd -- --mute-audio` captures three hand-held seal poses and closed/opening/open eyes. Repeat with `forward_plus`. This needs an actual renderer; `moon_seal_test.gd` covers lifecycle and timing headlessly. Generated asset provenance is in `assets/generated/ENDING_MOTION.md`.

Export Web, then serve `build/web` at `127.0.0.1:4193`. Execute the async
function in `tests/web_story_test.js` with a Playwright page (Chrome installed).
It launches an isolated browser and injects preview arguments into the served
HTML without modifying the export. It captures memory, ending and shard scenes,
checks runtime errors and WebGL context loss, and closes its own browser.
Inspect the returned screenshots separately; `runtimeClean` is not visual approval.

Desktop equivalents: `godot --path . -- --story-preview --story-ending`
(or `--story-shard`; omit the scene flag for memory and tablet).
These explicit fixtures suppress autosaves and do not represent a full playthrough.

Fallen masonry: `godot --headless --path . --script tests/ruin_rubble_test.gd`.
Expected prefix `RUIN_RUBBLE_TEST_PASS grounded normals deterministic one_batch`.

Moon shard reward: `godot --headless --path . --script tests/moon_shard_test.gd`.
Expected `MOON_SHARD_TEST_PASS geometry reward_once dialogue_cleanup map_cleanup`.
Omit headless and append `-- --shard-capture --mute-audio` for a reward screenshot.

Ruin ground material: `godot --headless --path . --script tests/ruin_soil_test.gd`.
Expected `RUIN_SOIL_TEST_PASS material collision courts village_unchanged`.

Foreground house cutaway: `godot --headless --path . --script tests/foreground_cutaway_test.gd`.
Expected `FOREGROUND_CUTAWAY_TEST_PASS hysteresis shadows tiles 192_views map_cleanup`.
Also covers house 07's 45-degree return view: the camera-tilted character face
intersects house 04 even when vertical-body rays miss it. The regression must
detect that neighboring facade; actual dual-renderer captures remain required.

Manual audio listening: `tests/audio_mix_audition.gd` records four 33-second
desktop Master mixes using the existing audio systems and authored cue timings.
Requires a real audio device and existing `--capture-dir`; no headless or mute.
It does not save preferences, normalize recordings or approve subjective sound.
See `docs/AUDIO_LISTENING.md` for commands, timestamps and limits. This manual
fixture is not part of the 54 automated asset checks.
See `docs/FOREGROUND_CUTAWAY.md` for actual-renderer capture instructions and test limits.

House exterior themes: `godot --headless --path . --script tests/house_exterior_test.gd`.
Expected `HOUSE_EXTERIOR_TEST_PASS eight_themes entrance_clear`.
For all six gable emblems, omit `--headless` and append
`-- --emblem-capture --mute-audio`; see `docs/HOUSE_EXTERIORS.md`.
For a pottery-house screenshot, omit `--headless` and append
`-- --exterior-capture --mute-audio`.

Exterior window frames: `godot --headless --path . --script tests/house_window_test.gd`.
Expected `HOUSE_WINDOW_TEST_PASS aligned_crossbars eight_outer_frames`; this checks
geometry only, not shader appearance. See `docs/HOUSE_WINDOWS.md`.

Run `godot --headless --path . --script tests/street_lantern_test.gd`.
Expected: `STREET_LANTERN_TEST_PASS shared_meshes grounded outward_panes unchanged_light`.
Checks mesh sharing, ground contact, outward pane normals and preserved lighting.

八方向斜走：`player_art_test.gd` 另驗證雙鍵輸入、等速斜走、停止保留斜向、八個鏡頭角度。`equipment_replacement_test.gd` 涵蓋四套裝備的 128 個畫格。`player_motion_capture.gd` 現輸出 32 個實際玩家姿勢；用 `--capture-dir=/existing/path` 指定輸出位置，需實際 renderer。素材與提示詞見 `assets/generated/DIAGONAL_WALK.md`。

### 對話轉身

`godot --headless --path . --script tests/conversation_facing_test.gd` 驗證長老、露米、諾亞的八方向交談、兩個鏡頭角度、九組角色／裝備搭配、地圖待機與對話共用角色圖集、雙方互相面向、接地與高度、對話鎖定、立即還原及換圖清理。成功標記為 `CONVERSATION_FACING_TEST_PASS`。不寫入正常存檔。

對話開始時會先停止玩家水平慣性；與 NPC 的水平距離不足 1.35 時，優先向後退開，遇到障礙則搜尋側邊可通行位置。路徑皆受阻時保留原位，避免穿牆。`conversation_facing_test.gd` 另驗證近距離、完全同點、足夠距離不移動及牆邊退讓。

實機以 `godot --path . --rendering-method forward_plus --script tests/conversation_facing_test.gd -- --facing-capture --mute-audio` 輸出三張待機 `/tmp/map-idle-*.png` 與六張對話 `/tmp/conversation-*.png`；另以 `gl_compatibility` 重跑。來源及提示詞見 `assets/generated/CONVERSATION_FACING.md`。轉身使用八個站姿切換，並非逐幀旋轉動畫。

月紋門通行：`gate_art_test.gd` 另驗證雙側石牆、木門接合細節、門後觸發區，以及往返後角色位於門檻後方且不會立即跳回原地圖。
實際畫面驗收：移除 `--headless` 並加 `-- --gate-capture`，以 `forward_plus` 和 `gl_compatibility` 各輸出關門、開門與抵達門後三張 `/tmp/wanderlight-gate-<renderer>-<view>.png`；門框／門扉僅在擋住角色時局部隱藏，碰撞仍保留。

`gate_art_test.gd` 另驗證移至村界後的關隘往返與東側獨立道路：角色能穿出東側缺口，並被可見的路尾木柵阻擋；`--gate-capture` 增加 `east_road` 畫面。

### 戰鬥站位與角色資訊

```bash
godot --headless --path . --script tests/party_formation_test.gd
godot --path . --rendering-method gl_compatibility --script tests/party_formation_test.gd -- --formation-capture
```

驗證前排阻擋、長槍／月影斬射程、遠程法術、換排次數與交換位置、倒地後屏障解除、敵方射程與角色 HP／MP 資訊卡不重疊、不超出舞台。視覺模式將實際換排畫面輸出至 `/tmp/party-formation.png`。

### 全隊規劃、速度順序與拖曳

```bash
godot --headless --path . --script tests/party_round_test.gd
godot --headless --path . --script tests/party_drag_test.gd
godot --path . --rendering-method gl_compatibility --script tests/party_battle_ui_test.gd -- --party-art-capture
```

涵蓋安排／修改不扣資源、開始回合鎖定、雙方依速度交錯行動、同速排序、倒地跳過／失效目標處理、藥水預訂與全隊每回合一次換排。拖曳測試透過原生滑鼠按下、移動與放開驗證完整交換。速度條是固定速度數值比例，並非即時蓄力條。GPU 截圖輸出 `/tmp/party-round-planning.png`。舊版逐人即時出手的 UI 測試已改為全隊規劃流程；獨立姿勢／裝備測試直接執行單次動作，完整回合由 UI 與音效測試驗證。

### 自動戰鬥

`godot --headless --path . --script tests/party_auto_battle_test.gd` 驗證自動規劃、治療／守護、範圍目標、零 MP 普攻、立即取消、回合中停止、恢復、勝利停止與新遭遇重置，並確認不使用藥水。實際渲染加 `-- --auto-capture` 可輸出 `/tmp/party-auto-battle.png`。


角色遮擋提示：`foreground_cutaway.gd` 保留原有包圍盒粗略判定與恢復延遲，但不再隱藏場景物件或更改陰影。每位玩家共用一個 `occluded_character.gd`，同步動畫、裝備貼圖及腳底位移；shader 只在角色像素比場景深度更遠時顯示 28% 淡藍色剪影。透明且不寫入深度的物件不會觸發像素遮擋提示。

新增實際 GPU 回歸（不能加 `--headless`），分別執行：

```bash
godot --path . --rendering-method forward_plus --script tests/occluded_character_render_test.gd
godot --path . --rendering-method gl_compatibility --script tests/occluded_character_render_test.gd
```

成功標記：`OCCLUDED_CHARACTER_RENDER_TEST_PASS behind front partial`。比較提示開關前後的畫面，確認後方可見剪影、前方即使粗判誤報也完全不變、局部遮擋只影響部分角色像素。可加 `-- --capture-dir=/absolute/existing/directory` 儲存圖片；此 GPU 測試單獨執行，未加入原有批次清單。原 `foreground_cutaway_test.gd`／`furniture_cutaway_test.gd` 改為驗證物件保持可見及陰影、碰撞、互動不變。


柱前上半身遮擋修正：玩家圖面使用 `BILLBOARD_FIXED_Y`，保持直立並只繞 Y 軸朝向鏡頭，透視剪影使用相同基底。避免完全 billboard 隨俯視角後傾，讓角色頭部穿入腳後方的石柱／牆面。`occluded_character_render_test.gd` 另載入實際柱模型，驗證八個鏡頭方向、0.8／1.1 公尺兩種柱前距離：與無柱參考圖比較，角色像素應完全不被覆蓋或染色。成功標記追加 `pillar_front_16_views`；`foreground_cutaway_test.gd` 同時確認陶匠住宅返回點不再因頭部後傾誤報鄰屋遮擋。

房門在水平距離 0.65 內且面向門時自動觸發，不必按鍵（朝向門的進出方向，左右各 45° 內），背對或側對時不顯示該門提示，也不觸發開門；村莊、星灣城住宅入口及室內出口皆適用。抵達／讀檔後需離開門口的 0.85 範圍才重新允許自動觸發，避免來回傳送；稍遠處仍保留按鍵互動。回歸涵蓋村莊與星灣城的無按鍵進出、方向阻擋、距離限制及抵達保護。判定使用門的固定進出方向，貼門、與互動點重疊或稍微穿過互動點時仍可操作；回歸亦涵蓋這三種近距離位置及背對阻擋。

房門開啟流程回歸：`godot --headless --path . --rendering-method gl_compatibility --script tests/house_door_test.gd`（亦以 `forward_plus` 執行）。成功標記 `HOUSE_DOOR_TEST_PASS`；涵蓋八棟住宅室內外的背對／側對阻擋、正面提示與實際互動輸入，以及玩家退讓、門軸動畫、走向入口、延後入屋、連按保護、住戶對話、室內門逐步開啟、延後出屋、退讓與開門時朝向房門、進出屋後朝向行進方向與操作解鎖。

場景物件碰撞：`godot --headless --path . --script tests/prop_collision_test.gd`。成功標記 `PROP_COLLISION_TEST_PASS`；以玩家膠囊從四側測試村莊及遺跡的木箱、陶罐、水晶、圍欄、路燈與樹幹，逐個排除鄰近物件干擾；另確認樹冠下可從樹幹旁通行。另執行 `house_door_test.gd` 確認八棟住宅入口仍可通行。

房屋外側花台碰撞：`godot --headless --path . --script tests/house_facade_collision_test.gd`。成功標記 `HOUSE_FACADE_COLLISION_TEST_PASS`；以玩家膠囊驗證八棟住宅共 64 處花台／展示架，碰撞先於牆面，且物理形狀不繼承不等比縮放。搭配 `house_door_test.gd` 檢查入口退讓與進屋。

### 村莊散步村民

`godot --headless --path . --script tests/wandering_villager_test.gd` 驗證三位村民移動、對話暫停、玩家接近停步、路線折返與地圖切換清理。預期 `WANDERING_VILLAGER_TEST_PASS movement pause proximity patrol maps fixed_roster dialogue repeat`。另驗證固定順序芙蘿／米菈／歐文、玩家互動偵測、姓名與獨立短對話、重複交談、交談時全員停步、連按不切換說話者，以及換圖後保留名單與文本；不改動任務旗標或背包。

## 主要 NPC 碰撞

`godot --headless --path . --script tests/npc_collision_test.gd` 驗證長老、露米、守門人與遺跡守護者會阻擋玩家，四面接近仍可取得互動目標，持續前進不能穿透、後退不會卡住，切圖返回後碰撞仍有效。成功標記為 `NPC_COLLISION_TEST_PASS blocking interaction retreat map_reload`。

### Outskirts exploration

```bash
godot --headless --path . --rendering-method forward_plus --script tests/outskirts_test.gd
godot --headless --path . --rendering-method gl_compatibility --script tests/outskirts_test.gd
```

Expect `OUTSKIRTS_TEST_PASS routes events early_pickup rewards save trails main_quest`.
Checks village ↔ road ↔ forest transitions, map labels, map-local events, early parcel pickup, one-time rewards, rest recovery, save/load, unobstructed marked forest trails, and unchanged main quest. Uses only `user://outskirts_test.json`, removed after success. Add `-- --capture` in a graphical run to capture both maps to `/tmp/firefly_forest.png` and `/tmp/east_road.png`.


對話遮擋淡出回歸測試（玩家／NPC 視線、透視／正交、共享材質保護、延遲恢復與換圖清理）：

```bash
godot --headless --path . --script tests/dialogue_occlusion_test.gd
```


居民八方向與行走：`godot --headless --path . --script tests/resident_motion_test.gd`。檢查八個身分、256 個姿勢畫格、alpha 腳底、鏡頭八方位、實際住宅交談轉向、踏步／停止／對話鎖定，以及三位不重複的巡遊角色。成功標記 `RESIDENT_MOTION_TEST_PASS`。既有 `wandering_villager_test.gd` 繼續驗證實際路線移動、禮讓、停留與地圖重建；`house_interior_test.gd` 驗證八棟住宅互動。

居民美術對照：建立輸出目錄後，執行 `godot --path . --rendering-method gl_compatibility --script tests/resident_motion_capture.gd -- --capture-dir=/absolute/existing/directory`，再改為 `forward_plus`。透過 960 × 1600 SubViewport 捕捉實際共用角色腳本的八位 × 八方向 × 四姿勢。這是隔離美術診斷圖，成功標記 `RESIDENT_MOTION_CAPTURE_PASS` 只表示捕捉成功，不代表正常遊玩畫面或連續動畫驗收。兩者不寫玩家存檔。

對外道路自動通行：`godot --headless --path . --script tests/road_exit_test.gd`。以真正玩家碰撞體從四個出口各三條路線行走，不呼叫互動，檢查目的地、每次只切圖一次、抵達不彈回，以及對話鎖定後恢復；成功標記 `ROAD_EXIT_TEST_PASS`。

同種樹形變化：`godot --headless --path . --script tests/tree_variants_test.gd`，成功標記 `TREE_VARIANTS_TEST_PASS`。驗證 15 個素材、透明裁切邊界、鄰近垂柳使用不同樹形、重新建立地圖配置不變及樹根接地。完整遊戲碰撞另跑 `prop_collision_test.gd`。

### Regional map UI

`godot --headless --path . --script tests/map_ui_test.gd`

Expected: `MAP_UI_TEST_PASS five_regions input_lock modal_guards keyboard button north_up targets`.
Checks G/Esc and the map button, five region types, objective synchronization, north-up orientation, movement lock, and opening guards during dialogue/battle/equipment/transitions. Uses test-mode save isolation. Run with an actual renderer to also capture `/tmp/wanderlight-large-map.png` for visual review; append `-- --mobile-controls` to inspect the touch layout.

自然水域：`godot --headless --path . --script tests/natural_water_test.gd`。驗證玩家尺寸膠囊可走池塘淺岸、穿越舊道中央淺灘，且無法穿入溪流／池塘深水。成功標記 `NATURAL_WATER_TEST_PASS`。去掉 `--headless` 並分別指定 `--rendering-method forward_plus` 與 `gl_compatibility`，亦檢查水面動畫並輸出 `/tmp/natural-water.png`。

木橋通行：`godot --headless --path . --script tests/creek_bridge_test.gd`。使用實際玩家碰撞體驗證雙向上下橋、橋面高度、側欄阻擋與木質腳步聲；成功標記 `CREEK_BRIDGE_TEST_PASS`。以圖形模式執行可擷取 `/tmp/creek-bridge.png`。


## 動作戰鬥

主場景使用 `action_battle_ui.gd`，由 GameState 持有 `action_battle.gd`，每個物理更新執行空間戰鬥。`world_action_battle.gd` 將模型的移動／尋路／視線查詢接到原地 3D 場景與實際碰撞體，HUD 不使用 SubViewport。存檔結構不變，不保存戰鬥中途狀態。

```bash
godot --headless --path . --script tests/action_battle_test.gd
godot --headless --path . --script tests/action_battle_ui_test.gd
godot --headless --path . --rendering-method forward_plus -- --playthrough-test
godot --headless --path . --rendering-method gl_compatibility -- --playthrough-test
```

模型測試涵蓋移動邊界、攻擊距離與方向、前搖、預警鎖定、走位避招、閃避、暫停、冷卻、資源、換人及勝負後停止。UI／場景測試涵蓋保留地圖與鏡頭、原地開戰、石柱碰撞與閃避掃掠、隔牆攻擊阻擋、敵人繞路、暫停與換人鏡頭、多指觸控、勝利後自動離場、位置保留及場景清理；非 headless 執行時另存 `/tmp/wanderlight-world-battle.png` 供畫面檢查。完整主線測試以固定步進操作真實模型，驗證戰敗恢復、重試與勝利交任務。

既有 `party_*` 回合測試保留為舊系統回歸測試，不代表主場景目前的操作。戰場圖庫仍使用原本靜態展示介面。

直接試玩：`godot --path . -- --battle-preview`，開啟戰鬥準備彈窗，選擇自動／技能／藥水設定後按「開始戰鬥」，不寫入正常自動存檔。


自動動作戰鬥：`godot --headless --path . --script tests/action_auto_battle_test.gd`。
涵蓋預設關閉、自動追擊／技能／閃避、暫停、手動接管、換人、無 MP 戰鬥與勝敗後停止。`action_battle_ui_test.gd` 另驗證 B 鍵、觸控開關、手動接管及完整原地自動戰鬥獲勝，而且不消耗共享藥水。

### Action combat artwork

`godot --headless --path . --script tests/action_art_test.gd` checks alpha, measured atlas bounds, cardinal selection, windup/contact/recovery/death priority, single damage resolution, and effect pause/cleanup.

`godot --path . --rendering-method gl_compatibility --script tests/action_art_world_test.gd` renders a deterministic original-map fixture with casting, moon slash, frost, heal and ward effects; saves `/tmp/wanderlight-action-art-world.png`. Repeat with `forward_plus` for desktop visual QA. These fixtures use new-game test state and never save over player data.

After changing action PNGs, run `python3 tools/art/inspect_action_atlases.py` (Pillow) to regenerate measured `regions.json` and `regions.gd`, inspect the images, then run the art test and Web export. The measurement script reads alpha only and does not alter source raster pixels.

戰前準備回歸：`tests/action_battle_ui_test.gd` 驗證確認前凍結與快捷鍵防繞過；`tests/action_auto_battle_test.gd` 驗證技能關閉、手動技能、藥水門檻、庫存扣除、冷卻、暫停、手動接管與結束後不扣藥。

## 星灣城與商道

```bash
godot --headless --path . --rendering-method forward_plus --script tests/starbay_test.gd
godot --headless --path . --rendering-method gl_compatibility --script tests/starbay_test.gd
```

成功標記：`STARBAY_TEST_PASS walking_roundtrip streets floor rest save minimap`。檢查暮光村→東行舊道→風丘商道→星灣城的實際出口感應與回程、抵達後不反覆傳送、所有主街的角色膠囊通行與地板射線、茶棚恢復、城內存讀檔、地圖標題與主線隔離。測試只使用並清除 `user://starbay_test_<process-id>.json`。

移除 `--headless` 並附加 `-- --capture` 可擷取 `/tmp/starbay_market.png`、`/tmp/starbay_belfry.png`、`/tmp/starbay_map.png`、`/tmp/starbay_road.png`；需可用的圖形顯示。

## 星灣城房屋

新增角色驗證：`godot --headless --path . --script tests/city_resident_art_test.gd`。檢查 26 間住家涵蓋全部 16 種新造型、透明圖集載入、人物高度、最近鄰採樣與交談。成功標記：`CITY_RESIDENT_ART_TEST_PASS 16 designs 26 homes dialogue scale`。移除 `--headless` 並附加 `-- --capture` 可將茶師室內畫面存至 `/tmp/city-npc-<rendering_method>.png`，不寫入一般存檔。

`godot --headless --path . --script tests/city_house_test.gd` 實際逐一操作 26 個門口，檢查開門進屋、六種格局、中央通道膠囊碰撞、地板、屋主／陳設互動、各房型存讀檔，以及出屋返回正確的星灣城門前。使用獨立 `user://city_house_test_<process-id>.json`，成功後清除。

成功標記：`CITY_HOUSE_TEST_PASS 26_doors six_layouts collisions dialogue save return`。移除 `--headless`、加入 `--rendering-method gl_compatibility` 或 `forward_plus`，附加 `-- --capture` 可擷取六房型的 `/tmp/city-house-<kind>.png`。村莊原有八棟住宅另以 `tests/house_door_test.gd` 回歸。

## 町屋風格外觀

`godot --path . --rendering-method forward_plus --script tests/japanese_house_capture.gd` 擷取南門旅舍、溪風茶室及守鐘人之家的正側面；改為 `gl_compatibility` 可檢查 Web 相容渲染。輸出 `/tmp/japanese-house-<index>-<renderer>.png`，成功標記 `JAPANESE_HOUSE_CAPTURE_PASS`。此工具只作畫面檢查、不寫存檔；進出功能使用 `tests/city_house_test.gd` 的 26 棟門口回歸，街道通行使用 `tests/starbay_test.gd`。

星灣城測試另涵蓋三座公共地標、五條新增步道、月儀／老樹環形步道的角色膠囊掃掠與地板，以及三處介紹互動。`--capture` 額外輸出 `/tmp/starbay_moon.png`、`/tmp/starbay_tree.png`、`/tmp/starbay_pavilion.png`；地圖截圖會包含新地標。

小地圖自動尋路：`godot --headless --path . --script tests/map_navigation_test.gd`。驗證小地圖不接受點選、放大地圖圖示命中、村莊與遺跡實際行走抵達、障礙繞行、手動／模式／換圖取消、不可達目的地、大地圖點選，以及星灣城與室內路線。成功標記 `MAP_NAVIGATION_TEST_PASS`。

## 城內店舖

`godot --headless --path . --script tests/city_shop_test.gd` 驗證四店門口可達、實際開門／返程、專屬店名、室內通道、NPC 對話、陳設調查、旅店恢復及獨立測試存讀檔。成功標記：`CITY_SHOP_TEST_PASS four_shops doors collisions dialogue rest save return`。

視覺檢查：`godot --path . --rendering-method forward_plus --script tests/city_shop_test.gd -- --capture`，以及相同指令改用 `gl_compatibility`。輸出 `/tmp/city-shop-house_city_*-<renderer>.png` 與 `/tmp/city-shop-room-house_city_*-<renderer>.png`。不寫玩家正常存檔。

壁爐動態回歸：`godot --path . --rendering-method forward_plus --script tests/hearth_art_test.gd`，另以 `gl_compatibility` 執行。檢查側火舌根部對齊、呼吸縮放後的火焰高度、火星大小與橫樑界線；MultiMesh 位置檢查需要實際 GPU，headless 只執行其他檢查。

`house_door_test.gd` 也驗證進出後回身關門、關門期間鎖定操作、門扇完全閉合與主角姿態復原。

路面變化沿用 `garden_art_test.gd` 驗證村莊道路邊界與植栽；`footsteps_test.gd` 額外檢查東行土路及商道多邊形採用泥地音效。渲染檢查需使用 Forward+ 與 Compatibility 實際查看村莊、東行舊道、螢光森林、風丘商道與星灣城，確認路面分級與草地斑駁。

伸手開關門美術與同步測試（八方向、四種換裝、腳底對齊、手到門才動、動作後復原）：

```sh
godot --headless --path . --script tests/door_action_art_test.gd
# 實際渲染截圖，需先建立輸出目錄
godot --path . --script tests/door_action_art_test.gd -- --capture-dir=/absolute/output/directory
```

野外戰鬥：`godot --headless --path . --script tests/field_combat_test.gd`。驗證玩家膠囊上下坡、怪物追上高台與追下坡、離開追擊範圍後返回、高低差阻擋命中、攻擊起手／打斷／冷卻、閃避與介面暫停、經驗升級、掉落拾取、讀檔不重複獎勵、v3 遷移與倒下回村。獨立使用 `user://field_combat_test.json`，成功標記 `FIELD_COMBAT_TEST_PASS`。

野外戰鬥畫面：`godot --path . --rendering-method forward_plus --script tests/field_render_test.gd`，另以 `gl_compatibility` 執行一次；截圖寫入 `/tmp/field-forward_plus.png`、`/tmp/field-gl_compatibility.png`。成功標記 `FIELD_RENDER_TEST_PASS`。

野外自動戰鬥：`godot --headless --path . --script tests/field_auto_battle_test.gd`，驗證手動接手、技能與喝藥開關、失焦／選單暫停、預警閃避，以及從入口實際沿坡道清除三敵、拾取全部掉落並停止。不寫入玩家存檔。成功標記 `FIELD_AUTO_BATTLE_TEST_PASS`。


山區地圖：`godot --headless --fixed-fps 60 --path . --script tests/mountain_maps_test.gd`，另加 `--rendering-method gl_compatibility` 執行一次。驗證三區路面碰撞、角色實際上下山、自動行走、高處存讀檔、步行出口與抵達後不會反覆換圖。獨立使用並清理 `user://mountain_maps_test.json`；成功標記 `MOUNTAIN_MAPS_TEST_PASS ground uphill downhill save walking_exits`。使用可見視窗加 `-- --capture` 可將三區截圖寫入 `/tmp/moss_steps.png`、`/tmp/wind_gorge.png`、`/tmp/moon_highland.png`。
