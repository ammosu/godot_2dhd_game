extends Node
## Per-instance material fading, supported by Forward+ and Compatibility.
## Only scenery meshes participate; character sprites and collision stay intact.
const FADED_ALPHA: float = 0.12
const RESTORE_DELAY: float = 0.22
var _camera: Camera3D
var _parts: Array[GeometryInstance3D] = []
var _faded: Dictionary = {}
var _trees: Array[Sprite3D] = []
var _registered_cutaways: Dictionary = {}


func configure(scenery: Node3D, camera: Camera3D) -> void:
	restore()
	_camera = camera
	_parts.clear()
	_trees.clear()
	_registered_cutaways.clear()
	for node: Node in scenery.find_children("*", "GeometryInstance3D", true, false):
		if node is Sprite3D and node.name == "TreeArt":
			_trees.append(node as Sprite3D)
		if node is MeshInstance3D or node is MultiMeshInstance3D:
			_parts.append(node as GeometryInstance3D)


func update(targets: Array[Node3D], delta: float) -> void:
	if is_instance_valid(_camera):
		_camera.set_meta("dialogue_subjects", targets)
	# Cutaway meshes may be registered after the map's initial scenery scan.
	# Include their roots too: find_children does not include the root itself.
	if not targets.is_empty():
		for group: StringName in [&"foreground_cutaways", &"gate_cutaways"]:
			for controller: Node in get_tree().get_nodes_in_group(group):
				if _registered_cutaways.has(controller.get_instance_id()):
					continue
				_registered_cutaways[controller.get_instance_id()] = true
				for part: Dictionary in controller.get("_parts"):
					var visual := part.visual as GeometryInstance3D
					if is_instance_valid(visual) and (visual is MeshInstance3D or visual is MultiMeshInstance3D) and visual not in _parts:
						_parts.append(visual)
	if targets.is_empty() and _faded.is_empty():
		return
	var endpoints: Array[Vector3] = []
	if is_instance_valid(_camera):
		for target: Node3D in targets:
			if not is_instance_valid(target):
				continue
			var center: Vector3 = target.global_position
			if target is SpriteBase3D:
				# NPC art is already anchored at its visible center.
				center = target.get_parent().global_position
			for height: float in [0.25, 0.8, 1.4]:
				for width: float in [-0.3, 0.0, 0.3]:
					endpoints.append(center + Vector3.UP * height + _camera.global_basis.x * width)
	for visual: GeometryInstance3D in _parts:
		if not is_instance_valid(visual):
			continue
		var blocked: bool = false
		if not endpoints.is_empty() and visual.is_visible_in_tree() and visual.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			var bounds: AABB = visual.get_aabb()
			if visual is MultiMeshInstance3D and visual.multimesh != null and visual.multimesh.custom_aabb.has_volume():
				bounds = visual.multimesh.custom_aabb
			var inverse: Transform3D = visual.global_transform.affine_inverse()
			for endpoint: Vector3 in endpoints:
				var origin: Vector3 = _camera.global_position
				if _camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
					origin = _camera.project_ray_origin(_camera.unproject_position(endpoint))
				if bounds.intersects_segment(inverse * origin, inverse * endpoint) != null:
					blocked = true
					break
		if not endpoints.is_empty() and visual.has_meta("dialogue_lantern") and _dominates_dialogue_center(visual, endpoints):
			blocked = true
		if blocked and not _faded.has(visual):
			_start_fade(visual)
		if not _faded.has(visual):
			continue
		var entry: Dictionary = _faded[visual]
		entry.clear_time = 0.0 if blocked else float(entry.clear_time) + delta
		var desired: float = 1.0 if blocked or float(entry.clear_time) < RESTORE_DELAY else 0.0
		entry.weight = move_toward(float(entry.weight), desired, delta / 0.18)
		for slot: Dictionary in entry.slots:
			var material: Material = slot.fade
			var alpha: float = float(slot.alpha) * lerpf(1.0, FADED_ALPHA, float(entry.weight))
			if material is BaseMaterial3D:
				material.albedo_color.a = alpha
			elif material is ShaderMaterial:
				material.set_shader_parameter("dialogue_alpha", alpha)
		if is_zero_approx(float(entry.weight)):
			_restore_part(visual, entry)
			_faded.erase(visual)


