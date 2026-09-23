extends Node
## ============================================================
## SaveManager - 存档管理器 (Autoload 单例)
## 本地回归模式负责slot_0~2.json读写；联网角色由服务端持久化。
## 访问方式: get_node("/root/SaveManager")
## ============================================================

const SAVE_VERSION := 1
const MAX_SLOTS := 3
const SAVE_DIR := "user://saves/"
const SETTINGS_PATH := "user://client_settings.cfg"
const BATTLE_SPEEDS: Array[float] = [0.75, 1.0, 2.0]

signal slot_changed(slot: int)


func _ready() -> void:
	# 确保存档目录存在
	DirAccess.make_dir_absolute(SAVE_DIR)


## ============ 槽位信息 ============

func get_slot_info(slot: int) -> Dictionary:
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		return { "empty": true, "slot": slot }

	var data := _read_json(path)
	if data.is_empty():
		return { "empty": true, "slot": slot }

	return {
		"empty": false,
		"slot": slot,
		"name": data.get("character_name", "???"),
		"level": data.get("level", 1),
		"last_saved": data.get("last_saved", 0),
		"gold": data.get("gold", 0),
	}


func get_all_slots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in range(MAX_SLOTS):
		result.append(get_slot_info(i))
	return result


## ============ 创建角色 ============

func create_character(slot: int, char_name: String) -> Dictionary:
	var now := int(Time.get_unix_time_from_system())
	var data: Dictionary = {
		"version": SAVE_VERSION,
		"character_name": char_name,
		"created_at": now,
		"last_saved": now,
		"last_online": now,
		"level": 1,
		"exp": 0,
		"exp_max": 100,
		"gold": 0,
		"revive_coins": 3,
		"player_hp": 500,
		"boss_tier": 0,
		"boss_index": 1,
		"grid_index": 0,
		"map_total_grids": 28,
		"map_grids": _default_map_grids(),
		"dice_history": [],
		"poker_records": [],
		"free_points": 0,
		"stat_atk": 0,
		"stat_def": 0,
		"stat_spd": 0,
		"stat_luk": 0,
	}
	_write_json(_slot_path(slot), data)
	slot_changed.emit(slot)
	return data


## ============ 保存/加载 ============

func save_game(slot: int, data: Dictionary) -> void:
	# 合并已有数据，保留 created_at / last_online 等仅创建时写入的字段
	var existing := _read_json(_slot_path(slot))
	if not existing.is_empty():
		for key in existing:
			if not data.has(key):
				data[key] = existing[key]
	data["last_saved"] = int(Time.get_unix_time_from_system())
	data["version"] = SAVE_VERSION
	_write_json(_slot_path(slot), data)
	slot_changed.emit(slot)


func load_game(slot: int) -> Dictionary:
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	return _read_json(path)


## ============ 删除 ============

func delete_slot(slot: int) -> void:
	var path := _slot_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	slot_changed.emit(slot)


## ============ 客户端设置 ============

func get_battle_speed() -> float:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return BATTLE_SPEEDS[0]
	return _normalize_battle_speed(float(config.get_value("battle", "speed", BATTLE_SPEEDS[0])))


func set_battle_speed(value: float) -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("battle", "speed", _normalize_battle_speed(value))
	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("[SaveManager] 无法保存战斗速度设置: " + str(error))


func _normalize_battle_speed(value: float) -> float:
	for allowed in BATTLE_SPEEDS:
		if is_equal_approx(value, allowed):
			return allowed
	return BATTLE_SPEEDS[0]


## ============ 名称校验 ============

func validate_name(input_name: String) -> Dictionary:
	var trimmed := input_name.strip_edges()
	if trimmed.is_empty():
		return { "valid": false, "error": "名称不能为空", "weight": 0, "byte_count": 0 }
	if trimmed != input_name:
		return { "valid": false, "error": "名称不能包含空格", "weight": name_weight(trimmed), "byte_count": name_weight(trimmed) }

	var weight := 0
	for character in trimmed:
		var code := character.unicode_at(0)
		if _is_ascii_letter_or_digit(code):
			weight += 1
		elif _is_cjk_character(code):
			weight += 2
		else:
			return { "valid": false, "error": "只能使用汉字、英文字母和数字", "weight": weight, "byte_count": weight }
		if weight > 14:
			return { "valid": false, "error": "名称长度超过14", "weight": weight, "byte_count": weight }

	return { "valid": true, "error": "", "weight": weight, "byte_count": weight, "trimmed": trimmed }


func name_weight(input_name: String) -> int:
	var weight := 0
	for character in input_name:
		var code := character.unicode_at(0)
		if _is_ascii_letter_or_digit(code):
			weight += 1
		elif _is_cjk_character(code):
			weight += 2
	return weight


func _is_ascii_letter_or_digit(code: int) -> bool:
	return (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122)


func _is_cjk_character(code: int) -> bool:
	return (code >= 0x3400 and code <= 0x4DBF) or (code >= 0x4E00 and code <= 0x9FFF) or (code >= 0xF900 and code <= 0xFAFF)


## ============ 内部 ============

func _slot_path(slot: int) -> String:
	return SAVE_DIR + "slot_" + str(slot) + ".json"


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var text := file.get_as_text()
	file.close()
	if text.is_empty():
		return {}
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_warning("[SaveManager] JSON 解析失败: " + path + " error=" + str(json.get_error_message()))
		return {}
	return json.get_data()


func _write_json(path: String, data: Dictionary) -> void:
	var json_text := JSON.stringify(data, "\t")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("[SaveManager] 无法写入存档: " + path)
		return
	file.store_string(json_text)
	file.close()


func _default_map_grids() -> Array:
	# 初始仅投放基础格；合成/神祇/闪电/挑战/彩票按 Boss 进度解锁。
	return [0, 1, 5, 1, 7, 2, 1, 4, 1, 6, 5, 1, 7, 2, 1, 12, 1, 5, 1, 4, 2, 1, 7, 6, 1, 12, 1, 11]
