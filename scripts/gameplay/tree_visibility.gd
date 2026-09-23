extends Node
## Fade only tree billboards between the current camera and the player's body.
## Billboard-space intersection works after orbiting, in both desktop renderers.
const FADED_ALPHA: float = 0.16
var _player: Node3D
var _camera: Camera3D
var _trees: Array[Dictionary] = []

func configure(scenery: Node3D, player: Node3D, camera: Camera3D) -> void:
	_player = player
	_camera = camera
	process_priority = 25
	for node: Node in scenery.find_children("TreeArt", "Sprite3D", true, false):
		var art := node as Sprite3D
		_trees.append({"art": art, "alpha": art.modulate.a, "cut": art.alpha_cut, "clear": 1.0})

func obstructs(art: Sprite3D) -> bool:
	if not art.is_visible_in_tree() or not is_instance_valid(_camera) or not is_instance_valid(_player):
		return false
	var normal := _camera.global_position - art.global_position
	normal.y = 0
	if normal.length_squared() < 0.001:
		return false
	normal = normal.normalized()
	var right := Vector3.UP.cross(normal).normalized()
	var scale: Vector3 = art.global_basis.get_scale()
	var bounds := art.get_aabb()
	var rect := Rect2(Vector2(bounds.position.x * scale.x, bounds.position.y * scale.y), Vector2(bounds.size.x * scale.x, bounds.size.y * scale.y))
	for height: float in [0.25, 0.8, 1.45]:
		for width: float in [-0.25, 0.0, 0.25]:
			var endpoint := _player.global_position + Vector3.UP * height + _camera.global_basis.x * width
			var origin := _camera.global_position
			if _camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
				origin = _camera.project_ray_origin(_camera.unproject_position(endpoint))
			var ray := endpoint - origin
			var denominator: float = normal.dot(ray)
			if absf(denominator) < 0.0001:
				continue
			var fraction: float = normal.dot(art.global_position - origin) / denominator
			if fraction <= 0 or fraction >= 1:
				continue
			var hit := origin + ray * fraction - art.global_position
			if rect.has_point(Vector2(hit.dot(right), hit.y)):
				return true
	return false

func _process(delta: float) -> void:
	for entry: Dictionary in _trees:
		var art: Sprite3D = entry.art
		if not is_instance_valid(art):
			continue
		var blocked := obstructs(art)
		entry.clear = 0.0 if blocked else float(entry.clear) + delta
		var desired: float = float(entry.alpha) * (FADED_ALPHA if blocked or float(entry.clear) < 0.22 else 1.0)
		art.modulate.a = move_toward(art.modulate.a, desired, delta * 6.0)
		art.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED if art.modulate.a < float(entry.alpha) - 0.001 else int(entry.cut)

func _exit_tree() -> void:
	for entry: Dictionary in _trees:
		var art: Sprite3D = entry.art
		if is_instance_valid(art):
			art.modulate.a = entry.alpha
			art.alpha_cut = entry.cut
