class_name BattleView
extends Control

signal closed

## 自动挂机战斗在结算页短暂展示后自动返回地图；手动模式由玩家确认。
var auto_continue: bool = false

const HERO_PATH := "res://assets/hreo.png"
const BOSS_DIR := "res://assets/battle_characters/boss/"
const MONSTER_DIR := "res://assets/battle_characters/monsters/"
const VIEW_SIZE := Vector2(1280, 528)
const WeatherEffectCls = preload("res://scripts/ui/weather_effect.gd")
const SMALL_ASSETS: Array[String] = [
	"char_0001.png", "char_0007.png", "char_0016.png", "char_0031.png", "char_0048.png",
	"char_0067.png", "char_0085.png", "char_0094.png", "char_0125.png", "char_0170.png",
	"char_0198.png", "char_0240.png", "char_0305.png", "char_0371.png", "char_0430.png",
]

const SHRINE := Color("b93647")
const SHRINE_DARK := Color("762c39")
const GOLD := Color("e7b84f")
const PAPER := Color("fffaf4")
const INK := Color("2f2930")
const JADE := Color("3d927d")
const HP_COLOR := Color("e34f5f")
const SHIELD_COLOR := Color("69bde9")

var _edata: Dictionary
var _units: Dictionary = {}
var _unit_data: Dictionary = {}
var _speed := 0.75
var _skip := false
var _kind := "battle"
var _event_label: Label
var _combat_log: RichTextLabel
var _combat_lines: Array[String] = []
var _combat_log_at_top: bool = true
var _combat_log_updating: bool = false
var _status_tip_overlay: Button
var _status_tip: Panel
var _status_tip_title: Label
var _status_tip_body: Label
var _boss_key := ""
var _boss_hp: ProgressBar
var _boss_hp_text: Label
var _challenge_time: Label
var _challenge_damage: Label
var _challenge_dps: Label
var _challenge_rank: Label
var _challenge_total := 0.0
var _challenge_elapsed := 0.0
var _result_closed := false


func setup(edata: Dictionary) -> void:
	_edata = edata
	_kind = str(_edata.get("battle_kind", "battle"))
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_view()
	call_deferred("_play")


func _build_view() -> void:
	_build_background()
	_build_header()
	var result: Dictionary = _edata.get("battle_result", {})
	var player_max := int(result.get("player_max_hp", 1))
	_create_unit({"id": 0, "name": "主角", "display_name": "勇者", "row": "front", "max_hp": player_max, "current_hp": int(result.get("player_start_hp", player_max))}, "player", Vector2(205, 210), HERO_PATH, Vector2(125, 150))

	var encounter: Dictionary = _edata.get("encounter", result.get("encounter", {}))
	var fronts: Array = []
	var backs: Array = []
	for raw in encounter.get("units", []):
		var unit: Dictionary = raw
		if str(unit.get("row", "front")) == "back":
			backs.append(unit)
		else:
			fronts.append(unit)
	for i in range(fronts.size()):
		var unit: Dictionary = fronts[i]
		_create_unit(unit, "enemy", Vector2(700, 165 + i * 115), _enemy_texture_path(unit), _enemy_size(unit))
	for i in range(backs.size()):
		var unit: Dictionary = backs[i]
		_create_unit(unit, "enemy", Vector2(945, 165 + i * 115), _enemy_texture_path(unit), _enemy_size(unit))

	if _kind == "boss":
		_build_boss_hud()
	elif _kind == "challenge":
		_build_challenge_hud()
	_build_footer()
	_build_status_tip()


func _build_background() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color("e8f2ed")
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var far_hills := Polygon2D.new()
	far_hills.polygon = PackedVector2Array([Vector2(0, 315), Vector2(0, 190), Vector2(165, 245), Vector2(330, 130), Vector2(500, 250), Vector2(700, 165), Vector2(890, 250), Vector2(1080, 135), Vector2(1280, 235), Vector2(1280, 315)])
	far_hills.color = Color("cadbd6")
	add_child(far_hills)
	var hills := Polygon2D.new()
	hills.polygon = PackedVector2Array([Vector2(0, 385), Vector2(0, 290), Vector2(145, 235), Vector2(285, 330), Vector2(455, 210), Vector2(635, 332), Vector2(820, 245), Vector2(990, 325), Vector2(1145, 225), Vector2(1280, 310), Vector2(1280, 385)])
	hills.color = Color("a9c7bc")
	add_child(hills)
	var ground := ColorRect.new()
	ground.position = Vector2(0, 330)
	ground.size = Vector2(1280, 198)
	ground.color = Color("93b69c")
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ground)
	var axis := ColorRect.new()
	axis.position = Vector2(639, 105)
	axis.size = Vector2(2, 350)
	axis.color = Color(0.46, 0.17, 0.22, 0.18)
	axis.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(axis)
	var weather := str(_edata.get("encounter", {}).get("weather", "sunny"))
	var tint_colors := {"thunderstorm": Color(0.18, 0.22, 0.34, 0.22), "drizzle": Color(0.25, 0.55, 0.70, 0.12), "fog": Color(0.9, 0.94, 0.92, 0.28), "blizzard": Color(0.75, 0.9, 1.0, 0.22), "scorching_sun": Color(1.0, 0.48, 0.20, 0.15), "sandstorm": Color(0.66, 0.50, 0.27, 0.20), "aurora": Color(0.32, 0.85, 0.65, 0.14)}
	if tint_colors.has(weather):
		var weather_tint := ColorRect.new()
		weather_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		weather_tint.color = tint_colors[weather]
		weather_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(weather_tint)
	var weather_effect: Control = WeatherEffectCls.new()
	weather_effect.name = "WeatherEffect"
	add_child(weather_effect)
	weather_effect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	weather_effect.setup(weather, true)
	_build_torii()


func _build_torii() -> void:
	var torii := Control.new()
	torii.position = Vector2(550, 115)
	torii.modulate.a = 0.14
	torii.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(torii)
	for rect in [Rect2(0, 0, 180, 13), Rect2(15, 25, 150, 9), Rect2(32, 25, 13, 170), Rect2(135, 25, 13, 170)]:
		var part := ColorRect.new()
		part.position = rect.position
		part.size = rect.size
		part.color = SHRINE
		torii.add_child(part)


