class_name MobileControls
extends Control

signal camera_dragged(radians: float)

const JOYSTICK_RADIUS: float = 86.0
const JOYSTICK_KNOB_RADIUS: float = 34.0
const ACTION_RADIUS: float = 58.0
const CAMERA_DRAG_DEADZONE: float = 10.0
const MOVE_DEADZONE: float = 0.22
const WEB_LANDSCAPE_LISTENER_SCRIPT: String = """
(() => {
	if (window.__wanderlightLandscapeListenerInstalled) {
		return;
	}
	window.__wanderlightLandscapeListenerInstalled = true;
	const lockLandscape = () => {
		if (screen.orientation && typeof screen.orientation.lock === "function") {
			return screen.orientation.lock("landscape").catch(() => {});
		}
		return Promise.resolve();
	};
	const requestLandscape = () => {
		if (window.innerWidth >= window.innerHeight) {
			return;
		}
		const root = document.documentElement;
		if (document.fullscreenElement) {
			void lockLandscape();
			return;
		}
		if (typeof root.requestFullscreen === "function") {
			void root.requestFullscreen({ navigationUI: "hide" }).then(lockLandscape, lockLandscape);
			return;
		}
		if (typeof root.webkitRequestFullscreen === "function") {
			root.webkitRequestFullscreen();
		}
		void lockLandscape();
	};
	document.addEventListener("pointerup", requestLandscape, { capture: true });
})();
"""

const MOVE_ACTIONS: Array[StringName] = [
	&"move_left",
	&"move_right",
	&"move_forward",
	&"move_back",
]

var _mobile_device: bool = false
var _landscape: bool = true
var _move_touch_index: int = -1
var _move_vector: Vector2 = Vector2.ZERO
var _button_touches: Dictionary = {}
var _pressed_buttons: Dictionary = {}
var _camera_touch_index: int = -1
var _camera_pending := Vector2.ZERO
var _camera_dragging: bool = false
var _previous_mode: int = -1


static func is_mobile_device() -> bool:
	if "--mobile-controls" in OS.get_cmdline_user_args():
		return true
	return (
		OS.has_feature("android")
		or OS.has_feature("ios")
		or OS.has_feature("web_android")
		or OS.has_feature("web_ios")
	)


func _ready() -> void:
	_mobile_device = is_mobile_device()
	if _mobile_device:
		get_window().content_scale_size = Vector2i(960, 540)
		get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_input(_mobile_device)
	set_process_unhandled_input(_mobile_device)
	set_process(_mobile_device)
	get_window().focus_exited.connect(_release_all_actions)
	GameState.map_change_requested.connect(func(_map: String, _spawn: String) -> void: _release_all_actions())
	_install_web_landscape_listener()
	GameState.state_changed.connect(_refresh_visibility)
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_refresh_visibility()
	queue_redraw()


func _exit_tree() -> void:
	_release_all_actions()


func _input(event: InputEvent) -> void:
	if not _mobile_device:
		return
	if not _camera_input_allowed():
		_cancel_camera_drag()
	if not _landscape:
		var pressed_touch := event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed
		var pressed_click := (
			event is InputEventMouseButton
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
			and (event as InputEventMouseButton).pressed
		)
		if pressed_touch or pressed_click:
			accept_event()
		return
	if GameState.mode not in [GameState.Mode.EXPLORE, GameState.Mode.BATTLE]:
		return
	if event is InputEventScreenTouch:
		_handle_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_drag(event as InputEventScreenDrag)


