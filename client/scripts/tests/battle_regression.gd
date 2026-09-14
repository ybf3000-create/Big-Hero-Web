extends SceneTree

const BattleEngine = preload("res://scripts/battle_engine.gd")
const MonsterGen = preload("res://scripts/monster_gen.gd")
const SkillData = preload("res://scripts/skill_data.gd")

var failures: Array[String] = []


func _init() -> void:
	seed(20260803)
	_test_all_skills()
	_test_melee_visuals()
	_test_all_bosses()
	_test_all_weather()
	if failures.is_empty():
		print("[Regression] PASS skills=36 bosses=20 weather=8")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _player(skill_ids: Array[int] = []) -> Dictionary:
	var slots: Array = []
	for sid in skill_ids:
		slots.append({"skill_id": sid, "priority": 3})
	return {
		"name": "测试勇者", "level": 60, "current_hp": 200000, "max_hp": 200000,
		"atk": 12000.0, "def": 5000.0, "speed_points": 40, "crit": 20.0,
		"critdmg": 180.0, "hit": 100.0, "dodge": 5.0, "block": 5.0,
		"skill_dmg": 10.0, "cd_reduce": 20.0, "lifesteal": 5.0,
		"skill_slots": slots, "set_counts": {}, "battle_gold": 100000,
	}


func _validate(label: String, result: Dictionary) -> void:
	if result.is_empty():
		failures.append(label + " returned empty result")
		return
	if int(result.get("rounds", -1)) < 0 or float(result.get("elapsed", -1.0)) < 0.0:
		failures.append(label + " invalid time/rounds")
	if int(result.get("player_hp", -1)) < 0 or int(result.get("player_hp", 0)) > int(result.get("player_max_hp", 0)):
		failures.append(label + " invalid player hp")
	if not result.has("events") or not result.has("outcome"):
		failures.append(label + " missing events/outcome")


func _test_all_skills() -> void:
	for skill in SkillData.SKILLS:
		var encounter := MonsterGen.generate_encounter("challenge", {"player_level": 60, "boss_tier": 12})
		encounter["duration_limit"] = 12.0
		_validate("skill_%d" % int(skill["id"]), BattleEngine.run_battle(_player([int(skill["id"])]), encounter))


func _test_melee_visuals() -> void:
	for skill_id in SkillData.MELEE_SKILL_IDS:
		var skill := SkillData.get_skill(skill_id)
		if BattleEngine._skill_visual_type(skill) != "melee":
			failures.append("skill_%d melee visual missing" % skill_id)
	for skill_id in [10, 33, 35]:
		var skill := SkillData.get_skill(skill_id)
		if BattleEngine._skill_visual_type(skill) == "melee":
			failures.append("skill_%d ranged skill marked melee" % skill_id)


func _test_all_bosses() -> void:
	for boss_index in range(1, 21):
		var encounter := MonsterGen.generate_encounter("boss", {"player_level": 45, "boss_tier": boss_index - 1, "boss_index": boss_index})
		_validate("boss_%d" % boss_index, BattleEngine.run_battle(_player([5, 18, 25, 36]), encounter))


func _test_all_weather() -> void:
	for weather in ["sunny", "thunderstorm", "drizzle", "fog", "blizzard", "scorching_sun", "sandstorm", "aurora"]:
		var encounter := MonsterGen.generate_encounter("challenge", {"player_level": 60, "boss_tier": 12})
		encounter["weather"] = weather
		encounter["duration_limit"] = 12.0
		_validate("weather_" + weather, BattleEngine.run_battle(_player([13, 16, 25, 28]), encounter))
