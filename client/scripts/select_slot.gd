extends Control
## ============================================================
## select_slot - 角色选择/创建界面
## debug_cmd 可触发: _on_slot_clicked, _show_create_dialog, _show_delete_dialog
## ============================================================
## 3个存档槽位 + 创建弹窗 + 删除确认
## ============================================================

var _slot_panels: Array[Panel] = []
var _active_slot: int = -1  # 当前激活槽位
var _delete_buttons: Array[Button] = []


func _sm():  # SaveManager 快捷访问
	return get_node("/root/SaveManager")


func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	_build_ui()
	_refresh_slots()


func _build_ui() -> void:
	# 背景
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.08, 0.08, 0.12)
	add_child(bg)

	# 标题
	var title := Label.new()
	title.text = "大 勇 者"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 60)
	title.size = Vector2(1280, 60)
	add_child(title)

	var subtitle := Label.new()
	subtitle.text = "选择一个存档开始冒险"
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.position = Vector2(0, 125)
	subtitle.size = Vector2(1280, 24)
	add_child(subtitle)

	# 3个槽位面板
	const PANEL_W := 340
	const PANEL_H := 200
	const GAP := 40
	var total_w := 3 * PANEL_W + 2 * GAP
	var start_x := (1280.0 - float(total_w)) / 2.0
	var start_y := 200.0

	for i in range(3):
		var panel := Panel.new()
		panel.name = "SlotPanel" + str(i)
		panel.position = Vector2(start_x + i * (PANEL_W + GAP), start_y)
		panel.size = Vector2(PANEL_W, PANEL_H)
		_panel_style(panel, Color(0.12, 0.13, 0.18))

		# 槽位编号
		var num_lbl := Label.new()
		num_lbl.name = "SlotNum"
		num_lbl.text = "存档 " + str(i + 1)
		num_lbl.add_theme_font_size_override("font_size", 14)
		num_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
		num_lbl.position = Vector2(16, 10)
		panel.add_child(num_lbl)

		# 内容区域
		var content := Label.new()
		content.name = "SlotContent"
		content.text = "[ 空槽位 ]"
		content.add_theme_font_size_override("font_size", 22)
		content.add_theme_color_override("font_color", Color(0.35, 0.35, 0.45))
		content.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		content.position = Vector2(0, 30)
		content.size = Vector2(PANEL_W, PANEL_H - 30)
		panel.add_child(content)

		# 点击区域（覆盖整个面板）
		var btn := Button.new()
		btn.name = "SlotBtn" + str(i)
		btn.flat = true
		btn.position = Vector2(0, 0)
		btn.size = Vector2(PANEL_W, PANEL_H)
		_btn_transparent(btn)
		btn.pressed.connect(_on_slot_clicked.bind(i))
		panel.add_child(btn)

		add_child(panel)
		_slot_panels.append(panel)

	# 底部提示
	var hint := Label.new()
	hint.text = "点击空槽位创建角色 · 点击已创建角色进入游戏"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.3, 0.35, 0.4))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(0, start_y + PANEL_H + 20)
	hint.size = Vector2(1280, 20)
	add_child(hint)