func _build_header() -> void:
	var crest := Label.new()
	crest.text = "戦"
	crest.position = Vector2(22, 18)
	crest.size = Vector2(36, 36)
	crest.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crest.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crest.add_theme_font_size_override("font_size", 20)
	crest.add_theme_color_override("font_color", Color("ffe69d"))
	crest.add_theme_stylebox_override("normal", _box(SHRINE, Color("fff7e5"), 2, 18))
	add_child(crest)
	var title := Label.new()
	title.text = {"battle": "遭遇战", "elite": "精英来袭", "boss": "BOSS 战", "challenge": "伤害挑战"}.get(_kind, "战斗")
	title.position = Vector2(67, 17)
	title.size = Vector2(210, 22)
	title.add_theme_font_size_override("font_size", 16)
	_text_outline(title, Color.WHITE, 2)
	add_child(title)
	var subtitle := Label.new()
	subtitle.text = "60 秒存活伤害验证" if _kind == "challenge" else str(_edata.get("encounter", {}).get("template_name", "朱樱山道"))
	subtitle.position = Vector2(68, 39)
	subtitle.size = Vector2(250, 16)
	subtitle.add_theme_font_size_override("font_size", 10)
	_text_outline(subtitle, Color("f7e9e8"), 1)
	add_child(subtitle)
	var weather := str(_edata.get("encounter", {}).get("weather", "sunny"))
	var weather_names := {"sunny": "晴天", "thunderstorm": "雷雨天", "drizzle": "细雨", "fog": "大雾", "blizzard": "暴风雪", "scorching_sun": "烈日", "sandstorm": "沙暴", "aurora": "北极光"}
	var weather_label := Label.new()
	weather_label.text = "天气 · " + str(weather_names.get(weather, "晴天"))
	weather_label.position = Vector2(286, 18)
	weather_label.size = Vector2(145, 28)
	weather_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weather_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	weather_label.add_theme_font_size_override("font_size", 11)
	weather_label.add_theme_color_override("font_color", Color("fff7e8"))
	weather_label.add_theme_stylebox_override("normal", _box(Color(0.22, 0.28, 0.32, 0.82), Color("f0d59b"), 1, 3))
	add_child(weather_label)

	_event_label = Label.new()
	_event_label.position = Vector2(475, 92)
	_event_label.size = Vector2(330, 34)
	_event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_event_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_event_label.add_theme_font_size_override("font_size", 14)
	_event_label.add_theme_color_override("font_color", Color("fff9e8"))
	_event_label.add_theme_stylebox_override("normal", _box(Color(0.27, 0.15, 0.18, 0.86), Color("f1d895"), 2, 0))
	add_child(_event_label)

	var speed_btn := HoverHintButton.new()
	speed_btn.text = "×0.75"
	speed_btn.position = Vector2(1154, 18)
	speed_btn.size = Vector2(54, 34)
	_style_icon_button(speed_btn)
	speed_btn.tooltip_text = "战斗速度"
	speed_btn.pressed.connect(func():
		if _speed < 1.0:
			_speed = 1.0
			speed_btn.text = "×1"
		elif _speed < 2.0:
			_speed = 2.0
			speed_btn.text = "×2"
		else:
			_speed = 0.75
			speed_btn.text = "×0.75"
	)
	add_child(speed_btn)
	var skip_btn := HoverHintButton.new()
	skip_btn.text = "≫"
	skip_btn.position = Vector2(1214, 18)
	skip_btn.size = Vector2(44, 34)
	_style_icon_button(skip_btn)
	skip_btn.tooltip_text = "跳过战斗"
	skip_btn.pressed.connect(func(): _skip = true)
	add_child(skip_btn)


func _create_unit(data: Dictionary, side: String, pos: Vector2, texture_path: String, sprite_size: Vector2) -> void:
	var root := Control.new()
	root.position = pos
	root.size = Vector2(180, 120)
	add_child(root)
	var sprite := TextureRect.new()
	sprite.name = "Sprite"
	sprite.position = Vector2((180.0 - sprite_size.x) * 0.5, -sprite_size.y + 70)
	sprite.size = sprite_size
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(texture_path):
		sprite.texture = load(texture_path)
	root.add_child(sprite)

	var name_label := Label.new()
	name_label.text = str(data.get("display_name", data.get("name", "敌人")))
	name_label.position = Vector2(0, 71)
	name_label.size = Vector2(180, 20)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 12)
	_text_outline(name_label, Color.WHITE, 2)
	root.add_child(name_label)

	var hp_frame := Panel.new()
	hp_frame.name = "HPFrame"
	hp_frame.position = Vector2(5, 91)
	hp_frame.size = Vector2(170, 20)
	hp_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_frame.add_theme_stylebox_override("panel", _box(Color("392f34"), Color("fff9ee"), 2, 1))
	root.add_child(hp_frame)
	var max_hp := maxf(float(data.get("max_hp", 1)), 1.0)
	var current_hp := float(data.get("current_hp", data.get("max_hp", 1)))
	var hp := ColorRect.new()
	hp.name = "HP"
	hp.position = Vector2(8, 94)
	hp.size = Vector2(164.0 * clampf(current_hp / max_hp, 0.0, 1.0), 14)
	hp.color = HP_COLOR if side == "player" else Color("c33a4c")
	hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hp)

	var shield := ColorRect.new()
	shield.name = "Shield"
	shield.position = Vector2(8, 94)
	shield.size = Vector2(0, 14)
	shield.color = Color(SHIELD_COLOR, 0.34)
	shield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shield)
	var hp_text := Label.new()
	hp_text.name = "HPText"
	hp_text.text = "%d / %d" % [int(current_hp), int(max_hp)]
	hp_text.position = Vector2(5, 91)
	hp_text.size = Vector2(170, 20)
	hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_text.add_theme_font_size_override("font_size", 9)
	_text_outline(hp_text, Color.WHITE, 1)
	root.add_child(hp_text)

	var statuses := HBoxContainer.new()
	statuses.name = "Statuses"
	statuses.position = Vector2(28, 120)
	statuses.size = Vector2(124, 26)
	statuses.alignment = BoxContainer.ALIGNMENT_CENTER
	statuses.add_theme_constant_override("separation", 4)
	root.add_child(statuses)

	var key := _key(side, int(data.get("id", 0)))
	_units[key] = root
	_unit_data[key] = {"max_hp": max_hp, "current_hp": current_hp, "shield": 0.0, "name": name_label.text, "is_boss": bool(data.get("is_boss", false))}
	_unit_data[key]["row"] = str(data.get("row", "front"))
	_unit_data[key]["alive"] = true
	if bool(data.get("is_boss", false)):
		_boss_key = key


