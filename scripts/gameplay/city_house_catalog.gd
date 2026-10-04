extends RefCounted
## Stable city addresses, room plans and dialogue; no persistent state here.
const Shops = preload("res://scripts/gameplay/city_shops.gd")
const POSITIONS := [
	Vector3(-24, 25, -0.6), Vector3(-10, 27, 0.6), Vector3(-29, 20, -0.2),
	Vector3(-34, 11, -1.4), Vector3(-34, 3, -1.6), Vector3(-23, 7, 1.3),
	Vector3(10, 24, 0.2), Vector3(-14, -3, -0.3), Vector3(-7, -3, -0.1),
	Vector3(-17, -14, 1.0), Vector3(-27, -24, -1.2),
	Vector3(-20, -31, 2.7), Vector3(-13, -33, 3.0), Vector3(-2, -32, -2.8),
	Vector3(6, -24, 1.6), Vector3(9, -9, -1.8), Vector3(15, -20, 2.8),
	Vector3(24, -19, 2.7), Vector3(29, -11, 1.3), Vector3(27, -3, 1.3),
	Vector3(15, -2, -1.4), Vector3(19, 3, -1.5), Vector3(25, 16, 0.3),
	Vector3(16, 19, 0.1), Vector3(7, 18, -0.3), Vector3(-1, 22, 0.0),
]

const TITLES := ["南門旅舍", "車伕之家", "行囊商舖", "西街織坊", "石匠居所", "溪風茶室", "水岸藥房", "抄書人之家", "舊街書鋪", "染布工坊", "石巷客舍", "西北藏書室", "守鐘人之家", "觀星書房", "北庭藥房", "工匠會客所", "陶器工坊", "東街織坊", "船具商舖", "東岸藥房", "匠人之家", "岸邊旅店", "南岸茶室", "花草商舖", "月帆商行", "市集住家"]
const KINDS := ["inn", "home", "shop", "workshop", "home", "inn", "herbalist", "library", "library", "workshop", "inn", "library", "home", "library", "herbalist", "home", "workshop", "workshop", "shop", "herbalist", "home", "inn", "inn", "herbalist", "shop", "home"]
const THEMES := {
	"inn": {"art": "rain", "furniture": "旅客留言簿", "text": "有人寫下明早要搭的船，也有人只留了一句謝謝。紙角沾著茶漬。", "line": "濕外衣掛門邊就好，別帶到床上。", "color": Color("b98162"), "width": 5.4, "depth": 6.3},
	"home": {"art": "ada", "furniture": "家用針線盒", "text": "盒裡放著補到一半的布偶，旁邊是一件袖口磨薄的外衣。", "line": "椅子上的衣服挪開就能坐，我還沒補完。", "color": Color("9c7589"), "width": 4.5, "depth": 5.5},
	"shop": {"art": "mira", "furniture": "到貨清單", "text": "繩索和布匹旁都寫著數量，最後一行的到貨日被改了兩次。", "line": "貨船還沒靠岸，手邊只剩不賣的樣品。", "color": Color("668e9c"), "width": 5.2, "depth": 5.8},
	"library": {"art": "owen", "furniture": "舊街巷圖", "text": "地圖邊上添了幾條小巷，還有人用小字註明哪家有賣熱餅。", "line": "看書前先擦乾手，這裡的紙已經夠潮了。", "color": Color("617e92"), "width": 4.6, "depth": 7.0},
	"workshop": {"art": "locke", "furniture": "工匠樣品架", "text": "架上放著布樣和小陶碗，尺寸寫在紙片上，壓著一顆石子。", "line": "桌邊有碎料，坐下前我先替你掃掃。", "color": Color("b88763"), "width": 5.7, "depth": 5.4},
	"herbalist": {"art": "seph", "furniture": "草藥栽培筆記", "text": "紙上記著澆水的日子，幾頁夾著乾葉，摸起來有些發脆。", "line": "窗邊那盆才冒新葉，先別碰它。", "color": Color("668c76"), "width": 5.0, "depth": 6.1},
}

static func index_of(id: String) -> int:
	if not id.begins_with("house_city_"):
		return -1
	var number := id.trim_prefix("house_city_")
	if not number.is_valid_int():
		return -1
	var index := int(number) - 1
	return index if index >= 0 and index < POSITIONS.size() and id == address(index) else -1

static func address(index: int) -> String:
	return "house_city_%02d" % (index + 1)

static func home(id: String) -> Dictionary:
	var index := index_of(id)
	if index < 0:
		return {}
	var at: Vector3 = POSITIONS[index]
	return {"id": id, "name": Shops.SHOPS[id].name if Shops.SHOPS.has(id) else TITLES[index], "position": Vector3(at.x, 0, at.y), "yaw": at.z, "kind": KINDS[index], "index": index}

static func resident(id: String) -> Dictionary:
	if Shops.SHOPS.has(id):
		var shop: Dictionary = Shops.SHOPS[id]
		return {"name": shop.owner, "art": "city_residents/" + str(shop.art), "tint": Color.WHITE, "text": shop.line}
	var info := home(id)
	var theme: Dictionary = THEMES[info.kind]
	return preload("res://scripts/gameplay/city_resident_catalog.gd").resident(int(info.index), str(theme.line))

static func furniture(id: String) -> Dictionary:
	if Shops.SHOPS.has(id):
		var shop: Dictionary = Shops.SHOPS[id]
		return {"name": shop.display, "text": shop.detail}
	var theme: Dictionary = THEMES[home(id).kind]
	return {"name": theme.furniture, "text": theme.text}

static func footprint(id: String) -> PackedVector2Array:
	var kind: String = home(id).kind
	var theme: Dictionary = THEMES[kind]
	var w: float = theme.width
	var d: float = theme.depth
	if kind in ["inn", "shop", "workshop"]:
		return PackedVector2Array([Vector2(-w, 3.5), Vector2(-w, -d + 2), Vector2(-w + 2, -d + 2), Vector2(-w + 2, -d), Vector2(w, -d), Vector2(w, 3.5)])
	return PackedVector2Array([Vector2(-w, 3.5), Vector2(-w, -d + 0.8), Vector2(-w + 1, -d), Vector2(w - 1, -d), Vector2(w, -d + 0.8), Vector2(w, 3.5)])
