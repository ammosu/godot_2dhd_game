extends RefCounted
## Complete outfit/sword replacement atlases, shared by preview, exploration
## and battle. No original gear is rendered underneath a selected variant.
const ClassArt = preload("res://scripts/gameplay/class_art.gd")
const Grounding = preload("res://scripts/gameplay/sprite_grounding.gd")
const WALK: SpriteFrames = preload("res://assets/generated/wanderer_frames.tres")
const POSES: Array[String] = ["idle", "windup", "attack", "recover", "hurt", "guard", "defeated"]
const PAD := Vector2(48, 40)
static var _textures: Dictionary[String, Texture2D] = {}
static var _frames: Dictionary[String, SpriteFrames] = {}


static func variant(loadout: Dictionary, actor: String = "wanderer") -> String:
	if actor == "wanderer" and not ClassArt.vocation(loadout).is_empty():
		return "class_" + ClassArt.vocation(loadout)
	if actor != "wanderer":
		var armor := str(loadout.get("armor", "")) == ("dawn_plate" if actor == "noah" else "astral_robe")
		var weapon := str(loadout.get("weapon", "")) == ("dawn_partisan" if actor == "noah" else "astral_staff")
		return actor + "_both" if armor and weapon else actor + "_armor" if armor else actor + "_weapon" if weapon else ""
	var armor := str(loadout.get("armor", "")) == "moonward_cloak"
	var weapon := str(loadout.get("weapon", "")) == "moonsteel_saber"
	if armor and weapon:
		return "moonward_saber"
	return "moonward" if armor else "saber" if weapon else ""


static func texture_for(base: Texture2D, pose: String, loadout: Dictionary, actor: String = "wanderer") -> Texture2D:
	var id := variant(loadout, actor)
	if id.begins_with("class_"):
		return ClassArt.texture_for(id.trim_prefix("class_"), "idle" if pose.begins_with("walk_") or pose == "guard" else pose, int(ClassArt.FACINGS.get(pose.trim_prefix("walk_"), 0)))
	if id.is_empty():
		return base
	var original := base as AtlasTexture
	assert(original != null)
	var key := "%s:%s:%s:%s:%s" % [original.atlas.resource_path, original.region, original.margin, pose, id]
	if _textures.has(key):
		return _textures[key]
	# Diagonal outfits have independently measured crops, rather than the
	# cardinal atlas's fixed column/row layout.
	if original.has_meta("diagonal_frame"):
		var diagonals := load("res://assets/generated/equipment/%s_diagonal_frames.tres" % id) as SpriteFrames
		_textures[key] = diagonals.get_frame_texture(StringName(pose.trim_prefix("walk_")), int(original.get_meta("diagonal_frame")))
		return _textures[key]
	var family := "npc" if pose == "npc" else "walk" if pose.begins_with("walk_") else "transitions" if pose in ["windup", "recover"] else "defeated" if pose == "defeated" else "combat"
	var sheet_id := id
	if actor != "wanderer" and family in ["npc", "defeated"]:
		sheet_id = "party_" + id.trim_prefix(actor + "_")
	var sheet := load("res://assets/generated/equipment/%s_%s.png" % [sheet_id, family]) as Texture2D
	# Expand the crop into its surrounding empty cell to include the actual cape
	# and curved tip. Preserve original canvas origin; padding must not move feet.
	var origin := original.margin.position - original.region.position + PAD
	var bounds := Rect2(-origin, base.get_size() + PAD * 2.0)
	if family == "npc":
		bounds = bounds.intersection(original.region)
	elif family == "walk":
		var column := floorf(original.region.get_center().x / 320.0)
		var row := int(floorf(original.region.get_center().y / 312.0))
		var edges: Array[int] = [0, 326, 638, 948, 1280]
		bounds = bounds.intersection(Rect2(column * 320.0, edges[row], 320.0, edges[row + 1] - edges[row]))
	elif family == "combat":
		var left := pose in ["idle", "hurt"]
		var top := pose in ["idle", "attack"]
		var split := 575.0 if actor == "wanderer" else 620.0
		var row_split := 600.0 if actor == "wanderer" else 620.0
		bounds = bounds.intersection(Rect2(0 if left else split, 0 if top else row_split, split if left else 1280 - split, row_split if top else 1280 - row_split))
	elif family == "transitions":
		var split := 960.0 if actor == "noah" else 896.0
		bounds = bounds.intersection(Rect2(0 if pose == "windup" else split, 0, split, sheet.get_height()))
	else:
		var top := 0.0 if actor == "wanderer" else 430.0 if actor == "noah" else 830.0
		var bottom := 430.0 if actor == "wanderer" else 830.0 if actor == "noah" else float(sheet.get_height())
		bounds = bounds.intersection(Rect2(0, top, sheet.get_width(), bottom - top))
	bounds = bounds.intersection(Rect2(Vector2.ZERO, sheet.get_size()))
	var result := AtlasTexture.new()
	result.atlas = sheet
	result.region = bounds
	result.margin = Rect2(bounds.position + origin, base.get_size() + PAD * 2.0 - bounds.size)
	result.filter_clip = true
	result.set_meta("pose", pose)
	result.set_meta("variant", id)
	result.set_meta("canvas_padding", PAD)
	var ground: float = float(base.get_meta("ground_y")) if base.has_meta("ground_y") else Grounding.foot_baseline(base, 0.5)
	result.set_meta("ground_y", ground + PAD.y)
	result.set_meta("display_height", float(base.get_meta("display_height", 175.0)) * result.get_height() / base.get_height())
	_textures[key] = result
	return result


static func walking_frames(loadout: Dictionary) -> SpriteFrames:
	if not ClassArt.vocation(loadout).is_empty():
		return ClassArt.walking_frames(loadout)
	var id := variant(loadout)
	if id.is_empty():
		return WALK
	if _frames.has(id):
		return _frames[id]
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for direction: StringName in WALK.get_animation_names():
		frames.add_animation(direction)
		frames.set_animation_speed(direction, WALK.get_animation_speed(direction))
		frames.set_animation_loop(direction, WALK.get_animation_loop(direction))
		for index: int in range(WALK.get_frame_count(direction)):
			frames.add_frame(direction, texture_for(WALK.get_frame_texture(direction, index), "walk_" + str(direction), loadout))
	_frames[id] = frames
	return frames
