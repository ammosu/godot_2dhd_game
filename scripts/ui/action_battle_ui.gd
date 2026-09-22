class_name ActionBattleUI
extends CanvasLayer

signal battle_finished(victory: bool)
const Encounter = preload("res://scripts/gameplay/world_action_battle.gd")
var session: RefCounted
var _root: Control
var encounter: Node3D
var _map: Node3D
var _player: CharacterBody3D
var _rig: Node3D
var _guardian: Node3D
var reward_position := Vector3.ZERO
var _result_time: float = 0.0
var _health: ProgressBar
var _health_text: Label
var _status: Label
var _hint: Label
var _boss: ProgressBar
var _boss_name: Label
var _pause: Button
var _auto_button: Button
var _buttons: Dictionary = {}
var _resolved: bool = false
var _touch_move := Vector2.ZERO

func _ready() -> void:
	layer = 70
	_build()
	_root.hide()
	get_window().focus_exited.connect(_lost_focus)

func configure_world(map: Node3D, player: CharacterBody3D, rig: Node3D, guardian: Node3D) -> void:
	_map = map
	_player = player
	_rig = rig
	_guardian = guardian


func start_battle(enemy: Dictionary) -> void:
	if is_active() or not is_instance_valid(_map):
		return
	session = GameState.begin_action_battle(enemy)
	encounter = Encounter.new()
	encounter.name = "WorldCombat"
	_map.add_child(encounter)
	encounter.setup(session, _player, _rig, _guardian)
	_result_time = 0.0
	_resolved = false
	_touch_move = Vector2.ZERO
	_root.show()
	if "--battle-preview" in OS.get_cmdline_user_args():
		session.paused = true
	_hint.text = "WASD 移動 · J 攻擊 · K 技能 · 空白 閃避 · Tab 換人 · Q/E 鏡頭"
	_refresh()

func is_active() -> bool:
	return _root != null and _root.visible

func is_resolved() -> bool:
	return is_active() and _resolved

func did_player_win() -> bool:
	return session != null and int(session.winner) == 0

func can_accept_action() -> bool:
	return is_active() and not _resolved and not session.paused

func _physics_process(delta: float) -> void:
	if not can_accept_action():
		return
	var movement := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if _touch_move != Vector2.ZERO:
		movement = _touch_move
	if Input.is_physical_key_pressed(KEY_J):
		session.set_auto_enabled(false)
		session.command("attack")
	advance_combat(delta, encounter.input_direction(movement))

func advance_combat(delta: float, movement: Vector2) -> void:
	if not can_accept_action():
		return
	session.step(delta, movement)
	if GameState.player_hp != int(session.actors[0].hp) or GameState.player_mp != int(session.actors[0].mp):
		GameState.sync_party_battle()
	for event: Dictionary in session.events:
		var kind: String = event.kind
		encounter.show_event(event)
		if kind == "swing":
			var index: int = int(event.index)
			var cue: StringName = &"frost_impact" if index == 2 and event.intent == "skill" else &"moon_bolt" if index in [2, 5] else &"moon_slash" if index == 0 and event.intent == "skill" else &"spear_thrust" if index == 1 else &"claw_swipe" if index == 4 else &"slash"
			GameAudio.play_cue(cue)
		else:
			GameAudio.play_cue(&"moon_heal" if kind == "heal" else &"protect" if kind == "ward" else &"impact")
	session.events.clear()
	encounter.refresh(delta)
	if int(session.winner) != -1:
		_resolve_battle()
	_refresh()

func choose_action(action: String) -> void:
	if not can_accept_action():
		return
	if action != "switch":
		session.set_auto_enabled(false)
	if action == "potion":
		if not GameState.use_action_potion():
			_hint.text = "無法使用藥水：請確認庫存、HP 或等待動作結束。"
	elif action == "switch":
		session.switch_actor()
	else:
		if not session.command(action):
			_hint.text = "動作尚未就緒，或 MP 不足。"
	_refresh()

func _toggle_auto() -> void:
	if not is_active() or _resolved:
		return
	session.set_auto_enabled(not bool(session.auto_enabled))
	_hint.text = "自動：追擊、攻擊、技能與閃避；不喝藥。移動或出招即可接手。" if session.auto_enabled else "已切回手動操作。B 可再次開啟自動戰鬥。"
	_refresh()

