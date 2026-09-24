extends Control

## ============================================================
## 大勇者 - 主游戏界面 v0.5
## 菱形格子 + 主角叠格子 + 单行按钮 + 自动挂机
## debug_cmd 可触发: click_dice, click_bag, click_skill, click_log, click_home, toggle_auto
## ============================================================

# -- 格子类型 --
const GRID_TYPES = [
	{ "icon": "家", "name": "勇者之家",  "clr": Color(0.3, 0.5, 0.3) },
	{ "icon": "战", "name": "战斗格",    "clr": Color(0.6, 0.2, 0.2) },
	{ "icon": "英", "name": "精英战斗",  "clr": Color(0.5, 0.1, 0.3) },
	{ "icon": "挑", "name": "挑战格",    "clr": Color(0.7, 0.5, 0.1) },
	{ "icon": "息", "name": "休息格",    "clr": Color(0.2, 0.5, 0.5) },
	{ "icon": "箱", "name": "宝箱格",    "clr": Color(0.7, 0.6, 0.1) },
	{ "icon": "锻", "name": "锻造格",    "clr": Color(0.5, 0.3, 0.1) },
	{ "icon": "命", "name": "命运格",    "clr": Color(0.4, 0.2, 0.6) },
	{ "icon": "神", "name": "神祇格",    "clr": Color(0.6, 0.6, 0.1) },
	{ "icon": "合", "name": "合成格",    "clr": Color(0.3, 0.2, 0.7) },
	{ "icon": "雷", "name": "闪电格",    "clr": Color(0.8, 0.8, 0.1) },
	{ "icon": "B", "name": "Boss格",    "clr": Color(0.6, 0.0, 0.0) },
	{ "icon": "空", "name": "空地",      "clr": Color(0.3, 0.5, 0.2) },
	{ "icon": "金", "name": "空地2",     "clr": Color(0.3, 0.5, 0.2) },
	{ "icon": "彩", "name": "彩票格",    "clr": Color(0.75, 0.25, 0.45) },
	{ "icon": "建", "name": "建设格",    "clr": Color(0.25, 0.55, 0.35) },
]

# 扑克牌花色（工具常量已移至 UIUtils）
const SUITS := ["♠", "♣", "♥", "♦"]

# -- 玩家状态 --
var player_name: String = "勇者"
var player_level: int = 1
var player_exp: int = 0
var player_exp_max: int = 100
const MAX_PLAYER_LEVEL := 100
const MAX_OFFLINE_SECONDS := 12 * 3600
var player_gold: int = 0
var player_revive: int = 3
var player_max_revive: int = 3
var player_hp: int = 500
var player_max_hp: int = 500
var player_boss_tier: int = 0
var player_boss_index: int = 1
# 自由属性点（每升1级+2点）
var player_free_points: int = 0
var player_stat_atk: int = 0
var player_stat_def: int = 0
var player_stat_spd: int = 0
var player_stat_luk: int = 0
var authoritative_stats: Dictionary = {}
var _attribute_request_in_flight: bool = false
var player_grid_index: int = 0
var map_total_grids: int = 28
var map_grids: Array[int] = []
var construction_buildings: Dictionary = {}
var pending_construction: Variant = null
var last_dice_roll: int = 0
var last_dice_suit: String = ""
var last_dice_history: Array[int] = []
var poker_records: Array[Dictionary] = []
var auto_play_enabled: bool = false
var _current_slot: int = -1  # 当前存档槽位

const VISIBLE_BEFORE: int = 3
const VISIBLE_AFTER: int  = 5
const CURRENT_TILE_SLOT: int = VISIBLE_BEFORE

const GridTileCls = preload("res://scripts/grid_tile.gd")
const DiceRollerCls = preload("res://scripts/dice_roller.gd")
const GridExecutorCls = preload("res://scripts/grid_executor.gd")
const InventoryCls = preload("res://scripts/inventory.gd")
const EquipmentCls = preload("res://scripts/equipment.gd")
const ItemDBRef = preload("res://scripts/item_db.gd")
const EquipGenCls = preload("res://scripts/equip_gen.gd")
const EquipData = preload("res://scripts/equip_data.gd")
const EquipmentRulesCls = preload("res://scripts/equipment_rules.gd")
const SkillDataRef = preload("res://scripts/skill_data.gd")
const SkillCls = preload("res://scripts/skill_system.gd")
const LoginScriptRef = preload("res://scripts/login.gd")
const UIUtilsRef = preload("res://scripts/ui/ui_utils.gd")
const TopBarCls = preload("res://scripts/ui/top_bar.gd")
const ShrineBackdropCls = preload("res://scripts/ui/shrine_backdrop.gd")
const BattleViewCls = preload("res://scripts/ui/battle_view.gd")
const WeatherEffectCls = preload("res://scripts/ui/weather_effect.gd")

# 子系统
var dice: RefCounted
var executor: RefCounted
var inventory: RefCounted
var skill_system: RefCounted
var equipment: RefCounted
var top_bar  # TopBar instance (no type hint to avoid parse-order issue after cache clear)

# 技能槽位（内嵌管理，6槽）

# 生成装备实例列表（每件唯一）
var equip_instances: Array[Dictionary] = []
var equip_capacity: int = EquipmentRulesCls.EQUIP_CAPACITY_BASE
var equip_expansion_count: int = 0
var dismantle_essence: int = 0
var auto_dismantle_enabled: bool = false
var auto_dismantle_rules: Array[Dictionary] = []
var gem_bag: Array[Dictionary] = []   # [{gem_id, level, count}]
var lottery_tickets: Array[int] = []  # 3位数 000~999, 最多10张
var _tooltip_nodes: Array[Node] = []  # 当前打开的 tooltip 列表
var _float_text_node: Control           # 当前飘字
var active_buffs: Array[Dictionary] = []  # [{name, turns_remaining}]
var lottery_draw_at: int = 0           # 下次开奖圈数
var completed_laps: int = 0
var lottery_last_draw_lap: int = 0
var _deity_buffs: Array[Dictionary] = []
var current_weather: String = "sunny"
var weather_roll_count: int = 0
var weather_roll_target: int = 8
var weather_sunny_buffer: int = 10
var last_gold_per_hour: float = 0.0
var last_exp_per_hour: float = 0.0
var _pending_offline_reward: Dictionary = {}
var NetworkClient: Variant
var next_roll_modifier: int = 0
var hibernate_laps: int = 0

# 移动动画
var _moving: bool = false
var _network_roll_in_flight: bool = false
var _network_roll_generation: int = 0
var _network_action_in_flight: bool = false
var _network_state_recovery_in_flight: bool = false
var _pending_network_response: Dictionary = {}
var _battle_active: bool = false
var _move_step: int = 0
var _move_total: int = 0
var _move_timer: float = 0.0
var _bounce_offset: float = 0.0     # 主角跳跃偏移
var _scroll_offset: float = 0.0     # 地块左滑偏移

const STEP_PAUSE: float = 0.21      # 每步停顿（原 0.3，缩短30%）
const STEP_SLIDE: float = 0.175     # 滑动时长（原 0.25，缩短30%）
const STEP_TOTAL: float = STEP_PAUSE + STEP_SLIDE  # 单步总时长
const DETAIL_CLICK_DELAY: float = 0.45  # 等待浏览器判定双击后再打开单击详情
var _detail_click_generation: int = 0

# 平行四边形地块尺寸（顶边宽 × 高，斜边由 GridTile.SHEAR 控制）
const TILE_W: float = 160.0       # 上下边水平宽度
const TILE_H: float = 90.0        # 平行四边形高度（标签内置）
const TILE_SHEAR: float = 45.0    # 斜边偏移（与 GridTile.SHEAR 一致）
const TILE_COUNT: int = VISIBLE_BEFORE + VISIBLE_AFTER + 1
const TILE_SLOT_NAMES: Array[String] = ["PrevGrid3", "PrevGrid2", "PrevGrid1", "CurrentGrid", "NextGrid1", "NextGrid2", "NextGrid3", "NextGrid4", "NextGrid5"]
const EXPANSION_PROTECT_RADIUS: int = 3
const EXPANSION_RESHUFFLE_ATTEMPTS: int = 80
# TILE_Y 在 _build_map_area 中动态计算


## ============ _ready ============
func _ready() -> void:
	NetworkClient = get_node_or_null("/root/NetworkClient")
	anchor_right  = 1.0
	anchor_bottom = 1.0
	var app_theme := Theme.new()
	app_theme.default_font = ThemeDB.fallback_font
	theme = app_theme

	# 初始化子系统
	dice = DiceRollerCls.new()
	executor = GridExecutorCls.new()
	inventory = InventoryCls.new()
	equipment = EquipmentCls.new()
	skill_system = SkillCls.new()

	top_bar = TopBarCls.new(self)
	_refresh_player_hp_bounds(true)

	# 从选择界面传来的存档数据
	if has_meta("save_slot") and has_meta("save_data"):
		_current_slot = get_meta("save_slot") as int
		var data: Dictionary = get_meta("save_data") as Dictionary
		_load_from_save_data(data)

	top_bar.build()
	top_bar.refresh_poker_slots()  # TopBar 创建后才能刷新牌型显示
	_build_map_area()
	_build_bottom_bar()
	if map_grids.is_empty():
		_generate_mock_map()
	_refresh_grid_display()

	# 信号
	$BottomBar/DiceRollBtn.pressed.connect(_on_dice_roll)
	$BottomBar/BagBtn.pressed.connect(_on_bag_pressed)
	$BottomBar/SkillBtn.pressed.connect(_on_skill_pressed)
	$BottomBar/LogBtn.pressed.connect(_on_log_pressed)
	$BottomBar/SettingsBtn.pressed.connect(_on_settings_pressed)
	$MapArea/AutoPlayCheck.toggled.connect(_on_auto_play_toggled)
	var auto_check := $MapArea/AutoPlayCheck as CheckButton
	auto_check.set_pressed_no_signal(auto_play_enabled)
	if _is_network_game():
		if not NetworkClient.chat_message_received.is_connected(_on_world_chat_message):
			NetworkClient.chat_message_received.connect(_on_world_chat_message)
		if not NetworkClient.chat_error.is_connected(_on_world_chat_error):
			NetworkClient.chat_error.connect(_on_world_chat_error)
		if not NetworkClient.realtime_authenticated.is_connected(_on_network_reconnected):
			NetworkClient.realtime_authenticated.connect(_on_network_reconnected)
		if not NetworkClient.realtime_disconnected.is_connected(_on_network_disconnected):
			NetworkClient.realtime_disconnected.connect(_on_network_disconnected)
		if not NetworkClient.session_invalidated.is_connected(_on_network_session_invalidated):
			NetworkClient.session_invalidated.connect(_on_network_session_invalidated)
		if not NetworkClient.kicked.is_connected(_on_network_kicked):
			NetworkClient.kicked.connect(_on_network_kicked)
		if not NetworkClient.web_visibility_changed.is_connected(_on_web_visibility_changed):
			NetworkClient.web_visibility_changed.connect(_on_web_visibility_changed)
		if not NetworkClient.background_resumed.is_connected(_on_background_resumed):
			NetworkClient.background_resumed.connect(_on_background_resumed)
	if auto_play_enabled:
		_start_auto_timer()
	if not _pending_offline_reward.is_empty():
		_show_offline_reward(_pending_offline_reward)


func _sm():
	return get_node_or_null("/root/SaveManager")


func _is_valid_equipment(eqp: Dictionary, expected_slot: String = "") -> bool:
	return EquipmentRulesCls.is_valid_equipment(eqp, expected_slot)


func _normalize_auto_dismantle_rules(raw: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if raw is Dictionary:
		var saved_rules: Variant = (raw as Dictionary).get("rules", [])
		if saved_rules is Array:
			for item in saved_rules:
				if item is Dictionary:
					result.append((item as Dictionary).duplicate(true))
	return result.slice(0, 10)


## ============================================================
## 第一部分 — 顶部属性栏
## ============================================================
func _build_map_area() -> void:
	var area := Panel.new()
	area.name = "MapArea"
	area.position = Vector2(0, 104)
	area.size = Vector2(1280, 528)
	UIUtils.shrine_panel_style(area, Color("f6d6d6"), Color("b88d89"), 1)

	# 抽象和风背景：未来替换背景图时，保留本节点作为兜底。
	var backdrop: Control = ShrineBackdropCls.new()
	backdrop.name = "ShrineBackdrop"
	backdrop.position = Vector2.ZERO
	backdrop.size = area.size
	area.add_child(backdrop)

	var weather_effect: Control = WeatherEffectCls.new()
	weather_effect.name = "WeatherEffect"
	weather_effect.position = Vector2.ZERO
	weather_effect.size = area.size
	weather_effect.setup(current_weather, false)
	area.add_child(weather_effect)

	# -- 平行四边形地块（下移到靠近底部，不占底部UI） --
	var total_span := TILE_COUNT * TILE_W
	var start_x := (1280.0 - total_span) / 2.0
	var tile_y: float = area.size.y - TILE_H - 12  # 靠下，留 12px 间距
	var slot_names: Array[String] = TILE_SLOT_NAMES
	var grid_tile_y: float = tile_y  # 主角定位用

	for i in range(TILE_COUNT):
		var tile: Control = GridTileCls.new()
		tile.name = slot_names[i]
		# x: 地块N的右下角=地块N+1的左下角（斜边公用）
		tile.position = Vector2(start_x + i * TILE_W, tile_y)
		tile.size = Vector2(TILE_W + TILE_SHEAR, TILE_H)  # 不含标签行
		tile.set_label_positions(0, 0)
		tile.clicked.connect(func() -> void: _on_map_tile_clicked(i))
		area.add_child(tile)

	# -- 主角图像（PNG 自带透明背景，直接读取源图避免导入压缩/透明异常） --
	var hero_tex: Texture2D = _load_hero_texture("res://assets/hreo.png")
	if hero_tex:
		var hero := TextureRect.new()
		hero.name = "HeroOnMap"
		hero.texture = hero_tex
		hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hero.size = Vector2(130, 130)
		area.add_child(hero)
		_position_hero_on_tile(hero, CURRENT_TILE_SLOT, area)  # 初始在当前格
	else:
		var fallback := Label.new()
		fallback.name = "HeroFallback"
		fallback.text = "勇者"
		fallback.add_theme_font_size_override("font_size", 64)
		# 居中当前格
		var fcx: float = start_x + CURRENT_TILE_SLOT * TILE_W + TILE_W / 2.0 + TILE_SHEAR / 2.0
		fallback.position = Vector2(fcx - 32, grid_tile_y - 50)
		area.add_child(fallback)

	# -- 左上角地图状态 --
	var status_panel := Panel.new()
	status_panel.name = "MapStatusPanel"
	status_panel.position = Vector2(20, 18)
	status_panel.size = Vector2(310, 34)
	UIUtils.shrine_panel_style(status_panel, Color(1.0, 0.976, 0.96, 0.92), Color("b88d89"), 1)
	area.add_child(status_panel)

	var pos_lbl := Label.new()
	pos_lbl.name = "GridPosLabel"
	pos_lbl.text = "当前格 1 / " + str(map_total_grids) + "  ·  已击败 Boss 0 / 200"
	pos_lbl.add_theme_font_size_override("font_size", 13)
	pos_lbl.add_theme_color_override("font_color", Color("352e38"))
	pos_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pos_lbl.position = Vector2(12, 2)
	pos_lbl.size = Vector2(286, 30)
	status_panel.add_child(pos_lbl)

	# -- 右上角：自动挂机 --
	var auto_check := CheckButton.new()
	auto_check.name = "AutoPlayCheck"
	auto_check.text = "自动挂机"
	auto_check.add_theme_font_size_override("font_size", 13)
	auto_check.add_theme_color_override("font_color", Color("352e38"))
	auto_check.add_theme_color_override("font_pressed_color", Color("527d68"))
	auto_check.button_pressed = false
	auto_check.position = Vector2(1120, 18)
	auto_check.size = Vector2(140, 34)

	var chk_icon := StyleBoxFlat.new()
	chk_icon.bg_color = Color(1.0, 0.976, 0.96, 0.92)
	chk_icon.border_width_left = 1; chk_icon.border_width_right = 1
	chk_icon.border_width_top = 1; chk_icon.border_width_bottom = 1
	chk_icon.border_color = Color("b88d89")
	chk_icon.set_corner_radius_all(3)
	auto_check.add_theme_stylebox_override("normal", chk_icon)

	area.add_child(auto_check)

	add_child(area)


func _load_hero_texture(res_path: String) -> Texture2D:
	var imported: Texture2D = load(res_path) as Texture2D
	if imported:
		return imported
	var image: Image = Image.load_from_file(res_path)
	if image != null and not image.is_empty():
		return ImageTexture.create_from_image(image)
	return null


## 调试面板开关
func _toggle_debug_panel() -> void:
	if _is_network_game():
		return
	var existing := get_node_or_null("DebugOverlay")
	if existing:
		existing.queue_free()
		return
	_build_debug_panel()


## 构建调试面板（4列 × 最大5排）
func _build_debug_panel() -> void:
	const COLS: int = 4
	const MAX_ROWS: int = 5
	const BTN_W: float = 130.0
	const BTN_H: float = 36.0
	const GAP: float = 8.0
	const MARGIN: float = 14.0
	const TITLE_H: float = 32.0
	var panel_w: float = MARGIN * 2 + BTN_W * COLS + GAP * (COLS - 1)
	var panel_h: float = TITLE_H + MARGIN + (BTN_H + GAP) * MAX_ROWS + MARGIN

	# 遮罩（点击关闭）
	var overlay := ColorRect.new()
	overlay.name = "DebugOverlay"
	overlay.color = Color(0, 0, 0, 0.45)
	overlay.size = Vector2(1280, 720)
	overlay.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			_toggle_debug_panel()
	)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	# 面板
	var panel := Panel.new()
	panel.name = "DebugPanel"
	panel.position = Vector2((1280.0 - panel_w) / 2.0, (720.0 - panel_h) / 2.0)
	panel.size = Vector2(panel_w, panel_h)
	UIUtils.panel_style(panel, Color(0.10, 0.10, 0.18, 0.97))
	overlay.add_child(panel)
	add_child(overlay)

	# 标题
	var title := Label.new()
	title.text = "调试面板"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 4)
	title.size = Vector2(panel_w, TITLE_H)
	panel.add_child(title)

	# 关闭按钮（右上角）
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.position = Vector2(panel_w - 32, 4)
	close_btn.size = Vector2(26, 26)
	UIUtils.btn_style_mini(close_btn, Color(0.4, 0.12, 0.12))
	close_btn.pressed.connect(_toggle_debug_panel)
	panel.add_child(close_btn)

	# ---------- 按钮定义 ----------
	var btn_defs: Array[Dictionary] = [
		# 第1排：资源生成
		{"text": "生成宝石",  "clr": Color(0.38, 0.12, 0.38), "cb": _on_test_generate_gem},
		{"text": "获得打孔器", "clr": Color(0.30, 0.20, 0.10), "cb": _on_test_add_socket_tool},
		{"text": "生成装备",  "clr": Color(0.22, 0.15, 0.38), "cb": _on_test_generate_equip},
		{"text": "+自由点",   "clr": Color(0.30, 0.25, 0.10), "cb": _on_test_add_free_point},
		{"text": "生成彩票",  "clr": Color(0.38, 0.08, 0.18), "cb": _on_test_generate_lottery},
		# 第2排：战斗测试
		{"text": "普通战斗",   "clr": Color(0.15, 0.35, 0.15), "cb": func(): _on_test_battle("battle")},
		{"text": "精英战斗",   "clr": Color(0.35, 0.20, 0.10), "cb": func(): _on_test_battle("elite")},
		{"text": "Boss战斗",   "clr": Color(0.35, 0.10, 0.10), "cb": func(): _on_test_battle("boss")},
	]

	for idx in range(btn_defs.size()):
		var def: Dictionary = btn_defs[idx]
		var row: int = idx / COLS
		var col: int = idx % COLS
		if row >= MAX_ROWS:
			break
		var bx: float = MARGIN + col * (BTN_W + GAP)
		var by: float = TITLE_H + MARGIN + row * (BTN_H + GAP)
		var btn := Button.new()
		btn.text = def["text"]
		btn.position = Vector2(bx, by)
		btn.size = Vector2(BTN_W, BTN_H)
		UIUtils.btn_style_mini(btn, def["clr"] as Color)
		btn.add_theme_font_size_override("font_size", 13)
		var cb: Callable = def["cb"] as Callable
		if cb.is_valid():
			btn.pressed.connect(cb)
		panel.add_child(btn)


## -- 测试战斗触发 --
func _on_test_battle(battle_kind: String) -> void:
	if _is_network_game():
		return
	var ctx := {
		"player_level": player_level,
		"player_gold": player_gold,
		"player_revive": player_revive,
		"player_hp": player_hp,
		"player_max_hp": player_max_hp,
		"player_name": player_name,
		"boss_tier": player_boss_tier,
		"boss_index": player_boss_index,
		"equip_instances": equip_instances,
		"equipment": equipment,
		"player_state": _build_player_battle_state(),
	}
	var result: Dictionary
	match battle_kind:
		"elite":
			result = GridExecutorCls._exec_elite(ctx)
		"boss":
			result = GridExecutorCls._exec_boss(ctx)
		_:
			result = GridExecutorCls._exec_battle(ctx)

	player_gold = int(ctx.get("player_gold", player_gold))
	player_revive = int(ctx.get("player_revive", player_revive))
	player_hp = clampi(int(ctx.get("player_hp", player_hp)), 0, player_max_hp)

	var edata: Dictionary = result.get("data", {})
	if edata.has("battle_result"):
		_apply_battle_result(edata)
		_show_battle_view(edata)
	var msg: String = edata.get("message", battle_kind + " 战斗完成")
	var clr: Color = Color(1.0, 0.85, 0.3)
	if edata.get("force_home", false):
		clr = Color(1.0, 0.4, 0.4)
	_show_float_text(msg, clr)

	top_bar.refresh()
	top_bar.refresh_compact_stats()
	_auto_save()


func _on_test_add_free_point() -> void:
	if _is_network_game():
		return
	player_free_points += 1
	_show_float_text("+1 自由属性点 (共" + str(player_free_points) + "点)", Color(1.0, 0.85, 0.2))
	_refresh_all_stats_panels()


## 将主角图像定位到指定菱形格子正上方
func _position_hero_on_tile(hero: TextureRect, tile_index: int, p_area: Control = null) -> void:
	var area: Control = p_area if p_area else get_node_or_null("MapArea")
	if not area:
		return
	var total_span := TILE_COUNT * TILE_W
	var start_x := (1280.0 - total_span) / 2.0
	var tile_y: float = area.size.y - TILE_H - 12  # 与 _build_map_area 一致
	# 平行四边形几何中心
	var center_x: float = start_x + tile_index * TILE_W + TILE_W / 2.0 + TILE_SHEAR / 2.0
	var center_y: float = tile_y + TILE_H / 2.0
	hero.position = Vector2(center_x - hero.size.x / 2.0, center_y - hero.size.y + 10 + _bounce_offset)


## ============================================================
## 第三部分 — 底部按钮组（单行：背包 技能 | 掷骰 | 日志 设置）
## ============================================================
func _build_bottom_bar() -> void:
	var bar := Panel.new()
	bar.name = "BottomBar"
	bar.position = Vector2(0, 632)
	bar.size = Vector2(1280, 88)
	UIUtils.shrine_panel_style(bar, Color("fff9f5"), Color("b88d89"), 2)

	# 单行布局：4小按钮(w=170) + 1大按钮(w=260) = 940，剩余 340 / 6间隔 = 57
	const SMALL_W := 170
	const SMALL_H := 44
	const DICE_W := 260
	const DICE_H := 52
	const GAP := 57

	var dice_x := GAP + SMALL_W + GAP + SMALL_W + GAP  # = 57+170+57+170+57 = 511
	var btn_y := (88.0 - SMALL_H) / 2.0
	var dice_y := (88.0 - DICE_H) / 2.0

	# -- 掷骰大按钮（居中） --
	var dice_btn := Button.new()
	dice_btn.name = "DiceRollBtn"
	dice_btn.text = "掷骰前进"
	dice_btn.position = Vector2(dice_x, dice_y)
	dice_btn.size = Vector2(DICE_W, DICE_H)
	UIUtils.shrine_button_style(dice_btn, true)
	dice_btn.add_theme_font_size_override("font_size", 19)
	bar.add_child(dice_btn)

	# -- 功能按钮（左侧2个 + 右侧2个） --
	var btn_defs := [
		{ "name": "BagBtn",       "text": "背包",  "x": GAP },
		{ "name": "SkillBtn",     "text": "技能",  "x": GAP + SMALL_W + GAP },
		{ "name": "LogBtn",       "text": "聊天",  "x": dice_x + DICE_W + GAP },
		{ "name": "SettingsBtn",  "text": "主界面",  "x": dice_x + DICE_W + GAP + SMALL_W + GAP },
	]
	for b in btn_defs:
		var btn := Button.new()
		btn.name = b["name"]
		btn.text = b["text"]
		btn.position = Vector2(b["x"], btn_y)
		btn.size = Vector2(SMALL_W, SMALL_H)
		UIUtils.shrine_button_style(btn, false)
		btn.add_theme_font_size_override("font_size", 16)
		bar.add_child(btn)

	# 调试工具只属于离线开发档，联网模式下客户端不能提供本地改档入口。
	if not _is_network_game():
		var debug_btn := Button.new()
		debug_btn.name = "DebugPanelBtn"
		debug_btn.text = "调试"
		debug_btn.position = Vector2(8, 314)
		debug_btn.size = Vector2(80, 28)
		UIUtils.btn_style_mini(debug_btn, Color(0.22, 0.22, 0.35))
		debug_btn.pressed.connect(_toggle_debug_panel)
		add_child(debug_btn)

	add_child(bar)


## ============================================================
## 自动挂机
## ============================================================
func _on_auto_play_toggled(pressed: bool) -> void:
	auto_play_enabled = pressed
	if _is_network_game():
		var response: Dictionary = await NetworkClient.execute_game_command("auto-play", {"enabled": pressed})
		if not response.get("ok", false):
			auto_play_enabled = not pressed
			var auto_check := get_node_or_null("MapArea/AutoPlayCheck") as CheckButton
			if auto_check:
				auto_check.set_pressed_no_signal(auto_play_enabled)
			_show_float_text(_network_error_message(response), Color(1.0, 0.3, 0.3))
			return
	var battle_view := get_node_or_null("MapArea/BattleView")
	if battle_view:
		battle_view.auto_continue = pressed
	if pressed:
		# 启动自动掷骰计时器
		_start_auto_timer()
	else:
		# 停止计时器
		_stop_auto_timer()


func _start_auto_timer() -> void:
	if _is_network_game() and NetworkClient.is_web_page_hidden():
		return
	var timer := get_node_or_null("AutoPlayTimer") as Timer
	if not timer:
		timer = Timer.new()
		timer.name = "AutoPlayTimer"
		timer.one_shot = true
		timer.timeout.connect(_on_auto_dice_roll)
		add_child(timer)
	timer.start(1.5)


func _stop_auto_timer() -> void:
	var timer := get_node_or_null("AutoPlayTimer") as Timer
	if timer:
		timer.stop()


func _on_auto_dice_roll() -> void:
	if not auto_play_enabled:
		return
	_on_dice_roll()


func _refresh_player_hp_bounds(fill_if_empty: bool = false) -> void:
	var ps: Dictionary = _calc_player_stats()
	player_max_hp = maxi(int(ps.get("hp", 500)), 1)
	if fill_if_empty:
		player_hp = player_max_hp
	else:
		# Refreshing equipment/stats must not heal a network character. HP is
		# authoritative state and is only changed by a server snapshot or battle.
		player_hp = clampi(player_hp, 0, player_max_hp)


## ============================================================
## 从存档数据恢复状态
## ============================================================
func _load_from_save_data(data: Dictionary) -> void:
	if data.is_empty():
		return
	player_name = data.get("character_name", "勇者")
	player_level = clampi(int(data.get("level", 1)), 1, MAX_PLAYER_LEVEL)
	player_exp = maxi(int(data.get("exp", 0)), 0) if player_level < MAX_PLAYER_LEVEL else 0
	player_exp_max = maxi(int(data.get("exp_max", 100)), 1)
	player_gold = data.get("gold", 0)
	player_revive = data.get("revive_coins", 3)
	player_boss_tier = data.get("boss_tier", 0)
	player_boss_index = data.get("boss_index", player_boss_tier + 1)
	player_free_points = data.get("free_points", 0)
	player_stat_atk = data.get("stat_atk", 0)
	player_stat_def = data.get("stat_def", 0)
	player_stat_spd = data.get("stat_spd", 0)
	player_stat_luk = data.get("stat_luk", 0)
	authoritative_stats = data.get("authoritative_stats", {}).duplicate(true)
	player_grid_index = data.get("grid_index", 0)
	map_total_grids = data.get("map_total_grids", 28)
	map_grids.clear()
	for item in data.get("map_grids", []):
		map_grids.append(int(item))
	construction_buildings = (data.get("construction_buildings", {}) as Dictionary).duplicate(true)
	pending_construction = data.get("pending_construction", null)
	last_dice_history.clear()
	for item in data.get("dice_history", []):
		last_dice_history.append(int(item))
	poker_records.clear()
	for item in data.get("poker_records", []):
		if item is Dictionary:
			poker_records.append(_normalize_poker_record(item as Dictionary))
	inventory.from_dict(data.get("inventory", []))
	equipment.from_dict(data.get("equipment", {}))
	equip_instances.clear()
	for item in data.get("equip_instances", []):
		var normalized := EquipmentRulesCls.normalize_equipment(EquipGenCls.deserialize(item as Dictionary))
		normalized["enhance"] = 0
		equip_instances.append(normalized)
	equip_capacity = clampi(int(data.get("equip_capacity", EquipmentRulesCls.EQUIP_CAPACITY_BASE)), EquipmentRulesCls.EQUIP_CAPACITY_BASE, EquipmentRulesCls.EQUIP_CAPACITY_MAX)
	equip_expansion_count = clampi(int(data.get("equip_expansion_count", (equip_capacity - EquipmentRulesCls.EQUIP_CAPACITY_BASE) / EquipmentRulesCls.EQUIP_EXPAND_SIZE)), 0, EquipmentRulesCls.EQUIP_EXPANSION_COSTS.size())
	dismantle_essence = maxi(0, int(data.get("dismantle_essence", 0)))
	auto_dismantle_enabled = bool(data.get("auto_dismantle_enabled", false))
	auto_dismantle_rules = _normalize_auto_dismantle_rules(data.get("auto_dismantle_rules", {}))
	auto_play_enabled = bool(data.get("auto_play_enabled", false))
	skill_system.update_max_slots(player_level)
	skill_system.from_dict(data.get("skill_system", {}))
	skill_system.update_max_slots(player_level)
	_refresh_player_hp_bounds(true)
	if data.has("player_max_hp"):
		player_max_hp = maxi(int(data.get("player_max_hp", player_max_hp)), 1)
		player_hp = clampi(int(data.get("player_hp", player_max_hp)), 0, player_max_hp)
	gem_bag.assign(data.get("gem_bag", []))
	lottery_tickets.assign(data.get("lottery_tickets", []))
	for ticket_index in range(lottery_tickets.size()):
		lottery_tickets[ticket_index] = clampi(lottery_tickets[ticket_index], 0, 999)
	completed_laps = int(data.get("completed_laps", 0))
	lottery_last_draw_lap = int(data.get("lottery_last_draw_lap", completed_laps))
	_deity_buffs.assign(data.get("deity_buffs", []))
	current_weather = str(data.get("current_weather", "sunny"))
	call_deferred("_refresh_map_weather_effect")
	weather_roll_count = int(data.get("weather_roll_count", 0))
	weather_roll_target = clampi(int(data.get("weather_roll_target", randi_range(1, 15))), 1, 15)
	weather_sunny_buffer = maxi(0, int(data.get("weather_sunny_buffer", 10)))
	last_gold_per_hour = float(data.get("last_gold_per_hour", 0.0))
	last_exp_per_hour = float(data.get("last_exp_per_hour", 0.0))
	var server_offline_reward: Variant = data.get("offline_reward", null)
	if server_offline_reward is Dictionary and not (server_offline_reward as Dictionary).is_empty():
		var reward: Dictionary = server_offline_reward as Dictionary
		_pending_offline_reward = {
			"seconds": int(reward.get("seconds", 0)),
			"gold": int(reward.get("gold", 0)),
			"exp": int(reward.get("experience", 0)),
		}
	next_roll_modifier = int(data.get("next_roll_modifier", 0))
	hibernate_laps = int(data.get("hibernate_laps", 0))
	if not _is_network_game():
		_prepare_offline_reward(int(data.get("last_online", data.get("last_saved", Time.get_unix_time_from_system()))))
	# refresh_poker_slots() 延迟到 top_bar.build() 之后


## ============================================================
## 构建存档数据
## ============================================================
func _normalize_poker_record(raw: Dictionary) -> Dictionary:
	var value := clampi(int(raw.get("value", 0)), 1, 6)
	var suit_raw: Variant = raw.get("suit", "")
	var suit_index := -1
	if suit_raw is float or suit_raw is int:
		suit_index = int(suit_raw)
	else:
		suit_index = SUITS.find(str(suit_raw))
	return {"value": value, "suit": SUITS[clampi(suit_index, 0, SUITS.size() - 1)] if suit_index >= 0 else ""}


func _build_save_data() -> Dictionary:
	return {
		"character_name": player_name,
		"level": player_level,
		"exp": player_exp,
		"exp_max": player_exp_max,
		"gold": player_gold,
		"revive_coins": player_revive,
		"boss_tier": player_boss_tier,
		"boss_index": player_boss_index,
		"free_points": player_free_points,
		"stat_atk": player_stat_atk,
		"stat_def": player_stat_def,
		"stat_spd": player_stat_spd,
		"stat_luk": player_stat_luk,
		"authoritative_stats": authoritative_stats.duplicate(true),
		"grid_index": player_grid_index,
		"map_total_grids": map_total_grids,
		"map_grids": map_grids,
		"construction_buildings": construction_buildings.duplicate(true),
		"pending_construction": pending_construction,
		"dice_history": last_dice_history,
		"poker_records": poker_records,
		"inventory": inventory.to_dict(),
		"equipment": equipment.to_dict(),
		"equip_instances": equip_instances,
		"equip_capacity": equip_capacity,
		"equip_expansion_count": equip_expansion_count,
		"dismantle_essence": dismantle_essence,
		"auto_dismantle_enabled": auto_dismantle_enabled,
		"auto_dismantle_rules": {"rules": auto_dismantle_rules.duplicate(true)},
		"skill_system": skill_system.to_dict(),
		"gem_bag": gem_bag,
		"lottery_tickets": lottery_tickets,
		"completed_laps": completed_laps,
		"lottery_last_draw_lap": lottery_last_draw_lap,
		"deity_buffs": _deity_buffs,
		"current_weather": current_weather,
		"weather_roll_count": weather_roll_count,
		"weather_roll_target": weather_roll_target,
		"weather_sunny_buffer": weather_sunny_buffer,
		"last_gold_per_hour": last_gold_per_hour,
		"last_exp_per_hour": last_exp_per_hour,
		"next_roll_modifier": next_roll_modifier,
		"hibernate_laps": hibernate_laps,
		"last_online": int(Time.get_unix_time_from_system()),
	}


