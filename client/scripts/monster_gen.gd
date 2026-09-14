class_name MonsterGen
extends RefCounted

const CHALLENGE_DURATION: float = 60.0
const CHALLENGE_INFINITE_HP: int = 99999999

const ELITE_PASSIVE_POOL: Array[String] = [
	"铁壁",
	"狂暴",
	"回复",
	"荆棘",
	"迅捷",
	"毒素",
	"护盾",
	"诅咒",
]

const TYPE_DEFS: Dictionary = {
	"史莱姆·战士": {"hp_mul": 1.5, "atk_mul": 0.7, "def_mul": 1.2, "speed_points": 5, "skill_id": 21},
	"史莱姆·射手": {"hp_mul": 0.8, "atk_mul": 1.4, "def_mul": 0.6, "speed_points": 25, "skill_id": 10},
	"史莱姆·法师": {"hp_mul": 0.7, "atk_mul": 1.6, "def_mul": 0.5, "speed_points": 8, "skill_id": 28},
	"史莱姆·盗贼": {"hp_mul": 0.6, "atk_mul": 1.3, "def_mul": 0.4, "speed_points": 35, "skill_id": 27},
	"哥布林·战士": {"hp_mul": 1.3, "atk_mul": 0.9, "def_mul": 1.3, "speed_points": 8, "skill_id": 23},
	"哥布林·射手": {"hp_mul": 0.8, "atk_mul": 1.5, "def_mul": 0.5, "speed_points": 25, "skill_id": 10},
	"哥布林·法师": {"hp_mul": 0.7, "atk_mul": 1.7, "def_mul": 0.4, "speed_points": 8, "skill_id": 16},
	"哥布林·祭祀": {"hp_mul": 1.0, "atk_mul": 0.6, "def_mul": 0.8, "speed_points": 8, "skill_id": 22},
	"哥布林·盗贼": {"hp_mul": 0.7, "atk_mul": 1.2, "def_mul": 0.5, "speed_points": 35, "skill_id": 7},
	"骷髅·战士": {"hp_mul": 1.1, "atk_mul": 1.0, "def_mul": 1.1, "speed_points": 15, "skill_id": 8},
	"骷髅·射手": {"hp_mul": 0.7, "atk_mul": 1.6, "def_mul": 0.4, "speed_points": 25, "skill_id": 33},
	"骷髅·法师": {"hp_mul": 0.6, "atk_mul": 1.8, "def_mul": 0.3, "speed_points": 5, "skill_id": 18},
	"骷髅·祭祀": {"hp_mul": 1.0, "atk_mul": 0.6, "def_mul": 0.8, "speed_points": 8, "skill_id": 22},
	"狼·战士": {"hp_mul": 1.2, "atk_mul": 1.1, "def_mul": 0.9, "speed_points": 25, "skill_id": 9},
	"狼·射手": {"hp_mul": 0.9, "atk_mul": 1.3, "def_mul": 0.5, "speed_points": 25, "skill_id": 35},
	"狼·盗贼": {"hp_mul": 0.6, "atk_mul": 1.4, "def_mul": 0.3, "speed_points": 35, "skill_id": 29},
	"狼·祭祀": {"hp_mul": 1.0, "atk_mul": 0.7, "def_mul": 0.7, "speed_points": 15, "skill_id": 25},
	"蝙蝠·战士": {"hp_mul": 1.0, "atk_mul": 1.2, "def_mul": 0.6, "speed_points": 35, "skill_id": 12},
	"蝙蝠·射手": {"hp_mul": 0.7, "atk_mul": 1.4, "def_mul": 0.4, "speed_points": 25, "skill_id": 11},
	"蝙蝠·法师": {"hp_mul": 0.6, "atk_mul": 1.6, "def_mul": 0.3, "speed_points": 15, "skill_id": 30},
	"蝙蝠·盗贼": {"hp_mul": 0.5, "atk_mul": 1.2, "def_mul": 0.3, "speed_points": 35, "skill_id": 27},
	"蜘蛛·战士": {"hp_mul": 1.4, "atk_mul": 0.8, "def_mul": 1.4, "speed_points": 5, "skill_id": 23},
	"蜘蛛·射手": {"hp_mul": 0.8, "atk_mul": 1.5, "def_mul": 0.5, "speed_points": 25, "skill_id": 27},
	"蜘蛛·法师": {"hp_mul": 0.9, "atk_mul": 1.3, "def_mul": 0.6, "speed_points": 8, "skill_id": 17},
	"蜘蛛·盗贼": {"hp_mul": 0.5, "atk_mul": 1.3, "def_mul": 0.3, "speed_points": 35, "skill_id": 36},
	"树精·战士": {"hp_mul": 1.8, "atk_mul": 0.5, "def_mul": 1.5, "speed_points": 5, "skill_id": 26},
	"树精·法师": {"hp_mul": 1.1, "atk_mul": 1.3, "def_mul": 0.8, "speed_points": 8, "skill_id": 31},
	"树精·祭祀": {"hp_mul": 1.3, "atk_mul": 0.4, "def_mul": 0.8, "speed_points": 5, "skill_id": 25},
	"树精·射手": {"hp_mul": 1.0, "atk_mul": 1.4, "def_mul": 0.7, "speed_points": 8, "skill_id": 33},
	"石魔·战士": {"hp_mul": 2.0, "atk_mul": 0.6, "def_mul": 1.8, "speed_points": 5, "skill_id": 15},
	"石魔·法师": {"hp_mul": 1.2, "atk_mul": 1.5, "def_mul": 1.0, "speed_points": 8, "skill_id": 14},
	"石魔·射手": {"hp_mul": 1.0, "atk_mul": 1.3, "def_mul": 1.0, "speed_points": 15, "skill_id": 34},
	"石魔·盗贼": {"hp_mul": 0.8, "atk_mul": 1.0, "def_mul": 0.8, "speed_points": 25, "skill_id": 7},
	"鹰身女妖·战士": {"hp_mul": 0.9, "atk_mul": 1.4, "def_mul": 0.5, "speed_points": 35, "skill_id": 8},
	"鹰身女妖·射手": {"hp_mul": 0.7, "atk_mul": 1.6, "def_mul": 0.4, "speed_points": 25, "skill_id": 35},
	"鹰身女妖·法师": {"hp_mul": 0.6, "atk_mul": 1.7, "def_mul": 0.3, "speed_points": 15, "skill_id": 16},
	"鹰身女妖·祭祀": {"hp_mul": 0.8, "atk_mul": 0.7, "def_mul": 0.5, "speed_points": 25, "skill_id": 22},
	"暗影·战士": {"hp_mul": 1.0, "atk_mul": 1.2, "def_mul": 0.8, "speed_points": 15, "skill_id": 36},
	"暗影·法师": {"hp_mul": 0.7, "atk_mul": 1.8, "def_mul": 0.3, "speed_points": 8, "skill_id": 19},
	"暗影·盗贼": {"hp_mul": 0.5, "atk_mul": 1.5, "def_mul": 0.2, "speed_points": 35, "skill_id": 36},
	"暗影·祭祀": {"hp_mul": 0.9, "atk_mul": 0.8, "def_mul": 0.6, "speed_points": 15, "skill_id": 24},
}

