extends SceneTree

const Appearance = preload("res://scripts/gameplay/equipment_appearance.gd")
const Portrait = preload("res://scripts/ui/equipment_portrait.gd")
var failures: Array[String] = []
var capture: bool = false


func _init() -> void:
	call_deferred("_run")


func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)


func screenshot(label: String) -> void:
	if not capture:
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var path := "/tmp/wanderlight-equipment-" + label + ".png"
	check(root.get_texture().get_image().save_png(path) == OK, "Screenshot failed: " + label)
	print(path)


func _run() -> void:
	capture = "--equipment-capture" in OS.get_cmdline_user_args()
	var state: Node = root.get_node("GameState")
	state.call("reset_new_game", false)
	state.get("flags")["intro_seen"] = true
	var world := load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(world)
	await process_frame
	var ui: Node = world.get_node("EquipmentUI")
	var player: Node = world.get_node("Player")
	var original: Dictionary = state.get("equipped").duplicate(true)
	ui.call("open")
	check(bool(ui.get("visible")), "Equipment screen failed to open")
	check(bool(state.call("is_input_locked")), "World input not locked")
	await screenshot("starter")
	ui.call("select_item", "moonward_cloak")
	await screenshot("armor-only")
	ui.call("select_item", "traveler_coat")
	ui.call("select_item", "moonsteel_saber")
	await screenshot("weapon-only")
	ui.call("select_item", "moonward_cloak")
	check(state.get("equipped") == original, "Preview changed authoritative equipment")
	check(int(state.get("player_attack")) == 18, "Preview changed combat stats")
	check("18  →  22" in str(ui.get("_stats_label").text), "Attack comparison missing")
	await screenshot("preview")
	ui.call("close")
	check(state.get("equipped") == original, "Cancel committed preview")
	ui.call("open")
	check(ui.get("pending") == original, "Reopen retained cancelled preview")
	ui.call("select_item", "moonsteel_saber")
	ui.call("select_item", "moonward_cloak")
	ui.call("confirm_equipment")
	check(int(state.get("player_attack")) == 22 and int(state.get("player_defense")) == 7, "Confirmation failed")
	var sprite: AnimatedSprite3D = player.get("sprite")
	check(sprite.sprite_frames == Appearance.walking_frames(state.get("equipped")), "Exploration replacement not applied")
	for direction: String in ["down", "up", "left", "right"]:
		for frame: int in range(4):
			sprite.animation = direction
			sprite.frame = frame
			player.call("_refresh_equipment")
			var base := Appearance.WALK.get_frame_texture(direction, frame)
			check(sprite.sprite_frames.get_frame_texture(direction, frame) == Appearance.texture_for(base, "walk_" + direction, state.get("equipped")), "Walking frame mismatch")
	ui.call("close")
	await screenshot("explore")
	var save_path := "user://equipment_visual_%d.json" % Time.get_ticks_usec()
	check(bool(state.call("save_game", save_path, false)), "Visual loadout save failed")
	state.call("equip_loadout", original)
	check(sprite.sprite_frames == Appearance.WALK, "Starter loadout retained upgraded art")
	check(bool(state.call("load_game", save_path, false)), "Visual loadout load failed")
	await process_frame
	check(sprite.sprite_frames == Appearance.walking_frames(state.get("equipped")), "Load did not restore exploration art")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	var battle: Node = world.get_node("BattleUI")
	battle.call("start_battle", {"name": "裝備測試", "max_hp": 1000, "attack": 14, "defense": 3})
	check(int(state.get("battle_session").actors[0].attack) == 22, "Battle did not inherit equipped attack")
	check(not bool(state.call("equip_item", "traveler_blade")), "Battle allowed equipment changes")
	ui.call("open")
	check(not bool(ui.get("visible")), "Equipment screen opened during battle")
	for pose: String in Appearance.POSES:
		battle.call("_pose", 0, pose)
		var portrait: TextureRect = battle.get("_portraits")[0]
		var base := load("res://assets/generated/wanderer_combat_%s.tres" % pose) as Texture2D
		check(portrait.texture == Appearance.texture_for(base, pose, state.get("equipped")), "Battle pose replacement mismatch: " + pose)
	await screenshot("battle")
	battle.call("_pose", 0, "idle")
	battle.call("choose_action", "attack")
	for phase: String in ["windup", "attack", "recover", "idle"]:
		var deadline := Time.get_ticks_msec() + 4000
		var live_portrait: TextureRect = battle.get("_portraits")[0]
		while str(live_portrait.texture.get_meta("pose", "")) != phase and Time.get_ticks_msec() < deadline:
			await process_frame
		check(str(live_portrait.texture.get_meta("pose", "")) == phase, "Missing live attack phase: " + phase)
		check(str(live_portrait.texture.get_meta("variant", "")) == "moonward_saber", "Live animation reverted to old gear: " + phase)
	check(int(state.get("battle_session").actors[3].hp) == 981, "Equipped attack damage did not resolve once")
	if capture:
		await _gallery(state)
		await _walk_gallery(state)
	await create_timer(2.7).timeout
	world.queue_free()
	await process_frame
	state.set("battle_session", null)
	state.call("reset_new_game", false)
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	if failures.is_empty():
		print("EQUIPMENT_VISUAL_TEST_PASS preview cancel confirm world_16_frames battle_7_poses locks")
	quit(0 if failures.is_empty() else 1)


func _gallery(state: Node) -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 110
	root.add_child(canvas)
	var background := ColorRect.new()
	background.color = Color("182737")
	canvas.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for index: int in range(7):
		var pose: String = Appearance.POSES[index]
		var texture := load("res://assets/generated/wanderer_combat_%s.tres" % pose) as Texture2D
		var portrait := Portrait.new()
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		canvas.add_child(portrait)
		var ratio := 245.0 / texture.get_height()
		portrait.dress(texture, pose, state.get("equipped"))
		portrait.size = portrait.texture.get_size() * ratio
		portrait.position = Vector2(160 + (index % 4) * 320 - portrait.size.x * 0.5, 60 + (index / 4) * 330 - Appearance.PAD.y * ratio)
		var label := Label.new()
		label.position = Vector2(90 + (index % 4) * 320, 20 + (index / 4) * 330)
		label.text = pose
		canvas.add_child(label)
	await screenshot("poses")
	canvas.queue_free()
	await process_frame


func _walk_gallery(state: Node) -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 110
	root.add_child(canvas)
	var background := ColorRect.new()
	background.color = Color("182737")
	canvas.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var frames := load("res://assets/generated/wanderer_frames.tres") as SpriteFrames
	var directions: Array[String] = ["down", "left", "up", "right"]
	for row: int in range(4):
		for frame: int in range(4):
			var portrait := Portrait.new()
			portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			canvas.add_child(portrait)
			portrait.dress(frames.get_frame_texture(directions[row], frame), "walk_" + directions[row], state.get("equipped"))
			portrait.size = portrait.texture.get_size() * (180.0 / 320.0)
			portrait.position = Vector2(70 + frame * 320, row * 180) - Appearance.PAD * (180.0 / 320.0)
	await screenshot("walking")
	canvas.queue_free()
	await process_frame
