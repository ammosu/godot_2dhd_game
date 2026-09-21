extends Node
## Per-instance material fading, supported by Forward+ and Compatibility.
## Only scenery meshes participate; character sprites and collision stay intact.
const FADED_ALPHA: float = 0.12
const RESTORE_DELAY: float = 0.22
var _camera: Camera3D
var _parts: Array[GeometryInstance3D] = []
var _faded: Dictionary = {}


func configure(scenery: Node3D, camera: Camera3D) -> void:
	restore()
	_camera = camera
	_parts.clear()
	for node: Node in scenery.find_children("*", "GeometryInstance3D", true, false):
		if node is MeshInstance3D or node is MultiMeshInstance3D:
			_parts.append(node as GeometryInstance3D)


func update(targets: Array[Node3D], delta: float) -> void:
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
		if blocked and not _faded.has(visual):
			_start_fade(visual)
		if not _faded.has(visual):
			continue
		var entry: Dictionary = _faded[visual]
		entry.clear_time = 0.0 if blocked else float(entry.clear_time) + delta
		var desired: float = 1.0 if blocked or float(entry.clear_time) < RESTORE_DELAY else 0.0
		entry.weight = move_toward(float(entry.weight), desired, delta / 0.18)
		for slot: Dictionary in entry.slots:
			var material: BaseMaterial3D = slot.fade
			material.albedo_color.a = float(slot.alpha) * lerpf(1.0, FADED_ALPHA, float(entry.weight))
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
		if not source is BaseMaterial3D:
			continue # Custom water/effect shaders retain their own presentation.
		var fade := source.duplicate() as BaseMaterial3D
		fade.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		slots.append({"index": index, "override": override_slot, "original": original, "fade": fade, "alpha": fade.albedo_color.a})
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
	for visual: Variant in _faded:
		if is_instance_valid(visual):
			_restore_part(visual, _faded[visual])
	_faded.clear()


func _exit_tree() -> void:
	restore()
