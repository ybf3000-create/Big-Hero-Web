class_name ActivityLog
extends RefCounted

## 本地行为日志。日志不上传服务器，也不写入联网角色存档。
const PATH := "user://activity_log.jsonl"
const CATEGORIES := ["important", "battle", "event"]
const MAX_PER_CATEGORY := 200

var entries: Array[Dictionary] = []

func _init() -> void:
	_load()


func add(category: String, text: String) -> void:
	if not CATEGORIES.has(category) or text.strip_edges().is_empty():
		return
	var now := int(Time.get_unix_time_from_system())
	entries.append({
		"timestamp": now,
		"time": Time.get_time_string_from_system(),
		"category": category,
		"text": text.strip_edges(),
	})
	var category_count := 0
	for item in entries:
		if str(item.get("category", "")) == category:
			category_count += 1
	if category_count > MAX_PER_CATEGORY:
		for i in range(entries.size()):
			if str(entries[i].get("category", "")) == category:
				entries.remove_at(i)
				break
	_save()


func get_entries(filter: String = "all") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in range(entries.size() - 1, -1, -1):
		var item := entries[i]
		if filter != "all" and str(item.get("category", "")) != filter:
			continue
		result.append(item.duplicate(true))
	return result


func _load() -> void:
	entries.clear()
	if not FileAccess.file_exists(PATH):
		return
	var file := FileAccess.open(PATH, FileAccess.READ)
	if not file:
		return
	var invalid := false
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty():
			continue
		var json := JSON.new()
		if json.parse(line) != OK or not (json.data is Dictionary):
			invalid = true
			break
		var item: Dictionary = json.data
		if CATEGORIES.has(str(item.get("category", ""))) and not str(item.get("text", "")).is_empty():
			entries.append(item)
	file.close()
	if invalid:
		entries.clear()
		_save()


func _save() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if not file:
		return
	for item in entries:
		file.store_line(JSON.stringify(item))
	file.close()
