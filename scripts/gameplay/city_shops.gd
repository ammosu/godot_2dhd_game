extends RefCounted
## Shop identities and original mesh dressing; existing addresses remain save-compatible.
const Build = preload("res://scripts/gameplay/japanese_house.gd")
const SHOPS := {
	"house_city_03": {"name": "鐵砧武器店", "kind": "weapon", "owner": "布倫・武器匠", "art": "blacksmith", "color": Color("a36045"), "upper": false,
		"line": "歡迎來到鐵砧武器店。劍架上的長劍都經過配重，握把也纏了防滑皮革。出城前，可以打開裝備介面替隊伍挑選趁手的武器。", "display": "鍛造武器展示架", "detail": "長劍依重量排在木架上；鐵砧旁留下打磨的細屑。這裡展示武器，目前尚未開放買賣。"},
	"house_city_25": {"name": "織盾裝備店", "kind": "armor", "owner": "茜・裝備裁縫", "art": "silk_merchant", "color": Color("527f95"), "upper": true,
		"line": "織盾裝備店歡迎你。皮甲、披風和盾牌都要合身，走遠路才不會累。樓上是裁縫工作間，樓下可以看看護具，再到裝備介面調整隊伍的行裝。", "display": "盾甲與披風樣品", "detail": "木製人台披著藍色旅行斗篷，旁邊的盾牌包了金屬邊。展示品保留了皮革縫線與扣帶，目前尚未開放買賣。"},
	"house_city_07": {"name": "月露藥水店", "kind": "potion", "owner": "白朮・藥水師", "art": "apothecary", "color": Color("537e66"), "upper": false,
		"line": "這裡是月露藥水店。紅瓶是回復藥，藍瓶是調配中的月露，請別拿錯了。窗邊晾著草藥，架上的藥瓶避開爐火保存；目前先開放參觀。", "display": "藥瓶與調製筆記", "detail": "紅、藍、綠色藥瓶依用途分層收好，每瓶都繫著標籤。藥師正在整理供貨，藥水買賣尚未開放。"},
	"house_city_01": {"name": "月帆旅店", "kind": "inn", "owner": "小春・旅店掌櫃", "art": "tea_master", "color": Color("996552"), "upper": true,
		"line": "歡迎住進月帆旅店。先喝杯熱茶，床鋪已經整理好了。到客房旁的休息處歇一會兒，就能恢復生命與魔力；這次住宿由商會招待。", "display": "旅店住宿簿", "detail": "住宿簿夾著商道地圖，櫃台後掛著房間鑰匙。低矮的樓上是客房外觀，現可活動的室內為一樓接待與雙床休息區。"},
}

