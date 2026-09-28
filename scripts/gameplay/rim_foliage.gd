extends RefCounted
## Hill-foot shrubs, ferns and mossy stones from one 4 x 3 generated atlas.
## Crops and root baselines are measured from alpha, not assumed from the grid.

const Grounding = preload("res://scripts/gameplay/sprite_grounding.gd")
const SHRUBS: Array[int] = [0, 1, 2, 3]
const FERNS: Array[int] = [4, 5, 6, 7]
const STONES: Array[int] = [8, 9, 10, 11]
## Rendered height in metres per cell; stones vary most.
const HEIGHTS: Array[float] = [1.05, 0.85, 1.0, 1.15, 0.8, 0.95, 1.0, 0.9, 1.1, 0.55, 0.6, 1.45]
static var _textures: Array[AtlasTexture] = []
static var _baselines: Array[float] = []


static func _prepare() -> void:
	if not _textures.is_empty():
		return
	var sheet := load("res://assets/generated/village_rim_foliage.png") as Texture2D
	var image := sheet.get_image()
	if image.is_compressed():
		image.decompress()
	var cell := Vector2i(image.get_width() / 4, image.get_height() / 3)
	for index: int in range(12):
		var origin := Vector2i(index % 4, index / 4) * cell
		var used: Rect2i = image.get_region(Rect2i(origin, cell)).get_used_rect()
		var texture := AtlasTexture.new()
		texture.atlas = sheet
		texture.region = Rect2(Rect2i(origin + used.position, used.size).grow(2).intersection(Rect2i(origin, cell)))
		_textures.append(texture)
		var crop: Image = image.get_region(Rect2i(texture.region))
		_baselines.append(float(crop.get_used_rect().end.y))


## One grounded billboard; `tone` darkens pieces further into the woods.
static func place(parent: Node3D, at: Vector3, index: int, scale: float, flip: bool, tone: Color = Color("b4c2b6")) -> Sprite3D:
	_prepare()
	var holder := Node3D.new()
	holder.name = "RimStone" if index in STONES else "RimFoliage"
	holder.position = at
	parent.add_child(holder)
	var sprite := Sprite3D.new()
	sprite.texture = _textures[index]
	sprite.pixel_size = HEIGHTS[index] * scale / _textures[index].get_height()
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	# Painted with its own light; `tone` sets the night exposure.
	sprite.shaded = false
	sprite.double_sided = true
	sprite.flip_h = flip
	sprite.modulate = tone
	holder.add_child(sprite)
	Grounding.anchor(sprite, sprite.texture, _baselines[index])
	sprite.remove_from_group("grounded_character_art")
	return sprite
