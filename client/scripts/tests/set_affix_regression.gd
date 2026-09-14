extends SceneTree

const EquipGenRef = preload("res://scripts/equip_gen.gd")
const RulesRef = preload("res://scripts/equipment_rules.gd")
const BattleRef = preload("res://scripts/battle_engine.gd")

var failures := 0

func _init() -> void:
	_test_slot_enhance_formula()
	_test_all_set_affixes_are_connected()
	_test_key_affix_values()
	if failures == 0:
		print("[set_affix_regression] PASS affixes=52 slots=8")
		quit(0)
	else:
		push_error("[set_affix_regression] FAIL count=%d" % failures)
		quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _test_slot_enhance_formula() -> void:
	var slot_values := {"weapon":40.0, "armor":30.0, "shoes":4.0, "ring":2.0, "necklace":3.0, "cape":5.0, "helmet":2.0, "charm":100.0}
	for slot_name in slot_values:
		var base_value := float(slot_values[slot_name])
		var enhanced := RulesRef.enhanced_main_value({"slot":slot_name, "main_value":base_value}, 1)
		_expect(is_equal_approx(enhanced, base_value * 1.03), "%s槽位主属性未按3%%强化" % slot_name)
	_expect(is_equal_approx(RulesRef.enhanced_main_value({"main_value":6.0}, 1), 6.18), "百分比主属性不得截断小数")

func _test_all_set_affixes_are_connected() -> void:
	var source := ""
	for path in ["res://scripts/main_game.gd", "res://scripts/battle_engine.gd", "res://scripts/grid_executor.gd"]:
		source += FileAccess.get_file_as_string(path)
	var count := 0
	for set_name in EquipGenRef.SET_AFFIX_POOL:
		for affix in EquipGenRef.SET_AFFIX_POOL[set_name]:
			count += 1
			var affix_name := str(affix.get("name", ""))
			_expect(source.contains(affix_name), "%s未接入属性/战斗/掉落逻辑" % affix_name)
	_expect(count == 52, "套装专属词条应为52条")

func _test_key_affix_values() -> void:
	var actor := {"set_affixes":["【烈焰】灼烧", "【烈焰】核心"], "atk":100.0, "side":"player", "id":0, "name":"测试"}
	var target := {"dots":[], "current_hp":10000.0, "max_hp":10000.0, "shield":0.0, "alive":true, "side":"enemy", "id":1, "name":"木桩", "controls":{}, "buffs":{}, "revives_left":0}
	var state := {"events":[], "log":[], "damage_total":0.0, "actors":{"player":actor, "enemies":[target]}}
	for i in range(5):
		BattleRef._apply_set_burn(state, target, actor)
	_expect(target["dots"].size() == 4, "烈焰核心应将灼烧上限提高到4层")
	_expect(is_equal_approx(float(target["dots"][0].get("damage", 0.0)), 30.0), "烈焰灼烧应将基础灼烧伤害提高50%")
	var luxury_state := BattleRef._build_initial_state({"name":"测试", "atk":100.0, "max_hp":1000, "current_hp":1000, "set_counts":{"奢侈":4}, "set_affixes":["【奢侈】镀金", "【奢侈】豪赌"], "battle_gold":20000}, {"battle_kind":"battle", "units":[]})
	_expect(is_equal_approx(float(luxury_state["actors"]["player"]["atk"]), 185.0), "奢侈镀金+豪赌的攻击加成不正确")
