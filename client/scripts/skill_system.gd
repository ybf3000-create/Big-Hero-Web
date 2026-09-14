class_name SkillSystem
extends RefCounted

const SkillDataRef = preload("res://scripts/skill_data.gd")

signal skills_changed

var slots: Array = []
var cooldowns: Dictionary = {}
var max_slots: int = 2
var unlocked_skills: Array[int] = [1, 22]


func _init():
	slots.clear()
	for i in range(6):
		slots.append(null)
	slots[0] = { "skill_id": 1, "priority": 2 }
	slots[1] = { "skill_id": 22, "priority": 2 }


func update_max_slots(level: int) -> void:
	var new_max: int = 2
	if level >= 5:   new_max = 3
	if level >= 15:  new_max = 4
	if level >= 35:  new_max = 5
	if level >= 45:  new_max = 6
	if new_max != max_slots:
		max_slots = new_max
		skills_changed.emit()


func get_slot_count() -> int:
	return slots.size()


func get_unlocked_slots() -> int:
	return max_slots


func get_slot_skill_id(slot_idx: int):
	if slot_idx < 0 or slot_idx >= slots.size():
		return null
	var entry = slots[slot_idx]
	return entry["skill_id"] if entry else null


func get_slot_priority(slot_idx: int) -> int:
	if slot_idx < 0 or slot_idx >= slots.size():
		return 1
	var entry = slots[slot_idx]
	return entry["priority"] if entry else 1


func equip_skill(skill_id: int) -> bool:
	if not is_skill_unlocked(skill_id):
		return false
	for i in range(max_slots):
		var entry = slots[i]
		if entry and entry["skill_id"] == skill_id:
			return false
	for i in range(max_slots):
		if slots[i] == null:
			slots[i] = { "skill_id": skill_id, "priority": 2 }
			cooldowns[skill_id] = 0.0
			skills_changed.emit()
			return true
	return false


func is_skill_unlocked(skill_id: int) -> bool:
	return skill_id in unlocked_skills


func unlock_skill(skill_id: int) -> bool:
	if is_skill_unlocked(skill_id) or SkillDataRef.get_skill(skill_id).is_empty():
		return false
	unlocked_skills.append(skill_id)
	unlocked_skills.sort()
	skills_changed.emit()
	return true


func unequip_skill(slot_idx: int) -> bool:
	if slot_idx < 0 or slot_idx >= max_slots:
		return false
	if slots[slot_idx] == null:
		return false
	var sid: int = slots[slot_idx]["skill_id"]
	slots[slot_idx] = null
	cooldowns.erase(sid)
	skills_changed.emit()
	return true


func toggle_priority(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= max_slots:
		return
	var entry = slots[slot_idx]
	if entry == null:
		return
	entry["priority"] = (entry["priority"] % 3) + 1
	skills_changed.emit()


func to_dict() -> Dictionary:
	var slot_data: Array = []
	for i in range(slots.size()):
		slot_data.append(slots[i].duplicate() if slots[i] else null)
	return {
		"slots": slot_data,
		"max_slots": max_slots,
		"cooldowns": cooldowns.duplicate(),
		"unlocked_skills": unlocked_skills.duplicate(),
	}


func from_dict(data: Dictionary) -> void:
	slots.clear()
	var saved_slots: Array = data.get("slots", [])
	if saved_slots.is_empty():
		saved_slots = [
			{ "skill_id": 1, "priority": 2 },
			{ "skill_id": 22, "priority": 2 },
		]
	for d in saved_slots:
		slots.append(d.duplicate() if d else null)
	while slots.size() < 6:
		slots.append(null)
	max_slots = data.get("max_slots", 2)
	cooldowns.clear()
	var cd_data: Dictionary = data.get("cooldowns", {})
	for k in cd_data:
		cooldowns[int(k)] = cd_data[k]
	unlocked_skills.clear()
	var saved_unlocks: Array = data.get("unlocked_skills", [])
	if saved_unlocks.is_empty():
		# 旧存档迁移：保留已装备技能，并补发两个初始技能。
		saved_unlocks = [1, 22]
		for entry in slots:
			if entry and int(entry.get("skill_id", 0)) > 0:
				saved_unlocks.append(int(entry["skill_id"]))
	for sid in saved_unlocks:
		var skill_id := int(sid)
		if skill_id > 0 and skill_id not in unlocked_skills:
			unlocked_skills.append(skill_id)
	unlocked_skills.sort()


func select_next_skill() -> int:
	var candidates: Array = []
	for i in range(max_slots):
		var entry = slots[i]
		if entry == null:
			continue
		var sid: int = entry["skill_id"]
		if cooldowns.get(sid, 0.0) <= 0.0:
			candidates.append([entry["priority"], i, sid])
	if candidates.is_empty():
		return -1
	candidates.sort_custom(func(a, b):
		if a[0] != b[0]: return a[0] > b[0]
		return a[1] < b[1]
	)
	return candidates[0][2]
