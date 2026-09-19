class_name GridExecutor
extends RefCounted
## ============================================================
## GridExecutor v0.4 — 地图格执行 + 战斗接线
## ============================================================

const EquipGenCls = preload("res://scripts/equip_gen.gd")
const BattleEngineCls = preload("res://scripts/battle_engine.gd")
const MonsterGenCls = preload("res://scripts/monster_gen.gd")

# 格子类型枚举 — 与 main_game.gd GRID_TYPES 索引对齐
enum GridType {
	HOME     = 0,
	BATTLE   = 1,
	ELITE    = 2,
	CHALLENG = 3,
	REST     = 4,
	TREASURE = 5,
	FORGE    = 6,
	FATE     = 7,
	GOD      = 8,
	SYNTH    = 9,
	LIGHT    = 10,
	BOSS     = 11,
	EMPTY    = 12,
	EMPTY2   = 13,
	LOTTERY  = 14,
	CONSTRUCTION = 15,
}


static func execute(grid_type: int, ctx: Dictionary) -> Dictionary:
	match grid_type:
		GridType.HOME:     return _exec_home(ctx)
		GridType.BATTLE:   return _exec_battle(ctx)
		GridType.ELITE:    return _exec_elite(ctx)
		GridType.CHALLENG: return _exec_challenge(ctx)
		GridType.REST:     return _exec_rest(ctx)
		GridType.TREASURE: return _exec_treasure(ctx)
		GridType.FORGE:    return _exec_forge(ctx)
		GridType.FATE:     return _exec_fate(ctx)
		GridType.GOD:      return _exec_god(ctx)
		GridType.SYNTH:    return _exec_synthesize(ctx)
		GridType.LIGHT:    return _exec_lightning(ctx)
		GridType.BOSS:     return _exec_boss(ctx)
		GridType.EMPTY:    return _exec_empty(ctx)
		GridType.EMPTY2:   return _exec_empty(ctx)
		GridType.LOTTERY:  return _exec_lottery(ctx)
		GridType.CONSTRUCTION: return {"event": "construction", "data": {}}
	return {"event": "unknown", "data": {}}


static func _exec_home(_ctx: Dictionary) -> Dictionary:
	return {"event": "home", "data": {"message": "回到勇者之家"}}


static func _exec_battle(ctx: Dictionary) -> Dictionary:
	return _run_combat("battle", ctx)


static func _exec_elite(ctx: Dictionary) -> Dictionary:
	return _run_combat("elite", ctx)


static func _exec_boss(ctx: Dictionary) -> Dictionary:
	return _run_combat("boss", ctx)


static func _exec_challenge(ctx: Dictionary) -> Dictionary:
	return _run_combat("challenge", ctx)


