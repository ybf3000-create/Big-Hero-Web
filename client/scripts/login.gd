extends Control

const UI_FONT: Font = preload("res://assets/fonts/NotoSansHans-Regular.otf")
const CREDENTIALS_PATH := "user://login_credentials.cfg"

var _mode := "login"
var _panel: PanelContainer
var _form: VBoxContainer
var _login_tab: Button
var _register_tab: Button
var _username: LineEdit
var _password: LineEdit
var _password_confirm: LineEdit
var _invite_code: LineEdit
var _remember_credentials: CheckBox
var _status: Label
var _submit: Button
var _character_area: VBoxContainer
var _character_name: LineEdit
var _character_summary: Label
var _enter_game: Button
var _logout_account: Button
var _delete_character: Button
var NetworkClient: Variant


func _ready() -> void:
	NetworkClient = get_node_or_null("/root/NetworkClient")
	var app_theme := Theme.new()
	app_theme.default_font = ThemeDB.fallback_font
	theme = app_theme
	_build_ui()
	_remove_old_plaintext_credentials()
	_show_mode("login")
	NetworkClient.kicked.connect(_on_kicked)
	NetworkClient.realtime_disconnected.connect(_on_realtime_disconnected)
	if not NetworkClient.session_token.is_empty():
		_show_character_entry()
	elif OS.has_feature("web"):
		_restore_saved_login()


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
	_remember_credentials = CheckBox.new()
	_remember_credentials.text = "记住登录状态（仅限当前浏览器）"
	_remember_credentials.add_theme_font_size_override("font_size", 13)
	_remember_credentials.add_theme_color_override("font_color", Color("b9c1cf"))
	_form.add_child(_remember_credentials)

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
	_logout_account = Button.new()
	_logout_account.text = "退出账号"
	_logout_account.custom_minimum_size = Vector2(0, 38)
	_logout_account.pressed.connect(_on_logout_account)
	_character_area.add_child(_logout_account)
	_delete_character = Button.new()
	_delete_character.text = "删除当前角色"
	_delete_character.custom_minimum_size = Vector2(0, 36)
	_delete_character.add_theme_color_override("font_color", Color("ffaaa5"))
	_delete_character.pressed.connect(_on_delete_character)
	_character_area.add_child(_delete_character)


func _show_mode(mode: String) -> void:
	_mode = mode
	_status.text = ""
	_character_area.visible = false
	_form.visible = true
	_submit.visible = true
	_username.visible = mode != "change_password"
	_password_confirm.visible = mode == "register" or mode == "change_password"
	_invite_code.visible = mode == "register"
	_remember_credentials.visible = mode == "login"
	_tabs_visible(mode != "change_password")
	_panel.custom_minimum_size.y = 600 if mode == "register" else 480
	_submit.text = "创建账号" if mode == "register" else "修改密码" if mode == "change_password" else "登录"
	_login_tab.button_pressed = mode == "login"
	_register_tab.button_pressed = mode == "register"
	_password.placeholder_text = "新密码" if mode == "change_password" else "密码"
	if mode == "change_password":
		_password.clear()
		_password_confirm.clear()
		_password.grab_focus()
	else:
		_username.grab_focus()


func _tabs_visible(visible: bool) -> void:
	_login_tab.visible = visible
	_register_tab.visible = visible


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
	elif _mode == "change_password":
		var changed: Dictionary = await NetworkClient.change_password(_password.text, _password_confirm.text)
		if changed.get("ok", false):
			_password.clear()
			_password_confirm.clear()
			_show_character_entry()
			_show_status("密码修改成功；下次请用新密码登录", false)
		else:
			_show_response_error(changed)
	else:
		var response: Dictionary = await NetworkClient.login(_username.text, _password.text, _remember_credentials.button_pressed)
		if response.get("ok", false):
			_password.clear()
			_show_character_entry()
		else:
			_show_response_error(response)
	_set_busy(false)