const NORMAL_TEMPLATES: Array[Dictionary] = [
	{"id": "N-01", "name": "独行肉盾", "front": ["史莱姆·战士"], "back": [], "min_tier": 0},
	{"id": "N-02", "name": "孤高炮台", "front": ["骷髅·法师"], "back": [], "min_tier": 0},
	{"id": "N-03", "name": "盾+弓", "front": ["哥布林·战士", "哥布林·射手"], "back": [], "min_tier": 0},
	{"id": "N-04", "name": "远近夹击", "front": ["狼·战士"], "back": ["狼·射手"], "min_tier": 0},
	{"id": "N-05", "name": "蝙蝠群", "front": ["蝙蝠·战士", "蝙蝠·盗贼", "蝙蝠·射手"], "back": [], "min_tier": 1},
	{"id": "N-06", "name": "蛛网防线", "front": ["蜘蛛·战士"], "back": ["蜘蛛·射手", "蜘蛛·法师"], "min_tier": 1},
	{"id": "N-07", "name": "哥布林小队", "front": ["哥布林·战士", "哥布林·盗贼"], "back": ["哥布林·射手", "哥布林·法师"], "min_tier": 4},
	{"id": "N-08", "name": "亡灵小队", "front": ["骷髅·战士", "骷髅·射手"], "back": ["骷髅·法师", "骷髅·祭祀"], "min_tier": 4},
	{"id": "N-09", "name": "史莱姆大军", "front": ["史莱姆·战士", "史莱姆·盗贼"], "back": ["史莱姆·射手", "史莱姆·法师", "史莱姆·法师"], "min_tier": 8},
	{"id": "N-10", "name": "石魔军团", "front": ["石魔·战士", "石魔·射手"], "back": ["石魔·法师", "石魔·盗贼", "石魔·射手"], "min_tier": 8},
	{"id": "N-11", "name": "狼群", "front": ["狼·战士", "狼·盗贼"], "back": ["狼·射手", "狼·射手", "狼·祭祀"], "min_tier": 8},
	{"id": "N-12", "name": "森林守护", "front": ["树精·战士"], "back": ["树精·射手", "树精·祭祀"], "min_tier": 4},
	{"id": "N-13", "name": "暗影突袭", "front": ["暗影·盗贼", "暗影·战士"], "back": ["暗影·法师", "暗影·祭祀"], "min_tier": 8},
	{"id": "N-14", "name": "风暴双子", "front": ["鹰身女妖·战士"], "back": ["鹰身女妖·法师"], "min_tier": 8},
	{"id": "N-15", "name": "混沌联军", "front": ["哥布林·战士", "骷髅·战士"], "back": ["哥布林·射手", "骷髅·法师", "蝙蝠·盗贼"], "min_tier": 8},
]