func _draw() -> void:
	if not _mobile_device:
		return
	if not _landscape:
		_draw_portrait_notice()
		return
	if GameState.mode not in [GameState.Mode.EXPLORE, GameState.Mode.BATTLE]:
		return

	var base := _joystick_center()
	var knob_offset := _move_vector * (JOYSTICK_RADIUS - JOYSTICK_KNOB_RADIUS)
	draw_circle(base, JOYSTICK_RADIUS, Color(0.035, 0.065, 0.10, 0.66))
	draw_arc(base, JOYSTICK_RADIUS, 0.0, TAU, 64, Color(0.85, 0.65, 0.36, 0.76), 3.0, true)
	draw_circle(base + knob_offset, JOYSTICK_KNOB_RADIUS, Color(0.38, 0.64, 0.65, 0.80))
	draw_arc(base + knob_offset, JOYSTICK_KNOB_RADIUS, 0.0, TAU, 40, Color(0.92, 0.82, 0.56), 3.0, true)

	if GameState.mode == GameState.Mode.BATTLE:
		return
	_draw_round_button(_action_center(), ACTION_RADIUS, "互動", &"interact", Color(0.10, 0.25, 0.29, 0.88))
	_draw_pill_button(_equipment_rect(), "裝備", &"equipment_menu")
	_draw_pill_button(_save_rect(), "存檔", &"save_game")
	_draw_pill_button(_load_rect(), "讀檔", &"load_game")


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.canceled:
		if event.index == _camera_touch_index:
			_cancel_camera_drag()
		if event.index == _move_touch_index:
			_move_touch_index = -1
			_move_vector = Vector2.ZERO
			_apply_move_actions()
		if _button_touches.has(event.index):
			_set_button_action(_button_touches[event.index], false)
			_button_touches.erase(event.index)
		queue_redraw()
		return
	if event.pressed:
		if _move_touch_index == -1 and event.position.distance_to(_joystick_center()) <= JOYSTICK_RADIUS * 1.45:
			_move_touch_index = event.index
			_update_move_vector(event.position)
			accept_event()
			return
		var action := _action_at(event.position)
		if not action.is_empty():
			_button_touches[event.index] = action
			_set_button_action(action, true)
			accept_event()
	else:
		if event.index == _camera_touch_index:
			_cancel_camera_drag()
			accept_event()
		if event.index == _move_touch_index:
			_move_touch_index = -1
			_move_vector = Vector2.ZERO
			_apply_move_actions()
			queue_redraw()
			accept_event()
		elif _button_touches.has(event.index):
			var action: StringName = _button_touches[event.index]
			_button_touches.erase(event.index)
			_set_button_action(action, false)
			accept_event()


func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index == _camera_touch_index:
		if not _camera_input_allowed():
			_cancel_camera_drag()
			return
		var horizontal: float = event.relative.x
		if not _camera_dragging:
			_camera_pending += event.relative
			if _camera_pending.length() < CAMERA_DRAG_DEADZONE:
				return
			if absf(_camera_pending.y) > absf(_camera_pending.x):
				_cancel_camera_drag()
				return
			_camera_dragging = true
			horizontal = _camera_pending.x - signf(_camera_pending.x) * CAMERA_DRAG_DEADZONE
		camera_dragged.emit(-horizontal * PI / maxf(size.x, 1.0))
		accept_event()
		return
	if event.index != _move_touch_index:
		return
	_update_move_vector(event.position)
	accept_event()


func _update_move_vector(touch_position: Vector2) -> void:
	_move_vector = (touch_position - _joystick_center()) / JOYSTICK_RADIUS
	if _move_vector.length() > 1.0:
		_move_vector = _move_vector.normalized()
	if _move_vector.length() < MOVE_DEADZONE:
		_move_vector = Vector2.ZERO
	_apply_move_actions()
	queue_redraw()


func _apply_move_actions() -> void:
	_set_move_action(&"move_left", maxf(0.0, -_move_vector.x))
	_set_move_action(&"move_right", maxf(0.0, _move_vector.x))
	_set_move_action(&"move_forward", maxf(0.0, -_move_vector.y))
	_set_move_action(&"move_back", maxf(0.0, _move_vector.y))


func _set_move_action(action: StringName, strength: float) -> void:
	if strength > 0.0:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


func _set_button_action(action: StringName, pressed: bool) -> void:
	_pressed_buttons[action] = pressed
	var action_event := InputEventAction.new()
	action_event.action = action
	action_event.pressed = pressed
	action_event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(action_event)
	if pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)
	queue_redraw()


func _action_at(position: Vector2) -> StringName:
	if GameState.mode == GameState.Mode.EXPLORE and position.distance_to(_action_center()) <= ACTION_RADIUS * 1.2:
		return &"interact"
	if GameState.mode == GameState.Mode.BATTLE:
		return &""
	if _save_rect().grow(8.0).has_point(position):
		return &"save_game"
	if _load_rect().grow(8.0).has_point(position):
		return &"load_game"
	if _equipment_rect().grow(8.0).has_point(position):
		return &"equipment_menu"
	return &""


func _draw_round_button(center: Vector2, radius: float, label: String, action: StringName, color: Color) -> void:
	var is_pressed := bool(_pressed_buttons.get(action, false))
	var button_color := color.lightened(0.16) if is_pressed else color
	draw_circle(center, radius, button_color)
	draw_arc(center, radius, 0.0, TAU, 48, Color(0.92, 0.76, 0.42, 0.9), 3.0, true)
	_draw_centered_text(center, label, 23 if radius > 40.0 else 28)


func _draw_pill_button(rect: Rect2, label: String, action: StringName) -> void:
	var is_pressed := bool(_pressed_buttons.get(action, false))
	var style := preload("res://scripts/ui/presentation_theme.gd").panel(0)
	if is_pressed:
		style.bg_color = Color("345563")
	draw_style_box(style, rect)
	_draw_centered_text(rect.get_center(), label, 22)


