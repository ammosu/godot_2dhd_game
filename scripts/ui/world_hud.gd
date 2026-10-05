class_name WorldHud
extends CanvasLayer
## Exploration HUD: location title, travel hints, compact status card, mini-map
## and interaction prompt. Notices queue while dialogue is open; the owner
## adds `notices` beside this layer.

signal destination_selected(point: Dictionary)

const Presentation = preload("res://scripts/ui/presentation_theme.gd")
const MiniMapControl = preload("res://scripts/ui/mini_map.gd")
const Outskirts = preload("res://scripts/gameplay/outskirts.gd")
const CryptLayout = preload("res://scripts/gameplay/crypt_layout.gd")
const HouseCatalog = preload("res://scripts/gameplay/house_catalog.gd")
const QUEST_FONT_SIZE: int = 15
const MAX_QUEST_PANEL_WIDTH: float = 420.0

var map_label: Label
var quest_label: Label
var prompt_label: Label
var notice_label: Label
var mini_map: MiniMapControl
var map_button: Button
var player_status: PanelContainer
var notices: CanvasLayer
var _quest_panel: PanelContainer
var _quest_row: HBoxContainer
var _quest_marker: Label
var _quest_flash: Tween
var _travel_hints: PanelContainer
var _story_focus: bool = false
var _field_combat_active: bool = false
var _dialogue_open: bool = false
const COMBAT_NOTICE_TTL_MS: int = 8000
const RESULT_NOTICE_TTL_MS: int = 6000
var _active_notice: Dictionary = {}
var _notice_queue: Array[Dictionary] = []
var _notice_seen: Dictionary = {}
var _notice_remaining: float = 0.0
var _notice_banner: PanelContainer
var _notice_tween: Tween
var _prompt_pill: PanelContainer
var _prompt_key: Label
var _prompt_action: Label


func _init() -> void:
	name = "HUD"
	layer = 30


