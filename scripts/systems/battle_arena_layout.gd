extends RefCounted
## Pure, versioned visual layout generation. Never consumes the gameplay RNG.

const LAYOUT_VERSION: int = 1
const LAYOUT_COUNT: int = 4
const MAX_PLACEMENT_ATTEMPTS: int = 6
const THEMES: Array[String] = ["village", "forest", "ruins", "moon_spring", "eclipse"]
const POOLS: Dictionary = {
	"village": {"rear": ["crate", "jar", "marker"], "low": ["grass", "flower", "rubble"]},
	"forest": {"rear": ["tree", "log", "marker"], "low": ["grass", "rubble", "flower"]},
	"ruins": {"rear": ["pillar", "rubble", "marker"], "low": ["rubble", "grass"]},
	"moon_spring": {"rear": ["pillar", "reed", "rubble"], "low": ["reed", "flower", "rubble"]},
	"eclipse": {"rear": ["pillar", "marker", "rubble"], "low": ["rubble"]},
}
# Conservative horizontal footprint radii, before per-instance uniform scaling.
const RADII: Dictionary = {
	"pillar": 0.65, "rubble": 0.6, "grass": 0.45, "crate": 0.6, "jar": 0.45,
	"tree": 0.9, "log": 0.8, "marker": 0.45, "reed": 0.4, "flower": 0.35,
}
# Authored slots: only rear objects can be tall. The two front slots are low
# and outside both teams; the combat rectangle is permanently empty.
const REAR_SLOTS: Array[Vector3] = [
	Vector3(-8.2, 0, -3.65), Vector3(-5.4, 0, -3.65), Vector3(-2.7, 0, -3.65),
	Vector3(0, 0, -3.65), Vector3(2.7, 0, -3.65), Vector3(5.4, 0, -3.65), Vector3(8.2, 0, -3.65),
]
const LAYOUT_SLOTS: Array = [[0, 2, 4, 6], [0, 1, 4, 6], [0, 2, 5, 6], [0, 1, 3, 5, 6]]
const FRONT_SLOTS: Array[Vector3] = [Vector3(-8.5, 0, 3.65), Vector3(8.5, 0, 3.65)]


static func normalize_theme(theme: String) -> String:
	var normalized := theme.strip_edges().to_lower()
	return normalized if normalized in THEMES else "ruins"


static func generate(theme: String, visual_seed: int, layout_index: int = -1) -> Dictionary:
	var selected_theme := normalize_theme(theme)
	var rng := RandomNumberGenerator.new()
	rng.seed = visual_seed
	var rolled_layout := posmod(visual_seed, LAYOUT_COUNT)
	var selected_layout := layout_index if layout_index >= 0 and layout_index < LAYOUT_COUNT else rolled_layout
	var props: Array[Dictionary] = []
	var pool: Dictionary = POOLS[selected_theme]
	for slot_index: int in LAYOUT_SLOTS[selected_layout]:
		# Outer rear anchors always remain; inner dressing may be absent.
		if slot_index not in [0, 6] and rng.randf() < 0.16:
			continue
		_place(props, REAR_SLOTS[slot_index], pool.rear, rng, false)
	for slot: Vector3 in FRONT_SLOTS:
		if rng.randf() >= 0.22:
			_place(props, slot, pool.low, rng, true)
	return {
		"theme": selected_theme, "visual_seed": visual_seed, "layout_version": LAYOUT_VERSION,
		"layout_index": selected_layout, "props": props,
	}


static func _place(props: Array[Dictionary], anchor: Vector3, kinds: Array, rng: RandomNumberGenerator, front: bool) -> void:
	for attempt: int in range(MAX_PLACEMENT_ATTEMPTS):
		var kind := str(kinds[rng.randi_range(0, kinds.size() - 1)])
		var size := rng.randf_range(0.78, 1.02) if not front else rng.randf_range(0.5, 0.68)
		var position := anchor + Vector3(rng.randf_range(-0.14, 0.14), 0, rng.randf_range(-0.1, 0.1))
		var prop := {"kind": kind, "position": position, "rotation": rng.randf_range(-PI, PI), "scale": size}
		if is_safe_prop(prop, props):
			props.append(prop)
			return
	# Empty slot is the deliberately clear fallback; never retry indefinitely.


static func is_safe_prop(prop: Dictionary, placed: Array[Dictionary]) -> bool:
	var kind := str(prop.get("kind", ""))
	if not RADII.has(kind) or not prop.get("position") is Vector3:
		return false
	var position: Vector3 = prop.position
	var size := float(prop.get("scale", 0.0))
	if not position.is_finite() or not is_finite(size) or size <= 0.0 or size > 1.02:
		return false
	if absf(position.x) > 9.0 or absf(position.z) > 4.0 or position.y != 0.0:
		return false
	var radius: float = float(RADII[kind]) * size
	var nearest := Vector2(clampf(position.x, -7.0, 7.0), clampf(position.z, -2.5, 2.5))
	if Vector2(position.x, position.z).distance_to(nearest) < radius + 0.18:
		return false
	if position.z > -3.5:
		if position.z < 3.5 or absf(position.x) < 8.0:
			return false
		if kind not in ["grass", "flower", "rubble", "reed"] or size > 0.68:
			return false
	for other: Dictionary in placed:
		var other_radius := float(RADII.get(str(other.kind), 0.8)) * float(other.scale)
		if position.distance_to(other.position) < radius + other_radius + 0.25:
			return false
	return true
