class_name EquipmentUI
extends CanvasLayer

const Portrait = preload("res://scripts/ui/equipment_portrait.gd")
const Appearance = preload("res://scripts/gameplay/equipment_appearance.gd")
const PartyEquipment = preload("res://scripts/systems/party_equipment.gd")
const WalkFrames: SpriteFrames = preload("res://assets/generated/wanderer_frames.tres")
const ItemIcons: Texture2D = preload("res://assets/generated/equipment/equipment_icons.png")
const PartyIcons: Texture2D = preload("res://assets/generated/equipment/party_icons.png")
const ICON_CELLS: Dictionary = {"traveler_blade": Vector2(0, 0), "moonsteel_saber": Vector2(1, 0), "traveler_coat": Vector2(0, 1), "moonward_cloak": Vector2(1, 1)}
const PARTY_ICON_CELLS: Dictionary = {"watch_spear": Vector2(0, 0), "dawn_partisan": Vector2(1, 0), "watch_mail": Vector2(2, 0), "dawn_plate": Vector2(3, 0), "lantern_staff": Vector2(0, 1), "astral_staff": Vector2(1, 1), "sage_robe": Vector2(2, 1), "astral_robe": Vector2(3, 1)}
const GOLD := Color("e6c58b")
const INK := Color("182737")
const MINT := Color("a1e6dd")
const PAPER := Color("f1e8d4")
var pending: Dictionary = {}
var selected_actor: String = "wanderer"
var _drafts: Dictionary = {}
var _actor_buttons: Dictionary[String, Button] = {}
var _direction_buttons: Array[Button] = []
var _actor_note: Label
var _panel: Panel
var _portrait: TextureRect
var _stats_label: Label
var _description_label: Label
var _status: Label
var _confirm: Button
var _pose_picker: OptionButton
var _walk_button: Button
var _buttons: Dictionary[String, Button] = {}
var _pose: String = "walk_down"
var _elapsed: float = 0.0
var _last_frame: int = -1
var _animate: bool = false
var _selected: String = "traveler_blade"


func _ready() -> void:
	layer = 75
	_build_ui()
	visible = false
	GameState.state_changed.connect(_on_state_changed)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("equipment_menu"):
		if visible:
			close()
		elif GameState.mode == GameState.Mode.EXPLORE:
			open()
		else:
			return
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	if GameState.mode != GameState.Mode.EXPLORE:
		return
	_drafts.clear()
	pending = GameState.get_loadout(selected_actor)
	visible = true
	GameState.set_mode(GameState.Mode.EQUIPMENT)
	_refresh()
	_buttons[_selected].grab_focus()


func close() -> void:
	visible = false
	_drafts.clear()
	pending = GameState.get_loadout(selected_actor)
	if GameState.mode == GameState.Mode.EQUIPMENT:
		GameState.set_mode(GameState.Mode.EXPLORE)


func select_actor(actor: String) -> void:
	if actor not in PartyEquipment.ACTORS:
		return
	_drafts[selected_actor] = pending.duplicate(true)
	selected_actor = actor
	pending = Dictionary(_drafts.get(actor, GameState.get_loadout(actor))).duplicate(true)
	_selected = str(pending.weapon)
	_animate = false
	_walk_button.text = "行走"
	_pose = "idle"
	_pose_picker.select(1)
	_refresh()


func select_item(item_id: String) -> void:
	if not visible or not GameState.can_equip(item_id, selected_actor):
		return
	var item := GameState.get_equipment_item(item_id)
	if item.is_empty():
		return
	_selected = item_id
	pending[str(item.slot)] = item_id
	if str(item.slot) == "weapon":
		set_preview_pose("idle")
	_refresh()


func confirm_equipment() -> void:
	if visible and GameState.equip_loadout(pending, selected_actor):
		_drafts[selected_actor] = pending.duplicate(true)
		_refresh()


func _on_state_changed() -> void:
	if visible and GameState.mode != GameState.Mode.EQUIPMENT:
		close()
	elif visible:
		_refresh()


func _process(delta: float) -> void:
	if not visible or not _animate:
		return
	_elapsed += delta
	var frame := int(_elapsed * 5.0) % 4
	if frame != _last_frame:
		_last_frame = frame
		_refresh_portrait()


func set_preview_pose(pose: String) -> void:
	if selected_actor != "wanderer" and pose.begins_with("walk_"):
		return
	_pose = pose
	_pose_picker.select(0 if pose.begins_with("walk_") else Appearance.POSES.find(pose) + 1)
	_refresh_portrait()