## ============================================================
## 掷骰逻辑 — 使用 DiceRoller + 步进移动 + GridExecutor
## ============================================================
func _on_dice_roll() -> void:
	if _moving or _battle_active or get_node_or_null("MapArea/BattleView"):
		return  # 移动中不能再次掷骰
	if _is_network_game():
		_on_network_dice_roll()
		return

	last_dice_roll = dice.roll()
	if next_roll_modifier != 0:
		last_dice_roll = clampi(last_dice_roll + next_roll_modifier, 1, 6)
		next_roll_modifier = 0
	_tick_weather_roll()
	last_dice_suit = SUITS[randi() % 4]

	top_bar.refresh_dice_display()

	var record := { "value": last_dice_roll, "suit": last_dice_suit }
	poker_records.append(record)
	top_bar.refresh_poker_slots()

	_show_dice_popup(last_dice_roll, last_dice_suit)

	last_dice_history.append(last_dice_roll)
	while last_dice_history.size() > 6:
		last_dice_history.pop_front()
	var hist_text := "花色记录: "
	for d in last_dice_history:
		hist_text += str(d) + " "
	var hist_lbl: Label = $TopBar/DiceHistLabel as Label
	if hist_lbl:
		hist_lbl.text = hist_text

	# 启动步进移动
	_move_step = 0
	_move_total = last_dice_roll
	_move_timer = 0.0
	_scroll_offset = 0.0
	_bounce_offset = 0.0
	_moving = true


func _on_network_dice_roll() -> void:
	if _network_roll_in_flight:
		return
	_network_roll_in_flight = true
	var request_generation := _network_roll_generation
	var response: Dictionary = await NetworkClient.execute_game_command("roll")
	if request_generation != _network_roll_generation:
		return
	_network_roll_in_flight = false
	if not response.get("ok", false):
		var recovered := false
		if _is_session_failure(response):
			_return_to_network_login()
			return
		if _is_transport_failure(response):
			recovered = await _recover_network_state("服务器已完成的操作会在重新同步后保留")
		if recovered:
			if auto_play_enabled:
				_start_auto_timer()
			return
		_show_float_text(_network_error_message(response), Color(1.0, 0.3, 0.3))
		if auto_play_enabled:
			_start_auto_timer()
		return
	var event: Dictionary = response.get("event", {}) as Dictionary
	last_dice_roll = clampi(int(event.get("dice", 1)), 1, 6)
	var suit_index := clampi(int((response.get("state", {}) as Dictionary).get("lastDiceSuit", 0)), 0, SUITS.size() - 1)
	last_dice_suit = SUITS[suit_index]
	_pending_network_response = response.duplicate(true)
	top_bar.refresh_dice_display()
	_show_dice_popup(last_dice_roll, last_dice_suit)
	_move_step = 0
	_move_total = last_dice_roll
	_move_timer = 0.0
	_scroll_offset = 0.0
	_bounce_offset = 0.0
	_moving = true


## 步进移动：每步停顿→滑动→复位→刷新内容
func _process(delta: float) -> void:
	if not _moving:
		return

	_move_timer += delta
	var step_phase: float = _move_timer / STEP_TOTAL  # 当前步进度 0~1
	var slide_start: float = STEP_PAUSE / STEP_TOTAL

	if step_phase > slide_start:
		# 滑动阶段：偏移从 0 → -TILE_W
		var sp: float = (step_phase - slide_start) / (1.0 - slide_start)
		_scroll_offset = -TILE_W * sp
		_bounce_offset = -abs(sin(sp * PI)) * 22.0
	else:
		_scroll_offset = 0.0
		_bounce_offset = 0.0

	_slide_grids()

	# 单步完成 → 复位偏移 + 刷新格子内容（补右边新格子）
	if _move_timer >= STEP_TOTAL:
		_move_timer = 0.0
		_move_step += 1
		_scroll_offset = 0.0
		_bounce_offset = 0.0

		player_grid_index = (player_grid_index + 1) % map_total_grids
		var prev_idx := (player_grid_index - 1 + map_total_grids) % map_total_grids
		if prev_idx > player_grid_index and not _is_network_game():
			player_gold += 50
			completed_laps += 1
			_tick_lap_effects()
			_check_lottery_draw()
			var rl: Label = $TopBar/DiceRewardLabel as Label
			if rl:
				rl.text = str(completed_laps) + " 圈"
			top_bar.refresh()

		_refresh_grid_display()
		_slide_grids()

		if _move_step >= _move_total:
			_moving = false
			_scroll_offset = 0.0
			_bounce_offset = 0.0
			_move_step = 0
			_move_total = 0
			_slide_grids()
			_on_move_complete()


## 每帧更新地块位置（应用滑动偏移）
func _slide_grids() -> void:
	var area := get_node_or_null("MapArea")
	if not area:
		return
	var total_span := TILE_COUNT * TILE_W
	var start_x := (1280.0 - total_span) / 2.0
	var slot_names: Array[String] = TILE_SLOT_NAMES
	for i in range(TILE_COUNT):
		var tile := area.get_node_or_null(slot_names[i])
		if tile:
			tile.position.x = start_x + i * TILE_W + _scroll_offset

	# 主角弹跳：始终锚定在逻辑当前格槽位上
	var hero: TextureRect = area.get_node_or_null("HeroOnMap") as TextureRect
	if hero:
		var tile_y: float = area.size.y - TILE_H - 12
		var cx: float = start_x + CURRENT_TILE_SLOT * TILE_W + TILE_W / 2.0 + TILE_SHEAR / 2.0
		var cy: float = tile_y + TILE_H / 2.0
		hero.position = Vector2(cx - hero.size.x / 2.0, cy - hero.size.y + 10 + _bounce_offset)


func _on_move_complete() -> void:
	if _is_network_game() and not _pending_network_response.is_empty():
		_apply_network_roll_response(_pending_network_response)
		_pending_network_response.clear()
		return
	var gtype: int = map_grids[player_grid_index % map_total_grids]
	var ctx := {
		"player_level": player_level,
		"player_gold": player_gold,
		"player_revive": player_revive,
		"player_hp": player_hp,
		"player_max_hp": player_max_hp,
		"player_name": player_name,
		"boss_tier": player_boss_tier,
		"boss_index": player_boss_index,
		"equip_instances": equip_instances,
		"equipment": equipment,
		"player_state": _build_player_battle_state(),
		"weather": current_weather,
		"hibernate": hibernate_laps > 0,
	}
	var result: Dictionary = executor.execute(gtype, ctx)
	player_gold = int(ctx.get("player_gold", player_gold))
	player_revive = int(ctx.get("player_revive", player_revive))
	player_hp = clampi(int(ctx.get("player_hp", player_hp)), 0, player_max_hp)
	print("[Grid] 格子类型=", gtype, " → ", result["event"])

	var edata: Dictionary = result.get("data", {})
	if edata.has("battle_result"):
		_apply_battle_result(edata)
		top_bar.check_poker_hand()
		top_bar.refresh()
		top_bar.refresh_compact_stats()
		_auto_save()
		_show_battle_view(edata)
		return

	if edata.get("type", "") == "equip":
		var eqp: Dictionary = edata.get("equip", {})
		if not eqp.is_empty():
			_show_float_text("获得装备 " + EquipGenCls.full_name(eqp), Color(1.0, 0.85, 0.3))
	elif edata.get("type", "") == "gem":
		_add_gem(int(edata.get("gem_id", 0)), int(edata.get("level", 1)), 1)
	elif edata.get("type", "") == "card":
		# 兼容旧版本地结果：天命卡获得后立即执行，不再进入背包。
		_apply_fate_card({})
	elif edata.get("type", "") == "lottery":
		_grant_lottery_ticket(int(edata.get("ticket", randi_range(0, 999))))
	elif edata.has("deity_effect"):
		_apply_deity_effect(edata.get("name", "神祇"), edata.get("deity_effect", {}))
	if edata.has("item_id"):
		var received_item_id := int(edata.get("item_id", 0))
		if received_item_id == 5:
			# 兼容旧版服务器事件，避免天命卡重新落入客户端背包。
			_apply_fate_card({})
		else:
			inventory.add_item(received_item_id, int(edata.get("count", 1)))
	if edata.has("next_step_bonus"):
		next_roll_modifier = int(edata.get("next_step_bonus", 0))
	if edata.has("next_step_penalty"):
		next_roll_modifier = -int(edata.get("next_step_penalty", 0))
	if edata.has("hibernate_laps"):
		hibernate_laps = maxi(hibernate_laps, int(edata.get("hibernate_laps", 1)))
	if edata.has("buff_type"):
		_add_buff(str(edata.get("name", "命运效果")), str(edata.get("buff_type", "")), int(edata.get("buff_turns", 1)))
	if bool(edata.get("teleport", false)):
		_teleport_to_grid_type(GridExecutorCls.GridType.LIGHT)
		return
	if bool(edata.get("teleport_treasure", false)):
		_teleport_to_grid_type(GridExecutorCls.GridType.TREASURE)
		return
	elif edata.has("jump"):
		var jump_val: int = edata["jump"]
		_do_lightning_jump(jump_val)
		return

	var msg: String = edata.get("message", "")
	if not msg.is_empty():
		var clr: Color = Color(1.0, 0.85, 0.3)
		if edata.get("type", "") == "punish":
			clr = Color(1.0, 0.4, 0.4)
		elif edata.get("type", "") == "bless":
			clr = Color(0.3, 1.0, 0.6)
		_show_float_text(msg, clr)

	if edata.get("name", "") in ["技能大赛", "攻击削弱"]:
		var turns: int = 3
		var bname: String = edata["name"]
		var bt: String = "dmg_x" + ("1.3" if bname == "技能大赛" else "0.7")
		_add_buff(bname, bt, turns)

	top_bar.check_poker_hand()
	if edata.has("exp_gain") and not edata.has("battle_result"):
		_add_exp(int(edata["exp_gain"]))

	top_bar.refresh()
	top_bar.refresh_compact_stats()
	_auto_save()
	if auto_play_enabled:
		_start_auto_timer()


func _apply_network_roll_response(response: Dictionary) -> void:
	var server_character: Dictionary = response.get("character", {}) as Dictionary
	var server_state: Dictionary = response.get("state", {}) as Dictionary
	var event: Dictionary = response.get("event", {}) as Dictionary
	var previous_laps := completed_laps
	var data: Dictionary = LoginScriptRef.server_state_to_save_data(server_character, server_state)
	_load_from_save_data(data)
	if completed_laps > previous_laps:
		var reward_label: Label = $TopBar/DiceRewardLabel as Label
		if reward_label: reward_label.text = str(completed_laps) + " 圈"
	_refresh_grid_display()
	top_bar.refresh()
	top_bar.refresh_compact_stats()
	top_bar.refresh_poker_slots()
	_refresh_visible_inventory_panel()
	var poker: Dictionary = event.get("poker", {}) as Dictionary
	if not poker.is_empty():
		var display_records: Array[Dictionary] = []
		for raw_record in poker.get("records", []):
			if raw_record is Dictionary:
				display_records.append(_normalize_poker_record(raw_record as Dictionary))
		poker_records = display_records
		top_bar.refresh_poker_slots()
		top_bar.set_poker_result(str(poker.get("message", "未成牌")))
	var lottery_draw: Dictionary = event.get("lotteryDraw", {}) as Dictionary
	var lottery_rewards: Dictionary = lottery_draw.get("rewards", {}) as Dictionary
	var lottery_message := str(lottery_rewards.get("message", ""))
	if bool(lottery_draw.get("won", false)) and not lottery_message.is_empty():
		_show_float_text(lottery_message, Color(1.0, 0.85, 0.3))
	if str(event.get("kind", "")) == "construction" and str(event.get("action", "")) == "choose":
		_show_construction_choice(int(event.get("gridIndex", player_grid_index)), event)
		return
	for raw_path_event in event.get("pathEvents", []):
		var path_event: Dictionary = raw_path_event as Dictionary
		var path_message := str(path_event.get("message", ""))
		if not path_message.is_empty(): _show_float_text(path_message, Color(1.0, 0.85, 0.3))
	if str(event.get("kind", "")) == "construction" and str(event.get("action", "")) in ["shop", "chest", "battle"] and not event.has("battle_result") and int(event.get("to", player_grid_index)) == player_grid_index:
		_show_construction_management(int(event.get("gridIndex", player_grid_index)), event)
	var battle_result: Dictionary = event.get("battle_result", {}) as Dictionary
	var history: Array = battle_result.get("events", []) as Array
	if not history.is_empty():
		_show_battle_view({
			"battle_kind": str(event.get("battleKind", "battle")),
			"battle_result": battle_result,
			"encounter": event.get("encounter", {}),
			# The server result is the only source for combat rewards and outcome.
			# Forward these fields to the view so its summary matches the state
			# already loaded above instead of displaying zero rewards.
			"gold_gain": int(battle_result.get("gold_gain", 0)),
			"exp_gain": int(battle_result.get("exp_gain", 0)),
			"drops": battle_result.get("drops", []),
			"revive_used": bool(battle_result.get("revive_used", false)),
			"force_home": bool(battle_result.get("force_home", false)),
			"gold_penalty": int(battle_result.get("gold_penalty", 0)),
			"luxury_gold_spent": int(battle_result.get("luxury_gold_spent", 0)),
			"boss_cleared": bool(battle_result.get("boss_cleared", false)),
			"message": str(event.get("message", "")),
		})
	else:
		var message := str(event.get("message", ""))
		if not message.is_empty():
			_show_float_text(message, Color(1.0, 0.85, 0.3))
	if auto_play_enabled and history.is_empty():
		_start_auto_timer()


func _show_construction_choice(grid_index: int, event: Dictionary) -> void:
	var old := get_node_or_null("ConstructionChoice")
	if old: old.queue_free()
	var panel := Panel.new()
	panel.name = "ConstructionChoice"
	panel.position = Vector2(350, 180)
	panel.size = Vector2(580, 300)
	UIUtils.panel_style(panel, Color(0.10, 0.13, 0.18, 0.98))
	var title := Label.new()
	title.text = "建设格：选择建设方向"
	title.position = Vector2(24, 18)
	title.size = Vector2(530, 32)
	title.add_theme_font_size_override("font_size", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)
	var hint := Label.new()
	hint.text = "建设费用 5000 金币，10 秒未选择将由服务器随机选择"
	hint.position = Vector2(24, 58)
	hint.size = Vector2(530, 26)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color("d9c98a"))
	panel.add_child(hint)
	var options := [
		{"type": "shop", "text": "商店\n收益随建设等级和间隔回合提高"},
		{"type": "chest", "text": "宝箱\n提高宝箱最低品质"},
		{"type": "battle", "text": "战斗\n提高金币、经验和装备掉落率"},
	]
	for index in range(options.size()):
		var option: Dictionary = options[index]
		var option_type := str(option["type"])
		var button := Button.new()
		button.text = str(option["text"])
		button.position = Vector2(22 + index * 182, 112)
		button.size = Vector2(170, 112)
		button.add_theme_font_size_override("font_size", 14)
		button.pressed.connect(Callable(self, "_choose_construction").bind(grid_index, option_type, panel))
		panel.add_child(button)
	add_child(panel)
	var timeout_timer := get_tree().create_timer(10.2)
	timeout_timer.timeout.connect(func() -> void:
		if is_instance_valid(panel): _resolve_construction_timeout(panel))


func _choose_construction(grid_index: int, direction: String, panel: Panel) -> void:
	if is_instance_valid(panel): panel.queue_free()
	var response: Dictionary = await NetworkClient.execute_game_command("construction/choose", {"grid_index": grid_index, "type": direction})
	if not response.get("ok", false):
		if _is_transport_failure(response):
			await _recover_network_state("建设操作结果已重新同步")
		elif _is_session_failure(response):
			_return_to_network_login()
		_show_float_text(_network_error_message(response), Color(1.0, 0.3, 0.3))
		return
	var server_character: Dictionary = response.get("character", {}) as Dictionary
	var server_state: Dictionary = response.get("state", {}) as Dictionary
	_load_from_save_data(LoginScriptRef.server_state_to_save_data(server_character, server_state))
	_refresh_grid_display()
	top_bar.refresh()
	_refresh_visible_inventory_panel()
	_show_float_text(str((response.get("event", {}) as Dictionary).get("message", "建设完成")), Color(0.4, 1.0, 0.6))
	if auto_play_enabled:
		_start_auto_timer()


func _resolve_construction_timeout(panel: Panel) -> void:
	if is_instance_valid(panel): panel.queue_free()
	var response: Dictionary = await NetworkClient.execute_game_command("construction/resolve")
	if not response.get("ok", false):
		if _is_transport_failure(response):
			await _recover_network_state("建设操作结果已重新同步")
		elif _is_session_failure(response):
			_return_to_network_login()
		return
	var server_character: Dictionary = response.get("character", {}) as Dictionary
	var server_state: Dictionary = response.get("state", {}) as Dictionary
	_load_from_save_data(LoginScriptRef.server_state_to_save_data(server_character, server_state))
	_refresh_grid_display()
	top_bar.refresh()
	_refresh_visible_inventory_panel()
	_show_float_text(str((response.get("event", {}) as Dictionary).get("message", "建设已自动完成")), Color(1.0, 0.85, 0.3))
	if auto_play_enabled:
		_start_auto_timer()


func _show_construction_management(grid_index: int, event: Dictionary) -> void:
	var old := get_node_or_null("ConstructionManagement")
	if old: old.queue_free()
	var building: Dictionary = construction_buildings.get(str(grid_index), {}) as Dictionary
	if building.is_empty(): return
	var panel := Panel.new()
	panel.name = "ConstructionManagement"
	panel.position = Vector2(430, 420)
	panel.size = Vector2(420, 138)
	UIUtils.panel_style(panel, Color(0.10, 0.13, 0.18, 0.97))
	var title := Label.new()
	title.text = "%s建设格 Lv.%d" % [str({"shop": "商店", "chest": "宝箱", "battle": "战斗"}.get(str(building.get("type", "")), "建设")), int(building.get("level", 1))]
	title.position = Vector2(18, 12)
	title.size = Vector2(384, 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)
	var close := Button.new()
	close.text = "关闭"
	close.position = Vector2(330, 92)
	close.size = Vector2(70, 30)
	close.pressed.connect(panel.queue_free)
	panel.add_child(close)
	var level := int(building.get("level", 1))
	if level < 10:
		var upgrade := Button.new()
		upgrade.text = "升级（%d金）" % (level * 1500)
		upgrade.position = Vector2(38, 76)
		upgrade.size = Vector2(130, 38)
		upgrade.pressed.connect(func() -> void: _manage_construction("construction/upgrade", grid_index, panel))
		panel.add_child(upgrade)
	var demolish := Button.new()
	demolish.text = "拆除（免费）"
	demolish.position = Vector2(188, 76)
	demolish.size = Vector2(130, 38)
	demolish.pressed.connect(func() -> void: _manage_construction("construction/demolish", grid_index, panel))
	panel.add_child(demolish)
	add_child(panel)


func _manage_construction(path: String, grid_index: int, panel: Panel) -> void:
	if is_instance_valid(panel): panel.queue_free()
	var response: Dictionary = await NetworkClient.execute_game_command(path, {"grid_index": grid_index})
	if not response.get("ok", false):
		if _is_transport_failure(response):
			await _recover_network_state("建设操作结果已重新同步")
		elif _is_session_failure(response):
			_return_to_network_login()
		_show_float_text(_network_error_message(response), Color(1.0, 0.3, 0.3))
		return
	var server_character: Dictionary = response.get("character", {}) as Dictionary
	var server_state: Dictionary = response.get("state", {}) as Dictionary
	_load_from_save_data(LoginScriptRef.server_state_to_save_data(server_character, server_state))
	_refresh_grid_display()
	top_bar.refresh()
	_refresh_visible_inventory_panel()
	_show_float_text(str((response.get("event", {}) as Dictionary).get("message", "建设格已更新")), Color(0.4, 1.0, 0.6))


func _build_player_battle_state() -> Dictionary:
	var ps: Dictionary = _calc_player_stats()
	var deity: Dictionary = _calc_deity_bonus()
	return {
		"name": player_name,
		"level": player_level,
		"current_hp": player_hp,
		"max_hp": player_max_hp,
		"atk": ps.get("atk", 25),
		"def": ps.get("def", 15),
		"speed_points": float(ps.get("spd", 0.0)),
		"crit": ps.get("crit", 0),
		"critdmg": ps.get("critdmg", 150),
		"hit": ps.get("hit", 0),
		"dodge": ps.get("dodge", 0),
		"block": ps.get("block", 0),
		"skill_dmg": ps.get("skill_dmg", 0),
		"cd_reduce": clampf(float(ps.get("cd_reduce", 0)) + (1.0 - float(deity.get("cd_mult", 1.0))) * 100.0, -50.0, 50.0),
		"lifesteal": ps.get("lifesteal", 0.0),
		"free_atk_pct": ps.get("free_atk_pct", 0.0),
		"free_def_pct": ps.get("free_def_pct", 0.0),
		"gold_bonus": float(ps.get("gold_bonus", 0.0)) + (float(deity.get("gold_mult", 1.0)) - 1.0) * 100.0,
		"exp_bonus": ps.get("exp_bonus", 0.0),
		"luk": ps.get("luk", 0.0),
		"skill_slots": skill_system.to_dict().get("slots", []).duplicate(true),
		"battle_damage_mult": _calc_battle_damage_mult() * float(deity.get("damage_mult", 1.0)),
		"incoming_damage_mult": float(deity.get("incoming_damage_mult", 1.0)),
		"set_counts": _count_equipped_suits(),
		"set_affixes": _equipped_set_affix_names(),
		"battle_gold": player_gold,
	}


func _show_battle_view(edata: Dictionary) -> void:
	var area := get_node_or_null("MapArea") as Control
	if not area or area.get_node_or_null("BattleView"):
		return
	_stop_auto_timer()
	_battle_active = true
	var roll_button := get_node_or_null("BottomBar/DiceRollBtn") as Button
	if roll_button:
		roll_button.disabled = true
	var view: Control = BattleViewCls.new()
	view.name = "BattleView"
	view.auto_continue = auto_play_enabled
	area.add_child(view)
	view.closed.connect(func():
		_battle_active = false
		var button := get_node_or_null("BottomBar/DiceRollBtn") as Button
		if button:
			button.disabled = false
		if auto_play_enabled:
			_start_auto_timer()
	)
	view.setup(edata)


func _calc_battle_damage_mult() -> float:
	var mult: float = 1.0
	for buff in active_buffs:
		match String(buff.get("type", "")):
			"dmg_x1.3":
				mult *= 1.3
			"dmg_x0.7":
				mult *= 0.7
	return mult


func _apply_battle_result(edata: Dictionary) -> void:
	var battle_result: Dictionary = edata.get("battle_result", {})
	if battle_result.is_empty():
		return
	# 每场战斗独立计算血量；离开战斗后恢复满血，不保留结算剩余值。
	player_hp = player_max_hp
	if edata.has("exp_gain"):
		_add_exp(int(edata.get("exp_gain", 0)))
	var elapsed := maxf(float(battle_result.get("elapsed", 0.0)), 3.0)
	if int(edata.get("gold_gain", 0)) > 0:
		last_gold_per_hour = lerpf(last_gold_per_hour, float(edata.get("gold_gain", 0)) * 3600.0 / elapsed, 0.25) if last_gold_per_hour > 0.0 else float(edata.get("gold_gain", 0)) * 3600.0 / elapsed
	if int(edata.get("exp_gain", 0)) > 0:
		last_exp_per_hour = lerpf(last_exp_per_hour, float(edata.get("exp_gain", 0)) * 3600.0 / elapsed, 0.25) if last_exp_per_hour > 0.0 else float(edata.get("exp_gain", 0)) * 3600.0 / elapsed
	var drop_names: Array[String] = _grant_battle_drops(edata.get("drops", []))
	if not drop_names.is_empty():
		if drop_names.size() == 1:
			_show_float_text("获得掉落 " + drop_names[0], Color(0.9, 0.8, 0.3))
		else:
			_show_float_text("获得掉落 " + str(drop_names.size()) + " 件", Color(0.9, 0.8, 0.3))
	_tick_buffs()
	if bool(edata.get("boss_cleared", false)):
		_handle_boss_clear()
	if bool(edata.get("force_home", false)):
		player_grid_index = 0
		_refresh_grid_display()
	_refresh_player_hp_bounds(false)


func _grant_battle_drops(drops: Array) -> Array[String]:
	var names: Array[String] = []
	for raw in drops:
		var drop: Dictionary = raw
		var kind: String = String(drop.get("kind", ""))
		if kind in ["equip", "boss"]:
			var eqp: Dictionary = _roll_drop_equip(drop)
			if not eqp.is_empty() and _add_equipment_instance(eqp):
				names.append(EquipGenCls.full_name(eqp))
	return names


func _add_equipment_instance(raw_equip: Dictionary) -> bool:
	var eqp := EquipmentRulesCls.normalize_equipment(raw_equip)
	if auto_dismantle_enabled and not bool(eqp.get("locked", false)) and EquipmentRulesCls.should_auto_dismantle(eqp, {"rules": auto_dismantle_rules}):
		dismantle_essence += EquipmentRulesCls.essence_value(eqp)
		_return_equipment_gems(eqp)
		return false
	if equip_instances.size() >= equip_capacity:
		var replace_index := -1
		for i in range(equip_instances.size()):
			var current: Dictionary = equip_instances[i]
			if bool(current.get("equipped", false)) or bool(current.get("locked", false)):
				continue
			if replace_index < 0 or int(current.get("quality", 0)) < int(equip_instances[replace_index].get("quality", 0)):
				replace_index = i
		if replace_index < 0:
			_show_float_text("装备背包已满且全部锁定", Color(1.0, 0.45, 0.35))
			return false
		var removed: Dictionary = equip_instances[replace_index]
		dismantle_essence += EquipmentRulesCls.essence_value(removed)
		_return_equipment_gems(removed)
		equip_instances.remove_at(replace_index)
	equip_instances.append(eqp)
	return true


func _return_equipment_gems(eqp: Dictionary) -> void:
	for gem in eqp.get("gems", []):
		if gem is Dictionary:
			_add_gem(int(gem.get("id", 0)), int(gem.get("level", 1)), 1)
		elif int(gem) > 0:
			_add_gem(int(gem), 1, 1)


func _roll_drop_equip(drop: Dictionary) -> Dictionary:
	var kind: String = String(drop.get("kind", "equip"))
	if kind == "equip" and drop.has("chance") and randf() > float(drop.get("chance", 0.0)):
		return {}
	var options: Dictionary = {"boss_tier": player_boss_tier}
	var equipped_set_affixes := _equipped_set_affix_names()
	if equipped_set_affixes.has("【引力】磁力"):
		options["set_rate_bonus"] = 2.0
	var suits := _count_equipped_suits()
	if int(suits.get("引力", 0)) >= 4:
		var luck := int(_calc_player_stats().get("luk", 0))
		options["extra_suit_rate"] = 0.01 + float(luck) * 0.002 + (0.005 if equipped_set_affixes.has("【引力】护符") else 0.0)
	if kind == "boss":
		options["min_quality"] = 3
		options["max_quality"] = 4
	else:
		if drop.has("quality_floor"):
			options["min_quality"] = int(drop.get("quality_floor", 0))
	var eqp: Dictionary = EquipGenCls.generate(_random_drop_slot(), player_level, options)
	if randf() < float(_calc_deity_bonus().get("quality_up_chance", 0.0)) and int(eqp.get("quality", 0)) < 4:
		var promoted_options := options.duplicate(true)
		promoted_options["forced_quality"] = int(eqp.get("quality", 0)) + 1
		eqp = EquipGenCls.generate(str(eqp.get("slot", _random_drop_slot())), player_level, promoted_options)
	return eqp


func _random_drop_slot() -> String:
	var slots: Array[String] = ["weapon", "armor", "shoes", "ring", "necklace", "cape", "helmet", "charm"]
	return slots[randi() % slots.size()]


func _handle_boss_clear() -> void:
	player_boss_tier += 1
	player_boss_index = mini(player_boss_tier + 1, 200)
	var old_total: int = map_total_grids
	if player_boss_tier <= 20:
		var new_total: int = mini(128, 28 + player_boss_tier * 5)
		if new_total > old_total:
			_rebuild_map_for_boss_clear(old_total, new_total)
			_show_float_text("Boss击破！地图扩张到 " + str(map_total_grids) + " 格", Color(1.0, 0.75, 0.25))
	_refresh_grid_display()


func _rebuild_map_for_boss_clear(old_total: int, new_total: int) -> void:
	var previous_map: Array[int] = map_grids.duplicate()
	if previous_map.is_empty():
		_generate_mock_map()
		previous_map = map_grids.duplicate()
	var protected_indices: Array[int] = _collect_protected_indices(old_total)
	var protected_map: Dictionary = {}
	for idx in protected_indices:
		protected_map[idx] = previous_map[idx]
	map_total_grids = new_total
	var rebuilt: Array[int] = []
	rebuilt.resize(new_total)
	for i in range(new_total):
		rebuilt[i] = -1
	for idx in protected_indices:
		rebuilt[idx] = int(protected_map[idx])
	var counts: Dictionary = _count_grid_types(previous_map)
	for grid_type in _roll_expansion_grid_types(player_boss_tier, new_total - old_total):
		counts[grid_type] = int(counts.get(grid_type, 0)) + 1
	for grid_type in protected_map.values():
		counts[grid_type] = maxi(int(counts.get(grid_type, 0)) - 1, 0)
	var pending_types: Array[int] = _build_pending_grid_types_from_counts(counts, new_total - protected_indices.size())
	pending_types = _shuffle_grid_pool_with_constraints(pending_types)
	var pool_idx: int = 0
	for i in range(new_total):
		if rebuilt[i] != -1:
			continue
		if pool_idx >= pending_types.size():
			rebuilt[i] = GridExecutorCls.GridType.BATTLE
		else:
			rebuilt[i] = pending_types[pool_idx]
			pool_idx += 1
	map_grids.clear()
	for cell in rebuilt:
		map_grids.append(int(cell))
	_refresh_lottery_cycle_after_expansion(old_total, new_total)


func _collect_protected_indices(total: int) -> Array[int]:
	var indices: Array[int] = []
	for offset in range(-EXPANSION_PROTECT_RADIUS, EXPANSION_PROTECT_RADIUS + 1):
		var idx: int = posmod(player_grid_index + offset, total)
		if not indices.has(idx):
			indices.append(idx)
	indices.sort()
	return indices


func _count_grid_types(grid_list: Array[int]) -> Dictionary:
	var counts: Dictionary = {}
	for grid_type in grid_list:
		counts[grid_type] = int(counts.get(grid_type, 0)) + 1
	return counts


func _roll_expansion_grid_types(boss_tier: int, add_count: int) -> Array[int]:
	var plan: Array[int] = _get_expansion_addition_plan(boss_tier)
	var result: Array[int] = []
	for i in range(mini(add_count, plan.size())):
		result.append(plan[i])
	while result.size() < add_count:
		result.append(GridExecutorCls.GridType.BATTLE)
	return result


func _get_expansion_addition_plan(boss_tier: int) -> Array[int]:
	match boss_tier:
		1:
			return [GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.ELITE, GridExecutorCls.GridType.TREASURE, GridExecutorCls.GridType.EMPTY]
		2:
			return [GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.FATE, GridExecutorCls.GridType.FORGE, GridExecutorCls.GridType.CONSTRUCTION]
		3:
			return [GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.ELITE, GridExecutorCls.GridType.TREASURE, GridExecutorCls.GridType.CONSTRUCTION]
		4:
			return [GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.FATE, GridExecutorCls.GridType.FATE, GridExecutorCls.GridType.SYNTH]
		5:
			return [GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.ELITE, GridExecutorCls.GridType.TREASURE, GridExecutorCls.GridType.SYNTH]
		6:
			return [GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.FATE, GridExecutorCls.GridType.FORGE, GridExecutorCls.GridType.GOD]
		7:
			return [GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.ELITE, GridExecutorCls.GridType.TREASURE, GridExecutorCls.GridType.GOD]
		8:
			return [GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.FATE, GridExecutorCls.GridType.GOD, GridExecutorCls.GridType.LIGHT]
		9:
			return [GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.ELITE, GridExecutorCls.GridType.TREASURE, GridExecutorCls.GridType.LIGHT]
		10:
			return [GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.FATE, GridExecutorCls.GridType.FORGE, GridExecutorCls.GridType.CHALLENG]
		11:
			return [GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.ELITE, GridExecutorCls.GridType.TREASURE, GridExecutorCls.GridType.CHALLENG]
		12:
			return [GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.FATE, GridExecutorCls.GridType.GOD, GridExecutorCls.GridType.LOTTERY]
		13:
			return [GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.ELITE, GridExecutorCls.GridType.TREASURE, GridExecutorCls.GridType.CONSTRUCTION]
		14:
			return [GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.FATE, GridExecutorCls.GridType.CONSTRUCTION, GridExecutorCls.GridType.BOSS]
		15:
			return [GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.ELITE, GridExecutorCls.GridType.TREASURE, GridExecutorCls.GridType.BOSS]
		16:
			return [GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.FATE, GridExecutorCls.GridType.FORGE, GridExecutorCls.GridType.CONSTRUCTION]
		17:
			return [GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.ELITE, GridExecutorCls.GridType.TREASURE, GridExecutorCls.GridType.CONSTRUCTION]
		18:
			return [GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.FATE, GridExecutorCls.GridType.GOD, GridExecutorCls.GridType.BOSS]
		19:
			return [GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.ELITE, GridExecutorCls.GridType.TREASURE, GridExecutorCls.GridType.CONSTRUCTION]
		20:
			return [GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.REST, GridExecutorCls.GridType.FORGE, GridExecutorCls.GridType.CONSTRUCTION]
		_:
			return []


func _build_pending_grid_types_from_counts(counts: Dictionary, expected_size: int) -> Array[int]:
	var pool: Array[int] = []
	var ordered_types: Array[int] = [
		GridExecutorCls.GridType.HOME,
		GridExecutorCls.GridType.BATTLE,
		GridExecutorCls.GridType.ELITE,
		GridExecutorCls.GridType.CHALLENG,
		GridExecutorCls.GridType.REST,
		GridExecutorCls.GridType.TREASURE,
		GridExecutorCls.GridType.FORGE,
		GridExecutorCls.GridType.FATE,
		GridExecutorCls.GridType.GOD,
		GridExecutorCls.GridType.SYNTH,
		GridExecutorCls.GridType.LIGHT,
		GridExecutorCls.GridType.BOSS,
		GridExecutorCls.GridType.EMPTY,
		GridExecutorCls.GridType.CONSTRUCTION,
		GridExecutorCls.GridType.LOTTERY,
	]
	for grid_type in ordered_types:
		var amount: int = maxi(int(counts.get(grid_type, 0)), 0)
		for _i in range(amount):
			pool.append(grid_type)
	while pool.size() < expected_size:
		pool.append(GridExecutorCls.GridType.BATTLE)
	if pool.size() > expected_size:
		pool.resize(expected_size)
	return pool


func _shuffle_grid_pool_with_constraints(pool: Array[int]) -> Array[int]:
	if pool.size() <= 1:
		return pool
	var best: Array[int] = pool.duplicate()
	for _attempt in range(EXPANSION_RESHUFFLE_ATTEMPTS):
		var candidate: Array[int] = pool.duplicate()
		_shuffle_int_array(candidate)
		if _passes_grid_distance_rules(candidate):
			return candidate
		best = candidate
	return best


func _shuffle_int_array(arr: Array[int]) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = randi_range(0, i)
		var tmp: int = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func _passes_grid_distance_rules(pool: Array[int]) -> bool:
	if not _check_min_gap(pool, GridExecutorCls.GridType.ELITE, 3):
		return false
	if not _check_min_gap(pool, GridExecutorCls.GridType.REST, 5):
		return false
	if not _check_min_gap(pool, GridExecutorCls.GridType.EMPTY2, 6):
		return false
	if not _check_cross_gap(pool, GridExecutorCls.GridType.LIGHT, GridExecutorCls.GridType.BOSS, 8):
		return false
	if not _check_max_consecutive(pool, GridExecutorCls.GridType.EMPTY2, 2):
		return false
	return true


