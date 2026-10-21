class_name GameData
extends RefCounted
## Central balance data. Resource order is always biomass, tissue, enzyme, core.

const DEATH_KEEP_RATIO: float = 0.5
const MAX_ENEMIES: int = 112
const WAVE_RESERVE: int = 24
const PLAYER_SHOT_RANGE: float = 343.75
const WAVES: Dictionary = {"initial": 16, "interval": 1.9, "minimum_interval": 0.65, "ramp_seconds": 150.0, "initial_size": 3, "maximum_size": 10, "size_step_seconds": 30.0, "nest_pack": 9}
const MAX_PROJECTILES: int = 240
const RESOURCE_LIMIT: int = 999999
const REGEN: Dictionary = {"upgrade_rate": 0.05, "module_rate": 0.025, "damage_delay": 5.0}
const GUARDIAN_ATTACKS: Dictionary = {
	"dash": {"windup": 0.85, "speed": 620.0, "duration": 0.60, "damage": 30.0, "recovery": 0.55},
	"fan": {"windup": 0.80, "projectiles": 7, "spread": 0.60, "bursts": 3, "burst_interval": 0.20, "recovery": 0.45},
	"slam": {"windup": 1.05, "radius": 142.0, "damage": 28.0, "projectiles": 14, "recovery": 0.65},
	"enrage_threshold": 0.5, "enrage_speed": 1.15, "enrage_cooldown": 0.78, "enrage_windup": 0.85,
}

const RESOURCES: Array = [
	{"id": "biomass", "name": "Биомасса", "color": Color("88d478"), "glyph": "●"},
	{"id": "tissue", "name": "Плотная ткань", "color": Color("d69c68"), "glyph": "◆"},
	{"id": "enzyme", "name": "Энергофермент", "color": Color("69d4e4"), "glyph": "▲"},
	{"id": "core", "name": "Органическое ядро", "color": Color("c28aff"), "glyph": "✦"},
]

const ENEMIES: Dictionary = {
	"crawler": {"name": "Ползун", "hp": 24.0, "speed": 79.0, "damage": 7.0, "radius": 13.0, "armor": 0.0, "cooldown": 0.9, "loot": [3, 0, 0, 0], "color": Color("c69369")},
	"shell": {"name": "Панцирник", "hp": 66.0, "speed": 43.0, "damage": 13.0, "radius": 20.0, "armor": 0.22, "cooldown": 1.3, "loot": [2, 2, 0, 0], "color": Color("b67f66")},
	"ranged": {"name": "Излучатель", "hp": 36.0, "speed": 50.0, "damage": 10.0, "radius": 16.0, "armor": 0.0, "cooldown": 2.3, "range": 250.0, "projectile_speed": 126.0, "telegraph": 0.65, "loot": [1, 0, 2, 0], "color": Color("9dd0b2")},
	"guardian": {"name": "Искажённый страж", "hp": 520.0, "speed": 130.0, "damage": 22.0, "radius": 37.0, "armor": 0.12, "cooldown": 1.35, "range": 460.0, "projectile_speed": 225.0, "telegraph": 0.9, "loot": [18, 6, 8, 1], "color": Color("ce856e")},
}

const MISSIONS: Array = [
	{"id": 0, "name": "Шёпот под кронами", "biome": "Биолюминесцентный лес", "description": "Уничтожьте три гнездовых узла. После выполнения цели можно продолжить сбор и вернуться через меню.", "difficulty": "Умеренная", "rewards": ["Биомасса", "Плотная ткань", "Энергофермент", "Ядро стража"], "heart_required": 0, "nodes": 3, "node_hp": 105.0, "enemy_multiplier": 1.0, "color": Color("77bca3")},
	{"id": 1, "name": "Багровая низина", "biome": "Споровые топи", "description": "Подавите три споровых сердца. Из каждого выйдет страж — уничтожьте всех троих. Здесь ткани плотнее, а фермент нестабилен.", "difficulty": "Высокая", "rewards": ["Плотная ткань", "Энергофермент", "Органическое ядро"], "heart_required": 2, "nodes": 3, "node_hp": 165.0, "enemy_multiplier": 1.3, "color": Color("ba88a8")},
]

