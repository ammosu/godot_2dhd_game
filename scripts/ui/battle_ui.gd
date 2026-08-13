class_name BattleUI
extends CanvasLayer

signal battle_finished(victory: bool)

var _root: Control
var _title_label: Label
var _enemy_hp_label: Label
var _player_status_label: Label
var _log_label: Label
var _action_grid: GridContainer
var _continue_button: Button
var _action_buttons: Array[Button] = []

var _enemy_name: String
var _enemy_hp: int
var _enemy_max_hp: int
var _enemy_attack: int
var _enemy_defense: int
var _active: bool = false
var _player_turn: bool = false
var _guarding: bool = false
var _victory: bool = false


func _ready() -> void:
	layer = 70
	_build_ui()


func start_battle(enemy_data: Dictionary) -> void:
	_enemy_name = str(enemy_data.get("name", "未知敵人"))
	_enemy_max_hp = int(enemy_data.get("max_hp", 50))
	_enemy_hp = _enemy_max_hp
	_enemy_attack = int(enemy_data.get("attack", 10))
	_enemy_defense = int(enemy_data.get("defense", 2))
	_active = true
	_player_turn = true
	_guarding = false
	_victory = false
	_root.visible = true
	_action_grid.visible = true
	_continue_button.visible = false
	GameState.set_mode(GameState.Mode.BATTLE)
	_set_actions_enabled(true)
	_log_label.text = "%s 擋住了去路。輪到你行動。" % _enemy_name
	_update_display()


func choose_action(action: String) -> void:
	if not _active or not _player_turn:
		return
	match action:
		"attack":
			var damage := maxi(1, GameState.player_attack - _enemy_defense)
			_enemy_hp = maxi(0, _enemy_hp - damage)
			_log_label.text = "你攻擊 %s，造成 %d 點傷害。" % [_enemy_name, damage]
		"skill":
			if not GameState.spend_mp(5):
				_log_label.text = "MP 不足，無法施展月影斬。"
				_update_display()
				return
			var damage := maxi(1, GameState.player_attack + 11 - _enemy_defense)
			_enemy_hp = maxi(0, _enemy_hp - damage)
			_log_label.text = "月影斬命中，造成 %d 點傷害！" % damage
		"potion":
			if not GameState.use_potion():
				_log_label.text = "現在無法使用藥水。"
				_update_display()
				return
			_log_label.text = "使用藥水，恢復 35 點 HP。"
		"guard":
			_guarding = true
			_log_label.text = "你擺出防禦姿態。"
		_:
			return
	_update_display()
	if _enemy_hp <= 0:
		GameState.defeat_guardian()
		_end_battle(true)
		return
	_player_turn = false
	_set_actions_enabled(false)
	_enemy_turn.call_deferred()


func is_active() -> bool:
	return _root.visible


func is_resolved() -> bool:
	return _root.visible and not _active


func did_player_win() -> bool:
	return _victory


func _enemy_turn() -> void:
	await get_tree().create_timer(0.55).timeout
	if not _active:
		return
	var damage := maxi(1, _enemy_attack - GameState.player_defense)
	if _guarding:
		damage = maxi(1, damage / 2)
		_guarding = false
	GameState.damage_player(damage)
	_log_label.text += "\n%s 反擊，造成 %d 點傷害。" % [_enemy_name, damage]
	_update_display()
	if GameState.player_hp <= 0:
		_end_battle(false)
		return
	_player_turn = true
	_set_actions_enabled(true)


func _end_battle(victory: bool) -> void:
	_active = false
	_player_turn = false
	_victory = victory
	_action_grid.visible = false
	_continue_button.visible = true
	_continue_button.text = "勝利！繼續" if victory else "戰敗…返回村莊"
	_log_label.text += "\n%s" % ("遺跡守衛化為月光。" if victory else "你失去了意識。")
	_update_display()


func _finish_battle() -> void:
	if _active or not _root.visible:
		return
	_root.visible = false
	GameState.set_mode(GameState.Mode.EXPLORE)
	battle_finished.emit(_victory)


