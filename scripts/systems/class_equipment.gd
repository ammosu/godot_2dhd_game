extends RefCounted
## Vocation equipment is owned by the hero, never by companion inventories.
const DEFAULTS: Dictionary = {
	"traveler": {"weapon": "traveler_blade", "armor": "traveler_coat"},
	"archer": {"weapon": "willow_bow", "armor": "hunter_vest"},
	"mage": {"weapon": "apprentice_staff", "armor": "apprentice_robe"},
	"thief": {"weapon": "twin_daggers", "armor": "shadow_leathers"},
}
const ITEMS: Dictionary = {
	"willow_bow": {"class": "archer", "name": "柳木長弓", "slot": "weapon", "attack": 5, "defense": 0, "icon": "bow", "description": "弓箭手專用。輕彈的弓臂，射出直線穿透箭。"},
	"moonstring_bow": {"class": "archer", "name": "月弦獵弓", "slot": "weapon", "attack": 9, "defense": 0, "icon": "bow", "description": "弓箭手專用。銀月弓弦提高每支箭的傷害。"},
	"hunter_vest": {"class": "archer", "name": "林地獵裝", "slot": "armor", "attack": 0, "defense": 3, "icon": "vest", "description": "弓箭手專用。皮革胸衣與綠色短披肩。"},
	"ranger_mail": {"class": "archer", "name": "遊俠護甲", "slot": "armor", "attack": 0, "defense": 6, "icon": "vest", "description": "弓箭手專用。以輕鎖甲保護拉弓時暴露的側身。"},
	"apprentice_staff": {"class": "mage", "name": "霜晶法杖", "slot": "weapon", "attack": 6, "defense": 0, "icon": "staff", "description": "魔法師專用。凝聚魔力彈與霜星爆的冰藍晶杖。"},
	"winter_staff": {"class": "mage", "name": "凜冬權杖", "slot": "weapon", "attack": 11, "defense": 0, "icon": "staff", "description": "魔法師專用。更強的魔力核心，提高法術傷害。"},
	"apprentice_robe": {"class": "mage", "name": "星紋法袍", "slot": "armor", "attack": 0, "defense": 1, "icon": "robe", "description": "魔法師專用。銀線星紋的深藍法袍。"},
	"winter_robe": {"class": "mage", "name": "霜月祭袍", "slot": "armor", "attack": 0, "defense": 4, "icon": "robe", "description": "魔法師專用。冰晶護符與加厚襯裡抵擋衝擊。"},
	"twin_daggers": {"class": "thief", "name": "夜行雙匕", "slot": "weapon", "attack": 4, "defense": 0, "icon": "daggers", "description": "盜賊專用。兩把短匕，適合快攻與背後影襲。"},
	"crescent_daggers": {"class": "thief", "name": "殘月雙牙", "slot": "weapon", "attack": 8, "defense": 0, "icon": "daggers", "description": "盜賊專用。彎曲雙刃提高影襲與普攻傷害。"},
	"shadow_leathers": {"class": "thief", "name": "夜行輕甲", "slot": "armor", "attack": 0, "defense": 2, "icon": "leathers", "description": "盜賊專用。貼身皮甲與紫色兜帽，便於敏捷閃避。"},
	"phantom_leathers": {"class": "thief", "name": "幽影軟甲", "slot": "armor", "attack": 0, "defense": 5, "icon": "leathers", "description": "盜賊專用。關節補強的暗色軟甲。"},
}

static func defaults(class_id: String) -> Dictionary:
	return Dictionary(DEFAULTS.get(class_id, DEFAULTS.traveler)).duplicate(true)
