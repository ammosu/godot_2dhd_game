extends RefCounted
const Proportions = preload("res://scripts/gameplay/character_proportions.gd")
## Four camera-relative facings, measured RGBA regions; presentation only.
const Appearance = preload("res://scripts/gameplay/equipment_appearance.gd")
const Movement = preload("res://scripts/gameplay/enemy_movement_art.gd")
const DATA: Dictionary = preload("res://assets/generated/action/regions.gd").DATA
const ARMED_WALK: Dictionary = preload("res://assets/generated/action/armed_walk_anchors.gd").DATA
const POSES: Array[String] = ["idle", "walk_a", "walk_b", "windup", "attack", "recover", "cast", "release", "dodge_a", "dodge_b", "hurt", "defeated"]
static var _cache: Dictionary[String, AtlasTexture] = {}

static func directional_texture(actor: String, pose_name: String, screen: Vector2, sprite: Sprite3D, loadout: Dictionary = {}) -> AtlasTexture:
	if actor == "wanderer":
		var diagonal := Appearance.ClassArt.diagonal_walking_texture(loadout, pose_name, screen)
		if diagonal != null:
			return diagonal
	if Movement.supports(actor, pose_name):
		var previous: int = int(sprite.get_meta("movement_facing", -1))
		var facing: int = Movement.direction(screen, previous)
		sprite.set_meta("movement_facing", facing)
		return Movement.texture_for(actor, pose_name, facing)
	# Re-enter locomotion from the actual heading after an attack or hit.
	if sprite.has_meta("movement_facing"):
		sprite.remove_meta("movement_facing")
	return texture_for(actor, pose_name, direction(screen), loadout)

static func direction(facing: Vector2) -> int:
	if absf(facing.y) > absf(facing.x):
		return 0 if facing.y >= 0 else 2
	return 1 if facing.x >= 0 else 3

static func pose(actor: Dictionary, moving: bool, clock: float) -> String:
	if int(actor.hp) <= 0:
		return "defeated"
	if float(actor.hurt) > 0:
		return "hurt"
	if float(actor.dash) > 0:
		return "dodge_a" if float(actor.dash) > 0.11 else "dodge_b"
	if float(actor.get("support_cast", 0.0)) > 0:
		return "release"
	var magic: bool = str(actor.art) in ["elder", "eclipse_mage"] or str(actor.get("hero_class", "")) == "mage"
	if float(actor.windup) > 0:
		return "cast" if magic else "windup"
	if float(actor.swing) > 0:
		return "release" if magic else "attack"
	if float(actor.get("recovery", 0.0)) > 0:
		return "recover"
	if moving:
		return ["walk_a", "idle", "walk_b", "idle"][int(clock * 10.0) % 4]
	return "idle"

static func texture_for(actor: String, pose_name: String, facing: int, loadout: Dictionary = {}) -> AtlasTexture:
	var variant: String = Appearance.variant(loadout, actor) if actor in ["wanderer", "noah", "elder"] else ""
	if variant.begins_with("class_"):
		return Appearance.ClassArt.texture_for(variant.trim_prefix("class_"), pose_name, facing)
	var sheet: String = variant if not variant.is_empty() else actor
	var frame: int = facing * 12 + maxi(0, POSES.find(pose_name))
	var key := "%s:%d" % [sheet, frame]
	if _cache.has(key):
		return _cache[key]
	var data: Dictionary = DATA[sheet]
	var box: Array = data.frames[frame]
	var texture := AtlasTexture.new()
	texture.atlas = load("res://assets/generated/action/%s.png" % sheet) as Texture2D
	texture.region = Rect2(float(box[0]), float(box[1]), float(box[2]), float(box[3]))
	texture.filter_clip = true
	texture.set_meta("ground_y", float(box[3]))
	texture.set_meta("anchor_x", float(box[4]) if box.size() > 4 else float(box[2]) * 0.5)
	# A swinging foot/sword is not a body pivot. Keep the walking head on the
	# idle axis; weapon-equipped exploration and arena share these textures.
	if actor == "wanderer" and pose_name in ["idle", "walk_a", "walk_b"] and ARMED_WALK.has(sheet):
		texture.set_meta("anchor_x", float(ARMED_WALK[sheet].anchors[facing][POSES.find(pose_name)]))
	# Normalize against standing body height within this facing, not the weapon
	# reach or crouched/dead frame height. Defeat must not grow to standing size.
	var idle: Array = data.frames[facing * 12]
	texture.set_meta("pixel_size", (0.8 if actor == "dusk_bat" else 1.45 if actor == "moss_wolf" else 1.88 if actor == "guardian" else 1.85 if actor == "noah" else 1.575) / float(idle[3]))
	if actor in ["wanderer", "noah", "elder"]:
		var standing := AtlasTexture.new()
		standing.atlas = texture.atlas
		standing.region = Rect2(idle[0], idle[1], idle[2], idle[3])
		standing.set_meta("anchor_x", float(idle[4]) if idle.size() > 4 else float(idle[2]) * 0.5)
		# Cache one reference per sheet/facing; all action poses share its fit.
		var reference_key := sheet + ":standing:" + str(facing)
		if not _cache.has(reference_key):
			_cache[reference_key] = standing
		Proportions.stamp(texture, _cache[reference_key], float(idle[3]))
	texture.set_meta("pose", pose_name)
	texture.set_meta("facing", facing)
	texture.set_meta("variant", variant)
	texture.set_meta("flip_h", actor == "moss_wolf" and facing == 1)
	_cache[key] = texture
	return texture