const LEGACY_UPGRADES: Dictionary = {
	"regeneration": {"name": "Регенеративная ткань", "description": "+15 здоровья и +0,05 HP/с за уровень. Лечение начинается через 5 с без урона.", "max_level": 3, "costs": [[12, 0, 0, 0], [24, 4, 2, 0], [42, 9, 6, 1]], "color": Color("b5d987")},
	"muscle": {"name": "Нейромышечные волокна", "description": "+8% скорости за уровень", "max_level": 3, "costs": [[14, 2, 0, 0], [28, 6, 2, 0], [46, 10, 6, 1]], "color": Color("dbb27c")},
	"resonator": {"name": "Боевой резонатор", "description": "+10% урона и +7% частоты за уровень", "max_level": 3, "costs": [[15, 4, 0, 0], [30, 8, 3, 0], [50, 12, 8, 1]], "color": Color("d997c5")},
	"receptor": {"name": "Нейронный рецептор", "description": "+25% подбора и +15% обнаружения за уровень", "max_level": 3, "costs": [[10, 0, 3, 0], [22, 3, 6, 0], [36, 6, 12, 1]], "color": Color("83d7d4")},
}

const Evolution = preload("res://scripts/evolution_data.gd")
static var UPGRADES: Dictionary = Evolution.host_nodes(LEGACY_UPGRADES)
static var MODULES: Dictionary = Evolution.ship_nodes()

static func default_levels(ship: bool) -> Dictionary:
	var result := {}
	for id: String in MODULES if ship else UPGRADES:
		result[id] = 0
	return result

static func upgrade_cost(id: String, level: int) -> Array:
	if not UPGRADES.has(id) or level < 0 or level >= int(UPGRADES[id]["max_level"]):
		return []
	return UPGRADES[id]["costs"][level].duplicate()

static func module_cost(id: String, level: int) -> Array:
	if not MODULES.has(id) or level < 0 or level >= int(MODULES[id]["max_level"]):
		return []
	return MODULES[id]["costs"][level].duplicate()

static func stats(levels: Dictionary) -> Dictionary:
	var regeneration: int = clampi(int(levels.get("regeneration", 0)), 0, 3)
	var muscle: int = clampi(int(levels.get("muscle", 0)), 0, 3)
	var resonator: int = clampi(int(levels.get("resonator", 0)), 0, 3)
	var receptor: int = clampi(int(levels.get("receptor", 0)), 0, 3)
	var result := {"hp": 100.0 + regeneration * 15.0, "max_hp": 100.0 + regeneration * 15.0, "speed": 175.0 * (1.0 + muscle * 0.08), "damage": 10.0 * (1.0 + resonator * 0.10), "fire_interval": 0.4 / (1.0 + resonator * 0.07), "pickup_radius": 58.0 * (1.0 + receptor * 0.25), "detection_radius": 350.0 * (1.0 + receptor * 0.15), "regen": regeneration * float(REGEN["upgrade_rate"]), "armor": 0.0}
	var traits := Evolution.traits(UPGRADES,levels)
	result.merge(traits)
	result["armor"] = float(traits.get("armor",0))
	result["max_hp"] += float(traits.get("hp_flat",0))
	result["hp"] = result["max_hp"]
	result["damage"] *= 1.0 + float(traits.get("damage_bonus",0))
	result["speed"] *= 1.0 + float(traits.get("speed_bonus",0))
	result["fire_interval"] /= 1.0 + float(traits.get("fire_bonus",0))
	result["pickup_radius"] *= 1.0 + float(traits.get("pickup_bonus",0))
	result["detection_radius"] *= 1.0 + float(traits.get("detection_bonus",0))
	result["regen"] += float(traits.get("regen_flat",0))
	result["regen_delay"] = maxf(1.0,5.0-float(traits.get("regen_delay_reduction",0)))
	return result