func _build_boss_hud() -> void:
	if _boss_key.is_empty() or not _units.has(_boss_key):
		return
	var data: Dictionary = _unit_data[_boss_key]
	var title := Label.new()
	title.text = str(data.get("name", "BOSS"))
	title.position = Vector2(480, 14)
	title.size = Vector2(320, 25)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 19)
	_text_outline(title, Color("ffe393"), 2)
	add_child(title)
	_boss_hp = ProgressBar.new()
	_boss_hp.position = Vector2(360, 43)
	_boss_hp.size = Vector2(560, 24)
	_boss_hp.show_percentage = false
	_boss_hp.max_value = float(data.get("max_hp", 1.0))
	_boss_hp.value = float(data.get("current_hp", _boss_hp.max_value))
	_boss_hp.add_theme_stylebox_override("background", _box(Color("382d35"), Color("fff8e7"), 2, 0))
	_boss_hp.add_theme_stylebox_override("fill", _box(SHRINE, Color.TRANSPARENT, 0, 0))
	add_child(_boss_hp)
	_boss_hp_text = Label.new()
	_boss_hp_text.position = _boss_hp.position
	_boss_hp_text.size = _boss_hp.size
	_boss_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_hp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_boss_hp_text.add_theme_font_size_override("font_size", 11)
	_text_outline(_boss_hp_text, Color.WHITE, 1)
	_update_boss_hp(_boss_hp.value, _boss_hp.max_value)
	add_child(_boss_hp_text)


func _build_challenge_hud() -> void:
	var panel := Panel.new()
	panel.position = Vector2(355, 15)
	panel.size = Vector2(570, 62)
	panel.add_theme_stylebox_override("panel", _box(Color(0.27, 0.17, 0.20, 0.92), Color("fff3c7"), 2, 2))
	add_child(panel)
	_challenge_time = _challenge_stat(panel, Vector2(10, 6), Vector2(135, 50), "剩余时间", "01:00", Color("ffe078"), 23)
	_challenge_damage = _challenge_stat(panel, Vector2(150, 6), Vector2(270, 50), "累计总伤害", "0", Color("fff4cc"), 25)
	_challenge_dps = _challenge_stat(panel, Vector2(425, 6), Vector2(135, 50), "当前 DPS", "0", Color("86e6c0"), 18)
	_challenge_rank = Label.new()
	_challenge_rank.position = Vector2(420, 80)
	_challenge_rank.size = Vector2(440, 21)
	_challenge_rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_challenge_rank.text = "铜 5千　银 2.5万　金 10万　传说 25万　神话 50万"
	_challenge_rank.add_theme_font_size_override("font_size", 10)
	_challenge_rank.add_theme_color_override("font_color", Color("71575d"))
	_challenge_rank.add_theme_stylebox_override("normal", _box(Color(1, 0.98, 0.95, 0.84), Color("b99769"), 1, 2))
	add_child(_challenge_rank)


func _challenge_stat(parent: Control, pos: Vector2, stat_size: Vector2, caption: String, value: String, color: Color, font_size: int) -> Label:
	var caption_label := Label.new()
	caption_label.position = pos
	caption_label.size = Vector2(stat_size.x, 16)
	caption_label.text = caption
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption_label.add_theme_font_size_override("font_size", 9)
	caption_label.add_theme_color_override("font_color", Color("e4ced0"))
	parent.add_child(caption_label)
	var label := Label.new()
	label.position = pos + Vector2(0, 17)
	label.size = Vector2(stat_size.x, stat_size.y - 17)
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	_text_outline(label, color, 1)
	parent.add_child(label)
	return label


func _build_footer() -> void:
	_combat_log = RichTextLabel.new()
	_combat_log.position = Vector2(18, 426)
	_combat_log.size = Vector2(320, 86)
	_combat_log.bbcode_enabled = true
	_combat_log.fit_content = false
	_combat_log.scroll_active = true
	_combat_log.scroll_following = false
	_combat_log.custom_minimum_size = Vector2(320, 86)
	_combat_log.add_theme_font_size_override("normal_font_size", 10)
	_combat_log.add_theme_color_override("default_color", Color("4b393d"))
	_combat_log.add_theme_stylebox_override("normal", _box(Color(1, 0.98, 0.95, 0.88), SHRINE, 2, 2))
	add_child(_combat_log)
	var combat_scroll := _combat_log.get_v_scroll_bar()
	combat_scroll.value_changed.connect(func(value: float):
		if _combat_log_updating:
			return
		_combat_log_at_top = value <= 0.5
	)
	var hint := Label.new()
	hint.text = "点击状态图标查看效果"
	hint.position = Vector2(1040, 490)
	hint.size = Vector2(220, 20)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_font_size_override("font_size", 9)
	hint.add_theme_color_override("font_color", Color("654e54"))
	add_child(hint)


func _build_status_tip() -> void:
	_status_tip_overlay = Button.new()
	_status_tip_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_status_tip_overlay.flat = true
	_status_tip_overlay.z_index = 89
	_status_tip_overlay.visible = false
	_status_tip_overlay.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_status_tip_overlay.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	_status_tip_overlay.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	_status_tip_overlay.pressed.connect(_hide_status_tip)
	add_child(_status_tip_overlay)

	_status_tip = Panel.new()
	_status_tip.z_index = 90
	_status_tip.size = Vector2(255, 118)
	_status_tip.visible = false
	_status_tip.mouse_filter = Control.MOUSE_FILTER_STOP
	_status_tip.add_theme_stylebox_override("panel", _box(Color(0.17, 0.13, 0.15, 0.97), Color("f0d28b"), 2, 5))
	add_child(_status_tip)
	_status_tip_title = Label.new()
	_status_tip_title.position = Vector2(12, 9)
	_status_tip_title.size = Vector2(231, 22)
	_status_tip_title.add_theme_font_size_override("font_size", 14)
	_status_tip_title.add_theme_color_override("font_color", Color("ffe294"))
	_status_tip.add_child(_status_tip_title)
	_status_tip_body = Label.new()
	_status_tip_body.position = Vector2(12, 35)
	_status_tip_body.size = Vector2(231, 74)
	_status_tip_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_tip_body.add_theme_font_size_override("font_size", 11)
	_status_tip_body.add_theme_color_override("font_color", Color("f7eef0"))
	_status_tip.add_child(_status_tip_body)