static func exterior(house: Node3D, id: String) -> void:
	var shop: Dictionary = SHOPS[id]
	house.add_to_group("city_shops")
	house.set_meta("shop_kind", shop.kind)
	var root := Node3D.new()
	root.name = "ArchitecturalDetails"
	house.add_child(root)
	var wood := Build.material("timber_albedo.png", Color("947b60"))
	var wall := Build.material("plaster_albedo.png", Color("e7dbc2"))
	var stone := Build.material("ruin_flagstone.png", Color("9d9995"))
	var cloth := preload("res://scripts/gameplay/cloth_material.gd").make((shop.color as Color).lightened(0.22))
	var canvas := preload("res://scripts/gameplay/cloth_material.gd").make(Color("eee0cb"))
	var roof := Build.material("slate_roof_albedo.png", (shop.color as Color).lightened(0.18))
	var glow := Build.material("linen_albedo.png", Color("ffe3a3"))
	glow.emission_enabled = true
	glow.emission = Color("eac184")
	glow.emission_energy_multiplier = 0.35
	Build.box(root, "Foundation", Vector3(0, 0.17, 0), Vector3(4.18, 0.34, 3.4), stone)
	for side: float in [-1, 1]:
		Build.box(root, "ShopWing", Vector3(side * 1.205, 1.18, 0), Vector3(1.59, 1.96, 3.2), wall)
	Build.box(root, "Lintel", Vector3(0, 1.92, 0), Vector3(0.82, 0.48, 3.2), wall)
	Build.box(root, "Recess", Vector3(0, 0.91, 0.41), Vector3(0.82, 1.42, 2.38), wood)
	preload("res://scripts/gameplay/house_details.gd")._build_door(root, wood)
	for x: float in [-1.98, -0.49, 0.49, 1.98]:
		Build.box(root, "FacadePost", Vector3(x, 1.18, -1.65), Vector3(0.13, 1.98, 0.13), wood)
	for side: float in [-1, 1]:
		Build.lattice(root, Vector3(side * 1.22, 1.25, -1.71), 0, wood, glow)
		Build.lattice(root, Vector3(side * 2.03, 1.25, 0), PI * 0.5, wood, glow)
	var eave: float = 2.22
	if bool(shop.upper):
		# A shallow second storey + flattened roof keeps the skyline below 4.4 units.
		Build.box(root, "UpperStorey", Vector3(0, 2.72, 0), Vector3(3.96, 1.1, 3.14), wall)
		for y: float in [2.20, 3.24]:
			Build.box(root, "StoreyBelt", Vector3(0, y, 0), Vector3(4.2, 0.12, 3.4), wood)
		for side: float in [-1, 1]:
			for x: float in [-1.17, 1.17]:
				var win := Node3D.new()
				root.add_child(win)
				win.position = Vector3(x, 2.73, side * 1.65)
				win.scale = Vector3(0.72, 0.64, 1)
				Build.lattice(win, Vector3.ZERO, 0, wood, glow)
			Build.box(root, "UpperPost", Vector3(side * 1.98, 2.72, -1.64), Vector3(0.12, 1.1, 0.14), wood)
		eave = 3.3
	var roof_root := Node3D.new()
	roof_root.name = "LowRoof"
	root.add_child(roof_root)
	roof_root.scale.y = 0.58
	roof_root.position.y = eave - 2.22 * 0.58
	Build.roof(roof_root, roof, wood, wall)
	# Awning has a scalloped stripe edge and never crosses the walk-in door below 1.9.
	for index: int in range(10):
		var tint: Material = cloth if index % 2 == 0 else canvas
		var canopy := Build.box(root, "ShopAwning", Vector3(-1.98 + index * 0.44, 2.1, -2.0), Vector3(0.44, 0.06, 0.8), tint)
		canopy.rotation.x = -0.14
		Build.box(root, "AwningValance", Vector3(-1.98 + index * 0.44, 1.97, -2.4), Vector3(0.43, 0.19, 0.045), tint)
	Build.box(root, "SignBracket", Vector3(2.13, 2.65, -1.89), Vector3(0.13, 0.13, 1.0), wood)
	Build.box(root, "HangingSign", Vector3(2.13, 2.25, -2.35), Vector3(0.8, 0.7, 0.10), wood)
	var icon := Node3D.new()
	root.add_child(icon)
	icon.position = Vector3(2.13, 2.05, -2.43)
	icon.scale = Vector3.ONE * 0.52
	emblem(icon, str(shop.kind), glow, cloth)
	var label := Label3D.new()
	label.name = "ShopName"
	label.text = str(shop.name)
	label.font = load("res://assets/fonts/SourceHanSansTW-Regular.otf") as Font
	label.font_size = 48
	label.pixel_size = 0.0037
	label.position = Vector3(0, 2.48, -1.86)
	label.rotation.y = PI
	Build.box(root, "ShopNameBoard", Vector3(0, 2.48, -1.8), Vector3(1.72, 0.30, 0.07), wood)
	label.modulate = Color("fff0cc")
	label.outline_size = 6
	root.add_child(label)
	if shop.kind == "weapon":
		Build.box(root, "ForgeChimney", Vector3(-1.45, 2.65, 0.65), Vector3(0.6, 1.45, 0.65), stone)
		for x: float in [-1.77, -1.13]:
			Build.box(root, "ChimneyRim", Vector3(x, 3.42, 0.65), Vector3(0.13, 0.12, 0.79), stone)
		for z: float in [0.32, 0.98]:
			Build.box(root, "ChimneyRim", Vector3(-1.45, 3.42, z), Vector3(0.54, 0.12, 0.13), stone)
	elif shop.kind == "potion":
		for side: float in [-1, 1]:
			Build.box(root, "HerbWindowBox", Vector3(side * 1.2, 0.65, -1.92), Vector3(1.05, 0.22, 0.3), wood)
			for sprig: int in range(5):
				var leaf := Build.box(root, "HerbSprig", Vector3(side * 1.2 - 0.4 + sprig * 0.2, 0.88, -1.92), Vector3(0.11, 0.29 + (sprig % 2) * 0.12, 0.14), cloth)
				leaf.rotation.z = (sprig - 2) * 0.16
	Build.lantern(root, Vector3(-1.9, 1.65, -2.05), wood, glow)
	var display := Node3D.new()
	display.name = "ShopWindowDisplay"
	root.add_child(display)
	display.position = Vector3(1.22, 0.32, -1.9)
	display.scale = Vector3.ONE * 0.7
	Build.box(display, "DisplayPlinth", Vector3(0, 0.16, 0), Vector3(1.25, 0.32, 0.48), wood)
	display_goods(display, str(shop.kind), Vector3(0, 0.35, 0), wood, cloth)

