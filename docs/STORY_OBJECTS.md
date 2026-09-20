# 故事物件製作狀態

故事 worktree 的物件以 `STORY_BIBLE.md` 為依據。文字提及不代表已有可見演出。

最新動作更新：使用者確認保留目前美術後，結尾月印改由實際艾爾角色以三姿勢取出／抬起／手持，不再使用旅人頭頂放大展示。霧中插圖加上閉眼至睜眼的局部 shader 動畫，翻頁延續、不改背景。以下放大展示／靜態特寫描述為前版製作歷程；現況與完整提示以 `assets/generated/ENDING_MOTION.md` 為準。

- 已有：中央月燈、月泉、月紋門、石碑、戰後月光碎片、八屋主題家具。
- 本輪新增：原創古道光紋，中央帶北向缺口的環與通向北門的分段石路嵌線。由 `scripts/gameplay/awakened_road.gd` 建構單一網格，無碰撞、無外部素材；既有任務完成狀態控制可見性，換圖重新建立，不新增存檔欄位。
- 月印已製作：原創十六邊青銅印牌、焦黑缺口環與殘留月光細線，沿用既有原創銅貼圖。結尾以放大物件展示，對話結束或換圖釋放；不是持握動作。北門封印改為同方向缺口環，對應碎片斷環的 80 度缺口。實作見 `scripts/gameplay/moon_seal.gd`。

月印展示時序：在結尾第三頁「月印烙下環紋」才顯示，艾爾說明與可選石碑回收頁保留；進入霧中甦醒段落後隱藏。`DialogueUI.page_shown` 驅動畫面，物件釋放後連線自動移除。古道環也採 80 度缺口，轉向北門。
- 碎片飛行已接入：戰後從守衛原位置升起，以 1.4 秒弧線飛到旅人上方，再沿用原本浮動展示。快速結束對話及離圖仍直接釋放，不延遲探索解鎖；飛行不修改背包或任務獎勵。
- 石碑已換用缺口環與磨名刻痕貼圖，保留原 GLB、側邊石材與刻文配置。來源及提示見 `assets/generated/STORY_TABLET.md`。
- 月泉記憶已接入原創插圖：月光古道、霧中旅人與截路村牆，在月泉第一頁對話展示，翻頁、結束及離圖清除。受傷與滿血都能看到；HP／MP 恢復照舊。這是靜態記憶插圖，來源及提示見 `assets/generated/SPRING_MEMORY.md`。
- 霧中甦醒已接入原創靜態特寫：古道通入夜霧，只有微弱銀色眼光，不揭露身分或立場。在結尾睜眼旁白及霧中之聲兩頁展示，系統完成頁及離圖清除；不是逐格睜眼動畫。來源與完整提示見 `assets/generated/FOG_AWAKENING.md`。`moon_seal_test.gd` 同時驗證兩種石碑路徑的插圖時序與清理；加 `-- --awakening-capture --mute-audio` 可拍攝實景。
- 整體環境、角色動畫及音訊尚未全部通過資產驗收，見 `ASSET_ACCEPTANCE.md`。本輪不將局部物件接入視為全部資源完成。

驗證：`godot --headless --path . --script tests/awakened_road_test.gd` 檢查任務時序、換圖清理及回村還原。移除 `--headless`，加 `-- --road-capture` 可輸出 `/tmp/wanderlight-road-<renderer>.png` 供實景檢視；測試不寫正常存檔。

月印：`godot --headless --path . --script tests/moon_seal_test.gd` 驗證展示、任務獎勵及對話／換圖清理；實機執行加 `-- --seal-capture` 可拍攝結尾展示。`tests/gate_art_test.gd` 保留門扉開啟、互動與碰撞回歸。

月泉：`godot --headless --path . --script tests/spring_memory_test.gd` 驗證受傷／滿血、翻頁及換圖清理；實機加 `-- --memory-capture` 拍攝對話與插圖。沒有新增記憶旗標或存檔欄位。

Web 實測（2026-09-21）：Chrome 153、1280×720、獨立瀏覽器 context 的月泉／結尾／碎片三場景均完成，無 console／page error，WebGL context 未遺失。人工檢視確認月泉插圖與石碑缺口環、結尾光路及月印第三頁出現／霧中段落隱藏、碎片展示及對話結束清除。截圖前綴 `/tmp/wanderlight-web-story-1789922300103`。此為明確預览入口，並非 Web 完整遊玩、飛行逐幀或效能驗收。
