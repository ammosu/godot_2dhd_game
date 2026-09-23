extends Control
signal action_pressed(action: String)
const IconButton = preload("res://scripts/ui/battle_icon_button.gd")
const Layout = preload("res://scripts/systems/battle_control_layout.gd")
const CAPTIONS: Dictionary = {"attack": "普攻", "skill": "月影斬", "dodge": "閃避", "switch": "換人", "potion": "藥水"}
const KEYS: Dictionary = {"attack": "J", "skill": "K", "dodge": "Space", "switch": "Tab", "potion": "H"}
var buttons: Dictionary = {}
var layout: Dictionary = Layout.DEFAULTS.duplicate(true)
var preview: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for action: String in CAPTIONS:
		var button := IconButton.new()
		button.name = action.capitalize()
		button.caption = CAPTIONS[action]
		button.hotkey = KEYS[action]
		button.glyph = "moon" if action == "skill" else action
		button.accent = Color("e9c47f") if action == "attack" else Color("9feaff") if action == "skill" else Color("9ee6bd") if action == "potion" else Color("bbc9df")
		button.tooltip_text = "%s [%s]" % [button.caption, button.hotkey]
		if preview or MobileControls.is_mobile_device():
			button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.pressed.connect(func() -> void: action_pressed.emit(action))
		add_child(button)
		if not preview:
			button.add_to_group("camera_touch_blocker")
		buttons[action] = button
	resized.connect(_arrange)
	_arrange()

func apply_layout(value: Dictionary) -> void:
	layout = Layout.sanitize(value)
	_arrange()

func _arrange() -> void:
	if buttons.is_empty():
		return
	var center := size - Vector2(84 + float(layout.inset_x), 84 + float(layout.inset_y))
	for action: String in buttons:
		var button: Button = buttons[action]
		var diameter: float = (112.0 if action == "attack" else 78.0) * float(layout.size)
		button.size = Vector2.ONE * diameter
		var point: Vector2 = center
		if action != "attack":
			var slot: int = layout.order.find(action)
			point += Vector2.from_angle(PI + slot * PI / 6.0) * float(layout.radius)
		button.position = point - button.size * 0.5
		button.show_caption = bool(layout.labels)
		button.queue_redraw()
	queue_redraw()

func _draw() -> void:
	var center := size - Vector2(84 + float(layout.inset_x), 84 + float(layout.inset_y))
	draw_arc(center, float(layout.radius), PI, PI * 1.5, 64, Color(0.61, 0.77, 0.87, 0.16), 1.0, true)
