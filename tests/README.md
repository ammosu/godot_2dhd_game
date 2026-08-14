# Playthrough smoke test

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
