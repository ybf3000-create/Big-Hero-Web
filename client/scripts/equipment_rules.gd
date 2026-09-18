class_name EquipmentRules
extends RefCounted

const ESSENCE_BY_QUALITY: Array[int] = [1, 3, 8, 20, 50]
const REROLL_COSTS := {
	0: {"essence": 15, "epic_gold": 5000, "legendary_gold": 10000},
	1: {"essence": 30, "epic_gold": 10000, "legendary_gold": 20000},
	2: {"essence": 100, "epic_gold": 30000, "legendary_gold": 60000},
}
const EQUIP_CAPACITY_BASE := 100
const EQUIP_CAPACITY_MAX := 1000
const EQUIP_EXPAND_SIZE := 50
const EQUIP_EXPANSION_COSTS: Array[int] = [
	5000, 15000, 30000, 50000, 75000, 100000, 150000, 200000, 300000,
	400000, 500000, 750000, 1000000, 1500000, 2000000, 3000000, 4000000, 5000000,
]
const LEGACY_MAIN_STATS := {
	"weapon": {"name": "攻击力", "base": 40.0}, "armor": {"name": "防御力", "base": 30.0},
	"shoes": {"name": "闪避率", "base": 4.0}, "ring": {"name": "暴击率", "base": 2.0},
	"necklace": {"name": "技能伤害", "base": 3.0}, "cape": {"name": "速度", "base": 5.0},
	"helmet": {"name": "格挡率", "base": 2.0}, "charm": {"name": "生命值", "base": 100.0},
}
const LEGACY_QUALITY_COEF := [1.0, 1.2, 1.5, 2.0, 3.0]

static func normalize_equipment(eqp: Dictionary) -> Dictionary:
	if eqp.is_empty():
		return eqp
	if not eqp.has("initial_gem_slots"):
		eqp["initial_gem_slots"] = int(eqp.get("gem_slots", 0))
	if not eqp.has("locked"):
		eqp["locked"] = int(eqp.get("quality", 0)) >= 4
	if not eqp.has("acquired_at"):
		eqp["acquired_at"] = int(Time.get_unix_time_from_system())
	var slot_name := str(eqp.get("slot", ""))
	var legacy_main: Dictionary = LEGACY_MAIN_STATS.get(slot_name, {})
	if not eqp.has("main_stat"):
		eqp["main_stat"] = str(legacy_main.get("name", "主属性"))
	if not eqp.has("main_value"):
		var quality := clampi(int(eqp.get("quality", 0)), 0, LEGACY_QUALITY_COEF.size() - 1)
		eqp["main_value"] = float(legacy_main.get("base", 0.0)) * float(LEGACY_QUALITY_COEF[quality])
	for affix in eqp.get("affixes", []):
		if not affix.has("type"):
			affix["type"] = _infer_affix_type(str(affix.get("name", "")))
	return eqp

static func essence_value(eqp: Dictionary) -> int:
	return ESSENCE_BY_QUALITY[clampi(int(eqp.get("quality", 0)), 0, ESSENCE_BY_QUALITY.size() - 1)]

static func max_gem_slots(eqp: Dictionary) -> int:
	var quality: int = int(eqp.get("quality", 0))
	return 3 if quality >= 3 else 0


static func enhanced_main_value(eqp: Dictionary, slot_enhance: int) -> float:
	return float(eqp.get("main_value", 0.0)) * (1.0 + 0.03 * float(clampi(slot_enhance, 0, 200)))

static func can_socket(eqp: Dictionary) -> bool:
	return not eqp.is_empty() and int(eqp.get("gem_slots", 0)) < max_gem_slots(eqp)

static func affix_count(eqp: Dictionary) -> int:
	return eqp.get("affixes", []).size() + eqp.get("set_affixes", []).size()

static func matches_six_dimensions(eqp: Dictionary, rules: Dictionary) -> bool:
	if rules.is_empty():
		return true
	var qualities: Array = rules.get("qualities", [])
	if not qualities.is_empty() and not qualities.has(int(eqp.get("quality", -1))):
		return false
	var slots: Array = rules.get("slots", [])
	if not slots.is_empty() and not slots.has(int(eqp.get("slot_type_id", -1))):
		return false
	var count := affix_count(eqp)
	if count < int(rules.get("affix_min", 0)) or count > int(rules.get("affix_max", 8)):
		return false
	var types: Array = rules.get("affix_types", [])
	if not types.is_empty():
		var has_type := false
		for affix in eqp.get("affixes", []):
			if types.has(str(affix.get("type", _infer_affix_type(str(affix.get("name", "")))))):
				has_type = true
				break
		for affix in eqp.get("set_affixes", []):
			if types.has(str(affix.get("type", "set"))):
				has_type = true
				break
		if not has_type:
			return false
	var sockets: Array = rules.get("initial_sockets", [])
	if not sockets.is_empty() and not sockets.has(int(eqp.get("initial_gem_slots", eqp.get("gem_slots", 0)))):
		return false
	var suits: Array = rules.get("suits", [])
	var suit_name: String = str(eqp.get("suit_name", ""))
	var suit_key: String = suit_name if not suit_name.is_empty() else "none"
	if not suits.is_empty() and not suits.has(suit_key):
		return false
	return true

static func reroll_affixes(eqp: Dictionary, locked_indices: Array[int], affix_pool: Array[Dictionary]) -> bool:
	if int(eqp.get("quality", 0)) < 3 or locked_indices.size() > 2:
		return false
	var old: Array = eqp.get("affixes", [])
	if old.is_empty():
		return false
	var result: Array[Dictionary] = []
	var used_names: Array[String] = []
	for i in range(old.size()):
		if locked_indices.has(i):
			var kept: Dictionary = old[i].duplicate(true)
			result.append(kept)
			used_names.append(str(kept.get("name", "")))
		else:
			result.append({})
	for i in range(result.size()):
		if not result[i].is_empty():
			continue
		var candidates: Array[Dictionary] = affix_pool.filter(func(defn: Dictionary): return not used_names.has(str(defn.get("name", ""))))
		if candidates.is_empty():
			return false
		var defn: Dictionary = candidates[randi() % candidates.size()]
		var value: float = snapped(randf_range(float(defn.get("min", 0.0)), float(defn.get("max", 0.0))), 0.1)
		result[i] = {"name": defn.get("name", ""), "type": defn.get("type", "universal"), "value": value, "display": str(defn.get("fmt", "+%.0f")) % value}
		used_names.append(str(defn.get("name", "")))
	eqp["affixes"] = result
	return true

static func _infer_affix_type(name: String) -> String:
	if name.begins_with("【"):
		return "set"
	if name in ["攻击%", "暴击率", "暴击伤害", "技能伤害", "命中", "攻击(数值)"]:
		return "attack"
	if name in ["防御%", "生命%", "格挡率", "闪避率", "吸血", "防御(数值)"]:
		return "defense"
	return "universal"
