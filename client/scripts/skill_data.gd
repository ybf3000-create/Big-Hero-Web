class_name SkillData
extends RefCounted
## ============================================================
## SkillData v0.2 — 全部36技能定义 + 控制效果 + 被动技能
## 来源：技能系统细化案【定案】v0.6
## ============================================================

# 目标标签（对应策划案 §3.1）
enum TargetTag {
	FRONT_LINE,        # 前排位序
	BACK_LINE,         # 后排位序
	LOWEST_HP,         # 全场最低HP
	LOWEST_HP_PCT,     # 全场最低HP%
	HIGHEST_ATK,       # 全场最高攻击
	HIGHEST_DEF,       # 全场最高防御
	AOE_FRONT,         # 前排全体
	AOE_ALL,           # 敌方全体
	AOE_BACK,          # 后排全体
	PIERCE,            # 贯穿
	SELF,              # 玩家自身
	SELF_HEAL,         # 治疗自身
}

# 技能类型/流派
enum School {
	BURST,     # ⚡ 爆发流
	SUSTAIN,   # 🔥 持续流
	CONTROL,   # 🧊 控制流
	SURVIVAL,  # 🛡 生存流
	DOT,       # ☠ Dot流
	PIERCE,    # 🎯 贯穿流
}

# 控制类型
enum ControlType {
	NONE,
	FREEZE,    # 冻结
	STUN,      # 眩晕
	SILENCE,   # 沉默
	PARALYSIS, # 麻痹
	SLOW,      # 减速
	ANTI_HEAL, # 禁疗
}

# Dot叠加模式
enum DotMode {
	REFRESH,   # 刷新持续时间
	STACK,     # 叠加层数
}

# 近战技能直接在目标位置播放刀波，不生成飞行投射物。
const MELEE_SKILL_IDS: Array[int] = [
	1, 2, 3, 4, 5, 6,
	7, 8, 9, 12,
	15, 16, 19,
	27, 29,
	34, 36,
]

# 技能结构模板
# action_cd = 释放后等待的自身行动次数；price = 永久解锁金币价格（0为初始技能）
# { id, name, icon, school, target, action_cd, price, desc,
#   dmg_pct, hits, dot_pct, dot_tick_interval, dot_tick_count, dot_type, dot_mode,
#   control, control_dur, control_pct,
#   shield_pct, shield_stat, heal_pct, heal_stat,
#   buff_effect, buff_dur, bonus }