func _check_min_gap(pool: Array[int], target_type: int, min_gap: int) -> bool:
	var positions: Array[int] = []
	for i in range(pool.size()):
		if pool[i] == target_type:
			positions.append(i)
	if positions.size() <= 1:
		return true
	for i in range(positions.size()):
		for j in range(i + 1, positions.size()):
			if positions[j] - positions[i] < min_gap:
				return false
	return true


func _check_cross_gap(pool: Array[int], type_a: int, type_b: int, min_gap: int) -> bool:
	var positions_a: Array[int] = []
	var positions_b: Array[int] = []
	for i in range(pool.size()):
		if pool[i] == type_a:
			positions_a.append(i)
		elif pool[i] == type_b:
			positions_b.append(i)
	if positions_a.is_empty() or positions_b.is_empty():
		return true
	for a in positions_a:
		for b in positions_b:
			if absi(a - b) < min_gap:
				return false
	return true


func _check_max_consecutive(pool: Array[int], target_type: int, max_run: int) -> bool:
	var run: int = 0
	for grid_type in pool:
		if grid_type == target_type:
			run += 1
			if run > max_run:
				return false
		else:
			run = 0
	return true


func _refresh_lottery_cycle_after_expansion(old_total: int, new_total: int) -> void:
	# 地图扩张不改变现有进度，圈数仍只在经过起点时增加。
	return


func _auto_save() -> void:
	if _current_slot < 0:
		return
	var sm = _sm()
	if sm:
		sm.save_game(_current_slot, _build_save_data())


func _prepare_offline_reward(last_online: int) -> void:
	var now := int(Time.get_unix_time_from_system())
	var seconds := clampi(now - last_online, 0, MAX_OFFLINE_SECONDS)
	if seconds < 60:
		return
	var gold_rate := last_gold_per_hour if last_gold_per_hour > 0.0 else float(maxi(player_level, 1) * 600)
	var exp_rate := last_exp_per_hour if last_exp_per_hour > 0.0 else float(maxi(player_level, 1) * 720)
	var gold_gain := int(floor(gold_rate * float(seconds) / 3600.0 * 0.10))
	var exp_gain := int(floor(exp_rate * float(seconds) / 3600.0 * 0.10))
	if gold_gain <= 0 and exp_gain <= 0:
		return
	player_gold += gold_gain
	_pending_offline_reward = {"seconds": seconds, "gold": gold_gain, "exp": exp_gain}
	# 等 UI 创建完成后再统一升级并显示。
	call_deferred("_apply_pending_offline_exp", exp_gain)


func _apply_pending_offline_exp(exp_gain: int) -> void:
	_add_exp(exp_gain)


func _show_offline_reward(reward: Dictionary) -> void:
	var hours := float(reward.get("seconds", 0)) / 3600.0
	_show_float_text("离线 %.1f 小时：+%d金币 +%d经验" % [hours, int(reward.get("gold", 0)), int(reward.get("exp", 0))], Color(0.35, 0.85, 1.0))
	_pending_offline_reward.clear()


func _tick_weather_roll() -> void:
	if player_boss_tier < 6:
		current_weather = "sunny"
		_refresh_map_weather_effect()
		return
	weather_roll_count += 1
	if weather_roll_count < weather_roll_target:
		return
	weather_roll_count = 0
	weather_roll_target = randi_range(1, 15)
	if weather_sunny_buffer > 0:
		weather_sunny_buffer -= 1
		current_weather = "sunny"
		_refresh_map_weather_effect()
		return
	var weather_pool := [
		{"id": "sunny", "weight": 58}, {"id": "thunderstorm", "weight": 10}, {"id": "drizzle", "weight": 8},
		{"id": "fog", "weight": 7}, {"id": "blizzard", "weight": 7}, {"id": "scorching_sun", "weight": 5},
		{"id": "sandstorm", "weight": 3}, {"id": "aurora", "weight": 2},
	]
	var previous := current_weather
	for attempt in range(2):
		var roll := randi_range(1, 100)
		for entry in weather_pool:
			roll -= int(entry["weight"])
			if roll <= 0:
				current_weather = str(entry["id"])
				break
		if current_weather != previous:
			break
	_refresh_map_weather_effect()


func _refresh_map_weather_effect() -> void:
	var effect := get_node_or_null("MapArea/WeatherEffect")
	if effect and effect.has_method("set_weather"):
		effect.set_weather(current_weather)


func _tick_lap_effects() -> void:
	if hibernate_laps > 0:
		hibernate_laps -= 1
	for i in range(_deity_buffs.size() - 1, -1, -1):
		_deity_buffs[i]["turns"] = int(_deity_buffs[i].get("turns", 1)) - 1
		if int(_deity_buffs[i]["turns"]) <= 0:
			_deity_buffs.remove_at(i)


func _apply_deity_effect(deity_name: String, effect: Dictionary) -> void:
	if effect.is_empty():
		return
	if str(effect.get("stat", "")) == "fate_now":
		_apply_fate_card({})
		return
	var buff := effect.duplicate(true)
	buff["name"] = deity_name
	_apply_deity_buff(buff)


func _build_grid_context() -> Dictionary:
	return {"player_level": player_level, "player_gold": player_gold, "player_revive": player_revive, "player_hp": player_hp, "player_max_hp": player_max_hp, "player_name": player_name, "boss_tier": player_boss_tier, "boss_index": player_boss_index, "equip_instances": equip_instances, "equipment": equipment, "gem_bag": gem_bag, "player_state": _build_player_battle_state(), "weather": current_weather, "hibernate": hibernate_laps > 0}


func _teleport_to_grid_type(grid_type: int) -> void:
	var candidates: Array[int] = []
	for i in range(map_grids.size()):
		if int(map_grids[i]) == grid_type:
			candidates.append(i)
	if candidates.is_empty():
		_show_float_text("地图上没有可传送的目标格", Color(0.8, 0.65, 0.65))
		return
	player_grid_index = candidates[randi() % candidates.size()]
	_refresh_grid_display()
	call_deferred("_on_move_complete")


func _apply_simple_grid_result(edata: Dictionary) -> void:
	if edata.get("equip", {}) is Dictionary and not edata.get("equip", {}).is_empty():
		_add_equipment_instance(edata.get("equip", {}))
	if edata.has("gem_id"):
		_add_gem(int(edata.get("gem_id", 0)), int(edata.get("level", 1)), 1)
	if edata.has("item_id"):
		var received_item_id := int(edata.get("item_id", 0))
		if received_item_id == 5:
			_apply_fate_card({})
		else:
			inventory.add_item(received_item_id, int(edata.get("count", 1)))
	if edata.has("next_step_bonus"):
		next_roll_modifier = int(edata.get("next_step_bonus", 0))
	if edata.has("next_step_penalty"):
		next_roll_modifier = -int(edata.get("next_step_penalty", 0))
	if edata.has("hibernate_laps"):
		hibernate_laps = maxi(hibernate_laps, int(edata.get("hibernate_laps", 1)))
	if edata.has("buff_type"):
		_add_buff(str(edata.get("name", "命运效果")), str(edata.get("buff_type", "")), int(edata.get("buff_turns", 1)))
	if bool(edata.get("teleport", false)):
		_teleport_to_grid_type(GridExecutorCls.GridType.LIGHT)
	elif bool(edata.get("teleport_treasure", false)):
		_teleport_to_grid_type(GridExecutorCls.GridType.TREASURE)
	var message := str(edata.get("message", ""))
	if not message.is_empty():
		_show_float_text(message, Color(0.9, 0.75, 1.0))


## ============================================================
## 经验/升级系统
## ============================================================
## 增加经验，若经验满则自动升级
func _add_exp(amount: int) -> void:
	if amount <= 0:
		return
	if player_level >= MAX_PLAYER_LEVEL:
		player_level = MAX_PLAYER_LEVEL
		player_exp = 0
		return
	player_exp += amount
	while player_exp >= player_exp_max and player_level < MAX_PLAYER_LEVEL:
		player_exp -= player_exp_max
		player_level += 1
		player_free_points += 2
		player_exp_max = int(100.0 * pow(1.12, player_level - 1))
		_refresh_player_hp_bounds(false)
		_show_float_text("升级! Lv." + str(player_level) + " 获得2点自由属性点", Color(0.3, 1.0, 0.6))
	if player_level >= MAX_PLAYER_LEVEL:
		player_level = MAX_PLAYER_LEVEL
		player_exp = 0
	top_bar.refresh()


## 消耗自由属性点加点
func _add_free_stat(stat_name: String) -> void:
	if _is_network_game():
		_add_network_free_stat(stat_name)
		return
	if player_free_points <= 0:
		_show_float_text("没有可用属性点", Color(0.6, 0.6, 0.7))
		return
	match stat_name:
		"atk":
			player_stat_atk += 1
		"def":
			player_stat_def += 1
		"spd":
			player_stat_spd += 1
		"luk":
			player_stat_luk += 1
		_:
			return
	player_free_points -= 1
	_refresh_all_stats_panels()


## 洗点：重置自由属性点
func _reset_stats() -> void:
	if _is_network_game():
		_reset_network_stats()
		return
	var cost: int = player_level * 200
	if player_gold < cost:
		_show_float_text("金币不足！洗点需要 " + str(cost) + " 金", Color(1.0, 0.3, 0.3))
		return
	var total_used: int = player_stat_atk + player_stat_def + player_stat_spd + player_stat_luk
	if total_used <= 0 and player_free_points > 0:
		_show_float_text("没有已分配的属性点需要重置", Color(0.6, 0.6, 0.7))
		return
	if total_used <= 0:
		return
	player_gold -= cost
	player_free_points += total_used
	player_stat_atk = 0
	player_stat_def = 0
	player_stat_spd = 0
	player_stat_luk = 0
	_show_float_text("洗点成功！消耗 " + str(cost) + " 金币，归还 " + str(total_used) + " 自由属性点", Color(0.3, 1.0, 0.6))
	_refresh_all_stats_panels()


func _is_network_game() -> bool:
	return has_meta("network_character_id") and not str(get_meta("network_character_id", "")).is_empty()


func _network_error_message(response: Dictionary) -> String:
	var error: Dictionary = response.get("error", {}) as Dictionary
	return str(error.get("message", "操作失败，请稍后重试"))


func _run_network_game_command(path: String, payload: Dictionary = {}, success_message: String = "操作完成") -> bool:
	if _network_action_in_flight:
		return false
	_network_action_in_flight = true
	var response: Dictionary = await NetworkClient.execute_game_command(path, payload)
	_network_action_in_flight = false
	if not response.get("ok", false):
		if _is_session_failure(response):
			_return_to_network_login()
			return false
		if _is_transport_failure(response):
			await _recover_network_state("服务器已完成的操作会在重新同步后保留")
		_show_float_text(_network_error_message(response), Color(1.0, 0.3, 0.3))
		return false
	var server_character: Dictionary = response.get("character", {}) as Dictionary
	var server_state: Dictionary = response.get("state", {}) as Dictionary
	_load_from_save_data(LoginScriptRef.server_state_to_save_data(server_character, server_state))
	_refresh_grid_display()
	top_bar.refresh()
	top_bar.refresh_poker_slots()
	top_bar.refresh_compact_stats()
	_refresh_all_stats_panels()
	_refresh_visible_inventory_panel()
	var event: Dictionary = response.get("event", {}) as Dictionary
	var display_message := success_message if not success_message.is_empty() else str(event.get("message", "操作完成"))
	_show_float_text(display_message, Color(0.45, 1.0, 0.65))
	return true


func _is_transport_failure(response: Dictionary) -> bool:
	var error: Dictionary = response.get("error", {}) as Dictionary
	var code := str(error.get("code", ""))
	return code in ["NETWORK_ERROR", "INVALID_RESPONSE", "SERVICE_UNAVAILABLE"]


func _is_session_failure(response: Dictionary) -> bool:
	var error: Dictionary = response.get("error", {}) as Dictionary
	return str(error.get("code", "")) in ["SESSION_INVALID", "CHARACTER_REQUIRED"]


func _return_to_network_login() -> void:
	_stop_auto_timer()
	_moving = false
	NetworkClient.invalidate_local_session()
	get_tree().change_scene_to_file("res://scenes/login.tscn")


func _recover_network_state(message := "服务器状态已重新同步") -> bool:
	if not _is_network_game() or _network_state_recovery_in_flight:
		return false
	_network_state_recovery_in_flight = true
	var response: Dictionary = await NetworkClient.get_game_state()
	_network_state_recovery_in_flight = false
	if not response.get("ok", false):
		var error: Dictionary = response.get("error", {}) as Dictionary
		if str(error.get("code", "")) in ["SESSION_INVALID", "CHARACTER_REQUIRED"]:
			_return_to_network_login()
		return false
	var server_character: Dictionary = response.get("character", {}) as Dictionary
	var server_state: Dictionary = response.get("state", {}) as Dictionary
	_load_from_save_data(LoginScriptRef.server_state_to_save_data(server_character, server_state))
	_refresh_grid_display()
	top_bar.refresh()
	top_bar.refresh_poker_slots()
	top_bar.refresh_compact_stats()
	_refresh_all_stats_panels()
	_refresh_visible_inventory_panel()
	_show_float_text(message, Color(0.35, 0.85, 1.0))
	return true


func _on_network_reconnected() -> void:
	if _is_network_game():
		await _recover_network_state("网络恢复，已同步服务器状态")


func _on_web_visibility_changed(hidden: bool) -> void:
	if not _is_network_game():
		return
	_stop_auto_timer()
	if hidden:
		return
	# 浏览器后台期间服务器已继续推进。丢弃切入后台前尚未播放的旧响应，
	# 回到页面后只展示最新权威快照，避免排队播放大量过时动画。
	_network_roll_generation += 1
	_network_roll_in_flight = false
	_pending_network_response.clear()
	_moving = false
	_battle_active = false
	for node_name in ["ConstructionChoice", "ConstructionManagement"]:
		var overlay := get_node_or_null(node_name)
		if overlay:
			overlay.queue_free()
	var battle_view := get_node_or_null("MapArea/BattleView")
	if battle_view:
		battle_view.queue_free()
	var roll_button := get_node_or_null("BottomBar/DiceRollBtn") as Button
	if roll_button:
		roll_button.disabled = false
	await get_tree().create_timer(0.25).timeout
	if await _recover_network_state("后台挂机结果已同步") and auto_play_enabled:
		_start_auto_timer()


func _on_background_resumed() -> void:
	_on_web_visibility_changed(false)


func _on_network_disconnected(message: String) -> void:
	if not _is_network_game():
		return
	_stop_auto_timer()
	_moving = false
	await _recover_network_state(message)


func _on_network_kicked(message: String) -> void:
	if not _is_network_game():
		return
	_return_to_network_login()


func _on_network_session_invalidated(message: String) -> void:
	if not _is_network_game():
		return
	_return_to_network_login()


func _skill_slots_payload(priority_override_slot: int = -1, remove_slot: int = -1, add_skill_id: int = 0) -> Array:
	var payload: Array = []
	for i in range(skill_system.get_unlocked_slots()):
		if i == remove_slot:
			continue
		var skill_id = skill_system.get_slot_skill_id(i)
		if skill_id == null:
			continue
		var priority: int = int(skill_system.get_slot_priority(i))
		if i == priority_override_slot:
			priority = priority % 3 + 1
		payload.append({"skill_id": int(skill_id), "priority": priority})
	if add_skill_id > 0:
		payload.append({"skill_id": add_skill_id, "priority": 2})
	return payload


func _sync_network_skill_slots(priority_override_slot: int = -1, remove_slot: int = -1, add_skill_id: int = 0) -> bool:
	return await _run_network_game_command("skill/slot", {"slots": _skill_slots_payload(priority_override_slot, remove_slot, add_skill_id)}, "技能设置已保存")


func _apply_network_attribute_response(response: Dictionary) -> void:
	var state: Dictionary = response.get("state", {}) as Dictionary
	var attributes: Dictionary = state.get("attributes", {}) as Dictionary
	var server_character: Dictionary = response.get("character", {}) as Dictionary
	player_free_points = int(state.get("freeAttributePoints", player_free_points))
	player_stat_atk = int(attributes.get("attack", player_stat_atk))
	player_stat_def = int(attributes.get("defense", player_stat_def))
	player_stat_spd = int(attributes.get("speed", player_stat_spd))
	player_stat_luk = int(attributes.get("luck", player_stat_luk))
	player_level = int(server_character.get("level", player_level))
	player_exp = int(server_character.get("experience", player_exp))
	player_gold = int(str(server_character.get("gold", player_gold)))
	_refresh_all_stats_panels()


func _add_network_free_stat(stat_name: String) -> void:
	if _attribute_request_in_flight:
		return
	if player_free_points <= 0:
		_show_float_text("没有可用属性点", Color(0.6, 0.6, 0.7))
		return
	_attribute_request_in_flight = true
	await _run_network_game_command("attributes/allocate", {"attribute": stat_name}, "属性已分配")
	_attribute_request_in_flight = false


func _reset_network_stats() -> void:
	if _attribute_request_in_flight:
		return
	_attribute_request_in_flight = true
	await _run_network_game_command("attributes/reset", {}, "属性已重置")
	_attribute_request_in_flight = false


## ============ 闪电跳跃 ============
func _do_lightning_jump(jump_val: int) -> void:
	_show_float_text("闪电跳跃 " + str(jump_val) + " 格！", Color(1.0, 1.0, 0.3))
	# 粒子特效(竖着上升)
	_spawn_lightning_particles()
	# 跳跃
	player_grid_index = (player_grid_index + jump_val) % map_total_grids
	_refresh_grid_display()
	_on_move_complete()  # 触发新格子


func _spawn_lightning_particles() -> void:
	var hero: TextureRect = get_node_or_null("MapArea/HeroOnMap") as TextureRect
	if not hero: return
	var particles := CPUParticles2D.new()
	particles.emitting = true
	particles.amount = 20
	particles.lifetime = 0.8
	particles.direction = Vector2(0, -1)
	particles.spread = 30.0
	particles.gravity = Vector2(0, 0)
	particles.initial_velocity_min = 80.0
	particles.initial_velocity_max = 160.0
	particles.color = Color(1.0, 1.0, 0.3, 0.8)
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.position = hero.position + Vector2(hero.size.x/2, hero.size.y/2)
	hero.get_parent().add_child(particles)
	# 人物闪烁消失
	var tw := create_tween()
	tw.tween_property(hero, "modulate:a", 0.0, 0.3)
	tw.tween_property(hero, "modulate:a", 1.0, 0.3)
	hero.modulate.a = 1.0
	# 自动清理粒子
	var t := get_tree().create_timer(1.5)
	t.timeout.connect(particles.queue_free)


## ============ Buff 管理 ============
func _add_buff(name: String, type_tag: String, turns: int) -> void:
	active_buffs.append({ "name": name, "type": type_tag, "turns": turns })
	_show_float_text(name + "(" + str(turns) + "场)", Color(0.3, 1.0, 0.6))


func _tick_buffs() -> void:
	for i in range(active_buffs.size() - 1, -1, -1):
		active_buffs[i]["turns"] -= 1
		if active_buffs[i]["turns"] <= 0:
			active_buffs.remove_at(i)


## ============ 彩票开奖 ============
func _check_lottery_draw() -> void:
	if lottery_tickets.is_empty() or completed_laps - lottery_last_draw_lap < 5:
		return
	var win_num: int = randi_range(0, 999)
	var win_s: String = _fmt_lottery(win_num)
	var hit: bool = lottery_tickets.has(win_num)
	if hit:
		_grant_lottery_jackpot()
	_show_lottery_popup(win_s, hit)
	lottery_tickets.clear()
	lottery_last_draw_lap = completed_laps


func _grant_lottery_ticket(number: int) -> void:
	if lottery_tickets.size() >= 10:
		_show_float_text("彩票已满（最多10张）", Color(1.0, 0.45, 0.45))
		return
	lottery_tickets.append(clampi(number, 0, 999))
	_show_float_text("获得彩票 " + _fmt_lottery(number), Color(1.0, 0.75, 0.25))


func _grant_lottery_jackpot() -> void:
	player_gold += maxi(10000, player_level * 5000)
	_add_gem(randi_range(1, 8), 3, 1)
	inventory.add_item(5, 1)
	for quality in [2, 3, 4]:
		_add_equipment_instance(EquipGenCls.generate(_random_drop_slot(), player_level, {"boss_tier": player_boss_tier, "forced_quality": quality}))


func _show_lottery_popup(win_num: String, hit: bool) -> void:
	var ticket_texts: Array[String] = []
	for ticket in lottery_tickets:
		ticket_texts.append(_fmt_lottery(ticket))
	var held_text: String = " / ".join(ticket_texts)
	_moving = false

	# 遮罩
	var ov: ColorRect = ColorRect.new()
	ov.name = "LotteryOverlay"
	ov.position = Vector2(0, 0)
	ov.size = Vector2(1280, 720)
	ov.color = Color(0, 0, 0, 0.42)
	add_child(ov)

	# 与主界面一致的朱樱神社纸面弹窗。
	var popup: Panel = Panel.new()
	popup.position = Vector2(360, 160)
	popup.size = Vector2(560, 370)
	UIUtils.shrine_panel_style(popup, Color("fff9f5"), Color("b88d89"), 2)
	ov.add_child(popup)
	var gold_line := ColorRect.new()
	gold_line.position = Vector2(0, 0)
	gold_line.size = Vector2(560, 2)
	gold_line.color = Color("d9a441")
	popup.add_child(gold_line)
	var red_line := ColorRect.new()
	red_line.position = Vector2(0, 2)
	red_line.size = Vector2(560, 3)
	red_line.color = Color("c94a55")
	popup.add_child(red_line)

	var title: Label = Label.new()
	title.text = "彩票开奖"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("96353e"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(20, 16)
	title.size = Vector2(520, 34)
	popup.add_child(title)

	var tickets_lbl := Label.new()
	tickets_lbl.text = "本期彩票（%d张）：%s" % [ticket_texts.size(), held_text]
	tickets_lbl.position = Vector2(24, 54)
	tickets_lbl.size = Vector2(512, 42)
	tickets_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tickets_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tickets_lbl.add_theme_font_size_override("font_size", 12)
	tickets_lbl.add_theme_color_override("font_color", Color("746672"))
	popup.add_child(tickets_lbl)

	var number_panel := Panel.new()
	number_panel.position = Vector2(84, 103)
	number_panel.size = Vector2(392, 90)
	UIUtils.shrine_panel_style(number_panel, Color("f4e8e7"), Color("d9a441"), 2)
	popup.add_child(number_panel)
	var num_lbl: Label = Label.new()
	num_lbl.text = "---"
	num_lbl.add_theme_font_size_override("font_size", 62)
	num_lbl.add_theme_color_override("font_color", Color("96353e"))
	num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num_lbl.position = Vector2(8, 0)
	num_lbl.size = Vector2(376, 88)
	number_panel.add_child(num_lbl)

	var status_lbl := Label.new()
	status_lbl.text = "号码滚动中…"
	status_lbl.position = Vector2(20, 204)
	status_lbl.size = Vector2(520, 32)
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_lbl.add_theme_font_size_override("font_size", 16)
	status_lbl.add_theme_color_override("font_color", Color("746672"))
	popup.add_child(status_lbl)

	await _animate_lottery_number(num_lbl, win_num)
	if not is_instance_valid(popup):
		return

	if hit:
		status_lbl.text = "恭喜中奖！"
		status_lbl.add_theme_font_size_override("font_size", 22)
		status_lbl.add_theme_color_override("font_color", Color("c94a55"))

		var rewards: Label = Label.new()
		var jackpot_gold: int = maxi(10000, player_level * 5000)
		rewards.text = "金币 %d  ·  随机Lv.3宝石×1  ·  天命事件立即结算\n稀有装备×1  ·  史诗装备×1  ·  传说装备×1" % jackpot_gold
		rewards.add_theme_font_size_override("font_size", 13)
		rewards.add_theme_color_override("font_color", Color("a56f00"))
		rewards.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rewards.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rewards.position = Vector2(20, 245)
		rewards.size = Vector2(520, 64)
		popup.add_child(rewards)

		_spawn_confetti(ov)
	else:
		status_lbl.text = "未中奖，本期彩票已清空"
		status_lbl.add_theme_color_override("font_color", Color("746672"))

	var close_note := Label.new()
	close_note.text = "2.2秒后自动关闭"
	close_note.position = Vector2(20, 337)
	close_note.size = Vector2(520, 20)
	close_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_note.add_theme_font_size_override("font_size", 11)
	close_note.add_theme_color_override("font_color", Color("8f8183"))
	popup.add_child(close_note)

	var t := get_tree().create_timer(2.2)
	t.timeout.connect(func():
		if is_instance_valid(ov): ov.queue_free()
		if auto_play_enabled: _start_auto_timer()
	)


func _spawn_confetti(parent: Control) -> void:
	var particles := CPUParticles2D.new()
	particles.emitting = true
	particles.amount = 60
	particles.lifetime = 1.5
	particles.gravity = Vector2(0, 80)
	particles.initial_velocity_min = 100.0
	particles.initial_velocity_max = 300.0
	particles.spread = 180.0
	particles.position = Vector2(640, 240)
	particles.color = Color(1.0, 0.8, 0.2, 0.9)
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 6.0
	parent.add_child(particles)
	var t := get_tree().create_timer(3.0)
	t.timeout.connect(particles.queue_free)


func _animate_lottery_number(label: Label, final_number: String) -> void:
	for _spin in range(12):
		if not is_instance_valid(label):
			return
		label.text = _fmt_lottery(randi_range(0, 999))
		await get_tree().create_timer(0.07).timeout
	if is_instance_valid(label):
		label.text = final_number


## ============================================================
## 扑克牌牌型检测
## ============================================================


## 统一刷新所有属性面板（穿脱装备后调用）
func _refresh_all_stats_panels() -> void:
	_refresh_player_hp_bounds(false)
	top_bar.refresh()
	top_bar.refresh_compact_stats()
	# 如果属性面板正打开着，关闭后下次打开会显示最新值
	var sp: Node = get_node_or_null("StatsPanel")
	if sp:
		_refresh_stats_panel()


func _refresh_visible_inventory_panel() -> void:
	var inventory_panel := get_node_or_null("InventoryPanel") as Panel
	if inventory_panel:
		_refresh_item_area(inventory_panel)


func _refresh_grid_display() -> void:
	var area := get_node_or_null("MapArea")
	if not area:
		return
	var idx := player_grid_index
	var offsets: Array[int] = []
	for offset in range(-VISIBLE_BEFORE, VISIBLE_AFTER + 1):
		offsets.append(offset)
	var slot_names: Array[String] = TILE_SLOT_NAMES

	for i in range(TILE_COUNT):
		var grid_idx: int = idx + offsets[i]
		var tile = area.get_node(slot_names[i])
		if not tile:
			continue

		var info := _get_grid_info(grid_idx)
		var is_current := (i == CURRENT_TILE_SLOT)
		var clr: Color = info["clr"]
		var fill: Color = clr.lightened(0.24) if is_current else clr.lightened(0.52)
		var border: Color = Color("d9a441") if is_current else Color("ab7772")
		tile.setup(info["icon"], info["name"] + "#" + str(grid_idx), fill, border)

		# 视野外格子半透明
		var dist := absi(i - CURRENT_TILE_SLOT)
		tile.modulate.a = 1.0 if dist <= 2 else maxf(0.15, 1.0 - (dist - 2) * 0.28)

	# 主角位置更新
	var hero: TextureRect = area.get_node_or_null("HeroOnMap") as TextureRect
	if hero:
		_position_hero_on_tile(hero, CURRENT_TILE_SLOT)

	var pos_lbl: Label = area.get_node("MapStatusPanel/GridPosLabel") as Label
	if pos_lbl:
		pos_lbl.text = "当前格 " + str(idx + 1) + " / " + str(map_total_grids) + "  ·  已击败 Boss " + str(player_boss_index - 1) + " / 200"


func _get_grid_info(index: int) -> Dictionary:
	var wrapped := index % map_total_grids
	if wrapped < 0:
		wrapped += map_total_grids
	var info: Dictionary = (GRID_TYPES[map_grids[wrapped]] as Dictionary).duplicate(true)
	var building: Dictionary = construction_buildings.get(str(wrapped), {}) as Dictionary
	if not building.is_empty():
		var btype := str(building.get("type", ""))
		var labels := {"shop": "商店", "chest": "宝箱", "battle": "战斗"}
		var icons := {"shop": "商", "chest": "箱", "battle": "战"}
		info["name"] = str(labels.get(btype, "建设")) + " Lv." + str(int(building.get("level", 1)))
		info["icon"] = str(icons.get(btype, "建"))
	return info


func _on_map_tile_clicked(slot: int) -> void:
	if not _is_network_game(): return
	var grid_index := posmod(player_grid_index + slot - CURRENT_TILE_SLOT, map_total_grids)
	var building: Dictionary = construction_buildings.get(str(grid_index), {}) as Dictionary
	if building.is_empty(): return
	_show_construction_management(grid_index, {"kind": "construction", "action": "manage"})


func _generate_mock_map() -> void:
	map_grids.clear()
	var base: Array[int] = [0, 1, 5, 1, 7, 2, 1, 4, 1, 6, 5, 1, 7, 2, 1, 12, 1, 5, 1, 4, 2, 1, 7, 6, 1, 12, 1, 11]
	for i in range(map_total_grids):
		map_grids.append(base[i] if i < base.size() else GridExecutorCls.GridType.BATTLE)


## ============================================================
## 骰子花色弹窗（1秒消失）
## ============================================================
func _show_dice_popup(roll: int, suit: String) -> void:
	var old_popup := get_node_or_null("DicePopup")
	if old_popup:
		old_popup.queue_free()

	var popup := Panel.new()
	popup.name = "DicePopup"
	popup.position = Vector2(500, 170)
	popup.size = Vector2(280, 180)
	UIUtils.panel_style(popup, Color(0.12, 0.12, 0.20, 0.94))

	var num_label := Label.new()
	num_label.text = str(roll)
	num_label.add_theme_font_size_override("font_size", 56)
	num_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num_label.position = Vector2(20, 20)
	num_label.size = Vector2(120, 60)
	popup.add_child(num_label)

	var suit_label := Label.new()
	suit_label.text = suit
	suit_label.add_theme_font_size_override("font_size", 56)
	suit_label.add_theme_color_override("font_color", UIUtils.suit_color(suit))
	suit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	suit_label.position = Vector2(140, 20)
	suit_label.size = Vector2(120, 60)
	popup.add_child(suit_label)

	add_child(popup)

	var timer := get_tree().create_timer(1.0)
	timer.timeout.connect(func():
		if popup and is_instance_valid(popup):
			popup.queue_free()
	)


## 画面正中偏上，渐入上浮渐出，3秒消失，新提示顶替旧提示
func _show_float_text(text: String, clr: Color = Color.WHITE) -> void:
	if _float_text_node and is_instance_valid(_float_text_node):
		_float_text_node.queue_free()

	# 确保浮字在最上层（使用独立 CanvasLayer）
	var layer: CanvasLayer = get_node_or_null("FloatTextLayer")
	if not layer:
		layer = CanvasLayer.new()
		layer.name = "FloatTextLayer"
		layer.layer = 128  # 最高渲染层
		add_child(layer)

	var backdrop := Panel.new()
	backdrop.name = "FloatText"
	backdrop.position = Vector2(390, 270)
	backdrop.size = Vector2(500, 54)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var backdrop_style := StyleBoxFlat.new()
	backdrop_style.bg_color = Color(0.10, 0.11, 0.13, 0.92)
	backdrop_style.border_color = Color(0.82, 0.70, 0.38, 0.85)
	backdrop_style.set_border_width_all(1)
	backdrop_style.set_corner_radius_all(5)
	backdrop.add_theme_stylebox_override("panel", backdrop_style)
	var lbl: Label = Label.new()
	# Strip emoji and unsupported pictographs instead of letting the web font
	# render tofu boxes; all gameplay messages retain their Chinese/ASCII text.
	lbl.text = UIUtils.plain_text(text, "提示")
	lbl.add_theme_font_override("font", ThemeDB.fallback_font)
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.add_theme_color_override("font_color", clr)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.72))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 3)
	lbl.add_theme_constant_override("shadow_outline_size", 2)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.position = Vector2(10, 5)
	lbl.size = Vector2(480, 44)
	lbl.modulate.a = 1.0
	backdrop.add_child(lbl)
	layer.add_child(backdrop)
	_float_text_node = backdrop

	var tw := create_tween()
	tw.set_parallel(false)
	tw.tween_property(backdrop, "modulate:a", 1.0, 0.2)
	tw.tween_property(backdrop, "position:y", 225, 1.8)
	tw.parallel().tween_property(backdrop, "modulate:a", 0.0, 1.8)
	tw.tween_callback(func():
		if _float_text_node == backdrop:
			_float_text_node = null
		if is_instance_valid(backdrop):
			backdrop.queue_free()
	)


## 统计已装备中各套装的件数
func _count_equipped_suits() -> Dictionary:
	var counts: Dictionary = {}
	for ei in range(equip_instances.size()):
		var ep: Dictionary = equip_instances[ei]
		if not ep.get("equipped", false):
			continue
		var sn: String = ep.get("suit_name", "")
		if not sn.is_empty():
			counts[sn] = counts.get(sn, 0) + 1
		var extra_sn: String = ep.get("extra_suit_name", "")
		if not extra_sn.is_empty() and extra_sn != sn:
			counts[extra_sn] = counts.get(extra_sn, 0) + 1
	return counts


func _equipped_set_affix_names() -> Array[String]:
	var names: Array[String] = []
	for ep in equip_instances:
		if not bool(ep.get("equipped", false)):
			continue
		for affix in ep.get("set_affixes", []):
			var affix_name := str(affix.get("name", ""))
			if not affix_name.is_empty() and not names.has(affix_name):
				names.append(affix_name)
	return names


func _add_equipment_icon(parent: Control, eqp: Dictionary, pos: Vector2, icon_size: Vector2, fallback_font_size: int = 22) -> void:
	var icon_path := str(eqp.get("icon_path", ""))
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		var texture := load(icon_path) as Texture2D
		if texture:
			var image := TextureRect.new()
			image.texture = texture
			image.position = pos
			image.size = icon_size
			image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			image.mouse_filter = Control.MOUSE_FILTER_IGNORE
			parent.add_child(image)
			return
	var fallback := Label.new()
	fallback.text = UIUtils.safe_icon(str(eqp.get("icon", "")), "装")
	fallback.add_theme_font_size_override("font_size", fallback_font_size)
	fallback.position = pos
	fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(fallback)

func _remove_ui_node_now(node: Node) -> void:
	if not is_instance_valid(node):
		return
	var parent := node.get_parent()
	if parent:
		parent.remove_child(node)
	node.queue_free()


func _close_all_tooltips() -> void:
	_cancel_pending_detail_click()
	for node in _tooltip_nodes:
		_remove_ui_node_now(node)
	_tooltip_nodes.clear()
	_remove_ui_node_now(get_node_or_null("TooltipOverlay"))
	# Compatibility cleanup for dialogs created before they were registered.
	for node_name in ["ExpansionConfirm", "ResetConfirmDialog"]:
		_remove_ui_node_now(get_node_or_null(node_name))


func _queue_detail_click(action: Callable) -> void:
	_detail_click_generation += 1
	var generation := _detail_click_generation
	await get_tree().create_timer(DETAIL_CLICK_DELAY).timeout
	if generation == _detail_click_generation:
		action.call()


func _cancel_pending_detail_click() -> void:
	_detail_click_generation += 1


func _on_test_generate_equip() -> void:
	if _is_network_game():
		return
	var slots: Array[String] = ["weapon","armor","shoes","ring","necklace","cape","helmet","charm"]
	var slot: String = slots[randi() % slots.size()]
	var eqp: Dictionary = EquipGenCls.generate(slot, player_level)
	_add_equipment_instance(eqp)
	print("[装备测试] 生成:", EquipGenCls.full_name(eqp), "品质:", eqp["quality_name"], "孔数:", eqp["gem_slots"])
	_auto_save()


