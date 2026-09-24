class_name ItemDB
extends RefCounted
## ============================================================
## ItemDB - 物品数据库 v0.1
## 所有物品的模板定义（消耗品/装备/材料）
## ============================================================

enum ItemType {
	CONSUMABLE = 0,
	WEAPON     = 1,
	ARMOR      = 2,   # 衣服/防具
	SHOES      = 3,   # 鞋子
	RING       = 4,   # 戒指
	NECKLACE   = 5,   # 项链
	CAPE       = 6,   # 披风
	HELMET     = 7,   # 头盔
	CHARM      = 8,   # 护符
	MATERIAL   = 9,   # 材料
}

# 物品模板结构：{ id, name, type, icon, desc, price, stack_max, stats }
# stats: { atk, def, hp, spd, luk, heal, exp_bonus, gold_bonus }
static var ITEMS: Dictionary = {}

static func _init_all() -> void:
	if not ITEMS.is_empty():
		return
	ITEMS = {
		# ======== 消耗品 ========
		1: { "id": 1, "name": "回复药水", "type": 0, "icon": "药", "desc": "恢复 50 HP", "price": 30, "stack_max": 99, "stats": { "heal": 50 } },
		2: { "id": 2, "name": "大回复药", "type": 0, "icon": "药", "desc": "恢复 200 HP", "price": 100, "stack_max": 50, "stats": { "heal": 200 } },
		3: { "id": 3, "name": "经验卷轴", "type": 0, "icon": "经", "desc": "获得 100 经验", "price": 80, "stack_max": 20, "stats": { "exp_bonus": 100 } },
		4: { "id": 4, "name": "金币袋",   "type": 0, "icon": "金", "desc": "获得 200 金币", "price": 0, "stack_max": 30, "stats": { "gold_bonus": 200 } },
		5: { "id": 5, "name": "天命卡",   "type": 0, "icon": "卡", "desc": "获得后立即随机触发一次命运事件", "price": 0, "stack_max": 99, "stats": { "fate_event": 1 } },
		6: { "id": 6, "name": "打孔器",   "type": 0, "icon": "孔", "desc": "为符合条件的装备增加1个宝石孔", "price": 0, "stack_max": 99, "stats": { "socket_tool": 1 } },

		# ======== 武器 ========
		10: { "id": 10, "name": "铁剑",   "type": 1, "icon": "剑", "desc": "基础武器",     "price": 100, "stack_max": 1, "stats": { "atk": 8 } },
		11: { "id": 11, "name": "钢剑",   "type": 1, "icon": "剑", "desc": "精良武器",     "price": 300, "stack_max": 1, "stats": { "atk": 18 } },
		12: { "id": 12, "name": "火焰剑", "type": 1, "icon": "剑", "desc": "附带火焰伤害", "price": 600, "stack_max": 1, "stats": { "atk": 28, "luk": 5 } },

		# ======== 防具 ========
		20: { "id": 20, "name": "布甲",   "type": 2, "icon": "甲", "desc": "基础防具",   "price": 80,  "stack_max": 1, "stats": { "def": 5 } },
		21: { "id": 21, "name": "锁子甲", "type": 2, "icon": "甲", "desc": "精良防具",   "price": 250, "stack_max": 1, "stats": { "def": 12 } },
		22: { "id": 22, "name": "龙鳞甲", "type": 2, "icon": "甲", "desc": "龙鳞打造",   "price": 500, "stack_max": 1, "stats": { "def": 22, "hp": 30 } },

		# ======== 鞋子 ========
		30: { "id": 30, "name": "布鞋",     "type": 3, "icon": "鞋", "desc": "基础鞋子",   "price": 60,  "stack_max": 1, "stats": { "spd": 4 } },
		31: { "id": 31, "name": "疾风靴",   "type": 3, "icon": "鞋", "desc": "速度+10",    "price": 250, "stack_max": 1, "stats": { "spd": 10 } },

		# ======== 戒指 ========
		40: { "id": 40, "name": "铜戒指",   "type": 4, "icon": "戒", "desc": "攻击+3",     "price": 120, "stack_max": 1, "stats": { "atk": 3 } },
		41: { "id": 41, "name": "力量戒指", "type": 4, "icon": "戒", "desc": "攻击+10",    "price": 350, "stack_max": 1, "stats": { "atk": 10 } },

		# ======== 项链 ========
		50: { "id": 50, "name": "银项链",   "type": 5, "icon": "链", "desc": "生命+20",    "price": 150, "stack_max": 1, "stats": { "hp": 20 } },
		51: { "id": 51, "name": "生命项链", "type": 5, "icon": "链", "desc": "生命+50",    "price": 400, "stack_max": 1, "stats": { "hp": 50 } },

		# ======== 披风 ========
		60: { "id": 60, "name": "麻布披风", "type": 6, "icon": "披", "desc": "防御+3",     "price": 100, "stack_max": 1, "stats": { "def": 3 } },
		61: { "id": 61, "name": "英雄披风", "type": 6, "icon": "披", "desc": "全属性+3",   "price": 500, "stack_max": 1, "stats": { "atk": 3, "def": 3, "spd": 3 } },

		# ======== 头盔 ========
		70: { "id": 70, "name": "皮帽",     "type": 7, "icon": "帽", "desc": "防御+4",     "price": 80,  "stack_max": 1, "stats": { "def": 4 } },
		71: { "id": 71, "name": "钢盔",     "type": 7, "icon": "⛑", "desc": "防御+12",    "price": 300, "stack_max": 1, "stats": { "def": 12 } },

		# ======== 护符 ========
		80: { "id": 80, "name": "幸运符",   "type": 8, "icon": "符", "desc": "幸运+5",     "price": 180, "stack_max": 1, "stats": { "luk": 5 } },
		81: { "id": 81, "name": "守护护符", "type": 8, "icon": "符", "desc": "幸运+15",   "price": 450, "stack_max": 1, "stats": { "luk": 15 } },

		# ======== 材料 ========
		90: { "id": 90, "name": "铁矿石", "type": 9, "icon": "矿", "desc": "锻造材料", "price": 15, "stack_max": 99, "stats": {} },
		91: { "id": 91, "name": "龙鳞片", "type": 9, "icon": "材", "desc": "稀有材料", "price": 50, "stack_max": 50, "stats": {} },
	}


static func get_item(id: int) -> Dictionary:
	_init_all()
	return ITEMS.get(id, {})


static func get_name(id: int) -> String:
	return get_item(id).get("name", "???")


static func get_icon(id: int) -> String:
	return get_item(id).get("icon", "物")
