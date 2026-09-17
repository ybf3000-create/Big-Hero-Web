extends Control

const UI_FONT: Font = preload("res://assets/fonts/NotoSansHans-Regular.otf")

var _mode := "login"
var _panel: PanelContainer
var _form: VBoxContainer
var _login_tab: Button
var _register_tab: Button
var _username: LineEdit
var _password: LineEdit
var _password_confirm: LineEdit
var _invite_code: LineEdit
var _status: Label
var _submit: Button
var _character_area: VBoxContainer
var _character_name: LineEdit
var _character_summary: Label
var _enter_game: Button


func _ready() -> void:
	var app_theme := Theme.new()
	app_theme.default_font = ThemeDB.fallback_font
	theme = app_theme
	_build_ui()
	_show_mode("login")
	NetworkClient.kicked.connect(_on_kicked)
	NetworkClient.realtime_disconnected.connect(_on_realtime_disconnected)


func _build_ui() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("101218")
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(460, 480)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("191d27")
	panel_style.border_color = Color("383f50")
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(6)
	_panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 38)
	margin.add_theme_constant_override("margin_right", 38)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	_panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	var title := Label.new()
	title.text = "大 勇 者"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color("f1c95b"))
	root.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "熟人服务器"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color("8d96a8"))
	root.add_child(subtitle)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	root.add_child(tabs)
	_login_tab = _make_tab_button("登录")
	_register_tab = _make_tab_button("注册")
	_login_tab.pressed.connect(_show_mode.bind("login"))
	_register_tab.pressed.connect(_show_mode.bind("register"))
	tabs.add_child(_login_tab)
	tabs.add_child(_register_tab)

	_form = VBoxContainer.new()
	_form.add_theme_constant_override("separation", 10)
	root.add_child(_form)
	_username = _make_input("账号")
	_password = _make_input("密码", true)
	_password_confirm = _make_input("再次输入密码", true)
	_invite_code = _make_input("邀请码")
	_form.add_child(_username)
	_form.add_child(_password)
	_form.add_child(_password_confirm)
	_form.add_child(_invite_code)

	_status = Label.new()
	_status.custom_minimum_size = Vector2(0, 42)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 14)
	root.add_child(_status)

	_submit = Button.new()
	_submit.custom_minimum_size = Vector2(0, 44)
	_submit.pressed.connect(_on_submit)
	_style_primary_button(_submit)
	root.add_child(_submit)

	_character_area = VBoxContainer.new()
	_character_area.visible = false
	_character_area.add_theme_constant_override("separation", 12)
	root.add_child(_character_area)

	_character_summary = Label.new()
	_character_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_character_summary.add_theme_font_size_override("font_size", 20)
	_character_summary.add_theme_color_override("font_color", Color("e8ecf3"))
	_character_area.add_child(_character_summary)

	_character_name = _make_input("角色名：最多7个汉字或14个字母/数字")
	_character_area.add_child(_character_name)

	_enter_game = Button.new()
	_enter_game.custom_minimum_size = Vector2(0, 44)
	_enter_game.pressed.connect(_on_character_action)
	_style_primary_button(_enter_game)
	_character_area.add_child(_enter_game)


func _show_mode(mode: String) -> void:
	_mode = mode
	_status.text = ""
	_character_area.visible = false
	_form.visible = true
	_submit.visible = true
	_password_confirm.visible = mode == "register"
	_invite_code.visible = mode == "register"
	_panel.custom_minimum_size.y = 600 if mode == "register" else 480
	_submit.text = "创建账号" if mode == "register" else "登录"
	_login_tab.button_pressed = mode == "login"
	_register_tab.button_pressed = mode == "register"
	_username.grab_focus()


func _on_submit() -> void:
	_set_busy(true)
	_show_status("正在连接服务器…", false)
	if _mode == "register":
		var registered: Dictionary = await NetworkClient.register_account(
			_username.text,
			_password.text,
			_password_confirm.text,
			_invite_code.text
		)
		if registered.get("ok", false):
			_password_confirm.clear()
			_invite_code.clear()
			_show_mode("login")
			_show_status("账号创建成功，请登录", false)
		else:
			_show_response_error(registered)
	else:
		var response: Dictionary = await NetworkClient.login(_username.text, _password.text)
		if response.get("ok", false):
			_password.clear()
			_show_character_entry()
		else:
			_show_response_error(response)
	_set_busy(false)


func _show_character_entry() -> void:
	_panel.custom_minimum_size.y = 480
	_form.visible = false
	_submit.visible = false
	_character_area.visible = true
	_status.text = ""
	if NetworkClient.character is Dictionary:
		var current := NetworkClient.character as Dictionary
		_character_summary.text = "%s  ·  Lv.%d" % [
			str(current.get("name", "勇者")),
			int(current.get("level", 1)),
		]
		_character_name.visible = false
		_enter_game.text = "进入游戏"
	else:
		_character_summary.text = "创建你的勇者"
		_character_name.visible = true
		_character_name.clear()
		_enter_game.text = "创建角色"
		_character_name.grab_focus()


func _on_character_action() -> void:
	if NetworkClient.character is not Dictionary:
		_set_busy(true)
		var response: Dictionary = await NetworkClient.create_character(_character_name.text)
		_set_busy(false)
		if not response.get("ok", false):
			_show_response_error(response)
			return
		_show_character_entry()
		return
	_start_game(NetworkClient.character as Dictionary)


func _start_game(server_character: Dictionary) -> void:
	var data := {
		"character_name": str(server_character.get("name", "勇者")),
		"level": int(server_character.get("level", 1)),
		"exp": int(server_character.get("experience", 0)),
		"gold": int(str(server_character.get("gold", "0"))),
		"last_online": int(Time.get_unix_time_from_system()),
	}
	var main_scene := load("res://scenes/main_game.tscn") as PackedScene
	if not main_scene:
		_show_status("游戏场景加载失败", true)
		return
	var main := main_scene.instantiate()
	main.set_meta("save_slot", -1)
	main.set_meta("save_data", data)
	main.set_meta("network_character_id", str(server_character.get("id", "")))
	get_tree().root.add_child(main)
	queue_free()


func _on_kicked(message: String) -> void:
	_show_mode("login")
	_show_status(message, true)


func _on_realtime_disconnected(message: String) -> void:
	_show_mode("login")
	_show_status(message, true)


func _show_response_error(response: Dictionary) -> void:
	var error: Dictionary = response.get("error", {})
	_show_status(str(error.get("message", "操作失败，请稍后重试")), true)


func _show_status(message: String, is_error: bool) -> void:
	_status.text = message
	_status.add_theme_color_override(
		"font_color",
		Color("ff7770") if is_error else Color("83d6a1")
	)


func _set_busy(busy: bool) -> void:
	_submit.disabled = busy
	_enter_game.disabled = busy
	_login_tab.disabled = busy
	_register_tab.disabled = busy


func _make_input(placeholder: String, secret := false) -> LineEdit:
	var input := LineEdit.new()
	input.placeholder_text = placeholder
	input.secret = secret
	input.custom_minimum_size = Vector2(0, 42)
	input.add_theme_font_size_override("font_size", 16)
	return input


func _make_tab_button(label_text: String) -> Button:
	var button := Button.new()
	button.text = label_text
	button.toggle_mode = true
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 38)
	return button


func _style_primary_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("b68724")
	normal.set_corner_radius_all(5)
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("d3a43d")
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_color_override("font_color", Color("101218"))
	button.add_theme_font_size_override("font_size", 16)