func _on_test_generate_gem() -> void:
	if _is_network_game():
		return
	var gid: int = randi_range(1, 8)
	_add_gem(gid, 1, 1)
	var gdef: Dictionary = EquipData.GEM_DEFS.get(gid, {})
	_show_float_text(UIUtils.safe_icon(str(gdef.get("icon", "")), "宝") + " " + gdef.get("name", "???") + " Lv.1", Color(1, 0.7, 0.3))


func _on_test_add_socket_tool() -> void:
	if _is_network_game():
		return
	inventory.add_item(6, 1)
	_auto_save()
	_show_float_text("获得 打孔器×1", Color(0.75, 0.25, 0.3))


## 添加宝石到背包
func _add_gem(gid: int, lv: int, cnt: int) -> void:
	for g in gem_bag:
		if g["id"] == gid and g["level"] == lv:
			g["count"] += cnt
			return
	gem_bag.append({ "id": gid, "level": lv, "count": cnt })


## 宝石合成：使用宝石卡片上的“3合1”按钮
func _synthesize_gem(gid: int, lv: int) -> bool:
	if _is_network_game():
		return await _run_network_game_command("gem/synthesize", {"gem_id": gid, "level": lv}, "宝石合成完成")
	if lv >= 10:
		_show_float_text("宝石已达到最高等级", Color(0.65, 0.45, 0.35))
		return false
	var idx: int = -1
	for i in range(gem_bag.size()):
		if gem_bag[i]["id"] == gid and gem_bag[i]["level"] == lv:
			idx = i
			break
	if idx < 0 or gem_bag[idx]["count"] < 3:
		_show_float_text("需要3颗同等级宝石才能合成", Color(1, 0.4, 0.4))
		return false
	var synth_cost: int = (lv + 1) * 500
	if player_gold < synth_cost:
		_show_float_text("金币不足，需要%d金" % synth_cost, Color(1, 0.4, 0.4))
		return false
	player_gold -= synth_cost
	gem_bag[idx]["count"] -= 3
	if gem_bag[idx]["count"] <= 0:
		gem_bag.remove_at(idx)
	_add_gem(gid, lv + 1, 1)
	_auto_save()
	top_bar.refresh()
	var gdef: Dictionary = EquipData.GEM_DEFS.get(gid, {})
	_show_float_text(UIUtils.safe_icon(str(gdef.get("icon", "")), "宝") + " 合成 → Lv." + str(lv + 1), Color(0.3, 1.0, 0.6))
	return true


func _on_test_generate_lottery() -> void:
	if _is_network_game():
		return
	if lottery_tickets.size() >= 10:
		_show_float_text("彩票已满（最多10张）", Color(1, 0.4, 0.4))
		return
	var num: int = randi_range(0, 999)
	lottery_tickets.append(num)
	_show_float_text("获得彩票 " + _fmt_lottery(num), Color(1, 0.7, 0.2))


func _fmt_lottery(num: int) -> String:
	return str(num).pad_zeros(3)


func _build_lottery_tab(area: Panel, _main_panel: Panel) -> void:
	var gap: float = 10.0
	var sy: float = gap

	var title: Label = Label.new()
	title.text = "彩票 (" + str(lottery_tickets.size()) + "/10)"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	title.position = Vector2(gap, sy)
	area.add_child(title)
	sy += 28

	if lottery_tickets.is_empty():
		var empty_lbl: Label = Label.new()
		empty_lbl.text = "暂无彩票，走到彩票格可获取"
		empty_lbl.add_theme_font_size_override("font_size", 12)
		empty_lbl.add_theme_color_override("font_color", Color(0.4, 0.45, 0.5))
		empty_lbl.position = Vector2(gap, sy + 8)
		area.add_child(empty_lbl)
		sy += 38

	for tx in range(lottery_tickets.size()):
		var row_y: float = sy + tx * 44
		if row_y > 280:
			break

		# 彩票卡片
		var card: Panel = Panel.new()
		card.position = Vector2(gap, row_y)
		card.size = Vector2(300, 38)
		var cs := StyleBoxFlat.new()
		cs.bg_color = Color("fff8f3")
		cs.border_width_left = 1; cs.border_width_right = 1
		cs.border_width_top = 1; cs.border_width_bottom = 1
		cs.border_color = Color(1.0, 0.6, 0.2, 0.5)
		cs.set_corner_radius_all(6)
		card.add_theme_stylebox_override("panel", cs)
		area.add_child(card)

		# 数字（大字）
		var num_lbl: Label = Label.new()
		num_lbl.text = _fmt_lottery(lottery_tickets[tx])
		num_lbl.add_theme_font_size_override("font_size", 28)
		num_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		num_lbl.position = Vector2(gap + 12, row_y + 2)
		area.add_child(num_lbl)

		# 编号
		var idx_lbl: Label = Label.new()
		idx_lbl.text = "#" + str(tx + 1)
		idx_lbl.add_theme_font_size_override("font_size", 9)
		idx_lbl.add_theme_color_override("font_color", Color(0.4, 0.45, 0.5))
		idx_lbl.position = Vector2(gap + 100, row_y + 4)
		area.add_child(idx_lbl)

	sy += lottery_tickets.size() * 44 + 20

	# 底部说明
	var rounds_left: int = 10 - (player_grid_index / map_total_grids) % 10
	rounds_left = maxi(1, rounds_left)
	var footer: Label = Label.new()
	footer.text = "还有 " + str(rounds_left) + " 圈开奖  |  中奖号码为开奖时生成的3位数字"
	footer.add_theme_font_size_override("font_size", 11)
	footer.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
	footer.position = Vector2(gap, sy)
	footer.size = Vector2(640, 20)
	area.add_child(footer)


func _build_gem_tab(area: Panel, main_panel: Panel) -> void:
	var title := Label.new()
	title.text = "宝石背包"
	title.position = Vector2(12, 8)
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color("96353e"))
	area.add_child(title)
	if gem_bag.is_empty():
		var empty := Label.new()
		empty.text = "暂无宝石，可从宝箱、命运事件和调试功能中获得"
		empty.position = Vector2(12, 52)
		empty.add_theme_color_override("font_color", Color("6f6264"))
		area.add_child(empty)
		return
	var sorted_gems: Array[Dictionary] = gem_bag.duplicate(true)
	sorted_gems.sort_custom(func(a: Dictionary, b: Dictionary):
		return int(a.get("id", 0)) < int(b.get("id", 0)) if int(a.get("id", 0)) != int(b.get("id", 0)) else int(a.get("level", 1)) < int(b.get("level", 1))
	)
	for i in range(sorted_gems.size()):
		var gem: Dictionary = sorted_gems[i]
		var col := i % 3
		var row := i / 3
		var x := 12.0 + col * 216.0
		var y := 42.0 + row * 102.0
		if y > 300.0: break
		var card := Panel.new()
		card.position = Vector2(x, y)
		card.size = Vector2(204, 94)
		UIUtils.shrine_panel_style(card, Color("fffdfb"), Color("d6b8b3"), 1)
		area.add_child(card)
		var defn: Dictionary = EquipData.GEM_DEFS.get(int(gem.get("id", 0)), {})
		var icon := Label.new(); icon.text = UIUtils.safe_icon(str(defn.get("icon", "")), "宝"); icon.position = Vector2(10, 9); icon.add_theme_font_size_override("font_size", 24); card.add_child(icon)
		var name := Label.new(); name.text = "%s  Lv.%d" % [defn.get("name", "宝石"), int(gem.get("level", 1))]; name.position = Vector2(46, 8); name.add_theme_font_size_override("font_size", 13); name.add_theme_color_override("font_color", Color("352e38")); card.add_child(name)
		var count := Label.new(); count.text = "持有 ×%d" % int(gem.get("count", 0)); count.position = Vector2(46, 29); count.add_theme_color_override("font_color", Color("6f6264")); card.add_child(count)
		var detail := Button.new()
		detail.text = "详情"
		detail.position = Vector2(46, 62)
		detail.size = Vector2(44, 24)
		UIUtils.btn_style_mini(detail, Color("6f4a72"))
		detail.add_theme_font_size_override("font_size", 11)
		detail.pressed.connect(func():
			_show_gem_detail(gem, defn)
		)
		card.add_child(detail)
		var synth := Button.new()
		var level := int(gem.get("level", 1))
		var gid := int(gem.get("id", 0))
		var cost := (level + 1) * 500
		synth.text = "3合1  %d金" % cost if level < 10 else "已满级"
		synth.position = Vector2(94, 62); synth.size = Vector2(102, 24)
		synth.disabled = int(gem.get("count", 0)) < 3 or level >= 10 or player_gold < cost
		UIUtils.shrine_button_style(synth, false)
		synth.pressed.connect(func():
			await _synthesize_gem(gid, level)
			if is_instance_valid(main_panel): main_panel.queue_free()
			call_deferred("_show_inventory_panel")
		)
		card.add_child(synth)


func _show_gem_detail(gem: Dictionary, defn: Dictionary) -> void:
	_close_all_tooltips()
	_ensure_overlay()
	var panel := Panel.new()
	panel.name = "GemDetail"
	panel.position = Vector2(430, 205)
	panel.size = Vector2(420, 230)
	_prepare_modal_panel(panel)
	UIUtils.shrine_panel_style(panel, Color("fff9f5"), Color("b88d89"), 2)
	_tooltip_nodes.append(panel)
	var title := Label.new()
	title.text = "%s  Lv.%d" % [str(defn.get("name", "宝石")), int(gem.get("level", 1))]
	title.position = Vector2(18, 16)
	title.size = Vector2(384, 28)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("96353e"))
	panel.add_child(title)
	var body := Label.new()
	body.text = "用途：镶嵌到装备的宝石孔，提供对应属性。\n效果：%s\n当前持有：%d 颗\n合成：3颗同种同等级宝石 + %d 金币，合成为 Lv.%d。" % [str(defn.get("desc", "暂无说明")), int(gem.get("count", 0)), (int(gem.get("level", 1)) + 1) * 500, int(gem.get("level", 1)) + 1]
	body.position = Vector2(18, 55)
	body.size = Vector2(384, 105)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 14)
	body.add_theme_color_override("font_color", Color("4f454d"))
	panel.add_child(body)
	var close := Button.new()
	close.text = "关闭"
	close.position = Vector2(165, 177)
	close.size = Vector2(90, 32)
	UIUtils.shrine_button_style(close, false)
	close.pressed.connect(_close_all_tooltips)
	panel.add_child(close)
	add_child(panel)


func _on_bag_pressed() -> void:
	_show_inventory_panel()
func _on_skill_pressed() -> void:
	_stats_tab = "skill"
	_show_stats_panel()
func _on_log_pressed() -> void:
	if not _is_network_game():
		_show_float_text("聊天仅在联网角色中开放", Color("8b7a7d"))
		return
	var existing := get_node_or_null("WorldChatPanel")
	if existing:
		existing.queue_free()
		return
	_build_world_chat_panel()


func _build_world_chat_panel() -> void:
	var panel := Panel.new()
	panel.name = "WorldChatPanel"
	panel.position = Vector2(820, 118)
	panel.size = Vector2(440, 490)
	UIUtils.shrine_panel_style(panel, Color("fff9f5"), Color("b88d89"), 2)
	add_child(panel)
	_raise_ui_panel(panel)

	var title := Label.new()
	title.text = "世界聊天"
	title.position = Vector2(18, 12)
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", Color("96353e"))
	panel.add_child(title)

	var auction := Button.new()
	auction.text = "拍卖行"
	auction.position = Vector2(282, 8)
	auction.size = Vector2(100, 30)
	UIUtils.shrine_button_style(auction, false)
	auction.pressed.connect(func():
		panel.queue_free()
		_build_auction_panel("market")
	)
	panel.add_child(auction)

	var close := Button.new()
	close.text = "✕"
	close.position = Vector2(394, 8)
	close.size = Vector2(32, 30)
	UIUtils.shrine_button_style(close, false)
	close.pressed.connect(panel.queue_free)
	panel.add_child(close)

	var history := RichTextLabel.new()
	history.name = "History"
	history.bbcode_enabled = false
	history.scroll_active = true
	history.scroll_following = true
	history.position = Vector2(16, 50)
	history.size = Vector2(408, 350)
	history.add_theme_font_size_override("normal_font_size", 14)
	history.add_theme_color_override("default_color", Color("4f454d"))
	panel.add_child(history)

	var status := Label.new()
	status.name = "Status"
	status.position = Vector2(18, 402)
	status.size = Vector2(400, 22)
	status.add_theme_font_size_override("font_size", 12)
	status.add_theme_color_override("font_color", Color("8b7a7d"))
	panel.add_child(status)

	var input := LineEdit.new()
	input.name = "Input"
	input.placeholder_text = "输入1～120个字符"
	input.max_length = 120
	input.position = Vector2(16, 430)
	input.size = Vector2(326, 42)
	panel.add_child(input)

	var send := Button.new()
	send.text = "发送"
	send.position = Vector2(350, 430)
	send.size = Vector2(74, 42)
	UIUtils.shrine_button_style(send, true)
	panel.add_child(send)
	var submit := func(_ignored: String = ""):
		var body := input.text.strip_edges()
		if body.is_empty():
			return
		if not NetworkClient.send_world_chat(body):
			status.text = "聊天连接尚未就绪"
			return
		input.clear()
		status.text = ""
	send.pressed.connect(func(): submit.call())
	input.text_submitted.connect(func(value: String): submit.call(value))
	input.grab_focus()
	_load_world_chat_history(panel)


func _build_auction_panel(initial_tab: String = "market") -> void:
	if not _is_network_game():
		_show_float_text("拍卖行仅在联网角色中开放", Color("8b7a7d"))
		return
	var old := get_node_or_null("AuctionPanel")
	if old:
		old.queue_free()
	var panel := Panel.new()
	panel.name = "AuctionPanel"
	panel.position = Vector2(145, 92)
	panel.size = Vector2(990, 550)
	UIUtils.shrine_panel_style(panel, Color("fff9f5"), Color("b88d89"), 2)
	add_child(panel)
	_raise_ui_panel(panel)

	var title := Label.new()
	title.text = "拍卖行"
	title.position = Vector2(22, 14)
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", Color("96353e"))
	panel.add_child(title)

	var close := Button.new()
	close.text = "✕"
	close.position = Vector2(940, 10)
	close.size = Vector2(34, 32)
	UIUtils.shrine_button_style(close, false)
	close.pressed.connect(panel.queue_free)
	panel.add_child(close)

	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 8)
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.position = Vector2(20, 96)
	scroll.size = Vector2(950, 410)
	scroll.add_child(content)
	panel.add_child(scroll)

	var status := Label.new()
	status.name = "Status"
	status.position = Vector2(22, 512)
	status.size = Vector2(930, 25)
	status.add_theme_color_override("font_color", Color("8b7a7d"))
	panel.add_child(status)

	var tabs := {"market": "市场", "mine": "我的订单", "sell": "上架物品"}
	var tab_x := 150.0
	for key in tabs:
		var button := Button.new()
		button.text = tabs[key]
		button.position = Vector2(tab_x, 48)
		button.size = Vector2(150, 36)
		UIUtils.shrine_button_style(button, key == initial_tab)
		button.pressed.connect(func():
			panel.queue_free()
			_build_auction_panel(key)
		)
		panel.add_child(button)
		tab_x += 164
	_load_auction_tab(panel, initial_tab)


func _clear_container(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()


func _load_auction_tab(panel: Panel, tab: String) -> void:
	var status := panel.get_node("Status") as Label
	var content := panel.get_node("Scroll/Content") as VBoxContainer
	status.text = "正在读取拍卖数据…"
	if tab == "sell":
		status.text = "每个角色最多同时上架3件，订单仓库最多30件"
		_build_auction_sell_candidates(panel, content)
		return
	var response: Dictionary
	if tab == "mine":
		response = await NetworkClient.get_my_auction_listings()
	else:
		response = await NetworkClient.get_auction_listings(100)
	if not is_instance_valid(panel):
		return
	if not response.get("ok", false):
		status.text = _network_error_message(response)
		status.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		return
	var listings: Array = response.get("listings", []) as Array
	status.text = "共 %d 条订单" % listings.size()
	if listings.is_empty():
		_add_auction_empty(content, "当前没有可显示的订单")
		return
	for raw in listings:
		_add_auction_listing_card(panel, content, raw as Dictionary, tab)


func _add_auction_empty(content: VBoxContainer, message: String) -> void:
	var label := Label.new()
	label.text = message
	label.custom_minimum_size = Vector2(920, 60)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color("8b7a7d"))
	content.add_child(label)


func _auction_item_name(listing: Dictionary) -> String:
	var item: Dictionary = listing.get("item", {}) as Dictionary
	match str(listing.get("itemKind", "")):
		"equipment": return str(item.get("name", item.get("baseName", "装备")))
		"item": return "打孔器"
		"gem":
			var defn: Dictionary = EquipData.GEM_DEFS.get(int(item.get("gemId", 0)), {})
			return "%s Lv.%d" % [defn.get("name", "宝石"), int(item.get("level", 1))]
	return "未知物品"


func _add_auction_listing_card(panel: Panel, content: VBoxContainer, listing: Dictionary, tab: String) -> void:
	var card := Panel.new()
	card.custom_minimum_size = Vector2(930, 74)
	card.size = Vector2(930, 74)
	UIUtils.shrine_panel_style(card, Color("fffdfb"), Color("d6b8b3"), 1)
	content.add_child(card)
	var row := HBoxContainer.new()
	row.position = Vector2(10, 5)
	row.size = Vector2(910, 64)
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)
	var description := Label.new()
	description.custom_minimum_size = Vector2(570, 64)
	description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	description.text = "%s  ×%d\n卖家：%s  ·  一口价：%d 金币" % [
		_auction_item_name(listing), int(listing.get("itemCount", 1)),
		str(listing.get("sellerName", "勇者")), int(listing.get("buyoutPrice", 0)),
	]
	description.add_theme_color_override("font_color", Color("4f454d"))
	row.add_child(description)
	var state_label := Label.new()
	state_label.custom_minimum_size = Vector2(120, 64)
	state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var status_names := {"active": "出售中", "sold": "已售出", "cancelled": "已取消", "expired": "已过期", "claimed": "已领取"}
	state_label.text = status_names.get(str(listing.get("status", "active")), "未知")
	state_label.add_theme_color_override("font_color", Color("4f454d"))
	row.add_child(state_label)
	var action := Button.new()
	action.custom_minimum_size = Vector2(150, 42)
	var listing_id := str(listing.get("id", ""))
	if tab == "market":
		action.text = "一口价购买"
		action.pressed.connect(func(): _auction_buy(panel, listing_id))
	else:
		var listing_status := str(listing.get("status", ""))
		if listing_status == "active":
			action.text = "取消并取回"
			action.pressed.connect(func(): _auction_cancel(panel, listing_id))
		elif listing_status in ["sold", "cancelled", "expired"]:
			action.text = "领取"
			action.pressed.connect(func(): _auction_claim(panel, listing_id))
		else:
			action.text = "已完成"
			action.disabled = true
	UIUtils.shrine_button_style(action, tab == "market")
	row.add_child(action)


func _auction_buy(panel: Panel, listing_id: String) -> void:
	var status := panel.get_node("Status") as Label
	status.text = "正在购买…"
	var response: Dictionary = await NetworkClient.buy_auction_listing(listing_id)
	if not is_instance_valid(panel): return
	if not response.get("ok", false):
		status.text = _network_error_message(response)
		return
	await _refresh_network_character_state()
	_show_float_text("购买成功，物品已收入背包", Color(0.3, 1.0, 0.6))
	panel.queue_free()
	_build_auction_panel("market")


func _auction_cancel(panel: Panel, listing_id: String) -> void:
	var status := panel.get_node("Status") as Label
	status.text = "正在取消订单…"
	var response: Dictionary = await NetworkClient.cancel_auction_listing(listing_id)
	if not is_instance_valid(panel): return
	if not response.get("ok", false):
		status.text = _network_error_message(response)
		return
	panel.queue_free()
	_build_auction_panel("mine")


func _auction_claim(panel: Panel, listing_id: String) -> void:
	var status := panel.get_node("Status") as Label
	status.text = "正在领取…"
	var response: Dictionary = await NetworkClient.claim_auction_listing(listing_id)
	if not is_instance_valid(panel): return
	if not response.get("ok", false):
		status.text = _network_error_message(response)
		return
	await _refresh_network_character_state()
	_show_float_text("领取成功", Color(0.3, 1.0, 0.6))
	panel.queue_free()
	_build_auction_panel("mine")


func _build_auction_sell_candidates(panel: Panel, content: VBoxContainer) -> void:
	var candidates := 0
	for equipment_item in equip_instances:
		var equipment_data: Dictionary = equipment_item as Dictionary
		var has_socketed_gem := false
		for gem in equipment_data.get("gems", []):
			if _gem_entry_id(gem) != 0: has_socketed_gem = true
		var eligible := (int(equipment_data.get("quality", 0)) == 4 or not str(equipment_data.get("suit_name", "")).is_empty()) \
			and not bool(equipment_data.get("locked", false)) and not bool(equipment_data.get("bound", false)) \
			and not bool(equipment_data.get("equipped", false)) and not has_socketed_gem
		if eligible and not str(equipment_data.get("server_id", "")).is_empty():
			candidates += 1
			_add_auction_sell_card(panel, content, "equipment", str(equipment_data.get("server_id", "")), 1, 1, EquipGenCls.full_name(equipment_data))
	for stack in inventory.items:
		if int(stack.get("item_id", 0)) == 6 and not bool(stack.get("bound", false)):
			candidates += 1
			_add_auction_sell_card(panel, content, "item", 6, int(stack.get("count", 0)), 1, "打孔器")
	for gem in gem_bag:
		if bool(gem.get("bound", false)) or int(gem.get("count", 0)) <= 0: continue
		candidates += 1
		var defn: Dictionary = EquipData.GEM_DEFS.get(int(gem.get("id", 0)), {})
		_add_auction_sell_card(panel, content, "gem", int(gem.get("id", 0)), int(gem.get("count", 0)), int(gem.get("level", 1)), "%s Lv.%d" % [defn.get("name", "宝石"), int(gem.get("level", 1))])
	if candidates == 0:
		_add_auction_empty(content, "没有符合条件的物品\n仅未绑定、未锁定、未镶嵌的传说/套装装备，1～10级宝石和打孔器可以上架")


func _add_auction_sell_card(panel: Panel, content: VBoxContainer, kind: String, item_id: Variant, available: int, level: int, display_name: String) -> void:
	var card := Panel.new()
	card.custom_minimum_size = Vector2(930, 72)
	card.size = Vector2(930, 72)
	UIUtils.shrine_panel_style(card, Color("fffdfb"), Color("d6b8b3"), 1)
	content.add_child(card)
	var row := HBoxContainer.new()
	row.position = Vector2(10, 5)
	row.size = Vector2(910, 62)
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var name_label := Label.new()
	name_label.text = "%s\n可上架：%d" % [display_name, available]
	name_label.custom_minimum_size = Vector2(380, 60)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", Color("4f454d"))
	row.add_child(name_label)
	var count := SpinBox.new()
	count.min_value = 1
	count.max_value = available
	count.value = 1
	count.custom_minimum_size = Vector2(90, 38)
	count.tooltip_text = "上架数量"
	row.add_child(count)
	var price := SpinBox.new()
	price.min_value = 1
	price.max_value = 9000000000000000.0
	price.value = 100
	price.step = 1
	price.custom_minimum_size = Vector2(210, 38)
	price.tooltip_text = "一口价（金币）"
	row.add_child(price)
	var duration := OptionButton.new()
	duration.add_item("8小时", 8)
	duration.add_item("12小时", 12)
	duration.add_item("24小时", 24)
	duration.select(2)
	duration.custom_minimum_size = Vector2(105, 38)
	row.add_child(duration)
	var submit := Button.new()
	submit.text = "上架"
	submit.custom_minimum_size = Vector2(90, 40)
	UIUtils.shrine_button_style(submit, true)
	submit.pressed.connect(func(): _auction_create(panel, kind, item_id, int(count.value), int(price.value), duration.get_selected_id(), level))
	row.add_child(submit)


func _auction_create(panel: Panel, kind: String, item_id: Variant, count: int, price: int, duration: int, level: int) -> void:
	var status := panel.get_node("Status") as Label
	status.text = "正在上架…"
	var response: Dictionary = await NetworkClient.create_auction_listing(kind, item_id, count, price, duration, level)
	if not is_instance_valid(panel): return
	if not response.get("ok", false):
		status.text = _network_error_message(response)
		return
	await _refresh_network_character_state()
	_show_float_text("上架成功", Color(0.3, 1.0, 0.6))
	panel.queue_free()
	_build_auction_panel("mine")


func _refresh_network_character_state() -> bool:
	var response: Dictionary = await NetworkClient.get_game_state()
	if not response.get("ok", false):
		return false
	var data: Dictionary = LoginScriptRef.server_state_to_save_data(response.get("character", {}) as Dictionary, response.get("state", {}) as Dictionary)
	_load_from_save_data(data)
	top_bar.refresh()
	top_bar.refresh_compact_stats()
	_refresh_grid_display()
	return true


func _load_world_chat_history(panel: Panel) -> void:
	var response: Dictionary = await NetworkClient.get_world_chat(50)
	if not is_instance_valid(panel):
		return
	if not response.get("ok", false):
		var status := panel.get_node_or_null("Status") as Label
		if status:
			status.text = _network_error_message(response)
		return
	var history := panel.get_node_or_null("History") as RichTextLabel
	if not history:
		return
	history.clear()
	for raw in response.get("messages", []):
		_append_world_chat_message(history, raw as Dictionary)


func _append_world_chat_message(history: RichTextLabel, message: Dictionary) -> void:
	var sender_value: Variant = message.get("senderName")
	var sender := UIUtils.plain_text("系统" if sender_value == null or str(sender_value).is_empty() else str(sender_value), "系统")
	var body := UIUtils.plain_text(str(message.get("body", "")), "")
	history.add_text("[%s] %s\n" % [sender, body])
	history.scroll_to_line(maxi(0, history.get_line_count() - 1))


func _on_world_chat_message(message: Dictionary) -> void:
	var history := get_node_or_null("WorldChatPanel/History") as RichTextLabel
	if history:
		_append_world_chat_message(history, message)


func _on_world_chat_error(message: String) -> void:
	var status := get_node_or_null("WorldChatPanel/Status") as Label
	if status:
		status.text = message
	else:
		_show_float_text(message, Color(1.0, 0.4, 0.35))


func _on_settings_pressed()-> void:
	_auto_save()
	if get_tree():
		get_tree().change_scene_to_file("res://scenes/login.tscn" if _is_network_game() else "res://scenes/select_slot.tscn")


## ============ 背包 UI 面板 (重制版) ============
var _inv_tab: String = "equip"   # "consume" | "equip"
var _inv_filter_quality: Array[int] = []   # 空=全部, 选中多个
var _inv_filter_slot: Array[int] = []       # 空=全部, 选中多个
var _equip_page: int = 0

## 洗点确认弹窗
func _show_reset_confirm() -> void:
	if get_node_or_null("ResetConfirmDialog"):
		return

	var cost: int = player_level * 200
	var total_used: int = player_stat_atk + player_stat_def + player_stat_spd + player_stat_luk
	if total_used <= 0:
		_show_float_text("没有已分配的属性点需要重置", Color(0.6, 0.6, 0.7))
		return
	if player_gold < cost:
		_show_float_text("金币不足！洗点需要 " + str(cost) + " 金", Color(1.0, 0.3, 0.3))
		return

	# 遮罩（由 _close_all_tooltips 统一清理）
	_ensure_overlay()

	var dialog: Panel = Panel.new()
	dialog.name = "ResetConfirmDialog"
	dialog.position = Vector2(340, 280)
	dialog.size = Vector2(360, 180)
	_prepare_modal_panel(dialog)
	UIUtils.shrine_panel_style(dialog, Color("fff9f5"), Color("b88d89"), 2)
	_tooltip_nodes.append(dialog)

	var title: Label = Label.new()
	title.text = "🔄 洗点确认"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("96353e"))
	title.position = Vector2(20, 16)
	dialog.add_child(title)

	var body: Label = Label.new()
	body.text = "重置全部 " + str(total_used) + " 点自由属性点\n消耗金币: " + str(cost) + " 金"
	body.add_theme_font_size_override("font_size", 14)
	body.add_theme_color_override("font_color", Color("4f454d"))
	body.position = Vector2(20, 52)
	dialog.add_child(body)

	var confirm_btn: Button = Button.new()
	confirm_btn.text = "确认洗点"
	confirm_btn.position = Vector2(60, 120)
	confirm_btn.size = Vector2(100, 36)
	UIUtils.shrine_button_style(confirm_btn, true)
	confirm_btn.pressed.connect(func():
		_reset_stats()
		_close_all_tooltips()
	)
	dialog.add_child(confirm_btn)

	var cancel_btn: Button = Button.new()
	cancel_btn.text = "取消"
	cancel_btn.position = Vector2(200, 120)
	cancel_btn.size = Vector2(80, 36)
	UIUtils.shrine_button_style(cancel_btn, false)
	cancel_btn.pressed.connect(_close_all_tooltips)
	dialog.add_child(cancel_btn)

	add_child(dialog)


## ============================================================
## 第三部分续 — 背包面板
## ============================================================
func _show_inventory_panel() -> void:
	# queue_free 要到帧末才生效；先移出场景树，避免刷新时叠出多个同名面板。
	var old: Node = get_node_or_null("InventoryPanel")
	if old and is_instance_valid(old):
		remove_child(old)
		old.queue_free()
	_auto_save()
	_build_inventory_panel()


func _raise_ui_panel(panel: CanvasItem) -> void:
	# Ordinary windows and their contents all stay at z=0. Scene-tree order then
	# keeps every child inside its own window's stacking context: moving a window
	# to the front moves the complete subtree, without a child leaking through a
	# newer sibling window.
	panel.z_index = 0
	panel.move_to_front()


func _prepare_modal_panel(panel: Control) -> void:
	# TooltipOverlay is z=100. Every blocking dialog must be one level above it.
	panel.z_index = 101
	panel.mouse_filter = Control.MOUSE_FILTER_STOP


