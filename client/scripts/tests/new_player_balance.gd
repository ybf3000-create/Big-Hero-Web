extends SceneTree

const BattleEngine = preload("res://scripts/battle_engine.gd")
const MonsterGen = preload("res://scripts/monster_gen.gd")


func _init() -> void:
	var failures: Array[String] = []
	for template in MonsterGen.NORMAL_TEMPLATES:
		if int(template.get("min_tier", 0)) > 0:
			continue
		var victories := 0
		var remaining_hp_total := 0
		for sample in range(20):
			seed(1000 + sample)
			var encounter := MonsterGen._build_encounter_from_template(template, "battle", 1, 0, false)
			encounter["weather"] = "sunny"
			var result := BattleEngine.run_battle(_new_player(), encounter)
			if int(result.get("outcome", -1)) == BattleEngine.Outcome.VICTORY:
				victories += 1
				remaining_hp_total += int(result.get("player_hp", 0))
		var average_hp := remaining_hp_total / maxi(victories, 1)
		print("[new_player_balance] %s victories=%d/20 avg_hp=%d" % [template.get("id", "?"), victories, average_hp])
		if victories < 20:
			failures.append("%s 新档胜率仅 %d/20" % [template.get("id", "?"), victories])
	if failures.is_empty():
		print("[new_player_balance] PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _new_player() -> Dictionary:
	return {
		"name": "新档勇者", "level": 1,
		"current_hp": 500, "max_hp": 500,
		"atk": 25.0, "def": 15.0, "speed_points": 0.0,
		"crit": 0.0, "critdmg": 150.0, "hit": 0.0,
		"dodge": 0.0, "block": 0.0, "skill_dmg": 0.0,
		"cd_reduce": 0.0, "lifesteal": 0.0,
		"skill_slots": [
			{"skill_id": 1, "priority": 2},
			{"skill_id": 22, "priority": 2},
		],
		"set_counts": {}, "set_affixes": [], "battle_gold": 0,
	}
