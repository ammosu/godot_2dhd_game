extends RefCounted
## Prologue films: waking in the fog, the whisper and moonbeam, and the collapse at the
## village with the dream that follows. Pure data for CutscenePlayer; the traveler is the
## live player actor. Lines and progress stay with prologue.gd.

## Slow, unsteady steps for an exhausted traveler reaching the village.
const WEARY_WALK_SPEED: float = 1.2


## World rule, then a low point-of-view that opens from black and rises out of the murk.
static func waking() -> Array[Dictionary]:
	return [
		{
			"duration": 6.0, "black": true, "letterbox": false,
			"caption": "夜裡會起霧。\n霧會讓人迷路，忘記回家的路。",
		},
		{
			# The traveler stands behind the lens so only the foggy road is seen.
			"duration": 8.5, "map": "east_road", "spawn": "prologue_wake", "music": "ruins",
			"fade_in": 2.6, "fov": 50.0, "actor_at": Vector3(12.6, 0.0, 5.0),
			"camera": {"from": Vector3(10.2, 0.45, 5.3), "to": Vector3(9.8, 1.45, 5.1),
				"look_from": Vector3(6.0, 7.5, 2.0), "look_to": Vector3(-2.0, 0.9, 5.0)},
			"events": [{"at": 0.0, "id": "waking_fog"}],
			"speaker": "旅人", "caption": "……這裡是哪裡？",
			"fade_out": 0.9,
		},
	]


## The whisper finds the traveler wherever the second clue was read.
static func whisper() -> Array[Dictionary]:
	return [
		{
			"duration": 5.5, "fade_in": 0.4, "fov": 36.0,
			"camera": {"track": true, "from": Vector3(-2.6, 1.5, 3.4), "to": Vector3(-1.6, 1.25, 2.2),
				"look_from": Vector3(-0.4, 1.05, 0.0), "look_to": Vector3(-0.5, 1.05, 0.0)},
			"events": [{"at": 1.6, "id": "road_whisper"}],
			"acts": [{"at": 1.8, "who": "actor", "act": "surprise", "emote": "question"}],
			"speaker": "低語", "caption": "……往西走。那裡還有一盞燈。",
		},
	]


## The clouds part over the road west and the moon marks the way.
static func moonbeam() -> Array[Dictionary]:
	return [
		{
			"duration": 5.0, "fov": 42.0,
			"camera": {"track": true, "from": Vector3(3.2, 2.0, 3.0), "to": Vector3(2.8, 2.3, 2.6),
				"look_from": Vector3(-5.0, 1.4, 0.0), "look_to": Vector3(-6.0, 2.6, 0.0)},
			"events": [{"at": 0.6, "id": "moonbeam"}],
			"caption": "只有月光，能穿過霧。",
			"fade_out": 0.6,
		},
	]


## The village gate, the north gate's answer, the collapse, and the dream three days on.
static func arrival() -> Array[Dictionary]:
	return [
		{
			"duration": 6.0, "map": "village", "spawn": "from_east_road", "music": "village",
			"fade_in": 1.2, "fov": 40.0, "actor_at": Vector3(23.5, 0.0, 4.6),
			"actor_path": [Vector3(19.0, 0.0, 4.6)], "actor_speed": WEARY_WALK_SPEED,
			"camera": {"look_actor": true, "from": Vector3(26.4, 2.5, 4.9), "to": Vector3(26.2, 2.8, 4.8),
				"look_from": Vector3(0.0, 0.9, 0.0), "look_to": Vector3(-2.0, 0.6, 0.0)},
			"acts": [{"at": 4.2, "who": "actor", "act": "shiver", "emote": "none"}],
			"caption": "暮光村。",
		},
		{
			"duration": 6.5, "fov": 38.0, "actor_at": Vector3(19.0, 0.0, 4.6),
			"actor_face": Vector3(0.0, 0.0, -19.3),
			"camera": {"from": Vector3(-3.4, 2.3, -10.5), "to": Vector3(-2.2, 2.7, -12.6),
				"look_from": Vector3(0.0, 1.5, -19.3), "look_to": Vector3(0.0, 1.7, -19.3)},
			"events": [{"at": 1.6, "id": "gate_glow"}],
			"caption": "那一夜，關了十二年的北門，月紋微微亮了一下。",
		},
		{
			# The lens sinks with the traveler as the strength gives out.
			"duration": 4.0, "fov": 38.0, "actor_at": Vector3(19.0, 0.0, 4.6),
			"actor_face": Vector3(16.0, 0.0, 4.6),
			"camera": {"from": Vector3(16.6, 1.4, 6.6), "to": Vector3(17.3, 0.55, 6.0),
				"look_from": Vector3(19.0, 1.1, 4.6), "look_to": Vector3(19.0, 0.35, 4.6)},
			"acts": [{"at": 0.5, "who": "actor", "act": "shiver", "emote": "ellipsis"}, {"at": 2.0, "who": "actor", "act": "recoil", "emote": "none"}],
			"fade_out": 1.8,
		},
		{"duration": 4.0, "black": true, "speaker": "？？？", "caption": "媽媽！路上有人倒下了！"},
		{"duration": 5.0, "black": true, "caption": "那一夜之後，月光再也沒有照進暮光村。"},
		{
			"duration": 5.5, "black": true, "letterbox": false,
			"title": "Wanderlight: Moon Shard", "subtitle": "序章〈熄滅的月燈〉",
		},
		{"duration": 3.0, "black": true, "caption": "三天後。"},
		# The dream: the oldest memories first, then the road that led here.
		{"duration": 4.8, "black": true, "speaker": "記憶", "caption": "……很多盞燈，在霧裡排成一列。有一隻很大的手，牽著我。"},
		{
			"duration": 4.8, "black": true, "speaker": "記憶", "caption": "咚、咚、咚。有人一直在敲門，敲了很久。",
			"events": [{"at": 0.6, "id": "dream_knock"}],
		},
		{"duration": 4.8, "black": true, "speaker": "記憶", "caption": "門沒有開。燈一盞一盞熄了。"},
		{"duration": 4.8, "black": true, "speaker": "記憶", "caption": "霧裡，有一盞燈朝我走過來。「別怕，跟著光走。」"},
		{"duration": 4.8, "black": true, "speaker": "記憶", "caption": "冷掉的路燈。倒在泥裡的路標。然後，是一個孩子的聲音——"},
	]