func _build_inventory_panel() -> void:

	var panel: Panel = Panel.new()
	panel.name = "InventoryPanel"
	panel.position = Vector2(140, 60)
	panel.size = Vector2(1000, 550)
	UIUtils.shrine_panel_style(panel, Color("fff9f5"), Color("b88d89"), 2)

	# 标题
	var title: Label = Label.new()
	title.name = "InventoryTitle"
	var used_capacity: int = equip_instances.size() if _inv_tab == "equip" else inventory.get_slot_count()
	var shown_capacity: int = equip_capacity if _inv_tab == "equip" else inventory.capacity
	var capacity_maxed: bool = equip_capacity >= EquipmentRulesCls.EQUIP_CAPACITY_MAX if _inv_tab == "equip" else inventory.is_expansion_maxed()
	title.text = "宝石背包  |  金币 %d" % player_gold if _inv_tab == "gem" else "背包 (%d/%d%s)  |  金币 %d  |  精华 %d" % [used_capacity, shown_capacity, "·满" if capacity_maxed else "", player_gold, dismantle_essence]
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("96353e"))
	title.position = Vector2(20, 10)
	panel.add_child(title)

	# 分页按钮（标签风格）
	var tabs := [
		{ "id": "consume", "text": "消耗品" },
		{ "id": "equip",   "text": "装    备" },
		{ "id": "gem",     "text": "宝    石" },
		{ "id": "lottery", "text": "彩    票" },
	]
	var inventory_tabs: Array[Button] = []
	for ti in range(tabs.size()):
		var tb: Button = Button.new()
		tb.text = tabs[ti]["text"]
		tb.position = Vector2(324 + ti * 104, 59)
		tb.size = Vector2(96, 34)
		tb.add_theme_font_size_override("font_size", 16)
		var is_tab_active: bool = (_inv_tab == tabs[ti]["id"])
		if is_tab_active:
			var active_tab := StyleBoxFlat.new()
			active_tab.bg_color = Color("fffdfb")
			active_tab.border_width_left = 2; active_tab.border_width_right = 2
			active_tab.border_width_top = 2; active_tab.border_width_bottom = 0
			active_tab.border_color = Color("c94a55")
			active_tab.corner_radius_top_left = 5; active_tab.corner_radius_top_right = 5
			tb.add_theme_stylebox_override("normal", active_tab)
			tb.add_theme_stylebox_override("hover", active_tab)
			tb.add_theme_stylebox_override("pressed", active_tab)
			UIUtils.set_button_text_color(tb, Color("5f5557"))
		else:
			UIUtils.shrine_button_style(tb, false)
			UIUtils.set_button_text_color(tb, Color("6f6264"))
		tb.flat = false
		var tid: String = tabs[ti]["id"]
		tb.pressed.connect(func():
			if _inv_tab == tid:
				return
			_inv_tab = tid
			_equip_page = 0
			_show_inventory_panel()
		)
		tb.set_meta("tab_id", tid)
		panel.add_child(tb)
		inventory_tabs.append(tb)

	# 装备栏（左侧）
	var equip_panel: Panel = Panel.new()
	equip_panel.position = Vector2(16, 92)
	equip_panel.size = Vector2(280, 390)
	UIUtils.shrine_panel_style(equip_panel, Color("fffdfb"), Color("d6b8b3"), 1)
	panel.add_child(equip_panel)

	var equip_title: Label = Label.new()
	equip_title.text = "装备栏"
	equip_title.add_theme_font_size_override("font_size", 14)
	equip_title.add_theme_color_override("font_color", Color("96353e"))
	equip_title.position = Vector2(10, 8)
	equip_panel.add_child(equip_title)

	var stat_btn: Button = Button.new()
	stat_btn.text = "?"
	stat_btn.position = Vector2(70, 4)
	stat_btn.size = Vector2(26, 22)
	UIUtils.btn_style_mini(stat_btn, Color(0.15, 0.22, 0.38))
	stat_btn.pressed.connect(_show_stats_panel)
	equip_panel.add_child(stat_btn)

	# 2列布局：左列 4 个，右列 4 个
	var cols2: Array[Array] = [
		[{ "name": "weapon",   "label": "武器" }, { "name": "armor",    "label": "防具" }],
		[{ "name": "shoes",    "label": "鞋子" }, { "name": "ring",     "label": "戒指" }],
		[{ "name": "necklace", "label": "项链" }, { "name": "cape",     "label": "披风" }],
		[{ "name": "helmet",   "label": "头盔" }, { "name": "charm",    "label": "护符" }],
	]
	var icon_s: float = 48.0
	var col_x: Array[float] = [12.0, 150.0]
	var row_start: float = 38.0
	var row_h2: float = 84.0

	for ri in range(cols2.size()):
		for ci in range(2):
			var es: Dictionary = cols2[ri][ci]
			var rx: float = col_x[ci]
			var ry: float = row_start + ri * row_h2

			# 标签
			var eq_lbl: Label = Label.new()
			eq_lbl.text = es["label"]
			eq_lbl.add_theme_font_size_override("font_size", 11)
			eq_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
			eq_lbl.position = Vector2(rx, ry)
			equip_panel.add_child(eq_lbl)

			# 装备槽底板；空槽保持轻量占位，避免出现突兀的深色方块。
			var frame_p: Panel = Panel.new()
			frame_p.position = Vector2(rx, ry + 16)
			frame_p.size = Vector2(icon_s + 2, icon_s + 2)
			frame_p.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var fb := StyleBoxFlat.new()
			fb.bg_color = Color("fff9f6")
			fb.border_width_left = 1; fb.border_width_right = 1
			fb.border_width_top = 1; fb.border_width_bottom = 1
			fb.border_color = Color("c9aaa8")
			fb.corner_radius_top_left = 3; fb.corner_radius_top_right = 3
			fb.corner_radius_bottom_left = 3; fb.corner_radius_bottom_right = 3
			frame_p.add_theme_stylebox_override("panel", fb)
			equip_panel.add_child(frame_p)

			var eqp: Dictionary = equipment.get_slot_item(es["name"])
			var has_equipment := _is_valid_equipment(eqp, str(es["name"]))
			if has_equipment:
				# 品质色边框
				var qclr: Color = UIUtils.qcolor(eqp.get("quality", 0))
				var qb2 := StyleBoxFlat.new()
				qb2.bg_color = Color(1,1,1,0)
				qb2.border_width_left = 2; qb2.border_width_right = 2
				qb2.border_width_top = 2; qb2.border_width_bottom = 2
				qb2.border_color = qclr
				frame_p.add_theme_stylebox_override("panel", qb2)
				frame_p.remove_theme_stylebox_override("panel")
				frame_p.add_theme_stylebox_override("panel", qb2)

				_add_equipment_icon(equip_panel, eqp, Vector2(rx + 3, ry + 18), Vector2(44, 44), 26)

				# 套装/宝石摘要放在槽位右侧，避免占用槽位下方的布局空间。
				var info_x: float = rx + icon_s + 8.0
				var info_y: float = ry + 18.0
				var info_w: float = 72.0

				var suit: String = str(eqp.get("suit_name", ""))
				if not suit.is_empty():
					var suit_counts: Dictionary = _count_equipped_suits()
					var st: Label = Label.new()
					st.text = "套装 %s×%d" % [suit.substr(0, 4), int(suit_counts.get(suit, 0))]
					st.add_theme_font_size_override("font_size", 8)
					st.add_theme_color_override("font_color", Color(0.16, 0.48, 0.34))
					st.position = Vector2(info_x, info_y)
					st.size = Vector2(info_w, 16)
					st.clip_text = true
					equip_panel.add_child(st)

				var gem_s: int = int(eqp.get("gem_slots", 0))
				if gem_s > 0:
					var gem_filled: int = 0
					for gv in eqp.get("gems", []):
						if _gem_entry_id(gv) > 0: gem_filled += 1
					var gt: Label = Label.new()
					gt.text = "宝石 %d/%d" % [gem_filled, gem_s]
					gt.add_theme_font_size_override("font_size", 8)
					gt.add_theme_color_override("font_color", Color(0.45, 0.25, 0.62))
					gt.position = Vector2(info_x, info_y + (18 if not suit.is_empty() else 0))
					gt.size = Vector2(info_w, 16)
					gt.clip_text = true
					equip_panel.add_child(gt)

				# 悬停查看摘要；单击打开详情；双击快速卸下。
				var slot_btn: Button = HoverHintButton.new()
				slot_btn.flat = true
				slot_btn.position = Vector2(rx, ry + 16)
				slot_btn.size = Vector2(50, 50)
				UIUtils.btn_transparent2(slot_btn)
				var esn: String = es["name"]
				slot_btn.tooltip_text = _equipment_hover_text(eqp, esn)
				slot_btn.gui_input.connect(func(ev: InputEvent):
					if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
						slot_btn.accept_event()
						if ev.double_click:
							_cancel_pending_detail_click()
							if is_instance_valid(panel):
								panel.queue_free()
							await _on_unequip_instance(esn)
							_show_inventory_panel()
						else:
							_queue_detail_click(func():
								if not is_instance_valid(panel):
									return
								_close_all_tooltips()
								_show_equip_tooltip(eqp, -1, esn, panel)
							)
					)
				equip_panel.add_child(slot_btn)
			else:
				var empty_icons := {
					"weapon": "武", "armor": "防", "shoes": "鞋", "ring": "戒",
					"necklace": "链", "cape": "披", "helmet": "盔", "charm": "符",
				}
				var empty_icon := Label.new()
				empty_icon.text = str(empty_icons.get(str(es["name"]), "装"))
				empty_icon.position = Vector2(rx + 1, ry + 20)
				empty_icon.size = Vector2(50, 38)
				empty_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				empty_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				empty_icon.add_theme_font_size_override("font_size", 20)
				empty_icon.add_theme_color_override("font_color", Color("d9bebc"))
				empty_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
				equip_panel.add_child(empty_icon)

			# 槽位强化角标始终显示；有装备时自然叠在图标右下角。
			var slot_enhance: int = int(equipment.get_slot_enhance(str(es["name"])))
			var enhance_badge := Label.new()
			enhance_badge.name = "EnhanceBadge_" + str(es["name"])
			enhance_badge.text = "+" + str(slot_enhance)
			enhance_badge.position = Vector2(rx + 24, ry + 43)
			enhance_badge.size = Vector2(26, 20)
			enhance_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			enhance_badge.add_theme_font_size_override("font_size", 11)
			enhance_badge.add_theme_color_override("font_color", Color("ffd45c") if has_equipment else Color("96353e"))
			enhance_badge.add_theme_color_override("font_outline_color", Color("352e38"))
			enhance_badge.add_theme_constant_override("outline_size", 3 if has_equipment else 1)
			enhance_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			equip_panel.add_child(enhance_badge)

	# 道具区域（右侧）
	var item_area: Panel = Panel.new()
	item_area.name = "ItemArea"
	item_area.position = Vector2(310, 92)
	item_area.size = Vector2(674, 390)
	UIUtils.shrine_panel_style(item_area, Color("fffdfb"), Color("c94a55"), 2)
	panel.add_child(item_area)

	# 过滤 + 内容（由 _rebuild_filters 统一管理）
	_rebuild_filters(item_area, panel)
	var content_area: Panel = Panel.new()
	content_area.name = "ItemContent"
	content_area.position = Vector2(0, 56 if _inv_tab == "equip" else 0)
	content_area.size = Vector2(674, 334 if _inv_tab == "equip" else 390)
	var ca_style := StyleBoxFlat.new()
	ca_style.bg_color = Color(1,1,1,0)
	content_area.add_theme_stylebox_override("panel", ca_style)
	item_area.add_child(content_area)

	if _inv_tab == "consume":
		_build_consume_tab(content_area, panel)
	elif _inv_tab == "gem":
		_build_gem_tab(content_area, panel)
	elif _inv_tab == "lottery":
		_build_lottery_tab(content_area, panel)
	else:
		_build_equip_tab(content_area, panel)

	# 底部按钮
	var bottom_y: float = 500.0

	var enhance_btn := Button.new()
	enhance_btn.text = "槽位强化"
	enhance_btn.position = Vector2(16, bottom_y)
	enhance_btn.size = Vector2(120, 30)
	UIUtils.shrine_button_style(enhance_btn, false)
	enhance_btn.pressed.connect(_show_slot_enhance_panel)
	enhance_btn.visible = _inv_tab == "equip"
	panel.add_child(enhance_btn)

	var dismantle_btn: Button = Button.new()
	dismantle_btn.text = "分解"
	dismantle_btn.position = Vector2(900, bottom_y)
	dismantle_btn.size = Vector2(80, 30)
	UIUtils.shrine_button_style(dismantle_btn, false)
	dismantle_btn.pressed.connect(func(): _show_dismantle_panel(panel))
	dismantle_btn.visible = _inv_tab == "equip"
	panel.add_child(dismantle_btn)

	if _inv_tab == "equip":
		var expand_btn := Button.new()
		expand_btn.text = "扩容 +50"
		expand_btn.position = Vector2(650, bottom_y)
		expand_btn.size = Vector2(100, 30)
		UIUtils.shrine_button_style(expand_btn, false)
		expand_btn.disabled = equip_capacity >= EquipmentRulesCls.EQUIP_CAPACITY_MAX
		expand_btn.pressed.connect(func(): _show_expansion_confirm(panel))
		panel.add_child(expand_btn)

		var auto_btn := Button.new()
		auto_btn.text = "自动分解设置"
		auto_btn.position = Vector2(760, bottom_y)
		auto_btn.size = Vector2(130, 30)
		UIUtils.shrine_button_style(auto_btn, false)
		auto_btn.pressed.connect(_show_auto_dismantle_panel)
		panel.add_child(auto_btn)

	# 关闭
	var close_btn: Button = Button.new()
	close_btn.text = "✕ 关闭"
	close_btn.position = Vector2(910, 8)
	close_btn.size = Vector2(70, 24)
	UIUtils.shrine_button_style(close_btn, false)
	close_btn.pressed.connect(func():
		_close_all_tooltips()
		_inv_filter_quality.clear()
		_inv_filter_slot.clear()
		_equip_page = 0
		panel.queue_free()
	)
	panel.add_child(close_btn)

	# Tabs need to cover only the inventory content below them. Keeping the same
	# z-index and moving them last preserves that local order without allowing
	# them to draw through a newer top-level window such as StatsPanel.
	for tab_button in inventory_tabs:
		tab_button.move_to_front()

	add_child(panel)
	_raise_ui_panel(panel)


func _slot_enhance_cost(slot_names: Array[String], levels: int) -> int:
	var total: int = 0
	for slot_name in slot_names:
		var current: int = int(equipment.get_slot_enhance(slot_name))
		var actual_levels: int = mini(levels, EquipmentCls.MAX_SLOT_ENHANCE - current)
		for offset in range(actual_levels):
			total += (current + offset) * EquipmentCls.SLOT_ENHANCE_COST_PER_LEVEL
	return total


func _apply_slot_enhancement(slot_names: Array[String], levels: int) -> bool:
	if _is_network_game():
		return await _run_network_slot_enhancement(slot_names, levels)
	var available_levels: int = 0
	for slot_name in slot_names:
		available_levels += mini(levels, EquipmentCls.MAX_SLOT_ENHANCE - int(equipment.get_slot_enhance(slot_name)))
	if available_levels <= 0:
		_show_float_text("所选槽位已达到强化上限", Color(0.65, 0.45, 0.35))
		return false
	var cost: int = _slot_enhance_cost(slot_names, levels)
	if player_gold < cost:
		_show_float_text("金币不足，需要%d金" % cost, Color(0.9, 0.3, 0.25))
		return false
	player_gold -= cost
	for slot_name in slot_names:
		for _step in range(levels):
			if not equipment.enhance_slot(slot_name):
				break
	_refresh_player_hp_bounds(false)
	_refresh_all_stats_panels()
	top_bar.refresh()
	_auto_save()
	_show_float_text("槽位强化完成  -%d金" % cost, Color(0.75, 0.25, 0.3))
	return true


func _run_network_slot_enhancement(slot_names: Array[String], levels: int) -> bool:
	return await _run_network_game_command("equipment/enhance", {"slots": slot_names, "levels": levels}, "槽位强化完成")


func _show_slot_enhance_panel(initial_slot: String = "weapon") -> void:
	var old := get_node_or_null("SlotEnhancePanel")
	if old:
		_close_all_tooltips()
		return
	_ensure_overlay()
	var dialog := Panel.new()
	dialog.name = "SlotEnhancePanel"
	dialog.position = Vector2(315, 135)
	dialog.size = Vector2(650, 450)
	_prepare_modal_panel(dialog)
	UIUtils.shrine_panel_style(dialog, Color("fff9f5"), Color("b88d89"), 2)
	_tooltip_nodes.append(dialog)
	# Attach the shell first so a later content-refresh failure cannot make the
	# entire dialog disappear in web exports.
	add_child(dialog)
	dialog.move_to_front()
	var title := Label.new()
	title.text = "槽位强化"
	title.position = Vector2(22, 16)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("96353e"))
	dialog.add_child(title)
	var gold_label := Label.new()
	gold_label.position = Vector2(430, 19)
	gold_label.size = Vector2(190, 24)
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gold_label.add_theme_font_size_override("font_size", 15)
	gold_label.add_theme_color_override("font_color", Color("8a5a12"))
	dialog.add_child(gold_label)
	var subtitle := Label.new()
	subtitle.text = "强化永久绑定槽位，换装后等级和加成保持不变"
	subtitle.position = Vector2(22, 48)
	subtitle.add_theme_color_override("font_color", Color("6f6264"))
	dialog.add_child(subtitle)

	var slot_defs: Array[Dictionary] = [
		{"id":"weapon", "name":"武器"}, {"id":"armor", "name":"防具"},
		{"id":"shoes", "name":"鞋子"}, {"id":"ring", "name":"戒指"},
		{"id":"necklace", "name":"项链"}, {"id":"cape", "name":"披风"},
		{"id":"helmet", "name":"头盔"}, {"id":"charm", "name":"护符"},
	]
	var all_slots: Array[String] = []
	var selector := OptionButton.new()
	selector.position = Vector2(22, 84)
	selector.size = Vector2(606, 40)
	var selected_index: int = 0
	for i in range(slot_defs.size()):
		var slot_id: String = str(slot_defs[i]["id"])
		all_slots.append(slot_id)
		var level: int = int(equipment.get_slot_enhance(slot_id))
		var equipped_mark: String = "  · 已装备" if _is_valid_equipment(equipment.get_slot_item(slot_id), slot_id) else ""
		selector.add_item("%s槽位   +%d / +%d%s" % [slot_defs[i]["name"], level, EquipmentCls.MAX_SLOT_ENHANCE, equipped_mark])
		selector.set_item_metadata(i, slot_id)
		if slot_id == initial_slot:
			selected_index = i
	selector.selected = selected_index
	dialog.add_child(selector)

	var detail := Label.new()
	detail.position = Vector2(22, 140)
	detail.size = Vector2(606, 70)
	detail.add_theme_font_size_override("font_size", 14)
	detail.add_theme_color_override("font_color", Color("352e38"))
	dialog.add_child(detail)
	var selected_one := Button.new(); selected_one.position = Vector2(22, 225); selected_one.size = Vector2(290, 46); UIUtils.shrine_button_style(selected_one, true); dialog.add_child(selected_one)
	var selected_five := Button.new(); selected_five.position = Vector2(338, 225); selected_five.size = Vector2(290, 46); UIUtils.shrine_button_style(selected_five, true); dialog.add_child(selected_five)
	var all_one := Button.new(); all_one.position = Vector2(22, 292); all_one.size = Vector2(290, 46); UIUtils.shrine_button_style(all_one, false); dialog.add_child(all_one)
	var all_five := Button.new(); all_five.position = Vector2(338, 292); all_five.size = Vector2(290, 46); UIUtils.shrine_button_style(all_five, false); dialog.add_child(all_five)

	var refresh_text := func():
		var slot_id: String = str(selector.get_item_metadata(selector.selected))
		var selected_slots: Array[String] = [slot_id]
		var level: int = int(equipment.get_slot_enhance(slot_id))
		var multiplier: float = equipment.get_slot_main_multiplier(slot_id)
		detail.text = "%s槽位：+%d\n当前主属性倍率：×%.2f   每强化1级增加3%%" % [slot_defs[selector.selected]["name"], level, multiplier]
		selected_one.text = "当前槽位 +1  （%d金）" % _slot_enhance_cost(selected_slots, 1)
		selected_five.text = "当前槽位 +5  （%d金）" % _slot_enhance_cost(selected_slots, 5)
		all_one.text = "全部槽位 +1  （%d金）" % _slot_enhance_cost(all_slots, 1)
		all_five.text = "全部槽位 +5  （%d金）" % _slot_enhance_cost(all_slots, 5)
		gold_label.text = "金币：%d" % player_gold
	selector.item_selected.connect(func(_index: int): refresh_text.call())
	refresh_text.call()

	var execute := func(target_slots: Array[String], levels: int):
		if not await _apply_slot_enhancement(target_slots, levels):
			return
		if not is_instance_valid(dialog):
			return
		for i in range(slot_defs.size()):
			var slot_id: String = str(slot_defs[i]["id"])
			var level: int = int(equipment.get_slot_enhance(slot_id))
			var equipped_mark: String = "  · 已装备" if _is_valid_equipment(equipment.get_slot_item(slot_id), slot_id) else ""
			selector.set_item_text(i, "%s槽位   +%d / +%d%s" % [slot_defs[i]["name"], level, EquipmentCls.MAX_SLOT_ENHANCE, equipped_mark])
			var inventory_panel: Node = get_node_or_null("InventoryPanel")
			if inventory_panel:
				var badge: Label = inventory_panel.find_child("EnhanceBadge_" + slot_id, true, false) as Label
				if badge: badge.text = "+" + str(level)
		var inventory_title: Label = get_node_or_null("InventoryPanel/InventoryTitle") as Label
		if inventory_title:
			inventory_title.text = "背包 (%d/%d%s)  |  金币 %d  |  精华 %d" % [equip_instances.size(), equip_capacity, "·满" if equip_capacity >= EquipmentRulesCls.EQUIP_CAPACITY_MAX else "", player_gold, dismantle_essence]
		refresh_text.call()
	selected_one.pressed.connect(func():
		var target: Array[String] = [str(selector.get_item_metadata(selector.selected))]
		execute.call(target, 1)
	)
	selected_five.pressed.connect(func():
		var target: Array[String] = [str(selector.get_item_metadata(selector.selected))]
		execute.call(target, 5)
	)
	all_one.pressed.connect(func(): execute.call(all_slots, 1))
	all_five.pressed.connect(func(): execute.call(all_slots, 5))

	var close := Button.new()
	close.text = "关闭"
	close.position = Vector2(268, 382)
	close.size = Vector2(114, 38)
	UIUtils.shrine_button_style(close, false)
	close.pressed.connect(_close_all_tooltips)
	dialog.add_child(close)


func _show_auto_dismantle_panel() -> void:
	_close_all_tooltips()
	_ensure_overlay()
	var dialog := Panel.new()
	dialog.name = "AutoDismantlePanel"
	dialog.position = Vector2(155, 90)
	dialog.size = Vector2(970, 540)
	_prepare_modal_panel(dialog)
	UIUtils.shrine_panel_style(dialog, Color("fff9f5"), Color("b88d89"), 2)
	_tooltip_nodes.append(dialog)
	var title := Label.new()
	title.text = "自动分解规则"
	title.position = Vector2(20, 14)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("96353e"))
	dialog.add_child(title)
	var hint := Label.new()
	hint.text = "任意一条规则命中就自动分解；每条规则可只选一列，未选列不参与判断。"
	hint.position = Vector2(20, 45)
	hint.add_theme_color_override("font_color", Color("6f6264"))
	dialog.add_child(hint)
	var enabled := CheckBox.new()
	enabled.text = "启用自动分解"
	enabled.button_pressed = auto_dismantle_enabled
	enabled.position = Vector2(780, 14)
	enabled.add_theme_font_size_override("font_size", 14)
	enabled.add_theme_color_override("font_color", Color("352e38"))
	dialog.add_child(enabled)
	var list_area := VBoxContainer.new()
	list_area.position = Vector2(20, 84)
	list_area.size = Vector2(930, 330)
	list_area.add_theme_constant_override("separation", 8)
	dialog.add_child(list_area)
	if auto_dismantle_rules.is_empty():
		var empty := Label.new()
		empty.text = "暂无分解规则"
		empty.add_theme_font_size_override("font_size", 16)
		empty.add_theme_color_override("font_color", Color("74676b"))
		list_area.add_child(empty)
	else:
		for index in range(auto_dismantle_rules.size()):
			var row := HBoxContainer.new()
			row.custom_minimum_size = Vector2(900, 38)
			row.add_theme_constant_override("separation", 8)
			var rule_label := Label.new()
			rule_label.text = "%d. %s" % [index + 1, _auto_rule_summary(auto_dismantle_rules[index])]
			rule_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rule_label.add_theme_color_override("font_color", Color("352e38"))
			row.add_child(rule_label)
			var edit_btn := Button.new()
			edit_btn.text = "编辑"
			edit_btn.custom_minimum_size = Vector2(68, 30)
			UIUtils.btn_style_mini(edit_btn, Color(0.18, 0.30, 0.42))
			var edit_index := index
			edit_btn.pressed.connect(func():
				_close_all_tooltips()
				_show_auto_dismantle_rule_editor(edit_index)
			)
			row.add_child(edit_btn)
			var delete_btn := Button.new()
			delete_btn.text = "删除"
			delete_btn.custom_minimum_size = Vector2(68, 30)
			UIUtils.btn_style_mini(delete_btn, Color(0.35, 0.16, 0.18))
			delete_btn.pressed.connect(func():
				var next_rules: Array[Dictionary] = auto_dismantle_rules.duplicate(true)
				next_rules.remove_at(edit_index)
				await _save_auto_dismantle_rules(next_rules, enabled.button_pressed)
				_close_all_tooltips()
				_show_auto_dismantle_panel()
			)
			row.add_child(delete_btn)
			list_area.add_child(row)
	var add_btn := Button.new()
	add_btn.text = "添加规则 (%d/10)" % auto_dismantle_rules.size()
	add_btn.position = Vector2(20, 430)
	add_btn.size = Vector2(150, 38)
	add_btn.disabled = auto_dismantle_rules.size() >= 10
	UIUtils.btn_style_mini(add_btn, Color(0.12, 0.35, 0.25))
	add_btn.pressed.connect(func():
		_close_all_tooltips()
		_show_auto_dismantle_rule_editor(-1)
	)
	dialog.add_child(add_btn)
	var save_btn := Button.new()
	save_btn.text = "保存并关闭"
	save_btn.position = Vector2(690, 430)
	save_btn.size = Vector2(120, 38)
	UIUtils.btn_style_mini(save_btn, Color(0.12, 0.35, 0.25))
	save_btn.pressed.connect(func():
		await _save_auto_dismantle_rules(auto_dismantle_rules, enabled.button_pressed)
		_close_all_tooltips()
	)
	dialog.add_child(save_btn)
	var cancel := Button.new()
	cancel.text = "取消"
	cancel.position = Vector2(825, 430)
	cancel.size = Vector2(100, 38)
	UIUtils.btn_style_mini(cancel, Color(0.25, 0.18, 0.2))
	cancel.pressed.connect(_close_all_tooltips)
	dialog.add_child(cancel)
	add_child(dialog)


func _auto_rule_summary(rule: Dictionary) -> String:
	var parts: Array[String] = []
	var quality_names := ["普通", "精良", "稀有", "史诗", "传说"]
	var slot_names := ["武器", "防具", "鞋子", "戒指", "项链", "披风", "头盔", "护符"]
	var socket_names := ["0孔", "1孔", "2孔", "3孔"]
	var suit_names := ["非套装", "龙鳞", "烈焰", "冰霜", "雷霆", "疾风", "铁壁", "暗影", "自然", "引力", "星辰", "幻影", "口才", "奢侈"]
	var quality_values: Array = rule.get("qualities", [])
	if not quality_values.is_empty(): parts.append("品质=" + _auto_rule_names(quality_values, quality_names))
	var slot_values: Array = rule.get("slots", [])
	if not slot_values.is_empty():
		var names: Array[String] = []
		for value in slot_values:
			var slot_index := int(value) - 1
			if slot_index >= 0 and slot_index < slot_names.size(): names.append(slot_names[slot_index])
		parts.append("部位=" + ",".join(names))
	var affix_values: Array = rule.get("affix_names", [])
	if not affix_values.is_empty(): parts.append("词缀=" + (str(affix_values[0]) if affix_values.size() == 1 else "%d项" % affix_values.size()))
	var socket_values: Array = rule.get("initial_sockets", [])
	if not socket_values.is_empty(): parts.append("孔数=" + _auto_rule_names(socket_values, socket_names))
	var suit_values: Array = rule.get("suits", [])
	if not suit_values.is_empty(): parts.append("套装=" + _auto_rule_names(suit_values, suit_names))
	var min_count := int(rule.get("affix_min", 0))
	var max_count := int(rule.get("affix_max", 8))
	if min_count > 0 or max_count < 8: parts.append("词缀数量=%d-%d" % [min_count, max_count])
	return "；".join(parts) if not parts.is_empty() else "无条件"


func _auto_rule_names(values: Array, names: Array[String]) -> String:
	var result: Array[String] = []
	for value in values:
		if value is int or value is float:
			var index := int(value)
			if index >= 0 and index < names.size(): result.append(names[index])
		else:
			result.append(str(value))
	return ",".join(result)


func _save_auto_dismantle_rules(next_rules: Array[Dictionary], enabled: bool) -> bool:
	if _is_network_game():
		return await _run_network_game_command("equipment/auto-dismantle", {"enabled": enabled, "rules": {"rules": next_rules}}, "自动分解设置已保存")
	auto_dismantle_rules = next_rules.duplicate(true)
	auto_dismantle_enabled = enabled
	_auto_save()
	_show_float_text("自动分解设置已保存", Color(0.45, 1.0, 0.65))
	return true


func _show_auto_dismantle_rule_editor(edit_index: int = -1) -> void:
	_close_all_tooltips()
	_ensure_overlay()
	var dialog := Panel.new()
	dialog.name = "AutoDismantleRuleEditor"
	dialog.position = Vector2(120, 52)
	dialog.size = Vector2(1040, 620)
	_prepare_modal_panel(dialog)
	UIUtils.shrine_panel_style(dialog, Color("fff9f5"), Color("b88d89"), 2)
	_tooltip_nodes.append(dialog)
	var title := Label.new()
	title.text = "添加分解规则" if edit_index < 0 else "编辑分解规则"
	title.position = Vector2(20, 14)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("96353e"))
	dialog.add_child(title)
	var hint := Label.new()
	hint.text = "可只选择任意一列；选择多列时需同时满足，未选择的列不参与判断。"
	hint.position = Vector2(20, 45)
	hint.add_theme_color_override("font_color", Color("6f6264"))
	dialog.add_child(hint)
	var saved: Dictionary = {}
	if edit_index >= 0 and edit_index < auto_dismantle_rules.size(): saved = auto_dismantle_rules[edit_index].duplicate(true)
	var affix_names: Array[String] = []
	for affix in EquipGenCls.AFFIX_POOL:
		var affix_name := str(affix.get("name", ""))
		if not affix_name.is_empty(): affix_names.append(affix_name)
	var defs: Array[Dictionary] = [
		{"key":"qualities", "title":"品质", "labels":["普通","精良","稀有","史诗","传说"], "values":[0,1,2,3,4]},
		{"key":"slots", "title":"部位", "labels":["武器","防具","鞋子","戒指","项链","披风","头盔","护符"], "values":[1,2,3,4,5,6,7,8]},
		{"key":"affix_names", "title":"随机词缀", "labels":affix_names, "values":affix_names},
		{"key":"initial_sockets", "title":"初始孔数", "labels":["0孔","1孔","2孔","3孔"], "values":[0,1,2,3]},
		{"key":"suits", "title":"套装", "labels":["非套装","龙鳞","烈焰","冰霜","雷霆","疾风","铁壁","暗影","自然","引力","星辰","幻影","口才","奢侈"], "values":["none","龙鳞","烈焰","冰霜","雷霆","疾风","铁壁","暗影","自然","引力","星辰","幻影","口才","奢侈"]},
	]
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(20, 78)
	scroll.size = Vector2(1000, 405)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dialog.add_child(scroll)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	columns.custom_minimum_size = Vector2(980, 0)
	scroll.add_child(columns)
	var checks: Dictionary = {}
	for defn in defs:
		var column := VBoxContainer.new()
		column.custom_minimum_size = Vector2(184, 0)
		column.add_theme_constant_override("separation", 2)
		columns.add_child(column)
		var header := Label.new()
		header.text = str(defn["title"]) + "（不选=忽略）"
		header.add_theme_color_override("font_color", Color("4f454d"))
		column.add_child(header)
		var values: Array = defn["values"]
		var labels: Array = defn["labels"]
		var field_checks: Array[CheckBox] = []
		for oi in range(values.size()):
			var check := CheckBox.new()
			check.text = str(labels[oi])
			check.button_pressed = (values[oi] in (saved.get(defn["key"], []) as Array))
			check.add_theme_color_override("font_color", Color("352e38"))
			check.add_theme_color_override("font_hover_color", Color("4f454d"))
			check.add_theme_color_override("font_pressed_color", Color("4f454d"))
			check.add_theme_color_override("font_focus_color", Color("4f454d"))
			field_checks.append(check)
			column.add_child(check)
		checks[defn["key"]] = field_checks
	# 部位单独提供“全部”，勾选后写入全部部位值。
	var slot_all := CheckBox.new()
	slot_all.text = "全部部位"
	slot_all.button_pressed = (checks["slots"].size() > 0 and checks["slots"].all(func(item: CheckBox): return item.button_pressed))
	slot_all.add_theme_color_override("font_color", Color("16804d"))
	slot_all.toggled.connect(func(pressed: bool):
		for item in checks["slots"]: item.button_pressed = pressed
	)
	for slot_check in checks["slots"]:
		slot_check.toggled.connect(func(_pressed: bool):
			slot_all.set_pressed_no_signal((checks["slots"] as Array).all(func(item: CheckBox): return item.button_pressed))
		)
	var slot_column: Node = columns.get_child(1)
	slot_column.add_child(slot_all)
	var count_lbl := Label.new()
	count_lbl.text = "词缀数量范围（含套装词条）"
	count_lbl.position = Vector2(22, 500)
	count_lbl.add_theme_color_override("font_color", Color("4f454d"))
	dialog.add_child(count_lbl)
	var min_box := SpinBox.new()
	min_box.min_value = 0; min_box.max_value = 8; min_box.value = int(saved.get("affix_min", 0))
	min_box.position = Vector2(220, 492); min_box.size = Vector2(80, 32)
	dialog.add_child(min_box)
	var range_lbl := Label.new(); range_lbl.text = "至"; range_lbl.position = Vector2(312, 500); range_lbl.add_theme_color_override("font_color", Color("4f454d")); dialog.add_child(range_lbl)
	var max_box := SpinBox.new()
	max_box.min_value = 0; max_box.max_value = 8; max_box.value = int(saved.get("affix_max", 8))
	max_box.position = Vector2(340, 492); max_box.size = Vector2(80, 32)
	dialog.add_child(max_box)
	var save_btn := Button.new()
	save_btn.text = "保存规则"
	save_btn.position = Vector2(690, 530); save_btn.size = Vector2(120, 38)
	UIUtils.btn_style_mini(save_btn, Color(0.12, 0.35, 0.25))
	save_btn.pressed.connect(func():
		if int(min_box.value) > int(max_box.value):
			_show_float_text("词缀数量下限不能大于上限", Color(1.0, 0.45, 0.35)); return
		var next_rule: Dictionary = {"affix_min": int(min_box.value), "affix_max": int(max_box.value)}
		for defn in defs:
			var selected: Array = []
			for i in range((checks[defn["key"]] as Array).size()):
				var check: CheckBox = checks[defn["key"]][i]
				if check.button_pressed: selected.append(defn["values"][i])
			next_rule[defn["key"]] = selected
		if _auto_rule_is_empty(next_rule):
			_show_float_text("请至少选择一项分解条件", Color(1.0, 0.45, 0.35)); return
		var next_rules: Array[Dictionary] = auto_dismantle_rules.duplicate(true)
		if edit_index >= 0 and edit_index < next_rules.size(): next_rules[edit_index] = next_rule
		else: next_rules.append(next_rule)
		_close_all_tooltips()
		if await _save_auto_dismantle_rules(next_rules, auto_dismantle_enabled):
			_show_auto_dismantle_panel()
	)
	dialog.add_child(save_btn)
	var cancel := Button.new(); cancel.text = "取消"; cancel.position = Vector2(825, 530); cancel.size = Vector2(100, 38)
	UIUtils.btn_style_mini(cancel, Color(0.25, 0.18, 0.2)); cancel.pressed.connect(_close_all_tooltips); dialog.add_child(cancel)
	add_child(dialog)


func _auto_rule_is_empty(rule: Dictionary) -> bool:
	for key in ["qualities", "slots", "affix_names", "initial_sockets", "suits"]:
		if not (rule.get(key, []) as Array).is_empty(): return false
	return int(rule.get("affix_min", 0)) <= 0 and int(rule.get("affix_max", 8)) >= 8


## 刷新物品区域（不关面板）
func _restyle_tab(tb: Button, active: bool) -> void:
	if active:
		var ta := StyleBoxFlat.new()
		ta.bg_color = Color(0.15, 0.18, 0.28)
		ta.set_content_margin_all(4)
		ta.border_width_bottom = 3
		ta.border_color = Color(0.3, 0.6, 1.0)
		tb.add_theme_stylebox_override("normal", ta)
		tb.add_theme_color_override("font_color", Color("4f454d"))
	else:
		var ta2 := StyleBoxFlat.new()
		ta2.bg_color = Color(0.08, 0.09, 0.15)
		ta2.set_content_margin_all(4)
		tb.add_theme_stylebox_override("normal", ta2)
		tb.add_theme_color_override("font_color", Color(0.4, 0.45, 0.5))

func _rebuild_filters(item_area: Panel, main_panel: Panel) -> void:
	# 清除旧过滤按钮（保留 ItemContent）
	for c in item_area.get_children():
		if c.get("name") != "ItemContent":
			c.queue_free()
	if _inv_tab != "equip":
		return

	var qlabels: Array[String] = ["全部", "灰", "绿", "蓝", "紫", "橙"]
	var qclrvals: Array[Color] = [Color(0.5,0.5,0.5), Color(0.6,0.6,0.6), Color(0.2,0.8,0.2), Color(0.2,0.4,1.0), Color(0.7,0.2,1.0), Color(1.0,0.6,0.1)]
	for qi in range(qlabels.size()):
		var qb: Button = Button.new()
		qb.text = qlabels[qi]
		qb.position = Vector2(4 + qi * 52, 4)
		qb.size = Vector2(48, 22)
		qb.add_theme_font_size_override("font_size", 12)
		qb.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var qv: int = qi - 1
		var selected: bool = (qv == -1 and _inv_filter_quality.is_empty()) or _inv_filter_quality.has(qv)
		var clr: Color = qclrvals[qi]
		UIUtils.btn_style_mini(qb, clr.darkened(0.18) if selected else Color("f4e8e7"))
		UIUtils.set_button_text_color(qb, Color("5f5557") if selected else (Color("352e38") if qi == 0 else clr.darkened(0.35)))
		qb.pressed.connect(func():
			if qv == -1:
				_inv_filter_quality.clear()
			else:
				if _inv_filter_quality.has(qv):
					_inv_filter_quality.erase(qv)
				else:
					_inv_filter_quality.append(qv)
			_rebuild_filters(item_area, main_panel)
			# 刷新内容
			var content: Node = item_area.get_node_or_null("ItemContent")
			if content:
				for c2 in content.get_children():
					c2.queue_free()
				if _inv_tab == "consume":
					_build_consume_tab(content, main_panel)
				elif _inv_tab == "gem":
					_build_gem_tab(content, main_panel)
				else:
					_build_equip_tab(content, main_panel)
		)
		item_area.add_child(qb)

	# 部位过滤（仅装备页显示）
	if _inv_tab == "equip":
		var slabels: Array[String] = ["全部", "武器", "防具", "鞋子", "戒指", "项链", "披风", "头盔", "护符"]
		for si in range(slabels.size()):
			var sb: Button = Button.new()
			sb.text = slabels[si]
			sb.position = Vector2(4 + si * 52, 32)
			sb.size = Vector2(48, 20)
			sb.add_theme_font_size_override("font_size", 12)
			sb.alignment = HORIZONTAL_ALIGNMENT_LEFT
			# slot_type_id 使用 1~8；旧写法 si-1 会把“鞋子”错映射到防具。
			var sv: int = si if si > 0 else -1
			var ssel: bool = (sv == -1 and _inv_filter_slot.is_empty()) or _inv_filter_slot.has(sv)
			UIUtils.btn_style_mini(sb, Color("c94a55") if ssel else Color("f4e8e7"))
			UIUtils.set_button_text_color(sb, Color("5f5557") if ssel else Color("352e38"))
			sb.pressed.connect(func():
				if sv == -1:
					_inv_filter_slot.clear()
				else:
					if _inv_filter_slot.has(sv):
						_inv_filter_slot.erase(sv)
					else:
						_inv_filter_slot.append(sv)
				_rebuild_filters(item_area, main_panel)
				var content2: Node = item_area.get_node_or_null("ItemContent")
				if content2:
					for c3 in content2.get_children():
						c3.queue_free()
					_build_equip_tab(content2, main_panel)
			)
			item_area.add_child(sb)


