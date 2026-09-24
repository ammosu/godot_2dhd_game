extends RefCounted
## Shared human stature and silhouette fitting, measured from standing art only.
## Weapons and action poses must never determine the size of a person's body.
const HEIGHT: float = 1.45
const HEAD_WIDTH_RATIO: float = 0.40
static var _profiles: Dictionary[String, Vector2] = {}


static func profile(texture: Texture2D, reference_height: float, ground: float = -1.0, pivot: float = -1.0) -> Vector2:
	var key := "%s:%s:%s:%s" % [texture.get_instance_id(), reference_height, ground, pivot]
	if _profiles.has(key):
		return _profiles[key]
	var image: Image
	var region: Rect2i
	var margin := Vector2.ZERO
	if texture is AtlasTexture:
		var atlas := texture as AtlasTexture
		image = atlas.atlas.get_image()
		region = Rect2i(atlas.region)
		margin = atlas.margin.position
	else:
		image = texture.get_image()
		region = Rect2i(Vector2i.ZERO, image.get_size())
	if image.is_compressed():
		if image.decompress() != OK:
			return Vector2(reference_height, 1.0)
	var baseline: float = ground if ground >= 0.0 else float(texture.get_meta("ground_y", margin.y + region.size.y))
	var center: float = pivot if pivot >= 0.0 else float(texture.get_meta("anchor_x", texture.get_width() * 0.5))
	center -= margin.x
	var first: int = maxi(0, int(baseline - margin.y - reference_height))
	var bottom: int = mini(region.size.y, int(baseline - margin.y))
	# A broad run through the body axis finds the crown while ignoring a thin
	# raised spear/staff beside it. Use standing frames, never attack bounds.
	var top: int = first
	for y: int in range(first, bottom):
		var count: int = 0
		for x: int in range(maxi(0, int(center - reference_height * 0.16)), mini(region.size.x, int(center + reference_height * 0.16))):
			if image.get_pixel(region.position.x + x, region.position.y + y).a >= 0.5:
				count += 1
		if count >= maxi(2, int(reference_height * 0.12)):
			top = y
			break
	var height: float = clampf(float(bottom - top), reference_height * 0.8, reference_height)
	var widths: Array[int] = []
	for y: int in range(top + int(height * 0.08), mini(bottom, top + int(height * 0.28))):
		var run: int = 0
		var widest: int = 0
		for x: int in range(region.size.x):
			if image.get_pixel(region.position.x + x, region.position.y + y).a >= 0.5:
				run += 1
				widest = maxi(widest, run)
			else:
				run = 0
		widths.append(widest)
	widths.sort()
	var head_width: float = float(widths[int(widths.size() * 0.7)]) if not widths.is_empty() else height * HEAD_WIDTH_RATIO
	# Modest fitting preserves the drawings and natural physique differences.
	var width_scale: float = clampf(height * HEAD_WIDTH_RATIO / maxf(head_width, 1.0), 0.85, 1.2)
	var result := Vector2(height, width_scale)
	_profiles[key] = result
	return result


static func apply(sprite: SpriteBase3D, standing: Texture2D, reference_height: float, world_height: float = HEIGHT) -> void:
	var fitted := profile(standing, reference_height)
	sprite.pixel_size = world_height / fitted.x
	sprite.scale.x = fitted.y


static func stamp(texture: Texture2D, standing: Texture2D, reference_height: float) -> void:
	var source_height: float = float(standing.get_meta("source_body_height", reference_height))
	var fitted := profile(standing, source_height)
	fitted.x *= reference_height / source_height
	texture.set_meta("body_height", fitted.x)
	texture.set_meta("width_scale", fitted.y)
	texture.set_meta("pixel_size", HEIGHT / fitted.x)


static func fit_portrait(texture: Texture2D, standing: Texture2D) -> void:
	var ground: float = float(standing.get_meta("ground_y", preload("res://scripts/gameplay/sprite_grounding.gd").foot_baseline(standing)))
	var height: float = float(standing.get_meta("body_height", (standing as AtlasTexture).region.size.y if standing is AtlasTexture else standing.get_height()))
	var fitted := profile(standing, height, ground)
	texture.set_meta("body_height", fitted.x)
	texture.set_meta("width_scale", fitted.y)