func _play() -> void:
	await get_tree().create_timer(0.45).timeout
	var events: Array = _edata.get("battle_result", {}).get("events", [])
	for index in range(events.size()):
		if _skip:
			break
		if _kind == "challenge":
			_update_challenge_clock(index, events.size())
		await _play_event(events[index] as Dictionary)
	_show_result()


func _play_event(event: Dictionary) -> void:
	match str(event.get("type", "")):
		"cast":
			await _play_cast(event)
		"damage":
			await _play_damage(event)
		"heal":
			await _play_gain(event, Color("72e89b"), "+")
		"shield":
			await _play_gain(event, SHIELD_COLOR, "护盾+")
		"status":
			var status_target := _find_unit(event.get("target", {}))
			var status_name := str(event.get("status", "状态"))
			if status_target:
				_float_number(status_target, status_name, Color("72b9ff"), 16)
				_add_status(status_target, status_name, float(event.get("duration", 0.0)))
			_log_line("%s 获得状态：%s" % [str(event.get("target", {}).get("name", "单位")), status_name], "#7250a0")
			await get_tree().create_timer(0.16 / _speed).timeout
		"summon":
			await _play_summon(event)
		"miss":
			var target := _find_unit(event.get("target", {}))
			if target:
				_float_number(target, "MISS", Color("eeeeee"), 18)
			_log_line("攻击未命中", "#777777")
			await get_tree().create_timer(0.18 / _speed).timeout


func _play_cast(event: Dictionary) -> void:
	var source_name := str(event.get("source", {}).get("name", "单位"))
	var skill_name := str(event.get("label", "攻击"))
	_event_label.text = source_name + " · " + skill_name
	_log_line("%s 使用 %s" % [source_name, skill_name], "#762c39")
	var source := _find_unit(event.get("source", {}))
	if not source:
		return
	var visual := str(event.get("visual", "basic"))
	var source_sprite := source.get_node_or_null("Sprite") as TextureRect
	if not source_sprite:
		return
	_float_action_name(source, source_sprite, skill_name, int(event.get("skill_id", 0)) > 0)
	var original := source_sprite.position
	var direction := 52.0 if str(event.get("source", {}).get("side", "enemy")) == "player" else -52.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(source_sprite, "position", original + Vector2(direction * 0.72, -18.0), 0.10 / _speed)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(source_sprite, "position", original + Vector2(direction, -5.0), 0.07 / _speed)
	tween.tween_property(source_sprite, "position", original, 0.12 / _speed)
	if visual == "melee":
		for target_ref in event.get("targets", []):
			var melee_target := _find_unit(target_ref)
			if melee_target:
				_spawn_slash_impact(melee_target)
	elif visual in ["projectile", "control", "dot", "fire", "ice", "thunder", "poison", "blood"] and not event.get("targets", []).is_empty():
		for target_ref in event.get("targets", []):
			var ranged_target := _find_unit(target_ref)
			if ranged_target:
				_spawn_projectile(source, ranged_target, _visual_color(visual), visual)
	elif visual == "heal":
		for target_ref in event.get("targets", []):
			var heal_target := _find_unit(target_ref)
			if heal_target:
				_spawn_heal_lines(heal_target)
	await tween.finished


func _play_summon(event: Dictionary) -> void:
	var raw_unit: Dictionary = event.get("unit", {}) as Dictionary
	var unit_id := int(raw_unit.get("id", 0))
	if unit_id <= 0:
		return
	var key := _key("enemy", unit_id)
	if _units.has(key):
		return
	var slot := _next_enemy_slot(str(raw_unit.get("row", "front")))
	raw_unit["row"] = slot["row"]
	_create_unit(raw_unit, "enemy", slot["position"], _enemy_texture_path(raw_unit), _enemy_size(raw_unit))
	var unit := _units.get(key, null) as Control
	if unit:
		unit.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(unit, "modulate:a", 1.0, 0.24 / _speed)
	_log_line("%s 被召唤入场" % str(raw_unit.get("name", "召唤物")), "#8b5aa8")
	await get_tree().create_timer(0.24 / _speed).timeout


func _next_enemy_slot(preferred_row: String) -> Dictionary:
	var rows: Array[String] = [preferred_row, "back" if preferred_row == "front" else "front"]
	for row in rows:
		var occupied := 0
		for info in _unit_data.values():
			if bool(info.get("alive", true)) and str(info.get("row", "front")) == row:
				occupied += 1
		if occupied < 3:
			return {"row": row, "position": Vector2(700, 165 + occupied * 115) if row == "front" else Vector2(945, 165 + occupied * 115)}
	return {"row": "back", "position": Vector2(945, 165)}


