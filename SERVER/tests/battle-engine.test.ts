import assert from "node:assert/strict";
import test from "node:test";
import { BattleOutcome, runBattle, type BattlePlayerState } from "../src/battle-engine.js";
import { BATTLE_SKILLS, MELEE_SKILL_IDS } from "../src/battle-catalog.js";
import { generateEncounter } from "../src/monster-generator.js";

function player(skillIds: number[]): BattlePlayerState {
  return {
    name: "测试勇者", level: 60, currentHp: 200_000, maxHp: 200_000, attack: 12_000, defense: 5_000,
    speedPoints: 40, crit: 20, critDamage: 180, hit: 100, dodge: 5, block: 5, skillDamage: 10,
    cooldownReduction: 20, lifesteal: 5, freeAttackPct: 0, freeDefensePct: 0, goldBonus: 0,
    experienceBonus: 0, luck: 0, skillSlots: skillIds.map((skillId) => ({ skillId, priority: 3 })), battleDamageMultiplier: 1,
    incomingDamageMultiplier: 1, passives: [], setCounts: {}, setAffixes: [], battleGold: 100_000,
  };
}

function seeded(seed: number): () => number {
  let value = seed >>> 0;
  return () => {
    value = (Math.imul(value, 1_664_525) + 1_013_904_223) >>> 0;
    return value / 0x1_0000_0000;
  };
}

function trainingEncounter(): Parameters<typeof runBattle>[1] {
  return {
    battle_kind: "challenge",
    monster_level: 10,
    template_id: "numeric-regression",
    template_name: "数值回归木桩",
    units: [{
      id: 1, name: "木桩", display_name: "木桩", row: "front", level: 10,
      max_hp: 999_999, current_hp: 999_999, atk: 0, def: 0, speed_points: 35, action_cd: 2.16,
      crit: 0, critdmg: 150, hit: 0, dodge: 0, block: 0, skill_ids: [], passives: [],
      is_elite: false, is_boss: false, infinite_hp: true, template_id: "numeric-regression",
    }],
    formation: { front: [1], back: [] }, duration_limit: 8, weather: "sunny",
  };
}

function validate(result: ReturnType<typeof runBattle>): void {
  assert.ok(result.rounds >= 0);
  assert.ok(result.elapsed >= 0);
  assert.ok(result.player_hp >= 0 && result.player_hp <= result.player_max_hp);
  assert.ok(Array.isArray(result.events));
  assert.ok(Object.values(BattleOutcome).includes(result.outcome as never));
}

test("all 36 original skills produce a valid authoritative battle timeline", () => {
  for (const skill of BATTLE_SKILLS) {
    const random = seeded(2_026_080_300 + skill.id);
    const encounter = generateEncounter("challenge", 60, 12, 13, "sunny", random);
    encounter.duration_limit = 12;
    const result = runBattle(player([skill.id]), encounter, random);
    validate(result);
    assert.ok(result.events.some((event) => event.type === "cast" && event.skill_id === skill.id), `skill ${skill.id} did not cast`);
  }
});

test("all 200 boss tiers generate valid server-owned encounters and battles", () => {
  for (let bossIndex = 1; bossIndex <= 200; bossIndex += 1) {
    const random = seeded(4_000 + bossIndex);
    const encounter = generateEncounter("boss", 100, bossIndex - 1, bossIndex, "sunny", random);
    const boss = encounter.units.find((unit) => unit.is_boss);
    assert.equal(boss?.boss_index, bossIndex);
    assert.equal(encounter.template_name, encounter.units.find((unit) => unit.is_boss)?.name);
    assert.match(boss?.asset ?? "", /\.png$/);
    assert.ok(boss?.boss_mechanic?.id, `boss ${bossIndex} is missing its authoritative mechanic`);
    validate(runBattle(player([5, 18, 25, 36]), encounter, random));
  }
});

