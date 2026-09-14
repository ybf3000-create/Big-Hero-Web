class_name EquipGen
extends RefCounted
## ============================================================
## EquipGen — 装备生成器 v1.0
## 按品质/部位/词条规则生成装备实例
## ============================================================

const EquipDataCls = preload("res://scripts/equip_data.gd")
const EquipIconsCls = preload("res://scripts/equip_icons.gd")

# 品质掉落权重
const QUALITY_WEIGHTS: Array[float] = [0.60, 0.28, 0.10, 0.017, 0.003]

# 品质 → 词条数
const AFFIX_COUNTS: Array[int] = [1, 2, 3, 4, 5]

# 史诗、传说的天生孔数：1孔60% / 2孔30% / 3孔10%。
const GEM_SLOT_MIN_QUALITY := 3

# 主属性基础值（按部位）
static var MAIN_BASE: Dictionary = {
	"weapon":    { "name": "攻击力",   "base": 40.0 },
	"armor":     { "name": "防御力",   "base": 30.0 },
	"shoes":     { "name": "闪避率",   "base": 4.0 },
	"ring":      { "name": "暴击率",   "base": 2.0 },
	"necklace":  { "name": "技能伤害", "base": 3.0 },
	"cape":      { "name": "速度",     "base": 5.0 },
	"helmet":    { "name": "格挡率",   "base": 2.0 },
	"charm":     { "name": "生命值",   "base": 100.0 },
}

# 品质系数
static var QUALITY_COEF: Array[float] = [1.0, 1.2, 1.5, 2.0, 3.0]

# 套装池（13套）
static var SET_POOL: Array[Dictionary] = [
	{ "name": "龙鳞", "pos": "坦克" },
	{ "name": "烈焰", "pos": "群伤" },
	{ "name": "冰霜", "pos": "控制" },
	{ "name": "雷霆", "pos": "爆发" },
	{ "name": "疾风", "pos": "攻速" },
	{ "name": "铁壁", "pos": "格挡" },
	{ "name": "暗影", "pos": "暗杀" },
	{ "name": "自然", "pos": "治疗" },
	{ "name": "引力", "pos": "刷宝" },
	{ "name": "星辰", "pos": "技能" },
	{ "name": "幻影", "pos": "闪避" },
	{ "name": "口才", "pos": "跳过" },
	{ "name": "奢侈", "pos": "扣钱" },
]