const ELITE_TEMPLATES: Array[Dictionary] = [
	{"id": "E-01", "name": "精英炮台", "front": ["⚔骷髅·法师"], "back": [], "min_tier": 0, "elite_bonus_count": 2},
	{"id": "E-02", "name": "铁壁+炮台", "front": ["⚔石魔·战士"], "back": ["哥布林·法师"], "min_tier": 0},
	{"id": "E-03", "name": "双狼精英", "front": ["⚔狼·战士", "⚔狼·盗贼"], "back": [], "min_tier": 0},
	{"id": "E-04", "name": "精英小队", "front": ["⚔哥布林·战士"], "back": ["⚔哥布林·射手", "哥布林·祭祀"], "min_tier": 0},
	{"id": "E-05", "name": "暗影精英团", "front": ["⚔暗影·盗贼", "暗影·战士"], "back": ["⚔暗影·法师", "暗影·祭祀"], "min_tier": 4},
	{"id": "E-06", "name": "风暴精英", "front": ["⚔鹰身女妖·法师"], "back": ["鹰身女妖·祭祀"], "min_tier": 4},
	{"id": "E-07", "name": "亡灵大军", "front": ["⚔骷髅·战士", "骷髅·射手"], "back": ["⚔骷髅·法师", "骷髅·祭祀", "骷髅·射手"], "min_tier": 4},
	{"id": "E-08", "name": "蛛王禁地", "front": ["⚔蜘蛛·战士"], "back": ["⚔蜘蛛·法师", "⚔蜘蛛·射手"], "min_tier": 4},
	{"id": "E-09", "name": "荆棘防线", "front": ["⚔树精·战士"], "back": ["⚔树精·射手", "骷髅·法师"], "min_tier": 8},
	{"id": "E-10", "name": "暗夜突袭", "front": ["⚔蝙蝠·战士", "蝙蝠·盗贼"], "back": ["⚔蝙蝠·法师", "蝙蝠·射手"], "min_tier": 8},
	{"id": "E-11", "name": "晶石阵列", "front": ["⚔石魔·法师"], "back": ["⚔石魔·射手"], "min_tier": 8},
	{"id": "E-12", "name": "天空霸主", "front": ["⚔鹰身女妖·战士"], "back": ["⚔鹰身女妖·射手", "鹰身女妖·祭祀"], "min_tier": 8},
	{"id": "E-13", "name": "哥布林部落", "front": ["⚔哥布林·战士", "⚔哥布林·盗贼"], "back": ["哥布林·射手", "⚔哥布林·法师", "哥布林·祭祀"], "min_tier": 16},
	{"id": "E-14", "name": "暗影铁卫", "front": ["⚔暗影·战士"], "back": ["⚔暗影·祭祀"], "min_tier": 16},
	{"id": "E-15", "name": "蜘蛛巢穴", "front": ["⚔蜘蛛·战士", "蜘蛛·射手"], "back": ["⚔蜘蛛·法师", "蜘蛛·盗贼", "蝙蝠·盗贼"], "min_tier": 16},
	{"id": "E-16", "name": "古树之怒", "front": ["⚔树精·祭祀", "树精·战士"], "back": ["⚔树精·法师"], "min_tier": 16},
]