static func _run_combat(battle_kind: String, ctx: Dictionary) -> Dictionary:
	var encounter: Dictionary = MonsterGenCls.generate_encounter(battle_kind, ctx)
	encounter["weather"] = str(ctx.get("weather", "sunny"))
	var player_state: Dictionary = ctx.get("player_state", {}).duplicate(true)
	var result: Dictionary
	var set_counts: Dictionary = player_state.get("set_counts", {})
	var set_affixes: Array = player_state.get("set_affixes", [])
	var talk_chance := 0.0
	if battle_kind == "battle" and bool(ctx.get("hibernate", false)):
		talk_chance = 1.0
	elif battle_kind == "battle" and int(set_counts.get("口才", 0)) >= 3:
		talk_chance = 0.25
		if set_affixes.has("【口才】魅力"): talk_chance += 0.05
		if set_affixes.has("【口才】超级魅力"): talk_chance += 0.05
	elif battle_kind == "elite" and int(set_counts.get("口才", 0)) >= 4:
		talk_chance = 0.05
		if set_affixes.has("【口才】雄辩"): talk_chance += 0.03
		if set_affixes.has("【口才】超级雄辩"): talk_chance += 0.03
	if talk_chance > 0.0 and randf() < talk_chance:
		var rewards: Dictionary = BattleEngineCls._calc_victory_rewards(encounter, player_state)
		result = {
			"outcome": BattleEngineCls.Outcome.VICTORY, "player_hp": int(player_state.get("current_hp", 1)),
			"player_max_hp": int(player_state.get("max_hp", 1)), "player_alive": true,
			"damage_total": 0, "elapsed": 0.0, "rounds": 0, "log": ["口才套装说服敌人，直接胜利"],
			"events": [], "battle_kind": battle_kind, "monster_level": encounter.get("monster_level", 1),
			"template_id": encounter.get("template_id", ""), "template_name": encounter.get("template_name", ""),
			"gold_gain": rewards.get("gold_gain", 0), "exp_gain": rewards.get("exp_gain", 0),
			"drops": rewards.get("drops", []), "boss_cleared": false, "talk_skip": true,
		}
	else:
		result = BattleEngineCls.run_battle(player_state, encounter)
	result["encounter"] = encounter

	ctx["player_hp"] = int(result.get("player_hp", ctx.get("player_hp", 1)))
	var luxury_spent := int(result.get("luxury_gold_spent", 0))
	if luxury_spent > 0:
		ctx["player_gold"] = maxi(0, int(ctx.get("player_gold", 0)) - luxury_spent)

	var outcome: int = int(result.get("outcome", -1))
	var is_challenge: bool = battle_kind == "challenge"
	var is_victory: bool = (not is_challenge and outcome == BattleEngineCls.Outcome.VICTORY) or (is_challenge and outcome == BattleEngineCls.Outcome.CHALLENGE_DONE)
	var data: Dictionary = {
		"battle_kind": battle_kind,
		"battle_result": result,
		"encounter": encounter,
		"type": battle_kind,
		"luxury_gold_spent": luxury_spent,
	}

	if is_victory:
		var gold_gain: int = int(result.get("gold_gain", 0))
		ctx["player_gold"] = int(ctx.get("player_gold", 0)) + gold_gain
		data["gold_gain"] = gold_gain
		data["exp_gain"] = int(result.get("exp_gain", 0))
		data["drops"] = result.get("drops", []).duplicate(true)
		data["damage_total"] = int(result.get("damage_total", 0))
		if battle_kind == "boss":
			data["message"] = "Boss战胜利! +%dEXP +%d金" % [data["exp_gain"], gold_gain]
			data["boss_cleared"] = bool(result.get("boss_cleared", false))
		elif battle_kind == "elite":
			data["message"] = "精英战胜利! +%dEXP +%d金" % [data["exp_gain"], gold_gain]
		elif battle_kind == "challenge":
			data["message"] = "挑战完成! 造成%d伤害 +%d金" % [data["damage_total"], gold_gain]
		else:
			data["message"] = "战斗胜利! +%dEXP +%d金" % [data["exp_gain"], gold_gain]
	else:
		data["gold_gain"] = 0
		data["exp_gain"] = 0
		data["drops"] = []
		if not is_challenge:
			var revive: int = int(ctx.get("player_revive", 0))
			if revive > 0:
				ctx["player_revive"] = revive - 1
				ctx["player_hp"] = int(ctx.get("player_max_hp", ctx.get("player_hp", 1)))
				result["player_hp"] = int(ctx["player_hp"])
				data["revive_used"] = true
				data["message"] = "战败，消耗1复活币重新站起"
			else:
				var penalty: int = int(floor(float(ctx.get("player_gold", 0)) * 0.15))
				ctx["player_gold"] = max(0, int(ctx.get("player_gold", 0)) - penalty)
				ctx["player_hp"] = int(ctx.get("player_max_hp", ctx.get("player_hp", 1)))
				result["player_hp"] = int(ctx["player_hp"])
				data["force_home"] = true
				data["gold_penalty"] = penalty
				data["message"] = "战败，强制回家并损失%d金币" % penalty
		else:
			data["damage_total"] = int(result.get("damage_total", 0))
			data["message"] = "挑战完成! 造成%d伤害" % data["damage_total"]

	return {"event": battle_kind, "data": data}


static func _exec_rest(ctx: Dictionary) -> Dictionary:
	var rev: int = ctx.get("player_revive", 3)
	if rev < 3:
		ctx["player_revive"] = rev + 1
		return {"event": "rest", "data": {"type": "revive", "message": "+1 复活币", "revive": rev + 1}}
	else:
		var lv: int = ctx.get("player_level", 1)
		var gold: int = mini(lv, 100) * 5
		ctx["player_gold"] = ctx.get("player_gold", 0) + gold
		return {"event": "rest", "data": {"type": "gold", "message": "+" + str(gold) + " 金币（复活币已满）", "gold": gold}}