func _refresh_slots() -> void:
	# 清除旧删除按钮
	for b in _delete_buttons:
		b.queue_free()
	_delete_buttons.clear()

	var slots = _sm().get_all_slots()
	for i in range(3):
		var info: Dictionary = slots[i]
		var content: Label = _slot_panels[i].get_node("SlotContent") as Label
		var num_lbl: Label = _slot_panels[i].get_node("SlotNum") as Label

		if info["empty"]:
			content.text = "[ + ]"
			content.add_theme_color_override("font_color", Color(0.3, 0.5, 0.3))
			content.add_theme_font_size_override("font_size", 36)
			num_lbl.text = "存档 " + str(i + 1) + " · 空"
		else:
			var extra := ""
			if _active_slot == i:
				extra = "\n[ 当前激活 ]"
			content.text = info["name"] + "\nLv." + str(info["level"]) + " · " + str(info["gold"]) + "金" + extra
			content.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
			content.add_theme_font_size_override("font_size", 18)
			num_lbl.text = "存档 " + str(i + 1) + " · " + info.get("name", "")

			# 删除按钮（右上角）
			var del := Button.new()
			del.text = "🗑"
			del.position = Vector2(300, 6)
			del.size = Vector2(30, 30)
			del.flat = true
			del.add_theme_font_size_override("font_size", 16)
			del.pressed.connect(_show_delete_dialog.bind(i, info))
			_slot_panels[i].add_child(del)
			_delete_buttons.append(del)

		# 边框高亮激活槽位
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.12, 0.13, 0.18)
		if _active_slot == i or (info["empty"] and _active_slot < 0):
			sb.border_color = Color(1.0, 0.85, 0.2, 0.7)
		else:
			sb.border_color = Color(0.3, 0.3, 0.4, 0.5)
		sb.border_width_left = 2; sb.border_width_right = 2
		sb.border_width_top = 2; sb.border_width_bottom = 2
		_slot_panels[i].add_theme_stylebox_override("panel", sb)


## ============ 槽位点击 ============

func _on_slot_clicked(slot: int) -> void:
	var info: Dictionary = _sm().get_slot_info(slot)
	if info["empty"]:
		_show_create_dialog(slot)
		return

	# 点击已创建槽位 → 直接进入游戏
	var data: Dictionary = _sm().load_game(slot)
	if not data.is_empty():
		_active_slot = slot
		_start_game(slot, data)


## ============ 创建角色弹窗 ============

func _show_create_dialog(slot: int) -> void:
	var dlg := Window.new()
	dlg.name = "CreateDialog"
	dlg.title = "创建角色 · 存档 " + str(slot + 1)
	dlg.size = Vector2(480, 340)
	dlg.position = Vector2(400, 200)
	dlg.unresizable = true
	dlg.popup_window = true
	dlg.close_requested.connect(func(): dlg.queue_free())

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.14, 0.14, 0.20)
	dlg.add_child(bg)

	# 标题
	var ttl := Label.new()
	ttl.text = "输入角色名称"
	ttl.add_theme_font_size_override("font_size", 20)
	ttl.add_theme_color_override("font_color", Color.WHITE)
	ttl.position = Vector2(30, 20)
	dlg.add_child(ttl)

	# 输入框
	var input := LineEdit.new()
	input.name = "NameInput"
	input.placeholder_text = "最多7个汉字或14个字母/数字"
	input.position = Vector2(30, 60)
	input.size = Vector2(420, 40)
	input.add_theme_font_size_override("font_size", 18)
	dlg.add_child(input)

	# 名称权重提示：汉字计2，字母/数字计1。
	var byte_info := Label.new()
	byte_info.name = "ByteInfo"
	byte_info.text = "名称长度 0 / 14"
	byte_info.add_theme_font_size_override("font_size", 13)
	byte_info.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	byte_info.position = Vector2(30, 108)
	dlg.add_child(byte_info)

	# 校验提示
	var validation := Label.new()
	validation.name = "ValidationLabel"
	validation.text = ""
	validation.add_theme_font_size_override("font_size", 13)
	validation.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	validation.position = Vector2(30, 130)
	dlg.add_child(validation)

	# 实时校验
	input.text_changed.connect(func(txt: String):
		var r: Dictionary = _sm().validate_name(txt)
		byte_info.text = "名称长度 " + str(r["weight"]) + " / 14"
		if r["valid"]:
			validation.text = "✓ 名称合法"
			validation.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
		else:
			validation.text = "✗ " + r["error"]
			validation.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	)

	# 角色预览
	var preview := Label.new()
	preview.text = "勇者"
	preview.add_theme_font_size_override("font_size", 64)
	preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview.position = Vector2(240, 170)
	preview.size = Vector2(200, 80)
	dlg.add_child(preview)

	# 按钮
	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	cancel_btn.position = Vector2(30, 280)
	cancel_btn.size = Vector2(130, 40)
	_btn_style(cancel_btn, Color(0.2, 0.2, 0.3))
	cancel_btn.pressed.connect(func(): dlg.queue_free())
	dlg.add_child(cancel_btn)

	var create_btn := Button.new()
	create_btn.name = "CreateBtn"
	create_btn.text = "开始冒险"
	create_btn.position = Vector2(320, 280)
	create_btn.size = Vector2(130, 40)
	_btn_style(create_btn, Color(0.15, 0.35, 0.20))
	create_btn.disabled = true
	dlg.add_child(create_btn)

	# 名称合法时启用按钮
	input.text_changed.connect(func(txt: String):
		var r: Dictionary = _sm().validate_name(txt)
		create_btn.disabled = not r["valid"]
	)

	create_btn.pressed.connect(func():
		var r: Dictionary = _sm().validate_name(input.text)
		if r["valid"]:
			var data: Dictionary = _sm().create_character(slot, r["trimmed"])
			_active_slot = slot
			dlg.queue_free()
			_refresh_slots()
			# 进入游戏
			_start_game(slot, data)
	)

	add_child(dlg)
	dlg.popup_centered()
	input.grab_focus()