func _refresh_item_area(main_panel: Panel) -> void:
	var item_area: Panel = main_panel.get_node_or_null("ItemArea") as Panel
	if not item_area:
		return
	# 重建过滤按钮（部位筛选仅装备页显示）
	_rebuild_filters(item_area, main_panel)

	var content: Node = item_area.get_node_or_null("ItemContent")
	if not content:
		return
	for c in content.get_children():
		c.queue_free()
	if _inv_tab == "consume":
		_build_consume_tab(content, main_panel)
	elif _inv_tab == "gem":
		_build_gem_tab(content, main_panel)
	elif _inv_tab == "lottery":
		_build_lottery_tab(content, main_panel)
	else:
		_build_equip_tab(content, main_panel)


## 背包扩容确认弹窗
func _show_expansion_confirm(main_panel: Panel) -> void:
	var is_equip := _inv_tab == "equip"
	var cost: int = EquipmentRulesCls.EQUIP_EXPANSION_COSTS[equip_expansion_count] if is_equip and equip_expansion_count < EquipmentRulesCls.EQUIP_EXPANSION_COSTS.size() else inventory.get_next_expansion_cost()
	if is_equip and equip_capacity >= EquipmentRulesCls.EQUIP_CAPACITY_MAX:
		cost = -1
	if cost < 0:
		_show_float_text("背包已达到最大容量", Color(0.6, 0.6, 0.7))
		return

	# 避免重复弹窗
	if get_node_or_null("ExpansionConfirm"):
		return

	# 遮罩（已有 overlay 不重复创建，由 _close_all_tooltips 统一清理）
	_ensure_overlay()

	var dialog: Panel = Panel.new()
	dialog.name = "ExpansionConfirm"
	dialog.position = Vector2(340, 280)
	dialog.size = Vector2(360, 180)
	_prepare_modal_panel(dialog)
	UIUtils.shrine_panel_style(dialog, Color("fff9f5"), Color("b88d89"), 2)
	_tooltip_nodes.append(dialog)

	var title: Label = Label.new()
	title.text = "📦 背包扩容"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("96353e"))
	title.position = Vector2(20, 16)
	dialog.add_child(title)

	var body: Label = Label.new()
	var current_cap: int = equip_capacity if is_equip else inventory.capacity
	var expand_size: int = EquipmentRulesCls.EQUIP_EXPAND_SIZE if is_equip else InventoryCls.SLOTS_PER_EXPAND
	var new_cap: int = current_cap + expand_size
	body.text = "扩容 +%d 格\n当前: %d → %d 格\n消耗金币: %d" % [expand_size, current_cap, new_cap, cost]
	body.add_theme_font_size_override("font_size", 14)
	body.add_theme_color_override("font_color", Color("4f454d"))
	body.position = Vector2(20, 52)
	dialog.add_child(body)

	var confirm_btn: Button = Button.new()
	confirm_btn.text = "确认扩容"
	confirm_btn.position = Vector2(60, 120)
	confirm_btn.size = Vector2(100, 36)
	UIUtils.btn_style_mini(confirm_btn, Color(0.1, 0.3, 0.15))
	confirm_btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	confirm_btn.pressed.connect(func():
		if _is_network_game():
			_close_all_tooltips()
			if is_instance_valid(main_panel): main_panel.queue_free()
			await _run_network_game_command("equipment/expand" if is_equip else "inventory/expand", {}, "背包扩容成功")
			return
		# 点击确认时才检查金币
		var cost2: int = inventory.get_next_expansion_cost()
		if cost2 < 0:
			_show_float_text("背包已达到最大容量", Color(0.6, 0.6, 0.7))
		elif player_gold < cost2:
			_show_float_text("金币不足！扩容需要 " + str(cost2) + " 金", Color(1.0, 0.3, 0.3))
		else:
			player_gold -= cost2
			if is_equip:
				equip_capacity = mini(EquipmentRulesCls.EQUIP_CAPACITY_MAX, equip_capacity + EquipmentRulesCls.EQUIP_EXPAND_SIZE)
				equip_expansion_count += 1
			else:
				inventory.expand()
			_show_float_text("扩容成功！背包 %d 格" % (equip_capacity if is_equip else inventory.capacity), Color(0.3, 1.0, 0.6))
		_close_all_tooltips()
		if is_instance_valid(main_panel):
			main_panel.queue_free()
		_show_inventory_panel()
		top_bar.refresh()
	)
	dialog.add_child(confirm_btn)

	var cancel_btn: Button = Button.new()
	cancel_btn.text = "取消"
	cancel_btn.position = Vector2(200, 120)
	cancel_btn.size = Vector2(80, 36)
	UIUtils.btn_style_mini(cancel_btn, Color(0.2, 0.2, 0.3))
	cancel_btn.pressed.connect(_close_all_tooltips)
	dialog.add_child(cancel_btn)

	add_child(dialog)


func _build_consume_tab(area: Panel, main_panel: Panel) -> void:
	var cols: int = 8
	var gap: float = 8.0
	var icon_s: float = 48.0
	var row_h: float = icon_s + gap + 14  # 每行高度（含底部标签空间）

	# 计算可见范围内最多能放多少格
	var max_y: float = 370.0
	var max_visible_rows: int = int(max_y / row_h)
	var total_cells: int = mini(inventory.capacity, max_visible_rows * cols)

	# 构建格子底框样式
	var cell_style := StyleBoxFlat.new()
	cell_style.bg_color = Color("fff8f3")
	cell_style.border_width_left = 1; cell_style.border_width_right = 1
	cell_style.border_width_top = 1; cell_style.border_width_bottom = 1
	cell_style.border_color = Color("d6b8b3")

	var empty_style := StyleBoxFlat.new()
	empty_style.bg_color = Color("f7ece9")
	empty_style.border_width_left = 1; empty_style.border_width_right = 1
	empty_style.border_width_top = 1; empty_style.border_width_bottom = 1
	empty_style.border_color = Color("dfc9c5")

	for i in range(total_cells):
		var col: int = i % cols
		var row: int = i / cols
		var x: float = gap + col * (icon_s + gap)
		var y: float = gap + row * (icon_s + gap + 14)

		# 格子底框
		var cell_bg: Panel = Panel.new()
		cell_bg.position = Vector2(x, y)
		cell_bg.size = Vector2(icon_s, icon_s)
		area.add_child(cell_bg)

		var slot: Dictionary = inventory.get_slot(i)
		if slot.is_empty():
			# 空格子
			cell_bg.add_theme_stylebox_override("panel", empty_style)
			cell_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		else:
			# 有物品
			cell_bg.add_theme_stylebox_override("panel", cell_style)
			var defn: Dictionary = ItemDBRef.get_item(slot["item_id"])

			var icon: Label = Label.new()
			icon.text = UIUtils.safe_icon(str(defn.get("icon", "")), "物")
			icon.add_theme_font_size_override("font_size", 24)
			icon.add_theme_color_override("font_color", Color("4f454d"))
			icon.position = Vector2(x + 4, y + 4)
			area.add_child(icon)

			var cnt_lbl: Label = Label.new()
			cnt_lbl.text = "×" + str(slot["count"])
			cnt_lbl.add_theme_font_size_override("font_size", 9)
			cnt_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			cnt_lbl.position = Vector2(x + 2, y + icon_s - 12)
			area.add_child(cnt_lbl)

			# 点击使用
			var btn: Button = HoverHintButton.new()
			btn.flat = true
			btn.position = Vector2(x, y)
			btn.size = Vector2(icon_s, icon_s)
			btn.tooltip_text = "%s\n%s" % [str(defn.get("name", "物品")), str(defn.get("desc", ""))]
			UIUtils.btn_transparent2(btn)
			var si: int = i
			btn.pressed.connect(func():
				await _on_item_action(si)
				main_panel.queue_free()
				_show_inventory_panel()
			)
			area.add_child(btn)


func _build_equip_tab(area: Panel, main_panel: Panel) -> void:
	var cols: int = 8
	var gap: float = 8.0
	var icon_s: float = 48.0
	var row_h: float = icon_s + gap + 22
	var max_y: float = 360.0
	var max_visible_rows: int = int(max_y / row_h)
	var total_cells: int = max_visible_rows * cols

	# 空格子样式
	var empty_style := StyleBoxFlat.new()
	empty_style.bg_color = Color("f7ece9")
	empty_style.border_width_left = 1; empty_style.border_width_right = 1
	empty_style.border_width_top = 1; empty_style.border_width_bottom = 1
	empty_style.border_color = Color("dfc9c5")

	var filtered: Array[int] = []
	for j in range(equip_instances.size()):
		var eqp: Dictionary = equip_instances[j]
		if eqp.get("equipped", false) or eqp.get("locked", false):
			continue
		if not _inv_filter_quality.is_empty() and not _inv_filter_quality.has(eqp.get("quality", -1)):
			continue
		if not _inv_filter_slot.is_empty() and not _inv_filter_slot.has(eqp.get("slot_type_id", -1)):
			continue
		filtered.append(j)
	var page_size := total_cells
	var page_count: int = maxi(1, ceili(float(filtered.size()) / float(page_size)))
	_equip_page = clampi(_equip_page, 0, page_count - 1)
	var page_start := _equip_page * page_size

	for i in range(total_cells):
		var col: int = i % cols
		var row: int = i / cols
		var x: float = gap + col * (icon_s + gap)
		var y: float = gap + row * (icon_s + gap + 22)

		if y > max_y:
			break

		if page_start + i < filtered.size():
			# 有装备
			var ei: int = filtered[page_start + i]
			var eqp: Dictionary = equip_instances[ei]

			# 品质边框
			var qclr: Color = UIUtils.qcolor(eqp.get("quality", 0))
			var qborder: Panel = Panel.new()
			qborder.position = Vector2(x - 1, y - 1)
			qborder.size = Vector2(icon_s + 2, icon_s + 2)
			var qb := StyleBoxFlat.new()
			qb.bg_color = Color("fff8f3")
			qb.border_width_left = 2; qb.border_width_right = 2
			qb.border_width_top = 2; qb.border_width_bottom = 2
			qb.border_color = qclr
			qborder.add_theme_stylebox_override("panel", qb)
			area.add_child(qborder)

			# 图标
			_add_equipment_icon(area, eqp, Vector2(x + 2, y + 1), Vector2(icon_s - 4, icon_s - 4), 22)

			# 名称（品质色）
			var ename: Label = Label.new()
			var short_name: String = eqp.get("base_name", "???")
			ename.text = ("🔒" if bool(eqp.get("locked", false)) else "") + short_name.substr(0, 4)
			ename.add_theme_font_size_override("font_size", 9)
			ename.add_theme_color_override("font_color", qclr)
			ename.position = Vector2(x, y + icon_s + 2)
			ename.size = Vector2(icon_s, 12)
			ename.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			area.add_child(ename)

			# 悬停查看摘要；单击打开详情；双击快速装备。
			var btn: Button = HoverHintButton.new()
			btn.flat = true
			btn.position = Vector2(x, y)
			btn.size = Vector2(icon_s, icon_s + 16)
			UIUtils.btn_transparent2(btn)
			var eidx: int = ei
			btn.tooltip_text = _equipment_hover_text(eqp)
			btn.gui_input.connect(func(ev: InputEvent):
				if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
					btn.accept_event()
					if ev.double_click:
						_cancel_pending_detail_click()
						if is_instance_valid(main_panel):
							main_panel.queue_free()
						await _on_equip_instance(eidx)
						_show_inventory_panel()
					else:
						_queue_detail_click(func():
							if not is_instance_valid(main_panel):
								return
							_close_all_tooltips()
							var s: String = eqp.get("slot", "")
							var weq: Dictionary = equipment.get_slot_item(s)
							if _is_valid_equipment(weq, s):
								_show_compare_tooltips(eqp, weq, s, main_panel)
							else:
								_show_equip_tooltip(eqp, eidx, "", main_panel)
						)
			)
			area.add_child(btn)
		else:
			# 空格子
			var empty_frame: Panel = Panel.new()
			empty_frame.position = Vector2(x, y)
			empty_frame.size = Vector2(icon_s, icon_s)
			empty_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
			empty_frame.add_theme_stylebox_override("panel", empty_style)
			area.add_child(empty_frame)
	if page_count > 1:
		var prev := Button.new(); prev.text = "◀"; prev.position = Vector2(470, 300); prev.size = Vector2(44, 28); prev.disabled = _equip_page <= 0
		UIUtils.btn_style_mini(prev, Color(0.15, 0.2, 0.32)); prev.pressed.connect(func(): _equip_page -= 1; _refresh_item_area(main_panel)); area.add_child(prev)
		var page_lbl := Label.new(); page_lbl.text = "%d / %d" % [_equip_page + 1, page_count]; page_lbl.position = Vector2(520, 305); page_lbl.size = Vector2(70, 24); page_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; area.add_child(page_lbl)
		var next := Button.new(); next.text = "▶"; next.position = Vector2(596, 300); next.size = Vector2(44, 28); next.disabled = _equip_page >= page_count - 1
		UIUtils.btn_style_mini(next, Color(0.15, 0.2, 0.32)); next.pressed.connect(func(): _equip_page += 1; _refresh_item_area(main_panel)); area.add_child(next)


## 装备完整 tooltip
func _show_equip_tooltip(eqp: Dictionary, idx: int, slot_name: String, main_panel: Panel, x_pos: float = 340.0) -> void:
	# Empty equipment slots are decorative only and must never open a blank
	# detail dialog, even if a delayed click arrives while the panel refreshes.
	if not _is_valid_equipment(eqp, slot_name):
		return
	# 确保全屏遮罩层存在
	_ensure_overlay()

	var tip: Panel = Panel.new()
	tip.name = "EquipTooltip"
	var viewport_size := get_viewport().get_visible_rect().size
	tip.position = Vector2(clampf(x_pos, 8.0, maxf(8.0, viewport_size.x - 348.0)), clampf(122.0, 8.0, maxf(8.0, viewport_size.y - 348.0)))
	tip.size = Vector2(340, 340)
	_prepare_modal_panel(tip)
	UIUtils.shrine_panel_style(tip, Color("fff9f5"), Color("b88d89"), 2)
	_tooltip_nodes.append(tip)

	var sy: float = 8.0
	var qclr: Color = UIUtils.qcolor(eqp.get("quality", 0))
	var quality_text_colors: Array[Color] = [Color("5f5558"), Color("277a4d"), Color("275fa8"), Color("713f9c"), Color("a85b14")]
	var qtext: Color = quality_text_colors[clampi(int(eqp.get("quality", 0)), 0, quality_text_colors.size() - 1)]
	var qname: String = eqp.get("quality_name", "")

	# 品质色条
	var qbar: ColorRect = ColorRect.new()
	qbar.position = Vector2(0, 0)
	qbar.size = Vector2(340, 3)
	qbar.color = qclr
	tip.add_child(qbar)

	# 是否已装备标记
	if not slot_name.is_empty():
		var badge: Label = Label.new()
		badge.text = "【装备中】"
		badge.add_theme_font_size_override("font_size", 10)
		badge.add_theme_color_override("font_color", Color("16804d"))
		badge.position = Vector2(265, sy)
		tip.add_child(badge)

	# 名称 + 强化
	var name_lbl: Label = Label.new()
	name_lbl.text = "[" + qname + "] " + eqp.get("base_name", "???")
	var effective_slot: String = slot_name if not slot_name.is_empty() else str(eqp.get("slot", ""))
	var slot_enhance: int = int(equipment.get_slot_enhance(effective_slot))
	if slot_enhance > 0:
		name_lbl.text += "  槽位+" + str(slot_enhance)
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", qtext)
	name_lbl.position = Vector2(12, sy)
	tip.add_child(name_lbl)
	sy += 24

	# 套装信息
	var suit: String = eqp.get("suit_name", "")
	if not suit.is_empty():
		var suit_counts: Dictionary = _count_equipped_suits()
		var scnt: int = suit_counts.get(suit, 0)
		var sl: Label = Label.new()
		sl.text = "套装: " + suit + "  (" + str(scnt) + "/4)"
		if scnt >= 4:
			sl.text += "  ●已激活"
		elif scnt >= 2:
			sl.text += "  ●2件效果"
		sl.add_theme_font_size_override("font_size", 12)
		sl.add_theme_color_override("font_color", Color("287a58"))
		sl.position = Vector2(12, sy)
		tip.add_child(sl)
		sy += 18

	# 装备等级
	var lv_lbl: Label = Label.new()
	lv_lbl.text = "装备等级 Lv." + str(player_level)
	lv_lbl.add_theme_font_size_override("font_size", 11)
	lv_lbl.add_theme_color_override("font_color", Color("74676b"))
	lv_lbl.position = Vector2(12, sy)
	tip.add_child(lv_lbl)
	sy += 18

	# 分割线
	sy += 4
	var sep: ColorRect = ColorRect.new()
	sep.position = Vector2(8, sy)
	sep.size = Vector2(324, 1)
	sep.color = Color("d7bfbc")
	tip.add_child(sep)
	sy += 8

	# 主属性 + 强化收益
	var main_lbl: Label = Label.new()
	var enhanced_main := EquipmentRulesCls.enhanced_main_value(eqp, slot_enhance)
	main_lbl.text = eqp.get("main_stat", "") + ": " + str(eqp.get("main_value", 0))
	if slot_enhance > 0:
		var enhance_bonus: float = enhanced_main - float(eqp.get("main_value", 0.0))
		main_lbl.text += "  (+" + str(snapped(enhance_bonus, 0.1)) + " 强化)"
	main_lbl.add_theme_font_size_override("font_size", 13)
	main_lbl.add_theme_color_override("font_color", Color("9a6800"))
	main_lbl.position = Vector2(12, sy)
	tip.add_child(main_lbl)
	sy += 18

	# 词条
	var affixes: Array = eqp.get("affixes", [])
	for aff in affixes:
		var al: Label = Label.new()
		al.text = aff.get("name", "") + "  " + aff.get("display", "")
		al.add_theme_font_size_override("font_size", 12)
		al.add_theme_color_override("font_color", Color("4f454d"))
		al.position = Vector2(12, sy)
		tip.add_child(al)
		sy += 16

	# 套装专属词条不参与普通重铸。
	for set_aff in eqp.get("set_affixes", []):
		var sal := Label.new()
		sal.text = str(set_aff.get("name", "套装词条")) + "  " + str(set_aff.get("desc", ""))
		sal.add_theme_font_size_override("font_size", 11)
		sal.add_theme_color_override("font_color", Color("267452"))
		sal.position = Vector2(12, sy)
		tip.add_child(sal)
		sy += 16

	# 宝石
	var gem_slots: int = eqp.get("gem_slots", 0)
	var gems: Array = eqp.get("gems", [])
	if gem_slots > 0:
		sy += 2
		var gsep: ColorRect = ColorRect.new()
		gsep.position = Vector2(8, sy)
		gsep.size = Vector2(324, 1)
		gsep.color = Color("d7bfbc")
		tip.add_child(gsep)
		sy += 6

		var gtitle: Label = Label.new()
		gtitle.text = "宝石槽位 (" + str(gem_slots) + ")"
		gtitle.add_theme_font_size_override("font_size", 11)
		gtitle.add_theme_color_override("font_color", Color("704a91"))
		gtitle.position = Vector2(12, sy)
		tip.add_child(gtitle)
		sy += 18

		for k in range(gem_slots):
			var gem_entry: Variant = gems[k] if k < gems.size() else 0
			var gid: int = _gem_entry_id(gem_entry)
			var gem_level: int = _gem_entry_level(gem_entry)
			var gdef: Dictionary = EquipData.GEM_DEFS.get(gid, {})
			var gl: Button = Button.new()
			if gid > 0:
				gl.text = "%s %s Lv.%d  ·  更换 / 拆卸" % [UIUtils.safe_icon(str(gdef.get("icon", "")), "宝"), gdef.get("name", "???"), gem_level]
			else:
				gl.text = "○  空槽位  ·  点击镶嵌"
			UIUtils.shrine_button_style(gl, gid > 0)
			gl.add_theme_font_size_override("font_size", 10)
			gl.position = Vector2(16, sy)
			gl.size = Vector2(308, 24)
			var socket_index := k
			gl.pressed.connect(func():
				_show_gem_socket_panel(eqp, socket_index, main_panel)
			)
			tip.add_child(gl)
			sy += 28

	# 底部按钮跟随动态宝石列表，避免三孔装备内容重叠。
	var btn_y: float = maxf(305.0, sy + 5.0)
	tip.size.y = btn_y + 35.0
	if idx >= 0:
		var equip_btn: Button = Button.new()
		equip_btn.text = "装备"
		equip_btn.position = Vector2(12, btn_y)
		equip_btn.size = Vector2(60, 26)
		UIUtils.btn_style_mini(equip_btn, Color(0.15, 0.28, 0.45))
		var eid: int = idx
		equip_btn.pressed.connect(func():
			_close_all_tooltips()
			main_panel.queue_free()
			await _on_equip_instance(eid)
			_show_inventory_panel()
		)
		tip.add_child(equip_btn)

		var lock_btn := Button.new()
		lock_btn.text = "解锁" if bool(eqp.get("locked", false)) else "锁定"
		lock_btn.position = Vector2(82, btn_y)
		lock_btn.size = Vector2(60, 26)
		UIUtils.btn_style_mini(lock_btn, Color(0.3, 0.23, 0.1))
		lock_btn.pressed.connect(func():
			var next_locked := not bool(eqp.get("locked", false))
			if _is_network_game():
				await _run_network_game_command("equipment/lock", {"equipment_id": str(eqp.get("server_id", "")), "locked": next_locked}, "装备已锁定" if next_locked else "装备已解锁")
			else:
				eqp["locked"] = next_locked
			_close_all_tooltips()
			main_panel.queue_free()
			_show_inventory_panel()
		)
		tip.add_child(lock_btn)

		if int(eqp.get("quality", 0)) >= 3:
			var reroll_btn := Button.new()
			reroll_btn.text = "重铸"
			reroll_btn.position = Vector2(152, btn_y)
			reroll_btn.size = Vector2(60, 26)
			UIUtils.btn_style_mini(reroll_btn, Color(0.25, 0.12, 0.35))
			var reroll_idx := idx
			reroll_btn.pressed.connect(func():
				_close_all_tooltips()
				_show_reroll_panel(reroll_idx, main_panel)
			)
			tip.add_child(reroll_btn)
	elif not slot_name.is_empty():
		var unequip_btn: Button = Button.new()
		unequip_btn.text = "卸下"
		unequip_btn.position = Vector2(12, btn_y)
		unequip_btn.size = Vector2(60, 26)
		UIUtils.btn_style_mini(unequip_btn, Color(0.35, 0.12, 0.12))
		var esn: String = slot_name
		unequip_btn.pressed.connect(func():
			_close_all_tooltips()
			main_panel.queue_free()
			await _on_unequip_instance(esn)
			_show_inventory_panel()
		)
		tip.add_child(unequip_btn)
		var worn_lock_btn := Button.new()
		worn_lock_btn.text = "解锁" if bool(eqp.get("locked", false)) else "锁定"
		worn_lock_btn.position = Vector2(82, btn_y)
		worn_lock_btn.size = Vector2(60, 26)
		UIUtils.btn_style_mini(worn_lock_btn, Color(0.3, 0.23, 0.1))
		worn_lock_btn.pressed.connect(func():
			var next_locked := not bool(eqp.get("locked", false))
			if _is_network_game():
				await _run_network_game_command("equipment/lock", {"equipment_id": str(eqp.get("server_id", "")), "locked": next_locked}, "装备已锁定" if next_locked else "装备已解锁")
			else:
				eqp["locked"] = next_locked
				var original_idx := _find_instance_idx(eqp)
				if original_idx >= 0: equip_instances[original_idx]["locked"] = next_locked
			_close_all_tooltips()
			main_panel.queue_free()
			_show_inventory_panel()
		)
		tip.add_child(worn_lock_btn)

	# 装备/卸下按钮结束

	# 把 tip 放到 root 层，确保在遮罩层之上
	add_child(tip)


func _equipment_hover_text(eqp: Dictionary, slot_name: String = "") -> String:
	var lines: Array[String] = []
	var quality_name := str(eqp.get("quality_name", ""))
	var display_name := str(eqp.get("base_name", "???"))
	lines.append(("[" + quality_name + "] " if not quality_name.is_empty() else "") + display_name)
	var effective_slot := slot_name if not slot_name.is_empty() else str(eqp.get("slot", ""))
	var enhance := int(equipment.get_slot_enhance(effective_slot))
	var main_stat := str(eqp.get("main_stat", ""))
	if not main_stat.is_empty():
		var main_value := EquipmentRulesCls.enhanced_main_value(eqp, enhance)
		lines.append("%s：%s%s" % [main_stat, str(snapped(main_value, 0.1)), "  槽位+%d" % enhance if enhance > 0 else ""])
	var suit_name := str(eqp.get("suit_name", ""))
	if not suit_name.is_empty():
		lines.append("套装：" + suit_name)
	for affix in eqp.get("affixes", []).slice(0, 4):
		lines.append(str(affix.get("name", "")) + " " + str(affix.get("display", "")))
	var gem_slots := int(eqp.get("gem_slots", 0))
	if gem_slots > 0:
		var filled := 0
		for gem in eqp.get("gems", []):
			if _gem_entry_id(gem) > 0:
				filled += 1
		lines.append("宝石：%d/%d" % [filled, gem_slots])
	return "\n".join(lines)


func _ensure_overlay() -> void:
	if get_node_or_null("TooltipOverlay"):
		return
	var ov: Button = Button.new()
	ov.name = "TooltipOverlay"
	ov.flat = true
	ov.position = Vector2(0, 0)
	ov.size = get_viewport().get_visible_rect().size
	ov.z_index = 100
	var os := StyleBoxFlat.new()
	os.bg_color = Color(0, 0, 0, 0.01)
	ov.add_theme_stylebox_override("normal", os)
	ov.pressed.connect(_close_all_tooltips)
	add_child(ov)


func _gem_entry_id(entry: Variant) -> int:
	return int(entry.get("id", 0)) if entry is Dictionary else int(entry)


func _gem_entry_level(entry: Variant) -> int:
	return maxi(1, int(entry.get("level", 1))) if entry is Dictionary else 1


func _show_gem_socket_panel(eqp: Dictionary, socket_index: int, main_panel: Panel) -> void:
	_close_all_tooltips()
	_ensure_overlay()
	var dialog := Panel.new()
	dialog.name = "GemSocketDialog"
	dialog.position = Vector2(390, 145)
	dialog.size = Vector2(500, 410)
	_prepare_modal_panel(dialog)
	UIUtils.shrine_panel_style(dialog, Color("fff9f5"), Color("b88d89"), 2)
	_tooltip_nodes.append(dialog)
	add_child(dialog)

	var gems: Array = eqp.get("gems", []).duplicate(true)
	while gems.size() < int(eqp.get("gem_slots", 0)):
		gems.append(0)
	var old_entry: Variant = gems[socket_index] if socket_index < gems.size() else 0
	var old_id := _gem_entry_id(old_entry)
	var old_level := _gem_entry_level(old_entry)
	var old_def: Dictionary = EquipData.GEM_DEFS.get(old_id, {})

	var title := Label.new()
	title.text = "宝石镶嵌  ·  孔位 %d" % (socket_index + 1)
	title.position = Vector2(22, 14)
	title.size = Vector2(360, 28)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("96353e"))
	dialog.add_child(title)

	var current := Label.new()
	current.text = "当前：%s %s Lv.%d" % [UIUtils.safe_icon(str(old_def.get("icon", "")), "宝"), old_def.get("name", "空槽位"), old_level] if old_id > 0 else "当前：空槽位"
	current.position = Vector2(22, 48)
	current.size = Vector2(450, 24)
	current.add_theme_font_size_override("font_size", 12)
	current.add_theme_color_override("font_color", Color("6f6264"))
	dialog.add_child(current)

	var y := 82.0
	var available := gem_bag.duplicate(true)
	available.sort_custom(func(a: Dictionary, b: Dictionary):
		return int(a.get("level", 1)) > int(b.get("level", 1)) if int(a.get("id", 0)) == int(b.get("id", 0)) else int(a.get("id", 0)) < int(b.get("id", 0))
	)
	if available.is_empty():
		var empty := Label.new()
		empty.text = "宝石背包为空"
		empty.position = Vector2(22, y)
		empty.add_theme_color_override("font_color", Color("8b7a7d"))
		dialog.add_child(empty)
	else:
		for bag_entry in available.slice(0, 8):
			var gid := int(bag_entry.get("id", 0))
			var level := int(bag_entry.get("level", 1))
			var count := int(bag_entry.get("count", 0))
			var gdef: Dictionary = EquipData.GEM_DEFS.get(gid, {})
			var choose := Button.new()
			choose.text = "%s  %s Lv.%d   持有×%d   %s" % [UIUtils.safe_icon(str(gdef.get("icon", "")), "宝"), gdef.get("name", "宝石"), level, count, gdef.get("desc", "")]
			choose.position = Vector2(22, y)
			choose.size = Vector2(456, 32)
			UIUtils.shrine_button_style(choose, false)
			choose.add_theme_font_size_override("font_size", 11)
			choose.pressed.connect(func(): _socket_gem(eqp, socket_index, gid, level, main_panel))
			dialog.add_child(choose)
			y += 36.0

	if old_id > 0:
		var remove := Button.new()
		remove.text = "拆卸当前宝石"
		remove.position = Vector2(22, 356)
		remove.size = Vector2(150, 34)
		UIUtils.shrine_button_style(remove, true)
		remove.pressed.connect(func(): _remove_socketed_gem(eqp, socket_index, main_panel))
		dialog.add_child(remove)
	var close := Button.new()
	close.text = "关闭"
	close.position = Vector2(378, 356)
	close.size = Vector2(100, 34)
	UIUtils.shrine_button_style(close, false)
	close.pressed.connect(_close_all_tooltips)
	dialog.add_child(close)


func _socket_gem(eqp: Dictionary, socket_index: int, gid: int, level: int, main_panel: Panel) -> void:
	if _is_network_game():
		_close_all_tooltips()
		if is_instance_valid(main_panel): main_panel.queue_free()
		await _run_network_game_command("equipment/gem-socket", {"equipment_id": str(eqp.get("server_id", "")), "socket_index": socket_index, "gem_id": gid, "level": level}, "宝石已镶嵌")
		return
	var bag_index := -1
	for i in range(gem_bag.size()):
		if int(gem_bag[i].get("id", 0)) == gid and int(gem_bag[i].get("level", 1)) == level and int(gem_bag[i].get("count", 0)) > 0:
			bag_index = i
			break
	if bag_index < 0:
		_show_float_text("宝石数量不足", Color(1.0, 0.4, 0.4))
		return
	var gems: Array = eqp.get("gems", []).duplicate(true)
	while gems.size() < int(eqp.get("gem_slots", 0)):
		gems.append(0)
	var old_entry: Variant = gems[socket_index]
	var old_id := _gem_entry_id(old_entry)
	if old_id > 0:
		_add_gem(old_id, _gem_entry_level(old_entry), 1)
	gem_bag[bag_index]["count"] = int(gem_bag[bag_index].get("count", 0)) - 1
	if int(gem_bag[bag_index]["count"]) <= 0:
		gem_bag.remove_at(bag_index)
	gems[socket_index] = {"id": gid, "level": level}
	eqp["gems"] = gems
	_finish_gem_operation(main_panel, "宝石已镶嵌")


func _remove_socketed_gem(eqp: Dictionary, socket_index: int, main_panel: Panel) -> void:
	if _is_network_game():
		_close_all_tooltips()
		if is_instance_valid(main_panel): main_panel.queue_free()
		await _run_network_game_command("equipment/gem-unsocket", {"equipment_id": str(eqp.get("server_id", "")), "socket_index": socket_index}, "宝石已拆卸")
		return
	var gems: Array = eqp.get("gems", []).duplicate(true)
	if socket_index < 0 or socket_index >= gems.size():
		return
	var old_entry: Variant = gems[socket_index]
	var old_id := _gem_entry_id(old_entry)
	if old_id <= 0:
		return
	_add_gem(old_id, _gem_entry_level(old_entry), 1)
	gems[socket_index] = 0
	eqp["gems"] = gems
	_finish_gem_operation(main_panel, "宝石已拆卸")


func _finish_gem_operation(main_panel: Panel, message: String) -> void:
	_auto_save()
	_close_all_tooltips()
	if is_instance_valid(main_panel):
		main_panel.queue_free()
	call_deferred("_show_inventory_panel")
	_show_float_text(message, Color(0.45, 0.82, 0.68))


## 对比 tooltips（背包装备 + 已装备同部位）
func _show_compare_tooltips(bag_eqp: Dictionary, wear_eqp: Dictionary, slot: String, main_panel: Panel) -> void:
	# 背包的在左边，已装备的在右边
	_show_equip_tooltip(bag_eqp, _find_instance_idx(bag_eqp), "", main_panel, 320.0)
	_show_equip_tooltip(wear_eqp, -1, slot, main_panel, 670.0)


func _find_instance_idx(eqp: Dictionary) -> int:
	for i in range(equip_instances.size()):
		if equip_instances[i].get("uid", -1) == eqp.get("uid", -1):
			return i
	return -1


## 卸下装备
func _on_unequip_instance(slot_name: String) -> void:
	if _is_network_game():
		await _run_network_game_command("equipment/unequip", {"slot": slot_name}, "装备已卸下")
		return
	print("[DEBUG] _on_unequip_instance called, slot=", slot_name)
	var eqp: Dictionary = equipment.unequip(slot_name)
	if eqp.is_empty():
		print("[DEBUG] unequip returned empty for ", slot_name)
		return
	print("[DEBUG] unequipped: ", eqp.get("base_name","?"), " uid=", eqp.get("uid",-1))
	# 在 equip_instances 中找到原始条目，标记为未装备
	var uid: int = eqp.get("uid", -1)
	for i in range(equip_instances.size()):
		if equip_instances[i].get("uid", -1) == uid:
			equip_instances[i]["equipped"] = false
			print("[DEBUG] 卸下完成:", equip_instances[i].get("base_name","?"), "←", slot_name)
			# 卸下装备后刷新所有属性面板
			_refresh_all_stats_panels()
			return
	# 没找到原始条目（装备来自宝箱等直接装备的情况），追加
	eqp["equipped"] = false
	equip_instances.append(eqp)
	print("[DEBUG] 卸下: 原始条目未找到，追加")


func _on_equip_instance(idx: int) -> void:
	print("[DEBUG] _on_equip_instance called, idx=", idx, " total=", equip_instances.size())
	if idx < 0 or idx >= equip_instances.size():
		print("[DEBUG] _on_equip_instance OUT OF BOUNDS")
		return
	var eqp: Dictionary = equip_instances[idx]
	if _is_network_game():
		await _run_network_game_command("equipment/equip", {"equipment_id": str(eqp.get("server_id", ""))}, "装备已穿戴")
		return
	print("[DEBUG] eqp keys: ", eqp.keys(), " slot: ", eqp.get("slot","?"))
	var slot_name: String = eqp.get("slot", "")
	if slot_name.is_empty():
		print("[DEBUG] _on_equip_instance slot empty")
		return
	# 卸下同部位旧装备
	for i in range(equip_instances.size()):
		if i != idx and equip_instances[i].get("equipped", false) and equip_instances[i].get("slot", "") == slot_name:
			equip_instances[i]["equipped"] = false
			break
	eqp["equipped"] = true
	var ok: bool = equipment.equip_instance(slot_name, eqp)
	print("[DEBUG] equip_instance returned: ", ok, " slot: ", slot_name, " name: ", eqp.get("base_name","?"))
	# 穿戴装备后刷新所有属性面板
	_refresh_all_stats_panels()
	print("[装备] 穿戴:", EquipGenCls.full_name(eqp), "→", slot_name)