static func _exec_treasure(ctx: Dictionary) -> Dictionary:
	var roll: float = randf()
	if roll < 0.55:
		return _treasure_gold(ctx)
	elif roll < 0.80:
		return _treasure_equip(ctx)
	elif roll < 0.92:
		return _treasure_card(ctx)
	else:
		return _treasure_gem(ctx)


static func _treasure_gold(ctx: Dictionary) -> Dictionary:
	var lv: int = ctx.get("player_level", 1)
	var gold: int = mini(lv, 100) * randi_range(6, 12)
	ctx["player_gold"] = ctx.get("player_gold", 0) + gold
	return {"event": "treasure", "data": {"type": "gold", "amount": gold, "message": "宝箱开出 +" + str(gold) + " 金币"}}


static func _treasure_equip(ctx: Dictionary) -> Dictionary:
	var eqp: Dictionary = EquipGenCls.generate(_random_slot(), ctx.get("player_level", 1), _equip_generation_options(ctx))
	return {"event": "treasure", "data": {"type": "equip", "equip": eqp, "message": "宝箱获得: " + EquipGenCls.full_name(eqp)}}


static func _treasure_card(_ctx: Dictionary) -> Dictionary:
	return {"event": "treasure", "data": {"type": "card", "item_id": 5, "count": 1, "message": "宝箱开出天命卡×1"}}


static func _treasure_gem(_ctx: Dictionary) -> Dictionary:
	var gid: int = randi_range(1, 7)
	var lv: int = 1
	var lv_roll: float = randf()
	if lv_roll < 0.60:
		lv = 1
	elif lv_roll < 0.85:
		lv = 2
	elif lv_roll < 0.97:
		lv = 3
	else:
		lv = 4
	var gdef: Dictionary = EquipGenCls.EquipDataCls.GEM_DEFS.get(gid, {})
	return {"event": "treasure", "data": {"type": "gem", "gem_id": gid, "level": lv, "message": "宝箱开出" + UIUtils.safe_icon(str(gdef.get("icon", "")), "宝") + " Lv." + str(lv)}}


static func _exec_forge(ctx: Dictionary) -> Dictionary:
	var equipment: Equipment = ctx.get("equipment") as Equipment
	if equipment == null:
		return {"event": "forge", "data": {"type": "fail", "message": "装备槽位数据缺失"}}
	var equipped_slots: Array[String] = []
	for sn in equipment.SLOT_TYPE.keys():
		if not equipment.get_slot_item(sn).is_empty():
			equipped_slots.append(sn)
	if equipped_slots.is_empty():
		return {"event": "forge", "data": {"type": "fail", "message": "装备架空空如也"}}

	var slot: String = equipped_slots[randi() % equipped_slots.size()]
	var enhance: int = equipment.get_slot_enhance(slot)
	if enhance >= equipment.MAX_SLOT_ENHANCE:
		return {"event": "forge", "data": {"type": "cap", "message": slot + " 强化已达上限 +200"}}

	var cost: int = equipment.get_slot_enhance_cost(slot)
	var gold: int = ctx.get("player_gold", 0)
	if gold < cost:
		return {"event": "forge", "data": {"type": "nofund", "message": "金币不足（需要 " + str(cost) + "）"}}

	ctx["player_gold"] = gold - cost
	equipment.enhance_slot(slot)
	return {"event": "forge", "data": {"type": "success", "slot": slot, "enhance": enhance + 1, "cost": cost, "message": slot + " +" + str(enhance) + " → +" + str(enhance + 1) + "  (-" + str(cost) + "金)"}}


static var FATE_EVENTS: Array[Dictionary] = [
	{"name": "股市大涨", "type": "reward", "weight": 6},
	{"name": "宝石行情好", "type": "reward", "weight": 6},
	{"name": "技能大赛", "type": "reward", "weight": 7},
	{"name": "天命降临", "type": "reward", "weight": 6},
	{"name": "装备促销", "type": "reward", "weight": 6},
	{"name": "小憩", "type": "reward", "weight": 7},
	{"name": "获得宝石", "type": "reward", "weight": 6},
	{"name": "获得打孔器", "type": "reward", "weight": 6},
	{"name": "股市崩盘", "type": "punish", "weight": 8},
	{"name": "暴风雨", "type": "punish", "weight": 7},
	{"name": "拆迁通知", "type": "punish", "weight": 7},
	{"name": "诅咒降临", "type": "punish", "weight": 8},
	{"name": "攻击削弱", "type": "punish", "weight": 5},
	{"name": "传送门", "type": "special", "weight": 8},
]

