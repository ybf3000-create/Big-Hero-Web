extends SceneTree

const SaveManagerCls = preload("res://scripts/save_manager.gd")
const MainGameCls = preload("res://scripts/main_game.gd")
const CjkFont = preload("res://assets/fonts/NotoSansHans-Regular.otf")

var failures: Array[String] = []


func _init() -> void:
	_test_character_name_rules()
	_test_network_numeric_baseline()
	_expect(CjkFont.has_char("大".unicode_at(0)), "Web内置字体应包含常用汉字")
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