# 13 套各 4 条专属词条。词条名称是唯一键，同名效果全身只生效一次。
static var SET_AFFIX_POOL: Dictionary = {
	"龙鳞": [
		{"name":"【龙鳞】硬皮","desc":"受到伤害 -4%"}, {"name":"【龙鳞】再生","desc":"龙鳞反伤额外 +10%"},
		{"name":"【龙鳞】坚韧","desc":"格挡率 +3%"}, {"name":"【龙鳞】龙威","desc":"龙威 AOE 伤害 +30%"}],
	"烈焰": [
		{"name":"【烈焰】灼烧","desc":"灼烧伤害 +50%"}, {"name":"【烈焰】核心","desc":"灼烧最多可叠至 4 个同 id 实例"},
		{"name":"【烈焰】燎原","desc":"灼烧扩散范围 +1"}, {"name":"【烈焰】引爆","desc":"灼烧实例≥3时额外触发攻击力×80% AOE"}],
	"冰霜": [
		{"name":"【冰霜】蔓延","desc":"冻结命中后扩散到 1 个相邻敌人"}, {"name":"【冰霜】护盾","desc":"冻结敌人时获得的护盾翻倍"},
		{"name":"【冰霜】寒甲","desc":"被冻结敌人受到伤害 +20%"}, {"name":"【冰霜】极寒","desc":"冻结持续时间 +0.5秒"}],
	"雷霆": [
		{"name":"【雷霆】之速","desc":"闪电链多连 1 个目标"}, {"name":"【雷霆】余震","desc":"狂雷模式 +1秒"},
		{"name":"【雷霆】蓄能","desc":"狂雷模式期间暴击伤害 +50%"}, {"name":"【雷霆】轰鸣","desc":"闪电链伤害 +30%"}],
	"疾风": [
		{"name":"【疾风】步法","desc":"双动所需行动次数从3次降至2次"}, {"name":"【疾风】回响","desc":"双动重置 CD 时多重置 1 个技能"},
		{"name":"【疾风】疾行","desc":"速度 +5"}, {"name":"【疾风】连击","desc":"双动第二次攻击伤害 +30%"}],
	"铁壁": [
		{"name":"【铁壁】堡垒","desc":"格挡额外减伤 +10%"}, {"name":"【铁壁】反击","desc":"格挡时造成攻击力×50%反击伤害"},
		{"name":"【铁壁】坚壁","desc":"每格挡3次的反伤比例 +10%"}, {"name":"【铁壁】铁甲","desc":"格挡率 +3%"}],
	"暗影": [
		{"name":"【暗影】之刃","desc":"暗影突袭伤害额外 +30%"}, {"name":"【暗影】潜伏","desc":"暗影潜行 +2秒"},
		{"name":"【暗影】杀意","desc":"暗影突袭期间暴击伤害 +50%"}, {"name":"【暗影】疾影","desc":"暗影突袭持续时间 +2秒"}],
	"自然": [
		{"name":"【自然】恩赐","desc":"击杀回血 +5%"}, {"name":"【自然】庇护","desc":"自然护盾上限 +15%"},
		{"name":"【自然】繁茂","desc":"护盾存在时每秒回血 +2%"}, {"name":"【自然】生根","desc":"吸血 +2%"}],
	"引力": [
		{"name":"【引力】吸引","desc":"金币掉落 +10%"}, {"name":"【引力】护符","desc":"引力额外词条触发率 +0.5%"},
		{"name":"【引力】磁力","desc":"掉落装备时套装词条出现率 +2%"}, {"name":"【引力】万有","desc":"幸运 +5"}],
	"星辰": [
		{"name":"【星辰】专注","desc":"技能重置概率 +10%"}, {"name":"【星辰】涌动","desc":"星辰坠落所需星能 -1层"},
		{"name":"【星辰】辉光","desc":"星辰坠落伤害 +50%"}, {"name":"【星辰】流转","desc":"技能重置成功时获得2层星能"}],
	"幻影": [
		{"name":"【幻影】步法","desc":"闪避成功增伤 +20%"}, {"name":"【幻影】迷踪","desc":"幻影步持续时间 +1秒"},
		{"name":"【幻影】残影","desc":"幻影步期间攻击力 +15%"}, {"name":"【幻影】灵动","desc":"闪避率 +3%"}],
	"口才": [
		{"name":"【口才】魅力","desc":"普通战斗跳过概率 +5%"}, {"name":"【口才】超级魅力","desc":"普通战斗跳过概率 +5%，可与魅力叠加"},
		{"name":"【口才】雄辩","desc":"精英战斗跳过概率 +3%"}, {"name":"【口才】超级雄辩","desc":"精英战斗跳过概率 +3%，可与雄辩叠加"}],
	"奢侈": [
		{"name":"【奢侈】镀金","desc":"扣钱换取的攻击力额外 +10%"}, {"name":"【奢侈】挥霍","desc":"金币<5000时攻击力额外 +20%"},
		{"name":"【奢侈】豪赌","desc":"金币>10000时攻击力额外 +15%"}, {"name":"【奢侈】破产","desc":"金币<500时攻击力额外 +40%"}],
}

# 套装品质修正（概率乘数）
static var SET_QUALITY_MOD: Array[float] = [1.5, 1.2, 1.0, 0.7, 0.4]

# 附加词条池
static var AFFIX_POOL: Array[Dictionary] = [
	{ "name": "攻击%",     "type": "attack",  "min": 3.0,  "max": 15.0, "fmt": "+%.0f%%" },
	{ "name": "暴击率",    "type": "attack",  "min": 1.0,  "max": 8.0,  "fmt": "+%.0f%%" },
	{ "name": "暴击伤害",  "type": "attack",  "min": 5.0,  "max": 25.0, "fmt": "+%.0f%%" },
	{ "name": "技能伤害",  "type": "attack",  "min": 3.0,  "max": 15.0, "fmt": "+%.0f%%" },
	{ "name": "命中",      "type": "attack",  "min": 1.0,  "max": 8.0,  "fmt": "+%.0f%%" },
	{ "name": "防御%",     "type": "defense", "min": 3.0,  "max": 12.0, "fmt": "+%.0f%%" },
	{ "name": "生命%",     "type": "defense", "min": 3.0,  "max": 15.0, "fmt": "+%.0f%%" },
	{ "name": "格挡率",    "type": "defense", "min": 1.0,  "max": 25.0, "fmt": "+%.0f%%" },
	{ "name": "闪避率",    "type": "defense", "min": 1.0,  "max": 25.0, "fmt": "+%.0f%%" },
	{ "name": "吸血",      "type": "defense", "min": 1.0,  "max": 5.0,  "fmt": "+%.0f%%" },
	{ "name": "速度",      "type": "universal","min": 2.0, "max": 15.0, "fmt": "+%.0f" },
	{ "name": "冷却缩减",  "type": "universal","min": 2.0, "max": 10.0, "fmt": "+%.0f%%" },
	{ "name": "幸运",      "type": "universal","min": 2.0, "max": 15.0, "fmt": "+%.0f" },
	{ "name": "金币加成",  "type": "universal","min": 5.0, "max": 25.0, "fmt": "+%.0f%%" },
	{ "name": "经验加成",  "type": "universal","min": 3.0, "max": 10.0, "fmt": "+%.0f%%" },
	{ "name": "攻击(数值)","type": "attack",  "min": 5.0,  "max": 50.0, "fmt": "+%.0f" },
	{ "name": "防御(数值)","type": "defense", "min": 5.0,  "max": 40.0, "fmt": "+%.0f" },
]