## ============ 删除存档 ============

func _show_delete_dialog(slot: int, info: Dictionary) -> void:
	if info["empty"]:
		return

	# 全屏半透明遮罩
	var overlay := ColorRect.new()
	overlay.name = "DeleteOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.6)
	add_child(overlay)

	# 对话框面板
	var D_WIDTH := 440.0
	var D_HEIGHT := 300.0
	var dlg := Panel.new()
	dlg.name = "DeletePanel"
	dlg.position = Vector2((1280.0 - D_WIDTH) / 2.0, (720.0 - D_HEIGHT) / 2.0)
	dlg.size = Vector2(D_WIDTH, D_HEIGHT)
	var dlg_bg := StyleBoxFlat.new()
	dlg_bg.bg_color = Color(0.15, 0.10, 0.10)
	dlg_bg.set_corner_radius_all(12)
	dlg_bg.border_color = Color(0.6, 0.2, 0.2, 0.5)
	dlg_bg.border_width_left = 2; dlg_bg.border_width_right = 2
	dlg_bg.border_width_top = 2; dlg_bg.border_width_bottom = 2
	dlg.add_theme_stylebox_override("panel", dlg_bg)
	overlay.add_child(dlg)

	# 标题
	var title := Label.new()
	title.text = "⚠ 删除存档「" + info["name"] + "」"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(20, 20)
	title.size = Vector2(D_WIDTH - 40, 30)
	dlg.add_child(title)

	# 存档详情
	var detail := Label.new()
	detail.text = "Lv." + str(info["level"]) + "  ·  " + str(info["gold"]) + " 金币"
	detail.add_theme_font_size_override("font_size", 16)
	detail.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.position = Vector2(20, 55)
	detail.size = Vector2(D_WIDTH - 40, 22)
	dlg.add_child(detail)

	# 提示文本
	var hint := Label.new()
	hint.text = "长按确定 3 秒后删除存档"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.85, 0.3, 0.3))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(20, 90)
	hint.size = Vector2(D_WIDTH - 40, 20)
	dlg.add_child(hint)

	# 进度条（初始不可见，按压时出现）
	var progress := ProgressBar.new()
	progress.name = "DeleteProgress"
	progress.value = 0.0
	progress.max_value = 3.0
	progress.position = Vector2(40, 130)
	progress.size = Vector2(D_WIDTH - 80, 26)
	_bar_style(progress, Color(0.85, 0.18, 0.18))
	dlg.add_child(progress)

	# 按钮
	const BTN_W := 170.0
	const BTN_H := 44.0
	var btn_y := 180.0
	var gap := (D_WIDTH - BTN_W * 2) / 3.0

	# 取消按钮
	var cancel_btn := Button.new()
	cancel_btn.text = "取 消"
	cancel_btn.position = Vector2(gap, btn_y)
	cancel_btn.size = Vector2(BTN_W, BTN_H)
	_btn_style(cancel_btn, Color(0.22, 0.24, 0.30))
	cancel_btn.pressed.connect(func():
		overlay.queue_free()
	)
	dlg.add_child(cancel_btn)

	# 确定按钮（长按3秒）
	var confirm_btn := Button.new()
	confirm_btn.name = "ConfirmBtn"
	confirm_btn.text = "确 定"
	confirm_btn.position = Vector2(gap * 2 + BTN_W, btn_y)
	confirm_btn.size = Vector2(BTN_W, BTN_H)
	_btn_style(confirm_btn, Color(0.55, 0.15, 0.12))
	dlg.add_child(confirm_btn)

	# 长按状态（包装在 Dict 中避免 lambda 捕获问题）
	var _s: Dictionary = { "pressing": false, "elapsed": 0.0, "deleted": false }

	var tick := Timer.new()
	tick.wait_time = 0.05
	tick.timeout.connect(func():
		if not _s["pressing"] or _s["deleted"]:
			if not _s["pressing"]:
				_s["elapsed"] = 0.0
				progress.value = 0.0
			return
		_s["elapsed"] += 0.05
		progress.value = _s["elapsed"]
		if _s["elapsed"] >= 3.0:
			_s["deleted"] = true
			_s["pressing"] = false
			tick.stop()
			_sm().delete_slot(slot)
			if _active_slot == slot:
				_active_slot = -1
			overlay.queue_free()
			_refresh_slots()
	)
	dlg.add_child(tick)
	tick.start()

	confirm_btn.button_down.connect(func():
		if _s["deleted"]: return
		_s["pressing"] = true
		_s["elapsed"] = 0.0
		progress.value = 0.0
	)
	confirm_btn.button_up.connect(func():
		_s["pressing"] = false
		_s["elapsed"] = 0.0
		progress.value = 0.0
	)

	# 对话框自身拦截点击（防冒泡）
	dlg.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			overlay.accept_event()  # no-op, just consume to prevent propagation
	)

	# 点击遮罩空白处关闭
	overlay.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			var mouse_pos := overlay.get_local_mouse_position()
			var dlg_rect := Rect2(dlg.position, dlg.size)
			if not dlg_rect.has_point(mouse_pos):
				overlay.queue_free()
	)


