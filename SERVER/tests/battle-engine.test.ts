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