const CHALLENGE_TEMPLATES: Array[Dictionary] = [
	{"id": "C-01", "name": "木桩阵列", "front": ["⚔石魔·战士"], "back": ["哥布林·射手", "哥布林·法师", "哥布林·祭祀"]},
	{"id": "C-02", "name": "森林试炼", "front": ["⚔树精·战士", "⚔树精·祭祀"], "back": ["骷髅·法师", "骷髅·射手"]},
	{"id": "C-03", "name": "暗影试炼", "front": ["⚔暗影·战士", "暗影·盗贼"], "back": ["⚔暗影·法师", "暗影·祭祀", "蝙蝠·射手"]},
]

const BOSS_TEMPLATES: Array[Dictionary] = [
	{"id": 1, "name": "史莱姆王", "front": ["Boss"], "back": []},
	{"id": 2, "name": "野人队长", "front": ["Boss"], "back": ["哥布林·射手"]},
	{"id": 3, "name": "骷髅将军", "front": ["Boss", "骷髅·战士"], "back": ["骷髅·射手"]},
	{"id": 4, "name": "狼王", "front": ["Boss", "狼·战士"], "back": []},
	{"id": 5, "name": "史前机兵", "front": ["Boss"], "back": ["蝙蝠·盗贼", "蝙蝠·射手"]},
	{"id": 6, "name": "花冠女皇", "front": ["Boss"], "back": ["蜘蛛·战士", "蜘蛛·射手"]},
	{"id": 7, "name": "树精长老", "front": ["Boss", "树精·战士"], "back": ["树精·祭祀"]},
	{"id": 8, "name": "石魔巨像", "front": ["Boss"], "back": []},
	{"id": 9, "name": "尸王", "front": ["Boss"], "back": ["骷髅·战士", "骷髅·法师"]},
	{"id": 10, "name": "鹰身女王", "front": ["Boss", "鹰身女妖·战士"], "back": ["鹰身女妖·祭祀"]},
	{"id": 11, "name": "暗影领主", "front": ["Boss", "暗影·盗贼"], "back": ["暗影·法师"]},
	{"id": 12, "name": "虚假帝皇", "front": ["Boss", "蜘蛛·法师"], "back": ["蜘蛛·战士"]},
	{"id": 13, "name": "幻蝶", "front": ["Boss"], "back": []},
	{"id": 14, "name": "异化鲨鲨", "front": ["Boss", "石魔·法师"], "back": ["石魔·射手"]},
	{"id": 15, "name": "暗影大祭司", "front": ["Boss", "暗影·祭祀"], "back": ["暗影·战士", "暗影·盗贼"]},
	{"id": 16, "name": "狼妄", "front": ["Boss", "狼·战士"], "back": ["狼·射手", "狼·祭祀"]},
	{"id": 17, "name": "骨龙", "front": ["Boss", "骷髅·法师"], "back": []},
	{"id": 18, "name": "绿精", "front": ["Boss", "树精·祭祀"], "back": ["树精·法师"]},
	{"id": 19, "name": "混沌魔像", "front": ["Boss", "暗影·法师"], "back": ["暗影·祭祀"]},
	{"id": 20, "name": "暗影", "front": ["Boss", "暗影·战士"], "back": ["暗影·法师", "暗影·祭祀"]},
]