static func _exec_fate(ctx: Dictionary) -> Dictionary:
	var weather_event: Dictionary = _try_weather_fate(ctx)
	if not weather_event.is_empty():
		return {"event": "fate", "data": weather_event}
	var pool: Array[Dictionary] = []
	for ev in FATE_EVENTS:
		for _w in range(ev["weight"]):
			pool.append(ev)
	var chosen: Dictionary = pool[randi() % pool.size()]

	match chosen["name"]:
		"股市大涨":
			var g: int = ctx.get("player_gold", 0)
			var add: int = clampi(int(g * 0.05), 100, 50000)
			ctx["player_gold"] = g + add
			return {"event": "fate", "data": {"type": "reward", "name": "股市大涨", "message": "股市大涨！+" + str(add) + " 金币"}}
		"股市崩盘":
			var g2: int = ctx.get("player_gold", 0)
			var sub: int = mini(g2, clampi(int(g2 * 0.05), 100, 10000))
			ctx["player_gold"] = maxi(0, g2 - sub)
			return {"event": "fate", "data": {"type": "punish", "name": "股市崩盘", "message": "股市崩盘！-" + str(sub) + " 金币"}}
		"小憩":
			var heal := int(ctx.get("player_max_hp", 1)) / 2
			ctx["player_hp"] = mini(int(ctx.get("player_max_hp", 1)), int(ctx.get("player_hp", 0)) + heal)
			return {"event": "fate", "data": {"type": "reward", "name": "小憩", "next_step_bonus": 1, "message": "小憩恢复50%HP，下次步数+1"}}
		"获得宝石":
			var gid: int = randi_range(1, 8)
			var gem_roll := randf()
			var gem_level := 1 if gem_roll < 0.60 else 2 if gem_roll < 0.85 else 3 if gem_roll < 0.97 else 4
			return {"event": "fate", "data": {"type": "reward", "name": "获得宝石", "gem_id": gid, "level": gem_level, "message": "获得宝石 Lv.%d" % gem_level}}
		"获得打孔器":
			return {"event": "fate", "data": {"type": "reward", "name": "获得打孔器", "item_id": 6, "count": 1, "message": "获得打孔器×1"}}
		"传送门":
			return {"event": "fate", "data": {"type": "special", "name": "传送门", "message": "传送门！传送到闪电格", "teleport": true}}
		"宝石行情好":
			return {"event": "fate", "data": {"type": "reward", "name": "宝石行情好", "gem_id": randi_range(1, 8), "level": 2, "message": "宝石行情好：获得Lv.2宝石"}}
		"技能大赛":
			return {"event": "fate", "data": {"type": "reward", "name": "技能大赛", "message": "未来3场战斗伤害+30%"}}
		"天命降临":
			return {"event": "fate", "data": {"type": "reward", "name": "天命降临", "item_id": 5, "count": 1, "message": "获得天命卡×1"}}
		"装备促销":
			var promoted_options := _equip_generation_options(ctx)
			promoted_options["min_quality"] = 1
			var promoted: Dictionary = EquipGenCls.generate(_random_slot(), int(ctx.get("player_level", 1)), promoted_options)
			return {"event": "fate", "data": {"type": "equip", "name": "装备促销", "equip": promoted, "message": "装备促销：获得精良以上装备"}}
		"暴风雨":
			return {"event": "fate", "data": {"type": "punish", "name": "暴风雨", "next_step_penalty": 1, "message": "暴风雨：下次骰子步数-1"}}
		"拆迁通知":
			var loss := mini(int(ctx.get("player_gold", 0)), maxi(100, int(ctx.get("player_level", 1)) * 50))
			ctx["player_gold"] = int(ctx.get("player_gold", 0)) - loss
			return {"event": "fate", "data": {"type": "punish", "name": "拆迁通知", "message": "拆迁通知：支付%d金币" % loss}}
		"诅咒降临":
			return {"event": "fate", "data": {"type": "punish", "name": "诅咒降临", "buff_type": "dmg_x0.8", "buff_turns": 3, "message": "诅咒降临：未来3场伤害-20%"}}
		"攻击削弱":
			return {"event": "fate", "data": {"type": "punish", "name": "攻击削弱", "message": "未来3场战斗伤害-30%"}}
		_:
			return {"event": "fate", "data": {"type": chosen["type"], "name": chosen["name"], "message": chosen["name"]}}


