# Playthrough smoke test

正式主線已使用 3 對 3 隊伍戰鬥：

```bash
godot --headless --path . --script tests/party_battle_test.gd
godot --headless --path . --script tests/party_battle_ui_test.gd
godot --path . -- --battle-preview
```

模型測試驗證三對三、中央／邊側 AoE、MP 扣一次、無效目標、倒地跳過、防禦、敵方魔法、勝利與藥水／旅人狀態回寫。UI 測試操作實際確認按鈕，核對預覽與爆發時傷害、連按鎖定、三位隊友及敵方回合、敵方 AoE、特效清理。完整 playthrough 已改為隊伍全勝／全滅，不再假設三次單人技能結束戰鬥。舊 `battle_ui.gd` 與其姿勢／音效測試保留為舊版單挑回歸，不是新隊伍流程的驗收依據。

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

成功標記為 `MOON_LAMP_ART_TEST_PASS meshes textures open_cage pivot interaction restored cleanup triangles=2272`。驗證四個貼圖網格、三角形預算、底座接地、開放燈籠結構、旋轉中心、頂點色明暗範圍、互動範圍、修復後發光與換圖清理；不取代實機畫面的視覺檢查。

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

成功標記：`HOUSE_INTERIOR_TEST_PASS eight_entrances furniture collision return_spawns save_load camera minimap`。逐棟由實際互動偵測進入、檢查基本家具與碰撞／出口通道、近牆隱藏但保留碰撞、室內存讀檔位置、小地圖及返回原屋門口；存檔使用獨立測試路徑並於結束刪除。視覺預覽：`godot --path . -- --interior-preview`。

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

成功標記為 `PLAYER_ART_TEST_PASS atlas alpha directions walk idle`。檢查四方向各四幀、320 × 320 對齊畫布、可見輪廓未被裁切、共同腳底基準與實際玩家程式的幀選擇。它不取代行走動畫的實機視覺檢查；戰鬥圖集由獨立測試驗證。

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