func _ready() -> void:
	add_to_group("world_hud")
	_quest_panel = PanelContainer.new()
	_quest_panel.position = Vector2(24.0, 24.0)
	_quest_panel.name = "QuestPanel"
	_quest_panel.theme = GameState.ui_theme
	add_child(_quest_panel)
	var location_style := Presentation.panel(10)
	location_style.bg_color = Color(0.035, 0.065, 0.10, 0.64)
	location_style.set_border_width_all(0)
	location_style.shadow_size = 0
	location_style.set_corner_radius_all(4)
	_quest_panel.add_theme_stylebox_override("panel", location_style)
	var info := VBoxContainer.new()
	_quest_panel.add_child(info)
	map_label = Label.new()
	map_label.add_theme_font_size_override("font_size", 19)
	map_label.add_theme_color_override("font_color", Presentation.PAPER)
	map_label.clip_text = true
	map_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(map_label)
	# One compact objective line; hidden while any combat HUD is on screen.
	_quest_row = HBoxContainer.new()
	_quest_row.name = "Objective"
	_quest_row.add_theme_constant_override("separation", 6)
	info.add_child(_quest_row)
	_quest_marker = Label.new()
	_quest_marker.add_theme_font_size_override("font_size", 13)
	_quest_marker.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_quest_row.add_child(_quest_marker)
	quest_label = Label.new()
	quest_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quest_label.clip_text = true
	quest_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	quest_label.add_theme_font_size_override("font_size", QUEST_FONT_SIZE)
	quest_label.add_theme_color_override("font_color", Color("e6dcc4"))
	_quest_row.add_child(quest_label)
	_travel_hints = PanelContainer.new()
	_travel_hints.name = "TravelHints"
	_travel_hints.theme = GameState.ui_theme
	_travel_hints.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_travel_hints.offset_left = 24
	_travel_hints.offset_top = -64
	_travel_hints.offset_right = 24
	_travel_hints.offset_bottom = -24
	_travel_hints.add_theme_stylebox_override("panel", Presentation.panel(10))
	add_child(_travel_hints)
	var shortcuts := HBoxContainer.new()
	shortcuts.add_theme_constant_override("separation", 12)
	_travel_hints.add_child(shortcuts)
	for shortcut: Array in [["WASD", "移動"], ["Space", "互動"], ["Q/E", "鏡頭"], ["G", "地圖"], ["I", "裝備"], ["F5", "存檔"], ["F9", "讀檔"]]:
		var key := Label.new()
		key.text = shortcut[0]
		key.custom_minimum_size.x = 26
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key.add_theme_color_override("font_color", Presentation.GOLD)
		var key_style := Presentation.panel(4)
		key_style.set_corner_radius_all(3)
		key_style.shadow_size = 0
		key.add_theme_stylebox_override("normal", key_style)
		shortcuts.add_child(key)
		var action := Label.new()
		action.text = shortcut[1]
		action.add_theme_color_override("font_color", Presentation.PAPER)
		shortcuts.add_child(action)

	player_status = preload("res://scripts/ui/party_status_card.gd").new()
	player_status.name = "PlayerStatus"
	player_status.compact = true
	player_status.theme = GameState.ui_theme
	add_child(player_status)
	player_status.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	player_status.offset_left = -250
	player_status.offset_right = -24
	player_status.offset_top = 8 if MobileControls.is_mobile_device() else 24
	player_status.offset_bottom = player_status.offset_top + 54

	mini_map = MiniMapControl.new()
	mini_map.name = "MiniMap"
	mini_map.anchor_left = 1.0
	mini_map.anchor_right = 1.0
	mini_map.offset_left = -194.0 if MobileControls.is_mobile_device() else -250.0
	mini_map.offset_right = -24.0
	mini_map.offset_top = 146.0 if MobileControls.is_mobile_device() else 90.0
	mini_map.offset_bottom = mini_map.offset_top + (170.0 if MobileControls.is_mobile_device() else 226.0)
	mini_map.theme = GameState.ui_theme
	add_child(mini_map)
	mini_map.destination_selected.connect(destination_selected.emit)
	map_button = Button.new()
	map_button.name = "OpenMap"
	map_button.focus_mode = Control.FOCUS_NONE
	map_button.tooltip_text = "開啟區域地圖 [G]"
	map_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for style: String in ["normal", "hover", "pressed", "disabled"]:
		map_button.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	mini_map.add_child(map_button)
	map_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# `prompt_label` is the positioned slot the field HUD reserves space for;
	# the visible pill (key cap + action) is centred inside it.
	prompt_label = Label.new()
	prompt_label.name = "InteractionPrompt"
	prompt_label.anchor_left = 0.5
	prompt_label.anchor_top = 1.0
	prompt_label.anchor_right = 0.5
	prompt_label.anchor_bottom = 1.0
	prompt_label.offset_left = -260.0
	prompt_label.offset_top = -72.0 if MobileControls.is_mobile_device() else -120.0
	prompt_label.offset_right = 260.0
	prompt_label.offset_bottom = -26.0 if MobileControls.is_mobile_device() else -74.0
	prompt_label.theme = GameState.ui_theme
	add_child(prompt_label)
	var prompt_center := CenterContainer.new()
	prompt_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	prompt_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_label.add_child(prompt_center)
	_prompt_pill = PanelContainer.new()
	_prompt_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pill_style := Presentation.panel(0)
	pill_style.bg_color = Color(0.035, 0.065, 0.10, 0.82)
	pill_style.set_corner_radius_all(20)
	pill_style.content_margin_left = 8
	pill_style.content_margin_right = 18
	pill_style.content_margin_top = 5
	pill_style.content_margin_bottom = 5
	_prompt_pill.add_theme_stylebox_override("panel", pill_style)
	prompt_center.add_child(_prompt_pill)
	var prompt_row := HBoxContainer.new()
	prompt_row.add_theme_constant_override("separation", 10)
	_prompt_pill.add_child(prompt_row)
	_prompt_key = Label.new()
	_prompt_key.text = "互動" if MobileControls.is_mobile_device() else "Space"
	_prompt_key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_key.add_theme_font_size_override("font_size", 14)
	_prompt_key.add_theme_color_override("font_color", Color("241a0c"))
	var key_style := StyleBoxFlat.new()
	key_style.bg_color = Color("e2c07e")
	key_style.border_color = Color("fff0c8")
	key_style.border_width_top = 1
	key_style.border_width_bottom = 3
	key_style.border_color = Color("8a6a36")
	key_style.set_corner_radius_all(14)
	key_style.content_margin_left = 12
	key_style.content_margin_right = 12
	key_style.content_margin_top = 2
	key_style.content_margin_bottom = 2
	_prompt_key.add_theme_stylebox_override("normal", key_style)
	prompt_row.add_child(_prompt_key)
	_prompt_action = Label.new()
	_prompt_action.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_action.add_theme_font_size_override("font_size", 19)
	_prompt_action.add_theme_color_override("font_color", Color("ffe7a8"))
	prompt_row.add_child(_prompt_action)
	_prompt_pill.hide()

	# Notifications must remain legible over dialogue and battle layers.
	notices = CanvasLayer.new()
	notices.name = "Notices"
	notices.layer = 90
	var notice_center := CenterContainer.new()
	notice_center.anchor_right = 1.0
	notice_center.anchor_top = 0.2
	notice_center.anchor_bottom = 0.2
	notice_center.offset_bottom = 56.0
	notice_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notices.add_child(notice_center)
	_notice_banner = PanelContainer.new()
	_notice_banner.name = "NoticeBanner"
	_notice_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice_banner.theme = GameState.ui_theme
	var banner := StyleBoxFlat.new()
	banner.bg_color = Color(0.035, 0.065, 0.10, 0.84)
	banner.border_color = Presentation.GOLD
	banner.border_width_top = 1
	banner.border_width_bottom = 1
	banner.content_margin_left = 36
	banner.content_margin_right = 36
	banner.content_margin_top = 8
	banner.content_margin_bottom = 9
	_notice_banner.add_theme_stylebox_override("panel", banner)
	notice_center.add_child(_notice_banner)
	notice_label = Label.new()
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.add_theme_color_override("font_color", Color("9ef4df"))
	notice_label.add_theme_font_size_override("font_size", 20)
	notice_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice_banner.add_child(notice_label)
	_notice_banner.modulate.a = 0.0
	_notice_banner.hide()
	for control: Node in get_children():
		if control is Control and control != prompt_label:
			control.add_to_group("camera_touch_blocker")


