class_name TopBar
extends RefCounted

const INK := Color("352e38")
const MUTED := Color("746672")
const SURFACE := Color("fff9f5")
const SURFACE_2 := Color("f4e8e7")
const PRIMARY := Color("c94a55")
const PRIMARY_DARK := Color("96353e")
const GOLD := Color("d9a441")
const GOOD := Color("78a98c")
const LINE := Color("b88d89")

var main_game


func _init(mg):
	main_game = mg


func _label(parent: Node, node_name: String, text: String, pos: Vector2, font_size: int, color: Color = INK) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _card(parent: Node, pos: Vector2, card_size: Vector2) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = card_size
	UIUtils.shrine_panel_style(panel, SURFACE_2, LINE, 1)
	parent.add_child(panel)
	return panel


func build() -> void:
	var bar := Panel.new()
	bar.name = "TopBar"
	bar.position = Vector2.ZERO
	bar.size = Vector2(1280, 104)
	UIUtils.shrine_panel_style(bar, SURFACE, LINE, 2)

	# 角色核心区
	var avatar_frame := Panel.new()
	avatar_frame.position = Vector2(12, 10)
	avatar_frame.size = Vector2(76, 82)
	UIUtils.shrine_panel_style(avatar_frame, SURFACE_2, PRIMARY, 2)
	bar.add_child(avatar_frame)

	var avatar_tex := load("res://assets/主角.png")
	if avatar_tex:
		var avatar := TextureRect.new()
		avatar.name = "AvatarImg"
		avatar.position = Vector2(2, 2)
		avatar.size = Vector2(72, 78)
		avatar.texture = avatar_tex
		avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		avatar_frame.add_child(avatar)

	var avatar_btn := Button.new()
	avatar_btn.name = "AvatarBtn"
	avatar_btn.position = Vector2(12, 10)
	avatar_btn.size = Vector2(76, 82)
	UIUtils.btn_transparent2(avatar_btn)
	avatar_btn.pressed.connect(main_game._open_stats_panel)
	bar.add_child(avatar_btn)

	var name_label := _label(bar, "NameLabel", "%s  Lv.%d" % [main_game.player_name, main_game.player_level], Vector2(100, 12), 18, INK)
	name_label.size = Vector2(330, 28)

	_label(bar, "ExpCaption", "经验", Vector2(100, 52), 10, MUTED)
	var exp_bar := ProgressBar.new()
	exp_bar.name = "ExpBar"
	exp_bar.position = Vector2(137, 51)
	exp_bar.size = Vector2(289, 18)
	exp_bar.show_percentage = false
	exp_bar.max_value = main_game.player_exp_max
	exp_bar.value = main_game.player_exp
	UIUtils.bar_style_light(exp_bar, Color("46558c"), SURFACE_2, LINE)
	bar.add_child(exp_bar)
	var exp_lbl := _label(bar, "ExpLabel", "", Vector2(137, 50), 10, Color.WHITE)
	exp_lbl.size = Vector2(289, 20)
	exp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	exp_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	exp_lbl.add_theme_constant_override("outline_size", 2)
	exp_lbl.add_theme_color_override("font_outline_color", Color("352e38"))
	exp_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sep_left := VSeparator.new()
	sep_left.position = Vector2(440, 10)
	sep_left.size = Vector2(2, 82)
	bar.add_child(sep_left)

	# 常用资源区
	var gold_card := _card(bar, Vector2(456, 22), Vector2(102, 60))
	_label(gold_card, "GoldCaption", "金币", Vector2(39, 7), 9, MUTED)
	_label(gold_card, "GoldIcon", "●", Vector2(12, 20), 18, GOLD)
	_label(bar, "GoldLabel", str(main_game.player_gold), Vector2(495, 46), 16, Color("a56f00"))

	var life_card := _card(bar, Vector2(566, 22), Vector2(102, 60))
	_label(life_card, "LifeCaption", "复活次数", Vector2(37, 7), 9, MUTED)
	_label(life_card, "LifeIcon", "♥", Vector2(10, 18), 22, PRIMARY)
	_label(bar, "ReviveLabel", str(main_game.player_revive) + " / " + str(main_game.player_max_revive), Vector2(603, 46), 15, PRIMARY)

	var reward_card := _card(bar, Vector2(676, 22), Vector2(104, 60))
	_label(reward_card, "RewardCaption", "掷骰奖励", Vector2(36, 7), 9, MUTED)
	_label(reward_card, "RewardIcon", "✦", Vector2(10, 19), 20, GOLD)
	var reward_lbl := _label(bar, "DiceRewardLabel", "过起点 +50金", Vector2(710, 46), 11, GOOD)
	reward_lbl.size = Vector2(68, 30)

	# 保留逻辑引用，花色历史不再常驻展示。
	var dice_hist := _label(bar, "DiceHistLabel", "", Vector2(456, 84), 1, Color.TRANSPARENT)
	dice_hist.visible = false

	var sep_right := VSeparator.new()
	sep_right.position = Vector2(792, 10)
	sep_right.size = Vector2(2, 82)
	bar.add_child(sep_right)

	# 本次骰子
	var dice_card := _card(bar, Vector2(808, 14), Vector2(92, 76))
	dice_card.name = "DiceCard"
	UIUtils.shrine_panel_style(dice_card, SURFACE_2, PRIMARY, 2)
	var dice_num := _label(dice_card, "DiceNumLabel", "--", Vector2(8, 13), 34, PRIMARY_DARK)
	dice_num.size = Vector2(42, 46)
	dice_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var suit_lbl := _label(dice_card, "DiceSuitLabel", "", Vector2(48, 15), 32, PRIMARY)
	suit_lbl.size = Vector2(38, 44)
	suit_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_label(bar, "PokerTitle", "牌型记录 · 3次结算", Vector2(916, 8), 10, MUTED)
	for i in range(3):
		var poker_card := _card(bar, Vector2(916 + i * 116, 27), Vector2(106, 56))
		poker_card.name = "PokerSlotBg" + str(i)
		var val_lbl := _label(poker_card, "PokerVal" + str(i), "-", Vector2(12, 9), 22, INK)
		val_lbl.size = Vector2(42, 36)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var poker_suit := _label(poker_card, "PokerSuit" + str(i), "", Vector2(54, 9), 22, INK)
		poker_suit.size = Vector2(38, 36)
		poker_suit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var result_lbl := _label(bar, "PokerResultLabel", "", Vector2(1090, 6), 11, Color("a56f00"))
	result_lbl.size = Vector2(160, 18)
	result_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# 朱红金边分隔线
	var red_line := ColorRect.new()
	red_line.position = Vector2(0, 99)
	red_line.size = Vector2(1280, 3)
	red_line.color = PRIMARY
	bar.add_child(red_line)
	var gold_line := ColorRect.new()
	gold_line.position = Vector2(0, 98)
	gold_line.size = Vector2(1280, 1)
	gold_line.color = GOLD
	bar.add_child(gold_line)

	main_game.add_child(bar)
	refresh()


