class_name MapUI
extends CanvasLayer
## Read-only regional map. Gameplay state and objective positions remain authoritative.

const MapControl = preload("res://scripts/ui/mini_map.gd")
const Houses = preload("res://scripts/gameplay/house_catalog.gd")

var source_map: MiniMap
var map_view: MiniMap
var open_button: Button
var _close_button: Button
var _routes: Label
var _previous_focus: Control


func _ready() -> void:
	layer = 76
	_build_ui()
	hide()
	GameState.state_changed.connect(_sync_mode)


func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("map_menu"):
		if visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	if GameState.is_input_locked() or not is_instance_valid(source_map):
		return
	_previous_focus = get_viewport().gui_get_focus_owner()
	map_view.copy_state_from(source_map)
	_routes.text = _route_description(GameState.current_map)
	show()
	GameState.set_mode(GameState.Mode.MAP)
	_close_button.grab_focus()


func close() -> void:
	if not visible:
		return
	hide()
	if GameState.mode == GameState.Mode.MAP:
		GameState.set_mode(GameState.Mode.EXPLORE)
	if is_instance_valid(_previous_focus) and _previous_focus.is_visible_in_tree():
		_previous_focus.grab_focus()
	else:
		_close_button.release_focus()


func _sync_mode() -> void:
	if is_instance_valid(open_button):
		open_button.disabled = GameState.mode != GameState.Mode.EXPLORE
	if visible and GameState.mode != GameState.Mode.MAP:
		hide()


func _route_description(map_id: String) -> String:
	match map_id:
		"village":
			var gate: String = "北門需先與長老交談取得月印。"
			if GameState.quest_state != GameState.QuestState.NOT_STARTED:
				gate = "北門已開啟。"
			return "北 → 北境遺跡　｜　東 → 東行舊道\n" + gate + "房屋門口按 Space／Enter 進入。"
		"ruins":
			return "南 → 暮光村\n沿中央道路探索；金色驚嘆號指向目前主線目標。"
		"east_road":
			return "西 → 暮光村　｜　北 → 螢光森林\n沿道路穿過出口，即可前往下一區域。"
		"firefly_forest":
			return "南 → 東行舊道\n青藍色驚嘆號標示目前的可選事件。"
	if Houses.is_interior(map_id):
		return "南側出口 → 暮光村\n靠近門口按 Space／Enter，返回這棟房屋外。"
	return "沿道路探索目前區域。"


func _build_ui() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.018, 0.023, 0.045, 0.96)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.theme = GameState.ui_theme
	shade.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "區域地圖　／　北方朝上"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("ffe29a"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_close_button = Button.new()
	_close_button.text = "關閉  G / Esc"
	_close_button.custom_minimum_size = Vector2(168, 48)
	_close_button.pressed.connect(close)
	header.add_child(_close_button)
	# Keep keyboard focus inside the modal, including reverse Tab navigation.
	_close_button.focus_next = _close_button.get_path()
	_close_button.focus_previous = _close_button.get_path()
	map_view = MapControl.new()
	map_view.north_up = true
	map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(map_view)
	var legend := HFlowContainer.new()
	legend.add_theme_constant_override("h_separation", 24)
	column.add_child(legend)
	for item: Array in [["▲ 你的位置", MiniMap.PLAYER_COLOR], ["◇ / ● 區域出口", MiniMap.EXIT_COLOR], ["! 主線目標", MiniMap.MAIN_TARGET_COLOR], ["! 可選事件", MiniMap.OPTIONAL_TARGET_COLOR]]:
		var label := Label.new()
		label.text = item[0]
		label.add_theme_color_override("font_color", item[1])
		legend.add_child(label)
	_routes = Label.new()
	_routes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_routes.add_theme_color_override("font_color", Color("d2c8bd"))
	column.add_child(_routes)
