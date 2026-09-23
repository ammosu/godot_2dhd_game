extends RefCounted
## Presentation preferences are separate from quest/save data.
const VERSION: int = 1
const DEFAULTS: Dictionary = {"radius": 184.0, "size": 1.0, "inset_x": 0.0, "inset_y": 0.0, "labels": true, "order": ["potion", "switch", "skill", "dodge"]}
const LIMITS: Dictionary = {"radius": Vector2(174, 218), "size": Vector2(0.8, 1.05), "inset_x": Vector2(0, 32), "inset_y": Vector2(0, 32)}
var settings_path: String = "user://battle_controls.cfg"
var values: Dictionary = DEFAULTS.duplicate(true)

static func sanitize(source: Dictionary) -> Dictionary:
	var clean: Dictionary = DEFAULTS.duplicate(true)
	for key: String in LIMITS:
		var candidate: Variant = source.get(key)
		if typeof(candidate) in [TYPE_FLOAT, TYPE_INT] and is_finite(float(candidate)):
			var bounds: Vector2 = LIMITS[key]
			clean[key] = clampf(float(candidate), bounds.x, bounds.y)
	if typeof(source.get("labels")) == TYPE_BOOL:
		clean.labels = source.labels
	var order: Variant = source.get("order")
	if order is Array and order.size() == 4:
		var remaining: Array = DEFAULTS.order.duplicate()
		for item: Variant in order:
			remaining.erase(item)
		if remaining.is_empty():
			clean.order = order.duplicate()
	return clean

func load_preferences() -> void:
	values = DEFAULTS.duplicate(true)
	var config := ConfigFile.new()
	if config.load(settings_path) != OK or config.get_value("controls", "version", 0) != VERSION:
		return
	var saved: Variant = config.get_value("controls", "layout", {})
	if saved is Dictionary:
		values = sanitize(saved)

func save_preferences(layout: Dictionary) -> Error:
	var next: Dictionary = sanitize(layout)
	var config := ConfigFile.new()
	config.set_value("controls", "version", VERSION)
	config.set_value("controls", "layout", next)
	var error: Error = config.save(settings_path)
	if error == OK:
		values = next
	return error