# 互斥组
static var MUTEX: Dictionary = {
	"攻击%": "攻击(数值)",
	"攻击(数值)": "攻击%",
	"防御%": "防御(数值)",
	"防御(数值)": "防御%",
}

static var _next_uid: int = 1


## 生成一件装备
## level: 玩家等级
## options: { boss_tier, forced_quality, min_quality, max_quality }
static func generate(slot_name: String, level: int = 1, options: Dictionary = {}) -> Dictionary:
	# 1. 品质
	var forced_quality: int = int(options.get("forced_quality", -1))
	var min_quality: int = int(options.get("min_quality", -1))
	var max_quality: int = int(options.get("max_quality", -1))
	var quality: int = 0
	if forced_quality >= 0:
		quality = clampi(forced_quality, 0, QUALITY_WEIGHTS.size() - 1)
	else:
		var range_min: int = clampi(min_quality if min_quality >= 0 else 0, 0, QUALITY_WEIGHTS.size() - 1)
		var range_max: int = clampi(max_quality if max_quality >= 0 else QUALITY_WEIGHTS.size() - 1, 0, QUALITY_WEIGHTS.size() - 1)
		if range_max < range_min:
			var tmp: int = range_min
			range_min = range_max
			range_max = tmp
		quality = _roll_quality_in_range(range_min, range_max)

	# 2. 图标
	var icon_info: Dictionary = EquipIconsCls.random_icon(slot_name)

	# 3. 主属性
	var main: Dictionary = MAIN_BASE.get(slot_name, { "name": "???", "base": 1.0 })
	var main_value: float = main["base"] * QUALITY_COEF[quality]
	if slot_name in ["shoes", "ring", "necklace", "helmet"]:
		# 百分比类主属性不受装备档位系数影响
		pass
	else:
		# 数值类主属性受装备档位系数影响
		var eq_tier: int = _calc_eq_tier(level, int(options.get("boss_tier", 0)))
		var level_coef: float = 1.0 + float(eq_tier - 1) * 0.015
		main_value *= level_coef
	main_value = snapped(main_value, 0.1)

	# 4. 附加词条
	var affixes: Array[Dictionary] = []
	var affix_count: int = AFFIX_COUNTS[quality]
	var attack_count: int = 0
	var defense_count: int = 0
	var used_names: Array[String] = []

	for _i in range(affix_count):
		var max_retry: int = 10
		while max_retry > 0:
			max_retry -= 1
			var aff: Dictionary = AFFIX_POOL[randi() % AFFIX_POOL.size()]
			# 检查重复
			if aff["name"] in used_names:
				continue
			# 检查互斥
			var blocked: bool = false
			for un in used_names:
				if MUTEX.get(un, "") == aff["name"] or MUTEX.get(aff["name"], "") == un:
					blocked = true
					break
			if blocked:
				continue
			# 检查类别上限
			if aff["type"] == "attack" and attack_count >= 2:
				continue
			if aff["type"] == "defense" and defense_count >= 2:
				continue
			# 通过
			if aff["type"] == "attack":
				attack_count += 1
			elif aff["type"] == "defense":
				defense_count += 1
			used_names.append(aff["name"])
			var v: float = randf_range(aff["min"], aff["max"])
			v = snapped(v, 0.1)
			var disp: String = aff["fmt"] % v
			affixes.append({ "name": aff["name"], "type": aff["type"], "value": v, "display": disp })
			break

	# 5. 宝石槽位
	var gem_slots: int = 0
	if quality >= GEM_SLOT_MIN_QUALITY:
		gem_slots = gem_slots_from_roll(randf())

	# 5.5 套装判定（3% + 幸运×0.3%）× 品质修正
	var suit_name: String = ""
	var set_rate_bonus: float = float(options.get("set_rate_bonus", 0.0))
	var set_rate: float = ((3.0 + 0.0 * 0.3) * SET_QUALITY_MOD[quality] + set_rate_bonus) / 100.0  # 幸运=0 默认
	if randf() < set_rate:
		suit_name = SET_POOL[randi() % SET_POOL.size()]["name"]
	var set_affixes: Array[Dictionary] = []
	var extra_suit_name := ""
	if not suit_name.is_empty():
		var pool: Array = SET_AFFIX_POOL.get(suit_name, [])
		if not pool.is_empty():
			var rolled: Dictionary = pool[randi() % pool.size()].duplicate(true)
			rolled["type"] = "set"
			set_affixes.append(rolled)
		var extra_suit_rate := clampf(float(options.get("extra_suit_rate", 0.0)), 0.0, 1.0)
		if extra_suit_rate > 0.0 and randf() < extra_suit_rate:
			var candidates: Array[String] = []
			for set_def in SET_POOL:
				var candidate := str(set_def.get("name", ""))
				if not candidate.is_empty() and candidate != suit_name:
					candidates.append(candidate)
			if not candidates.is_empty():
				extra_suit_name = candidates[randi() % candidates.size()]

	# 6. 组装
	var uid: int = _next_uid
	_next_uid += 1

	return {
		"uid": uid,
		"slot": slot_name,
		"slot_type_id": EquipDataCls.SLOT_TYPE_ID.get(slot_name, 0),
		"quality": quality,
		"quality_name": EquipDataCls.QUALITY_NAMES.get(quality, "???"),
		"base_name": icon_info.get("name", "???"),
		"icon": icon_info.get("icon", "❓"),
		"icon_path": icon_info.get("icon_path", ""),
		"main_stat": main["name"],
		"main_value": main_value,
		"affixes": affixes,
		"gems": [] as Array[int],
		"gem_slots": gem_slots,
		"initial_gem_slots": gem_slots,
		"enhance": 0,
		"locked": quality >= 4,
		"acquired_at": int(Time.get_unix_time_from_system()),
		"suit_name": suit_name,
		"extra_suit_name": extra_suit_name,
		"set_affixes": set_affixes,
		"suit_count": 0,
	}