## ============ 进入游戏 ============

func _start_game(slot: int, data: Dictionary) -> void:
	# 将存档数据传递给主界面
	if get_tree():
		var main_scene := load("res://scenes/main_game.tscn") as PackedScene
		if main_scene:
			var main := main_scene.instantiate()
			main.set_meta("save_slot", slot)
			main.set_meta("save_data", data)
			get_tree().root.add_child(main)
			queue_free()


## ============ 样式 ============

func _panel_style(node: Panel, clr: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = clr
	sb.border_width_left = 1; sb.border_width_right = 1
	sb.border_width_top = 1; sb.border_width_bottom = 1
	sb.border_color = Color(0.3, 0.3, 0.4, 0.5)
	sb.set_corner_radius_all(10)
	node.add_theme_stylebox_override("panel", sb)


func _btn_style(btn: Button, clr: Color) -> void:
	var n := StyleBoxFlat.new()
	n.bg_color = clr
	n.border_color = Color(0.5, 0.5, 0.6, 0.7)
	n.border_width_left = 2; n.border_width_right = 2
	n.border_width_top = 2; n.border_width_bottom = 2
	n.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", n)
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = clr.lightened(0.15)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", Color.WHITE)


func _btn_transparent(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(1, 1, 1, 0)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(1, 1, 1, 0.08)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(1, 1, 1, 0.15)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)


func _bar_style(node: ProgressBar, clr: Color) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = clr.darkened(0.5)
	bg.border_width_left = 1; bg.border_width_right = 1
	bg.border_width_top = 1; bg.border_width_bottom = 1
	bg.border_color = Color(0.4, 0.4, 0.5)
	node.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = clr
	node.add_theme_stylebox_override("fill", fill)
