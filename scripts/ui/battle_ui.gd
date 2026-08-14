class_name BattleUI
extends CanvasLayer

signal battle_finished(victory: bool)

var _root: Control
var _battle_panel: PanelContainer
var _combat_stage: Control
var _title_label: Label
var _enemy_hp_label: Label
var _enemy_hp_bar: ProgressBar
var _player_status_label: Label
var _player_hp_bar: ProgressBar
var _log_label: Label
var _action_grid: GridContainer
var _continue_button: Button
var _player_art: TextureRect
var _enemy_art: TextureRect
var _player_shadow: Panel
var _enemy_shadow: Panel
var _impact_flash: ColorRect
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
var _animation_busy: bool = false
var _animation_time: float = 0.0
var _player_home: Vector2
var _enemy_home: Vector2
var _homes_initialized: bool = false


func _ready() -> void:
	layer = 70
	_build_ui()


func _process(delta: float) -> void:
	if not _root.visible or _animation_busy:
		return
	_animation_time += delta
	_player_art.rotation = sin(_animation_time * 2.4) * 0.012
	_enemy_art.rotation = sin(_animation_time * 2.9 + 1.2) * 0.018
	_player_shadow.scale.x = 1.0 + sin(_animation_time * 2.4) * 0.035
	_enemy_shadow.scale.x = 1.0 + sin(_animation_time * 2.9 + 1.2) * 0.045


func start_battle(enemy_data: Dictionary) -> void:
	_enemy_name = str(enemy_data.get("name", "未知敵人"))
	_enemy_max_hp = int(enemy_data.get("max_hp", 50))
	_enemy_hp = _enemy_max_hp
	_enemy_attack = int(enemy_data.get("attack", 10))
	_enemy_defense = int(enemy_data.get("defense", 2))
	_active = true
	_player_turn = false
	_guarding = false
	_victory = false
	_animation_busy = true
	_animation_time = 0.0
	_root.visible = true
	_action_grid.visible = true
	_continue_button.visible = false
	GameState.set_mode(GameState.Mode.BATTLE)
	_set_actions_enabled(false)
	_log_label.text = "%s 擋住了去路。選擇旅人的行動。" % _enemy_name
	_update_display()
	await get_tree().process_frame
	if not _homes_initialized:
		_player_home = _player_art.position
		_enemy_home = _enemy_art.position
		_homes_initialized = true
	_reset_stage_actors()
	_play_battle_intro()


func choose_action(action: String) -> void:
	if not _active or not _player_turn or _animation_busy:
		return
	if action == "skill" and not GameState.spend_mp(5):
		_log_label.text = "MP 不足，無法施展月影斬。"
		_update_display()
		return
	if action == "potion" and not GameState.use_potion():
		_log_label.text = "現在無法使用藥水。"
		_update_display()
		return

	_player_turn = false
	_animation_busy = true
	_set_actions_enabled(false)
	_resolve_player_action(action)


func is_active() -> bool:
	return _root.visible


func is_resolved() -> bool:
	return _root.visible and not _active


func did_player_win() -> bool:
	return _victory


func _resolve_player_action(action: String) -> void:
	match action:
		"attack":
			var damage := maxi(1, GameState.player_attack - _enemy_defense)
			_log_label.text = "旅人拔刃向前！"
			await _animate_player_strike(false)
			_enemy_hp = maxi(0, _enemy_hp - damage)
			_log_label.text = "攻擊命中 %s，造成 %d 點傷害。" % [_enemy_name, damage]
			_spawn_damage_number(_enemy_art, damage, Color("fff0ad"))
		"skill":
			var damage := maxi(1, GameState.player_attack + 11 - _enemy_defense)
			_log_label.text = "月光聚於刀鋒——月影斬！"
			await _animate_player_strike(true)
			_enemy_hp = maxi(0, _enemy_hp - damage)
			_log_label.text = "月影斬破開防禦，造成 %d 點傷害！" % damage
			_spawn_damage_number(_enemy_art, damage, Color("9efcff"), true)
		"potion":
			_log_label.text = "旅人飲下藥水，恢復 35 點 HP。"
			await _animate_support_action(Color("85f3c5"), "＋35")
		"guard":
			_guarding = true
			_log_label.text = "旅人穩住腳步，架起防禦姿態。"
			await _animate_support_action(Color("8dc8ff"), "GUARD")
		_:
			_animation_busy = false
			_player_turn = true
			_set_actions_enabled(true)
			return

	_update_display()
	if _enemy_hp <= 0:
		GameState.defeat_guardian()
		await _animate_enemy_defeat()
		_end_battle(true)
		return
	_animation_busy = false
	_enemy_turn()


