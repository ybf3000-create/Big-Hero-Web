extends SceneTree

const EquipGenCls = preload("res://scripts/equip_gen.gd")
const EquipmentCls = preload("res://scripts/equipment.gd")
const Rules = preload("res://scripts/equipment_rules.gd")
const GridExecutorCls = preload("res://scripts/grid_executor.gd")
const MainGameCls = preload("res://scripts/main_game.gd")
const SkillSystemCls = preload("res://scripts/skill_system.gd")

var failures: Array[String] = []

func _init() -> void:
	_test_set_affixes()
	_test_lock_and_filter()
	_test_invalid_equipment_is_empty()
	_test_reroll()
	_test_slot_enhance_and_capacity()
	_test_synthesis_protection()
	_test_slot_batch_cost()
	if failures.is_empty():
		print("[equipment_regression] PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _test_set_affixes() -> void:
	_expect(EquipGenCls.SET_AFFIX_POOL.size() == 13, "套装数量应为13")
	var total := 0
	for pool in EquipGenCls.SET_AFFIX_POOL.values():
		_expect(pool.size() == 4, "每套必须固定4条专属词条")
		total += pool.size()
	_expect(total == 52, "套装专属词条总数应为52")
	_expect(EquipGen.gem_slots_from_roll(0.0) == 1 and EquipGen.gem_slots_from_roll(0.5999) == 1, "1孔区间应为60%")
	_expect(EquipGen.gem_slots_from_roll(0.60) == 2 and EquipGen.gem_slots_from_roll(0.8999) == 2, "2孔区间应为30%")
	_expect(EquipGen.gem_slots_from_roll(0.90) == 3 and EquipGen.gem_slots_from_roll(0.9999) == 3, "3孔区间应为10%")

func _test_lock_and_filter() -> void:
	var eqp := Rules.normalize_equipment({"quality": 4, "slot_type_id": 1, "affixes": [{"name":"攻击%"}], "set_affixes": [], "gem_slots": 2, "suit_name":"烈焰"})
	_expect(bool(eqp.get("locked", false)), "传说装备必须自动锁定")
	var matching := {"qualities":[4], "slots":[1, 2], "affix_min":1, "affix_max":2, "affix_types":["attack"], "initial_sockets":[2], "suits":["烈焰"]}
	_expect(Rules.matches_six_dimensions(eqp, matching), "六维全部满足时应匹配")
	matching["slots"] = [2]
	_expect(not Rules.matches_six_dimensions(eqp, matching), "任一维不满足时不得匹配")
	_expect(Rules.should_auto_dismantle(eqp, {"rules":[{"qualities":[4]}]}), "只选择品质列时应能命中")
	_expect(Rules.should_auto_dismantle(eqp, {"rules":[{"slots":[1]}]}), "只选择部位列时应能命中")
	_expect(not Rules.should_auto_dismantle(eqp, {"rules":[{"slots":[2]}]}), "只选择部位列时不匹配的部位不得命中")
	_expect(not Rules.should_auto_dismantle(eqp, {"rules":[{}]}), "空白规则不得命中任何装备")
	var legacy := Rules.normalize_equipment({"slot":"weapon", "quality":3})
	_expect(str(legacy.get("main_stat", "")) == "攻击力" and is_equal_approx(float(legacy.get("main_value", 0.0)), 80.0), "旧档装备必须自动补全主属性")

func _test_invalid_equipment_is_empty() -> void:
	var equipment := EquipmentCls.new()
	equipment.from_dict({"equipped": {"weapon": {"slot": "weapon", "enhance": 5}}})
	_expect(equipment.get_slot_item("weapon").is_empty(), "字段不完整的旧装备必须按空槽处理")
	_expect(not Rules.is_valid_equipment({"slot": "weapon", "base_name": "???"}, "weapon"), "占位装备名称不得视为有效装备")

func _test_reroll() -> void:
	var eqp := {"quality":3, "affixes":[{"name":"攻击%", "type":"attack", "value":5.0, "display":"+5%"}, {"name":"速度", "type":"universal", "value":3.0, "display":"+3"}]}
	var kept: Dictionary = eqp["affixes"][0].duplicate(true)
	_expect(Rules.reroll_affixes(eqp, [0], EquipGenCls.AFFIX_POOL), "史诗装备应可重铸")
	_expect(eqp["affixes"][0] == kept, "锁定词缀必须原样保留")
	_expect(Rules.REROLL_COSTS[0]["essence"] == 15 and Rules.REROLL_COSTS[2]["legendary_gold"] == 60000, "重铸费用表不正确")

func _test_slot_enhance_and_capacity() -> void:
	var equipment := EquipmentCls.new()
	equipment.equip_instance("weapon", {"slot": "weapon", "base_name": "测试武器", "main_value": 10, "enhance": 0})
	_expect(equipment.enhance_slot("weapon"), "槽位应可强化")
	var replacement := {"slot": "weapon", "base_name": "替换武器", "main_value": 20, "enhance": 0}
	equipment.equip_instance("weapon", replacement)
	_expect(equipment.get_slot_enhance("weapon") == 1, "换装后槽位强化必须保留")
	_expect(is_equal_approx(equipment.get_slot_main_multiplier("weapon"), 1.03), "槽位强化倍率应为每级3%")
	_expect(Rules.EQUIP_CAPACITY_BASE == 100 and Rules.EQUIP_CAPACITY_MAX == 1000 and Rules.EQUIP_EXPANSION_COSTS.size() == 18, "装备背包容量规则不正确")

func _test_synthesis_protection() -> void:
	var locked_materials: Array[Dictionary] = [
		{"uid":1, "slot":"weapon", "quality":1, "equipped":false, "locked":true, "gems":[]},
		{"uid":2, "slot":"armor", "quality":1, "equipped":false, "locked":false, "gems":[]},
	]
	var locked_result: Dictionary = GridExecutorCls._exec_synthesize({"equip_instances":locked_materials, "player_level":1})
	_expect(locked_result.get("data", {}).get("type", "") == "fail" and locked_materials.size() == 2, "锁定材料必须让合成事务终止")
	var materials: Array[Dictionary] = [
		{"uid":3, "slot":"weapon", "quality":1, "equipped":false, "locked":false, "gems":[{"id":2, "level":3}]},
		{"uid":4, "slot":"armor", "quality":1, "equipped":false, "locked":false, "gems":[]},
	]
	var gem_bag: Array[Dictionary] = []
	var result: Dictionary = GridExecutorCls._exec_synthesize({"equip_instances":materials, "gem_bag":gem_bag, "player_level":1})
	_expect(result.get("data", {}).get("type", "") == "success" and materials.size() == 1, "合法材料应合成为1件装备")
	_expect(gem_bag.size() == 1 and int(gem_bag[0].get("id", 0)) == 2 and int(gem_bag[0].get("level", 0)) == 3, "合成材料上的宝石必须自动返还")

func _test_slot_batch_cost() -> void:
	var game: Control = MainGameCls.new()
	game.equipment = EquipmentCls.new()
	game.skill_system = SkillSystemCls.new()
	var one_slot: Array[String] = ["weapon"]
	_expect(game._slot_enhance_cost(one_slot, 1) == 0, "槽位首次强化费用应与现有0级费用规则一致")
	_expect(game._slot_enhance_cost(one_slot, 5) == 5000, "单槽位+5费用汇总不正确")
	var slots: Array[String] = ["weapon", "armor", "shoes", "ring", "necklace", "cape", "helmet", "charm"]
	_expect(game._slot_enhance_cost(slots, 5) == 40000, "全部槽位+5费用汇总不正确")
	game.player_hp = 1
	game._refresh_player_hp_bounds(false)
	_expect(game.player_hp == game.player_max_hp, "非战斗状态不应保留残余血量")
	_expect(int(game._build_player_battle_state().get("current_hp", 0)) == game.player_max_hp, "每场战斗必须以满血开始")
	game.free()
