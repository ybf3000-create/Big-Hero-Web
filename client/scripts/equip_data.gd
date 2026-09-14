class_name EquipData
extends RefCounted
## ============================================================
## EquipData — 装备数据模型 v1.0
## 品质/词条/宝石/强化等级/套装 全部数据封装
## ============================================================

# 品质枚举
enum Quality {
	GRAY   = 0,  # 普通
	GREEN  = 1,  # 精良
	BLUE   = 2,  # 稀有
	PURPLE = 3,  # 史诗
	ORANGE = 4,  # 传说
}

# 品质名称/颜色
static var QUALITY_NAMES: Dictionary = {
	0: "普通", 1: "精良", 2: "稀有", 3: "史诗", 4: "传说",
}
static var QUALITY_COLORS: Dictionary = {
	0: Color(0.6, 0.6, 0.6),
	1: Color(0.2, 0.8, 0.2),
	2: Color(0.2, 0.4, 1.0),
	3: Color(0.7, 0.2, 1.0),
	4: Color(1.0, 0.6, 0.1),
}

# 部位 type_id 映射（与 equipment.gd SLOT_TYPE 对齐）
static var SLOT_TYPE_ID: Dictionary = {
	"weapon": 1, "armor": 2, "shoes": 3, "ring": 4,
	"necklace": 5, "cape": 6, "helmet": 7, "charm": 8,
}
static var TYPE_ID_TO_SLOT: Dictionary = {
	1: "weapon", 2: "armor", 3: "shoes", 4: "ring",
	5: "necklace", 6: "cape", 7: "helmet", 8: "charm",
}

# 宝石数据 { id: { name, icon, desc } }
static var GEM_DEFS: Dictionary = {
	1: { "id": 1, "name": "红宝石", "icon": "🔴", "desc": "攻击力 +10/级" },
	2: { "id": 2, "name": "蓝宝石", "icon": "🔵", "desc": "防御力 +10/级" },
	3: { "id": 3, "name": "绿宝石", "icon": "🟢", "desc": "生命值 +50/级" },
	4: { "id": 4, "name": "黄宝石", "icon": "🟡", "desc": "暴击率 +0.5%/级" },
	5: { "id": 5, "name": "紫宝石", "icon": "🟣", "desc": "技能伤害 +0.5%/级" },
	6: { "id": 6, "name": "钻石",   "icon": "💎", "desc": "命中率 +0.5%/级" },
	7: { "id": 7, "name": "橙宝石", "icon": "🟠", "desc": "暴击伤害 +2%/级" },
	8: { "id": 8, "name": "银宝石", "icon": "⚪", "desc": "格挡率 +0.5%/级" },
}

# 装备实例数据结构:
# {
#   uid: int           -- 唯一ID
#   slot: String       -- 部位 (weapon/armor/...)
#   slot_type_id: int  -- type_id 1~8
#   quality: int       -- 0~4
#   base_name: String  -- 基础名（从图标配置随机）
#   icon: String       -- emoji 图标
#   main_stat: String  -- 主属性名
#   main_value: float  -- 主属性值
#   affixes: Array[{name, value}] -- 附加词条
#   gems: Array[int]   -- 已镶嵌宝石ID列表
#   gem_slots: int     -- 孔数
#   enhance: int       -- 强化等级 0~200
#   suit_name: String  -- 套装名（空=无套装）
#   suit_count: int    -- 当前穿戴的套装件数（运行时计算）
# }


func _init() -> void:
	pass