func _play_damage(event: Dictionary) -> void:
	var target := _find_unit(event.get("target", {}))
	if not target:
		return
	var amount := int(event.get("amount", 0))
	# A server no-op event can occur for a fully absorbed/immune effect. It is
	# still authoritative, but displaying "-0" makes the battle look broken.
	if amount <= 0:
		_update_unit_hp(target, float(event.get("hp", 0)), float(event.get("max_hp", 1)))
		if event.has("shield"):
			_set_unit_shield(target, float(event.get("shield", 0.0)))
		return
	var is_dot := bool(event.get("dot", false))
	var is_crit := bool(event.get("crit", false))
	var color := Color("ca8cff") if is_dot else (Color("ffe066") if is_crit else Color.WHITE)
	var prefix := "盾 " if bool(event.get("block", false)) else "-"
	_float_number(target, prefix + str(amount) + ("!" if is_crit else ""), color, 28 if is_crit else 20)
	_update_unit_hp(target, float(event.get("hp", 0)), float(event.get("max_hp", 1)))
	if event.has("shield"):
		_set_unit_shield(target, float(event.get("shield", 0.0)))
	var ref_key := _key(str(event.get("target", {}).get("side", "enemy")), int(event.get("target", {}).get("id", 0)))
	if ref_key == _boss_key:
		_update_boss_hp(float(event.get("hp", 0)), float(event.get("max_hp", 1)))
	if _kind == "challenge" and str(event.get("target", {}).get("side", "enemy")) == "enemy":
		_challenge_total += maxf(float(amount), 0.0)
		_update_challenge_values()
	if is_dot:
		_add_status(target, str(event.get("label", "持续伤害")), 0.0, "dot")
	_log_line("%s受到 %d 伤害%s" % [str(event.get("target", {}).get("name", "目标")), amount, "（暴击）" if is_crit else ""], "#9b3648" if not is_dot else "#76509b")
	var sprite := target.get_node_or_null("Sprite") as TextureRect
	if sprite:
		var base_position := sprite.position
		var base_scale := sprite.scale
		var base_modulate := sprite.modulate
		var target_side := str(event.get("target", {}).get("side", "enemy"))
		var knockback := -11.0 if target_side == "player" else 11.0
		sprite.pivot_offset = sprite.size * 0.5
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_QUAD)
		tw.set_ease(Tween.EASE_OUT)
		tw.tween_property(sprite, "position", base_position + Vector2(knockback, 1.0), 0.05 / _speed)
		tw.parallel().tween_property(sprite, "scale", base_scale * 0.90, 0.05 / _speed)
		tw.parallel().tween_property(sprite, "modulate", Color(1.0, 0.48, 0.48, 0.38), 0.05 / _speed)
		tw.set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(sprite, "position", base_position + Vector2(knockback * 0.35, 0.0), 0.06 / _speed)
		tw.parallel().tween_property(sprite, "scale", base_scale * 1.03, 0.06 / _speed)
		tw.parallel().tween_property(sprite, "modulate", base_modulate, 0.06 / _speed)
		tw.tween_property(sprite, "position", base_position, 0.06 / _speed)
		tw.parallel().tween_property(sprite, "scale", base_scale, 0.06 / _speed)
		await tw.finished
	else:
		await get_tree().create_timer(0.17 / _speed).timeout


func _play_gain(event: Dictionary, color: Color, prefix: String) -> void:
	var target := _find_unit(event.get("target", {}))
	if target:
		var amount := int(event.get("amount", 0))
		if amount <= 0:
			_update_unit_hp(target, float(event.get("hp", 0)), float(event.get("max_hp", 1)))
			return
		_float_number(target, prefix + str(amount), color, 20)
		if prefix == "+":
			_spawn_heal_lines(target)
		if event.has("hp"):
			_update_unit_hp(target, float(event.get("hp", 0)), float(event.get("max_hp", 1)))
		if prefix.begins_with("护盾"):
			_set_unit_shield(target, float(event.get("shield", float(_unit_data.get(_key_for_unit(target), {}).get("shield", 0.0)) + amount)))
			_add_status(target, "护盾", 5.0, "shield")
		_log_line("%s %s%d" % [str(event.get("target", {}).get("name", "单位")), prefix, amount], "#297c64" if prefix == "+" else "#367ca6")
	await get_tree().create_timer(0.20 / _speed).timeout


func _update_unit_hp(target: Control, hp_value: float, max_hp: float) -> void:
	var hp := target.get_node_or_null("HP") as ColorRect
	if not hp:
		return
	var key := _key_for_unit(target)
	if not key.is_empty():
		_unit_data[key]["max_hp"] = maxf(max_hp, 1.0)
		_unit_data[key]["current_hp"] = hp_value
		_unit_data[key]["alive"] = hp_value > 0.0
		if hp_value <= 0.0:
			target.visible = false
		elif not target.visible:
			target.visible = true
	create_tween().tween_property(hp, "size:x", 164.0 * clampf(hp_value / maxf(max_hp, 1.0), 0.0, 1.0), 0.18 / _speed)
	var text := target.get_node_or_null("HPText") as Label
	if text:
		var shield_value := float(_unit_data.get(key, {}).get("shield", 0.0))
		text.text = "%d / %d%s" % [int(hp_value), int(max_hp), "　盾 %d" % int(shield_value) if shield_value > 0 else ""]


func _set_unit_shield(target: Control, shield_value: float) -> void:
	var key := _key_for_unit(target)
	if key.is_empty():
		return
	var info: Dictionary = _unit_data[key]
	info["shield"] = maxf(0.0, shield_value)
	var max_hp := maxf(float(info.get("max_hp", 1.0)), 1.0)
	var overlay := target.get_node_or_null("Shield") as ColorRect
	if overlay:
		overlay.size.x = 164.0 * minf(float(info["shield"]) / max_hp, 1.0)
	var text := target.get_node_or_null("HPText") as Label
	if text:
		text.text = "%d / %d　盾 %d" % [int(info.get("current_hp", 0.0)), int(info.get("max_hp", 1.0)), int(info["shield"])]


func _add_status(target: Control, status_name: String, duration: float, kind: String = "status") -> void:
	var row := target.get_node_or_null("Statuses") as HBoxContainer
	if not row:
		return
	var node_name := "Status_" + status_name.validate_node_name()
	var existing := row.get_node_or_null(node_name) as Button
	if existing:
		existing.set_meta("duration", duration)
		existing.text = _status_icon(status_name) + (" %ds" % int(ceil(duration)) if duration > 0 else "")
		existing.tooltip_text = _status_hover_text(status_name, duration)
		return
	if row.get_child_count() >= 5:
		row.get_child(0).queue_free()
	var button := HoverHintButton.new()
	button.name = node_name
	button.custom_minimum_size = Vector2(28, 24)
	button.text = _status_icon(status_name) + (" %ds" % int(ceil(duration)) if duration > 0 else "")
	button.add_theme_font_size_override("font_size", 9)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _box(_status_color(status_name, kind), Color.WHITE, 1, 4))
	button.add_theme_stylebox_override("hover", _box(_status_color(status_name, kind).lightened(0.15), GOLD, 2, 4))
	button.set_meta("status_name", status_name)
	button.set_meta("duration", duration)
	button.set_meta("kind", kind)
	button.tooltip_text = _status_hover_text(status_name, duration)
	button.pressed.connect(_show_status_tip.bind(button))
	row.add_child(button)