func _unhandled_input(event: InputEvent) -> void:
	if not _root.visible or event.is_echo():
		return
	if _active and _player_turn:
		if event.is_action_pressed("battle_attack"):
			choose_action("attack")
		elif event.is_action_pressed("battle_skill"):
			choose_action("skill")
		elif event.is_action_pressed("battle_potion"):
			choose_action("potion")
		elif event.is_action_pressed("battle_guard"):
			choose_action("guard")
	elif not _active and (event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")):
		_finish_battle()
	get_viewport().set_input_as_handled()


func _update_display() -> void:
	_title_label.text = "BATTLE  /  %s" % _enemy_name
	_enemy_hp_label.text = "%s  HP  %d / %d" % [_enemy_name, _enemy_hp, _enemy_max_hp]
	_player_status_label.text = "旅人  HP %d/%d    MP %d/%d    藥水 × %d" % [
		GameState.player_hp,
		GameState.player_max_hp,
		GameState.player_mp,
		GameState.player_max_mp,
		int(GameState.inventory.get("potion", 0)),
	]


func _set_actions_enabled(enabled: bool) -> void:
	for button in _action_buttons:
		button.disabled = not enabled


func _make_action_button(text: String, action: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(220.0, 56.0)
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(func() -> void: choose_action(action))
	_action_buttons.append(button)
	return button


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.theme = GameState.ui_theme
	add_child(_root)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.025, 0.02, 0.065, 0.96)
	_root.add_child(backdrop)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -390.0
	panel.offset_top = -285.0
	panel.offset_right = 390.0
	panel.offset_bottom = 285.0
	_root.add_child(panel)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("19152d")
	panel_style.border_color = Color("d7a65d")
	panel_style.set_border_width_all(4)
	panel_style.set_corner_radius_all(10)
	panel_style.set_content_margin_all(28.0)
	panel.add_theme_stylebox_override("panel", panel_style)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	panel.add_child(content)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_color_override("font_color", Color("f5c36e"))
	_title_label.add_theme_font_size_override("font_size", 30)
	content.add_child(_title_label)

	var enemy_art := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://assets/third_party/ninja_adventure/characters/ninja_blue.png") as Texture2D
	atlas.region = Rect2(0.0, 0.0, 16.0, 16.0)
	enemy_art.texture = atlas
	enemy_art.custom_minimum_size = Vector2(128.0, 128.0)
	enemy_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	enemy_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	enemy_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	enemy_art.modulate = Color("ca8cff")
	content.add_child(enemy_art)

	_enemy_hp_label = Label.new()
	_enemy_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_enemy_hp_label.add_theme_font_size_override("font_size", 20)
	content.add_child(_enemy_hp_label)

	_player_status_label = Label.new()
	_player_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_player_status_label.add_theme_color_override("font_color", Color("bde7e5"))
	_player_status_label.add_theme_font_size_override("font_size", 18)
	content.add_child(_player_status_label)

	_log_label = Label.new()
	_log_label.custom_minimum_size = Vector2(0.0, 60.0)
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_log_label.add_theme_font_size_override("font_size", 18)
	content.add_child(_log_label)

	_action_grid = GridContainer.new()
	_action_grid.columns = 2
	_action_grid.add_theme_constant_override("h_separation", 12)
	_action_grid.add_theme_constant_override("v_separation", 10)
	content.add_child(_action_grid)
	_action_grid.add_child(_make_action_button("[1] 攻擊", "attack"))
	_action_grid.add_child(_make_action_button("[2] 月影斬  MP 5", "skill"))
	_action_grid.add_child(_make_action_button("[3] 藥水", "potion"))
	_action_grid.add_child(_make_action_button("[4] 防禦", "guard"))

	_continue_button = Button.new()
	_continue_button.custom_minimum_size = Vector2(0.0, 60.0)
	_continue_button.add_theme_font_size_override("font_size", 20)
	_continue_button.pressed.connect(_finish_battle)
	content.add_child(_continue_button)
	_root.visible = false
