extends SceneTree

const SaveManagerCls = preload("res://scripts/save_manager.gd")
const MainGameCls = preload("res://scripts/main_game.gd")
const CjkFont = preload("res://assets/fonts/NotoSansHans-Regular.otf")
const EmojiFont = preload("res://assets/fonts/NotoEmoji-VariableFont.ttf")
const HoverHintButtonCls = preload("res://scripts/ui/hover_hint_button.gd")
const UIFontInstallerCls = preload("res://scripts/ui_font_installer.gd")

var failures: Array[String] = []


func _init() -> void:
	_test_character_name_rules()
	_test_network_numeric_baseline()
	_test_web_ui_resources()
	if failures.is_empty():
		print("[network_rules_regression] PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)


func _test_character_name_rules() -> void:
	var save_manager := SaveManagerCls.new()
	_expect(save_manager.validate_name("七个汉字名字啊")["valid"], "7个汉字应合法")
	_expect(not save_manager.validate_name("八个汉字名字啊哈")["valid"], "8个汉字应超出权重14")
	_expect(save_manager.validate_name("Hero2026ABCDEF")["valid"], "14个字母数字应合法")
	_expect(save_manager.validate_name("勇者Hero2026")["weight"] == 12, "混合名称应按汉字2、字母数字1计数")
	_expect(not save_manager.validate_name("勇者_01")["valid"], "下划线应被拒绝")
	_expect(not save_manager.validate_name("勇 者")["valid"], "空格应被拒绝")
	_expect(not save_manager.validate_name("勇者!")["valid"], "标点应被拒绝")
	save_manager.free()


func _test_network_numeric_baseline() -> void:
	_expect(MainGameCls.MAX_PLAYER_LEVEL == 100, "等级上限应为100")
	_expect(MainGameCls.MAX_OFFLINE_SECONDS == 12 * 3600, "离线收益上限应为12小时")


func _test_web_ui_resources() -> void:
	var font_installer := UIFontInstallerCls.new()
	font_installer._enter_tree()
	_expect(CjkFont.has_char("大".unicode_at(0)), "Web内置字体应包含常用汉字")
	_expect(ThemeDB.fallback_font.fallbacks.size() == 2, "Web字体应安装符号和Emoji后备")
	_expect(ThemeDB.fallback_font.has_char("中".unicode_at(0)), "Web后备字体应包含中文")
	_expect(EmojiFont.has_char("📋".unicode_at(0)), "Web内置Emoji字体应包含界面图标")

	var hint_button := HoverHintButtonCls.new()
	var tooltip := hint_button._make_custom_tooltip("第一行\n这是一段需要自动换行的中文提示文本")
	_expect(tooltip.custom_minimum_size.x == 300.0, "悬停提示应限制宽度")
	var tooltip_label := tooltip.get_child(0) as Label
	_expect(tooltip_label != null and tooltip_label.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "悬停提示应自动换行")
	tooltip.queue_free()
	hint_button.free()
	font_installer.free()
