class_name ActionBattleUI
extends CanvasLayer

signal battle_finished(victory: bool)
const Encounter = preload("res://scripts/gameplay/world_action_battle.gd")
const RadialDock = preload("res://scripts/ui/battle_radial_dock.gd")
const ControlLayout = preload("res://scripts/systems/battle_control_layout.gd")
const LayoutSettings = preload("res://scripts/ui/battle_layout_settings.gd")
const StatusCard = preload("res://scripts/ui/party_status_card.gd")
const Preparation = preload("res://scripts/ui/battle_preparation.gd")
var _preparation: AcceptDialog
var _preparing: bool = false
var _preparation_shade: ColorRect
var session: RefCounted
var _root: Control
var encounter: Node3D
var _map: Node3D
var _player: CharacterBody3D
var _rig: Node3D
var _guardian: Node3D
var reward_position := Vector3.ZERO
var _result_time: float = 0.0
var _status: Label
var _hint: Label
var _boss: ProgressBar
var _boss_name: Label
var _pause: Button
var _auto_button: Button
var _buttons: Dictionary = {}
var _resolved: bool = false
var _touch_move := Vector2.ZERO
var _party_rows: Array[PanelContainer] = []
var _control_layout := ControlLayout.new()
var _skill_dock: Control
var _layout_editor: ConfirmationDialog
var _layout_button: Button
var _settings_was_paused: bool = false

func _ready() -> void:
	layer = 70
	_control_layout.load_preferences()
	_build()
	_root.hide()
	_preparation_shade = ColorRect.new()
	_preparation_shade.color = Color(0.02, 0.03, 0.06, 0.55)
	_preparation_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_preparation_shade)
	_preparation_shade.hide()
	_preparation = Preparation.new()
	_preparation.theme = GameState.ui_theme
	add_child(_preparation)
	_preparation.options_confirmed.connect(confirm_preparation)
	_layout_editor = LayoutSettings.new()
	_layout_editor.theme = GameState.ui_theme
	add_child(_layout_editor)
	_layout_editor.layout_saved.connect(func(layout: Dictionary) -> void: _skill_dock.apply_layout(layout))
	_layout_editor.visibility_changed.connect(_layout_visibility_changed)
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
	session.paused = true
	_preparing = true
	_preparation_shade.show()
	_preparation.open_choices()
	_hint.text = _manual_hint()
	_refresh()

func confirm_preparation(options: Dictionary = {}) -> void:
	if not _preparing:
		return
	session.configure_automation(options)
	_preparing = false
	_preparation.hide()
	_preparation_shade.hide()
	session.paused = false
	_hint.text = _auto_description() if session.auto_enabled else _manual_hint()
	_refresh()

func _manual_hint() -> String:
	return "左側搖桿移動 · 圓形圖示出招 · 空白處左右滑動轉鏡頭" if MobileControls.is_mobile_device() else "WASD 移動 · J 攻擊 · K 技能 · 空白 閃避 · Tab 換人 · Q/E 鏡頭"

func _auto_description() -> String:
	return "自動：技能%s · 喝藥%s。移動或出招即可接手。" % ["開" if session.auto_use_skills else "關", "HP ≤ %d%%" % roundi(session.auto_potion_threshold * 100.0) if session.auto_use_potions else "關"]

func is_active() -> bool:
	return _root != null and _root.visible

func is_resolved() -> bool:
	return is_active() and _resolved

func did_player_win() -> bool:
	return session != null and int(session.winner) == 0

func can_accept_action() -> bool:
	return is_active() and not _preparing and not _layout_editor.visible and not _resolved and not session.paused

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
	GameState.advance_action_battle(delta, movement)
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
	if not is_active() or _resolved or _preparing or _layout_editor.visible:
		return
	session.set_auto_enabled(not bool(session.auto_enabled))
	_hint.text = _auto_description() if session.auto_enabled else "已切回手動操作。B 可再次開啟自動戰鬥。"
	_refresh()

func _toggle_pause() -> void:
	if not is_active() or _resolved or _preparing or _layout_editor.visible:
		return
	session.paused = not bool(session.paused)
	_touch_move = Vector2.ZERO
	_refresh()

func _lost_focus() -> void:
	# Opening the modal transfers window focus; combat is already paused there.
	if can_accept_action():
		session.paused = true
		_touch_move = Vector2.ZERO
		_refresh()

func _input(event: InputEvent) -> void:
	if _preparing or _layout_editor.visible:
		return
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
		KEY_O: _open_layout_settings()
		KEY_B: _toggle_auto()
		KEY_J: choose_action("attack")
		KEY_K: choose_action("skill")
		KEY_SPACE: choose_action("dodge")
		KEY_TAB: choose_action("switch")
		KEY_H: choose_action("potion")
		_: return
	get_viewport().set_input_as_handled()