func _show_status_tip(button: Button) -> void:
	var status_name := str(button.get_meta("status_name", "状态"))
	var duration := float(button.get_meta("duration", 0.0))
	_status_tip_title.text = status_name
	_status_tip_body.text = _status_description(status_name) + ("\n剩余时间：%.1f 秒" % duration if duration > 0 else "\n持续次数和剩余时间以战斗事件为准。")
	_status_tip_overlay.visible = true
	_status_tip.visible = true
	await get_tree().process_frame
	var button_rect := button.get_global_rect()
	var view_rect := get_global_rect()
	var local_anchor := button_rect.position - view_rect.position
	var tip_pos := Vector2(local_anchor.x + button_rect.size.x * 0.5 - _status_tip.size.x * 0.5, local_anchor.y - _status_tip.size.y - 8.0)
	if tip_pos.y < 8.0:
		tip_pos.y = local_anchor.y + button_rect.size.y + 8.0
	tip_pos.x = clampf(tip_pos.x, 8.0, maxf(8.0, size.x - _status_tip.size.x - 8.0))
	tip_pos.y = clampf(tip_pos.y, 8.0, maxf(8.0, size.y - _status_tip.size.y - 8.0))
	_status_tip.position = tip_pos


func _hide_status_tip() -> void:
	_status_tip.visible = false
	_status_tip_overlay.visible = false


func _status_hover_text(status_name: String, duration: float) -> String:
	return status_name + "\n" + _status_description(status_name) + ("\n剩余时间：%.1f 秒" % duration if duration > 0 else "")


func _status_description(status_name: String) -> String:
	var descriptions := {
		"护盾": "优先吸收即将受到的伤害。显示长度以最大生命值为上限，超过后只增加护盾数字。",
		"冻结": "无法行动；受到直接攻击时伤害提高50%，随后解除冻结。",
		"眩晕": "无法行动，直到持续时间结束。",
		"沉默": "无法释放技能，但仍可进行普通攻击。",
		"麻痹": "技能行动间隔增加30%，仍可正常行动。",
		"减速": "出手间隔延长50%，不影响Dot和Hot的真实秒数计时。",
		"禁疗": "受到的治疗效果降低50%。",
		"中毒": "按独立真实秒数计时造成持续伤害，不受防御、暴击和格挡影响。",
		"灼烧": "按独立真实秒数计时造成火焰持续伤害，可与烈焰套装联动。",
		"流血": "按独立真实秒数计时造成持续伤害。",
	}
	return str(descriptions.get(status_name, "该状态正在影响单位。点击其他状态图标可切换查看。"))


func _status_icon(status_name: String) -> String:
	return str({"护盾": "盾", "冻结": "冻", "眩晕": "晕", "沉默": "默", "麻痹": "麻", "减速": "缓", "禁疗": "禁", "中毒": "毒", "灼烧": "火", "流血": "血"}.get(status_name, status_name.left(1)))


func _status_color(status_name: String, kind: String) -> Color:
	if kind == "shield": return Color("3f8c91")
	if kind == "dot" or status_name in ["中毒", "灼烧", "流血"]: return Color("8c536b")
	return Color("4f7eaa")


func _spawn_projectile(source: Control, target: Control, color: Color, visual: String) -> void:
	var shot := ColorRect.new()
	shot.color = color
	shot.size = Vector2(22, 10)
	shot.position = source.position + Vector2(90, 35)
	shot.add_theme_stylebox_override("panel", _box(color, Color.WHITE, 1, 5))
	add_child(shot)
	var tw := create_tween()
	tw.tween_property(shot, "position", target.position + Vector2(90, 35), 0.18 / _speed)
	tw.tween_callback(_spawn_ranged_impact.bind(target, visual))
	tw.tween_callback(shot.queue_free)


func _spawn_slash_impact(target: Control) -> void:
	var effect := Node2D.new()
	effect.position = target.position + Vector2(90, 36)
	effect.z_index = 45
	add_child(effect)
	for stroke in [{"width": 11.0, "color": Color("fff1b0")}, {"width": 4.0, "color": Color("d95470")}]:
		var slash := Line2D.new()
		slash.points = PackedVector2Array([Vector2(-40, 34), Vector2(40, -38)])
		slash.width = float(stroke["width"])
		slash.default_color = stroke["color"]
		slash.begin_cap_mode = Line2D.LINE_CAP_ROUND
		slash.end_cap_mode = Line2D.LINE_CAP_ROUND
		effect.add_child(slash)
	effect.scale = Vector2(0.25, 0.25)
	var tween := create_tween()
	tween.tween_property(effect, "scale", Vector2.ONE, 0.08 / _speed)
	tween.tween_property(effect, "scale", Vector2(1.25, 1.25), 0.10 / _speed)
	tween.parallel().tween_property(effect, "modulate:a", 0.0, 0.10 / _speed)
	tween.tween_callback(effect.queue_free)


func _spawn_heal_lines(target: Control) -> void:
	for i in range(14):
		var line := ColorRect.new()
		line.color = Color("45dd79") if i % 3 else Color("a5f2b5")
		line.size = Vector2(3, 14)
		line.position = target.position + Vector2(48 + (i % 7) * 12, 48 + (i / 7) * 12)
		line.z_index = 44
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(line)
		line.modulate.a = 0.0
		var delay := float(i % 7) * 0.025 / _speed
		var tween := create_tween()
		tween.tween_interval(delay)
		tween.tween_property(line, "modulate:a", 1.0, 0.06 / _speed)
		tween.parallel().tween_property(line, "position:y", line.position.y - 72.0 - float(i % 3) * 10.0, 0.42 / _speed)
		tween.tween_property(line, "modulate:a", 0.0, 0.12 / _speed)
		tween.tween_callback(line.queue_free)