func refresh() -> void:
	var name_lbl: Label = main_game.get_node_or_null("TopBar/NameLabel") as Label
	if name_lbl:
		name_lbl.text = "%s  Lv.%d" % [main_game.player_name, main_game.player_level]
	var exp_bar: ProgressBar = main_game.get_node_or_null("TopBar/ExpBar") as ProgressBar
	if exp_bar:
		exp_bar.value = main_game.player_exp
		exp_bar.max_value = main_game.player_exp_max
	var exp_lbl: Label = main_game.get_node_or_null("TopBar/ExpLabel") as Label
	if exp_lbl:
		exp_lbl.text = str(main_game.player_exp) + " / " + str(main_game.player_exp_max)
	var gold_lbl: Label = main_game.get_node_or_null("TopBar/GoldLabel") as Label
	if gold_lbl:
		gold_lbl.text = str(main_game.player_gold)
	var rv_lbl: Label = main_game.get_node_or_null("TopBar/ReviveLabel") as Label
	if rv_lbl:
		rv_lbl.text = str(main_game.player_revive) + " / " + str(main_game.player_max_revive)


func refresh_compact_stats() -> void:
	# 战斗属性已移入角色详情页，保留接口供旧调用兼容。
	pass


func refresh_dice_display() -> void:
	var num_lbl: Label = main_game.get_node_or_null("TopBar/DiceCard/DiceNumLabel") as Label
	if num_lbl:
		num_lbl.text = str(main_game.last_dice_roll)
	var suit_lbl: Label = main_game.get_node_or_null("TopBar/DiceCard/DiceSuitLabel") as Label
	if suit_lbl:
		suit_lbl.text = main_game.last_dice_suit
		suit_lbl.add_theme_color_override("font_color", UIUtils.suit_color(main_game.last_dice_suit))


func refresh_poker_slots() -> void:
	for i in range(3):
		var val_lbl: Label = main_game.get_node_or_null("TopBar/PokerSlotBg" + str(i) + "/PokerVal" + str(i)) as Label
		var suit_lbl: Label = main_game.get_node_or_null("TopBar/PokerSlotBg" + str(i) + "/PokerSuit" + str(i)) as Label
		if i < main_game.poker_records.size():
			var rec := main_game.poker_records[i] as Dictionary
			if val_lbl:
				val_lbl.text = str(rec["value"])
			if suit_lbl:
				suit_lbl.text = rec["suit"]
				suit_lbl.add_theme_color_override("font_color", UIUtils.suit_color(main_game.last_dice_suit if rec["suit"] == "" else rec["suit"]))
		else:
			if val_lbl:
				val_lbl.text = "-"
			if suit_lbl:
				suit_lbl.text = ""


func check_poker_hand() -> void:
	if main_game.poker_records.size() < 3:
		return
	var vals: Array[int] = []
	var suits_arr: Array[String] = []
	for record in main_game.poker_records:
		vals.append(record["value"] as int)
		suits_arr.append(record["suit"] as String)
	var sorted: Array[int] = vals.duplicate()
	sorted.sort()
	var is_flush: bool = suits_arr[0] == suits_arr[1] and suits_arr[1] == suits_arr[2]
	var is_straight: bool = sorted[2] - sorted[1] == 1 and sorted[1] - sorted[0] == 1
	var count_map: Dictionary = {}
	for value in vals:
		count_map[value] = count_map.get(value, 0) + 1
	var max_count: int = 0
	for count in count_map.values():
		max_count = maxi(max_count, count as int)
	var hand_name: String = ""
	var multiplier: int = 0
	if is_flush and is_straight:
		hand_name = "同花顺"; multiplier = 10
	elif max_count >= 3:
		hand_name = "三条"; multiplier = 6
	elif is_straight:
		hand_name = "顺子"; multiplier = 4
	elif is_flush:
		hand_name = "同花"; multiplier = 3
	elif max_count >= 2:
		hand_name = "一对"; multiplier = 2
	var result_lbl: Label = main_game.get_node_or_null("TopBar/PokerResultLabel") as Label
	if multiplier > 0:
		var bonus: int = main_game.player_level * (randi() % 41 + 10) * multiplier
		main_game.player_gold += bonus
		if result_lbl:
			result_lbl.text = hand_name + " ×" + str(multiplier) + "  +" + str(bonus) + "金"
	else:
		if result_lbl:
			result_lbl.text = ""