# ======== ⚡ 爆发流 1~6 ========
static var SKILLS: Array[Dictionary] = [
	# 1 - 重击
	{ "id": 1, "name": "重击", "icon": "攻", "school": 0, "target": 0,
	  "action_cd": 4, "price": 0, "desc": "对前排位序的单个敌人造成攻击力×150%的伤害。",
	  "dmg_pct": 150.0, "hits": 1 },
	# 2 - 猛力一击
	{ "id": 2, "name": "猛力一击", "icon": "💥", "school": 0, "target": 0,
	  "action_cd": 6, "price": 1000, "desc": "对前排位序的单个敌人造成攻击力×250%的伤害。",
	  "dmg_pct": 250.0, "hits": 1 },
	# 3 - 蓄力斩
	{ "id": 3, "name": "蓄力斩", "icon": "蓄", "school": 0, "target": 0,
	  "action_cd": 8, "price": 10000, "desc": "对前排位序的单个敌人造成攻击力×400%的伤害。蓄力仅为表现，不会延迟出手。",
	  "dmg_pct": 400.0, "hits": 1 },
	# 4 - 碎裂打击
	{ "id": 4, "name": "碎裂打击", "icon": "碎", "school": 0, "target": 5,
	  "action_cd": 6, "price": 10000, "desc": "对全场防御最高的敌人造成攻击力×180%的伤害，本次攻击无视目标20%的防御。",
	  "dmg_pct": 180.0, "hits": 1, "bonus": { "ignore_def_pct": 20 } },
	# 5 - 致命一击
	{ "id": 5, "name": "致命一击", "icon": "致", "school": 0, "target": 2,
	  "action_cd": 9, "price": 100000, "desc": "对全场当前生命值最低的敌人造成攻击力×500%的伤害；目标生命低于30%时伤害翻倍。",
	  "dmg_pct": 500.0, "hits": 1, "bonus": { "execute_threshold": 0.3, "execute_mult": 2.0 } },
	# 6 - 终结技
	{ "id": 6, "name": "终结技", "icon": "🎯", "school": 0, "target": 3,
	  "action_cd": 10, "price": 100000, "desc": "对全场生命比例最低的敌人造成攻击力×300%的伤害；目标每损失1%生命，本次伤害提高1%。",
	  "dmg_pct": 300.0, "hits": 1, "bonus": { "missing_hp_scale": 1.0 } },

	# ======== 🔥 持续流 7~12 ========
	{ "id": 7, "name": "快速打击", "icon": "快", "school": 1, "target": 0,
	  "action_cd": 4, "price": 1000, "desc": "对前排位序的单个敌人造成攻击力×110%的伤害，本次攻击无视目标10%的防御。",
	  "dmg_pct": 110.0, "hits": 1, "bonus": { "ignore_def_pct": 10 } },
	{ "id": 8, "name": "连击", "icon": "💥", "school": 1, "target": 0,
	  "action_cd": 5, "price": 1000, "desc": "对前排位序的单个敌人连续攻击2次，每次造成攻击力×55%的伤害，并分别判定命中与暴击。",
	  "dmg_pct": 55.0, "hits": 2 },
	{ "id": 9, "name": "旋风斩", "icon": "🌀", "school": 1, "target": 7,
	  "action_cd": 7, "price": 10000, "desc": "对所有存活的敌人各造成攻击力×90%的伤害。",
	  "dmg_pct": 90.0, "hits": 1 },
	{ "id": 10, "name": "连射", "icon": "🏹", "school": 1, "target": 0,
	  "action_cd": 7, "price": 10000, "desc": "对前排位序的单个敌人连续攻击3次，每次造成攻击力×40%的伤害，并分别判定命中与暴击。",
	  "dmg_pct": 40.0, "hits": 3 },
	{ "id": 11, "name": "回旋镖", "icon": "回", "school": 1, "target": 7,
	  "action_cd": 7, "price": 10000, "desc": "攻击最多2个存活的敌人，对每个目标造成攻击力×110%的伤害。",
	  "dmg_pct": 110.0, "hits": 1, "bonus": { "max_targets": 2 } },
	{ "id": 12, "name": "无尽打击", "icon": "♾", "school": 1, "target": 0,
	  "action_cd": 8, "price": 50000, "desc": "对前排位序的单个敌人造成伤害。每场战斗首次倍率为攻击力×90%，每次使用提高10个百分点，第10次起保持180%；战斗结束后重置。",
	  "dmg_pct": 90.0, "hits": 1, "bonus": { "stack_step_pct": 10.0, "max_stacks": 10 } },

	# ======== 🧊 控制流 13~20 ========
	{ "id": 13, "name": "冰冻射击", "icon": "冰", "school": 2, "target": 0,
	  "action_cd": 6, "price": 10000, "desc": "对前排位序的单个敌人造成攻击力×100%的伤害并冻结4秒；对Boss的冻结时间减半。",
	  "dmg_pct": 100.0, "hits": 1,
	  "control": ControlType.FREEZE, "control_dur": 4.0 },
	{ "id": 14, "name": "冰霜新星", "icon": "冰", "school": 2, "target": 7,
	  "action_cd": 8, "price": 50000, "desc": "对所有存活的敌人各造成攻击力×80%的伤害并减速6秒；对Boss的减速时间减半。",
	  "dmg_pct": 80.0, "hits": 1,
	  "control": ControlType.SLOW, "control_dur": 6.0 },
	{ "id": 15, "name": "眩晕锤", "icon": "晕", "school": 2, "target": 0,
	  "action_cd": 7, "price": 10000, "desc": "对前排位序的单个敌人造成攻击力×120%的伤害并眩晕4秒；对Boss的眩晕时间减半。",
	  "dmg_pct": 120.0, "hits": 1,
	  "control": ControlType.STUN, "control_dur": 4.0 },
	{ "id": 16, "name": "雷霆一击", "icon": "雷", "school": 2, "target": 0,
	  "action_cd": 7, "price": 10000, "desc": "对前排位序的单个敌人造成攻击力×130%的伤害并麻痹6秒；对Boss的麻痹时间减半。",
	  "dmg_pct": 130.0, "hits": 1,
	  "control": ControlType.PARALYSIS, "control_dur": 6.0 },
	{ "id": 17, "name": "静默领域", "icon": "🔇", "school": 2, "target": 7,
	  "action_cd": 8, "price": 50000, "desc": "对所有存活的敌人各造成攻击力×60%的伤害并沉默5秒；对Boss的沉默时间减半。",
	  "dmg_pct": 60.0, "hits": 1,
	  "control": ControlType.SILENCE, "control_dur": 5.0 },
	{ "id": 18, "name": "深度冻结", "icon": "冻", "school": 2, "target": 0,
	  "action_cd": 9, "price": 100000, "desc": "对前排位序的单个敌人造成攻击力×200%的伤害并冻结6秒；对Boss冻结3秒。",
	  "dmg_pct": 200.0, "hits": 1,
	  "control": ControlType.FREEZE, "control_dur": 6.0 },
	{ "id": 19, "name": "腐蚀之触", "icon": "蚀", "school": 2, "target": 4,
	  "action_cd": 8, "price": 50000, "desc": "对全场攻击最高的敌人造成攻击力×100%的伤害并禁疗8秒；对Boss的禁疗时间减半。",
	  "dmg_pct": 100.0, "hits": 1,
	  "control": ControlType.ANTI_HEAL, "control_dur": 8.0 },
	{ "id": 20, "name": "时间凝滞", "icon": "⏳", "school": 2, "target": 7,
	  "action_cd": 10, "price": 100000, "desc": "对所有存活的敌人各造成攻击力×50%的伤害并麻痹6秒；对Boss的麻痹时间减半。",
	  "dmg_pct": 50.0, "hits": 1,
	  "control": ControlType.PARALYSIS, "control_dur": 6.0 },

	# ======== 🛡 生存流 21~26 ========
	{ "id": 21, "name": "护盾", "icon": "盾", "school": 3, "target": TargetTag.SELF,
	  "action_cd": 6, "price": 1000, "desc": "为自身生成等于防御力×300%的护盾，持续5秒。护盾优先吸收受到的伤害。",
	  "shield_pct": 300.0, "shield_stat": "def" },
	{ "id": 22, "name": "治疗波", "icon": "💚", "school": 3, "target": TargetTag.SELF_HEAL,
	  "action_cd": 6, "price": 0, "desc": "立即为自身恢复等于攻击力×150%的生命值，恢复量不超过最大生命。",
	  "heal_pct": 150.0, "heal_stat": "atk" },
	{ "id": 23, "name": "铁壁姿态", "icon": "🏰", "school": 3, "target": TargetTag.SELF,
	  "action_cd": 7, "price": 10000, "desc": "使自身防御提高至原来的2倍，持续4秒；不会改变行动速度。",
	  "buff_effect": "def_x2", "buff_dur": 4.0 },
	{ "id": 24, "name": "坚毅", "icon": "💪", "school": 3, "target": TargetTag.SELF,
	  "action_cd": 7, "price": 50000, "desc": "使自身受到的伤害降低40%并免疫所有控制效果，持续4秒。",
	  "buff_effect": "tenacity", "buff_dur": 4.0 },
	{ "id": 25, "name": "生命绽放", "icon": "🌿", "school": 3, "target": TargetTag.SELF_HEAL,
	  "action_cd": 8, "price": 50000, "desc": "立即恢复自身5%最大生命，之后每1秒再恢复一次，共触发5次。",
	  "heal_pct": 5.0, "heal_stat": "max_hp_pct", "bonus": { "tick_interval": 1.0, "tick_count": 5 } },
	{ "id": 26, "name": "不屈意志", "icon": "志", "school": 3, "target": TargetTag.SELF,
	  "action_cd": 8, "price": 100000, "desc": "自身生命低于20%时自动触发，4秒内受到致命伤害时生命最低保留1点；每场战斗只能触发一次。",
	  "buff_effect": "undying", "buff_dur": 4.0, "bonus": { "trigger_hp_pct": 0.2 } },

	# ======== ☠ Dot流 27~32 ========
	{ "id": 27, "name": "毒刃", "icon": "毒", "school": 4, "target": 0,
	  "action_cd": 5, "price": 1000, "desc": "对前排位序的单个敌人造成攻击力×80%的直接伤害，并施加毒素：每次造成攻击力×30%的伤害，立即触发首次，此后每2秒触发，共4次。",
	  "dmg_pct": 80.0, "hits": 1,
	  "dot_pct": 30.0, "dot_tick_interval": 2.0, "dot_tick_count": 4, "dot_type": "poison", "dot_mode": 0 },
	{ "id": 28, "name": "烈焰灼烧", "icon": "焰", "school": 4, "target": 7,
	  "action_cd": 7, "price": 10000, "desc": "对所有存活的敌人各造成攻击力×60%的直接伤害，并施加灼烧：每次造成攻击力×30%的伤害，立即触发首次，此后每2秒触发，共4次。",
	  "dmg_pct": 60.0, "hits": 1,
	  "dot_pct": 30.0, "dot_tick_interval": 2.0, "dot_tick_count": 4, "dot_type": "burn", "dot_mode": 0 },
	{ "id": 29, "name": "撕裂", "icon": "裂", "school": 4, "target": 0,
	  "action_cd": 5, "price": 10000, "desc": "对前排位序的单个敌人造成攻击力×120%的直接伤害，并施加流血：每次造成攻击力×20%的伤害，立即触发首次，此后每2秒触发，共3次。",
	  "dmg_pct": 120.0, "hits": 1,
	  "dot_pct": 20.0, "dot_tick_interval": 2.0, "dot_tick_count": 3, "dot_type": "bleed", "dot_mode": 0 },
	{ "id": 30, "name": "毒雾", "icon": "雾", "school": 4, "target": 7,
	  "action_cd": 8, "price": 50000, "desc": "对所有存活的敌人各造成攻击力×40%的直接伤害，并施加毒素：每次造成攻击力×35%的伤害，立即触发首次，此后每2秒触发，共5次。",
	  "dmg_pct": 40.0, "hits": 1,
	  "dot_pct": 35.0, "dot_tick_interval": 2.0, "dot_tick_count": 5, "dot_type": "poison", "dot_mode": 0 },
	{ "id": 31, "name": "剧毒爆发", "icon": "💚", "school": 4, "target": 0,
	  "action_cd": 9, "price": 50000, "desc": "立即对前排位序的单个敌人造成其所有持续伤害剩余总额×1.5的伤害，且不消耗原有持续效果；目标没有持续伤害时无效果。",
	  "bonus": { "detonate_dot": 1.5 } },
	{ "id": 32, "name": "瘟疫传播", "icon": "疫", "school": 4, "target": 7,
	  "action_cd": 10, "price": 100000, "desc": "将目标身上持续伤害的剩余次数和下次触发时间复制给其他存活敌人；没有可复制的持续伤害或仅剩1名敌人时无效果。",
	  "bonus": { "spread_dot": true } },

	# ======== 🎯 贯穿流 33~36 ========
	{ "id": 33, "name": "穿刺射击", "icon": "🏹", "school": 5, "target": 9,
	  "action_cd": 6, "price": 1000, "desc": "对前排目标造成攻击力×120%的伤害，并对同列后排目标造成攻击力×80%的贯穿伤害。同行后排为空时只攻击前排。",
	  "dmg_pct": 120.0, "hits": 1, "bonus": { "pierce_back_dmg": 80.0 } },
	{ "id": 34, "name": "裂地斩", "icon": "🌍", "school": 5, "target": 9,
	  "action_cd": 8, "price": 50000, "desc": "对前排目标造成攻击力×180%的伤害，并对同列后排目标造成攻击力×120%的贯穿伤害及8秒减速。同行后排为空时只攻击前排。",
	  "dmg_pct": 180.0, "hits": 1,
	  "bonus": { "pierce_back_dmg": 120.0, "pierce_back_slow": 8.0 } },
	{ "id": 35, "name": "穿透箭雨", "icon": "🌧", "school": 5, "target": 9,
	  "action_cd": 7, "price": 10000, "desc": "对前排目标及同列后排目标分别造成攻击力×90%的伤害，两段伤害均可暴击。同行后排为空时只攻击前排。",
	  "dmg_pct": 90.0, "hits": 1, "bonus": { "pierce_back_dmg": 90.0 } },
	{ "id": 36, "name": "暗影突袭", "icon": "🌑", "school": 5, "target": 9,
	  "action_cd": 9, "price": 100000, "desc": "对前排目标造成攻击力×150%的伤害，并对同列后排目标造成攻击力×100%的贯穿伤害；后排生命低于30%时，后排伤害倍率提高至150%。",
	  "dmg_pct": 150.0, "hits": 1,
	  "bonus": { "pierce_back_dmg": 100.0, "pierce_back_execute": { "threshold": 0.3, "mult": 1.5 } } },
]