func _refresh_portrait() -> void:
	var base: Texture2D
	if _pose.begins_with("walk_"):
		base = WalkFrames.get_frame_texture(StringName(_pose.trim_prefix("walk_")), maxi(_last_frame, 0) if _animate else 0)
	else:
		base = load("res://assets/generated/%s_combat_%s.tres" % [selected_actor, _pose]) as Texture2D
	_portrait.call("dress", base, _pose, pending, selected_actor)
	var ratio := (420.0 if _pose.begins_with("walk_") else 390.0) / base.get_height()
	var shown := _portrait.texture
	var padding: Vector2 = shown.get_meta("canvas_padding", Vector2.ZERO)
	_portrait.size = shown.get_size() * ratio
	_portrait.position = Vector2(600 - _portrait.size.x / 2.0, (107.0 if _pose.begins_with("walk_") else 128.0) - padding.y * ratio)


func _refresh() -> void:
	var current := GameState.get_loadout(selected_actor)
	var before := GameState.equipment_stats(current, selected_actor)
	var after := GameState.equipment_stats(pending, selected_actor)
	_stats_label.text = "攻擊   %d  →  %d   (%+d)      防禦   %d  →  %d   (%+d)" % [before.x, after.x, after.x - before.x, before.y, after.y, after.y - before.y]
	var changed := pending != current
	_confirm.disabled = not changed
	var context := "探索與戰鬥" if selected_actor == "wanderer" else "村莊與戰鬥"
	_status.text = "試穿中 · 確認後套用到%s" % context if changed else "目前穿戴 · %s外觀已同步" % context
	for actor: String in _actor_buttons:
		_actor_buttons[actor].set_pressed_no_signal(actor == selected_actor)
		_actor_buttons[actor].add_theme_stylebox_override("normal", _style(Color("304e59") if actor == selected_actor else Color("203343"), GOLD if actor == selected_actor else Color("48606a")))
	for button: Button in _direction_buttons:
		button.visible = selected_actor == "wanderer"
	_walk_button.visible = selected_actor == "wanderer"
	_actor_note.visible = selected_actor != "wanderer"
	var positions := {"weapon": 0, "armor": 0}
	var selected := GameState.get_equipment_item(_selected)
	_description_label.text = "%s\n%s" % [selected.get("name", ""), selected.get("description", "")]
	for item_id: String in _buttons:
		var item := GameState.get_equipment_item(item_id)
		_buttons[item_id].visible = str(item.get("actor", "wanderer")) == selected_actor
		if not _buttons[item_id].visible:
			continue
		_buttons[item_id].position.y = 181 + int(positions[item.slot]) * 106
		positions[item.slot] = int(positions[item.slot]) + 1
		var active := str(pending.get(str(item.slot), "")) == item_id
		var worn := str(current.get(str(item.slot), "")) == item_id
		var mark := "已穿戴" if worn else "試穿中" if active else "選擇試穿"
		_buttons[item_id].text = "%s\n%s %+d · %s" % [item.name, "攻擊" if item.slot == "weapon" else "防禦", int(item.attack) if item.slot == "weapon" else int(item.defense), mark]
		_buttons[item_id].disabled = item_id not in GameState.owned_equipment
		_buttons[item_id].add_theme_stylebox_override("normal", _style(Color("304e59") if active else Color("203343"), GOLD if active else Color("48606a")))
	_refresh_portrait()


func _layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var factor := minf(viewport_size.x / 1240.0, viewport_size.y / 700.0)
	_panel.scale = Vector2.ONE * factor
	_panel.position = (viewport_size - Vector2(1200, 660) * factor) / 2.0


