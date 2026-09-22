extends RefCounted
## Surface-only furniture dressing; never owns physics or persistent state.


static func wood(size: Vector3, pale: bool = false) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/furniture_wood.gdshader")
	material.set_shader_parameter("timber", preload("res://assets/generated/timber_albedo.png"))
	material.set_shader_parameter("dimensions", size)
	material.set_shader_parameter("wood_color", Color("a78a66") if pale else Color("826348"))
	return material


static func contact(parent: Node3D, at: Vector3, footprint: Vector2, strength: float = 0.18) -> void:
	var shadow := MeshInstance3D.new()
	shadow.name = "FurnitureContact"
	shadow.position = at + Vector3.UP * 0.028
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var plane := PlaneMesh.new()
	plane.size = footprint
	shadow.mesh = plane
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/furniture_contact.gdshader")
	material.set_shader_parameter("strength", strength)
	shadow.material_override = material
	parent.add_child(shadow)