func _start_fade(visual: GeometryInstance3D) -> void:
	var slots: Array[Dictionary] = []
	var mesh: Mesh = visual.mesh if visual is MeshInstance3D else visual.multimesh.mesh
	if mesh == null:
		return
	for index: int in range(1 if visual.material_override != null else mesh.get_surface_count()):
		var original: Material = visual.material_override
		var source: Material = original
		var override_slot: bool = original != null or visual is MultiMeshInstance3D
		if source == null:
			source = visual.get_active_material(index) if visual is MeshInstance3D else mesh.surface_get_material(index)
			if visual is MeshInstance3D:
				original = visual.get_surface_override_material(index)
		var fade: Material
		var alpha: float = 1.0
		if source is BaseMaterial3D:
			fade = source.duplicate() as BaseMaterial3D
			fade.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			alpha = fade.albedo_color.a
		elif source is ShaderMaterial and visual.has_meta("dialogue_lantern"):
			# Keep the frosted glass effect, adding alpha only to this instance.
			var glass := source.duplicate() as ShaderMaterial
			var shader := Shader.new()
			shader.code = source.shader.code.replace("void fragment() {", "uniform float dialogue_alpha = 1.0;\nvoid fragment() {\n ALPHA = dialogue_alpha;")
			glass.shader = shader
			fade = glass
		else:
			continue # Other custom water/effect shaders retain their presentation.
		slots.append({"index": index, "override": override_slot, "original": original, "fade": fade, "alpha": alpha})
		if override_slot:
			visual.material_override = fade
			break
		else:
			visual.set_surface_override_material(index, fade)
	if not slots.is_empty():
		_faded[visual] = {"slots": slots, "weight": 0.0, "clear_time": 0.0}


func _restore_part(visual: GeometryInstance3D, entry: Dictionary) -> void:
	if not is_instance_valid(visual):
		return
	for slot: Dictionary in entry.slots:
		if slot.override:
			visual.material_override = slot.original
		else:
			visual.set_surface_override_material(slot.index, slot.original)


func restore() -> void:
	if is_instance_valid(_camera):
		_camera.set_meta("dialogue_subjects", [])
	for visual: Variant in _faded:
		if is_instance_valid(visual):
			_restore_part(visual, _faded[visual])
	_faded.clear()


func _exit_tree() -> void:
	restore()


## Visual ray tests also cover roofs and billboard canopies without colliders.
func blocks_subject(subject: Node3D) -> bool:
	var feet: Vector3 = subject.get_parent().global_position if subject is SpriteBase3D else subject.global_position
	for height: float in [0.8, 1.4]:
		var endpoint: Vector3 = feet + Vector3.UP * height
		var origin: Vector3 = _camera.global_position
		if _camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
			origin = _camera.project_ray_origin(_camera.unproject_position(endpoint))
		var excluded: Array[RID] = []
		for actor: Node3D in _camera.get_meta("dialogue_subjects", []):
			if actor is CollisionObject3D:
				excluded.append(actor.get_rid())
		var ray := PhysicsRayQueryParameters3D.create(origin, endpoint, 1, excluded)
		if not _camera.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			return true
		for visual: GeometryInstance3D in _parts:
			if not is_instance_valid(visual) or not visual.is_visible_in_tree() or visual.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
				continue
			var inverse := visual.global_transform.affine_inverse()
			if visual.get_aabb().intersects_segment(inverse * origin, inverse * endpoint) != null:
				return true
		for art: Sprite3D in _trees:
			if not is_instance_valid(art) or not art.is_visible_in_tree():
				continue
			var normal := (_camera.global_position - art.global_position).slide(Vector3.UP).normalized()
			var denominator: float = normal.dot(endpoint - origin)
			if absf(denominator) < 0.0001:
				continue
			var fraction: float = normal.dot(art.global_position - origin) / denominator
			var hit: Vector3 = origin.lerp(endpoint, fraction) - art.global_position
			var bounds: AABB = art.get_aabb()
			var scale: Vector3 = art.global_basis.get_scale()
			var rect := Rect2(Vector2(bounds.position.x, bounds.position.y) * Vector2(scale.x, scale.y), Vector2(bounds.size.x, bounds.size.y) * Vector2(scale.x, scale.y))
			if fraction > 0.0 and fraction < 1.0 and rect.has_point(Vector2(hit.dot(Vector3.UP.cross(normal)), hit.y)):
				return true
	return false


## A close lamp between the two people can dominate the shot without hitting
## either person's ray. Limit this screen-space rule to foreground lanterns.
func _dominates_dialogue_center(visual: GeometryInstance3D, endpoints: Array[Vector3]) -> bool:
	if not visual.is_visible_in_tree():
		return false
	var viewport: Vector2 = _camera.get_viewport().get_visible_rect().size
	var bounds: AABB = visual.get_aabb()
	var rect := Rect2()
	var nearest: float = INF
	for index: int in range(8):
		var at: Vector3 = visual.global_transform * bounds.get_endpoint(index)
		if _camera.is_position_behind(at):
			return false
		nearest = minf(nearest, -(_camera.global_transform.affine_inverse() * at).z)
		var point: Vector2 = _camera.unproject_position(at) / viewport
		rect = Rect2(point, Vector2.ZERO) if index == 0 else rect.expand(point)
	var subject_depth: float = 0.0
	for endpoint: Vector3 in endpoints:
		subject_depth = maxf(subject_depth, -(_camera.global_transform.affine_inverse() * endpoint).z)
	var central: Rect2 = rect.intersection(Rect2(0.25, 0.12, 0.5, 0.56))
	return nearest < subject_depth and central.get_area() >= 0.012