func _style(color: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_content_margin_all(14)
	return style


func _label(text: String, at: Vector2, font_size: int, color: Color = PAPER) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	_panel.add_child(label)
	return label


func _button(text: String, at: Vector2, dimensions: Vector2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = at
	button.size = dimensions
	button.add_theme_font_size_override("font_size", 19)
	button.add_theme_color_override("font_color", PAPER)
	button.add_theme_stylebox_override("normal", _style(Color("203343"), Color("48606a")))
	button.add_theme_stylebox_override("hover", _style(Color("365761"), GOLD))
	button.add_theme_stylebox_override("pressed", _style(Color("496c73"), GOLD))
	var focus := _style(Color.TRANSPARENT, MINT)
	focus.set_border_width_all(3)
	button.add_theme_stylebox_override("focus", focus)
	button.pressed.connect(callback)
	_panel.add_child(button)
	return button


func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.025, 0.04, 0.07, 0.90)
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = Panel.new()
	_panel.size = Vector2(1200, 660)
	_panel.theme = GameState.ui_theme
	_panel.add_theme_stylebox_override("panel", _style(INK, GOLD))
	add_child(_panel)
	_label("隊伍的行裝", Vector2(32, 22), 32, GOLD).theme_type_variation = &"TitleLabel"
	_label("月光之下，整裝再出發。", Vector2(34, 65), 18, Color("9eafba"))
	for index: int in range(PartyEquipment.ACTORS.size()):
		var actor := PartyEquipment.ACTORS[index]
		var button := _button(str(PartyEquipment.NAMES[actor]), Vector2(371 + index * 152, 27), Vector2(144, 46), select_actor.bind(actor))
		button.toggle_mode = true
		button.add_theme_stylebox_override("pressed", _style(Color("304e59"), GOLD))
		_actor_buttons[actor] = button
	_button("關閉  I / Esc", Vector2(1008, 26), Vector2(160, 48), close)
	_label("武器", Vector2(32, 131), 25, GOLD)
	_label("防具", Vector2(924, 131), 25, GOLD)
	for slot: String in GameState.EQUIPMENT_SLOTS:
		var index := 0
		for item_id: String in GameState.EQUIPMENT_CATALOG:
			if str(GameState.EQUIPMENT_CATALOG[item_id].slot) != slot:
				continue
			var at := Vector2(32 if slot == "weapon" else 924, 181 + index * 106)
			_buttons[item_id] = _button("", at, Vector2(244, 88), select_item.bind(item_id))
			if ICON_CELLS.has(item_id):
				var icon := AtlasTexture.new()
				icon.atlas = ItemIcons
				var cell := ItemIcons.get_size() / 2.0
				icon.region = Rect2(Vector2(ICON_CELLS[item_id]) * cell, cell)
				_buttons[item_id].icon = icon
			elif PARTY_ICON_CELLS.has(item_id):
				var icon := AtlasTexture.new()
				icon.atlas = PartyIcons
				var cell := PartyIcons.get_size() / Vector2(4, 2)
				icon.region = Rect2(Vector2(PARTY_ICON_CELLS[item_id]) * cell, cell)
				_buttons[item_id].icon = icon
			_buttons[item_id].expand_icon = true
			_buttons[item_id].add_theme_constant_override("icon_max_width", 58)
			_buttons[item_id].add_theme_font_size_override("font_size", 16)
			index += 1
	_label("◇ ───────── ◇", Vector2(466, 480), 18, Color("54777d"))
	_portrait = Portrait.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_panel.add_child(_portrait)
	for index: int in range(4):
		var directions: Array[String] = ["down", "left", "up", "right"]
		var labels: Array[String] = ["正面", "左側", "背面", "右側"]
		_direction_buttons.append(_button(labels[index], Vector2(359 + index * 94, 523), Vector2(88, 44), set_preview_pose.bind("walk_" + directions[index])))
	_walk_button = _button("行走", Vector2(735, 523), Vector2(90, 44), _toggle_walk)
	_actor_note = _label("援軍 · 可檢查七種戰鬥姿勢", Vector2(425, 535), 18, MINT)
	_description_label = _label("", Vector2(32, 405), 18, Color("bdcbd0"))
	_description_label.size = Vector2(244, 100)
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var poses := OptionButton.new()
	_pose_picker = poses
	poses.position = Vector2(924, 411)
	poses.size = Vector2(244, 48)
	poses.add_theme_font_size_override("font_size", 19)
	poses.add_item("檢查戰鬥姿勢…")
	poses.set_item_disabled(0, true)
	var labels: Array[String] = ["戰鬥：待機", "戰鬥：蓄力", "戰鬥：攻擊", "戰鬥：收招", "戰鬥：受擊", "戰鬥：防禦", "戰鬥：倒下"]
	for label: String in labels:
		poses.add_item(label)
	poses.item_selected.connect(func(index: int) -> void: set_preview_pose(Appearance.POSES[index - 1]))
	_panel.add_child(poses)
	_status = _label("", Vector2(32, 573), 17, MINT)
	_stats_label = _label("", Vector2(32, 609), 21)
	_confirm = _button("確認穿戴", Vector2(992, 578), Vector2(176, 58), confirm_equipment)
	_button("還原試穿", Vector2(824, 578), Vector2(156, 58), _reset_preview)


func _toggle_walk() -> void:
	_animate = not _animate
	_walk_button.text = "停步" if _animate else "行走"
	if not _pose.begins_with("walk_"):
		set_preview_pose("walk_down")
	_refresh_portrait()


func _reset_preview() -> void:
	pending = GameState.get_loadout(selected_actor)
	_drafts[selected_actor] = pending.duplicate(true)
	_refresh()
