# Playthrough smoke test

從專案根目錄執行：

```bash
godot --headless --path . -- --playthrough-test
```

測試會在隔離的暫存存檔中驗證：

1. 新遊戲與接受任務。
2. 暮光村切換至北境遺跡。
3. 戰鬥開始、玩家勝利與任務道具發放。
4. 對話結束後回到探索、返回村莊並交付任務。
5. 戰敗狀態及回村恢復。
6. JSON 存檔寫入、狀態破壞、讀檔還原與地圖位置恢復。

成功標記：

```text
PLAYTHROUGH_TEST_PASS dialogue quest maps save battle
```
