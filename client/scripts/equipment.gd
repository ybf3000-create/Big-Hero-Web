class_name Equipment
extends RefCounted
## ============================================================
## Equipment - 装备栏管理 v0.3
## 8 槽位：武器·防具·鞋子·戒指·项链·披风·头盔·护符
## 存储完整装备实例（非 item_id）
## ============================================================

signal equipment_changed

const EquipmentRulesCls = preload("res://scripts/equipment_rules.gd")

const MAX_SLOT_ENHANCE := 200
const SLOT_ENHANCE_RATE := 0.03
const SLOT_ENHANCE_COST_PER_LEVEL := 500

# 装备槽数据: key=slot_name, value=装备实例字典 (空={})
var _equipped: Dictionary = {
	"weapon":    {},
	"armor":     {},
	"shoes":     {},
	"ring":      {},
	"necklace":  {},
	"cape":      {},
	"helmet":    {},
	"charm":     {},
}
var _slot_enhance: Dictionary = {
	"weapon": 0, "armor": 0, "shoes": 0, "ring": 0,
	"necklace": 0, "cape": 0, "helmet": 0, "charm": 0,
}

const SLOT_TYPE: Dictionary = {
	"weapon":    1,
	"armor":     2,
	"shoes":     3,
	"ring":      4,
	"necklace":  5,
	"cape":      6,
	"helmet":    7,
	"charm":     8,
}


## 穿戴装备实例
func equip_instance(slot_name: String, eqp: Dictionary) -> bool:
	if not _equipped.has(slot_name):
		return false
	if not EquipmentRulesCls.is_valid_equipment(eqp, slot_name):
		return false
	_equipped[slot_name] = eqp.duplicate(true)
	equipment_changed.emit()
	return true


## 卸下装备
func unequip(slot_name: String) -> Dictionary:
	if not _equipped.has(slot_name):
		return {}
	var old: Dictionary = _equipped[slot_name].duplicate(true)
	_equipped[slot_name] = {}
	equipment_changed.emit()
	return old


## 获取槽位装备
func get_slot_item(slot_name: String) -> Dictionary:
	var raw: Variant = _equipped.get(slot_name, {})
	if not (raw is Dictionary):
		return {}
	var eqp: Dictionary = raw as Dictionary
	return eqp if EquipmentRulesCls.is_valid_equipment(eqp, slot_name) else {}


## 已装备实例的显示文本（用于装备面板）
func get_slot_display(slot_name: String) -> String:
	var eqp: Dictionary = get_slot_item(slot_name)
	if eqp.is_empty():
		return "[ 空 ]"
	var s: String = UIUtils.safe_icon(str(eqp.get("icon", "")), "装") + " " + eqp.get("base_name", "???")
	var enhance: int = get_slot_enhance(slot_name)
	if enhance > 0:
		s += " +" + str(enhance)
	return s


func get_slot_enhance(slot_name: String) -> int:
	return int(_slot_enhance.get(slot_name, 0))


func get_slot_enhance_cost(slot_name: String) -> int:
	var level: int = get_slot_enhance(slot_name)
	return -1 if level >= MAX_SLOT_ENHANCE else level * SLOT_ENHANCE_COST_PER_LEVEL


func enhance_slot(slot_name: String) -> bool:
	if not _slot_enhance.has(slot_name) or get_slot_enhance(slot_name) >= MAX_SLOT_ENHANCE:
		return false
	_slot_enhance[slot_name] = get_slot_enhance(slot_name) + 1
	equipment_changed.emit()
	return true


func get_slot_main_multiplier(slot_name: String) -> float:
	return 1.0 + float(get_slot_enhance(slot_name)) * SLOT_ENHANCE_RATE


func to_dict() -> Dictionary:
	return {"equipped": _equipped.duplicate(true), "slot_enhance": _slot_enhance.duplicate(true)}


func from_dict(data: Dictionary) -> void:
	var equipped_data: Dictionary = data.get("equipped", data)
	var saved_enhance: Dictionary = data.get("slot_enhance", {})
	for key in _equipped:
		var v = equipped_data.get(key, {})
		if v is Dictionary:
			var normalized: Dictionary = v.duplicate(true)
			if not normalized.is_empty():
				normalized["slot"] = str(normalized.get("slot", key))
				normalized = EquipmentRulesCls.normalize_equipment(normalized)
			_equipped[key] = normalized if EquipmentRulesCls.is_valid_equipment(normalized, key) else {}
			# 旧存档实例强化迁移到槽位；迁移后装备实例不再携带强化收益。
			_slot_enhance[key] = clampi(maxi(int(saved_enhance.get(key, 0)), int(v.get("enhance", 0))), 0, MAX_SLOT_ENHANCE)
			if not _equipped[key].is_empty():
				_equipped[key]["enhance"] = 0
		else:
			_equipped[key] = {}
			_slot_enhance[key] = clampi(int(saved_enhance.get(key, 0)), 0, MAX_SLOT_ENHANCE)