const BOSS_MECHANICS: Dictionary = {
	1: {"id": "split", "name": "分裂", "threshold": 0.30, "count": 3},
	2: {"id": "command", "name": "指挥", "back_atk_mult": 1.30},
	3: {"id": "leadership", "name": "统率", "atk_per_death": 0.15},
	4: {"id": "blood_rage", "name": "嗜血", "threshold_step": 0.30},
	5: {"id": "vampire", "name": "吸血", "lifesteal": 20.0},
	6: {"id": "web", "name": "蛛网", "interval": 15.0, "stun": 4.0},
	7: {"id": "nature_guard", "name": "自然守护", "interval": 10.0, "heal_pct": 15.0},
	8: {"id": "rock", "name": "磐石", "damage_reduce": 0.30, "control_immune": true},
	9: {"id": "death_summon", "name": "死亡召唤", "threshold": 0.50, "interval": 8.0, "max_summons": 3},
	10: {"id": "storm_field", "name": "风暴领域", "player_cd_add": 0.60},
	11: {"id": "shadow_clone", "name": "暗影分身", "interval": 12.0, "max_summons": 2, "hp_mult": 0.50},
	12: {"id": "poison_aura", "name": "剧毒光环", "interval": 1.0, "damage_pct": 10.0},
	13: {"id": "charm", "name": "魅惑", "interval": 20.0, "stun": 3.0},
	14: {"id": "earthquake", "name": "地震", "interval": 15.0, "damage_mult": 1.50},
	15: {"id": "shadow_ritual", "name": "暗影仪式", "atk_mult": 2.0},
	16: {"id": "wolf_summon", "name": "狼群召唤", "interval": 10.0, "max_summons": 4},
	17: {"id": "dragon_breath", "name": "龙息", "interval": 8.0, "damage_mult": 2.0},
	18: {"id": "life_seed", "name": "生命之种", "revives": 1},
	19: {"id": "chaos_field", "name": "混沌领域", "interval": 10.0, "buff_mult": 1.50},
	20: {"id": "shadow_rule", "name": "暗影统御", "threshold_step": 0.10, "max_summons": 3, "atk_per_trigger": 0.05},
}


static func generate_encounter(battle_kind: String, ctx: Dictionary) -> Dictionary:
	var player_level: int = ctx.get("player_level", 1)
	var boss_tier: int = ctx.get("boss_tier", 0)
	var boss_index: int = ctx.get("boss_index", boss_tier + 1)
	match battle_kind:
		"battle":
			var normal_template: Dictionary = _pick_normal_template(boss_tier)
			var normal_lv: int = _roll_normal_level(player_level, boss_tier)
			return _build_encounter_from_template(normal_template, battle_kind, normal_lv, boss_tier, false)
		"elite":
			var elite_template: Dictionary = _pick_elite_template(boss_tier)
			var elite_lv: int = _roll_elite_level(player_level, boss_tier)
			return _build_encounter_from_template(elite_template, battle_kind, elite_lv, boss_tier, false)
		"challenge":
			var challenge_template: Dictionary = CHALLENGE_TEMPLATES[randi() % CHALLENGE_TEMPLATES.size()]
			var challenge_lv: int = _roll_elite_level(player_level, boss_tier)
			return _build_encounter_from_template(challenge_template, battle_kind, challenge_lv, boss_tier, true)
		"boss":
			var boss_template: Dictionary = _pick_boss_template(boss_index)
			return _build_boss_encounter(boss_template, player_level, boss_tier, boss_index)
		_:
			return {"battle_kind": battle_kind, "monster_level": player_level, "units": [], "formation": {"front": [], "back": []}}


static func speed_to_cd(speed_points: int) -> float:
	return 3.0 * (1.0 - minf(float(speed_points) * 0.008, 0.50))


static func get_area_min_level(tier: int) -> int:
	if tier <= 3:
		return 1
	if tier <= 7:
		return 6
	if tier <= 11:
		return 13
	if tier <= 15:
		return 21
	if tier <= 20:
		return 31
	if tier <= 30:
		return 46
	if tier <= 40:
		return 71
	if tier <= 50:
		return 101
	if tier <= 65:
		return 141
	if tier <= 80:
		return 201
	return 281


static func elite_dodge_block_for_tier(tier: int) -> float:
	if tier <= 7:
		return 0.0
	return minf(5.0 + float(tier) * 0.35, 33.0)


static func boss_dodge_block_for_tier(tier: int) -> float:
	return 10.0 + minf(float(tier) * 0.5, 25.0)


static func _roll_normal_level(player_level: int, tier: int) -> int:
	return maxi(get_area_min_level(tier), player_level - 3) + randi_range(0, 2)


