# Playthrough smoke test

從專案根目錄執行：

```bash
godot --headless --path . -- --playthrough-test
```

測試會在隔離的暫存存檔中驗證：

1. 新遊戲時月燈微弱、村民劇情對話與接受任務。
2. 暮光村切換至北境遺跡。
3. 閱讀遺跡石碑後保存故事旗標，以及月泉完整恢復 HP／MP。
4. 戰鬥開始、玩家勝利與任務道具發放。
5. 對話結束後回到探索、返回村莊、交付任務並點亮月燈。
6. 戰敗狀態及回村恢復。
7. JSON 存檔寫入、狀態破壞、讀檔還原、地圖位置與石碑線索恢復。

成功標記：

```text
PLAYTHROUGH_TEST_PASS dialogue quest maps save battle
```