test("lethal damage still triggers the Slime King's split and summoned minions keep their skills", () => {
  const random = seeded(20_260_921);
  const encounter = generateEncounter("boss", 60, 0, 1, "sunny", random);
  const boss = encounter.units.find((unit) => unit.is_boss)!;
  boss.max_hp = 100;
  boss.current_hp = 100;
  const result = runBattle({ ...player([]), attack: 10_000, currentHp: 200_000 }, encounter, random);
  const summons = result.events.filter((event) => event.type === "summon");
  assert.equal(summons.length, 3);
  assert.ok(result.events.some((event) => event.type === "cast" && event.mechanic === "split"));
  for (const event of summons) assert.deepEqual(event.unit?.skill_ids, [21]);
});

test("all weather types and battle modes produce browser-playable events", () => {
  for (const weather of ["sunny", "thunderstorm", "drizzle", "fog", "blizzard", "scorching_sun", "sandstorm", "aurora"]) {
    const random = seeded([...weather].reduce((sum, char) => sum + (char.codePointAt(0) ?? 0), 0));
    const encounter = generateEncounter("challenge", 60, 12, 13, weather, random);
    encounter.duration_limit = 12;
    const result = runBattle(player([13, 16, 25, 28]), encounter, random);
    validate(result);
    assert.ok(result.events.length > 0);
  }
  assert.deepEqual([...MELEE_SKILL_IDS].sort((a, b) => a - b), [1, 2, 3, 4, 5, 6, 7, 8, 9, 12, 15, 16, 19, 27, 29, 34, 36]);
});

test("control, dot, shield and healing event families are all represented", () => {
  const resultFamilies = new Set<string>();
  for (const skillId of [13, 21, 22, 25, 27]) {
    const random = seeded(99 + skillId);
    const encounter = generateEncounter("challenge", 60, 12, 13, "sunny", random);
    encounter.duration_limit = 18;
    for (const event of runBattle(player([skillId]), encounter, random).events) resultFamilies.add(String(event.type));
  }
  for (const family of ["cast", "damage", "status", "shield", "heal"]) assert.ok(resultFamilies.has(family), `missing ${family} events`);
});

test("skill-damage bonuses affect skills but never the fallback basic attack", () => {
  const basic = player([]);
  basic.skillDamage = 100;
  const basicResult = runBattle(basic, trainingEncounter(), () => 0.9);
  const basicHit = basicResult.events.find((event) => event.type === "damage" && event.source?.side === "player");
  assert.equal(basicHit?.amount, 12_000);

  const skill = player([1]);
  skill.skillDamage = 100;
  const skillResult = runBattle(skill, trainingEncounter(), () => 0.9);
  const skillHit = skillResult.events.find((event) => event.type === "damage" && event.source?.side === "player");
  assert.equal(skillHit?.amount, 36_000);
});

test("challenge gold rewards honor the authoritative gold bonus", () => {
  const base = player([]);
  base.goldBonus = 0;
  const boosted = { ...base, goldBonus: 100 };
  const normalResult = runBattle(base, trainingEncounter(), () => 0.9);
  const boostedResult = runBattle(boosted, trainingEncounter(), () => 0.9);
  assert.ok(normalResult.gold_gain > 0);
  assert.equal(boostedResult.gold_gain, normalResult.gold_gain * 2);
});

test("iron wall counterattack uses 30 percent of the defender attack", () => {
  const encounter = trainingEncounter();
  const result = runBattle({
    ...player([]), currentHp: 10_000, maxHp: 10_000, attack: 200, defense: 0, block: 100,
    setCounts: { 铁壁: 2 }, setAffixes: ["【铁壁】反击"],
  }, encounter, () => .9);
  const counter = result.events.find((event) => event.label === "铁壁反击");
  assert.equal(counter?.amount, 60);
});

test("iron wall four-piece reflection goes through defense reduction", () => {
  const encounter = trainingEncounter();
  encounter.units[0]!.def = 1000;
  const result = runBattle({
    ...player([]), currentHp: 1_000, maxHp: 1_000, attack: 1, defense: 0, block: 100,
    setCounts: { 铁壁: 4 }, setAffixes: [],
  }, encounter, () => .9);
  const reflected = result.events.find((event) => event.label === "铁壁·生命反伤");
  assert.ok(reflected);
  assert.ok(Number(reflected.amount) < 500);
});

