extends RefCounted
## Shared woven relief for scene textiles. Original analytic weave, cached once.

static var _weave_normal: ImageTexture


static func make(tint: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = preload("res://assets/generated/linen_albedo.png")
	material.albedo_color = tint
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.roughness = 0.98
	material.metallic_specular = 0.18
	material.normal_enabled = true
	material.normal_texture = _normal_texture()
	material.normal_scale = 0.32
	return material


static func _normal_texture() -> ImageTexture:
	if _weave_normal != null:
		return _weave_normal
	const SIZE: int = 128
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	# Alternating warp/weft crossings, with a broad, subtle yarn irregularity.
	# Periodic functions keep all four edges seamless.
	for y: int in range(SIZE):
		for x: int in range(SIZE):
			var u := float(x) / SIZE
			var v := float(y) / SIZE
			var dx := (_height(u + 1.0 / SIZE, v) - _height(u - 1.0 / SIZE, v)) * 1.8
			var dy := (_height(u, v + 1.0 / SIZE) - _height(u, v - 1.0 / SIZE)) * 1.8
			var normal := Vector3(-dx, -dy, 1.0).normalized()
			image.set_pixel(x, y, Color(normal.x * 0.5 + 0.5, normal.y * 0.5 + 0.5, normal.z * 0.5 + 0.5))
	image.generate_mipmaps()
	_weave_normal = ImageTexture.create_from_image(image)
	return _weave_normal


static func _height(u: float, v: float) -> float:
	var warp := cos(u * TAU * 16.0)
	var weft := cos(v * TAU * 16.0)
	var crossing := sin(u * TAU * 8.0) * sin(v * TAU * 8.0)
	return (warp + weft) * 0.18 + crossing * (warp - weft) * 0.12 + sin(u * TAU * 3.0 + sin(v * TAU * 2.0)) * 0.045
