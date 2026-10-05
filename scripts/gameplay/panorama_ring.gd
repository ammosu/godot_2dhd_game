extends MeshInstance3D
## A painted horizontal panorama on an open cylinder that rides with the camera
## like a skybox: always inside the far plane, too distant to show parallax.
## Presentation only (no collision); the texture must tile horizontally.

@export var texture: Texture2D
@export var radius: float = 70.0
@export var height: float = 18.0
## World height of the panorama's bottom edge.
@export var base_y: float = -4.0
@export var repeats: float = 6.0
@export var tint: Color = Color.WHITE
const SEGMENTS: int = 64


func _ready() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in range(SEGMENTS):
		var quad: Array[Vector3] = []
		var uvs: Array[Vector2] = []
		for corner: Vector2i in [Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 0), Vector2i(0, 0)]:
			var angle: float = TAU * float(index + corner.x) / SEGMENTS
			quad.append(Vector3(sin(angle) * radius, height * (1 - corner.y), cos(angle) * radius))
			uvs.append(Vector2(repeats * float(index + corner.x) / SEGMENTS, corner.y))
		for vertex: int in [0, 1, 2, 0, 2, 3]:
			surface.set_uv(uvs[vertex])
			surface.add_vertex(quad[vertex])
	mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.albedo_color = tint
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.5
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_follow()


func _process(_delta: float) -> void:
	_follow()


func _follow() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		global_position = Vector3(camera.global_position.x, base_y, camera.global_position.z)