func _spawn_ranged_impact(target: Control, visual: String) -> void:
	match visual:
		"fire": _spawn_burst_particles(target, Color("ff673d"), Color("ffd45d"), "triangle")
		"thunder": _spawn_lightning_impact(target)
		"poison", "dot": _spawn_burst_particles(target, Color("72cf58"), Color("a85ac7"), "bubble")
		"ice", "control": _spawn_burst_particles(target, Color("6edaff"), Color("d3f7ff"), "diamond")
		_: _spawn_impact_ring(target, Color("b8ebff"))


func _spawn_impact_ring(target: Control, color: Color) -> void:
	var ring := Line2D.new()
	var points := PackedVector2Array()
	for i in range(25):
		var angle := TAU * float(i) / 24.0
		points.append(Vector2(cos(angle), sin(angle)) * 18.0)
	ring.points = points
	ring.width = 5.0
	ring.default_color = color
	ring.position = target.position + Vector2(90, 36)
	ring.z_index = 44
	add_child(ring)
	var tween := create_tween()
	tween.tween_property(ring, "scale", Vector2(2.8, 2.8), 0.16 / _speed)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.16 / _speed)
	tween.tween_callback(ring.queue_free)


func _spawn_burst_particles(target: Control, primary: Color, secondary: Color, shape: String) -> void:
	for i in range(12):
		var particle := Polygon2D.new()
		match shape:
			"triangle": particle.polygon = PackedVector2Array([Vector2(0, -7), Vector2(5, 6), Vector2(-5, 6)])
			"diamond": particle.polygon = PackedVector2Array([Vector2(0, -9), Vector2(5, 0), Vector2(0, 9), Vector2(-5, 0)])
			_: particle.polygon = _circle_polygon(5.0, 10)
		particle.color = primary if i % 2 else secondary
		particle.position = target.position + Vector2(90, 36)
		particle.z_index = 44
		add_child(particle)
		var angle := TAU * float(i) / 12.0 + randf_range(-0.14, 0.14)
		var distance := randf_range(32.0, 64.0)
		var destination := particle.position + Vector2(cos(angle), sin(angle)) * distance
		if shape == "bubble":
			destination.y -= 32.0
		var tween := create_tween()
		tween.tween_property(particle, "position", destination, 0.22 / _speed)
		tween.parallel().tween_property(particle, "rotation", angle + 1.4, 0.22 / _speed)
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.22 / _speed)
		tween.tween_callback(particle.queue_free)


func _spawn_lightning_impact(target: Control) -> void:
	var effect := Node2D.new()
	effect.position = target.position + Vector2(90, 38)
	effect.z_index = 45
	add_child(effect)
	for offset in [-18.0, 0.0, 18.0]:
		var bolt := Line2D.new()
		bolt.points = PackedVector2Array([Vector2(offset - 12, -82), Vector2(offset + 8, -55), Vector2(offset - 7, -28), Vector2(offset + 10, 2)])
		bolt.width = 5.0
		bolt.default_color = Color("fff06b") if offset == 0.0 else Color("8ee8ff")
		bolt.begin_cap_mode = Line2D.LINE_CAP_ROUND
		bolt.end_cap_mode = Line2D.LINE_CAP_ROUND
		effect.add_child(bolt)
	var tween := create_tween()
	tween.tween_interval(0.06 / _speed)
	tween.tween_property(effect, "modulate:a", 0.0, 0.12 / _speed)
	tween.tween_callback(effect.queue_free)


func _circle_polygon(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(segments):
		var angle := TAU * float(i) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


func _float_number(target: Control, text: String, color: Color, font_size: int) -> void:
	var label := Label.new()
	label.text = text
	label.position = target.position + Vector2(42, -42)
	label.size = Vector2(150, 42)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	_text_outline(label, color, 3)
	label.z_index = 50
	add_child(label)
	var tw := create_tween()
	tw.tween_property(label, "position:y", label.position.y - 46, 0.55 / _speed)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.55 / _speed)
	tw.tween_callback(label.queue_free)


func _float_action_name(source: Control, sprite: TextureRect, action_name: String, is_skill: bool) -> void:
	var label := Label.new()
	label.text = action_name
	label.position = source.position + Vector2(0, sprite.position.y - 30.0)
	label.size = Vector2(180, 30)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 17 if is_skill else 15)
	_text_outline(label, Color("ffe58c") if is_skill else Color.WHITE, 4)
	label.z_index = 60
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y - 18.0, 0.38 / _speed)
	tween.tween_interval(0.12 / _speed)
	tween.tween_property(label, "modulate:a", 0.0, 0.18 / _speed)
	tween.tween_callback(label.queue_free)


func _update_boss_hp(value: float, max_hp: float) -> void:
	if not _boss_hp or not _boss_hp_text:
		return
	_boss_hp.max_value = maxf(max_hp, 1.0)
	create_tween().tween_property(_boss_hp, "value", value, 0.18 / _speed)
	_boss_hp_text.text = "%d / %d" % [int(value), int(max_hp)]


func _update_challenge_clock(index: int, event_count: int) -> void:
	var total_elapsed := float(_edata.get("battle_result", {}).get("elapsed", 60.0))
	_challenge_elapsed = total_elapsed * float(index) / maxf(float(event_count), 1.0)
	_update_challenge_values()


func _update_challenge_values() -> void:
	if not _challenge_time:
		return
	var remaining := maxi(0, int(ceil(60.0 - _challenge_elapsed)))
	_challenge_time.text = "%02d:%02d" % [remaining / 60, remaining % 60]
	_challenge_damage.text = _format_number(int(_challenge_total))
	_challenge_dps.text = _format_number(int(_challenge_total / maxf(_challenge_elapsed, 1.0)))
	var rank_name := "未达铜"
	for item in [[500000, "神话"], [250000, "传说"], [100000, "金"], [25000, "银"], [5000, "铜"]]:
		if _challenge_total >= float(item[0]):
			rank_name = str(item[1])
			break
	_challenge_rank.text = "当前档位：%s　　铜 5千　银 2.5万　金 10万　传说 25万　神话 50万" % rank_name


