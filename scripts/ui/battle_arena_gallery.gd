extends Node
## Standalone visual gallery. Does not start a GameState combat session or write saves.
const BattleUI = preload("res://scripts/ui/party_battle_ui.gd")
const Layout = preload("res://scripts/systems/battle_arena_layout.gd")
const THEMES: Array[String] = ["village", "forest", "ruins", "moon_spring", "eclipse"]
const LABELS: Array[String] = ["村莊廣場", "月夜森林", "古代遺跡", "月泉聖域", "月蝕神殿"]
var _battle: PartyBattleUI
var _theme: OptionButton
var _seed: SpinBox
var _description: Label
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_battle = BattleUI.new()
	add_child(_battle)
	var overlay := CanvasLayer.new()
	overlay.layer = 71
	add_child(overlay)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	margin.add_theme_constant_override("margin_left", 80)
	margin.add_theme_constant_override("margin_right", 80)
	margin.add_theme_constant_override("margin_top", 14)
	margin.theme = GameState.ui_theme
	overlay.add_child(margin)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	margin.add_child(bar)
	_theme = OptionButton.new()
	_theme.custom_minimum_size = Vector2(190, 44)
	for label: String in LABELS:
		_theme.add_item(label)
	_theme.item_selected.connect(func(_index: int) -> void: _refresh())
	bar.add_child(_theme)
	var seed_label := Label.new()
	seed_label.text = "配置種子"
	bar.add_child(seed_label)
	_seed = SpinBox.new()
	_seed.min_value = 0
	_seed.max_value = 2147483647
	_seed.value = 20260921
	_seed.step = 1
	_seed.custom_minimum_size.x = 190
	_seed.update_on_text_changed = false
	_seed.value_changed.connect(func(_value: float) -> void: _refresh())
	bar.add_child(_seed)
	var replay := Button.new()
	replay.text = "重現配置"
	replay.pressed.connect(_refresh)
	bar.add_child(replay)
	var reroll := Button.new()
	reroll.text = "隨機換景"
	reroll.pressed.connect(func() -> void: _seed.value = _rng.randi_range(0, 2147483647))
	bar.add_child(reroll)
	_description = Label.new()
	_description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bar.add_child(_description)
	_refresh()
	_theme.grab_focus()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			_capture_gallery(argument.trim_prefix("--capture-dir="))
			break


func _refresh() -> void:
	var descriptor := Layout.generate(THEMES[_theme.selected], int(_seed.value))
	_battle.show_arena_preview(descriptor)
	_description.text = "構圖 %d / 4" % (int(descriptor.layout_index) + 1)


func _capture_gallery(directory: String) -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Gallery captures require a display; omit --headless.")
		get_tree().quit(1)
		return
	var absolute := ProjectSettings.globalize_path(directory)
	if DirAccess.make_dir_recursive_absolute(absolute) != OK:
		push_error("Cannot create gallery capture directory: " + absolute)
		get_tree().quit(1)
		return
	for index: int in range(THEMES.size()):
		_theme.select(index)
		for visual_seed: int in [20260921, 42]:
			_seed.set_value_no_signal(visual_seed)
			_refresh()
			await get_tree().process_frame
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var result := get_viewport().get_texture().get_image().save_png(absolute.path_join("%s-%d.png" % [THEMES[index], visual_seed]))
			if result != OK:
				push_error("Could not save gallery capture")
				get_tree().quit(1)
				return
	_battle.queue_free()
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		get_node("/root/" + singleton).call("stop_all")
	await get_tree().create_timer(0.25).timeout
	print("BATTLE_ARENA_GALLERY_CAPTURE_PASS five_themes two_seeds six_actors")
	get_tree().quit()
