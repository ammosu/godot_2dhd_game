extends SceneTree
const Occlusion = preload("res://scripts/gameplay/dialogue_occlusion.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scenery := Node3D.new()
	root.add_child(scenery)
	var material := StandardMaterial3D.new()
	var blocker := MeshInstance3D.new()
	blocker.mesh = BoxMesh.new()
	blocker.mesh.size = Vector3(2, 3, 1)
	blocker.mesh.material = material
	blocker.position = Vector3(0, 1, 0)
	scenery.add_child(blocker)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(0, 2, 5)
	camera.look_at(Vector3(0, 0.8, -3))
	var player := Node3D.new()
	root.add_child(player)
	player.position = Vector3(6, 0, -3)
	var partner := Node3D.new()
	root.add_child(partner)
	partner.position = Vector3(0, 0, -3)
	var fade := Occlusion.new()
	root.add_child(fade)
	fade.configure(scenery, camera)
	for projection: int in [Camera3D.PROJECTION_PERSPECTIVE, Camera3D.PROJECTION_ORTHOGONAL]:
		camera.projection = projection
		fade.update([player, partner], 0.2)
		assert(blocker.get_active_material(0) != material, "Partner occlusion must fade independently of player")
		assert(is_equal_approx(blocker.get_active_material(0).albedo_color.a, 0.12))
		assert(material.albedo_color.a == 1.0, "Shared material changed")
		fade.update([], 0.1)
		assert(blocker.get_surface_override_material(0) != null, "Restore delay missing")
		fade.update([], 0.3)
		assert(blocker.get_surface_override_material(0) == null, "Original material not restored")
		partner.position.z = 3.0
		fade.update([partner], 0.2)
		assert(blocker.get_surface_override_material(0) == null, "Object behind actor faded")
		partner.position.z = -3.0
		fade.update([partner], 0.2)
		fade.restore()
		assert(blocker.get_surface_override_material(0) == null)
	fade.update([partner], 0.2)
	scenery.free()
	fade.update([], 0.3)
	fade.restore()
	fade.free()
	player.free()
	partner.free()
	camera.free()
	print("DIALOGUE_OCCLUSION_TEST_PASS both_subjects perspective orthographic shared_material restore map_cleanup")
	quit()