func _log_line(text: String, color: String) -> void:
	if not _combat_log:
		return
	var old_scroll := _combat_log.get_v_scroll_bar().value
	_combat_lines.push_front("[color=%s]%s[/color]" % [color, text])
	_combat_log_updating = true
	_combat_log.text = "\n".join(_combat_lines)
	if _combat_log_at_top:
		_combat_log.get_v_scroll_bar().value = 0.0
	else:
		_combat_log.get_v_scroll_bar().value = old_scroll
	_combat_log_updating = false


func _show_result() -> void:
	_hide_status_tip()
	_event_label.text = ""
	var result: Dictionary = _edata.get("battle_result", {})
	var outcome := int(result.get("outcome", 2))
	var victory := outcome == 0 or outcome == 3
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.05, 0.04, 0.06, 0.72)
	shade.z_index = 100
	add_child(shade)
	var panel := Panel.new()
	panel.position = Vector2(390, 105)
	panel.size = Vector2(500, 320)
	panel.z_index = 101
	panel.add_theme_stylebox_override("panel", _box(PAPER, SHRINE_DARK, 3, 5))
	add_child(panel)
	var title := Label.new()
	title.text = "挑战完成" if _kind == "challenge" else ("战斗胜利" if victory else "战斗失败")
	title.position = Vector2(20, 22)
	title.size = Vector2(460, 46)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", GOLD if victory else Color("d54f5c"))
	panel.add_child(title)
	var detail := Label.new()
	detail.text = "用时 %.1f 秒　行动 %d 次\n造成伤害 %s\n金币 %+d　经验 %+d" % [float(result.get("elapsed", 0.0)), int(result.get("rounds", 0)), _format_number(int(result.get("damage_total", 0))), int(_edata.get("gold_gain", 0)) - int(_edata.get("gold_penalty", 0)), int(_edata.get("exp_gain", 0))]
	if _kind == "challenge":
		detail.text = "60 秒伤害验证完成\n累计总伤害 %s\n最终 DPS %s\n金币 %+d　经验 %+d" % [_format_number(int(result.get("damage_total", 0))), _format_number(int(float(result.get("damage_total", 0)) / maxf(float(result.get("elapsed", 60.0)), 1.0))), int(_edata.get("gold_gain", 0)), int(_edata.get("exp_gain", 0))]
	var drop_count := int(_edata.get("drops", []).size())
	if drop_count > 0: detail.text += "\n装备掉落 ×%d" % drop_count
	if bool(_edata.get("revive_used", false)): detail.text += "\n消耗复活币 ×1"
	elif bool(_edata.get("force_home", false)): detail.text += "\n金币损失 %d，返回起点" % int(_edata.get("gold_penalty", 0))
	detail.position = Vector2(40, 85)
	detail.size = Vector2(420, 145)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.add_theme_font_size_override("font_size", 17)
	detail.add_theme_color_override("font_color", INK)
	panel.add_child(detail)
	var confirm := Button.new()
	confirm.text = "领取并返回地图" if victory else "确认"
	confirm.position = Vector2(145, 252)
	confirm.size = Vector2(210, 44)
	confirm.add_theme_stylebox_override("normal", _box(SHRINE, SHRINE_DARK, 2, 5))
	confirm.add_theme_stylebox_override("hover", _box(SHRINE.lightened(0.12), GOLD, 2, 5))
	confirm.add_theme_color_override("font_color", Color.WHITE)
	confirm.pressed.connect(_close_result)
	panel.add_child(confirm)
	if auto_continue:
		get_tree().create_timer(1.0).timeout.connect(_close_result)


func _close_result() -> void:
	if _result_closed:
		return
	_result_closed = true
	closed.emit()
	queue_free()


func _enemy_texture_path(unit: Dictionary) -> String:
	if bool(unit.get("is_boss", false)):
		var boss_path := BOSS_DIR + str(unit.get("name", "")) + ".png"
		if ResourceLoader.exists(boss_path): return boss_path
	var asset_name := str(unit.get("asset", ""))
	if not asset_name.is_empty():
		var explicit_path := MONSTER_DIR + asset_name
		if ResourceLoader.exists(explicit_path): return explicit_path
	var idx: int = int(abs(str(unit.get("name", "怪物")).hash()) % SMALL_ASSETS.size())
	var fallback := MONSTER_DIR + SMALL_ASSETS[idx]
	return fallback if ResourceLoader.exists(fallback) else MONSTER_DIR + "char_0001.png"


func _enemy_size(unit: Dictionary) -> Vector2:
	return Vector2(120, 190) if bool(unit.get("is_boss", false)) else Vector2(88, 88)


func _find_unit(ref: Dictionary) -> Control:
	return _units.get(_key(str(ref.get("side", "enemy")), int(ref.get("id", 0))), null) as Control


func _key(side: String, id: int) -> String:
	return side + ":" + str(id)


func _key_for_unit(unit: Control) -> String:
	for key in _units:
		if _units[key] == unit: return str(key)
	return ""


func _visual_color(visual: String) -> Color:
	return {"control": Color("75bfff"), "dot": Color("9c65c7"), "projectile": Color("ffd66b"), "fire": Color("ff673d"), "ice": Color("6edaff"), "thunder": Color("fff06b"), "poison": Color("73d45b"), "blood": Color("d94b5f")}.get(visual, Color.WHITE)


func _format_number(value: int) -> String:
	var raw := str(absi(value))
	var output := ""
	while raw.length() > 3:
		output = "," + raw.right(3) + output
		raw = raw.left(raw.length() - 3)
	return ("-" if value < 0 else "") + raw + output


func _text_outline(label: Label, color: Color, outline: int) -> void:
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", outline)


func _style_icon_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _box(Color(1, 0.98, 0.95, 0.94), Color("75565b"), 1, 5))
	button.add_theme_stylebox_override("hover", _box(Color.WHITE, SHRINE, 2, 5))
	button.add_theme_stylebox_override("pressed", _box(Color("f1dfe0"), SHRINE_DARK, 2, 5))
	button.add_theme_stylebox_override("focus", _box(Color("fff7f1"), GOLD, 2, 5))
	for color_key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(color_key, Color("4b3036"))
	button.add_theme_font_size_override("font_size", 13)


func _box(bg: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_width_left = width
	style.border_width_right = width
	style.border_width_top = width
	style.border_width_bottom = width
	style.border_color = border
	style.set_corner_radius_all(radius)
	return style
