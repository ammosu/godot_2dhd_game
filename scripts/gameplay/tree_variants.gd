extends RefCounted
## Three authored silhouettes per species, stable across map reloads.

const Grounding = preload("res://scripts/gameplay/sprite_grounding.gd")
const SPECIES: Array[String] = ["oak", "birch", "spruce", "willow", "rowan"]
const HEIGHTS: Array[float] = [3.4, 4.0, 4.5, 3.7, 2.9]
const VARIANT_COUNT: int = 3
# Alpha-inspected bounds, not assumed equal cells in the generated atlas.
const REGIONS: Array[Rect2] = [
	Rect2(145, 121, 301, 224), Rect2(592, 124, 201, 227),
	Rect2(164, 411, 236, 222), Rect2(584, 418, 243, 219),
	Rect2(167, 702, 241, 231), Rect2(619, 702, 148, 231),
	Rect2(139, 998, 315, 214), Rect2(574, 1001, 240, 216),
	Rect2(154, 1280, 229, 232), Rect2(547, 1307, 290, 205),
]
static var _textures: Array[Texture2D] = []
static var _baselines: Array[float] = []
static var _visible_heights: Array[float] = []
static var _root_centers: Array[float] = []


static func _atlas(sheet: Texture2D, region: Rect2) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = sheet
	texture.region = region
	return texture


static func _prepare() -> void:
	if not _textures.is_empty():
		return
	var original := load("res://assets/generated/village_tree_species.png") as Texture2D
	var variants := load("res://assets/generated/village_tree_variants.png") as Texture2D
	var cell: Vector2 = original.get_size() * 0.5
	for species: int in range(SPECIES.size()):
		if species == 0:
			_textures.append(load("res://assets/generated/village_oak.png") as Texture2D)
		else:
			var index: int = species - 1
			_textures.append(_atlas(original, Rect2(Vector2(index % 2, index / 2) * cell, cell)))
		for variant: int in range(2):
			_textures.append(_atlas(variants, REGIONS[species * 2 + variant]))
	for texture: Texture2D in _textures:
		var pixels := texture.get_image()
		if pixels.is_compressed():
			pixels.decompress()
		var top: int = pixels.get_height()
		var bottom: int = 0
		for y: int in range(pixels.get_height()):
			for x: int in range(pixels.get_width()):
				if pixels.get_pixel(x, y).a >= 0.5:
					top = mini(top, y)
					bottom = maxi(bottom, y + 1)
		# Root-center sampling aligns asymmetric trunks with their fixed collider.
		var left: int = pixels.get_width()
		var right: int = 0
		for y: int in range(maxi(top, bottom - maxi(4, (bottom - top) / 12)), bottom):
			for x: int in range(pixels.get_width()):
				if pixels.get_pixel(x, y).a >= 0.5:
					left = mini(left, x)
					right = maxi(right, x)
		_baselines.append(float(bottom))
		_visible_heights.append(float(maxi(1, bottom - top)))
		_root_centers.append(float(left + right) * 0.5)


static func _variant_for(root: Node3D, species: int, preferred: int) -> int:
	var selected: int = preferred
	var best_clearance: float = -1.0
	for offset: int in range(VARIANT_COUNT):
		var variant: int = (preferred + offset) % VARIANT_COUNT
		var clearance: float = 100.0
		for neighbor: Node in root.get_tree().get_nodes_in_group("village_trees"):
			if neighbor == root or neighbor.get_parent() != root.get_parent():
				continue
			if neighbor.get_meta("tree_species", "") != SPECIES[species] or int(neighbor.get_meta("tree_variant", -1)) != variant:
				continue
			clearance = minf(clearance, root.position.distance_squared_to((neighbor as Node3D).position))
		if clearance > best_clearance:
			best_clearance = clearance
			selected = variant
	return selected


static func decorate(root: Node3D, at: Vector3, species_override: int = -1) -> void:
	_prepare()
	var key: int = absi(roundi(at.x * 37.0) + roundi(at.z * 71.0))
	var species: int = (key ^ (key >> 3) ^ (key >> 7)) % SPECIES.size()
	if at.x > 13.0 and at.z < -9.0:
		species = 3
	if species_override >= 0 and species_override < SPECIES.size():
		species = species_override
	var variant: int = _variant_for(root, species, (key ^ (key >> 5)) % VARIANT_COUNT)
	var index: int = species * VARIANT_COUNT + variant
	root.set_meta("tree_species", SPECIES[species])
	root.set_meta("tree_variant", variant)
	var sprite := Sprite3D.new()
	sprite.name = "TreeArt"
	sprite.texture = _textures[index]
	var stature: float = [1.0, 0.90, 1.04][variant]
	sprite.pixel_size = HEIGHTS[species] * stature * (0.88 + float(key % 7) * 0.025) / _visible_heights[index]
	sprite.flip_h = key % 2 == 0
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = true
	sprite.double_sided = true
	root.add_child(sprite)
	Grounding.anchor(sprite, sprite.texture, _baselines[index])
	sprite.offset.x = (float(sprite.texture.get_width()) * 0.5 - _root_centers[index]) * (-1.0 if sprite.flip_h else 1.0)
	sprite.remove_from_group("grounded_character_art")
	Grounding.add_shadow(root, 0.62 if species == 2 else 0.85)