static func _roll_elite_level(player_level: int, tier: int) -> int:
	return maxi(get_area_min_level(tier), player_level - 1) + randi_range(0, 1)


static func _pick_normal_template(tier: int) -> Dictionary:
	var pool: Array[Dictionary] = []
	for template in NORMAL_TEMPLATES:
		if tier >= template.get("min_tier", 0):
			pool.append(template)
	return pool[randi() % pool.size()]


static func _pick_elite_template(tier: int) -> Dictionary:
	var pool: Array[Dictionary] = []
	for template in ELITE_TEMPLATES:
		if tier >= template.get("min_tier", 0):
			pool.append(template)
	return pool[randi() % pool.size()]


static func _pick_boss_template(boss_index: int) -> Dictionary:
	var idx: int = clampi(boss_index, 1, BOSS_TEMPLATES.size()) - 1
	return BOSS_TEMPLATES[idx]


static func _build_encounter_from_template(template: Dictionary, battle_kind: String, monster_level: int, tier: int, infinite_hp: bool) -> Dictionary:
	var units: Array[Dictionary] = []
	var front_ids: Array[int] = []
	var back_ids: Array[int] = []
	var next_id: int = 1
	for name in template.get("front", []):
		var unit: Dictionary = _build_unit_entry(name as String, next_id, "front", monster_level, tier, battle_kind, infinite_hp, template)
		if not unit.is_empty():
			units.append(unit)
			front_ids.append(next_id)
			next_id += 1
	for name in template.get("back", []):
		var unit: Dictionary = _build_unit_entry(name as String, next_id, "back", monster_level, tier, battle_kind, infinite_hp, template)
		if not unit.is_empty():
			units.append(unit)
			back_ids.append(next_id)
			next_id += 1
	return {
		"battle_kind": battle_kind,
		"monster_level": monster_level,
		"template_id": template.get("id", ""),
		"template_name": template.get("name", ""),
		"units": units,
		"formation": {"front": front_ids, "back": back_ids},
		"duration_limit": CHALLENGE_DURATION if battle_kind == "challenge" else 0.0,
	}


static func _build_boss_encounter(template: Dictionary, player_level: int, tier: int, boss_index: int) -> Dictionary:
	var boss_level: int = player_level + 2
	var units: Array[Dictionary] = []
	var front_ids: Array[int] = []
	var back_ids: Array[int] = []
	var next_id: int = 1
	for name in template.get("front", []):
		var unit: Dictionary = {}
		if name == "Boss":
			unit = _build_boss_unit(next_id, template.get("name", "Boss"), boss_level, tier, boss_index)
		else:
			unit = _build_unit_entry(name as String, next_id, "front", _roll_elite_level(player_level, tier), tier, "boss", false, {})
		if not unit.is_empty():
			units.append(unit)
			front_ids.append(next_id)
			next_id += 1
	for name in template.get("back", []):
		var unit: Dictionary = _build_unit_entry(name as String, next_id, "back", _roll_elite_level(player_level, tier), tier, "boss", false, {})
		if not unit.is_empty():
			units.append(unit)
			back_ids.append(next_id)
			next_id += 1
	return {
		"battle_kind": "boss",
		"monster_level": boss_level,
		"template_id": "Boss" + str(boss_index),
		"template_name": template.get("name", "Boss"),
		"units": units,
		"formation": {"front": front_ids, "back": back_ids},
		"duration_limit": 0.0,
		"weather": template.get("weather", "sunny"),
	}


