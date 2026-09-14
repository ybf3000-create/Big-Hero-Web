class_name Inventory
extends RefCounted
## ============================================================
## Inventory - 背包系统 v0.2
## 物品增删、堆叠、使用、扩容
## ============================================================

const ItemDBRef = preload("res://scripts/item_db.gd")

signal item_changed

# items: Array[{ item_id: int, count: int }]
var items: Array[Dictionary] = []
var capacity: int = 100
var expansion_count: int = 0  # 已扩容次数

# 扩容成本表（索引=扩容次数）
const EXPANSION_COST: Array[int] = [
	5000,     # 第1次: 100→150
	15000,    # 第2次: 150→200
	30000,    # 第3次: 200→250
	50000,    # 第4次: 250→300
	75000,    # 第5次: 300→350
	100000,   # 第6次: 350→400
	150000,   # 第7次: 400→450
	200000,   # 第8次: 450→500
	300000,   # 第9次: 500→550
	400000,   # 第10次: 550→600
	500000,   # 第11次: 600→650
	750000,   # 第12次: 650→700
	1000000,  # 第13次: 700→750
	1500000,  # 第14次: 750→800
]
const MAX_EXPANSIONS: int = 18
const SLOTS_PER_EXPAND: int = 50


## 添加物品（自动堆叠）
func add_item(item_id: int, count: int = 1) -> int:
	var defn: Dictionary = ItemDBRef.get_item(item_id)
	if defn.is_empty():
		return 0

	var stack_max: int = defn.get("stack_max", 1)
	var added: int = 0

	# 先尝试堆叠到已有槽位
	for slot in items:
		if slot["item_id"] == item_id and slot["count"] < stack_max:
			var room: int = stack_max - slot["count"]
			var take: int = mini(count, room)
			slot["count"] += take
			count -= take
			added += take
			if count <= 0:
				item_changed.emit()
				return added

	# 剩余创建新槽位
	while count > 0 and items.size() < capacity:
		var take: int = mini(count, stack_max)
		items.append({ "item_id": item_id, "count": take })
		count -= take
		added += take

	item_changed.emit()
	return added


## 移除物品
func remove_item(slot_idx: int, count: int = 1) -> bool:
	if slot_idx < 0 or slot_idx >= items.size():
		return false
	var slot: Dictionary = items[slot_idx]
	slot["count"] -= count
	if slot["count"] <= 0:
		items.remove_at(slot_idx)
	item_changed.emit()
	return true


## 获取槽位信息
func get_slot(slot_idx: int) -> Dictionary:
	if slot_idx < 0 or slot_idx >= items.size():
		return {}
	return items[slot_idx].duplicate()


func get_slot_count() -> int:
	return items.size()


## --- 扩容系统 ---

## 判断是否已满（不能再扩容了）
func is_expansion_maxed() -> bool:
	return expansion_count >= MAX_EXPANSIONS


## 获取下一次扩容需要的金币数，-1 表示已满
func get_next_expansion_cost() -> int:
	if is_expansion_maxed():
		return -1
	if expansion_count < EXPANSION_COST.size():
		return EXPANSION_COST[expansion_count]
	# 超出定义表的部分，自动递增长（2倍上次）
	var last_cost: int = EXPANSION_COST[-1]
	var extra: int = expansion_count - EXPANSION_COST.size() + 1
	return last_cost * int(pow(1.3, extra))


## 执行扩容（已验证金币足够后调用）
func expand() -> void:
	if is_expansion_maxed():
		return
	expansion_count += 1
	capacity += SLOTS_PER_EXPAND
	item_changed.emit()


## 序列化
func to_dict() -> Dictionary:
	return {
		"items": items.duplicate(true),
		"expansion_count": expansion_count,
		"capacity": capacity,
	}


func from_dict(data) -> void:
	items.clear()
	if data is Array:
		# 旧格式兼容
		for d in data:
			items.append(d.duplicate())
		expansion_count = 0
		capacity = 100
	elif data is Dictionary:
		for d in data.get("items", []):
			items.append(d.duplicate())
		expansion_count = data.get("expansion_count", 0)
		capacity = data.get("capacity", 100)
