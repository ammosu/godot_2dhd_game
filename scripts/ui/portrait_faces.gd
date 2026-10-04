extends RefCounted
## Square face crops cut from existing character art; no separate portrait
## bitmaps. Shared by party status cards and the dialogue box.
const ClassArt = preload("res://scripts/gameplay/class_art.gd")

## Combat-atlas crops used by the party cards.
const COMBAT_FACES: Dictionary = {
	"wanderer": Rect2(216, 96, 224, 224),
	"noah": Rect2(190, 76, 200, 200),
	"elder": Rect2(245, 62, 258, 258),
}
## Standing-art crops for story speakers: [atlas path, region].
const NPC_FACES: Dictionary = {
	"elder": ["res://assets/generated/village_npcs.png", Rect2(311, 46, 212, 212)],
	"rumi": ["res://assets/generated/village_npcs.png", Rect2(976, 116, 210, 210)],
	"noah": ["res://assets/generated/village_npcs.png", Rect2(1684, 52, 184, 184)],
	"guardian": ["res://assets/generated/guardian_poses.png", Rect2(262, 40, 176, 176)],
	"sia": ["res://assets/generated/residents/sia_walk.png", Rect2(92, 16, 114, 114)],
}
## Dialogue speaker names mapped to a face; "hero" follows the chosen class.
const SPEAKERS: Dictionary = {
	"長老・艾爾": "elder",
	"長老": "elder",
	"村童・露米": "rumi",
	"守門人・諾亞": "noah",
	"諾亞": "noah",
	"遺跡守衛": "guardian",
	"旅人": "hero",
	"鐘守・希雅": "sia",
	"希雅": "sia",
}


## Party card face for `art` ("wanderer", "noah", "elder").
static func combat_face(art: String, vocation: String, female: bool) -> AtlasTexture:
	if art == "wanderer" and (vocation != "traveler" or female):
		return hero_face(vocation, female)
	var face := AtlasTexture.new()
	face.atlas = load("res://assets/generated/%s_combat.png" % art) as Texture2D
	face.region = COMBAT_FACES[art]
	face.filter_clip = true
	return face


## The player's face for their class and body, from the class idle art.
static func hero_face(vocation: String, female: bool) -> AtlasTexture:
	if vocation == "traveler" and not female:
		return combat_face("wanderer", vocation, female)
	var source := ClassArt.texture_for("female_" + vocation if female else vocation, "idle")
	var side: float = source.region.size.y * 0.52
	var face := AtlasTexture.new()
	face.atlas = source.atlas
	face.region = Rect2(source.region.position + Vector2(float(source.get_meta("anchor_x")) - side * 0.5, 0), Vector2.ONE * side)
	face.filter_clip = true
	return face


## Face id for a dialogue speaker, or "" when the speaker has no portrait.
static func speaker_face_id(speaker: String) -> String:
	return str(SPEAKERS.get(speaker, ""))


static func npc_face(id: String) -> AtlasTexture:
	var entry: Array = NPC_FACES[id]
	var face := AtlasTexture.new()
	face.atlas = load(entry[0]) as Texture2D
	face.region = entry[1]
	face.filter_clip = true
	return face
