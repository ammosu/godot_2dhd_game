extends RefCounted
## Stable house identities shared by entrances, interiors and return spawns.

const City = preload("res://scripts/gameplay/city_house_catalog.gd")

const EXTERIOR_SCALE := Vector3(1.15, 1.08, 1.15)
const INTERIOR_CHARACTER_SCALE: float = 1.35
const EXTERIOR_COLLISION := Vector3(4.0, 2.3, 3.2) * EXTERIOR_SCALE

const HOMES: Array[Dictionary] = [
	{"id": "house_01", "name": "西街木屋", "position": Vector3(-12.7, 0, -8.5), "yaw": -PI * 0.5 + 0.13, "wall": Color("806967"), "roof": Color("59465f")},
	{"id": "house_02", "name": "花園小屋", "position": Vector3(-11.5, 0, 0.6), "yaw": -PI * 0.5 - 0.16, "wall": Color("73736a"), "roof": Color("5a4965")},
	{"id": "house_03", "name": "東街居所", "position": Vector3(12.6, 0, -3.4), "yaw": PI * 0.5 - 0.12, "wall": Color("667776"), "roof": Color("47566b")},
	{"id": "house_04", "name": "陶匠小屋", "position": Vector3(12.6, 0, 9.2), "yaw": 0.08, "wall": Color("826b61"), "roof": Color("654957")},
	{"id": "house_05", "name": "南街暖屋", "position": Vector3(-11.8, 0, 10.4), "yaw": -0.14, "wall": Color("765f70"), "roof": Color("50445f")},
	{"id": "house_06", "name": "旅人居所", "position": Vector3(-5.0, 0, 12.0), "yaw": 0.18, "wall": Color("6c747d"), "roof": Color("46536a")},
	{"id": "house_07", "name": "東南小屋", "position": Vector3(6.3, 0, 13.4), "yaw": 0.1, "wall": Color("706a80"), "roof": Color("514b6e")},
	{"id": "house_08", "name": "北街書屋", "position": Vector3(-6.4, 0, -11.6), "yaw": PI + 0.16, "wall": Color("7f725d"), "roof": Color("624b51")},
]


# Each resident has original profession-specific art; preserve its authored colors.
const RESIDENTS: Dictionary = {
	"house_01": {"name": "織工・米菈", "art": "residents/mira", "tint": Color.WHITE, "text": "進來歇歇腳吧。布上的菱形是祖母教我的老花樣，她說那是路口的形狀。"},
	"house_02": {"name": "園丁・芙蘿", "art": "residents/flo", "tint": Color.WHITE, "text": "小心門邊的花。這些幼苗最近都垂著頭，等月光回來，它們就會抬起來了。"},
	"house_03": {"name": "觀月人・席恩", "art": "residents/sien", "tint": Color.WHITE, "text": "月光其實偏了很多年，只是三天前突然整個不見——就是你來的那晚。"},
	"house_04": {"name": "陶匠・洛克", "art": "residents/locke", "tint": Color.WHITE, "text": "陶器還沒乾，別碰倒了。老碗的底下都印著一個缺口的圓圈，現在沒人這樣做了。"},
	"house_05": {"name": "裁縫・艾妲", "art": "residents/ada", "tint": Color.WHITE, "text": "你的外衣補好了，放在床邊。燈再暗，也得讓回家的人有個暖和的地方。"},
	"house_06": {"name": "旅人・雷恩", "art": "residents/rain", "tint": Color.WHITE, "text": "我本來只想住一晚，北門卻一直沒開。等路通了，我想去看看山那邊。"},
	"house_07": {"name": "藥師・賽芙", "art": "residents/seph", "tint": Color.WHITE, "text": "這些草藥正在陰乾，有點苦。筆記裡有幾種只長在舊路邊，現在採不到了。"},
	"house_08": {"name": "藏書人・歐文", "art": "residents/owen", "tint": Color.WHITE, "text": "書可以翻，輕一點。村子的舊紀錄少了幾頁，撕得很整齊……是誰撕的呢？"},
}


# Fixed street identities share names/art with their homes, but have outdoor lines.
const STREET_PATROLS: Array[Dictionary] = [
	{"house_id": "house_02", "text": "我每天都來廣場看看花。今天風很輕，正好帶幼苗出來曬一下。"},
	{"house_id": "house_01", "text": "織布坐久了，得出來走走。看看大家衣服的顏色，常常就有新點子。"},
	{"house_id": "house_08", "text": "讀不懂的地方，我就沿著北街散步。走到路口，答案有時就自己冒出來了。"},
]


const FURNITURE: Dictionary = {
	"house_01": {"name": "織布架", "text": "半織好的布上，菱形一個接一個。仔細看，像是很多條路交會在一起。"},
	"house_02": {"name": "育苗工作架", "text": "三盆幼苗沒有朝著窗戶，而是一起朝村外長。盆邊的舊字條寫著：『月光回來的時候，它們會這樣。』"},
	"house_03": {"name": "月相紀錄架", "text": "一疊很多年的紀錄。月亮每晚都在，照進村子的光卻一年比一年偏。"},
	"house_04": {"name": "晾陶架", "text": "舊陶器底下都壓著缺口的圓環印，新做的碗卻沒有。沒人記得為什麼不印了。"},
	"house_05": {"name": "布料櫃", "text": "布料依顏色排好。最上面那件，是剛補好的旅人外衣，針腳很細。"},
	"house_06": {"name": "旅人裝備架", "text": "架上留著很多不同大小的舊行囊。最裡面那個繫著褪色的木牌：『商隊・十二年前・北門』。"},
	"house_07": {"name": "草藥架", "text": "乾草藥旁寫著陌生的地名。筆記說，那些地方要走北門外的路才到得了。"},
	"house_08": {"name": "藏書閱讀櫃", "text": "村子的由來有兩種寫法，互相對不上。夾頁裡有整齊的撕痕，提到『守路的人』的那幾頁都不見了。"},
}


static func find_home(map_id: String) -> Dictionary:
	if City.index_of(map_id) >= 0:
		return City.home(map_id)
	for home: Dictionary in HOMES:
		if home.id == map_id:
			return home
	return {}


static func is_interior(map_id: String) -> bool:
	return not find_home(map_id).is_empty()


static func return_position(map_id: String) -> Vector3:
	var home := find_home(map_id)
	if home.is_empty():
		return Vector3(0, 0.1, 7.5)
	return (home.position as Vector3) + Basis(Vector3.UP, float(home.yaw)) * Vector3(0, 0.1, -2.85 * EXTERIOR_SCALE.z)


static func safe_village_position(position: Vector3) -> Vector3:
	# Old saves retain world coordinates. Relocate only points now inside an
	# expanded home (including the player's radius), without rewriting the save.
	for home: Dictionary in HOMES:
		var local: Vector3 = Basis(Vector3.UP, -float(home.yaw)) * (position - (home.position as Vector3))
		var half_size: Vector3 = EXTERIOR_COLLISION * 0.5
		if absf(local.x) < half_size.x + 0.3 and absf(local.z) < half_size.z + 0.3 and local.y < EXTERIOR_COLLISION.y:
			return return_position(home.id)
	return position


static func parent_map(map_id: String) -> String:
	return "starbay" if City.index_of(map_id) >= 0 else "village"

static func resident(map_id: String) -> Dictionary:
	return City.resident(map_id) if City.index_of(map_id) >= 0 else RESIDENTS[map_id]

static func furniture(map_id: String) -> Dictionary:
	return City.furniture(map_id) if City.index_of(map_id) >= 0 else FURNITURE[map_id]