func _draw_centered_text(center: Vector2, label: String, font_size: int) -> void:
	var font := GameState.ui_theme.default_font if GameState.ui_theme != null else ThemeDB.fallback_font
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var baseline := center + Vector2(-text_size.x * 0.5, text_size.y * 0.34)
	draw_string(font, baseline, label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color("fff2d2"))


func _draw_portrait_notice() -> void:
	var backdrop := Rect2(Vector2.ZERO, size)
	draw_rect(backdrop, Color(0.025, 0.045, 0.07, 0.97))
	var center := size * 0.5
	draw_arc(center + Vector2(0.0, -42.0), 46.0, -PI * 0.1, PI * 1.35, 40, Color("75d5ce"), 5.0, true)
	_draw_centered_text(center + Vector2(0.0, 42.0), "點一下切換橫向", int(size.x * 0.06))
	_draw_centered_text(center + Vector2(0.0, 122.0), "若瀏覽器未切換，請旋轉手機", int(size.x * 0.038))


func _install_web_landscape_listener() -> void:
	if not _mobile_device or not OS.has_feature("web"):
		return
	JavaScriptBridge.eval(WEB_LANDSCAPE_LISTENER_SCRIPT, true)


func _refresh_visibility() -> void:
	_landscape = _is_window_landscape()
	if _mobile_device and get_parent() is CanvasLayer:
		(get_parent() as CanvasLayer).layer = 50 if _landscape else 120
	if GameState.mode != _previous_mode or not _camera_input_allowed():
		_release_all_actions()
	_previous_mode = GameState.mode
	queue_redraw()


func _on_viewport_size_changed() -> void:
	_landscape = _is_window_landscape()
	if _mobile_device and get_parent() is CanvasLayer:
		(get_parent() as CanvasLayer).layer = 50 if _landscape else 120
	_release_all_actions()
	queue_redraw()


func _is_window_landscape() -> bool:
	if OS.has_feature("web"):
		var web_landscape: Variant = JavaScriptBridge.eval("window.innerWidth >= window.innerHeight", true)
		return bool(web_landscape)
	var window_size := DisplayServer.window_get_size()
	return window_size.x >= window_size.y


func _release_all_actions() -> void:
	_cancel_camera_drag()
	_move_touch_index = -1
	_move_vector = Vector2.ZERO
	for action in MOVE_ACTIONS:
		Input.action_release(action)
	for action: Variant in _pressed_buttons.keys():
		if bool(_pressed_buttons[action]):
			_set_button_action(action as StringName, false)
	_button_touches.clear()
	_pressed_buttons.clear()


func _joystick_center() -> Vector2:
	return Vector2(132.0, size.y - (108.0 if GameState.mode == GameState.Mode.BATTLE else 132.0))


func _action_center() -> Vector2:
	return Vector2(size.x - 112.0, size.y - 82.0)


func _save_rect() -> Rect2:
	return Rect2(Vector2(size.x - 210.0, 66.0), Vector2(82.0, 64.0))


func _equipment_rect() -> Rect2:
	return Rect2(Vector2(size.x - 304.0, 66.0), Vector2(82.0, 64.0))


func _load_rect() -> Rect2:
	return Rect2(Vector2(size.x - 116.0, 66.0), Vector2(82.0, 64.0))


func _camera_input_allowed() -> bool:
	if not _landscape:
		return false
	if GameState.mode == GameState.Mode.BATTLE:
		return GameState.battle_session != null and not bool(GameState.battle_session.paused) and int(GameState.battle_session.winner) == -1
	return GameState.mode == GameState.Mode.EXPLORE


func _process(_delta: float) -> void:
	if not _camera_input_allowed():
		_cancel_camera_drag()


func _unhandled_input(event: InputEvent) -> void:
	# Only claim an untouched world press after UI has had a chance to consume it.
	if not _mobile_device or not _camera_input_allowed() or _camera_touch_index != -1:
		return
	if not event is InputEventScreenTouch or not event.pressed or event.canceled:
		return
	if event.index == _move_touch_index or _button_touches.has(event.index):
		return
	if event.position.distance_to(_joystick_center()) <= JOYSTICK_RADIUS * 1.45 or not _action_at(event.position).is_empty():
		return
	for node: Node in get_tree().get_nodes_in_group("camera_touch_blocker"):
		var control := node as Control
		if control == null or not control.is_visible_in_tree():
			continue
		if control.has_method("contains_screen_point"):
			if control.contains_screen_point(event.position):
				return
		elif control.get_global_rect().has_point(event.position):
			return
	_camera_touch_index = event.index
	_camera_pending = Vector2.ZERO
	_camera_dragging = false
	accept_event()


func _cancel_camera_drag() -> void:
	_camera_touch_index = -1
	_camera_pending = Vector2.ZERO
	_camera_dragging = false