func _toggle_pause() -> void:
	if not is_active() or _resolved:
		return
	session.paused = not bool(session.paused)
	_touch_move = Vector2.ZERO
	_refresh()

func _lost_focus() -> void:
	if can_accept_action():
		session.paused = true
		_touch_move = Vector2.ZERO
		_refresh()

func _input(event: InputEvent) -> void:
	if is_active() and event is InputEventScreenTouch and event.pressed:
		if _press_at(event.position):
			get_viewport().set_input_as_handled()
		return
	if is_active() and MobileControls.is_mobile_device() and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Touch is handled explicitly, so ignore its emulated mouse duplicate.
		if event.device != -1 and _press_at(event.position):
			get_viewport().set_input_as_handled()
		return
	if not is_active() or not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.physical_keycode
	if _resolved:
		if key == KEY_ENTER:
			_finish_battle()
		return
	match key:
		KEY_ESCAPE: _toggle_pause()
		KEY_B: _toggle_auto()
		KEY_J: choose_action("attack")
		KEY_K: choose_action("skill")
		KEY_SPACE: choose_action("dodge")
		KEY_TAB: choose_action("switch")
		KEY_H: choose_action("potion")
		_: return
	get_viewport().set_input_as_handled()

func _press_at(point: Vector2) -> bool:
	if _auto_button.get_global_rect().has_point(point):
		_toggle_auto()
		return true
	if _pause.get_global_rect().has_point(point):
		_toggle_pause()
		return true
	for action: String in _buttons:
		var button: Button = _buttons[action]
		if button.get_global_rect().has_point(point):
			if not button.disabled:
				choose_action(action)
			return true
	return false


func _resolve_battle() -> void:
	if _resolved:
		return
	_resolved = true
	GameMusic.resolve_battle()
	GameAudio.play_cue(&"victory" if did_player_win() else &"defeat")
	if did_player_win():
		session.actors[0].hp = maxi(1, int(session.actors[0].hp))
		GameState.sync_party_battle()
		GameState.defeat_guardian()
	_hint.text = "試煉完成，獲得月光碎片。" if did_player_win() else "隊伍全數倒下，返回村莊休整後可再次挑戰。"
	_result_time = 0.0

func _finish_battle() -> void:
	if not is_resolved():
		return
	var victory: bool = did_player_win()
	_root.hide()
	_touch_move = Vector2.ZERO
	reward_position = encounter.reward_position
	encounter.finish()
	encounter.queue_free()
	GameState.set_mode(GameState.Mode.EXPLORE)
	battle_finished.emit(victory)

func _process(delta: float) -> void:
	if is_resolved():
		encounter.advance_effects(delta)
		_result_time += delta
		if _result_time >= 1.2:
			_finish_battle()