func layout(field_combat_active: bool) -> void:
	var mobile: bool = MobileControls.is_mobile_device()
	var available: float = get_viewport().get_visible_rect().size.x - (352.0 if mobile else 298.0)
	var font: Font = map_label.get_theme_font("font")
	var title_width: float = font.get_string_size(map_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x + 20.0
	var cap: float = 300.0
	if quest_label.visible:
		title_width = maxf(title_width, font.get_string_size(quest_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, QUEST_FONT_SIZE).x + 40.0)
		cap = MAX_QUEST_PANEL_WIDTH
	_quest_panel.custom_minimum_size.x = minf(title_width, minf(cap, maxf(100.0, available)))
	var marker_width: float = _quest_marker.get_minimum_size().x + float(_quest_row.get_theme_constant("separation"))
	quest_label.custom_minimum_size.x = maxf(40.0, _quest_panel.custom_minimum_size.x - 20.0 - marker_width)
	_quest_panel.size.x = _quest_panel.custom_minimum_size.x
	_quest_panel.reset_size()
	_travel_hints.visible = not _story_focus and not mobile and GameState.mode == GameState.Mode.EXPLORE and not field_combat_active


## `field_panel_top` is the field combat panel's top edge in viewport pixels, or NAN without one.
func layout_interaction_prompt(field_panel_top: float) -> void:
	var bottom: float = -26.0 if MobileControls.is_mobile_device() else -74.0
	if not is_nan(field_panel_top):
		# Field combat shares EXPLORE mode; reserve its actual container height,
		# including font, cooldown text and compact dungeon layout changes.
		bottom = field_panel_top - get_viewport().get_visible_rect().size.y - 12.0
	prompt_label.offset_top = bottom - 46.0
	prompt_label.offset_bottom = bottom


func set_prompt(prompt: String) -> void:
	var player := get_parent().get_node_or_null("Player")
	if player != null and is_instance_valid(player.field_combat) and player.field_combat.has_nearby_enemy(7.0):
		var target: Interactable3D = player.get_nearest_interactable()
		if target != null and target.low_priority:
			prompt = ""
	if prompt == _prompt_action.text and _prompt_pill.visible == not prompt.is_empty():
		return
	_prompt_action.text = prompt
	_prompt_pill.visible = not prompt.is_empty()


func refresh(field_combat_active: bool) -> void:
	_field_combat_active = field_combat_active
	var fighting: bool = GameState.mode == GameState.Mode.BATTLE
	mini_map.visible = not fighting and not _story_focus and not _dialogue_open
	player_status.visible = not fighting and not _story_focus and not _dialogue_open
	_quest_panel.visible = not _story_focus and (not fighting or not MobileControls.is_mobile_device())
	_update_mini_map_targets()
	map_label.text = _map_title(GameState.current_map)
	_show_objective(GameState.get_quest_text(), not fighting and not field_combat_active)
	_quest_panel.tooltip_text = map_label.text + "\n" + quest_label.text
	layout(field_combat_active)
	player_status.display_actor({
		"art": "wanderer", "hero_class": GameState.player_class,
		"hero_body": GameState.player_body, "hero_style": GameState.player_style,
		"name": "Lv.%d" % GameState.player_level, "hp": GameState.player_hp,
		"max_hp": GameState.player_max_hp, "mp": GameState.player_mp,
		"max_mp": GameState.player_max_mp, "ward": 0.0,
	}, false)
	player_status.tooltip_text = "Lv.%d · EXP %d / %d · 月苔 ×%d" % [GameState.player_level, GameState.player_xp, GameState.xp_to_next_level(), int(GameState.inventory.get("moon_moss", 0))]


func _show_objective(raw: String, allowed: bool) -> void:
	var main: bool = raw.begins_with("主線")
	var text: String = raw.trim_prefix("主線：").strip_edges()
	var changed: bool = not quest_label.text.is_empty() and text != quest_label.text
	quest_label.text = text
	_quest_marker.text = "◆" if main else "◇"
	_quest_marker.add_theme_color_override("font_color", Color("ffd45c") if main else Color("64e6ff"))
	quest_label.visible = allowed and not text.is_empty()
	_quest_row.visible = quest_label.visible
	if changed and quest_label.visible:
		# A brief warm glow tells the player the objective just moved on.
		if _quest_flash != null:
			_quest_flash.kill()
		_quest_row.modulate = Color(1.6, 1.4, 0.9)
		_quest_flash = create_tween()
		_quest_flash.tween_property(_quest_row, "modulate", Color.WHITE, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func set_story_focus(enabled: bool) -> void:
	_story_focus = enabled
	refresh(_field_combat_active)

func set_dialogue_open(enabled: bool) -> void:
	_dialogue_open = enabled
	refresh(_field_combat_active)
	if enabled:
		var now: int = Time.get_ticks_msec()
		_notice_queue = _notice_queue.filter(func(entry: Dictionary) -> bool:
			return entry.kind != "navigation" or now - int(entry.time) >= 2000
		)
		if _notice_remaining > 0.0 and _active_notice.get("kind", "") == "navigation" and now - int(_active_notice.time) >= 2000:
			_notice_queue.push_front(_active_notice.duplicate())
		_active_notice.clear()
		if _notice_tween != null:
			_notice_tween.kill()
		notice_label.text = ""
		_notice_remaining = 0.0
		_notice_banner.hide()

## Only older arrivals survive dialogue; automatic arrival scenes dismiss fresh ones.
func _notice_kind(message: String) -> String:
	if message.begins_with("抵達・"):
		return "navigation"
	if message.begins_with("獲得："):
		return "item"
	if message.begins_with("諾亞・") or message.begins_with("希雅・"):
		return "tutorial"
	if message.begins_with("經驗") or message.begins_with("拾取") or message.begins_with("影襲需要"):
		return "combat"
	return "result"


func _notice_engaged() -> bool:
	var player := get_parent().get_node_or_null("Player")
	return GameState.mode == GameState.Mode.BATTLE or (player != null and is_instance_valid(player.field_combat) and player.field_combat.is_engaged())


func _prune_notices(now: int) -> void:
	var engaged: bool = _notice_engaged()
	_notice_queue = _notice_queue.filter(func(entry: Dictionary) -> bool:
		if entry.kind == "navigation":
			return true
		if entry.kind in ["item", "result"]:
			return entry.map == GameState.current_map and now - int(entry.time) <= RESULT_NOTICE_TTL_MS and not engaged
		return entry.map == GameState.current_map and now - int(entry.time) <= COMBAT_NOTICE_TTL_MS and (entry.kind != "tutorial" or engaged)
	)


func show_notice(message: String) -> void:
	if message.is_empty():
		return
	var now: int = Time.get_ticks_msec()
	_prune_notices(now)
	var kind: String = _notice_kind(message)
	if kind == "navigation":
		# Arrival signals can follow the automatic dialogue signal in the same frame.
		if _dialogue_open or GameState.mode == GameState.Mode.DIALOGUE:
			return
		# Each arrival is a new navigation event, even when revisiting a map.
		_notice_queue.push_front({"message": message, "kind": kind, "time": now, "map": GameState.current_map})
		_notice_remaining = 0.0
		return
	if kind == "tutorial" and not _notice_engaged():
		return
	# Rewards may recur in a later fight, but duplicate signals and interrupted
	# banners must not replay. Story results are unique for this HUD's lifetime.
	if _notice_seen.has(message) and (kind not in ["combat"] or now - int(_notice_seen[message]) <= COMBAT_NOTICE_TTL_MS):
		return
	_notice_seen[message] = now
	if kind == "item" and not _notice_queue.is_empty() and _notice_queue.back().kind == "item":
		_notice_queue.back().message += "、" + message.trim_prefix("獲得：")
	else:
		_notice_queue.append({"message": message, "kind": kind, "time": now, "map": GameState.current_map})
	# Consume on the next frame so consecutive item signals form one banner.


func _process(delta: float) -> void:
	_prune_notices(Time.get_ticks_msec())
	if not _active_notice.is_empty() and _active_notice.kind != "navigation":
		if _active_notice.map != GameState.current_map or (_notice_engaged() and _active_notice.kind in ["item", "result"]):
			_notice_remaining = 0.0
			_active_notice.clear()
	if _notice_engaged() and _notice_remaining > 0.0 and _active_notice.get("kind", "") == "navigation" and _notice_queue.any(func(entry: Dictionary) -> bool: return entry.kind in ["combat", "tutorial"]):
		_notice_queue.push_front(_active_notice.duplicate())
		_notice_remaining = 0.0
		_active_notice.clear()
	if _dialogue_open or _story_focus or GameState.mode in [GameState.Mode.DIALOGUE, GameState.Mode.CUTSCENE]:
		return
	_notice_remaining = maxf(0.0, _notice_remaining - delta)
	if _notice_remaining > 0.0:
		return
	if _notice_queue.is_empty():
		notice_label.text = ""
		_notice_banner.hide()
		return
	if _notice_tween != null:
		_notice_tween.kill()
	# Battle information takes priority while engaged; arrivals keep their queue.
	var preferred := PackedStringArray(["combat", "tutorial"] if _notice_engaged() else ["navigation", "item", "result"])
	var next: int = 0
	for index: int in range(_notice_queue.size()):
		if _notice_queue[index].kind in preferred:
			next = index
			break
	_active_notice = _notice_queue[next].duplicate()
	notice_label.text = str(_active_notice.message)
	_notice_queue.remove_at(next)
	_notice_banner.show()
	_notice_banner.reset_size()
	_notice_banner.modulate.a = 0.0
	_notice_tween = create_tween()
	_notice_tween.tween_property(_notice_banner, "modulate:a", 1.0, 0.18)
	_notice_tween.tween_interval(2.6)
	_notice_tween.tween_property(_notice_banner, "modulate:a", 0.0, 0.35)
	_notice_remaining = 3.13


func _map_title(map_id: String) -> String:
	if HouseCatalog.is_interior(map_id):
		return str(HouseCatalog.find_home(map_id).name)
	if CryptLayout.NAMES.has(map_id):
		return CryptLayout.NAMES[map_id]
	if Outskirts.NAMES.has(map_id):
		return str(Outskirts.NAMES[map_id])
	return "北境遺跡" if map_id == "ruins" else "暮光村"


func _update_mini_map_targets() -> void:
	mini_map.set_map(GameState.current_map)
	var main_target_position := Vector3.ZERO
	var main_target_visible := false
	var optional_target_position := Vector3.ZERO
	var optional_target_visible := false
	if GameState.current_map == "village":
		match GameState.quest_state:
			GameState.QuestState.NOT_STARTED, GameState.QuestState.READY_TO_TURN_IN:
				main_target_position = Vector3(-3.0, 0.0, 1.2)
				main_target_visible = true
			GameState.QuestState.ACTIVE:
				main_target_position = Vector3(0.0, 0.0, -19.3)
				main_target_visible = true
		optional_target_position = Vector3(6.4, 0.0, 4.2)
		optional_target_visible = not bool(GameState.flags.get("rumi_tip_seen", false))
	elif CryptLayout.is_floor(GameState.current_map):
		main_target_position = Vector3(0, 0, 11.8)
		main_target_visible = true
	elif GameState.current_map == "ashen_crypt":
		optional_target_position = Vector3(0, 0, -9)
		optional_target_visible = not bool(GameState.flags.get("crypt_cleared", false))
	elif HouseCatalog.is_interior(GameState.current_map):
		main_target_position = Vector3(0, 0, 2.95)
		main_target_visible = true
	elif Outskirts.NAMES.has(GameState.current_map):
		for id: String in Outskirts.EVENTS:
			var event: Array = Outskirts.EVENTS[id]
			if event[0] == GameState.current_map and not bool(GameState.flags.get(id, false)):
				optional_target_position = event[1]
				optional_target_visible = true
				break
	elif GameState.quest_state == GameState.QuestState.ACTIVE:
		main_target_position = Vector3(0.0, 0.0, -8.2)
		main_target_visible = not bool(GameState.flags.get("guardian_defeated", false))
	elif GameState.quest_state == GameState.QuestState.READY_TO_TURN_IN:
		main_target_position = Vector3(0.0, 0.0, 15.1)
		main_target_visible = true
	mini_map.set_main_target(main_target_position, main_target_visible)
	mini_map.set_optional_target(optional_target_position, optional_target_visible)