func _remove_old_plaintext_credentials() -> void:
	if FileAccess.file_exists(CREDENTIALS_PATH):
		var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(CREDENTIALS_PATH))
		if error != OK:
			push_warning("无法删除旧版明文登录信息，请清除该站点的浏览器数据")


func _restore_saved_login() -> void:
	_set_busy(true)
	_show_status("正在恢复登录状态…", false)
	var restored: Dictionary = await NetworkClient.restore_login()
	_set_busy(false)
	if restored.get("ok", false):
		_remember_credentials.button_pressed = true
		_show_character_entry()
	else:
		var error: Dictionary = restored.get("error", {}) as Dictionary
		if str(error.get("code", "")) == "NO_REMEMBERED_LOGIN" or str(error.get("code", "")) == "SESSION_INVALID":
			_show_status("", false)
		else:
			_show_response_error(restored)


func _show_character_entry() -> void:
	if bool(NetworkClient.account.get("must_change_password", false)):
		_show_mode("change_password")
		_show_status("管理员已重置密码，请先设置新密码", false)
		return
	_tabs_visible(true)
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
		_delete_character.visible = true
	else:
		_character_summary.text = "创建你的勇者"
		_character_name.visible = true
		_character_name.clear()
		_enter_game.text = "创建角色"
		_delete_character.visible = false
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
	await _start_game(NetworkClient.character as Dictionary)


func _on_logout_account() -> void:
	_set_busy(true)
	await NetworkClient.logout()
	_set_busy(false)
	_username.clear()
	_password.clear()
	_remember_credentials.button_pressed = false
	_show_mode("login")
	_show_status("已退出登录", false)


func _on_delete_character() -> void:
	if NetworkClient.character is not Dictionary:
		return
	var current := NetworkClient.character as Dictionary
	var character_name := str(current.get("name", ""))
	var dialog := Panel.new()
	dialog.name = "DeleteCharacterDialog"
	dialog.size = Vector2(460, 270)
	dialog.position = (get_viewport_rect().size - dialog.size) * 0.5
	dialog.z_index = 100
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("191d27")
	panel_style.border_color = Color("6b4145")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(6)
	dialog.add_theme_stylebox_override("panel", panel_style)
	var title := Label.new()
	title.text = "删除当前角色"
	title.position = Vector2(24, 18)
	title.size = Vector2(412, 32)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("ffaaa5"))
	dialog.add_child(title)
	var body := Label.new()
	body.text = "此操作不可撤销。等级、装备、背包、拍卖记录都会被删除，账号会保留。\n请输入完整角色名后确认："
	body.position = Vector2(24, 58)
	body.size = Vector2(412, 48)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 14)
	body.add_theme_color_override("font_color", Color("d7ddea"))
	dialog.add_child(body)
	var input := LineEdit.new()
	input.position = Vector2(24, 122)
	input.size = Vector2(412, 40)
	input.placeholder_text = "请输入：" + character_name
	input.add_theme_font_size_override("font_size", 16)
	dialog.add_child(input)
	var cancel := Button.new()
	cancel.text = "取消"
	cancel.position = Vector2(24, 194)
	cancel.size = Vector2(190, 42)
	cancel.pressed.connect(dialog.queue_free)
	dialog.add_child(cancel)
	var confirm := Button.new()
	confirm.text = "确认删除"
	confirm.position = Vector2(246, 194)
	confirm.size = Vector2(190, 42)
	_style_primary_button(confirm)
	confirm.pressed.connect(_confirm_delete_character.bind(dialog, input, character_name))
	dialog.add_child(confirm)
	add_child(dialog)
	input.grab_focus()


func _confirm_delete_character(dialog: Control, input: LineEdit, character_name: String) -> void:
	if input.text.strip_edges() != character_name:
		_show_status("角色名不匹配，未执行删除", true)
		dialog.queue_free()
		return
	_set_busy(true)
	var response: Dictionary = await NetworkClient.delete_character(input.text)
	_set_busy(false)
	if response.get("ok", false):
		_show_character_entry()
		_show_status("角色已删除，可以创建新角色", false)
	else:
		_show_response_error(response)
	dialog.queue_free()


