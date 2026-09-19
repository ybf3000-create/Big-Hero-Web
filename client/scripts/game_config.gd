class_name GameConfig
extends RefCounted
## ==================================================================
## GameConfig — 游戏全局配置表 v0.1
## 集中管理：主角数值 / 货币 / 装备槽 / 技能 / 经济常数
##
## 使用方式:
##   const Config = preload("res://scripts/game_config.gd")
##   var hp: float = Config.PLAYER_BASE["hp"]
##   var gold_drop: int = Config.ECONOMY["battle_gold_min"]
##
## 修数值只需改这一个文件，不需要翻其他代码。
## ==================================================================

# ===================================================================
# 一、主角基础数值
# ===================================================================
static var PLAYER_BASE: Dictionary = {
	"name":           "勇者",    # 默认名字
	"level":          1,         # 初始等级
	"hp":             100.0,     # 基础生命值
	"atk":            10.0,      # 基础攻击力
	"def":            5.0,       # 基础防御力
	"spd":            5.0,       # 基础速度
	"luk":            5.0,       # 基础幸运
	"exp":            0,         # 初始经验
	"exp_max":        100,       # 初始升级所需经验
	"gold":           0,         # 初始金币
	"revive_coins":   3,         # 初始复活币
	"revive_max":     3,         # 最大复活币
	"grid_index":     0,         # 初始位置（0=起点）
	"map_total_grids": 28,       # 地图总格数
}

# ===================================================================
# 二、等级成长曲线
#    每级经验 = exp_base + level * exp_growth
#    每级属性增量 = base_attr * attr_growth_rate
# ===================================================================
static var LEVEL_UP: Dictionary = {
	"exp_base":         100,     # 基础经验需求
	"exp_growth":       50,      # 每级增长
	"hp_growth":        20.0,    # 每级 +HP
	"atk_growth":       3.0,     # 每级 +ATK
	"def_growth":       2.0,     # 每级 +DEF
	"spd_growth":       1.0,     # 每级 +SPD
	"luk_growth":       1.0,     # 每级 +LUK
	"gold_reward":      50,      # 升级奖励金币基数
}

# ===================================================================
# 三、货币系统
# ===================================================================
static var CURRENCY: Dictionary = {
	"gold":             { "name": "金币", "icon": "金", "desc": "通用货币，用于购买和强化" },
	"revive_coin":      { "name": "复活币", "icon": "复", "desc": "战斗中复活一次" },
	"lottery_ticket":   { "name": "彩票", "icon": "彩", "desc": "用于彩票格抽奖" },
	"diamond":          { "name": "命中宝石", "icon": "钻", "desc": "宝石材料，不属于货币" },
}

# ===================================================================
# 四、装备槽定义
#    与 equipment.gd 的 SLOT_TYPE 保持一致
#    type_id 对应 item_db.gd 的物品类型编号
# ===================================================================
static var EQUIP_SLOTS: Array[Dictionary] = [
	{ "key": "weapon",   "name": "武器",  "type_id": 1, "icon": "武" },
	{ "key": "armor",    "name": "防具",  "type_id": 2, "icon": "防" },
	{ "key": "shoes",    "name": "鞋子",  "type_id": 3, "icon": "鞋" },
	{ "key": "ring",     "name": "戒指",  "type_id": 4, "icon": "戒" },
	{ "key": "necklace", "name": "项链",  "type_id": 5, "icon": "链" },
	{ "key": "cape",     "name": "披风",  "type_id": 6, "icon": "披" },
	{ "key": "helmet",   "name": "头盔",  "type_id": 7, "icon": "盔" },
	{ "key": "charm",    "name": "护符",  "type_id": 8, "icon": "符" },
]

# ===================================================================
# 五、技能系统（预留框架）
#    每个技能：id, name, icon, type(主动/被动), cooldown, cost, effect
#    type: 0=伤害 1=治疗 2=Buff 3=Debuff 4=被动
# ===================================================================
static var SKILLS: Dictionary = {
	# 示例技能结构（后续 Phase 2 填充）
	# 1: { "id": 1, "name": "斩击", "icon": "⚔", "type": 0, "cd": 2, "cost": 10, "power": 1.5, "desc": "对单体造成150%物理伤害" },
	# 2: { "id": 2, "name": "治疗术", "icon": "♡", "type": 1, "cd": 3, "cost": 15, "power": 0.3, "desc": "恢复最大HP的30%" },
}

static var SKILL_TYPE_NAMES: Dictionary = {
	0: "伤害",
	1: "治疗",
	2: "Buff",
	3: "Debuff",
	4: "被动",
}

# ===================================================================
# 六、经济与掉落常数
# ===================================================================
static var ECONOMY: Dictionary = {
	"start_pass_gold":       50,    # 经过起点奖励金币
	"battle_gold_min":       10,    # 战斗胜利金币下限
	"battle_gold_max":       50,    # 战斗胜利金币上限
	"battle_exp_base":       20,    # 战斗基础经验
	"battle_exp_per_level":  5,     # 每怪等级额外经验
	"treasure_gold_min":     30,    # 宝箱金币下限
	"treasure_gold_max":     200,   # 宝箱金币上限
	"empty2_gold":           50,    # 空地2 额外金币
}

# ===================================================================
# 七、战斗常数（预留 Phase 2 使用）
# ===================================================================
static var COMBAT: Dictionary = {
	"crit_rate_base":   0.05,   # 基础暴击率 5%
	"crit_dmg_mult":    1.5,    # 暴击伤害倍率
	"dodge_rate_base":  0.03,   # 基础闪避率
	"min_damage":       1,      # 保底伤害
	"damage_formula":   "atk * (1 + luk * 0.01) / (1 + def * 0.02)",  # 伤害公式
	"frontline_slots":  3,      # 前排槽位数
	"backline_slots":   3,      # 后排槽位数
}

# ===================================================================
# 八、UI 常量
# ===================================================================
static var UI: Dictionary = {
	"base_width":   1280,
	"base_height":  720,
	"top_bar_h":    110,
	"bottom_bar_h": 86,
	"tile_w":       160,        # 地块宽度
	"tile_h":       90,         # 地块高度
	"tile_shear":   45,         # 斜边偏移
	"tile_count":   7,          # 可见地块数
	"dice_min":     1,
	"dice_max":     6,
}