static func _roll_quality() -> int:
	return _roll_quality_in_range(0, QUALITY_WEIGHTS.size() - 1)


static func gem_slots_from_roll(roll: float) -> int:
	if roll < 0.60:
		return 1
	if roll < 0.90:
		return 2
	return 3


static func _roll_quality_in_range(min_q: int, max_q: int) -> int:
	var total_weight: float = 0.0
	for i in range(min_q, max_q + 1):
		total_weight += QUALITY_WEIGHTS[i]
	if total_weight <= 0.0:
		return clampi(min_q, 0, QUALITY_WEIGHTS.size() - 1)
	var r: float = randf() * total_weight
	var cumulative: float = 0.0
	for i in range(min_q, max_q + 1):
		cumulative += QUALITY_WEIGHTS[i]
		if r <= cumulative:
			return i
	return max_q


static func _calc_eq_tier(level: int, boss_tier: int) -> int:
	var eq_tier: int = maxi(level, 1)
	for tier in range(1, boss_tier + 1):
		eq_tier += 1 if _boss_tier_x_value(tier) > 0 and tier % _boss_tier_x_value(tier) == 0 else 0
	return eq_tier


static func _boss_tier_x_value(tier: int) -> int:
	if tier <= 30:
		return 20
	if tier <= 60:
		return 10
	if tier <= 100:
		return 6
	if tier <= 150:
		return 4
	return 3


## 获取品质前缀词
static func quality_prefix(q: int) -> String:
	match q:
		0: return ""
		1: return "精良的"
		2: return "稀有的"
		3: return "史诗的"
		4: return "传说的"
	return ""


## 品质颜色字符串（CSS hex）
static func quality_hex(q: int) -> String:
	match q:
		0: return "#999999"
		1: return "#33cc33"
		2: return "#3366ff"
		3: return "#b333ff"
		4: return "#ff9911"
	return "#ffffff"


## 获取装备完整名
static func full_name(eqp: Dictionary) -> String:
	var s: String = ""
	if eqp.get("quality", 0) >= 1:
		s += quality_prefix(eqp["quality"]) + " "
	s += eqp.get("base_name", "???")
	return s


## 序列化（存档用）
static func serialize(eqp: Dictionary) -> Dictionary:
	return eqp.duplicate(true)


static func deserialize(data: Dictionary) -> Dictionary:
	var d: Dictionary = data.duplicate(true)
	return d
