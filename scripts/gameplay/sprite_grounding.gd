extends RefCounted
## Keep billboards rotating around their visible feet, not image centers.


static func foot_baseline(texture: Texture2D, threshold: float = 0.25) -> float:
	var image: Image
	var region: Rect2i
	var margin_y: float = 0.0
	if texture is AtlasTexture:
		var atlas := texture as AtlasTexture
		image = atlas.atlas.get_image()
		region = Rect2i(atlas.region)
		margin_y = atlas.margin.position.y
	else:
		image = texture.get_image()
		region = Rect2i(Vector2i.ZERO, image.get_size())
	for y: int in range(region.end.y - 1, region.position.y - 1, -1):
		for x: int in range(region.position.x, region.end.x):
			if image.get_pixel(x, y).a >= threshold:
				return float(y - region.position.y + 1) + margin_y
	return float(texture.get_height())


static func anchor(sprite: SpriteBase3D, texture: Texture2D) -> void:
	sprite.offset.y = foot_baseline(texture, sprite.alpha_scissor_threshold) - float(texture.get_height()) * 0.5
	sprite.position.y = 0.012
	# Camera-tilted billboard shadows slide away from the feet as the view orbits.
	# Use the stable ground-plane contact shadow instead of that card silhouette.
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.add_to_group("grounded_character_art")


static func add_shadow(parent: Node3D, radius: float, height: float = 0.014) -> MeshInstance3D:
	var shadow := MeshInstance3D.new()
	shadow.name = "ContactShadow"
	shadow.position.y = height
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var plane := PlaneMesh.new()
	plane.size = Vector2(radius * 2.0, radius * 1.45)
	shadow.mesh = plane
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/contact_shadow.gdshader")
	shadow.material_override = material
	parent.add_child(shadow)
	return shadow
