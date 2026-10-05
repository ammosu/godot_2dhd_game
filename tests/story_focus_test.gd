extends SceneTree
var failures: int = 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _run() -> void:
	var state := root.get_node("GameState")
	state.reset_new_game(false)
	state.flags.intro_seen = true
	var world: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world.set("_test_mode", true)
	var hud: Node = world.get_node("HUD")
	var dialogue: Node = world.get_node("DialogueUI")
	hud._notice_queue.clear()
	hud.set_process(false)
	var picture: Texture2D = load("res://assets/generated/fog_awakening_closed.png")
	dialogue.show_dialogue([{"text": "插圖", "illustration": picture}, {"text": "一般頁"}])
	check(not hud.mini_map.visible and not hud.player_status.visible and not hud._quest_panel.visible, "illustration hides HUD")
	hud.refresh(false)
	check(not hud.mini_map.visible, "refresh preserves story focus")
	check(dialogue._story_shade.visible and is_equal_approx(dialogue._illustration.anchor_right - dialogue._illustration.anchor_left, 0.7), "large illustration and shade")
	state.notification_requested.emit("第一則")
	state.notification_requested.emit("第二則")
	hud._process(10.0)
	check(not hud._notice_banner.visible and hud._notice_queue.size() == 2, "dialogue queues notices")
	dialogue.advance()
	check(not hud.mini_map.visible and not hud.player_status.visible and hud._quest_panel.visible and not dialogue._story_shade.visible, "plain dialogue keeps status and map hidden")
	hud._process(10.0)
	check(not hud._notice_banner.visible, "plain dialogue still defers notices")
	dialogue.advance()
	hud._process(0.0)
	check(hud.mini_map.visible and hud.player_status.visible, "closing dialogue restores HUD")
	check(hud.notice_label.text == "第一則", "first notice after closing")
	# Reopening dismisses an already shown notice; it must never replay.
	dialogue.show_dialogue([{"text": "再次對話", "illustration": picture}])
	check(not hud._notice_banner.visible, "existing notice hidden on reopening")
	dialogue.advance()
	hud._process(0.0)
	check(hud.notice_label.text == "第二則", "second notice follows first")
	hud._process(3.2)
	check(not hud._notice_banner.visible, "queue drains")
	# Quest items merge, duplicate signals disappear, expired combat rewards do not.
	hud.set_dialogue_open(true)
	hud.show_notice("經驗 +12")
	hud._notice_queue.back().time = Time.get_ticks_msec() - 8001
	hud.show_notice("獲得：古鐘槌")
	hud.show_notice("獲得：星灣的回信")
	hud.show_notice("獲得：古鐘槌")
	check(hud._notice_queue.size() == 1, "expired reward removed and repeated items deduplicated")
	check(hud._notice_queue[0].message == "獲得：古鐘槌、星灣的回信", "consecutive acquired items merge")
	hud.show_notice("拾取・月苔 ×1")
	hud.show_notice("諾亞加入了隊伍")
	hud.show_notice("驛路旅人平安了")
	var old_map: String = state.current_map
	state.current_map = "star_bay_city"
	hud._process(0.0)
	check(hud._notice_queue.is_empty(), "map change discards items, results and combat pickups")
	hud.show_notice("希雅・鐘聲：減速附近敵人")
	check(hud._notice_queue.is_empty(), "out of combat tutorial rejected")
	hud.show_notice("獲得：新道具")
	hud.show_notice("新的任務結果")
	for entry: Dictionary in hud._notice_queue:
		entry.time = Time.get_ticks_msec() - 6001
	hud.set_dialogue_open(false)
	hud._process(0.0)
	check(hud._notice_queue.is_empty() and not hud._notice_banner.visible, "items and results expire after six seconds")
	hud.set_dialogue_open(true)
	hud.show_notice("獲得：新鮮信件")
	hud.show_notice("獲得：新鮮鐘槌")
	hud.show_notice("完成新的任務")
	hud.set_dialogue_open(false)
	hud._process(0.0)
	check(hud.notice_label.text == "獲得：新鮮信件、新鮮鐘槌", "fresh items appear on first frame after dialogue")
	hud._process(3.2)
	check(hud.notice_label.text == "完成新的任務", "fresh quest result follows merged items")
	hud.set_dialogue_open(true)
	hud.show_notice("獲得：不能補播")
	hud.show_notice("不能補播的任務結果")
	state.mode = state.Mode.BATTLE
	hud.show_notice("經驗 +99")
	hud.set_dialogue_open(false)
	hud._process(0.0)
	check(hud.notice_label.text == "經驗 +99" and hud._notice_queue.is_empty(), "battle discards deferred outcomes and prioritizes combat")
	state.mode = state.Mode.EXPLORE
	hud._process(3.2)
	check(not hud._notice_banner.visible, "old outcomes never replay after battle")
	# Navigation interrupts an active result and repeat visits are never deduplicated.
	for visit: int in range(2):
		hud.show_notice("抵達・暮光村")
		hud._process(0.0)
		check(hud.notice_label.text == "抵達・暮光村", "repeat arrival displays immediately")
		hud.set_dialogue_open(true)
		hud._process(10.0)
		check(not hud._notice_banner.visible, "fresh arrival disappears immediately")
		hud.set_dialogue_open(false)
		hud._process(0.0)
		check(hud.notice_label.text.is_empty() and hud._active_notice.is_empty(), "fresh arrival never replays after dialogue")
		hud._process(3.2)
	# Queued arrivals also disappear; unrelated results remain queued.
	hud.show_notice("抵達・東行舊道")
	hud.show_notice("保留任務結果")
	hud.set_dialogue_open(true)
	check(hud._notice_queue.size() == 1 and hud._notice_queue[0].kind == "result", "queued fresh arrival removed without losing quest notice")
	hud.show_notice("抵達・東行舊道")
	check(hud._notice_queue.size() == 1, "same-frame arrival after dialogue open is suppressed")
	hud.set_dialogue_open(false)
	hud._notice_queue.clear()
	hud.show_notice("抵達・暮光村")
	hud._notice_queue[0].time = Time.get_ticks_msec() - 2000
	hud._process(0.0)
	var arrived_at: int = hud._active_notice.time
	hud.set_dialogue_open(true)
	hud.set_dialogue_open(true)
	check(hud._notice_queue.size() == 1 and hud._notice_queue[0].time == arrived_at, "older arrival keeps original timestamp without duplicates")
	hud.set_dialogue_open(false)
	hud._process(0.0)
	check(hud.notice_label.text == "抵達・暮光村", "arrival at two-second boundary still resumes")
	state.current_map = old_map
	world.queue_free()
	await process_frame
	if failures == 0:
		print("STORY_FOCUS_TEST_PASS focus restoration notices order")
	quit(0 if failures == 0 else 1)