static func _build_unit_entry(raw_name: String, unit_id: int, row: String, monster_level: int, tier: int, battle_kind: String, infinite_hp: bool, template: Dictionary) -> Dictionary:
	if raw_name.is_empty() or raw_name == "—":
		return {}
	var is_elite: bool = raw_name.begins_with("⚔")
	var clean_name: String = raw_name.substr(1) if is_elite else raw_name
	var def: Dictionary = TYPE_DEFS.get(clean_name, {})
	if def.is_empty():
		return {}
	var level_scale: float = 1.0 + float(monster_level - 1) * 0.15
	var tier_scale: float = 1.0 + float(tier) * 0.02
	var hp_mul: float = def.get("hp_mul", 1.0)
	var atk_mul: float = def.get("atk_mul", 1.0)
	var def_mul: float = def.get("def_mul", 1.0)
	var hp_value: int = int(round(300.0 * level_scale * tier_scale * hp_mul * (3.0 if is_elite else 1.0)))
	var atk_value: int = int(round(30.0 * level_scale * tier_scale * atk_mul * (1.8 if is_elite else 1.0)))
	var def_value: int = int(round(20.0 * level_scale * tier_scale * def_mul))
	# 新档没有装备，25点初始攻击会被旧版20点怪物基础防御近乎抵消。
	# 修正仅覆盖首区域的低等级普通怪；精英、Boss和后续区域仍使用完整强度。
	if battle_kind == "battle" and tier == 0 and monster_level <= 3:
		hp_value = int(round(float(hp_value) * 0.45))
		atk_value = int(round(float(atk_value) * 0.55))
		def_value = int(round(float(def_value) * 0.35))
	if infinite_hp:
		hp_value = CHALLENGE_INFINITE_HP
	var speed_points: int = int(def.get("speed_points", 15))
	var unit: Dictionary = {
		"id": unit_id,
		"name": clean_name,
		"display_name": raw_name,
		"row": row,
		"level": monster_level,
		"max_hp": maxi(hp_value, 1),
		"current_hp": maxi(hp_value, 1),
		"atk": maxi(atk_value, 1),
		"def": maxi(def_value, 0),
		"speed_points": speed_points,
		"action_cd": speed_to_cd(speed_points),
		"crit": 0.0,
		"critdmg": 150.0,
		"hit": 100.0,
		"dodge": 0.0,
		"block": 0.0,
		"skill_ids": [int(def.get("skill_id", 0))],
		"passives": [],
		"is_elite": is_elite,
		"is_boss": false,
		"infinite_hp": infinite_hp,
		"template_id": template.get("id", ""),
	}
	if is_elite:
		var evade_block: float = elite_dodge_block_for_tier(tier)
		unit["dodge"] = evade_block
		unit["block"] = evade_block
		var passive_count: int = int(template.get("elite_bonus_count", 1))
		unit["passives"] = _roll_passives(passive_count)
	return unit


static func _build_boss_unit(unit_id: int, boss_name: String, boss_level: int, tier: int, boss_index: int) -> Dictionary:
	var base_hp: float = 500.0 + float(boss_level - 1) * 80.0
	var base_atk: float = 25.0 + float(boss_level - 1) * 2.0
	var base_def: float = 15.0 + float(boss_level - 1) * 1.0
	var hp_mul: float = 8.0 + float(boss_index) * 0.15
	var atk_mul: float = 1.5 + float(boss_index) * 0.003
	var def_mul: float = 1.5 + float(boss_index) * 0.005
	var speed_points: int = 15
	if boss_index >= 16 and boss_index <= 50:
		speed_points = 25
	elif boss_index >= 51:
		speed_points = 35
	var evade_block: float = boss_dodge_block_for_tier(tier)
	return {
		"id": unit_id,
		"name": boss_name,
		"display_name": boss_name,
		"row": "front",
		"level": boss_level,
		"max_hp": int(round(base_hp * hp_mul)),
		"current_hp": int(round(base_hp * hp_mul)),
		"atk": int(round(base_atk * atk_mul)),
		"def": int(round(base_def * def_mul)),
		"speed_points": speed_points,
		"action_cd": speed_to_cd(speed_points),
		"crit": 0.0,
		"critdmg": 150.0,
		"hit": 100.0,
		"dodge": evade_block,
		"block": evade_block,
		"skill_ids": [],
		"passives": [],
		"is_elite": false,
		"is_boss": true,
		"infinite_hp": false,
		"template_id": "Boss" + str(boss_index),
		"boss_index": boss_index,
		"boss_mechanic": BOSS_MECHANICS.get(clampi(boss_index, 1, 20), {}).duplicate(true),
	}


static func _roll_passives(count: int) -> Array[String]:
	var pool: Array[String] = ELITE_PASSIVE_POOL.duplicate()
	var result: Array[String] = []
	while count > 0 and not pool.is_empty():
		var idx: int = randi() % pool.size()
		result.append(pool[idx])
		pool.remove_at(idx)
		count -= 1
	return result