func _start_game(server_character: Dictionary) -> void:
	_set_busy(true)
	var game_response: Dictionary = await NetworkClient.get_game_state()
	_set_busy(false)
	if not game_response.get("ok", false):
		_show_response_error(game_response)
		return
	server_character = game_response.get("character", server_character) as Dictionary
	var server_state: Dictionary = game_response.get("state", {}) as Dictionary
	var data := server_state_to_save_data(server_character, server_state)
	data["offline_reward"] = NetworkClient.offline_reward
	NetworkClient.offline_reward = null
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


static func server_state_to_save_data(server_character: Dictionary, state: Dictionary) -> Dictionary:
	var attributes: Dictionary = state.get("attributes", {}) as Dictionary
	var authoritative_stats: Dictionary = state.get("stats", {}) as Dictionary
	var inventory_items: Array = []
	for raw in state.get("inventory", []):
		inventory_items.append({"item_id": int(raw.get("itemId", 0)), "count": int(raw.get("count", 0)), "bound": bool(raw.get("bound", false))})
	var equip_instances: Array = []
	var equipped_ids: Dictionary = state.get("equipped", {}) as Dictionary
	var equipped_by_slot: Dictionary = {}
	for raw in state.get("equipmentBag", []):
		var item := _server_equipment_to_client(raw as Dictionary, equipped_ids)
		equip_instances.append(item)
		if bool(item.get("equipped", false)):
			equipped_by_slot[str(item.get("slot", ""))] = item.duplicate(true)
	var equipment_slots := {}
	for slot in ["weapon", "armor", "shoes", "ring", "necklace", "cape", "helmet", "charm"]:
		equipment_slots[slot] = equipped_by_slot.get(slot, {})
	var skill_slots: Array = []
	var skill_priorities: Dictionary = state.get("skillPriorities", {}) as Dictionary
	for raw_id in state.get("skillSlots", []):
		var skill_id := int(raw_id)
		skill_slots.append({"skill_id": skill_id, "priority": clampi(int(skill_priorities.get(str(skill_id), 2)), 1, 3)})
	while skill_slots.size() < 6:
		skill_slots.append(null)
	var gems: Array = []
	for raw in state.get("gemBag", []):
		gems.append({"id": int(raw.get("gemId", 0)), "level": int(raw.get("level", 1)), "count": int(raw.get("count", 0)), "bound": bool(raw.get("bound", false))})
	var map_values: Array[int] = []
	for raw in state.get("mapGrids", []):
		map_values.append(int(raw))
	var construction_buildings: Dictionary = state.get("constructionBuildings", {}) as Dictionary
	return {
		"character_name": str(server_character.get("name", "勇者")),
		"level": int(server_character.get("level", 1)),
		"exp": int(server_character.get("experience", 0)),
		"exp_max": int(100.0 * pow(1.12, int(server_character.get("level", 1)) - 1)),
		"gold": int(str(server_character.get("gold", "0"))),
		# HP is part of the server snapshot. Keep the browser presentation in
		# sync after a battle instead of resetting the bar to full locally.
		"player_hp": clampi(int(state.get("hp", state.get("maxHp", 500))), 0, maxi(1, int(state.get("maxHp", 500)))),
		"player_max_hp": maxi(1, int(state.get("maxHp", 500))),
		"revive_coins": int(state.get("reviveCoins", 3)),
		"boss_tier": int(state.get("bossTier", 0)),
		"boss_index": int(state.get("bossIndex", 1)),
		"free_points": int(state.get("freeAttributePoints", 0)),
		"stat_atk": int(attributes.get("attack", 0)),
		"stat_def": int(attributes.get("defense", 0)),
		"stat_spd": int(attributes.get("speed", 0)),
		"stat_luk": int(attributes.get("luck", 0)),
		# Derived combat values are calculated and persisted by the server. Keep
		# the snapshot for network UI/battle presentation instead of rebuilding it
		# from client-side equipment formulas.
		"authoritative_stats": authoritative_stats.duplicate(true),
		"grid_index": int(state.get("gridIndex", 0)),
		"map_total_grids": int(state.get("mapTotalGrids", map_values.size())),
		"map_grids": map_values,
		"construction_buildings": construction_buildings.duplicate(true),
		"pending_construction": state.get("pendingConstruction", null),
		"dice_history": state.get("diceHistory", []),
		"poker_records": state.get("pokerRecords", []),
		"inventory": {"items": inventory_items, "capacity": int(state.get("inventoryCapacity", 100)), "expansion_count": int(state.get("inventoryExpansionCount", 0))},
		"equipment": {"equipped": equipment_slots, "slot_enhance": state.get("slotEnhance", {})},
		"equip_instances": equip_instances,
		"equip_capacity": int(state.get("equipmentCapacity", 100)),
		"equip_expansion_count": int(state.get("equipmentExpansionCount", 0)),
		"dismantle_essence": int(state.get("dismantleEssence", 0)),
		"auto_dismantle_enabled": bool(state.get("autoDismantleEnabled", false)),
		"auto_dismantle_rules": state.get("autoDismantleRules", {}),
		"skill_system": {"slots": skill_slots, "unlocked_skills": state.get("skills", [1, 22])},
		"gem_bag": gems,
		"lottery_tickets": state.get("lotteryTicketNumbers", []),
		"completed_laps": int(state.get("completedLaps", 0)),
		"lottery_last_draw_lap": int(state.get("lotteryLastDrawLap", 0)),
		"deity_buffs": state.get("deityBuffs", []),
		"current_weather": str(state.get("weather", "sunny")),
		"weather_roll_count": int(state.get("weatherRollCount", 0)),
		"weather_roll_target": int(state.get("weatherRollTarget", 8)),
		"weather_sunny_buffer": int(state.get("weatherSunnyBuffer", 10)),
		"last_gold_per_hour": float(state.get("lastGoldPerHour", 0.0)),
		"last_exp_per_hour": float(state.get("lastExpPerHour", 0.0)),
		"next_roll_modifier": int(state.get("nextRollModifier", 0)),
		"hibernate_laps": int(state.get("hibernateLaps", 0)),
		"last_online": int(state.get("lastOnline", Time.get_unix_time_from_system())),
	}