func _press_at(point: Vector2) -> bool:
	if _preparing or _layout_editor.visible:
		return false
	if _layout_button.get_global_rect().has_point(point):
		_open_layout_settings()
		return true
	if _auto_button.get_global_rect().has_point(point):
		_toggle_auto()
		return true
	if _pause.get_global_rect().has_point(point):
		_toggle_pause()
		return true
	for action: String in _buttons:
		var button: Button = _buttons[action]
		if button.contains_screen_point(point):
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
	_status.text = "%s    敵人 %d / 3" % ["已暫停" if session.paused else "戰鬥結束" if _resolved else "自動戰鬥" if session.auto_enabled else "即時戰鬥", session.living(1).size()]
	for index: int in range(_party_rows.size()):
		_party_rows[index].display_actor(session.actors[index], index == int(session.controlled))
	_boss.max_value = session.actors[3].max_hp
	_boss.value = session.actors[3].hp
	_boss_name.text = "遺跡守衛  %d / %d" % [session.actors[3].hp, session.actors[3].max_hp]
	_pause.text = "繼續 [Esc]" if session.paused else "暫停 [Esc]"
	_pause.disabled = _resolved or _preparing
	_auto_button.disabled = _resolved or _preparing
	_auto_button.set_pressed_no_signal(bool(session.auto_enabled))
	_auto_button.text = "自動戰鬥：開 [B]" if session.auto_enabled else "自動戰鬥：關 [B]"
	_layout_button.disabled = _resolved or _preparing
	var skill_name: String = ["月影斬", "守護", "霜星爆"][int(session.controlled)]
	for action: String in _buttons:
		var button: Button = _buttons[action]
		var cooldown: float = float(actor.skill_cd) if action == "skill" else float(actor.dodge_cd) if action == "dodge" else float(actor.cooldown) if action in ["attack", "potion"] else 0.0
		button.caption = skill_name if action == "skill" else RadialDock.CAPTIONS[action]
		button.glyph = ["moon", "ward", "frost"][int(session.controlled)] if action == "skill" else action
		button.cooldown = cooldown
		button.cooldown_fraction = clampf(cooldown / (3.0 if action == "skill" else 1.1 if action == "dodge" else 0.6), 0.0, 1.0)
		button.badge = "×%d" % int(GameState.inventory.get("potion", 0)) if action == "potion" else ""
		button.tooltip_text = "%s [%s]%s" % [button.caption, RadialDock.KEYS[action], " · 消耗 5 MP" if action == "skill" else ""]
		button.disabled = _resolved or bool(session.paused) or cooldown > 0.0 or (action == "skill" and int(actor.mp) < 5) or (action == "potion" and (int(GameState.inventory.get("potion", 0)) <= 0 or int(actor.hp) >= int(actor.max_hp)))
		if button.disabled:
			button.tooltip_text += " · " + ("戰鬥結束" if _resolved else "已暫停" if session.paused else "冷卻 %.1f 秒" % cooldown if cooldown > 0 else "MP 不足" if action == "skill" else "藥水不足或 HP 已滿")
		button.queue_redraw()

func _open_layout_settings() -> void:
	if not is_active() or _preparing or _resolved or _layout_editor.visible:
		return
	_settings_was_paused = bool(session.paused)
	session.paused = true
	_touch_move = Vector2.ZERO
	_refresh()
	_layout_editor.open_layout(_control_layout, int(session.controlled))

func _layout_visibility_changed() -> void:
	if not _layout_editor.visible and is_active() and not _resolved:
		session.paused = _settings_was_paused
		_refresh()

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
	top.name = "PartyStatus"
	_root.add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	top.offset_left = -344
	top.offset_right = -20
	top.offset_top = 20
	top.add_theme_stylebox_override("panel", _hud_style(Color("71859a")))
	var stats := VBoxContainer.new()
	stats.custom_minimum_size.x = 300
	stats.add_theme_constant_override("separation", 5)
	top.add_child(stats)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 16)
	stats.add_child(_status)
	for index: int in range(3):
		var card := StatusCard.new()
		stats.add_child(card)
		_party_rows.append(card)
	_pause = Button.new()
	_pause.position = Vector2(24, 150)
	_pause.size = Vector2(164, 48)
	_pause.pressed.connect(_toggle_pause)
	if MobileControls.is_mobile_device():
		_pause.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_pause)
	_auto_button = Button.new()
	_auto_button.position = Vector2(24, 208)
	_auto_button.size = Vector2(240, 48)
	_auto_button.toggle_mode = true
	_auto_button.focus_mode = Control.FOCUS_NONE
	_auto_button.tooltip_text = "依戰前設定自動追擊、攻擊、技能、閃避與喝藥。移動或出招可立即接手；Tab 只切換跟隨角色。"
	_auto_button.pressed.connect(_toggle_auto)
	if MobileControls.is_mobile_device():
		_auto_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_auto_button)
	_layout_button = Button.new()
	_layout_button.text = "操作配置 [O]"
	_layout_button.position = Vector2(24, 266)
	_layout_button.size = Vector2(164, 48)
	_layout_button.pressed.connect(_open_layout_settings)
	if MobileControls.is_mobile_device():
		_layout_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_layout_button)
	_skill_dock = RadialDock.new()
	_skill_dock.name = "SkillDock"
	_root.add_child(_skill_dock)
	_skill_dock.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_skill_dock.offset_left = -408
	_skill_dock.offset_top = -408
	_skill_dock.offset_right = 0
	_skill_dock.offset_bottom = 0
	_skill_dock.apply_layout(_control_layout.values)
	_skill_dock.action_pressed.connect(choose_action)
	_buttons = _skill_dock.buttons
	_hint = Label.new()
	_root.add_child(_hint)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_left = -290
	_hint.offset_right = 150
	_hint.offset_top = -70
	_hint.offset_bottom = -20
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_constant_override("outline_size", 6)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for control: Control in [top, boss_panel, _pause, _auto_button, _layout_button, _hint]:
		control.add_to_group("camera_touch_blocker")


func _hud_style(border: Color, background: Color = Color(0.035, 0.06, 0.10, 0.9)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.border_width_left = 3
	style.set_corner_radius_all(5)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


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
