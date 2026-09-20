# 結尾動作素材

2026-09-21，使用者確認保留目前美術，補手持月印與睜眼。兩張素材由內建 imagegen 依既有原創圖片編修，非第三方下載；原輸出保留於 Codex generated_images。

- `elder_seal_motion.png`：1774×887 透明三姿勢圖集。`keeper_seal_motion.gd` 使用逐幀實測 alpha 範圍裁切，0／0.24／0.48 秒切換腰側、抬起、手持；留在最後姿勢直到霧中段落。替換實際艾爾 sprite，恢復原貼圖、比例與 offset，不修改碰撞、腳底或狀態。
- `fog_awakening_closed.png`：只取眼部小區域當閉眼底圖。`fog_awakening.gdshader` 保持原背景，0.25–1.45 秒逐漸張開，下一頁沿用進度；離圖、結束或其他插圖清除材質。沒有揭露甦醒者身分。
- 手持是三個關鍵姿勢，不是完整逐格骨架動畫；睜眼是局部 aperture shader 動畫，不是整張圖淡入。

原輸出：`exec-aba273f8-8961-44d8-b45e-326ee077c2ce.png`、`exec-d7607663-f293-46da-99d0-f2547b9a672a.png`，皆在 `/Users/cwchang/.codex/generated_images/01a0bf97-8bca-7b12-83c6-699844c1410d/`。

## 手持提示

Use case: identity-preserve. Reference image: existing game NPC sheet, use ONLY the white-haired elderly man at left. Create an original animation sprite sheet: exactly THREE equal-width cells in ONE horizontal row, transparent background genuine alpha, no text. Same elder identity, face, long white beard, blue robe and ochre mantle, staff in his right hand on viewer left; exact same front-facing pose, height, head scale, feet baseline and stationary staff across frames. Only his free left arm on viewer right changes. Frame 1: free hand holds small bronze circular seal at waist. Frame 2: elbow bent lifting seal midway toward chest. Frame 3: seal held up beside chest, fingers visibly gripping lower rim; bronze disk facing viewer with charred open C-shaped ring and very thin pale silver trace, ring must have a clear gap on viewer right. Coin about palm size, not giant shield. Three clean full-body pixel-art sprites matching reference, evenly centered one per cell with generous transparent margins and identical baseline. No other characters, no environment, no ground shadow, no glow outside seal, no extra arms, no labels. Keep the hand physically holding the disk in every frame. Target sheet 1536x768.

## 閉眼底圖提示

Use case: precise-object-edit. Edit target: attached fog forest game illustration. Remove ONLY the two tiny glowing white eyes near normalized x=0.50,y=0.38. Replace those tiny marks with matching featureless blue-gray fog so the hidden presence has its eyes completely closed/invisible. Preserve the ENTIRE rest of this image exactly: dimensions, viewpoint, fog, trees, ruins, moon, lighting and stone road unchanged. No new details, no figure, no face or silhouette, no text. This is the closed-eye animation base for this exact game picture.

## 驗證

與主分支裝備系統合併時，新增艾爾四種裝備搭配的結尾回歸：演出不修改裝備資料，結束後恢復進入演出前的換裝貼圖與 offset。手持三姿勢仍使用原藍金服裝的專用圖集，尚無星辰祭袍／星月杖版本；這是短暫演出外觀限制，不是卸除裝備。

本輪双 renderer 六階段實景已檢視；初版 shader 重複乘上貼圖導致變暗，已修正並重拍。Compatibility 閉眼／睜眼插圖像素差異只在局部 20×6 區域，原背景不變。雙 renderer 完整主線、月印時序／中斷恢復測試、Web release 匯出均通過。Chrome 153 三故事預覽無 console／page error 或 context loss；結尾初始／停留後截圖已檢視，前綴 `/tmp/wanderlight-web-story-1789923408301`。沒有重跑全 59 項或宣稱全部素材已驗收。

`tests/moon_seal_test.gd` 驗證三姿勢、原角色恢復、兩條石碑路徑、睜眼 0／中間／1 進度、翻頁延續與清理。`tests/ending_motion_capture.gd` 為兩種真實 renderer 分別拍攝六階段，輸出 `/tmp/wanderlight-ending-<stage>-<renderer>.png`；不寫正常存檔。固定姿勢截圖與時序測試不能外推全部角色動作已完成。
