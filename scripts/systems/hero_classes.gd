extends RefCounted
## Starting vocations. Equipment bonuses remain independent of the vocation.
const ORDER: Array[String] = ["traveler", "archer", "mage", "thief"]
const DATA: Dictionary = {
	"traveler": {"name": "旅人", "description": "均衡的近戰冒險者，揮出月影斬迎擊周圍敵人。", "hp": 100, "mp": 20, "attack": 14, "defense": 2, "skill": "月影斬", "cost": 5, "cooldown": 3.0, "power": 12, "radius": 2.2, "glyph": "moon", "cue": "moon_slash", "reach": 1.65, "interval": 0.38, "dodge": 1.0, "ranged": false, "effect": "moon_slash", "color": Color("e6c58b")},
	"archer": {"name": "弓箭手", "description": "保持距離精準射擊；月光穿射沿瞄準方向貫穿敵人。", "hp": 85, "mp": 24, "attack": 15, "defense": 1, "skill": "月光穿射", "cost": 4, "cooldown": 2.5, "power": 16, "radius": 0.45, "glyph": "arrow", "cue": "spear_thrust", "reach": 5.5, "interval": 0.50, "dodge": 1.0, "ranged": true, "effect": "arrow", "color": Color("a1e6bd")},
	"mage": {"name": "魔法師", "description": "以魔力彈遠距攻擊；霜星爆造成範圍傷害並緩速 3 秒。", "hp": 70, "mp": 40, "attack": 12, "defense": 0, "skill": "霜星爆", "cost": 8, "cooldown": 4.5, "power": 18, "radius": 2.2, "glyph": "frost", "cue": "frost_impact", "reach": 4.8, "interval": 0.60, "dodge": 1.0, "ranged": true, "effect": "frost", "color": Color("a8cfff")},
	"thief": {"name": "盜賊", "description": "快速近身連擊；影襲鎖定單體，從背後命中傷害更高。", "hp": 80, "mp": 20, "attack": 13, "defense": 1, "skill": "影襲", "cost": 3, "cooldown": 2.0, "power": 14, "radius": 0.6, "glyph": "daggers", "cue": "slash", "reach": 1.65, "interval": 0.26, "dodge": 0.65, "ranged": false, "effect": "shadow", "color": Color("d0b3e8")},
}

static func profile(id: String) -> Dictionary:
	return Dictionary(DATA.get(id, DATA.traveler)).duplicate(true)