static func emblem(parent: Node3D, kind: String, metal: Material, accent: Material) -> void:
	match kind:
		"weapon":
			Build.box(parent, "Blade", Vector3(0, 0.58, 0), Vector3(0.13, 0.7, 0.06), metal)
			Build.box(parent, "Guard", Vector3(0, 0.22, 0), Vector3(0.45, 0.07, 0.1), metal)
			Build.box(parent, "Grip", Vector3(0, 0.10, 0), Vector3(0.09, 0.22, 0.08), accent)
		"armor":
			var shield := Build.box(parent, "Shield", Vector3(0, 0.48, 0), Vector3(0.58, 0.68, 0.12), metal)
			Build.box(shield, "ShieldFace", Vector3(0, 0, -0.08), Vector3(0.47, 0.56, 0.07), accent)
			Build.box(shield, "ShieldBoss", Vector3(0, 0, -0.14), Vector3(0.13, 0.13, 0.09), metal)
		"potion":
			bottle(parent, Vector3(0, 0.02, 0), accent, metal, 1.6)
		"inn":
			Build.box(parent, "BedSymbol", Vector3(0, 0.35, 0), Vector3(0.8, 0.20, 0.1), metal)
			for x: float in [-0.37, 0.37]:
				Build.box(parent, "BedPost", Vector3(x, 0.27, 0), Vector3(0.09, 0.5, 0.1), metal)
			Build.box(parent, "Pillow", Vector3(-0.23, 0.5, 0), Vector3(0.22, 0.12, 0.13), accent)

static func bottle(parent: Node3D, at: Vector3, color: Material, cork: Material, size: float = 1.0) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.10 * size
	mesh.bottom_radius = 0.16 * size
	mesh.height = 0.32 * size
	mesh.radial_segments = 8
	var vial := MeshInstance3D.new()
	vial.name = "PotionBottle"
	vial.mesh = mesh
	vial.material_override = color
	vial.position = at + Vector3.UP * 0.16 * size
	parent.add_child(vial)
	Build.box(parent, "BottleCork", at + Vector3.UP * 0.36 * size, Vector3(0.13, 0.1, 0.13) * size, cork)
	Build.box(parent, "BottleLabel", at + Vector3(0, 0.17, -0.145) * size, Vector3(0.15, 0.12, 0.025) * size, cork)

static func display_goods(parent: Node3D, kind: String, at: Vector3, wood: Material, cloth: Material) -> void:
	var goods := Node3D.new()
	goods.name = "ProfessionGoods"
	goods.position = at
	parent.add_child(goods)
	var metal := Build.material("plaster_albedo.png", Color("c4d4d6"))
	if kind == "potion":
		for i: int in range(3):
			var tint := StandardMaterial3D.new()
			tint.albedo_color = [Color("ad4959"), Color("4e99b5"), Color("69a772")][i]
			bottle(goods, Vector3((i - 1) * 0.36, 0, 0), tint, wood)
	elif kind == "weapon":
		Build.box(goods, "WeaponRack", Vector3(0, 0.55, 0.13), Vector3(1.1, 0.1, 0.15), wood)
		for i: int in range(3):
			var sword := Node3D.new()
			goods.add_child(sword)
			sword.position.x = (i - 1) * 0.35
			emblem(sword, kind, metal, wood)
	else:
		emblem(goods, kind, metal, cloth)
		if kind == "armor":
			Build.box(goods, "Cloak", Vector3(0.7, 0.49, 0.04), Vector3(0.45, 0.8, 0.12), cloth)
			Build.box(goods, "MannequinStand", Vector3(0.7, 0.1, 0.1), Vector3(0.06, 0.4, 0.08), wood)

static func interior(room: Node3D, id: String, wood: Material, cloth: Material) -> void:
	if not SHOPS.has(id):
		return
	var shop: Dictionary = SHOPS[id]
	var at := Vector3(2.6, 1.04, -0.4)
	if shop.kind == "potion":
		at = Vector3(2.6, 1.0, -0.9)
	elif shop.kind == "inn":
		at = Vector3(3.1, 1.05, 0)
	display_goods(room, str(shop.kind), at, wood, cloth)
	if shop.kind == "inn":
		room.call("_interaction", "shop_inn_rest", "在月帆旅店休息（免費）", Vector3(0, 0.7, -3.6))