func _enemy_turn() -> void:
	await get_tree().create_timer(0.28).timeout
	if not _active:
		return
	_animation_busy = true
	_log_label.text += "\n%s 正在蓄力反擊……" % _enemy_name
	var damage := maxi(1, _enemy_attack - GameState.player_defense)
	if _guarding:
		damage = maxi(1, damage / 2)
		_guarding = false
	await _animate_enemy_strike()
	GameState.damage_player(damage)
	_log_label.text = "%s 突進反擊，造成 %d 點傷害。" % [_enemy_name, damage]
	_spawn_damage_number(_player_art, damage, Color("ff9d86"))
	_update_display()
	if GameState.player_hp <= 0:
		await _animate_player_defeat()
		_end_battle(false)
		return
	_animation_busy = false
	_player_turn = true
	_set_actions_enabled(true)


func _play_battle_intro() -> void:
	_animation_busy = true
	_player_art.position = _player_home - Vector2(95.0, 0.0)
	_enemy_art.position = _enemy_home + Vector2(95.0, 0.0)
	_player_art.modulate.a = 0.0
	_enemy_art.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_player_art, "position", _player_home, 0.32).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(_enemy_art, "position", _enemy_home, 0.32).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(_player_art, "modulate:a", 1.0, 0.22)
	tween.tween_property(_enemy_art, "modulate:a", 1.0, 0.22)
	await tween.finished
	_animation_busy = false
	_player_turn = true
	_set_actions_enabled(true)


