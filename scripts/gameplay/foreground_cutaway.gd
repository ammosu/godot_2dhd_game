extends Node
## Broad-phase obstruction hint for the depth-masked character silhouette.
## Scenery, materials, collisions and shadow casting always remain intact.

const RESTORE_DELAY: float = 0.22
var active: bool = false
var minimum_height: float = 0.45
var _clear_time: float = 0.0
var _house: Node3D
var _target: Node3D
var _camera: Camera3D
var _parts: Array[Dictionary] = []
var _bounds: AABB


func configure(house: Node3D, target: Node3D, camera: Camera3D, group: StringName = &"foreground_cutaways") -> void:
	_house = house
	_target = target
	_camera = camera
	process_priority = 20 # Evaluate after the camera rig finishes following/orbiting.
	_collect(house)
	add_to_group(group)
	var sprite := target.get_node_or_null("Sprite3D") as AnimatedSprite3D
	if sprite != null:
		var hint := target.get_node_or_null("OccludedCharacter")
		if hint == null:
			hint = preload("res://scripts/gameplay/occluded_character.gd").new()
			hint.name = "OccludedCharacter"
			target.add_child(hint)
			hint.configure(sprite)
		hint.register(self)


func _collect(node: Node) -> void:
	if node is GeometryInstance3D:
		var visual := node as GeometryInstance3D
		var local_transform := _house.global_transform.affine_inverse() * visual.global_transform
		var mesh_bounds: AABB = visual.get_aabb()
		if visual is MultiMeshInstance3D:
			# Renderer buffers may still be unsynchronized during construction.
			# HouseDetails supplies bounds directly from authored tile transforms.
			var batch := (visual as MultiMeshInstance3D).multimesh
			if batch != null and batch.custom_aabb.has_volume():
				mesh_bounds = batch.custom_aabb
		var bounds: AABB = local_transform * mesh_bounds
		if visual.visible and visual.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY and bounds.end.y > minimum_height:
			_bounds = bounds if _parts.is_empty() else _bounds.merge(bounds)
			_parts.append({"visual": visual, "bounds": bounds, "shadow": visual.cast_shadow})
	for child: Node in node.get_children():
		_collect(child)


func _process(delta: float) -> void:
	if not is_instance_valid(_target) or not is_instance_valid(_camera):
		_set_active(false)
		return
	if obstructs_view():
		_clear_time = 0.0
		_set_active(true)
	elif active:
		_clear_time += delta
		if _clear_time >= RESTORE_DELAY:
			_set_active(false)


func obstructs_view() -> bool:
	if _parts.is_empty():
		return false
	var origin := _house.to_local(_camera.global_position)
	var right := _camera.global_basis.x
	# Sample feet, torso and head, plus torso width. A center ray alone misses
	# partial occlusion of the billboard when standing by a roof edge.
	var offsets: Array[Vector3] = [Vector3.UP * 0.15, Vector3.UP * 0.8, Vector3.UP * 1.45, Vector3.UP * 0.8 + right * 0.25, Vector3.UP * 0.8 - right * 0.25]
	# Fully billboarded character art tilts with the camera. Its visible face
	# can penetrate scenery behind the vertical collision body, so sample that
	# rendered plane as well. Keep body rays for ordinary upright occlusion.
	var sprite := _target.get_node_or_null("Sprite3D") as SpriteBase3D
	if sprite != null and sprite.billboard == BaseMaterial3D.BILLBOARD_ENABLED:
		var up := _camera.global_basis.y
		for height: float in [0.15, 0.8, 1.45]:
			offsets.append(up * height)
		offsets.append(up * 0.8 + right * 0.25)
		offsets.append(up * 0.8 - right * 0.25)
	for offset: Vector3 in offsets:
		var endpoint := _house.to_local(_target.global_position + offset)
		if _bounds.intersects_segment(origin, endpoint) == null:
			continue
		for part: Dictionary in _parts:
			if (part.bounds as AABB).intersects_segment(origin, endpoint) != null:
				return true
	return false


func _set_active(value: bool) -> void:
	if value == active:
		return
	active = value


func _exit_tree() -> void:
	_set_active(false)
