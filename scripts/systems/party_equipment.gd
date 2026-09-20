extends RefCounted
## Character compatibility and defaults; persistent selections live in GameState.
const ACTORS: Array[String] = ["wanderer", "noah", "elder"]
const NAMES: Dictionary = {"wanderer": "旅人", "noah": "諾亞", "elder": "長老"}
const BASE_STATS: Dictionary = {"wanderer": Vector2i(14, 2), "noah": Vector2i(13, 3), "elder": Vector2i(11, 1)}
const DEFAULTS: Dictionary = {
	"wanderer": {"weapon": "traveler_blade", "armor": "traveler_coat"},
	"noah": {"weapon": "watch_spear", "armor": "watch_mail"},
	"elder": {"weapon": "lantern_staff", "armor": "sage_robe"},
}
const ITEMS: Dictionary = {
	"watch_spear": {"actor": "noah", "name": "守門長槍", "slot": "weapon", "attack": 4, "defense": 0, "description": "木柄鋼尖的長槍，守護村莊的老夥伴。"},
	"dawn_partisan": {"actor": "noah", "name": "曙光翼槍", "slot": "weapon", "attack": 8, "defense": 0, "description": "赤紅槍桿與金翼刃，鑲嵌晨光紅晶。"},
	"watch_mail": {"actor": "noah", "name": "守門甲衣", "slot": "armor", "attack": 0, "defense": 3, "description": "銀甲與藍色罩衣，守門人的熟悉裝束。"},
	"dawn_plate": {"actor": "noah", "name": "曙光鎧甲", "slot": "armor", "attack": 0, "defense": 7, "description": "象牙白金邊鎧甲，配上赤紅戰袍。"},
	"lantern_staff": {"actor": "elder", "name": "引燈木杖", "slot": "weapon", "attack": 4, "defense": 0, "description": "懸著小燈的彎木杖，指引迷途之人。"},
	"astral_staff": {"actor": "elder", "name": "星月法杖", "slot": "weapon", "attack": 9, "defense": 0, "description": "銀月托起紫晶，星光沿靛色杖身流動。"},
	"sage_robe": {"actor": "elder", "name": "長老法袍", "slot": "armor", "attack": 0, "defense": 2, "description": "藍金法袍與暖色披肩，承載村莊的記憶。"},
	"astral_robe": {"actor": "elder", "name": "星辰祭袍", "slot": "armor", "attack": 0, "defense": 5, "description": "深紫星紋長袍，搭配珍珠灰月石披肩。"},
}


static func defaults(actor: String) -> Dictionary:
	return Dictionary(DEFAULTS.get(actor, {})).duplicate(true)