## 装备分解面板
func _show_dismantle_panel(main_panel: Panel) -> void:
	var old: Node = main_panel.get_node_or_null("DismantlePanel")
	if old:
		old.queue_free()
		return

	var dp: Panel = Panel.new()
	dp.name = "DismantlePanel"
	dp.position = Vector2(310, 92)
	dp.size = Vector2(674, 390)
	UIUtils.shrine_panel_style(dp, Color("fff9f5"), Color("b88d89"), 2)

	var dtitle: Label = Label.new()
	dtitle.text = "装备分解"
	dtitle.add_theme_font_size_override("font_size", 16)
	dtitle.add_theme_color_override("font_color", Color("96353e"))
	dtitle.position = Vector2(12, 8)
	dp.add_child(dtitle)

	# 精华说明
	var info: Label = Label.new()
	info.text = "灰+1 / 绿+3 / 蓝+8 / 紫+20 / 橙+50   宝石自动拆卸返还"
	info.add_theme_font_size_override("font_size", 10)
	info.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	info.position = Vector2(12, 25)
	dp.add_child(info)

	# 手动分解沿用背包当前的品质/部位筛选。
	var filter_labels: Array[String] = ["全部", "灰", "绿", "蓝", "紫", "橙"]
	var filter_colors: Array[Color] = [Color(0.5,0.5,0.5), Color(0.6,0.6,0.6), Color(0.2,0.8,0.2), Color(0.2,0.4,1.0), Color(0.7,0.2,1.0), Color(1.0,0.6,0.1)]
	for qi in range(filter_labels.size()):
		var quality_btn := Button.new()
		quality_btn.text = filter_labels[qi]
		quality_btn.position = Vector2(12 + qi * 52, 45)
		quality_btn.size = Vector2(48, 22)
		quality_btn.add_theme_font_size_override("font_size", 11)
		var qv: int = qi - 1
		var q_selected: bool = (qv == -1 and _inv_filter_quality.is_empty()) or _inv_filter_quality.has(qv)
		var qclr: Color = filter_colors[qi]
		UIUtils.btn_style_mini(quality_btn, qclr.darkened(0.18) if q_selected else Color("f4e8e7"))
		UIUtils.set_button_text_color(quality_btn, Color("5f5557") if q_selected else (Color("352e38") if qi == 0 else qclr.darkened(0.35)))
		quality_btn.pressed.connect(func():
			if qv == -1: _inv_filter_quality.clear()
			elif _inv_filter_quality.has(qv): _inv_filter_quality.erase(qv)
			else: _inv_filter_quality.append(qv)
			dp.queue_free()
			await dp.tree_exited
			if is_instance_valid(main_panel):
				_show_dismantle_panel(main_panel)
		)
		dp.add_child(quality_btn)

	var dismantle_slot_labels: Array[String] = ["全部", "武器", "防具", "鞋子", "戒指", "项链", "披风", "头盔", "护符"]
	for si in range(dismantle_slot_labels.size()):
		var slot_btn := Button.new()
		slot_btn.text = dismantle_slot_labels[si]
		slot_btn.position = Vector2(12 + si * 52, 70)
		slot_btn.size = Vector2(48, 22)
		slot_btn.add_theme_font_size_override("font_size", 11)
		var sv: int = si if si > 0 else -1
		var slot_selected: bool = (sv == -1 and _inv_filter_slot.is_empty()) or _inv_filter_slot.has(sv)
		UIUtils.btn_style_mini(slot_btn, Color("c94a55") if slot_selected else Color("f4e8e7"))
		UIUtils.set_button_text_color(slot_btn, Color("5f5557") if slot_selected else Color("352e38"))
		slot_btn.pressed.connect(func():
			if sv == -1: _inv_filter_slot.clear()
			elif _inv_filter_slot.has(sv): _inv_filter_slot.erase(sv)
			else: _inv_filter_slot.append(sv)
			dp.queue_free()
			await dp.tree_exited
			if is_instance_valid(main_panel):
				_show_dismantle_panel(main_panel)
		)
		dp.add_child(slot_btn)

	var dismantle_targets: Array[int] = []
	var essence_label: Label = Label.new()
	essence_label.text = "预计获得: 0 精华"
	essence_label.add_theme_font_size_override("font_size", 12)
	essence_label.add_theme_color_override("font_color", Color("96353e"))
	essence_label.position = Vector2(500, 8)
	dp.add_child(essence_label)

	# 全选/取消
	var select_all_btn: Button = Button.new()
	select_all_btn.text = "全选"
	select_all_btn.position = Vector2(500, 30)
	select_all_btn.size = Vector2(50, 22)
	UIUtils.shrine_button_style(select_all_btn, false)
	select_all_btn.add_theme_font_size_override("font_size", 10)
	dp.add_child(select_all_btn)

	var deselect_btn: Button = Button.new()
	deselect_btn.text = "取消"
	deselect_btn.position = Vector2(558, 30)
	deselect_btn.size = Vector2(50, 22)
	UIUtils.shrine_button_style(deselect_btn, false)
	deselect_btn.add_theme_font_size_override("font_size", 10)
	dp.add_child(deselect_btn)

	# 刷新精华显示
	var _update_essence := func():
		var total: int = 0
		for ei in dismantle_targets:
			if ei < 0 or ei >= equip_instances.size():
				continue
			var q: int = equip_instances[ei].get("quality", 0)
			total += [1, 3, 8, 20, 50][q]
		essence_label.text = "预计获得: " + str(total) + " 精华"

	# 装备列表
	var cols: int = 8
	var gap: float = 8.0
	var icon_s: float = 48.0
	var dy: float = 100.0
	var selection_buttons: Array[Button] = []
	var candidates: Array[int] = []
	for candidate_idx in range(equip_instances.size()):
		var candidate: Dictionary = equip_instances[candidate_idx]
		if not bool(candidate.get("equipped", false)) and not bool(candidate.get("locked", false)):
			if not _inv_filter_quality.is_empty() and not _inv_filter_quality.has(int(candidate.get("quality", -1))):
				continue
			if not _inv_filter_slot.is_empty() and not _inv_filter_slot.has(int(candidate.get("slot_type_id", -1))):
				continue
			candidates.append(candidate_idx)
	candidates.sort_custom(func(a_idx: int, b_idx: int):
		var a: Dictionary = equip_instances[a_idx]
		var b: Dictionary = equip_instances[b_idx]
		if int(a.get("quality", 0)) != int(b.get("quality", 0)):
			return int(a.get("quality", 0)) < int(b.get("quality", 0))
		if int(a.get("slot_type_id", 0)) != int(b.get("slot_type_id", 0)):
			return int(a.get("slot_type_id", 0)) < int(b.get("slot_type_id", 0))
		return int(a.get("acquired_at", 0)) < int(b.get("acquired_at", 0))
	)

	for display_idx in range(candidates.size()):
		var j: int = candidates[display_idx]
		var eqp: Dictionary = equip_instances[j]
		var col: int = display_idx % cols
		var row: int = display_idx / cols
		var x: float = gap + col * 82.0
		var y: float = dy + row * 70.0

		if y > 340:
			break

		# 品质框
		var qclr: Color = UIUtils.qcolor(eqp.get("quality", 0))
		var qp: Panel = Panel.new()
		qp.position = Vector2(x - 1, y - 1)
		qp.size = Vector2(icon_s + 2, icon_s + 2)
		var qb := StyleBoxFlat.new()
		qb.bg_color = Color(1,1,1,0)
		qb.border_width_left = 2; qb.border_width_right = 2
		qb.border_width_top = 2; qb.border_width_bottom = 2
		qb.border_color = qclr
		qp.add_theme_stylebox_override("panel", qb)
		dp.add_child(qp)

		var bg: ColorRect = ColorRect.new()
		bg.position = Vector2(x, y)
		bg.size = Vector2(icon_s, icon_s)
		bg.color = Color("fffdfb")
		dp.add_child(bg)

		_add_equipment_icon(dp, eqp, Vector2(x + 3, y + 2), Vector2(icon_s - 6, icon_s - 6), 22)

		# 名字 + 精华数
		var q: int = eqp.get("quality", 0)
		var ename: Label = Label.new()
		ename.text = eqp.get("base_name","?") + "  +" + str([1,3,8,20,50][q])
		ename.add_theme_font_size_override("font_size", 8)
		ename.add_theme_color_override("font_color", qclr)
		ename.position = Vector2(x, y + icon_s + 2)
		ename.size = Vector2(icon_s, 12)
		ename.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dp.add_child(ename)

		# 点击整格选择；选中时使用粉色描边，不再显示额外勾选框。
		var select_btn := Button.new()
		select_btn.position = Vector2(x - 3, y - 3)
		select_btn.size = Vector2(icon_s + 6, icon_s + 6)
		select_btn.toggle_mode = true
		select_btn.flat = false
		var select_normal := StyleBoxFlat.new()
		select_normal.bg_color = Color(1, 1, 1, 0)
		select_normal.set_corner_radius_all(3)
		select_btn.add_theme_stylebox_override("normal", select_normal)
		var select_hover: StyleBoxFlat = select_normal.duplicate() as StyleBoxFlat
		select_hover.border_width_left = 2; select_hover.border_width_right = 2
		select_hover.border_width_top = 2; select_hover.border_width_bottom = 2
		select_hover.border_color = Color("e79aa6")
		select_btn.add_theme_stylebox_override("hover", select_hover)
		var select_pressed: StyleBoxFlat = select_normal.duplicate() as StyleBoxFlat
		select_pressed.border_width_left = 3; select_pressed.border_width_right = 3
		select_pressed.border_width_top = 3; select_pressed.border_width_bottom = 3
		select_pressed.border_color = Color("e65f7a")
		select_btn.add_theme_stylebox_override("pressed", select_pressed)
		select_btn.add_theme_stylebox_override("hover_pressed", select_pressed)
		var ej: int = j
		select_btn.toggled.connect(func(p: bool):
			if p:
				if not dismantle_targets.has(ej): dismantle_targets.append(ej)
			else:
				dismantle_targets.erase(ej)
			_update_essence.call()
		)
		dp.add_child(select_btn)
		selection_buttons.append(select_btn)

	# 全选/取消 联动
	select_all_btn.pressed.connect(func():
		for select_btn in selection_buttons:
			select_btn.button_pressed = true
	)
	deselect_btn.pressed.connect(func():
		for select_btn in selection_buttons:
			select_btn.button_pressed = false
	)

	# 确认分解
	var confirm_btn: Button = Button.new()
	confirm_btn.text = "确认分解"
	confirm_btn.position = Vector2(12, 350)
	confirm_btn.size = Vector2(100, 30)
	UIUtils.shrine_button_style(confirm_btn, true)
	confirm_btn.pressed.connect(func():
		if dismantle_targets.is_empty():
			return
		if _is_network_game():
			var server_ids: Array[String] = []
			for target_index in dismantle_targets:
				if target_index >= 0 and target_index < equip_instances.size():
					server_ids.append(str(equip_instances[target_index].get("server_id", "")))
			dp.queue_free()
			if is_instance_valid(main_panel): main_panel.queue_free()
			await _run_network_game_command("equipment/dismantle-many", {"equipment_ids": server_ids}, "装备分解完成")
			return
		var total_essence: int = 0
		var removed: Array[int] = []
		for ei in dismantle_targets:
			if ei < 0 or ei >= equip_instances.size():
				continue
			var ep: Dictionary = equip_instances[ei]
			if bool(ep.get("locked", false)) or bool(ep.get("equipped", false)):
				continue
			total_essence += EquipmentRulesCls.essence_value(ep)
			_return_equipment_gems(ep)
			removed.append(ei)
		removed.sort()
		for k in range(removed.size() - 1, -1, -1):
			equip_instances.remove_at(removed[k])
		dismantle_essence += total_essence
		_auto_save()
		print("[装备] 分解完成, 获得精华:", total_essence)
		dp.queue_free()
		main_panel.queue_free()
		_show_inventory_panel()
	)
	dp.add_child(confirm_btn)

	main_panel.add_child(dp)


func _show_socket_select_panel(item_slot_idx: int) -> void:
	_close_all_tooltips()
	_ensure_overlay()
	var dialog := Panel.new()
	dialog.name = "SocketSelectPanel"
	dialog.position = Vector2(390, 220)
	dialog.size = Vector2(500, 220)
	_prepare_modal_panel(dialog)
	UIUtils.shrine_panel_style(dialog, Color("fff9f5"), Color("b88d89"), 2)
	_tooltip_nodes.append(dialog)
	var title := Label.new()
	title.text = "选择要打孔的装备"
	title.position = Vector2(20, 18)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("96353e"))
	dialog.add_child(title)
	var selector := OptionButton.new()
	selector.position = Vector2(20, 58)
	selector.size = Vector2(460, 38)
	var targets: Array[int] = []
	for i in range(equip_instances.size()):
		var eqp: Dictionary = equip_instances[i]
		if EquipmentRulesCls.can_socket(eqp):
			targets.append(i)
			selector.add_item("%s  [%d/%d孔]%s" % [EquipGenCls.full_name(eqp), int(eqp.get("gem_slots", 0)), EquipmentRulesCls.max_gem_slots(eqp), "（穿戴中）" if bool(eqp.get("equipped", false)) else ""])
	dialog.add_child(selector)
	var confirm := Button.new()
	confirm.text = "确认打孔"
	confirm.position = Vector2(120, 145)
	confirm.size = Vector2(110, 38)
	UIUtils.btn_style_mini(confirm, Color(0.12, 0.35, 0.28))
	confirm.pressed.connect(func():
		var selected := selector.selected
		if selected < 0 or selected >= targets.size() or item_slot_idx < 0 or inventory.get_slot(item_slot_idx).is_empty():
			return
		var target: Dictionary = equip_instances[targets[selected]]
		if not EquipmentRulesCls.can_socket(target):
			_show_float_text("该装备已无法继续打孔", Color(1.0, 0.5, 0.4))
			return
		if _is_network_game():
			_close_all_tooltips()
			await _run_network_game_command("item/use", {"item_id": 6, "equipment_id": str(target.get("server_id", ""))}, "装备打孔成功")
			return
		target["gem_slots"] = int(target.get("gem_slots", 0)) + 1
		inventory.remove_item(item_slot_idx, 1)
		_auto_save()
		_close_all_tooltips()
		_show_float_text("%s 增加1个宝石孔" % EquipGenCls.full_name(target), Color(0.45, 0.9, 1.0))
	)
	dialog.add_child(confirm)
	var cancel := Button.new()
	cancel.text = "取消"
	cancel.position = Vector2(270, 145)
	cancel.size = Vector2(90, 38)
	UIUtils.btn_style_mini(cancel, Color(0.25, 0.18, 0.2))
	cancel.pressed.connect(_close_all_tooltips)
	dialog.add_child(cancel)
	add_child(dialog)


func _show_reroll_panel(equip_idx: int, main_panel: Panel) -> void:
	if equip_idx < 0 or equip_idx >= equip_instances.size():
		return
	var eqp: Dictionary = equip_instances[equip_idx]
	if int(eqp.get("quality", 0)) < 3:
		return
	_ensure_overlay()
	var dialog := Panel.new()
	dialog.name = "RerollPanel"
	dialog.position = Vector2(390, 145)
	dialog.size = Vector2(500, 410)
	_prepare_modal_panel(dialog)
	UIUtils.shrine_panel_style(dialog, Color("fff9f5"), Color("b88d89"), 2)
	_tooltip_nodes.append(dialog)
	var title := Label.new()
	title.text = "词缀重铸 - " + EquipGenCls.full_name(eqp)
	title.position = Vector2(18, 15)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("96353e"))
	dialog.add_child(title)
	var checks: Array[CheckBox] = []
	var affixes: Array = eqp.get("affixes", [])
	for i in range(affixes.size()):
		var cb := CheckBox.new()
		var affix_text := str(affixes[i].get("name", "")) + "  " + str(affixes[i].get("display", ""))
		cb.text = "☐ 锁定  " + affix_text
		cb.position = Vector2(22, 58 + i * 38)
		cb.size = Vector2(450, 32)
		cb.add_theme_color_override("font_color", Color("352e38"))
		cb.toggled.connect(func(pressed: bool):
			cb.text = ("☑ 锁定  " if pressed else "☐ 锁定  ") + affix_text
			if pressed:
				var count := 0
				for other in checks:
					if other.button_pressed: count += 1
				if count > 2:
					cb.set_pressed_no_signal(false)
					_show_float_text("最多锁定2条词缀", Color(1.0, 0.55, 0.35))
		)
		dialog.add_child(cb)
		checks.append(cb)
	var cost_label := Label.new()
	cost_label.position = Vector2(22, 275)
	cost_label.add_theme_color_override("font_color", Color("6f4a72"))
	dialog.add_child(cost_label)
	var refresh_cost := func():
		var count := 0
		for cb in checks:
			if cb.button_pressed: count += 1
		var cost: Dictionary = EquipmentRulesCls.REROLL_COSTS[count]
		var gold_cost := int(cost["legendary_gold"] if int(eqp.get("quality", 0)) == 4 else cost["epic_gold"])
		cost_label.text = "锁定%d条：消耗 %d 精华 + %d 金币（余额：%d精华）" % [count, cost["essence"], gold_cost, dismantle_essence]
	for cb in checks:
		cb.toggled.connect(func(_pressed: bool): refresh_cost.call())
	refresh_cost.call()
	var confirm := Button.new()
	confirm.text = "确认重铸"
	confirm.position = Vector2(120, 335)
	confirm.size = Vector2(110, 38)
	UIUtils.btn_style_mini(confirm, Color(0.28, 0.12, 0.38))
	confirm.pressed.connect(func():
		var locked: Array[int] = []
		for i in range(checks.size()):
			if checks[i].button_pressed: locked.append(i)
		var cost: Dictionary = EquipmentRulesCls.REROLL_COSTS[locked.size()]
		var gold_cost := int(cost["legendary_gold"] if int(eqp.get("quality", 0)) == 4 else cost["epic_gold"])
		if _is_network_game():
			_close_all_tooltips()
			if is_instance_valid(main_panel): main_panel.queue_free()
			await _run_network_game_command("equipment/reroll", {"equipment_id": str(eqp.get("server_id", "")), "locked_indices": locked}, "词缀重铸完成")
			return
		if dismantle_essence < int(cost["essence"]) or player_gold < gold_cost:
			_show_float_text("金币或分解精华不足", Color(1.0, 0.45, 0.35))
			return
		if not EquipmentRulesCls.reroll_affixes(eqp, locked, EquipGenCls.AFFIX_POOL):
			_show_float_text("重铸失败，装备数据异常", Color(1.0, 0.45, 0.35))
			return
		dismantle_essence -= int(cost["essence"])
		player_gold -= gold_cost
		_auto_save()
		_close_all_tooltips()
		if is_instance_valid(main_panel): main_panel.queue_free()
		_show_inventory_panel()
		_show_float_text("词缀重铸完成", Color(0.45, 1.0, 0.65))
	)
	dialog.add_child(confirm)
	var cancel := Button.new()
	cancel.text = "取消"
	cancel.position = Vector2(270, 335)
	cancel.size = Vector2(90, 38)
	UIUtils.btn_style_mini(cancel, Color(0.25, 0.18, 0.2))
	cancel.pressed.connect(_close_all_tooltips)
	dialog.add_child(cancel)
	add_child(dialog)


func _on_item_action(slot_idx: int) -> void:
	const TYPE_WEAPON: int = 1
	const TYPE_ARMOR: int = 2
	const TYPE_SHOES: int = 3
	const TYPE_RING: int = 4
	const TYPE_NECKLACE: int = 5
	const TYPE_CAPE: int = 6
	const TYPE_HELMET: int = 7
	const TYPE_CHARM: int = 8

	var slot: Dictionary = inventory.get_slot(slot_idx)
	if slot.is_empty():
		return
	var defn: Dictionary = ItemDBRef.get_item(slot["item_id"])
	var itype: int = defn.get("type", 0)

	if itype >= TYPE_WEAPON and itype <= TYPE_CHARM:
		var slot_name: String = ""
		match itype:
			TYPE_WEAPON:   slot_name = "weapon"
			TYPE_ARMOR:    slot_name = "armor"
			TYPE_SHOES:    slot_name = "shoes"
			TYPE_RING:     slot_name = "ring"
			TYPE_NECKLACE: slot_name = "necklace"
			TYPE_CAPE:     slot_name = "cape"
			TYPE_HELMET:   slot_name = "helmet"
			TYPE_CHARM:    slot_name = "charm"
		var old_id: int = equipment.unequip(slot_name)
		if old_id > 0:
			inventory.add_item(old_id, 1)
		equipment.equip(slot_name, slot["item_id"])
		inventory.remove_item(slot_idx, 1)
	else:
		# 消耗品
		var stats: Dictionary = defn.get("stats", {})
		if _is_network_game():
			if int(stats.get("socket_tool", 0)) > 0:
				if not _has_socket_target():
					_show_float_text("没有可继续打孔的史诗或传说装备", Color(1.0, 0.55, 0.45))
					return
				_show_socket_select_panel(slot_idx)
				return
			await _run_network_game_command("item/use", {"item_id": int(slot.get("item_id", 0))}, "")
			return
		if int(stats.get("fate_event", 0)) > 0:
			inventory.remove_item(slot_idx, 1)
			_apply_fate_card({})
			return
		if int(stats.get("socket_tool", 0)) > 0:
			if not _has_socket_target():
				_show_float_text("没有可继续打孔的史诗或传说装备", Color(1.0, 0.55, 0.45))
				return
			_show_socket_select_panel(slot_idx)
			return
		player_gold += stats.get("gold_bonus", 0)
		player_exp += stats.get("exp_bonus", 0)
		top_bar.refresh()
		inventory.remove_item(slot_idx, 1)


func _has_socket_target() -> bool:
	for equip in equip_instances:
		if EquipmentRulesCls.can_socket(equip):
			return true
	return false


## ============ 主角属性详情面板 ============
## ============ 主角属性计算 ============
func _calc_player_stats() -> Dictionary:
	if _is_network_game() and not authoritative_stats.is_empty():
		# The server is the source of truth for derived values. The client only
		# maps the snapshot to the keys used by existing panels and animations.
		var s := authoritative_stats
		var hp := maxi(int(s.get("maxHp", player_max_hp)), 1)
		var atk := int(s.get("attack", 25))
		var defense := int(s.get("defense", 15))
		return {
			"hp": hp, "hp_base": hp, "hp_equip": 0,
			"atk": atk, "atk_base": atk, "atk_equip": 0, "free_atk_pct": 0.0,
			"def": defense, "def_base": defense, "def_equip": 0, "free_def_pct": 0.0,
			"spd": float(s.get("speed", 0)), "luk": float(s.get("luck", 0)),
			"free_spd_pct": 0.0, "free_luk_pct": 0.0,
			"crit": snapped(float(s.get("crit", 0)), 0.01),
			"critdmg": snapped(float(s.get("critDamage", 150)), 0.01),
			"hit": snapped(float(s.get("hit", 0)), 0.01),
			"dodge": snapped(float(s.get("dodge", 0)), 0.01),
			"block": snapped(float(s.get("block", 0)), 0.01),
			"skill_dmg": snapped(float(s.get("skillDamage", 0)), 0.01),
			"cd_reduce": snapped(float(s.get("cooldownReduction", 0)), 0.01),
			"lifesteal": float(s.get("lifesteal", 0)),
			"gold_bonus": float(s.get("goldBonus", 0)),
			"exp_bonus": float(s.get("experienceBonus", 0)),
			"free_stat_atk": player_stat_atk, "free_stat_def": player_stat_def,
			"free_stat_spd": player_stat_spd, "free_stat_luk": player_stat_luk,
		}
	var lv: int = player_level
	var hp_base: int = 500 + (lv - 1) * 80
	var atk_base: int = 25 + (lv - 1) * 2
	var def_base: int = 15 + (lv - 1) * 1
	var hp_equip: float = 0.0
	var atk_equip: float = 0.0
	var def_equip: float = 0.0
	var spd: float = 0.0
	var luk: int = 0
	var crit: float = 0
	var critdmg: float = 0
	var hit: float = 0
	var dodge: float = 0
	var block: float = 0
	var skill_dmg: float = 0
	var cd_reduce: float = 0
	var lifesteal: float = 0.0
	var gold_bonus: float = 0.0
	var exp_bonus: float = 0.0

	# 遍历已装备的
	for ei in range(equip_instances.size()):
		var ep: Dictionary = equip_instances[ei]
		if not ep.get("equipped", false):
			continue
		var mv: float = ep.get("main_value", 0.0)
		var ms: String = ep.get("main_stat", "")
		var enhanced_value := EquipmentRulesCls.enhanced_main_value(ep, equipment.get_slot_enhance(str(ep.get("slot", ""))))
		match ms:
			"生命值":   hp_equip += enhanced_value
			"攻击力":   atk_equip += enhanced_value
			"防御力":   def_equip += enhanced_value
			"速度":     spd += enhanced_value
			"暴击率":   crit += enhanced_value
			"技能伤害": skill_dmg += enhanced_value
			"格挡率":   block += enhanced_value
			"闪避率":   dodge += enhanced_value

		# 词条加成（18词条全覆盖）
		for aff in ep.get("affixes", []):
			var av: float = aff.get("value", 0.0)
			match aff.get("name", ""):
				"攻击%":      atk_equip += int(atk_base * av / 100.0)
				"攻击(数值)": atk_equip += int(av)
				"防御%":      def_equip += int(def_base * av / 100.0)
				"防御(数值)": def_equip += int(av)
				"生命%":      hp_equip += int(hp_base * av / 100.0)
				"速度":       spd += int(av)
				"幸运":       luk += int(av)
				"暴击率":     crit += av
				"暴击伤害":   critdmg += av
				"命中":       hit += av
				"闪避率":     dodge += av
				"格挡率":     block += av
				"技能伤害":   skill_dmg += av
				"冷却缩减":   cd_reduce += av
				"吸血":       lifesteal += av
				"金币加成":   gold_bonus += av
				"经验加成":   exp_bonus += av

		# 已镶嵌宝石按实际等级结算。
		for gem_entry in ep.get("gems", []):
			var gem_id := _gem_entry_id(gem_entry)
			var gem_level := _gem_entry_level(gem_entry)
			match gem_id:
				1: atk_equip += 10 * gem_level
				2: def_equip += 10 * gem_level
				3: hp_equip += 50 * gem_level
				4: crit += 0.5 * gem_level
				5: skill_dmg += 0.5 * gem_level
				6: hit += 0.5 * gem_level
				7: critdmg += 2.0 * gem_level
				8: block += 0.5 * gem_level

	# 套装专属词条：同名词条全身只结算一次。
	var set_affix_names := _equipped_set_affix_names()
	if set_affix_names.has("【龙鳞】坚韧"): block += 3.0
	if set_affix_names.has("【疾风】疾行"): spd += 5
	if set_affix_names.has("【铁壁】铁甲"): block += 3.0
	if set_affix_names.has("【自然】生根"): lifesteal += 2.0
	if set_affix_names.has("【引力】吸引"): gold_bonus += 10.0
	if set_affix_names.has("【引力】万有"): luk += 5
	if set_affix_names.has("【幻影】灵动"): dodge += 3.0

	# 预留：天命卡加成
	# 套装 2 件效果统一在最终属性入口结算；3/4 件触发效果由战斗引擎处理。
	var suit_counts := _count_equipped_suits()
	if int(suit_counts.get("龙鳞", 0)) >= 2:
		def_equip += int((def_base + def_equip) * 0.15)
	if int(suit_counts.get("烈焰", 0)) >= 2:
		atk_equip += int((atk_base + atk_equip) * 0.10)
	if int(suit_counts.get("冰霜", 0)) >= 2:
		spd += 10
	if int(suit_counts.get("雷霆", 0)) >= 2:
		crit += 8.0
	if int(suit_counts.get("疾风", 0)) >= 2:
		spd += 20
	if int(suit_counts.get("铁壁", 0)) >= 2:
		block += 8.0
	if int(suit_counts.get("暗影", 0)) >= 2:
		critdmg += 25.0
	if int(suit_counts.get("自然", 0)) >= 2:
		lifesteal += 3.0
	if int(suit_counts.get("引力", 0)) >= 2:
		gold_bonus += 30.0
	if int(suit_counts.get("引力", 0)) >= 3:
		luk += 15
	if int(suit_counts.get("星辰", 0)) >= 2:
		cd_reduce += 10.0
	if int(suit_counts.get("幻影", 0)) >= 2:
		dodge += 8.0
	if int(suit_counts.get("口才", 0)) >= 2:
		luk += 10
	if int(suit_counts.get("奢侈", 0)) >= 2:
		gold_bonus -= 50.0

	# 预留：天命卡加成
	var fate: Dictionary = _calc_fate_bonus()
	# 预留：神祇祝福加成
	var deity: Dictionary = _calc_deity_bonus()

	# 自由属性点加成（v0.2: 每级2点）
	var free_atk_pct: float = player_stat_atk * 0.018    # 每点+1.8%最终伤害
	var free_def_pct: float = minf(player_stat_def * 0.012, 0.50)    # 每点+1.2%直接减伤（上限50%）
	var free_spd_pct: float = minf(player_stat_spd * 0.008, 0.50)    # 每点-0.8%出手CD（上限50%）
	var free_luk_pct: float = player_stat_luk * 0.015    # 每点+1.5%稀有掉落

	return {
		"hp": hp_base + int(round(hp_equip)), "hp_base": hp_base, "hp_equip": int(round(hp_equip)),
		"atk": atk_base + int(round(atk_equip)), "atk_base": atk_base, "atk_equip": int(round(atk_equip)), "free_atk_pct": free_atk_pct,
		"def": def_base + int(round(def_equip)), "def_base": def_base, "def_equip": int(round(def_equip)), "free_def_pct": free_def_pct,
		"spd": spd + player_stat_spd, "luk": luk + player_stat_luk,
		"free_spd_pct": free_spd_pct, "free_luk_pct": free_luk_pct,
		"crit": snapped(crit, 0.01), "critdmg": snapped(150.0 + critdmg, 0.01),
		"hit": snapped(hit, 0.01), "dodge": snapped(dodge, 0.01), "block": snapped(block, 0.01),
		"skill_dmg": snapped(skill_dmg, 0.01), "cd_reduce": snapped(cd_reduce, 0.01),
		"lifesteal": lifesteal,
		"gold_bonus": gold_bonus, "exp_bonus": exp_bonus,
		"free_stat_atk": player_stat_atk,
		"free_stat_def": player_stat_def,
		"free_stat_spd": player_stat_spd,
		"free_stat_luk": player_stat_luk,
	}


func _calc_fate_bonus() -> Dictionary:
	return {}


func _calc_deity_bonus() -> Dictionary:
	var result := {"gold_mult": 1.0, "damage_mult": 1.0, "incoming_damage_mult": 1.0, "cd_mult": 1.0, "quality_up_chance": 0.0}
	for buff in _deity_buffs:
		var stat := str(buff.get("stat", ""))
		if stat in ["gold_mult", "damage_mult", "cd_mult"]:
			result[stat] = float(result[stat]) * float(buff.get("value", 1.0))
		elif stat == "quality_up_chance":
			result[stat] = 1.0 - (1.0 - float(result[stat])) * (1.0 - float(buff.get("value", 0.0)))
		elif stat == "war_god":
			result["damage_mult"] = float(result["damage_mult"]) * 1.5
			result["incoming_damage_mult"] = float(result["incoming_damage_mult"]) * 0.7
		elif stat == "decline_god":
			result["damage_mult"] = float(result["damage_mult"]) * 0.7
			result["incoming_damage_mult"] = float(result["incoming_damage_mult"]) * 1.5
	return result


func _apply_fate_card(card_data: Dictionary) -> void:
	var ctx := _build_grid_context()
	var result: Dictionary = GridExecutorCls._exec_fate_with_limit(ctx)
	player_gold = int(ctx.get("player_gold", player_gold))
	player_revive = int(ctx.get("player_revive", player_revive))
	player_hp = clampi(int(ctx.get("player_hp", player_hp)), 0, player_max_hp)
	_apply_simple_grid_result(result.get("data", {}))


func _apply_deity_buff(buff_data: Dictionary) -> void:
	_deity_buffs.append(buff_data.duplicate(true))
	_refresh_all_stats_panels()


