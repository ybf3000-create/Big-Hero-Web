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
    experienceBonus: 0, skillSlots: skillIds.map((skillId) => ({ skillId, priority: 3 })), battleDamageMultiplier: 1,
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
    validate(runBattle(player([5, 18, 25, 36]), encounter, random));
  }
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
    experienceBonus: 0, skillSlots: [], battleDamageMultiplier: 1, incomingDamageMultiplier: 1,
    passives: [], setCounts: {}, setAffixes: [], battleGold: 0,
  }, encounter, () => 0.9);
  const enemyDamage = result.events.filter((event) => event.type === "damage" && event.source?.side === "enemy");
  assert.ok(enemyDamage.length > 0);
  assert.ok(enemyDamage.every((event) => Number.isFinite(event.amount) && Number(event.amount) > 0));
  assert.ok(result.player_hp < result.player_max_hp);
});