test("luxury set charges real battle gold every ten seconds and disables below the threshold", () => {
  const luxury = {
    ...player([]), level: 10, attack: 100, battleGold: 1_100,
    setCounts: { 奢侈: 3 }, setAffixes: [],
  };
  const encounter = trainingEncounter();
  encounter.duration_limit = 25;
  const result = runBattle(luxury, encounter, () => .9);
  assert.equal(result.luxury_gold_spent, 1_000);
  assert.ok(result.events.some((event) => event.type === "damage" && Number(event.amount) <= 100));
});

test("silence increases basic attack damage without changing skill damage", () => {
  const base = trainingEncounter();
  base.duration_limit = 5;
  const silenced = structuredClone(base);
  silenced.units[0]!.skill_ids = [17];
  silenced.units[0]!.speed_points = 50;
  const baseline = runBattle({ ...player([]), attack: 100 }, base, () => .9);
  const withSilence = runBattle({ ...player([]), attack: 100 }, silenced, () => .9);
  const baselineHit = baseline.events.find((event) => event.type === "damage" && event.source?.side === "player");
  const silencedHit = withSilence.events.find((event) => event.type === "damage" && event.source?.side === "player");
  assert.equal(baselineHit?.amount, 100);
  assert.equal(silencedHit?.amount, 120);
});

test("enemy skill damage remains finite and changes the authoritative player HP", () => {
  const encounter = {
    battle_kind: "battle" as const,
    monster_level: 10,
    template_id: "regression-enemy-skill",
    template_name: "敌方技能回归",
    units: [{
      id: 1, name: "测试射手", display_name: "测试射手", row: "front" as const, level: 10,
      max_hp: 99_999, current_hp: 99_999, atk: 120, def: 10, speed_points: 35, action_cd: 2.16,
      crit: 0, critdmg: 150, hit: 100, dodge: 0, block: 0, skill_ids: [10], passives: [],
      is_elite: false, is_boss: false, infinite_hp: false, template_id: "regression-enemy-skill",
    }],
    formation: { front: [1], back: [] }, duration_limit: 0, weather: "sunny",
  };
  const result = runBattle({
    name: "测试勇者", level: 10, currentHp: 10_000, maxHp: 10_000, attack: 1, defense: 10,
    speedPoints: 0, crit: 0, critDamage: 150, hit: 100, dodge: 0, block: 0, skillDamage: 0,
    cooldownReduction: 0, lifesteal: 0, freeAttackPct: 0, freeDefensePct: 0, goldBonus: 0,
    experienceBonus: 0, luck: 0, skillSlots: [], battleDamageMultiplier: 1, incomingDamageMultiplier: 1,
    passives: [], setCounts: {}, setAffixes: [], battleGold: 0,
  }, encounter, () => 0.9);
  const enemyDamage = result.events.filter((event) => event.type === "damage" && event.source?.side === "enemy");
  assert.ok(enemyDamage.length > 0);
  assert.ok(enemyDamage.every((event) => Number.isFinite(event.amount) && Number(event.amount) > 0));
  assert.ok(result.player_hp < result.player_max_hp);
});

test("set healing and shadow hit bonuses affect authoritative combat", () => {
  const nature = player([22]);
  nature.currentHp = 1_000;
  nature.maxHp = 10_000;
  nature.attack = 100;
  nature.setCounts = { 自然: 3 };
  const natureResult = runBattle(nature, trainingEncounter(), () => 0.9);
  const natureHeal = natureResult.events.find((event) => event.type === "heal" && event.label === "治疗波");
  assert.equal(natureHeal?.amount, 180);

  const noShadow = player([1]);
  noShadow.currentHp = 10_000;
  noShadow.maxHp = 10_000;
  noShadow.attack = 100;
  noShadow.hit = 0;
  const shadow = { ...noShadow, setCounts: { 暗影: 3 } };
  const dodgeTraining = trainingEncounter();
  dodgeTraining.units[0]!.dodge = 30;
  const without = runBattle(noShadow, dodgeTraining, () => 0.15);
  const withShadow = runBattle(shadow, dodgeTraining, () => 0.15);
  assert.ok(without.events.some((event) => event.type === "miss"));
  assert.ok(withShadow.events.some((event) => event.type === "damage" && event.source?.side === "player"));
});