static func _try_weather_fate(ctx: Dictionary) -> Dictionary:
	var weather := str(ctx.get("weather", "sunny"))
	if weather == "sunny" or int(ctx.get("boss_tier", 0)) < 6:
		return {}
	var luck := float(ctx.get("player_state", {}).get("luk", 0.0))
	if randf() >= minf(1.0, (30.0 + luck * 0.5) / 100.0):
		return {}
	match weather:
		"blizzard":
			return {"type": "special", "name": "冬眠", "hibernate_laps": 1, "message": "冬眠：本圈普通怪物直接结算胜利"}
		"drizzle":
			var before := int(ctx.get("player_revive", 0))
			ctx["player_revive"] = mini(3, before + 1)
			return {"type": "reward", "name": "滋润", "message": "滋润：复活币+%d" % (int(ctx["player_revive"]) - before)}
		"fog":
			return {"type": "special", "name": "雾中秘径", "teleport_treasure": true, "message": "雾中秘径：前往宝箱格"}
		"sandstorm":
			var gold := int(ctx.get("player_level", 1)) * 200
			ctx["player_gold"] = int(ctx.get("player_gold", 0)) + gold
			return {"type": "reward", "name": "沙中淘金", "message": "沙中淘金：+%d金币" % gold}
		"aurora":
			var aurora_options := _equip_generation_options(ctx)
			aurora_options["forced_quality"] = 4
			var equip := EquipGenCls.generate(_random_slot(), int(ctx.get("player_level", 1)), aurora_options)
			return {"type": "equip", "name": "许愿", "equip": equip, "message": "许愿：获得传说装备"}
	return {}


static var GOD_POOL: Array[Dictionary] = [
	{"name": "财神", "type": "bless", "weight": 15},
	{"name": "战神", "type": "bless", "weight": 15},
	{"name": "速神", "type": "bless", "weight": 15},
	{"name": "福神", "type": "bless", "weight": 15},
	{"name": "衰神", "type": "curse", "weight": 15},
	{"name": "穷神", "type": "curse", "weight": 8},
	{"name": "懒神", "type": "curse", "weight": 7},
	{"name": "命运之神", "type": "special", "weight": 10},
]

static func _exec_god(_ctx: Dictionary) -> Dictionary:
	var pool: Array[Dictionary] = []
	for gd in GOD_POOL:
		for _w in range(gd["weight"]):
			pool.append(gd)
	var chosen: Dictionary = pool[randi() % pool.size()]
	var effects: Dictionary = {
		"财神": {"stat": "gold_mult", "value": 2.0, "turns": 3, "desc": "金币收益×2"},
		"战神": {"stat": "war_god", "value": 1.0, "turns": 3, "desc": "伤害×1.5，受伤×0.7"},
		"速神": {"stat": "cd_mult", "value": 0.80, "turns": 3, "desc": "仅技能冷却×0.8"},
		"福神": {"stat": "quality_up_chance", "value": 0.30, "turns": 2, "desc": "掉落装备30%概率品质+1"},
		"衰神": {"stat": "decline_god", "value": 1.0, "turns": 2, "desc": "伤害×0.7，受伤×1.5"},
		"穷神": {"stat": "gold_mult", "value": 0.50, "turns": 2, "desc": "金币收益×0.5"},
		"懒神": {"stat": "cd_mult", "value": 1.30, "turns": 2, "desc": "技能冷却×1.3"},
		"命运之神": {"stat": "fate_now", "value": 1.0, "turns": 0, "desc": "立即触发一次命运事件"},
	}
	var effect: Dictionary = effects.get(chosen["name"], {})
	return {"event": "god", "data": {"type": chosen["type"], "name": chosen["name"], "deity_effect": effect, "message": "遇到%s：%s" % [chosen["name"], effect.get("desc", "")]}}


static func _exec_lottery(_ctx: Dictionary) -> Dictionary:
	return {"event": "lottery", "data": {"type": "lottery", "ticket": randi_range(0, 999), "message": "免费获得一张彩票"}}


