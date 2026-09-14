extends Node
## ============================================================
## DebugCommander - 调试命令接收器 (Autoload)
## 原理: AI(WorkBuddy) → godot-mcp → user://debug_cmd.txt → 本脚本
## 无需窗口坐标, 通过文本 JSON 命令模拟 UI 操作
##
## 格式: {"action": "命令名", "slot": 0, "text": "...", "seconds": 3}
##
## 命令速查:
##   选档:    click_slot {slot}          confirm_create
##   创建:    create_char {slot}         input_name {text}     cancel_create
##   删除:    click_delete {slot}        hold_confirm {sec}    click_cancel
##   主界面:  click_dice, click_bag, click_skill, click_log, click_home, toggle_auto
##
## 完整测试流程:
##   debug_cmd {action:"click_slot", slot:0}
##   debug_cmd {action:"input_name", text:"测试"}
##   debug_cmd {action:"confirm_create"}
##   debug_cmd {action:"click_dice"}
##   debug_cmd {action:"click_home"}
##
## 依赖: project.godot 中注册 Autoload, godot-mcp debug_cmd 工具
## ============================================================

var _timer: Timer
var _last_size: int = 0


func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = 0.3
	_timer.autostart = true
	_timer.timeout.connect(_check_command)
	add_child(_timer)
	_clear_cmd_file()


func _check_command() -> void:
	var path := "user://debug_cmd.txt"
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return
	var txt := f.get_as_text()
	f.close()
	if txt.is_empty() or txt.length() == _last_size:
		return
	_last_size = txt.length()

	var json := JSON.new()
	var err := json.parse(txt)
	if err != OK:
		push_warning("[DebugCmd] JSON parse error: ", txt)
		return
	var cmd: Dictionary = json.get_data()
	if cmd.is_empty():
		return

	var action: String = cmd.get("action", "")
	print("[DebugCmd] Executing: ", action)

	match action:
		"click_slot":
			_exec_on("select_slot", "_on_slot_clicked", [cmd.get("slot", 0)])
		"create_char":
			_exec_on("select_slot", "_show_create_dialog", [cmd.get("slot", 0)])
		"input_name":
			_set_line_edit("CreateDialog/NameInput", cmd.get("text", ""))
		"confirm_create":
			_press_button("CreateDialog", "CreateBtn")
		"cancel_create":
			_close_window("CreateDialog")
		"close_create":
			_close_window("CreateDialog")
		"click_delete":
			_exec_on("select_slot", "_show_delete_dialog", [cmd.get("slot", 0), _get_slot_info(cmd.get("slot", 0))])
		"hold_confirm":
			_simulate_hold("DeleteOverlay/DeletePanel/ConfirmBtn", cmd.get("seconds", 3.0))
		"click_cancel":
			_press_button_by_text("DeleteOverlay/DeletePanel", "取 消")
		"click_overlay":
			_exec_on_node("DeleteOverlay", "queue_free", [])
		"click_dice":
			_press_button_by_path("MainGame/BottomBar/DiceRollBtn")
		"click_bag":
			_press_button_by_path("MainGame/BottomBar/BagBtn")
		"click_skill":
			_press_button_by_path("MainGame/BottomBar/SkillBtn")
		"click_log":
			_press_button_by_path("MainGame/BottomBar/LogBtn")
		"click_home":
			_press_button_by_path("MainGame/BottomBar/SettingsBtn")
		"toggle_auto":
			_toggle_checkbox("MainGame/MapArea/AutoPlayCheck")
		_:
			push_warning("[DebugCmd] Unknown action: ", action)

	_clear_cmd_file()


func _clear_cmd_file() -> void:
	var f := FileAccess.open("user://debug_cmd.txt", FileAccess.WRITE)
	if f:
		f.store_string("")
		f.close()


## ============ Helpers ============

func _get_slot_info(slot: int) -> Dictionary:
	var sm := get_node_or_null("/root/SaveManager")
	if sm:
		var info: Dictionary = sm.get_slot_info(slot)
		return info
	return { "empty": true, "slot": slot }  # 默认空槽

func _get_root_control() -> Control:
	for child in get_tree().root.get_children():
		if child is Control:
			return child
	return null


func _exec_on(scene_name: String, method: String, args: Array) -> void:
	var ctrl := _get_root_control()
	if ctrl and ctrl.name.to_lower().replace("_", "") == scene_name.replace("_", ""):
		ctrl.callv(method, args)


func _find_node_by_path(root: Node, path: String) -> Node:
	var parts := path.split("/")
	var current := root
	for p in parts:
		current = current.get_node_or_null(p)
		if not current:
			return null
	return current


func _press_button_by_path(path: String) -> void:
	var root := get_tree().root
	var btn := _find_node_by_path(root, path)
	if btn is Button:
		_press(btn)


func _press_button(parent_name: String, btn_name: String) -> void:
	var ctrl := _get_root_control()
	if not ctrl:
		return
	var parent := ctrl.get_node_or_null(parent_name)
	if parent:
		var btn := parent.get_node_or_null(btn_name)
		if btn is Button:
			_press(btn)


func _press_button_by_text(parent_name: String, text: String) -> void:
	var ctrl := _get_root_control()
	if not ctrl:
		return
	var parent := ctrl.get_node_or_null(parent_name)
	if not parent:
		return
	for child in parent.get_children():
		if child is Button and child.text == text:
			_press(child)
			return


func _set_line_edit(rel_path: String, text: String) -> void:
	var ctrl := _get_root_control()
	if not ctrl:
		return
	var le := ctrl.get_node_or_null(rel_path)
	if le is LineEdit:
		le.text = text
		if le.has_signal("text_changed"):
			le.text_changed.emit(text)


func _close_window(node_name: String) -> void:
	var ctrl := _get_root_control()
	if not ctrl:
		return
	var w := ctrl.get_node_or_null(node_name)
	if w:
		w.queue_free()


func _toggle_checkbox(path: String) -> void:
	var root := get_tree().root
	var cb := _find_node_by_path(root, path)
	if cb is CheckBox:
		cb.button_pressed = not cb.button_pressed


func _exec_on_node(node_name: String, method: String, args: Array) -> void:
	var ctrl := _get_root_control()
	if not ctrl:
		return
	var node := ctrl.get_node_or_null(node_name)
	if node:
		node.callv(method, args)


func _press(btn: Button) -> void:
	btn.emit_signal("pressed")


func _simulate_hold(btn_path: String, seconds: float) -> void:
	var ctrl := _get_root_control()
	if not ctrl:
		return
	var btn := _find_node_by_path(ctrl, btn_path)
	if not (btn is Button):
		return
	btn.emit_signal("button_down")
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = seconds
	t.timeout.connect(func():
		if is_instance_valid(btn):
			btn.emit_signal("button_up")
		t.queue_free()
	)
	add_child(t)
	t.start()