static func _server_equipment_to_client(raw: Dictionary, equipped_ids: Dictionary) -> Dictionary:
	var id := str(raw.get("id", ""))
	var slot := str(raw.get("slot", ""))
	var quality := int(raw.get("quality", 0))
	return {
		"uid": id.hash(), "server_id": id, "slot": slot,
		"slot_type_id": ["weapon", "armor", "shoes", "ring", "necklace", "cape", "helmet", "charm"].find(slot) + 1,
		"quality": quality, "quality_name": ["普通", "精良", "稀有", "史诗", "传说"][clampi(quality, 0, 4)],
		"base_name": str(raw.get("baseName", raw.get("name", "装备"))), "icon": str(raw.get("icon", "")), "icon_path": str(raw.get("iconPath", "")),
		"main_stat": str(raw.get("mainStat", "主属性")), "main_value": float(raw.get("mainValue", 0.0)),
		"affixes": raw.get("affixes", []), "gems": raw.get("gems", []), "gem_slots": int(raw.get("gemSlots", 0)),
		"initial_gem_slots": int(raw.get("initialGemSlots", raw.get("gemSlots", 0))), "enhance": 0,
		"locked": bool(raw.get("locked", false)), "bound": bool(raw.get("bound", false)), "acquired_at": int(raw.get("acquiredAt", 0)),
		"suit_name": str(raw.get("suitName", "")), "extra_suit_name": str(raw.get("extraSuitName", "")), "set_affixes": raw.get("setAffixes", []),
		"equipped": str(equipped_ids.get(slot, "")) == id,
	}


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
	_logout_account.disabled = busy
	_delete_character.disabled = busy
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