func _refresh() -> void:
	if session == null:
		return
	if not session.auto_enabled and _hint.text.begins_with("自動："):
		_hint.text = "已切回手動操作。B 可再次開啟自動戰鬥。"
	var actor: Dictionary = session.actors[int(session.controlled)]
	_status.text = "%s · %s\nMP %d / %d    敵人 %d / 3" % ["已暫停" if session.paused else "戰鬥結束" if _resolved else "自動戰鬥" if session.auto_enabled else "即時戰鬥", actor.name, actor.mp, actor.max_mp, session.living(1).size()]
	_health.max_value = actor.max_hp
	_health.value = actor.hp
	_health_text.text = "HP %d / %d" % [actor.hp, actor.max_hp]
	var fill := _health.get_theme_stylebox("fill") as StyleBoxFlat
	fill.bg_color = Color("ba493f") if _health.ratio <= 0.25 else Color("397e63")
	_boss.max_value = session.actors[3].max_hp
	_boss.value = session.actors[3].hp
	_boss_name.text = "遺跡守衛  %d / %d" % [session.actors[3].hp, session.actors[3].max_hp]
	_pause.text = "繼續 [Esc]" if session.paused else "暫停 [Esc]"
	_pause.disabled = _resolved
	_auto_button.disabled = _resolved
	_auto_button.set_pressed_no_signal(bool(session.auto_enabled))
	_auto_button.text = "自動戰鬥：開 [B]" if session.auto_enabled else "自動戰鬥：關 [B]"
	var names: Dictionary = {"attack": "普攻 [J]", "skill": ["月影斬", "守護", "霜星爆"][int(session.controlled)] + " [K]", "dodge": "閃避 [空白]", "switch": "換人 [Tab]", "potion": "藥水 ×%d [H]" % int(GameState.inventory.get("potion", 0))}
	for action: String in _buttons:
		var button: Button = _buttons[action]
		var cooldown: float = float(actor.skill_cd) if action == "skill" else float(actor.dodge_cd) if action == "dodge" else float(actor.cooldown) if action in ["attack", "potion"] else 0.0
		button.text = names[action] + ("  %.1fs" % cooldown if cooldown > 0.0 else "")
		button.disabled = _resolved or bool(session.paused) or cooldown > 0.0 or (action == "skill" and int(actor.mp) < 5) or (action == "potion" and (int(GameState.inventory.get("potion", 0)) <= 0 or int(actor.hp) >= int(actor.max_hp)))

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.theme = GameState.ui_theme
	add_child(_root)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var boss_panel := VBoxContainer.new()
	_root.add_child(boss_panel)
	boss_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	boss_panel.offset_left = -180
	boss_panel.offset_right = 180
	boss_panel.offset_top = 18
	_boss_name = Label.new()
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name.add_theme_font_size_override("font_size", 18)
	_boss_name.add_theme_constant_override("outline_size", 5)
	boss_panel.add_child(_boss_name)
	_boss = _make_health_bar(Color("ba493f"), 10)
	_boss.custom_minimum_size = Vector2(360, 10)
	_boss.show_percentage = false
	boss_panel.add_child(_boss)
	var top := PanelContainer.new()
	top.position = Vector2(24, 150)
	_root.add_child(top)
	var stats := VBoxContainer.new()
	stats.custom_minimum_size.x = 264
	top.add_child(stats)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 18)
	stats.add_child(_status)
	_health = _make_health_bar(Color("397e63"), 24)
	stats.add_child(_health)
	_health_text = Label.new()
	_health_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_health_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_health_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_health_text.add_theme_font_size_override("font_size", 16)
	_health_text.add_theme_constant_override("outline_size", 4)
	_health_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_health.add_child(_health_text)
	_pause = Button.new()
	_pause.position = Vector2(24, 260)
	_pause.size = Vector2(164, 48)
	_pause.pressed.connect(_toggle_pause)
	if MobileControls.is_mobile_device():
		_pause.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_pause)
	_auto_button = Button.new()
	_auto_button.position = Vector2(24, 320)
	_auto_button.size = Vector2(240, 48)
	_auto_button.toggle_mode = true
	_auto_button.focus_mode = Control.FOCUS_NONE
	_auto_button.tooltip_text = "自動追擊、攻擊、技能與閃避，不消耗藥水。移動或出招可立即接手；Tab 只切換跟隨角色。"
	_auto_button.pressed.connect(_toggle_auto)
	if MobileControls.is_mobile_device():
		_auto_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_auto_button)
	var bottom := VBoxContainer.new()
	_root.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 290 if MobileControls.is_mobile_device() else 220
	bottom.offset_right = -24 if MobileControls.is_mobile_device() else -220
	bottom.offset_top = -115
	bottom.offset_bottom = -18
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_constant_override("outline_size", 6)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom.add_child(_hint)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	bottom.add_child(actions)
	for action: String in ["attack", "skill", "dodge", "switch", "potion"]:
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 56)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		if MobileControls.is_mobile_device():
			button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.pressed.connect(choose_action.bind(action))
		actions.add_child(button)
		_buttons[action] = button


func _make_health_bar(color: Color, height: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = height
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := StyleBoxFlat.new()
	background.bg_color = Color("141e2b")
	background.border_color = Color("9aaeb9")
	background.set_border_width_all(1)
	bar.add_theme_stylebox_override("background", background)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	return bar