## ============ 技能面板 ============
func _build_skill_tab(panel: Panel) -> void:
	var sec_y: float = 50.0
	var gold_lbl := Label.new()
	gold_lbl.text = "金币：%d" % player_gold
	gold_lbl.position = Vector2(420, 14)
	gold_lbl.add_theme_font_size_override("font_size", 14)
	gold_lbl.add_theme_color_override("font_color", Color("8a5a12"))
	panel.add_child(gold_lbl)

	# 装备技能槽位
	var eq_title: Label = Label.new()
	eq_title.text = "装备技能槽位"
	eq_title.add_theme_font_size_override("font_size", 13)
	eq_title.add_theme_color_override("font_color", Color("96353e"))
	eq_title.position = Vector2(16, sec_y)
	panel.add_child(eq_title)

	# ? 说明按钮
	var help_btn: Button = Button.new()
	help_btn.text = "?"
	help_btn.position = Vector2(114, sec_y - 3)
	help_btn.size = Vector2(22, 22)
	help_btn.add_theme_font_size_override("font_size", 11)
	UIUtils.btn_style_mini(help_btn, Color(0.15, 0.22, 0.38))
	help_btn.pressed.connect(func():
		_show_stat_tooltip("优先级规则", "点击数字 ①/②/③ 切换优先级\n双击已装备技能可卸下\n\n技能按自身行动次数冷却\n同时就绪时：③>②>①\n同级按槽位从左到右释放\n全部冷却中→普攻\n\n槽位解锁(角色等级):\nLv.1=2槽  Lv.5=3槽  Lv.15=4槽\nLv.35=5槽  Lv.45=6槽")
	)
	panel.add_child(help_btn)

	var slot_w: float = 304.0
	var slot_h: float = 64.0
	var gap_x: float = 12.0
	var gap_y: float = 8.0
	var cols: int = 3
	var max_slots: int = skill_system.get_slot_count()
	var unlocked: int = skill_system.get_unlocked_slots()

	for i in range(max_slots):
		var col: int = i % cols
		var row: int = i / cols
		var sx: float = 16.0 + col * (slot_w + gap_x)
		var sy: float = sec_y + 30.0 + row * (slot_h + gap_y)
		var sid: Variant = skill_system.get_slot_skill_id(i)
		var is_locked: bool = (i >= unlocked)

		if is_locked:
			# 锁定槽
			var lock_bg: Panel = Panel.new()
			lock_bg.position = Vector2(sx, sy)
			lock_bg.size = Vector2(slot_w, slot_h)
			lock_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var lock_st := StyleBoxFlat.new()
			lock_st.bg_color = Color("f3e7e4")
			lock_st.border_width_left = 1
			lock_st.border_width_right = 1
			lock_st.border_width_top = 1
			lock_st.border_width_bottom = 1
			lock_st.border_color = Color("d6b8b3")
			lock_bg.add_theme_stylebox_override("panel", lock_st)
			panel.add_child(lock_bg)
			var lock_lbl: Label = Label.new()
			var unlock_lv: int = [0, 0, 0, 5, 15, 35, 45][i+1] if i+1 < 7 else 45
			lock_lbl.text = "🔒 角色Lv." + str(unlock_lv) + " 解锁"
			lock_lbl.add_theme_font_size_override("font_size", 12)
			lock_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
			lock_lbl.position = Vector2(sx + 100, sy + 22)
			panel.add_child(lock_lbl)
		elif sid != null:
			# 已装备技能
			var sdata: Dictionary = SkillDataRef.get_skill(sid)
			var priority: int = skill_system.get_slot_priority(i)
			var prio_icons: String = ["①", "②", "③"][priority-1]
			var school_clr: Color = _skill_school_color(sdata.get("school", 0))

			var skill_bg: Panel = Panel.new()
			skill_bg.position = Vector2(sx, sy)
			skill_bg.size = Vector2(slot_w, slot_h)
			var sb := StyleBoxFlat.new()
			sb.bg_color = school_clr.lightened(0.82)
			sb.border_width_left = 1
			sb.border_width_right = 1
			sb.border_width_top = 1
			sb.border_width_bottom = 1
			sb.border_color = school_clr
			skill_bg.add_theme_stylebox_override("panel", sb)
			panel.add_child(skill_bg)

			var icon_lbl: Label = Label.new()
			icon_lbl.text = UIUtils.safe_icon(str(sdata.get("icon", "")), "技")
			icon_lbl.add_theme_font_size_override("font_size", 22)
			icon_lbl.position = Vector2(sx + 8, sy + 10)
			panel.add_child(icon_lbl)

			var name_lbl: Label = Label.new()
			name_lbl.text = sdata.get("name", "??")
			name_lbl.add_theme_font_size_override("font_size", 14)
			name_lbl.add_theme_color_override("font_color", Color("352e38"))
			name_lbl.position = Vector2(sx + 52, sy + 12)
			panel.add_child(name_lbl)

			var cd_lbl: Label = Label.new()
			cd_lbl.text = "行动冷却 " + SkillDataRef.action_cd_text(sdata)
			cd_lbl.add_theme_font_size_override("font_size", 11)
			cd_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
			cd_lbl.position = Vector2(sx + 52, sy + 32)
			panel.add_child(cd_lbl)

			# 优先级按钮（2.5x放大）
			var prio_btn: Button = Button.new()
			prio_btn.text = prio_icons
			prio_btn.position = Vector2(sx + slot_w - 100, sy + 7)
			prio_btn.size = Vector2(90, 50)
			prio_btn.add_theme_font_size_override("font_size", 26)
			var prio_clr: Color = [Color(0.6, 0.6, 0.6), Color(0.3, 1.0, 0.6), Color(0.3, 0.6, 1.0)][priority-1]
			UIUtils.shrine_button_style(prio_btn, false)
			prio_btn.add_theme_color_override("font_color", prio_clr)
			var si: int = i
			prio_btn.pressed.connect(func():
				if _is_network_game():
					await _sync_network_skill_slots(si)
				else:
					skill_system.toggle_priority(si)
					_stats_tab = "skill"
					_refresh_stats_panel()
			)
			panel.add_child(prio_btn)

			# 点击查看详情
			var detail_btn: Button = HoverHintButton.new()
			detail_btn.flat = true
			detail_btn.position = Vector2(sx, sy)
			# Keep the description hit area separate from the priority control.
			# The priority button starts at slot_w - 100, so leave a visible gap
			# instead of allowing a click on the skill card to change priority.
			detail_btn.size = Vector2(slot_w - 110, slot_h)
			UIUtils.btn_transparent2(detail_btn)
			var sid_cap: int = sid
			detail_btn.tooltip_text = _skill_hover_text(sdata)
			detail_btn.gui_input.connect(func(ev: InputEvent):
				if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
					detail_btn.accept_event()
					if ev.double_click:
						_cancel_pending_detail_click()
						if _is_network_game():
							await _sync_network_skill_slots(-1, si)
						else:
							skill_system.unequip_skill(si)
							_refresh_stats_panel()
					else:
						_queue_detail_click(func():
							if is_instance_valid(panel):
								_show_skill_tooltip(sid_cap, true, si, panel)
						)
			)
			panel.add_child(detail_btn)
		else:
			# 空槽
			var empty_bg: Panel = Panel.new()
			empty_bg.position = Vector2(sx, sy)
			empty_bg.size = Vector2(slot_w, slot_h)
			empty_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var es := StyleBoxFlat.new()
			es.bg_color = Color("fffdfb")
			es.border_width_left = 1
			es.border_width_right = 1
			es.border_width_top = 1
			es.border_width_bottom = 1
			es.border_color = Color("d6b8b3")
			es.set_corner_radius_all(4)
			empty_bg.add_theme_stylebox_override("panel", es)
			panel.add_child(empty_bg)
			var empty_lbl: Label = Label.new()
			empty_lbl.text = "空槽位 " + str(i+1) + "/" + str(max_slots)
			empty_lbl.add_theme_font_size_override("font_size", 12)
			empty_lbl.add_theme_color_override("font_color", Color(0.35, 0.35, 0.4))
			empty_lbl.position = Vector2(sx + 100, sy + 22)
			panel.add_child(empty_lbl)

	# 分隔
	var pool_y: float = sec_y + 30.0 + ((max_slots + 1) / cols) * (slot_h + gap_y) + 8
	var sep: ColorRect = ColorRect.new()
	sep.position = Vector2(16, pool_y)
	sep.size = Vector2(panel.size.x - 32.0, 1)
	sep.color = Color(0.2, 0.2, 0.3)
	panel.add_child(sep)

	# 技能池标题
	pool_y += 10
	var pool_title: Label = Label.new()
	pool_title.text = "技能池"
	pool_title.add_theme_font_size_override("font_size", 13)
	pool_title.add_theme_color_override("font_color", Color("96353e"))
	pool_title.position = Vector2(16, pool_y)
	panel.add_child(pool_title)

	# 流派筛选按钮
	pool_y += 22
	var school_names: Array[String] = ["全部", "爆发", "持续", "控制", "生存", "Dot", "贯穿"]
	var school_colors: Array[Color] = [
		Color(0.5,0.5,0.5), Color(0.8,0.3,0.3), Color(0.3,0.7,0.9),
		Color(0.3,0.6,1.0), Color(0.2,0.8,0.4), Color(0.7,0.3,0.9), Color(1.0,0.6,0.2)
	]
	for qi in range(school_names.size()):
		var qb: Button = Button.new()
		qb.text = school_names[qi]
		qb.position = Vector2(16 + qi * 48, pool_y)
		qb.size = Vector2(44, 22)
		qb.add_theme_font_size_override("font_size", 11)
		var selected: bool = (_skill_filter == qi - 1 and qi > 0) or (qi == 0 and _skill_filter < 0)
		if selected:
			# 选中：亮背景 + 深色文字，避免焦点状态变成白字。
			var sel_s := StyleBoxFlat.new()
			sel_s.bg_color = school_colors[qi].lightened(0.2)
			sel_s.border_width_left = 2; sel_s.border_width_right = 2
			sel_s.border_width_top = 2; sel_s.border_width_bottom = 2
			sel_s.border_color = Color("8e7679")
			sel_s.set_corner_radius_all(3)
			qb.add_theme_stylebox_override("normal", sel_s)
		else:
			UIUtils.btn_style_mini(qb, school_colors[qi].darkened(0.5))
		UIUtils.set_button_text_color(qb, Color("5f5557") if selected else school_colors[qi])
		qb.pressed.connect(func():
			_skill_filter = qi - 1 if qi > 0 else -1
			_stats_tab = "skill"
			_refresh_stats_panel()
		)
		panel.add_child(qb)

	# 技能网格（ScrollContainer 支持滚动查看全部技能）
	var pcol: int = 6
	var grid_y: float = pool_y + 30.0
	var icon_s: float = 148.0
	var i_gap: float = 8.0

	# 筛选可用技能
	var all_skills: Array[Dictionary] = []
	for s in SkillDataRef.SKILLS:
		if _skill_filter >= 0 and s["school"] != _skill_filter:
			continue
		all_skills.append(s)
	all_skills.sort_custom(func(a: Dictionary, b: Dictionary):
		var a_unlocked: bool = bool(skill_system.is_skill_unlocked(int(a["id"])))
		var b_unlocked: bool = bool(skill_system.is_skill_unlocked(int(b["id"])))
		if a_unlocked != b_unlocked:
			return a_unlocked
		return int(a["id"]) < int(b["id"])
	)

	# ScrollContainer 包裹技能网格
	var scroll: ScrollContainer = ScrollContainer.new()
	var scroll_top: float = grid_y
	var scroll_height: float = panel.size.y - scroll_top - 10
	scroll.position = Vector2(8, scroll_top)
	scroll.size = Vector2(panel.size.x - 20, scroll_height)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true

	# 滚动内容容器
	var content: Control = Control.new()
	content.name = "SkillGridContent"
	var total_rows: int = ceili(float(all_skills.size()) / pcol)
	var content_h: float = total_rows * 52.0 + 8
	content.custom_minimum_size = Vector2(panel.size.x - 24, content_h)
	scroll.add_child(content)

	for si in range(all_skills.size()):
		var sdata: Dictionary = all_skills[si]
		var is_unlocked: bool = skill_system.is_skill_unlocked(int(sdata["id"]))
		var col_i: int = si % pcol
		var row_i: int = si / pcol
		var cx: float = 4.0 + col_i * (icon_s + i_gap)
		var cy: float = 4.0 + row_i * 52.0

		var equipped: bool = false
		var equipped_slot: int = -1
		for ei in range(unlocked):
			var esid = skill_system.get_slot_skill_id(ei)
			if esid == sdata["id"]:
				equipped = true
				equipped_slot = ei
				break

		var sc: Color = _skill_school_color(sdata.get("school", 0))
		var p_style: StyleBoxFlat = StyleBoxFlat.new()
		p_style.bg_color = (sc.lightened(0.86) if not equipped else sc.lightened(0.72)) if is_unlocked else Color("f1e8e6")
		p_style.border_width_left = 1
		p_style.border_width_right = 1
		p_style.border_width_top = 1
		p_style.border_width_bottom = 1
		p_style.border_color = sc if is_unlocked else Color(0.28, 0.28, 0.32)
		p_style.set_corner_radius_all(4)
		var pool_bg: Panel = Panel.new()
		pool_bg.position = Vector2(cx, cy)
		pool_bg.size = Vector2(icon_s, 48)
		pool_bg.add_theme_stylebox_override("panel", p_style)
		content.add_child(pool_bg)

		var pool_icon: Label = Label.new()
		pool_icon.text = UIUtils.safe_icon(str(sdata.get("icon", "")), "技")
		pool_icon.add_theme_font_size_override("font_size", 18)
		pool_icon.position = Vector2(cx + 6, cy + 6)
		content.add_child(pool_icon)

		var pool_name: Label = Label.new()
		pool_name.text = sdata.get("name", "??")
		pool_name.add_theme_font_size_override("font_size", 12)
		pool_name.add_theme_color_override("font_color", Color("352e38") if is_unlocked else Color("8b7f80"))
		pool_name.position = Vector2(cx + 34, cy + 6)
		content.add_child(pool_name)

		var pool_info: Label = Label.new()
		if equipped:
			pool_info.text = "已装备 · 行动冷却 " + SkillDataRef.action_cd_text(sdata)
		elif is_unlocked:
			pool_info.text = "行动冷却 " + SkillDataRef.action_cd_text(sdata) + " · 已解锁"
		else:
			pool_info.text = "解锁 " + str(sdata.get("price", 0)) + " 金币"
		pool_info.add_theme_font_size_override("font_size", 10)
		var skill_price: int = int(sdata.get("price", 0))
		pool_info.add_theme_color_override("font_color", Color("17633f") if not is_unlocked and player_gold >= skill_price else Color("7d7072"))
		pool_info.position = Vector2(cx + 34, cy + 24)
		content.add_child(pool_info)

		# 点击查看详情 + 装备/卸下（tooltip内操作）
		var click_btn: Button = HoverHintButton.new()
		click_btn.flat = true
		click_btn.position = Vector2(cx, cy)
		click_btn.size = Vector2(icon_s, 48)
		UIUtils.btn_transparent2(click_btn)
		var sid_val: int = sdata["id"]
		var eq_slot: int = equipped_slot
		click_btn.tooltip_text = _skill_hover_text(sdata)
		click_btn.pressed.connect(func():
			_close_all_tooltips()
			_show_skill_tooltip(sid_val, equipped, eq_slot, panel)
		)
		content.add_child(click_btn)

	panel.add_child(scroll)


## 技能提示（支持装备/卸下操作）
## already_equipped: 是否已装备, equipped_slot: 已装备的槽位号(-1=未装备), parent_panel: 父面板(用于刷新)
func _show_skill_tooltip(skill_id: int, already_equipped: bool = false, equipped_slot: int = -1, parent_panel: Panel = null) -> void:
	var sdata: Dictionary = SkillDataRef.get_skill(skill_id)
	if sdata.is_empty():
		return
	var is_unlocked: bool = skill_system.is_skill_unlocked(skill_id)
	_close_all_tooltips()
	_ensure_overlay()

	var tip: Panel = Panel.new()
	tip.name = "SkillTooltip"
	tip.position = Vector2(360, 160)
	tip.size = Vector2(300, 260)
	_prepare_modal_panel(tip)
	UIUtils.shrine_panel_style(tip, Color("fff9f5"), Color("b88d89"), 2)
	_tooltip_nodes.append(tip)

	var sc: Color = _skill_school_color(sdata.get("school", 0))
	# 顶部品质色条
	var top_bar_rect: ColorRect = ColorRect.new()
	top_bar_rect.position = Vector2(0, 0)
	top_bar_rect.size = Vector2(300, 3)
	top_bar_rect.color = sc
	tip.add_child(top_bar_rect)

	var title: Label = Label.new()
	title.text = UIUtils.safe_icon(str(sdata.get("icon", "")), "技") + " " + sdata.get("name", "???")
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", sc)
	title.position = Vector2(16, 10)
	tip.add_child(title)

	# 流派 + CD + 目标
	var school_lbl: Label = Label.new()
	var target_str: String = ""
	match sdata.get("target", -1):
		0: target_str = "前单"
		1: target_str = "后单"
		2: target_str = "最低HP"
		3: target_str = "最低HP%"
		4: target_str = "最高攻"
		5: target_str = "最高防"
		6: target_str = "前排全体"
		7: target_str = "全体"
		8: target_str = "后排全体"
		9: target_str = "贯穿"
		10: target_str = "自身"
		11: target_str = "自身治疗"
	school_lbl.text = SkillDataRef.school_name(sdata.get("school", 0)) + "  |  行动冷却 " + SkillDataRef.action_cd_text(sdata) + ("  |  " + target_str if not target_str.is_empty() else "")
	school_lbl.add_theme_font_size_override("font_size", 12)
	school_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	school_lbl.position = Vector2(16, 34)
	tip.add_child(school_lbl)

	# 分隔
	var sep1: ColorRect = ColorRect.new()
	sep1.position = Vector2(8, 54)
	sep1.size = Vector2(284, 1)
	sep1.color = Color(0.2, 0.2, 0.3)
	tip.add_child(sep1)

	# 详细效果
	var sy: float = 60.0
	var desc: String = sdata.get("desc", "")
	if sdata.has("dmg_pct"):
		desc += "\n伤害倍率: " + str(sdata["dmg_pct"]) + "%"
		if sdata.has("hits") and sdata["hits"] > 1:
			desc += " ×" + str(sdata["hits"]) + "次"
	if sdata.has("control"):
		var cname: String = SkillDataRef.control_name(sdata.get("control", -1))
		if not cname.is_empty():
			desc += "\n控制: " + cname + " " + str(sdata.get("control_dur", 0)) + "秒"
	if sdata.has("dot_pct"):
		desc += "\nDot: " + str(sdata["dot_pct"]) + "%/次 ×" + str(sdata.get("dot_dur", 0)) + "秒"
	if sdata.has("shield_pct"):
		desc += "\n护盾: " + str(sdata["shield_pct"]) + "% " + sdata.get("shield_stat", "def")
	if sdata.has("heal_pct"):
		desc += "\n治疗: " + str(sdata["heal_pct"]) + "% " + sdata.get("heal_stat", "atk")

	if sdata.has("bonus"):
		var bonus: Dictionary = sdata["bonus"]
		if bonus.has("ignore_def_pct"):
			desc += "\n无视防御: " + str(bonus["ignore_def_pct"]) + "%"
		if bonus.has("execute_threshold"):
			desc += "\nHP<" + str(int(bonus["execute_threshold"] * 100)) + "%时伤害×" + str(bonus["execute_mult"])
		if bonus.has("missing_hp_scale"):
			desc += "\n每损失1%HP +" + str(bonus["missing_hp_scale"]) + "%伤害"
		if bonus.has("detonate_dot"):
			desc += "\n结算Dot剩余伤害×" + str(bonus["detonate_dot"])
		if bonus.has("spread_dot"):
			desc += "\n复制Dot到全体敌人"

	var body: Label = Label.new()
	body.text = desc
	body.add_theme_font_size_override("font_size", 12)
	body.add_theme_color_override("font_color", Color("352e38"))
	body.position = Vector2(16, sy)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.size = Vector2(270, 120)
	tip.add_child(body)

	# 底部操作按钮
	var btn_y: float = tip.size.y - 38
	if not is_unlocked:
		var buy_btn: Button = Button.new()
		var price: int = int(sdata.get("price", 0))
		buy_btn.text = "解锁  " + str(price) + " 金币"
		buy_btn.position = Vector2(16, btn_y)
		buy_btn.size = Vector2(150, 28)
		UIUtils.btn_style_mini(buy_btn, Color(0.35, 0.25, 0.08))
		buy_btn.disabled = player_gold < price
		var sid_buy: int = skill_id
		buy_btn.pressed.connect(func():
			if player_gold < price:
				_show_float_text("金币不足，需要 " + str(price) + " 金币", Color(1.0, 0.4, 0.3))
				return
			if _is_network_game():
				var unlocked_now := await _run_network_game_command("skill/unlock", {"skill_id": sid_buy}, "技能已解锁")
				if unlocked_now:
					_close_all_tooltips()
					_refresh_stats_panel()
				return
			else:
				player_gold -= price
				skill_system.unlock_skill(sid_buy)
				_auto_save()
			_close_all_tooltips()
			_refresh_stats_panel()
		)
		tip.add_child(buy_btn)
	elif already_equipped and equipped_slot >= 0:
		# 已装备 → 卸下按钮
		var unequip_btn: Button = Button.new()
		unequip_btn.text = "卸下"
		unequip_btn.position = Vector2(16, btn_y)
		unequip_btn.size = Vector2(80, 28)
		UIUtils.btn_style_mini(unequip_btn, Color(0.35, 0.12, 0.12))
		unequip_btn.add_theme_color_override("font_color", Color(1.0, 0.6, 0.6))
		var slot_idx: int = equipped_slot
		unequip_btn.pressed.connect(func():
			if _is_network_game():
				await _sync_network_skill_slots(-1, slot_idx)
				_close_all_tooltips()
				return
			else:
				skill_system.unequip_skill(slot_idx)
			_close_all_tooltips()
			_refresh_stats_panel()
		)
		tip.add_child(unequip_btn)
	else:
		# 未装备 → 装备按钮（按1~6找空位）
		var equip_btn: Button = Button.new()
		equip_btn.text = "装备"
		equip_btn.position = Vector2(16, btn_y)
		equip_btn.size = Vector2(80, 28)
		UIUtils.btn_style_mini(equip_btn, Color(0.15, 0.28, 0.45))
		equip_btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.6))
		var sid_v: int = skill_id
		equip_btn.pressed.connect(func():
			var ok: bool = skill_system.get_slot_skill_id(skill_system.get_unlocked_slots() - 1) == null
			if _is_network_game() and ok:
				ok = await _sync_network_skill_slots(-1, -1, sid_v)
			elif ok:
				ok = skill_system.equip_skill(sid_v)
			if ok:
				_close_all_tooltips()
				_refresh_stats_panel()
			else:
				_show_float_text("技能槽位已满，无空位可装备", Color(1.0, 0.5, 0.3))
		)
		tip.add_child(equip_btn)

	# 关闭按钮
	var close_btn: Button = Button.new()
	close_btn.text = "✕"
	close_btn.position = Vector2(tip.size.x - 38, btn_y)
	close_btn.size = Vector2(26, 28)
	UIUtils.btn_style_mini(close_btn, Color(0.25, 0.1, 0.1))
	close_btn.pressed.connect(_close_all_tooltips)
	tip.add_child(close_btn)

	add_child(tip)


func _skill_hover_text(skill: Dictionary) -> String:
	var lines: Array[String] = [
		UIUtils.safe_icon(str(skill.get("icon", "")), "技") + " " + str(skill.get("name", "???")),
		SkillDataRef.school_name(int(skill.get("school", 0))) + "  |  行动冷却 " + SkillDataRef.action_cd_text(skill),
	]
	var description := str(skill.get("desc", ""))
	if not description.is_empty():
		lines.append(description)
	return "\n".join(lines)


## 技能流派颜色
func _skill_school_color(school: int) -> Color:
	match school:
		0: return Color(0.8, 0.3, 0.2)   # 爆发流·红
		1: return Color(0.3, 0.7, 0.9)   # 持续流·蓝
		2: return Color(0.3, 0.6, 1.0)   # 控制流·靛蓝
		3: return Color(0.2, 0.8, 0.4)   # 生存流·绿
		4: return Color(0.7, 0.3, 0.9)   # Dot流·紫
		5: return Color(1.0, 0.6, 0.2)   # 贯穿流·橙
	return Color(0.5, 0.5, 0.5)


var _skill_filter: int = -1  # -1=全部, 0~5=流派


## ============ 面板内部刷新（不触发 toggle） ============
func _refresh_stats_panel() -> void:
	var old: Node = get_node_or_null("StatsPanel")
	if old:
		remove_child(old)
		old.queue_free()
	_show_stats_panel()


## ============ 属性面板 ============## ============ 角色属性/技能面板（分页） ============
var _stats_tab: String = "stats"  # "stats" | "skill"

## 强制打开面板（头像点击用，不 toggle 关闭，始终重建）
func _open_stats_panel() -> void:
	var old: Node = get_node_or_null("StatsPanel")
	if old:
		old.queue_free()
	call_deferred("_show_stats_panel")


func _show_stats_panel() -> void:
	# 移除旧面板（点击✕关闭时用于 toggle）
	var old: Node = get_node_or_null("StatsPanel")
	if old:
		old.queue_free()
		return

	var panel: Panel = Panel.new()
	panel.name = "StatsPanel"
	panel.position = Vector2(140, 50 if _stats_tab == "skill" else 40)
	panel.size = Vector2(1000, 650) if _stats_tab == "skill" else Vector2(600, 680)
	UIUtils.shrine_panel_style(panel, Color("fff9f5"), Color("b88d89"), 2)

	# 标题 + 分页按钮
	var title: Label = Label.new()
	title.text = "📋 " + player_name + "  Lv." + str(player_level)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("96353e"))
	title.position = Vector2(20, 12)
	panel.add_child(title)

	# 分页按钮
	var tab_defs := [
		{ "id": "stats", "text": "属性", "x": int(panel.size.x) - 200 },
		{ "id": "skill", "text": "技能", "x": int(panel.size.x) - 120 },
	]
	for td in tab_defs:
		var tb: Button = Button.new()
		tb.text = td["text"]
		tb.position = Vector2(td["x"], 8)
		tb.size = Vector2(70, 28)
		tb.add_theme_font_size_override("font_size", 14)
		var is_active: bool = (_stats_tab == td["id"])
		if is_active:
			UIUtils.shrine_button_style(tb, true)
		else:
			UIUtils.shrine_button_style(tb, false)
		tb.flat = true
		var tid: String = td["id"]
		tb.pressed.connect(func():
			if _stats_tab == tid:
				return
			_stats_tab = tid
			_refresh_stats_panel()
		)
		panel.add_child(tb)

	var close: Button = Button.new()
	close.text = "✕"
	close.position = Vector2(panel.size.x - 42, 8)
	close.size = Vector2(30, 28)
	UIUtils.shrine_button_style(close, false)
	close.pressed.connect(func():
		_close_all_tooltips()
		panel.queue_free()
	)
	panel.add_child(close)

	if _stats_tab == "skill":
		_build_skill_tab(panel)
		add_child(panel)
		_raise_ui_panel(panel)
		return

	# ========== 属性面板内容 ==========

	# 经验条
	var exp_bar: ProgressBar = ProgressBar.new()
	exp_bar.position = Vector2(20, 44)
	exp_bar.size = Vector2(560, 14)
	exp_bar.value = player_exp
	exp_bar.max_value = player_exp_max
	UIUtils.bar_style(exp_bar, Color(0.15, 0.35, 0.6))
	panel.add_child(exp_bar)

	var exp_lbl: Label = Label.new()
	exp_lbl.text = str(player_exp) + " / " + str(player_exp_max)
	exp_lbl.add_theme_font_size_override("font_size", 10)
	exp_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	exp_lbl.position = Vector2(20, 60)
	panel.add_child(exp_lbl)

	# ============ 自由属性点区域 ============
	var free_sec_y: float = 82.0

	var free_bg: Panel = Panel.new()
	free_bg.position = Vector2(16, free_sec_y)
	free_bg.size = Vector2(568, 88)
	UIUtils.shrine_panel_style(free_bg, Color("fff4f1"), Color("d9a6a3"), 1)
	panel.add_child(free_bg)

	var free_title: Label = Label.new()
	free_title.text = "✨ 自由属性点: " + str(player_free_points)
	free_title.add_theme_font_size_override("font_size", 14)
	free_title.add_theme_color_override("font_color", Color("3d927d") if player_free_points > 0 else Color("8b7a7d"))
	free_title.position = Vector2(28, free_sec_y + 7)
	panel.add_child(free_title)

	# 洗点按钮
	var reset_btn: Button = Button.new()
	reset_btn.text = "洗点"
	reset_btn.position = Vector2(500, free_sec_y + 6)
	reset_btn.size = Vector2(68, 28)
	UIUtils.shrine_button_style(reset_btn, true)
	reset_btn.pressed.connect(_show_reset_confirm)
	panel.add_child(reset_btn)

	# 4维自由属性
	var free_stats: Array[Dictionary] = [
		{ "name": "攻击", "key": "atk", "icon": "攻", "value": player_stat_atk, "desc": "每点+1.8%最终伤害(无上限)" },
		{ "name": "防御", "key": "def", "icon": "防", "value": player_stat_def, "desc": "每点+1.2%直接减伤(上限50%)" },
		{ "name": "速度", "key": "spd", "icon": "速", "value": player_stat_spd, "desc": "每点-0.8%出手CD(上限50%)" },
		{ "name": "幸运", "key": "luk", "icon": "幸", "value": player_stat_luk, "desc": "每点+1.5%稀有掉落/好事件概率" },
	]
	for fi in range(free_stats.size()):
		var fs: Dictionary = free_stats[fi]
		var fx: float = 28.0 + fi * 137.0
		var fy: float = free_sec_y + 36.0

		var stat_card := Panel.new()
		stat_card.position = Vector2(fx - 6, fy - 2)
		stat_card.size = Vector2(125, 44)
		UIUtils.shrine_panel_style(stat_card, Color("fffaf6"), Color("ead0cd"), 1)
		panel.add_child(stat_card)

		# 标签: 图标 + 名称
		var fl: Label = Label.new()
		fl.text = UIUtils.safe_icon(str(fs["icon"]), "属") + " " + fs["name"]
		fl.add_theme_font_size_override("font_size", 12)
		fl.add_theme_color_override("font_color", Color("4f454d"))
		fl.position = Vector2(fx, fy + 1)
		panel.add_child(fl)

		# 数值
		var fv: Label = Label.new()
		fv.name = "FreeStatVal_" + fs["key"]
		fv.text = str(fs["value"])
		fv.add_theme_font_size_override("font_size", 16)
		fv.add_theme_color_override("font_color", Color("a56f00"))
		fv.position = Vector2(fx + 2, fy + 20)
		panel.add_child(fv)

		# + 按钮（有点数才显示）
		if player_free_points > 0:
			var plus_btn: Button = Button.new()
			plus_btn.text = "+"
			plus_btn.position = Vector2(fx + 84, fy + 8)
			plus_btn.size = Vector2(28, 28)
			plus_btn.add_theme_font_size_override("font_size", 16)
			var sk: String = fs["key"]
			plus_btn.pressed.connect(func(): _add_free_stat(sk))
			UIUtils.shrine_button_style(plus_btn, false)
			plus_btn.add_theme_color_override("font_color", Color("287a58"))
			plus_btn.add_theme_color_override("font_hover_color", Color("1d6448"))
			panel.add_child(plus_btn)

	# 分隔线
	var sep_line: ColorRect = ColorRect.new()
	sep_line.position = Vector2(16, free_sec_y + 96)
	sep_line.size = Vector2(568, 1)
	sep_line.color = Color("d9a6a3")
	panel.add_child(sep_line)

	# ============ 属性列表分隔结束 ============

	# 属性列表（使用真实计算的数值）—— 18词条全属性
	var ps: Dictionary = _calc_player_stats()
	var stats: Array[Dictionary] = [
		{ "icon": "生", "name": "生命值 (HP)",   "value": str(ps["hp"]), "raw": ps["hp_base"], "eqp": ps["hp_equip"], "desc": "归零则战斗失败，消耗1枚复活币复活。\n每级+80" },
		{ "icon": "攻", "name": "攻击力 (ATK)",  "value": str(ps["atk"]), "raw": ps["atk_base"], "eqp": ps["atk_equip"], "desc": "基础攻击力，与装备攻击力相加后\n受自由属性点和装备词条加成" },
		{ "icon": "防", "name": "防御力 (DEF)",  "value": str(ps["def"]), "raw": ps["def_base"], "eqp": ps["def_equip"], "desc": "决定受到的伤害减免。\n减伤率 = DEF/(DEF+400)" },
		{ "icon": "速", "name": "速度 (SPD)",    "value": str(ps["spd"]), "raw": 0, "eqp": ps["spd"], "desc": "每点-0.8%出手CD（上限50%）。\n3.0秒× (1-速度%) = 实际CD" },
		{ "icon": "幸", "name": "幸运 (LUK)",    "value": str(ps["luk"]), "raw": 0, "eqp": ps["luk"], "desc": "每点+1.5%稀有掉落/好事件概率。\n影响宝箱品质、命运事件、战斗掉落" },
		{ "icon": "💥", "name": "暴击率",        "value": str(ps["crit"]) + "%", "raw": 0, "eqp": ps["crit"], "desc": "攻击时触发暴击的概率，普攻也可暴击。\n暴击伤害=攻击力×暴击倍率" },
		{ "icon": "💢", "name": "暴击伤害",       "value": str(ps["critdmg"]) + "%", "raw": 150, "eqp": ps["critdmg"], "desc": "暴击时的伤害倍率。\n基础150%，装备/宝石可提高" },
		{ "icon": "🎯", "name": "命中率",        "value": str(ps["hit"]) + "%", "raw": 0, "eqp": ps["hit"], "desc": "决定攻击是否命中。\n可抵消目标的闪避率" },
		{ "icon": "💨", "name": "闪避率",        "value": str(ps["dodge"]) + "%", "raw": 0, "eqp": ps["dodge"], "desc": "完全躲避攻击的概率。\n实际闪避=我方闪避-敌方命中" },
		{ "icon": "挡", "name": "格挡率",        "value": str(ps["block"]) + "%", "raw": 0, "eqp": ps["block"], "desc": "格挡后伤害减半。\n暴击+格挡同时触发=暴击×0.5" },
		{ "icon": "💥", "name": "技能伤害",       "value": "+" + str(ps["skill_dmg"]) + "%", "raw": 0, "eqp": ps["skill_dmg"], "desc": "技能造成的额外伤害加成。\n装备词条/宝石可提高" },
		{ "icon": "⏳", "name": "冷却缩减",       "value": "-" + str(ps["cd_reduce"]) + "%", "raw": 0, "eqp": ps["cd_reduce"], "desc": "减少技能冷却时间。\n装备词条/宝石可提高" },
		{ "icon": "血", "name": "吸血%",         "value": "+" + str(ps["lifesteal"]) + "%", "raw": 0, "eqp": ps["lifesteal"], "desc": "攻击时吸取伤害百分比的生命。\n装备词条可提高" },
		{ "icon": "金", "name": "金币加成",       "value": "+" + str(ps["gold_bonus"]) + "%", "raw": 0, "eqp": ps["gold_bonus"], "desc": "战斗/宝箱获得金币的额外加成。\n天命卡/装备词条可提高" },
		{ "icon": "📖", "name": "经验加成",       "value": "+" + str(ps["exp_bonus"]) + "%", "raw": 0, "eqp": ps["exp_bonus"], "desc": "战斗获得经验的额外加成。\n天命卡/装备词条可提高" },
	]

	var sy: float = free_sec_y + 106.0
	var left_x: float = 16.0
	var right_x: float = 310.0
	var row_w: float = 278.0

	for i in range(stats.size()):
		var col: int = i % 2
		var row_idx: int = i / 2
		var rx: float = left_x if col == 0 else right_x
		var ry: float = sy + row_idx * 47.0
		var st: Dictionary = stats[i]

		# 行背景
		var row_bg: Panel = Panel.new()
		row_bg.position = Vector2(rx, ry)
		row_bg.size = Vector2(row_w, 44)
		UIUtils.shrine_panel_style(row_bg, Color("fffaf6"), Color("ead0cd"), 1)
		panel.add_child(row_bg)

		# 图标
		var icon: Label = Label.new()
		icon.text = UIUtils.safe_icon(str(st["icon"]), "属")
		icon.add_theme_font_size_override("font_size", 16)
		icon.position = Vector2(rx + 8, ry + 10)
		panel.add_child(icon)

		# 名称
		var name_lbl: Label = Label.new()
		name_lbl.text = st["name"]
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.add_theme_color_override("font_color", Color("4f454d"))
		name_lbl.position = Vector2(rx + 32, ry + 12)
		panel.add_child(name_lbl)

		# 数值
		var val_lbl: Label = Label.new()
		val_lbl.text = st["value"]
		val_lbl.add_theme_font_size_override("font_size", 13)
		val_lbl.add_theme_color_override("font_color", Color("a56f00"))
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val_lbl.position = Vector2(rx + 148, ry + 10)
		val_lbl.size = Vector2(80, 20)
		panel.add_child(val_lbl)

		# 点击查看说明
		var btn: Button = Button.new()
		btn.text = "?"
		btn.position = Vector2(rx + row_w - 40, ry + 8)
		btn.size = Vector2(28, 24)
		btn.add_theme_font_size_override("font_size", 10)
		UIUtils.shrine_button_style(btn, false)
		btn.add_theme_color_override("font_color", Color("762c39"))
		var desc: String = st["desc"]
		btn.pressed.connect(func(): _show_stat_tooltip(st["name"], desc))
		panel.add_child(btn)

	sy += ceil(stats.size() / 2.0) * 47.0

	# 底部信息
	sy += 10.0
	var footer: Label = Label.new()
	footer.text = "金币 " + str(player_gold) + "  |  复活币 " + str(player_revive) + "/" + str(player_max_revive) + "  |  位置 " + str(player_grid_index) + "/" + str(map_total_grids)
	footer.add_theme_font_size_override("font_size", 12)
	footer.add_theme_color_override("font_color", Color("746672"))
	footer.position = Vector2(20, sy)
	panel.add_child(footer)

	add_child(panel)
	_raise_ui_panel(panel)


## 属性气泡说明
func _show_stat_tooltip(stat_name: String, desc: String) -> void:
	_close_all_tooltips()
	_ensure_overlay()

	var tip: Panel = Panel.new()
	tip.name = "StatTooltip"
	_prepare_modal_panel(tip)
	tip.position = Vector2(360, 280)
	tip.size = Vector2(320, 120)
	UIUtils.panel_style(tip, Color(0.05, 0.06, 0.12, 0.95))
	_tooltip_nodes.append(tip)

	var title: Label = Label.new()
	title.text = stat_name
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	title.position = Vector2(16, 10)
	tip.add_child(title)

	var body: Label = Label.new()
	body.text = desc
	body.add_theme_font_size_override("font_size", 12)
	body.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	body.position = Vector2(16, 34)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.size = Vector2(288, 76)
	tip.add_child(body)

	add_child(tip)