# 按ID快速查找
static func get_skill(id: int) -> Dictionary:
	for s in SKILLS:
		if s["id"] == id:
			return s
	return {}


static func action_cd_text(skill: Dictionary) -> String:
	var turns := int(skill.get("action_cd", 1))
	return "CD%d回合" % turns

# 按流派筛选
static func get_skills_by_school(school: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for s in SKILLS:
		if s["school"] == school:
			result.append(s)
	return result

# 获取技能显示名称
static func skill_name(id: int) -> String:
	var s := get_skill(id)
	return s.get("name", "???")

# 获取技能图标
static func skill_icon(id: int) -> String:
	var s := get_skill(id)
	return s.get("icon", "技")


static func is_melee_skill(id: int) -> bool:
	return id in MELEE_SKILL_IDS

# 流派名称
static func school_name(school: int) -> String:
	match school:
		0: return "爆发流"
		1: return "持续流"
		2: return "控制流"
		3: return "生存流"
		4: return "Dot流"
		5: return "贯穿流"
	return "未知"

# 控制类型名称
static func control_name(ct: int) -> String:
	match ct:
		ControlType.FREEZE: return "冻结"
		ControlType.STUN: return "眩晕"
		ControlType.SILENCE: return "沉默"
		ControlType.PARALYSIS: return "麻痹"
		ControlType.SLOW: return "减速"
		ControlType.ANTI_HEAL: return "禁疗"
	return ""