static func _exec_synthesize(ctx: Dictionary) -> Dictionary:
	var eqp_list: Array = ctx.get("equip_instances", [])
	var unequipped: Array[Dictionary] = []
	for ep in eqp_list:
		if not ep.get("equipped", false):
			unequipped.append(ep)
	if unequipped.size() < 2:
		return {"event": "synthesize", "data": {"type": "fail", "message": "背包装备不足2件，无法合成"}}
	var a: Dictionary = unequipped[randi() % unequipped.size()]
	var b: Dictionary = a
	while b["uid"] == a["uid"]:
		b = unequipped[randi() % unequipped.size()]
	# 合成是事务操作：任一随机材料锁定时，整次合成立即终止。
	if bool(a.get("locked", false)) or bool(b.get("locked", false)):
		return {"event": "synthesize", "data": {"type": "fail", "message": "选中的合成材料已锁定，合成终止"}}
	var gem_bag: Array = ctx.get("gem_bag", [])
	for material in [a, b]:
		for gem in material.get("gems", []):
			var gid: int = int(gem.get("id", 0)) if gem is Dictionary else int(gem)
			var level: int = int(gem.get("level", 1)) if gem is Dictionary else 1
			if gid <= 0:
				continue
			var found := false
			for bag_gem in gem_bag:
				if int(bag_gem.get("id", 0)) == gid and int(bag_gem.get("level", 1)) == level:
					bag_gem["count"] = int(bag_gem.get("count", 0)) + 1
					found = true
					break
			if not found:
				gem_bag.append({"id": gid, "level": level, "count": 1})

	var qa: int = a.get("quality", 0)
	var qb: int = b.get("quality", 0)
	var result_quality: int
	if qa == qb:
		result_quality = mini(qa + 1, 4)
	else:
		var low: int = mini(qa, qb)
		var high: int = maxi(qa, qb)
		var span: int = mini(high + 1, 4) - low + 1
		result_quality = low + randi() % span

	var slot: String = a["slot"] if randi() % 2 == 0 else b["slot"]
	var synth_options := _equip_generation_options(ctx)
	synth_options["forced_quality"] = result_quality
	var new_eqp: Dictionary = EquipGenCls.generate(slot, ctx.get("player_level", 1), synth_options)
	for ei in range(eqp_list.size() - 1, -1, -1):
		if eqp_list[ei]["uid"] == a["uid"] or eqp_list[ei]["uid"] == b["uid"]:
			eqp_list.remove_at(ei)
	eqp_list.append(new_eqp)
	return {"event": "synthesize", "data": {"type": "success", "quality": result_quality, "message": "合成获得 [" + EquipGenCls.EquipDataCls.QUALITY_NAMES.get(result_quality, "?") + "] " + new_eqp["base_name"]}}


static func _exec_lightning(_ctx: Dictionary) -> Dictionary:
	var jump: int = randi_range(2, 5)
	return {"event": "lightning", "data": {"jump": jump, "message": "闪电跳跃 " + str(jump) + " 格！"}}


static func _exec_empty(ctx: Dictionary) -> Dictionary:
	var lv: int = ctx.get("player_level", 1)
	var gold: int = maxi(1, int(mini(lv, 100) * randf_range(0.3, 0.8)))
	ctx["player_gold"] = ctx.get("player_gold", 0) + gold
	return {"event": "empty", "data": {"gold": gold, "message": "+%d 金" % gold}}


static func _random_slot() -> String:
	var slots: Array[String] = ["weapon", "armor", "shoes", "ring", "necklace", "cape", "helmet", "charm"]
	return slots[randi() % slots.size()]


static func _equip_generation_options(ctx: Dictionary) -> Dictionary:
	var options := {"boss_tier": int(ctx.get("boss_tier", 0))}
	var set_affixes: Array = ctx.get("player_state", {}).get("set_affixes", [])
	if set_affixes.has("【引力】磁力"):
		options["set_rate_bonus"] = 2.0
	var set_counts: Dictionary = ctx.get("player_state", {}).get("set_counts", {})
	if int(set_counts.get("引力", 0)) >= 4:
		var luck := float(ctx.get("player_state", {}).get("luk", 0.0))
		options["extra_suit_rate"] = 0.01 + luck * 0.002 + (0.005 if set_affixes.has("【引力】护符") else 0.0)
	return options