func _animate_player_strike(is_skill: bool) -> void:
	_player_art.rotation = -0.08
	var windup := create_tween()
	windup.tween_property(_player_art, "position", _player_home - Vector2(34.0, 0.0), 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await windup.finished
	var dash_target := Vector2(_enemy_home.x - 118.0, _enemy_home.y)
	var dash := create_tween()
	dash.tween_property(_player_art, "position", dash_target, 0.17 if is_skill else 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	await dash.finished
	_show_slash_effect(is_skill)
	_flash_actor(_enemy_art, Color("b9ffff") if is_skill else Color("ffffff"))
	_shake_panel(9.0 if is_skill else 5.0)
	await get_tree().create_timer(0.11).timeout
	var retreat := create_tween()
	retreat.tween_property(_player_art, "position", _player_home, 0.27).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	retreat.parallel().tween_property(_player_art, "rotation", 0.0, 0.18)
	await retreat.finished


func _animate_enemy_strike() -> void:
	var windup := create_tween()
	windup.tween_property(_enemy_art, "position", _enemy_home + Vector2(26.0, 0.0), 0.12)
	await windup.finished
	var dash_target := Vector2(_player_home.x + 118.0, _player_home.y)
	var dash := create_tween()
	dash.tween_property(_enemy_art, "position", dash_target, 0.19).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	await dash.finished
	_show_slash_effect(false, true)
	_flash_actor(_player_art, Color("ffb0a0"))
	_shake_panel(6.0)
	await get_tree().create_timer(0.1).timeout
	var retreat := create_tween()
	retreat.tween_property(_enemy_art, "position", _enemy_home, 0.25).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	await retreat.finished


func _animate_support_action(color: Color, text: String) -> void:
	var effect := Label.new()
	effect.text = text
	effect.theme = GameState.ui_theme
	effect.position = _player_art.position + Vector2(18.0, -25.0)
	effect.add_theme_color_override("font_color", color)
	effect.add_theme_color_override("font_outline_color", Color("111020"))
	effect.add_theme_constant_override("outline_size", 8)
	effect.add_theme_font_size_override("font_size", 28)
	effect.z_index = 12
	_combat_stage.add_child(effect)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(effect, "position:y", effect.position.y - 48.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(effect, "modulate:a", 0.0, 0.55).set_delay(0.2)
	tween.tween_property(_player_art, "modulate", color.lightened(0.25), 0.18)
	await tween.finished
	effect.queue_free()
	_player_art.modulate = Color.WHITE


func _animate_enemy_defeat() -> void:
	_animation_busy = true
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_enemy_art, "position:y", _enemy_home.y - 30.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_enemy_art, "rotation", 0.35, 0.45)
	tween.tween_property(_enemy_art, "modulate:a", 0.0, 0.45)
	tween.tween_property(_enemy_shadow, "modulate:a", 0.0, 0.38)
	await tween.finished


func _animate_player_defeat() -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_player_art, "position:y", _player_home.y + 18.0, 0.35)
	tween.tween_property(_player_art, "rotation", -0.45, 0.35)
	tween.tween_property(_player_art, "modulate", Color("706b7c"), 0.35)
	await tween.finished


func _show_slash_effect(is_skill: bool, mirrored: bool = false) -> void:
	var slash := ColorRect.new()
	slash.color = Color("8ffff5") if is_skill else Color("fff4c2")
	slash.custom_minimum_size = Vector2(9.0 if is_skill else 6.0, 150.0 if is_skill else 112.0)
	slash.size = slash.custom_minimum_size
	var target := _player_art if mirrored else _enemy_art
	slash.position = target.position + target.size * 0.5 - slash.size * 0.5
	slash.rotation = 0.72 if mirrored else -0.72
	slash.pivot_offset = slash.size * 0.5
	slash.scale = Vector2(0.25, 0.25)
	slash.z_index = 11
	slash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combat_stage.add_child(slash)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(slash, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(slash, "modulate:a", 0.0, 0.24).set_delay(0.08)
	tween.chain().tween_callback(slash.queue_free)
	_impact_flash.color = Color(0.45, 1.0, 0.96, 0.18) if is_skill else Color(1.0, 0.86, 0.62, 0.11)
	_impact_flash.modulate.a = 1.0
	var flash_tween := create_tween()
	flash_tween.tween_property(_impact_flash, "modulate:a", 0.0, 0.2)


func _flash_actor(actor: TextureRect, color: Color) -> void:
	actor.modulate = color
	var tween := create_tween()
	var resting_color := Color("ca8cff") if actor == _enemy_art else Color.WHITE
	tween.tween_property(actor, "modulate", resting_color, 0.22)


func _shake_panel(strength: float) -> void:
	var home := _battle_panel.position
	var tween := create_tween()
	tween.tween_property(_battle_panel, "position", home + Vector2(strength, -2.0), 0.035)
	tween.tween_property(_battle_panel, "position", home - Vector2(strength * 0.7, -1.0), 0.045)
	tween.tween_property(_battle_panel, "position", home, 0.05)


func _spawn_damage_number(actor: TextureRect, amount: int, color: Color, critical: bool = false) -> void:
	var number := Label.new()
	number.text = "%d%s" % [amount, "!" if critical else ""]
	number.theme = GameState.ui_theme
	number.position = actor.position + actor.size * Vector2(0.5, 0.15)
	number.add_theme_color_override("font_color", color)
	number.add_theme_color_override("font_outline_color", Color("151020"))
	number.add_theme_constant_override("outline_size", 9)
	number.add_theme_font_size_override("font_size", 38 if critical else 31)
	number.z_index = 14
	_combat_stage.add_child(number)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(number, "position:y", number.position.y - 58.0, 0.62).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(number, "modulate:a", 0.0, 0.62).set_delay(0.28)
	tween.chain().tween_callback(number.queue_free)


func _end_battle(victory: bool) -> void:
	_active = false
	_player_turn = false
	_animation_busy = false
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
	_reset_stage_actors()
	GameState.set_mode(GameState.Mode.EXPLORE)
	battle_finished.emit(_victory)


func _reset_stage_actors() -> void:
	if not _homes_initialized:
		return
	_player_art.position = _player_home
	_enemy_art.position = _enemy_home
	_player_art.rotation = 0.0
	_enemy_art.rotation = 0.0
	_player_art.modulate = Color.WHITE
	_enemy_art.modulate = Color("ca8cff")
	_player_shadow.modulate = Color.WHITE
	_enemy_shadow.modulate = Color.WHITE
	_player_shadow.scale = Vector2.ONE
	_enemy_shadow.scale = Vector2.ONE


func _unhandled_input(event: InputEvent) -> void:
	if not _root.visible or event.is_echo():
		return
	if _active and _player_turn and not _animation_busy:
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
	_title_label.text = "BREAK THE NIGHT  /  %s" % _enemy_name
	_enemy_hp_label.text = "%s    %d / %d" % [_enemy_name, _enemy_hp, _enemy_max_hp]
	_enemy_hp_bar.max_value = _enemy_max_hp
	_enemy_hp_bar.value = _enemy_hp
	_player_status_label.text = "旅人    HP %d/%d    MP %d/%d    藥水 × %d" % [
		GameState.player_hp,
		GameState.player_max_hp,
		GameState.player_mp,
		GameState.player_max_mp,
		int(GameState.inventory.get("potion", 0)),
	]
	_player_hp_bar.max_value = GameState.player_max_hp
	_player_hp_bar.value = GameState.player_hp


func _set_actions_enabled(enabled: bool) -> void:
	for button in _action_buttons:
		button.disabled = not enabled


func _make_action_button(text: String, action: String) -> Button:
	var button := Button.new()
	button.text = text.replace("[1] ", "").replace("[2] ", "").replace("[3] ", "").replace("[4] ", "") if MobileControls.is_mobile_device() else text
	button.custom_minimum_size = Vector2(250.0, 72.0 if MobileControls.is_mobile_device() else 52.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 20 if MobileControls.is_mobile_device() else 18)
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
	backdrop.color = Color(0.018, 0.015, 0.05, 0.97)
	_root.add_child(backdrop)

	_battle_panel = PanelContainer.new()
	_battle_panel.anchor_left = 0.5
	_battle_panel.anchor_top = 0.5
	_battle_panel.anchor_right = 0.5
	_battle_panel.anchor_bottom = 0.5
	_battle_panel.offset_left = -550.0
	_battle_panel.offset_top = -338.0 if MobileControls.is_mobile_device() else -300.0
	_battle_panel.offset_right = 550.0
	_battle_panel.offset_bottom = 338.0 if MobileControls.is_mobile_device() else 300.0
	_root.add_child(_battle_panel)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("151326")
	panel_style.border_color = Color("d7a65d")
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(20.0)
	_battle_panel.add_theme_stylebox_override("panel", panel_style)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	_battle_panel.add_child(content)
	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_color_override("font_color", Color("f5c36e"))
	_title_label.add_theme_font_size_override("font_size", 25)
	content.add_child(_title_label)
	_build_combat_stage(content)

	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 28)
	content.add_child(status_row)
	var player_status := VBoxContainer.new()
	player_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_row.add_child(player_status)
	_player_status_label = Label.new()
	_player_status_label.add_theme_color_override("font_color", Color("bde7e5"))
	_player_status_label.add_theme_font_size_override("font_size", 17)
	player_status.add_child(_player_status_label)
	_player_hp_bar = _make_hp_bar(Color("55d6a7"))
	player_status.add_child(_player_hp_bar)
	var enemy_status := VBoxContainer.new()
	enemy_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_row.add_child(enemy_status)
	_enemy_hp_label = Label.new()
	_enemy_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_enemy_hp_label.add_theme_color_override("font_color", Color("f3bdce"))
	_enemy_hp_label.add_theme_font_size_override("font_size", 17)
	enemy_status.add_child(_enemy_hp_label)
	_enemy_hp_bar = _make_hp_bar(Color("e6657d"))
	enemy_status.add_child(_enemy_hp_bar)

	_log_label = Label.new()
	_log_label.custom_minimum_size = Vector2(0.0, 48.0)
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_log_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_log_label.add_theme_color_override("font_color", Color("f4ead6"))
	_log_label.add_theme_font_size_override("font_size", 17)
	content.add_child(_log_label)
	_action_grid = GridContainer.new()
	_action_grid.columns = 2
	_action_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_grid.add_theme_constant_override("h_separation", 10)
	_action_grid.add_theme_constant_override("v_separation", 8)
	content.add_child(_action_grid)
	_action_grid.add_child(_make_action_button("[1] 攻擊", "attack"))
	_action_grid.add_child(_make_action_button("[2] 月影斬  MP 5", "skill"))
	_action_grid.add_child(_make_action_button("[3] 藥水", "potion"))
	_action_grid.add_child(_make_action_button("[4] 防禦", "guard"))
	_continue_button = Button.new()
	_continue_button.custom_minimum_size = Vector2(0.0, 58.0)
	_continue_button.add_theme_font_size_override("font_size", 20)
	_continue_button.pressed.connect(_finish_battle)
	content.add_child(_continue_button)
	_root.visible = false


func _build_combat_stage(parent: VBoxContainer) -> void:
	_combat_stage = Control.new()
	_combat_stage.custom_minimum_size = Vector2(0.0, 280.0)
	_combat_stage.clip_contents = true
	parent.add_child(_combat_stage)
	var sky := ColorRect.new()
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sky.color = Color("292440")
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combat_stage.add_child(sky)
	var moon_glow := Label.new()
	moon_glow.text = "◯"
	moon_glow.position = Vector2(470.0, -72.0)
	moon_glow.add_theme_color_override("font_color", Color(0.65, 0.92, 0.94, 0.24))
	moon_glow.add_theme_font_size_override("font_size", 190)
	_combat_stage.add_child(moon_glow)
	for star_position in [Vector2(90.0, 44.0), Vector2(260.0, 88.0), Vector2(700.0, 52.0), Vector2(915.0, 96.0)]:
		var star := Label.new()
		star.text = "◆"
		star.position = star_position
		star.modulate = Color(0.55, 0.9, 0.94, 0.32)
		star.add_theme_font_size_override("font_size", 14)
		_combat_stage.add_child(star)
	var horizon := ColorRect.new()
	horizon.anchor_top = 0.72
	horizon.anchor_right = 1.0
	horizon.anchor_bottom = 1.0
	horizon.color = Color("332d43")
	horizon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combat_stage.add_child(horizon)
	var ground_line := ColorRect.new()
	ground_line.anchor_top = 0.72
	ground_line.anchor_right = 1.0
	ground_line.offset_top = -2.0
	ground_line.offset_bottom = 2.0
	ground_line.color = Color(0.45, 0.77, 0.75, 0.32)
	ground_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combat_stage.add_child(ground_line)

	_player_shadow = _make_actor_shadow()
	_player_shadow.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	_player_shadow.offset_left = 118.0
	_player_shadow.offset_top = 75.0
	_player_shadow.offset_right = 286.0
	_player_shadow.offset_bottom = 94.0
	_combat_stage.add_child(_player_shadow)
	_enemy_shadow = _make_actor_shadow()
	_enemy_shadow.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	_enemy_shadow.offset_left = -315.0
	_enemy_shadow.offset_top = 75.0
	_enemy_shadow.offset_right = -127.0
	_enemy_shadow.offset_bottom = 94.0
	_combat_stage.add_child(_enemy_shadow)

	_player_art = TextureRect.new()
	_player_art.texture = load("res://assets/characters/wanderer.svg") as Texture2D
	_player_art.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	_player_art.offset_left = 145.0
	_player_art.offset_top = -105.0
	_player_art.offset_right = 257.0
	_player_art.offset_bottom = 76.0
	_player_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_player_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_player_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_player_art.pivot_offset = Vector2(56.0, 90.0)
	_player_art.z_index = 3
	_combat_stage.add_child(_player_art)
	_enemy_art = TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://assets/third_party/ninja_adventure/characters/ninja_blue.png") as Texture2D
	atlas.region = Rect2(0.0, 0.0, 16.0, 16.0)
	_enemy_art.texture = atlas
	_enemy_art.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	_enemy_art.offset_left = -282.0
	_enemy_art.offset_top = -96.0
	_enemy_art.offset_right = -158.0
	_enemy_art.offset_bottom = 76.0
	_enemy_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_enemy_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_enemy_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_enemy_art.flip_h = true
	_enemy_art.modulate = Color("ca8cff")
	_enemy_art.pivot_offset = Vector2(62.0, 86.0)
	_enemy_art.z_index = 3
	_combat_stage.add_child(_enemy_art)

	var player_name := Label.new()
	player_name.text = "旅人"
	player_name.position = Vector2(150.0, 231.0)
	player_name.add_theme_color_override("font_color", Color("a9f3ea"))
	player_name.add_theme_font_size_override("font_size", 16)
	_combat_stage.add_child(player_name)
	var enemy_name := Label.new()
	enemy_name.text = "遺跡守衛"
	enemy_name.position = Vector2(805.0, 231.0)
	enemy_name.add_theme_color_override("font_color", Color("e4b0f5"))
	enemy_name.add_theme_font_size_override("font_size", 16)
	_combat_stage.add_child(enemy_name)
	_impact_flash = ColorRect.new()
	_impact_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_impact_flash.color = Color.TRANSPARENT
	_impact_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_impact_flash.modulate.a = 0.0
	_impact_flash.z_index = 10
	_combat_stage.add_child(_impact_flash)


func _make_actor_shadow() -> Panel:
	var shadow := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.015, 0.05, 0.46)
	style.set_corner_radius_all(40)
	shadow.add_theme_stylebox_override("panel", style)
	shadow.pivot_offset = Vector2(84.0, 9.5)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return shadow


func _make_hp_bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0.0, 12.0)
	bar.show_percentage = false
	var background := StyleBoxFlat.new()
	background.bg_color = Color("332d43")
	background.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("background", background)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("fill", fill)
	return bar
