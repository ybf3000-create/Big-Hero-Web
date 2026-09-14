class_name EquipIcons
extends RefCounted

## 生成装备时扫描对应目录，后续添加图片无需修改配置。
const ICON_ROOT := "res://assets/equipment_icons"
const IMAGE_EXTENSIONS := ["png", "jpg", "jpeg", "webp", "svg"]
const SLOT_FOLDER := {
	"weapon": "weapon", "armor": "armor", "cape": "armor", "shoes": "shoes",
	"ring": "ring", "necklace": "charm", "charm": "charm", "helmet": "helmet",
}
const SLOT_DISPLAY := {
	"weapon": "武器", "armor": "铠甲", "cape": "披风", "shoes": "鞋子",
	"ring": "戒指", "necklace": "项链", "charm": "护符", "helmet": "头盔",
}

static func random_icon(slot_name: String) -> Dictionary:
	var folder: String = str(SLOT_FOLDER.get(slot_name, slot_name))
	var paths := _scan_folder("%s/%s" % [ICON_ROOT, folder])
	if paths.is_empty():
		return {"name": str(SLOT_DISPLAY.get(slot_name, "装备")), "icon": "?", "icon_path": ""}
	return {
		"name": str(SLOT_DISPLAY.get(slot_name, "装备")),
		"icon": "",
		"icon_path": paths[randi() % paths.size()],
	}

static func _scan_folder(path: String) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(path)
	if dir == null:
		return result
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.get_extension().to_lower() in IMAGE_EXTENSIONS:
			result.append(path.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()
	return result
