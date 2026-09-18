import { randomUUID } from "node:crypto";
import { BattleOutcome, runBattle, type BattlePlayerState } from "./battle-engine.js";
import { BOSS_NAMES, ELITE_TEMPLATES, EQUIPMENT_SLOTS, GRID_ICONS, GRID_NAMES, MONSTER_DEFS, NORMAL_TEMPLATES, QUALITY_NAMES, QUALITY_WEIGHTS, SET_AFFIXES, SET_NAMES, itemById, skillById } from "./game-catalog.js";
import { addItem, defaultGameState, recalculateStats, reconcileAttributePoints, removeItem, type EquipmentItem, type FreeAttributes, type GameState } from "./game-state.js";
import { generateEncounter } from "./monster-generator.js";

export interface CharacterProgress {
  name?: string;
  level: number;
  experience: number;
  gold: number;
}

export interface GameCommandResult {
  state: GameState;
  character: CharacterProgress;
  event: Record<string, unknown>;
}

const EXPANSION_COSTS = [5_000, 15_000, 30_000, 50_000, 75_000, 100_000, 150_000, 200_000, 300_000, 400_000, 500_000, 750_000, 1_000_000, 1_500_000];
const MONSTER_ASSETS = ["char_0001.png", "char_0007.png", "char_0016.png", "char_0031.png", "char_0048.png", "char_0067.png", "char_0085.png", "char_0094.png", "char_0125.png", "char_0170.png", "char_0198.png", "char_0240.png", "char_0305.png", "char_0371.png", "char_0430.png"];
const MAX_BOSS_INDEX = 200;
const QUALITY_COEFFICIENTS = [1, 1.2, 1.5, 2, 3];
const AFFIX_COUNTS = [1, 2, 3, 4, 5];
const SET_QUALITY_MODIFIERS = [1.5, 1.2, 1, 0.7, 0.4];
const AFFIX_POOL = [
  ["攻击%", "attack", 3, 15, "%"], ["暴击率", "attack", 1, 8, "%"], ["暴击伤害", "attack", 5, 25, "%"],
  ["技能伤害", "attack", 3, 15, "%"], ["命中", "attack", 1, 8, "%"], ["防御%", "defense", 3, 12, "%"],
  ["生命%", "defense", 3, 15, "%"], ["格挡率", "defense", 1, 25, "%"], ["闪避率", "defense", 1, 25, "%"],
  ["吸血", "defense", 1, 5, "%"], ["速度", "universal", 2, 15, ""], ["冷却缩减", "universal", 2, 10, "%"],
  ["幸运", "universal", 2, 15, ""], ["金币加成", "universal", 5, 25, "%"], ["经验加成", "universal", 3, 10, "%"],
  ["攻击(数值)", "attack", 5, 50, ""], ["防御(数值)", "defense", 5, 40, ""],
] as const;
const ESSENCE_BY_QUALITY = [1, 3, 8, 20, 50] as const;
const REROLL_COSTS = {
  0: { essence: 15, epicGold: 5_000, legendaryGold: 10_000 },
  1: { essence: 30, epicGold: 10_000, legendaryGold: 20_000 },
  2: { essence: 100, epicGold: 30_000, legendaryGold: 60_000 },
} as const;

function bossName(index: number): string {
  return BOSS_NAMES[Math.min(20, Math.max(1, index)) - 1] ?? "暗影";
}

function expandMapAfterBoss(state: GameState, clearedTier: number): void {
  if (clearedTier > 20 || state.mapTotalGrids >= 128) return;
  const target = Math.min(128, 28 + clearedTier * 5);
  const plans: number[][] = [
    [1, 1, 2, 5, 12], [1, 1, 7, 6, 13], [1, 1, 2, 5, 13], [1, 1, 7, 7, 9],
    [1, 1, 2, 5, 9], [1, 1, 7, 6, 8], [1, 1, 2, 5, 8], [1, 1, 7, 8, 10],
    [1, 1, 2, 5, 10], [1, 1, 7, 6, 3], [1, 1, 2, 5, 3], [1, 1, 7, 8, 14],
    [1, 1, 2, 5, 13], [1, 1, 7, 13, 11], [1, 1, 2, 5, 11], [1, 1, 7, 6, 13],
    [1, 1, 2, 5, 13], [1, 1, 7, 8, 11], [1, 1, 2, 5, 13], [1, 1, 4, 6, 13],
  ];
  const previous = state.mapGrids;
  const protectedIndices = new Set<number>();
  for (let offset = -3; offset <= 3; offset += 1) {
    protectedIndices.add((state.gridIndex + offset + state.mapTotalGrids) % state.mapTotalGrids);
  }
  const counts = new Map<number, number>();
  for (const grid of [...previous, ...(plans[clearedTier - 1] ?? [])].slice(0, target)) {
    counts.set(grid, (counts.get(grid) ?? 0) + 1);
  }
  for (const index of protectedIndices) {
    const grid = previous[index] ?? 1;
    counts.set(grid, Math.max(0, (counts.get(grid) ?? 0) - 1));
  }
  const pool: number[] = [];
  for (let grid = 0; grid <= 14; grid += 1) {
    for (let count = counts.get(grid) ?? 0; count > 0; count -= 1) pool.push(grid);
  }
  let shuffled = [...pool];
  for (let attempt = 0; attempt < 80; attempt += 1) {
    shuffled = [...pool];
    for (let index = shuffled.length - 1; index > 0; index -= 1) {
      const selected = Math.floor(Math.random() * (index + 1));
      [shuffled[index], shuffled[selected]] = [shuffled[selected]!, shuffled[index]!];
    }
    const positions = (type: number) => shuffled.flatMap((grid, index) => grid === type ? [index] : []);
    const separated = (type: number, gap: number) => positions(type).every((index, position, indices) => position === 0 || index - indices[position - 1]! >= gap);
    const lightningBossGap = positions(10).every((light) => positions(11).every((boss) => Math.abs(light - boss) >= 8));
    if (separated(2, 3) && separated(4, 5) && separated(13, 6) && lightningBossGap && !shuffled.some((grid, index) => grid === 13 && shuffled[index + 1] === 13 && shuffled[index + 2] === 13)) break;
  }
  let cursor = 0;
  const rebuilt: number[] = [];
  for (let index = 0; index < target; index += 1) {
    rebuilt.push(protectedIndices.has(index) ? previous[index]! : (shuffled[cursor++] ?? 1));
  }
  state.mapGrids = rebuilt;
  state.mapTotalGrids = target;
}

function expansionCost(count: number): number {
  if (count < EXPANSION_COSTS.length) return EXPANSION_COSTS[count] ?? 5_000;
  return Math.floor((EXPANSION_COSTS.at(-1) ?? 1_500_000) * (1.3 ** (count - EXPANSION_COSTS.length + 1)));
}

function numberValue(value: unknown, fallback = 0): number {
  return typeof value === "number" && Number.isFinite(value) ? value : fallback;
}

function levelUp(character: CharacterProgress): string[] {
  const messages: string[] = [];
  while (character.level < 100 && character.experience >= Math.floor(100 * 1.12 ** (character.level - 1))) {
    character.experience -= Math.floor(100 * 1.12 ** (character.level - 1));
    character.level += 1;
    messages.push(`等级提升至 ${character.level}，获得2点自由属性点`);
  }
  if (character.level >= 100) character.experience = 0;
  return messages;
}

function reward(state: GameState, character: CharacterProgress, gold: number, experience: number): string[] {
  character.gold = Math.min(9_000_000_000_000_000, character.gold + Math.max(0, Math.floor(gold)));
  character.experience += Math.max(0, Math.floor(experience));
  return levelUp(character);
}

function qualityRoll(minimum = 0, maximum = QUALITY_WEIGHTS.length - 1): number {
  const min = Math.max(0, Math.min(QUALITY_WEIGHTS.length - 1, minimum));
  const max = Math.max(min, Math.min(QUALITY_WEIGHTS.length - 1, maximum));
  const total = QUALITY_WEIGHTS.slice(min, max + 1).reduce((sum, weight) => sum + weight, 0);
  const roll = Math.random() * total;
  let cursor = 0;
  for (let index = min; index <= max; index += 1) {
    cursor += QUALITY_WEIGHTS[index] ?? 0;
    if (roll <= cursor) return index;
  }
  return max;
}

function equipmentTier(level: number, bossTier: number): number {
  let result = Math.max(1, level);
  for (let tier = 1; tier <= bossTier; tier += 1) {
    const interval = tier <= 30 ? 20 : tier <= 60 ? 10 : tier <= 100 ? 6 : tier <= 150 ? 4 : 3;
    if (tier % interval === 0) result += 1;
  }
  return result;
}

function generateEquipment(level: number, bossTier = 0, minimumQuality = 0, maximumQuality = 4, luck = 0): EquipmentItem {
  const slot = EQUIPMENT_SLOTS[Math.floor(Math.random() * EQUIPMENT_SLOTS.length)] ?? EQUIPMENT_SLOTS[0];
  const quality = qualityRoll(minimumQuality, maximumQuality);
  let mainValue = slot.base * (QUALITY_COEFFICIENTS[quality] ?? 1);
  if (!["shoes", "ring", "necklace", "helmet"].includes(slot.key)) {
    mainValue *= 1 + (equipmentTier(level, bossTier) - 1) * 0.015;
  }
  mainValue = Math.round(mainValue * 10) / 10;
  const affixes: NonNullable<EquipmentItem["affixes"]> = [];
  const used = new Set<string>();
  let attackCount = 0;
  let defenseCount = 0;
  for (let count = AFFIX_COUNTS[quality] ?? 1; count > 0; count -= 1) {
    for (let retry = 0; retry < 10; retry += 1) {
      const definition = AFFIX_POOL[Math.floor(Math.random() * AFFIX_POOL.length)]!;
      const [name, type, minimum, maximum, suffix] = definition;
      if (used.has(name) || (name === "攻击%" && used.has("攻击(数值)")) || (name === "攻击(数值)" && used.has("攻击%")) || (name === "防御%" && used.has("防御(数值)")) || (name === "防御(数值)" && used.has("防御%"))) continue;
      if (type === "attack" && attackCount >= 2) continue;
      if (type === "defense" && defenseCount >= 2) continue;
      const value = Math.round((minimum + Math.random() * (maximum - minimum)) * 10) / 10;
      affixes.push({ name, type, value, display: `+${value}${suffix}` });
      used.add(name);
      if (type === "attack") attackCount += 1;
      if (type === "defense") defenseCount += 1;
      break;
    }
  }
  const gemSlots = quality >= 3 ? (Math.random() < 0.6 ? 1 : Math.random() < 0.75 ? 2 : 3) : 0;
  const setChance = ((3 + Math.max(0, luck) * 0.3) * (SET_QUALITY_MODIFIERS[quality] ?? 1)) / 100;
  const suitName = Math.random() < setChance ? SET_NAMES[Math.floor(Math.random() * SET_NAMES.length)] ?? "" : "";
  const setPool = suitName ? SET_AFFIXES[suitName] ?? [] : [];
  const setName = setPool[Math.floor(Math.random() * setPool.length)];
  return {
    id: randomUUID(),
    slot: slot.key,
    name: `${QUALITY_NAMES[quality]}${slot.name}`,
    baseName: slot.name,
    icon: slot.icon,
    iconPath: "",
    slotTypeId: slot.typeId,
    quality,
    enhance: 0,
    mainStat: slot.mainStat,
    mainValue,
    affixes,
    gems: [],
    gemSlots,
    initialGemSlots: gemSlots,
    acquiredAt: Date.now(),
    suitName,
    extraSuitName: "",
    setAffixes: setName ? [{ name: setName, type: "set" }] : [],
    locked: quality >= 4,
    bound: false,
  };
}

function addGem(state: GameState, gemId: number, level = 1, count = 1, bound = false): boolean {
  const current = state.gemBag.find((entry) => entry.gemId === gemId && (entry.level ?? 1) === level && Boolean(entry.bound) === bound);
  if (current) current.count += count;
  else state.gemBag.push({ gemId, level, count, ...(bound ? { bound: true } : {}) });
  return true;
}

function takeGems(state: GameState, gemId: number, level: number, count: number): { ok: boolean; bound: boolean } {
  const candidates = state.gemBag.filter((entry) => entry.gemId === gemId && (entry.level ?? 1) === level);
  if (candidates.reduce((sum, entry) => sum + entry.count, 0) < count) return { ok: false, bound: false };
  let remaining = count;
  let consumedBound = false;
  candidates.sort((left, right) => Number(Boolean(right.bound)) - Number(Boolean(left.bound)));
  for (const entry of candidates) {
    const taken = Math.min(entry.count, remaining);
    entry.count -= taken;
    consumedBound ||= Boolean(entry.bound) && taken > 0;
    remaining -= taken;
    if (remaining === 0) break;
  }
  state.gemBag = state.gemBag.filter((entry) => entry.count > 0);
  return { ok: true, bound: consumedBound };
}

function gemParts(raw: number | { id: number; level?: number; bound?: boolean }): { id: number; level: number; bound: boolean } {
  return typeof raw === "number"
    ? { id: raw, level: 1, bound: false }
    : { id: Number(raw.id), level: Math.max(1, Math.floor(Number(raw.level ?? 1))), bound: Boolean(raw.bound) };
}

function returnEquipmentGems(state: GameState, item: EquipmentItem): void {
  for (const raw of item.gems ?? []) {
    const gem = gemParts(raw);
    if (gem.id >= 1 && gem.id <= 8) addGem(state, gem.id, gem.level, 1, gem.bound);
  }
}

function equipmentMatchesRules(item: EquipmentItem, rules: Record<string, unknown>): boolean {
  const listKeys = ["qualities", "slots", "affix_types", "initial_sockets", "suits"];
  const hasConstraint = listKeys.some((key) => Array.isArray(rules[key]) && (rules[key] as unknown[]).length > 0)
    || numberValue(rules.affix_min, 0) > 0
    || numberValue(rules.affix_max, 8) < 8;
  // 六个维度全部为空表示“不保留任何装备”，启用后所有未锁定掉落都会分解。
  if (!hasConstraint) return false;
  const includesOrAll = (key: string, value: unknown) => {
    const entries = rules[key];
    return !Array.isArray(entries) || entries.length === 0 || entries.includes(value);
  };
  if (!includesOrAll("qualities", item.quality)) return false;
  if (!includesOrAll("slots", item.slotTypeId ?? EQUIPMENT_SLOTS.find((slot) => slot.key === item.slot)?.typeId ?? -1)) return false;
  const affixCount = (item.affixes?.length ?? 0) + (item.setAffixes?.length ?? 0);
  if (affixCount < numberValue(rules.affix_min, 0) || affixCount > numberValue(rules.affix_max, 8)) return false;
  const types = Array.isArray(rules.affix_types) ? rules.affix_types : [];
  if (types.length > 0 && ![...(item.affixes ?? []), ...(item.setAffixes ?? [])].some((affix) => types.includes(affix.type))) return false;
  if (!includesOrAll("initial_sockets", item.initialGemSlots ?? item.gemSlots ?? 0)) return false;
  if (!includesOrAll("suits", item.suitName || "none")) return false;
  return true;
}

function receiveEquipment(state: GameState, item: EquipmentItem): { accepted: boolean; essence: number } {
  if (state.autoDismantleEnabled && !item.locked && !equipmentMatchesRules(item, state.autoDismantleRules)) {
    const essence = ESSENCE_BY_QUALITY[Math.max(0, Math.min(4, item.quality))] ?? 1;
    state.dismantleEssence += essence;
    return { accepted: false, essence };
  }
  if (state.equipmentBag.length >= state.equipmentCapacity) {
    const candidates = state.equipmentBag.filter((entry) => !entry.locked && !Object.values(state.equipped).includes(entry.id));
    candidates.sort((left, right) => left.quality - right.quality || (left.acquiredAt ?? 0) - (right.acquiredAt ?? 0));
    const removed = candidates[0];
    if (!removed) return { accepted: false, essence: 0 };
    state.equipmentBag = state.equipmentBag.filter((entry) => entry.id !== removed.id);
    returnEquipmentGems(state, removed);
    state.dismantleEssence += ESSENCE_BY_QUALITY[Math.max(0, Math.min(4, removed.quality))] ?? 1;
  }
  state.equipmentBag.push(item);
  return { accepted: true, essence: 0 };
}

function rerollAffixes(item: EquipmentItem, lockedIndices: number[]): void {
  if (item.quality < 3 || item.quality > 4 || lockedIndices.length > 2 || !item.affixes?.length) throw new Error("装备无法重铸");
  if (lockedIndices.some((index) => !Number.isInteger(index) || index < 0 || index >= item.affixes!.length)) throw new Error("锁定词条不存在");
  const used = new Set(lockedIndices.map((index) => item.affixes![index]!.name));
  item.affixes = item.affixes.map((affix, index) => {
    if (lockedIndices.includes(index)) return affix;
    const candidates = AFFIX_POOL.filter(([name]) => !used.has(name));
    const [name, type, minimum, maximum, suffix] = candidates[Math.floor(Math.random() * candidates.length)]!;
    const value = Math.round((minimum + Math.random() * (maximum - minimum)) * 10) / 10;
    used.add(name);
    return { name, type, value, display: `+${value}${suffix}` };
  });
}

function pokerReward(state: GameState, character: CharacterProgress): Record<string, unknown> | null {
  if (state.pokerRecords.length < 3) return null;
  const records = state.pokerRecords.slice(-3);
  state.pokerRecords = [];
  const values = records.map((entry) => entry.value).sort((left, right) => left - right);
  const flush = records.every((entry) => entry.suit === records[0]!.suit);
  const straight = values[1]! - values[0]! === 1 && values[2]! - values[1]! === 1;
  const maxCount = Math.max(...values.map((value) => values.filter((entry) => entry === value).length));
  const hand = flush && straight ? ["同花顺", 10] : maxCount === 3 ? ["三条", 6] : straight ? ["顺子", 4] : flush ? ["同花", 3] : maxCount === 2 ? ["一对", 2] : null;
  if (!hand) return { matched: false };
  const base = Math.floor(Math.random() * 41) + 10;
  const gold = character.level * base * Number(hand[1]);
  character.gold = Math.min(9_000_000_000_000_000, character.gold + gold);
  return { matched: true, hand: hand[0], multiplier: hand[1], base, gold, message: `${hand[0]} ×${hand[1]}，+${gold}金币` };
}

function weightedPick<T extends { weight: number }>(entries: T[]): T {
  const total = entries.reduce((sum, entry) => sum + entry.weight, 0);
  let roll = Math.random() * total;
  for (const entry of entries) {
    roll -= entry.weight;
    if (roll < 0) return entry;
  }
  return entries.at(-1)!;
}

function tickWeatherRoll(state: GameState): void {
  if (state.bossTier < 6) {
    state.weather = "sunny";
    return;
  }
  state.weatherRollCount += 1;
  if (state.weatherRollCount < state.weatherRollTarget) return;
  state.weatherRollCount = 0;
  state.weatherRollTarget = Math.floor(Math.random() * 15) + 1;
  if (state.weatherSunnyBuffer > 0) {
    state.weatherSunnyBuffer -= 1;
    state.weather = "sunny";
    return;
  }
  const pool = [
    { id: "sunny", weight: 58 }, { id: "thunderstorm", weight: 10 }, { id: "drizzle", weight: 8 },
    { id: "fog", weight: 7 }, { id: "blizzard", weight: 7 }, { id: "scorching_sun", weight: 5 },
    { id: "sandstorm", weight: 3 }, { id: "aurora", weight: 2 },
  ];
  const previous = state.weather;
  for (let attempt = 0; attempt < 2; attempt += 1) {
    state.weather = weightedPick(pool).id;
    if (state.weather !== previous) break;
  }
}

function lotteryLapDraw(state: GameState, character: CharacterProgress): Record<string, unknown> | null {
  if (state.lotteryTicketNumbers.length === 0 || state.completedLaps - state.lotteryLastDrawLap < 5) return null;
  const winningNumber = Math.floor(Math.random() * 1_000);
  const won = state.lotteryTicketNumbers.includes(winningNumber);
  state.lotteryTicketNumbers = [];
  state.lotteryTickets = 0;
  state.lotteryLastDrawLap = state.completedLaps;
  const rewards: Record<string, unknown> = {};
  if (won) {
    const gold = Math.max(10_000, character.level * 5_000);
    character.gold = Math.min(9_000_000_000_000_000, character.gold + gold);
    addGem(state, Math.floor(Math.random() * 8) + 1, 3);
    addItem(state, 5, 1);
    for (const quality of [2, 3, 4]) {
      receiveEquipment(state, generateEquipment(character.level, state.bossTier, quality, quality, state.stats.luck));
    }
    rewards.gold = gold;
  }
  return { winningNumber, won, rewards };
}

function tickLapEffects(state: GameState, character: CharacterProgress): Record<string, unknown> | null {
  if (state.hibernateLaps > 0) state.hibernateLaps -= 1;
  state.deityBuffs = state.deityBuffs
    .map((buff) => ({ ...buff, turns: Math.max(0, numberValue(buff.turns, 1) - 1) }))
    .filter((buff) => numberValue(buff.turns) > 0);
  return lotteryLapDraw(state, character);
}

function fateEvent(state: GameState, character: CharacterProgress): Record<string, unknown> {
  if (state.weather !== "sunny" && state.bossTier >= 6 && Math.random() < Math.min(1, (30 + state.stats.luck * .5) / 100)) {
    if (state.weather === "blizzard") { state.hibernateLaps = Math.max(state.hibernateLaps, 1); return { type: "special", name: "冬眠", hibernateLaps: 1, message: "冬眠：本圈普通怪物直接结算胜利" }; }
    if (state.weather === "drizzle") { const before = state.reviveCoins; state.reviveCoins = Math.min(3, before + 1); return { type: "reward", name: "滋润", message: `滋润：复活币+${state.reviveCoins - before}` }; }
    if (state.weather === "fog") return { type: "special", name: "雾中秘径", teleportTreasure: true, message: "雾中秘径：前往宝箱格" };
    if (state.weather === "sandstorm") { const gold = character.level * 200; character.gold += gold; return { type: "reward", name: "沙中淘金", gold, message: `沙中淘金：+${gold}金币` }; }
    if (state.weather === "aurora") {
      const equipment = generateEquipment(character.level, state.bossTier, 4, 4, state.stats.luck);
      receiveEquipment(state, equipment);
      return { type: "equipment", name: "许愿", equipment, message: "许愿：获得传说装备" };
    }
  }
  const selected = weightedPick([
    { name: "股市大涨", weight: 6 }, { name: "宝石行情好", weight: 6 }, { name: "技能大赛", weight: 7 },
    { name: "天命降临", weight: 6 }, { name: "装备促销", weight: 6 }, { name: "小憩", weight: 7 },
    { name: "获得宝石", weight: 6 }, { name: "获得打孔器", weight: 6 }, { name: "股市崩盘", weight: 8 },
    { name: "暴风雨", weight: 7 }, { name: "拆迁通知", weight: 7 }, { name: "诅咒降临", weight: 8 },
    { name: "攻击削弱", weight: 5 }, { name: "传送门", weight: 8 }, { name: "命运逆转", weight: 7 },
  ]).name;
  if (selected === "股市大涨") {
    const gold = Math.max(100, Math.min(50_000, Math.floor(character.gold * .05)));
    character.gold += gold;
    return { type: "reward", name: selected, gold, message: `股市大涨！+${gold} 金币` };
  }
  if (selected === "股市崩盘") {
    const gold = Math.min(character.gold, Math.max(100, Math.min(10_000, Math.floor(character.gold * .05))));
    character.gold -= gold;
    return { type: "punish", name: selected, gold: gold === 0 ? 0 : -gold, message: `股市崩盘！-${gold} 金币` };
  }
  if (selected === "小憩") {
    const healing = Math.floor(state.maxHp / 2);
    state.hp = Math.min(state.maxHp, state.hp + healing);
    state.nextRollModifier = 1;
    return { type: "reward", name: selected, healing, nextStepBonus: 1, message: "小憩恢复50%生命，下次步数+1" };
  }
  if (selected === "获得宝石" || selected === "宝石行情好") {
    const gemId = Math.floor(Math.random() * 8) + 1;
    const level = selected === "宝石行情好" ? 2 : 1;
    addGem(state, gemId, level);
    return { type: "reward", name: selected, gemId, level, message: selected === "宝石行情好" ? "宝石行情好：获得Lv.2宝石" : `获得宝石 #${gemId}` };
  }
  if (selected === "获得打孔器") {
    addItem(state, 6, 1);
    return { type: "reward", name: selected, itemId: 6, message: "获得打孔器×1" };
  }
  if (selected === "技能大赛") {
    state.buffs.skillBoost = 3;
    return { type: "reward", name: selected, message: "未来3场战斗伤害+30%" };
  }
  if (selected === "攻击削弱") {
    state.buffs.damagePenalty = 3;
    return { type: "punish", name: selected, message: "未来3场战斗伤害-30%" };
  }
  if (selected === "诅咒降临") {
    state.buffs.damagePenalty = 3;
    return { type: "punish", name: selected, message: "诅咒降临：未来3场伤害-20%" };
  }
  if (selected === "天命降临") {
    addItem(state, 5, 1);
    return { type: "reward", name: selected, itemId: 5, message: "获得天命卡×1" };
  }
  if (selected === "装备促销") {
    const equipment = generateEquipment(character.level, state.bossTier, 1, 4, state.stats.luck);
    const received = receiveEquipment(state, equipment);
    return { type: "equipment", name: selected, equipment: received.accepted ? equipment : null, message: received.accepted ? `装备促销：获得${equipment.name}` : received.essence > 0 ? `装备促销：自动分解为${received.essence}精华` : "装备背包已满" };
  }
  if (selected === "暴风雨") { state.nextRollModifier = -1; return { type: "punish", name: selected, nextStepPenalty: 1, message: "暴风雨：下次骰子步数-1" }; }
  if (selected === "拆迁通知") { const loss = Math.min(character.gold, Math.max(100, character.level * 50)); character.gold -= loss; return { type: "punish", name: selected, gold: -loss, message: `拆迁通知：支付${loss}金币` }; }
  if (selected === "传送门") return { type: "special", name: selected, teleport: true, message: "传送门！传送到闪电格" };
  const healing = state.maxHp - state.hp; state.hp = state.maxHp;
  return { type: "special", name: "命运逆转", healing, message: `命运逆转：恢复${healing}生命` };
}

function deityEvent(state: GameState, character: CharacterProgress): Record<string, unknown> {
  const selected = weightedPick([
    { name: "财神", type: "bless", weight: 15, stat: "gold_mult", value: 2, turns: 3, description: "金币收益×2" },
    { name: "战神", type: "bless", weight: 15, stat: "war_god", value: 1, turns: 3, description: "伤害×1.5，受伤×0.7" },
    { name: "速神", type: "bless", weight: 15, stat: "cd_mult", value: .8, turns: 3, description: "仅技能冷却×0.8" },
    { name: "福神", type: "bless", weight: 15, stat: "quality_up_chance", value: .3, turns: 2, description: "掉落装备30%概率品质+1" },
    { name: "衰神", type: "curse", weight: 15, stat: "decline_god", value: 1, turns: 2, description: "伤害×0.7，受伤×1.5" },
    { name: "穷神", type: "curse", weight: 8, stat: "gold_mult", value: .5, turns: 2, description: "金币收益×0.5" },
    { name: "懒神", type: "curse", weight: 7, stat: "cd_mult", value: 1.3, turns: 2, description: "技能冷却×1.3" },
    { name: "命运之神", type: "special", weight: 10, stat: "fate_now", value: 1, turns: 0, description: "立即触发一次命运事件" },
  ]);
  if (selected.stat === "fate_now") return { kind: "deity", deity: selected.name, immediateFate: fateEvent(state, character), message: `遇到${selected.name}：${selected.description}` };
  state.deityBuffs.push({ name: selected.name, stat: selected.stat, value: selected.value, turns: selected.turns });
  return { kind: "deity", deity: selected.name, effect: { stat: selected.stat, value: selected.value, turns: selected.turns }, message: `遇到${selected.name}：${selected.description}` };
}

function synthesizeEquipment(state: GameState, character: CharacterProgress): Record<string, unknown> {
  const candidates = state.equipmentBag.filter((equipment) => !Object.values(state.equipped).includes(equipment.id));
  if (candidates.length < 2) return { kind: "synthesize", success: false, message: "背包装备不足2件，无法合成" };
  const firstIndex = Math.floor(Math.random() * candidates.length);
  let secondIndex = Math.floor(Math.random() * (candidates.length - 1));
  if (secondIndex >= firstIndex) secondIndex += 1;
  const first = candidates[firstIndex]!;
  const second = candidates[secondIndex]!;
  if (first.locked || second.locked) return { kind: "synthesize", success: false, message: "选中的合成材料已锁定，合成终止" };
  for (const equipment of [first, second]) returnEquipmentGems(state, equipment);
  const low = Math.min(first.quality, second.quality);
  const high = Math.max(first.quality, second.quality);
  const quality = first.quality === second.quality
    ? Math.min(4, first.quality + 1)
    : low + Math.floor(Math.random() * (Math.min(4, high + 1) - low + 1));
  const generated = generateEquipment(character.level, state.bossTier, quality, quality, state.stats.luck);
  generated.slot = Math.random() < .5 ? first.slot : second.slot;
  const slotDefinition = EQUIPMENT_SLOTS.find((slot) => slot.key === generated.slot);
  if (slotDefinition) {
    generated.baseName = slotDefinition.name;
    generated.name = `${QUALITY_NAMES[quality]}${slotDefinition.name}`;
    generated.mainStat = slotDefinition.mainStat;
    generated.icon = slotDefinition.icon;
    generated.slotTypeId = slotDefinition.typeId;
  }
  state.equipmentBag = state.equipmentBag.filter((equipment) => equipment.id !== first.id && equipment.id !== second.id);
  receiveEquipment(state, generated);
  return { kind: "synthesize", success: true, equipment: generated, consumed: [first.id, second.id], message: `合成获得 [${QUALITY_NAMES[quality]}] ${generated.baseName}` };
}

function legacyBattle(state: GameState, character: CharacterProgress, kind: "normal" | "elite" | "boss"): Record<string, unknown> {
  const bossIndex = Math.max(1, Math.min(MAX_BOSS_INDEX, state.bossIndex));
  const templates = kind === "normal" ? NORMAL_TEMPLATES : kind === "elite" ? ELITE_TEMPLATES : [[bossName(bossIndex)]];
  const names = templates[Math.floor(Math.random() * templates.length)] ?? ["史莱姆·战士"];
  const scale = (character.level + (kind === "elite" ? 4 : kind === "boss" ? 10 : 0)) / 10;
  const playerStartHp = state.hp;
  const units: Array<Record<string, unknown> & { id: number; maxHp: number; currentHp: number; attack: number }> = [];
  let enemyHp = 0;
  let enemyAttack = 0;
  let enemyDefense = 0;
  for (const [index, name] of names.entries()) {
    if (!name) continue;
    const base = MONSTER_DEFS[name] ?? { hp: 1, atk: 1, def: 1, speed: 5 };
    const bossHpMultiplier = 8 + bossIndex * 0.15;
    const bossAttackMultiplier = 1.5 + bossIndex * 0.003;
    const bossDefenseMultiplier = 1.5 + bossIndex * 0.005;
    const bossLevel = character.level + 2;
    const unitHp = kind === "boss"
      ? Math.max(1, Math.round((500 + (bossLevel - 1) * 80) * bossHpMultiplier))
      : Math.max(50, Math.floor(base.hp * 300 * scale));
    const unitAttack = kind === "boss"
      ? Math.max(1, Math.round((25 + (bossLevel - 1) * 2) * bossAttackMultiplier))
      : Math.max(1, Math.floor(base.atk * 35 * scale));
    const unitDefense = kind === "boss"
      ? Math.max(0, Math.round((15 + (bossLevel - 1)) * bossDefenseMultiplier))
      : base.def * 12 * scale;
    enemyHp += unitHp;
    enemyAttack += unitAttack;
    enemyDefense += unitDefense;
    units.push({
      id: index + 1,
      name,
      displayName: name.replace("·", " "),
      row: index > 1 ? "back" : "front",
      maxHp: unitHp,
      currentHp: unitHp,
      attack: unitAttack,
      defense: unitDefense,
      speed: kind === "boss" ? (bossIndex <= 15 ? 15 : bossIndex <= 50 ? 25 : 35) : base.speed,
      isBoss: kind === "boss",
      ...(kind === "boss" ? { bossIndex } : {}),
      asset: kind === "boss" ? `${name}.png` : MONSTER_ASSETS[Math.abs([...name].reduce((sum, char) => sum + (char.codePointAt(0) ?? 0), 0)) % MONSTER_ASSETS.length],
    });
  }
  const selectedSkills = state.skillSlots.map((id) => skillById(id)).filter((skill) => skill !== undefined);
  const strongestSkill = selectedSkills.reduce((best, skill) => Math.max(best, (skill.damagePct ?? 100) * (skill.hits ?? 1)), 100);
  const buffMultiplier = (state.buffs.skillBoost ?? 0) > 0 ? 1.3 : (state.buffs.damagePenalty ?? 0) > 0 ? .7 : 1;
  const playerAttack = state.stats.attack
    * strongestSkill / 100
    * (1 + state.stats.skillDamage / 100)
    * (1 + state.attributes.attack * 0.018)
    * buffMultiplier;
  const playerDefense = state.stats.defense;
  let rounds = 0;
  let dealt = 0;
  let taken = 0;
  const events: Array<Record<string, unknown>> = [];
  const activeSkill = selectedSkills.reduce((best, skill) => ((skill.damagePct ?? 100) * (skill.hits ?? 1) > (best?.damagePct ?? 100) * (best?.hits ?? 1) ? skill : best), selectedSkills[0]);
  while (enemyHp > 0 && state.hp > 0 && rounds < 20) {
    rounds += 1;
    const critical = Math.random() * 100 < state.stats.crit;
    const damage = Math.max(1, Math.floor((playerAttack * (critical ? 1.8 : 1)) - enemyDefense));
    enemyHp -= damage;
    dealt += damage;
    events.push({ type: "cast", source: "player", sourceId: 0, skillName: activeSkill?.name ?? "普通攻击", skillIcon: activeSkill?.icon ?? "⚔" });
    let remainingDamage = damage;
    for (const target of units) {
      if (remainingDamage <= 0 || target.currentHp <= 0) continue;
      const applied = Math.min(remainingDamage, target.currentHp);
      target.currentHp -= applied;
      remainingDamage -= applied;
      events.push({ type: "damage", source: "player", sourceId: 0, target: "enemy", targetId: target.id, targetName: target.name, value: applied, critical, remainingHp: target.currentHp, maxHp: target.maxHp });
    }
    if (enemyHp > 0) {
      const defenseReduction = playerDefense / (playerDefense + 400);
      const freeDefenseReduction = Math.min(0.5, state.attributes.defense * 0.012);
      const incoming = Math.max(1, Math.floor(enemyAttack * (1 - defenseReduction) * (1 - freeDefenseReduction)));
      state.hp = Math.max(0, state.hp - incoming);
      taken += incoming;
      const attacker = units.find((unit) => unit.currentHp > 0) ?? units[0];
      events.push({ type: "damage", source: "enemy", sourceId: attacker?.id ?? 1, sourceName: attacker?.name ?? "敌人", target: "player", targetId: 0, value: incoming, critical: false, remainingHp: state.hp, maxHp: state.maxHp });
    }
  }
  const won = enemyHp <= 0;
  for (const name of ["skillBoost", "damagePenalty"]) {
    if ((state.buffs[name] ?? 0) > 0) state.buffs[name] = Math.max(0, (state.buffs[name] ?? 0) - 1);
  }
  if (won) {
    const multiplier = kind === "boss" ? 5 : kind === "elite" ? 2 : 1;
    const messages = reward(state, character, (60 + character.level * 12) * multiplier, (40 + character.level * 15) * multiplier);
    if (Math.random() < (kind === "boss" ? 1 : .35)) addItem(state, kind === "boss" ? 91 : 1, 1);
    const dropChance = kind === "boss" ? 1 : kind === "elite" ? .5 : .12;
    const equipment = Math.random() < dropChance && state.equipmentBag.length < state.equipmentCapacity
      ? generateEquipment(character.level, state.bossTier, kind === "boss" ? 3 : 0, 4, state.stats.luck)
      : null;
    if (equipment) receiveEquipment(state, equipment);
    const passiveHeal = selectedSkills.filter((skill) => skill.healPct).reduce((sum, skill) => sum + Math.floor(state.stats.attack * (skill.healPct ?? 0) / 100), 0);
    if (passiveHeal > 0) state.hp = Math.min(state.maxHp, state.hp + passiveHeal);
    if (kind === "boss") {
      state.bossTier = Math.min(MAX_BOSS_INDEX, state.bossTier + 1);
      state.bossIndex = Math.min(MAX_BOSS_INDEX, state.bossTier + 1);
      expandMapAfterBoss(state, state.bossTier);
    }
    return { kind: "battle", battleKind: kind, won: true, enemy: names, rounds, dealt, taken, skillPower: strongestSkill, playerStartHp, playerMaxHp: state.maxHp, playerBattleEndHp: Math.max(0, state.hp), encounter: { templateName: kind === "boss" ? "朱樱神社·首领" : kind === "elite" ? "朱樱山道·精英" : "朱樱山道", weather: state.weather, units }, events, rewards: { gold: (60 + character.level * 12) * multiplier, experience: (40 + character.level * 15) * multiplier, equipment, passiveHeal, messages } };
  }
  if (state.reviveCoins > 0) {
    state.reviveCoins -= 1;
    state.hp = state.maxHp;
    return { kind: "battle", battleKind: kind, won: false, enemy: names, rounds, dealt, taken, playerStartHp, playerMaxHp: state.maxHp, playerBattleEndHp: 0, encounter: { templateName: kind === "boss" ? "朱樱神社·首领" : "朱樱山道", weather: state.weather, units }, events, message: "战败，消耗1复活币重新站起", rewards: { reviveCoins: state.reviveCoins } };
  }
  const penalty = Math.floor(character.gold * .15);
  character.gold -= penalty;
  state.hp = state.maxHp;
  state.gridIndex = 0;
  return { kind: "battle", battleKind: kind, won: false, enemy: names, rounds, dealt, taken, playerStartHp, playerMaxHp: state.maxHp, playerBattleEndHp: 0, encounter: { templateName: kind === "boss" ? "朱樱神社·首领" : "朱樱山道", weather: state.weather, units }, events, message: `战败，强制回家并损失${penalty}金币`, rewards: { reviveCoins: 0, goldPenalty: penalty } };
}

function equippedBattleBonuses(state: GameState): { setCounts: Record<string, number>; setAffixes: string[] } {
  const setCounts: Record<string, number> = {};
  const setAffixes: string[] = [];
  for (const equipmentId of Object.values(state.equipped)) {
    if (!equipmentId) continue;
    const equipment = state.equipmentBag.find((entry) => entry.id === equipmentId);
    if (!equipment) continue;
    for (const setName of [equipment.suitName, equipment.extraSuitName]) {
      if (!setName) continue;
      setCounts[setName] = (setCounts[setName] ?? 0) + 1;
    }
    for (const affix of equipment.setAffixes ?? []) {
      if (!setAffixes.includes(affix.name)) setAffixes.push(affix.name);
    }
  }
  return { setCounts, setAffixes };
}

function originalBattle(state: GameState, character: CharacterProgress, kind: "battle" | "elite" | "boss" | "challenge"): Record<string, unknown> {
  const encounter = generateEncounter(kind, character.level, state.bossTier, state.bossIndex, state.weather);
  const sets = equippedBattleBonuses(state);
  let damageMultiplier = (state.buffs.skillBoost ?? 0) > 0 ? 1.3 : (state.buffs.damagePenalty ?? 0) > 0 ? .7 : 1;
  let incomingDamageMultiplier = 1;
  let cooldownModifier = 0;
  let goldBonus = state.stats.goldBonus;
  let qualityUpgradeChance = 0;
  for (const buff of state.deityBuffs) {
    const stat = String(buff.stat ?? "");
    const value = numberValue(buff.value, 1);
    if (stat === "war_god") { damageMultiplier *= 1.5; incomingDamageMultiplier *= .7; }
    if (stat === "decline_god") { damageMultiplier *= .7; incomingDamageMultiplier *= 1.5; }
    if (stat === "cd_mult") cooldownModifier += (1 - value) * 100;
    if (stat === "gold_mult") goldBonus += (value - 1) * 100;
    if (stat === "quality_up_chance") qualityUpgradeChance = Math.max(qualityUpgradeChance, value);
  }
  const player: BattlePlayerState = {
    name: character.name ?? "勇者",
    level: character.level,
    currentHp: Math.max(1, Math.min(state.maxHp, numberValue(state.hp, state.maxHp))),
    maxHp: state.maxHp,
    attack: state.stats.attack,
    defense: state.stats.defense,
    speedPoints: state.stats.speed,
    crit: state.stats.crit,
    critDamage: state.stats.critDamage,
    hit: state.stats.hit,
    dodge: state.stats.dodge,
    block: state.stats.block,
    skillDamage: state.stats.skillDamage,
    cooldownReduction: Math.max(-50, Math.min(50, state.stats.cooldownReduction + cooldownModifier)),
    lifesteal: state.stats.lifesteal,
    freeAttackPct: state.attributes.attack * .018,
    freeDefensePct: Math.min(.5, state.attributes.defense * .012),
    goldBonus,
    experienceBonus: state.stats.experienceBonus,
    skillSlots: state.skillSlots.map((skillId) => ({ skillId, priority: Math.max(1, Math.min(3, state.skillPriorities[String(skillId)] ?? 2)) })),
    battleDamageMultiplier: damageMultiplier,
    incomingDamageMultiplier,
    passives: [],
    setCounts: sets.setCounts,
    setAffixes: sets.setAffixes,
    battleGold: character.gold,
  };
  const talkChance = kind === "battle"
    ? (state.hibernateLaps > 0
      ? 1
      : (sets.setCounts["口才"] ?? 0) >= 3
        ? .25 + (sets.setAffixes.includes("【口才】魅力") ? .05 : 0) + (sets.setAffixes.includes("【口才】超级魅力") ? .05 : 0)
        : 0)
    : kind === "elite" && (sets.setCounts["口才"] ?? 0) >= 4
      ? .05 + (sets.setAffixes.includes("【口才】雄辩") ? .03 : 0) + (sets.setAffixes.includes("【口才】超级雄辩") ? .03 : 0)
      : 0;
  const talkSkip = talkChance > 0 && Math.random() < talkChance;
  // A speech/hibernate skip still uses the authoritative reward generator,
  // but runs with no enemies so the returned timeline is an instant victory.
  const battleEncounter = talkSkip
    ? { ...encounter, units: [], formation: { front: [], back: [] } }
    : encounter;
  const result = runBattle(player, battleEncounter);
  if (talkSkip) {
    result.talk_skip = true;
    result.log = ["口才套装说服敌人，直接胜利"];
  }
  const isChallenge = kind === "challenge";
  const won = result.outcome === BattleOutcome.VICTORY || (isChallenge && result.outcome === BattleOutcome.CHALLENGE_DONE);
  character.gold = Math.max(0, character.gold - result.luxury_gold_spent);
  const equipment: EquipmentItem[] = [];
  const messages: string[] = [];
  if (won) {
    character.gold = Math.min(9_000_000_000_000_000, character.gold + result.gold_gain);
    if (!isChallenge) {
      character.experience += result.exp_gain;
      messages.push(...levelUp(character));
      const elapsed = Math.max(result.elapsed, 3);
      if (result.gold_gain > 0) {
        const rate = result.gold_gain * 3_600 / elapsed;
        state.lastGoldPerHour = state.lastGoldPerHour > 0 ? state.lastGoldPerHour * .75 + rate * .25 : rate;
      }
      if (result.exp_gain > 0) {
        const rate = result.exp_gain * 3_600 / elapsed;
        state.lastExpPerHour = state.lastExpPerHour > 0 ? state.lastExpPerHour * .75 + rate * .25 : rate;
      }
    }
    for (const drop of result.drops) {
      let qualityFloor = Number(drop.quality_floor ?? (drop.kind === "boss" ? 3 : 0));
      if (Math.random() < qualityUpgradeChance) qualityFloor = Math.min(4, qualityFloor + 1);
      const generated = generateEquipment(character.level, state.bossTier, qualityFloor, 4, state.stats.luck);
      const received = receiveEquipment(state, generated);
      if (received.accepted) equipment.push(generated);
      else if (received.essence > 0) messages.push(`自动分解${generated.name}，获得${received.essence}分解精华`);
      else messages.push("装备背包已满且无可替换装备，掉落未能收入背包");
    }
    if (kind === "boss") {
      state.bossTier = Math.min(MAX_BOSS_INDEX, state.bossTier + 1);
      state.bossIndex = Math.min(MAX_BOSS_INDEX, state.bossTier + 1);
      expandMapAfterBoss(state, state.bossTier);
    }
  } else if (!isChallenge) {
    if (state.reviveCoins > 0) {
      state.reviveCoins -= 1;
      result.player_hp = state.maxHp;
      result.player_alive = true;
      result.revive_used = true;
      messages.push("战败，消耗1复活币重新站起");
    } else {
      const penalty = Math.floor(character.gold * .15);
      character.gold -= penalty;
      state.gridIndex = 0;
      state.reviveCoins = 3;
      result.player_hp = state.maxHp;
      result.player_alive = true;
      result.force_home = true;
      result.gold_penalty = penalty;
      messages.push(`战败，强制回家并损失${penalty}金币`);
    }
  }
  // Normal victories preserve the authoritative HP left by the battle.
  // Defeat handling below overwrites this with the revived/full HP value.
  state.hp = Math.max(0, Math.min(state.maxHp, result.player_hp));
  for (const name of ["skillBoost", "damagePenalty"]) {
    if ((state.buffs[name] ?? 0) > 0) state.buffs[name] = Math.max(0, (state.buffs[name] ?? 0) - 1);
  }
  return {
    kind: "battle",
    battleKind: kind,
    won,
    encounter,
    battle_result: result,
    events: result.events,
    enemy: encounter.units.map((unit) => unit.name),
    rewards: { gold: result.gold_gain, experience: result.exp_gain, equipment, messages },
    message: messages.at(-1) ?? (won ? (isChallenge ? `挑战完成，造成${result.damage_total}伤害` : "战斗胜利") : "战斗失败"),
  };
}

export function createInitialGameState(): GameState {
  const state = defaultGameState();
  recalculateStats(state, 1);
  return state;
}

export function applyGameCommand(
  original: GameState,
  characterInput: CharacterProgress,
  command: string,
  payload: Record<string, unknown>,
): GameCommandResult {
  const state: GameState = JSON.parse(JSON.stringify(original)) as GameState;
  const character = { ...characterInput };
  reconcileAttributePoints(state, character.level);
  recalculateStats(state, character.level);
  let event: Record<string, unknown>;
  let rollLotteryDraw: Record<string, unknown> | null = null;
  if (command === "roll") {
    const baseDice = Math.floor(Math.random() * 6) + 1;
    const dice = Math.max(1, Math.min(6, baseDice + state.nextRollModifier));
    state.nextRollModifier = 0;
    tickWeatherRoll(state);
    const previous = state.gridIndex;
    const next = (previous + dice) % state.mapTotalGrids;
    state.gridIndex = next;
    state.lastDiceRoll = dice;
    state.lastDiceSuit = Math.floor(Math.random() * 4);
    state.diceHistory = [...state.diceHistory.slice(-19), dice];
    state.pokerRecords = [...state.pokerRecords.slice(-19), { value: dice, suit: state.lastDiceSuit }];
    const poker = pokerReward(state, character);
    if (previous + dice >= state.mapTotalGrids) {
      state.completedLaps += 1;
      character.gold = Math.min(9_000_000_000_000_000, character.gold + 50);
      rollLotteryDraw = tickLapEffects(state, character);
      for (const buffName of Object.keys(state.buffs)) {
        if ((state.buffs[buffName] ?? 0) > 0 && !["skillBoost", "damagePenalty"].includes(buffName)) {
          state.buffs[buffName] = Math.max(0, (state.buffs[buffName] ?? 0) - 1);
        }
      }
    }
    const gridType = state.mapGrids[next] ?? 12;
    const eventName = GRID_NAMES[gridType] ?? "空地";
    if (gridType === 1 || gridType === 2 || gridType === 3 || gridType === 11) {
      const battleKind = gridType === 11 ? "boss" : gridType === 3 ? "challenge" : gridType === 2 ? "elite" : "battle";
      event = { ...originalBattle(state, character, battleKind), dice, from: previous, to: next, gridType, gridName: eventName, icon: GRID_ICONS[gridType], ...(rollLotteryDraw ? { lotteryDraw: rollLotteryDraw } : {}) };
    } else if (gridType === 4) {
      if (state.reviveCoins < 3) {
        state.reviveCoins += 1;
        event = { kind: "rest", dice, from: previous, to: next, gridType, gridName: eventName, message: "+1 复活币" };
      } else {
        const gold = Math.min(character.level, 100) * 5;
        character.gold += gold;
        event = { kind: "rest", dice, from: previous, to: next, gridType, gridName: eventName, gold, message: `+${gold} 金币（复活币已满）` };
      }
    } else if (gridType === 5) {
      const chestRoll = Math.random();
      if (chestRoll < .55) {
        const gold = Math.min(character.level, 100) * (Math.floor(Math.random() * 7) + 6);
        character.gold += gold;
        event = { kind: "chest", dice, from: previous, to: next, gridType, gridName: eventName, gold, message: `宝箱开出 +${gold} 金币` };
      } else if (chestRoll < .8 && state.equipmentBag.length < state.equipmentCapacity) {
        const equipment = generateEquipment(character.level, state.bossTier, 0, 4, state.stats.luck);
        const received = receiveEquipment(state, equipment);
        event = { kind: "chest", dice, from: previous, to: next, gridType, gridName: eventName, equipment: received.accepted ? equipment : null, message: received.accepted ? `宝箱获得：${equipment.name}` : received.essence > 0 ? `宝箱装备自动分解：+${received.essence}精华` : "装备背包已满" };
      } else if (chestRoll < .92) {
        addItem(state, 5, 1);
        event = { kind: "chest", dice, from: previous, to: next, gridType, gridName: eventName, itemId: 5, itemName: itemById(5)?.name, message: "宝箱开出天命卡×1" };
      } else {
        const gemId = Math.floor(Math.random() * 8) + 1;
        const gem = state.gemBag.find((entry) => entry.gemId === gemId);
        if (gem) gem.count += 1; else state.gemBag.push({ gemId, count: 1 });
        event = { kind: "chest", dice, from: previous, to: next, gridType, gridName: eventName, gemId, message: `宝箱开出宝石 #${gemId}` };
      }
    } else if (gridType === 6) {
      const equippedSlots = Object.entries(state.equipped).filter((entry) => entry[1] !== null).map((entry) => entry[0]);
      const slot = equippedSlots[Math.floor(Math.random() * equippedSlots.length)];
      if (!slot) event = { kind: "forge", dice, from: previous, to: next, gridType, gridName: eventName, message: "装备架空空如也" };
      else {
        const level = state.slotEnhance[slot] ?? 0;
        const cost = level * 500;
        if (level >= 200) event = { kind: "forge", dice, from: previous, to: next, gridType, gridName: eventName, message: `${slot}强化已达上限 +200` };
        else if (character.gold < cost) event = { kind: "forge", dice, from: previous, to: next, gridType, gridName: eventName, message: `金币不足（需要${cost}）` };
        else { character.gold -= cost; state.slotEnhance[slot] = level + 1; recalculateStats(state, character.level); event = { kind: "forge", dice, from: previous, to: next, gridType, gridName: eventName, slot, enhance: level + 1, cost, message: `${slot} +${level} → +${level + 1}（-${cost}金）` }; }
      }
    } else if (gridType === 7) {
      event = { kind: "fate", dice, from: previous, to: next, gridType, gridName: eventName, ...fateEvent(state, character) };
      if (event.teleport === true || event.teleportTreasure === true) {
        const targetType = event.teleportTreasure === true ? 5 : 10;
        const target = state.mapGrids.findIndex((entry, index) => index > state.gridIndex && entry === targetType);
        const wrappedTarget = target >= 0 ? target : state.mapGrids.findIndex((entry) => entry === targetType);
        if (wrappedTarget >= 0) {
          state.gridIndex = wrappedTarget;
          event.teleportTo = wrappedTarget;
        }
      }
    } else if (gridType === 8) {
      event = { dice, from: previous, to: next, gridType, gridName: eventName, ...deityEvent(state, character) };
    } else if (gridType === 9) {
      event = { dice, from: previous, to: next, gridType, gridName: eventName, ...synthesizeEquipment(state, character) };
    } else if (gridType === 10) {
      const jump = Math.floor(Math.random() * 4) + 2;
      const finalTo = (state.gridIndex + jump) % state.mapTotalGrids;
      state.gridIndex = finalTo;
      event = { kind: "lightning", dice, from: previous, to: next, finalTo, jump, gridType, gridName: eventName, message: `闪电跳跃 ${jump} 格！` };
    } else if (gridType === 14) {
      if (state.lotteryTicketNumbers.length >= 10) {
        event = { kind: "lottery", dice, from: previous, to: next, gridType, gridName: eventName, message: "彩票已满（最多10张）" };
      } else {
        const ticket = Math.floor(Math.random() * 1_000);
        state.lotteryTicketNumbers.push(ticket);
        state.lotteryTickets = state.lotteryTicketNumbers.length;
        event = { kind: "lottery", dice, from: previous, to: next, gridType, gridName: eventName, ticket, message: `获得彩票 ${ticket.toString().padStart(3, "0")}` };
      }
    } else if (gridType === 0) {
      state.hp = state.maxHp;
      event = { kind: "home", dice, from: previous, to: next, gridType, gridName: eventName, message: "回到勇者之家，状态已整备" };
    } else {
      const gold = Math.max(1, Math.floor(Math.min(character.level, 100) * (.3 + Math.random() * .5)));
      character.gold += gold;
      event = { kind: "move", dice, from: previous, to: next, gridType, gridName: eventName, gold, message: `+${gold} 金币` };
    }
    if (poker) event.poker = poker;
  } else if (command === "item_use") {
    const itemId = numberValue(payload.item_id, -1);
    const item = itemById(itemId);
    if (!item || item.type !== "consumable") throw new Error("物品不可使用或不存在");
    const effect = item.stats;
    if (Number(effect.socketTool ?? 0) > 0) {
      const equipmentId = typeof payload.equipment_id === "string" ? payload.equipment_id : "";
      const equipment = state.equipmentBag.find((entry) => entry.id === equipmentId);
      if (!equipment || equipment.quality < 3 || (equipment.gemSlots ?? 0) >= 3) throw new Error("该装备无法打孔");
      if (!removeItem(state, itemId, 1)) throw new Error("物品不足或不存在");
      equipment.gemSlots = (equipment.gemSlots ?? 0) + 1;
      event = { kind: "equipment", action: "socket_add", equipmentId, gemSlots: equipment.gemSlots, message: "打孔成功" };
    } else if (Number(effect.fate ?? 0) > 0) {
      if (!removeItem(state, itemId, 1)) throw new Error("物品不足或不存在");
      const fate = fateEvent(state, character);
      if (fate.teleport === true || fate.teleportTreasure === true) {
        const targetType = fate.teleportTreasure === true ? 5 : 10;
        const target = state.mapGrids.findIndex((entry, index) => index > state.gridIndex && entry === targetType);
        const wrappedTarget = target >= 0 ? target : state.mapGrids.findIndex((entry) => entry === targetType);
        if (wrappedTarget >= 0) {
          state.gridIndex = wrappedTarget;
          fate.teleportTo = wrappedTarget;
        }
      }
      event = { kind: "item_use", itemId, itemName: item.name, fate, message: String(fate.message ?? `使用了${item.name}`) };
    } else {
      if (!removeItem(state, itemId, 1)) throw new Error("物品不足或不存在");
      if (effect.heal) state.hp = Math.min(state.maxHp, state.hp + effect.heal);
      if (effect.experience) character.experience += effect.experience;
      if (effect.gold) character.gold += effect.gold;
      const messages = levelUp(character);
      event = { kind: "item_use", itemId, itemName: item.name, messages, message: `使用了${item.name}` };
    }
  } else if (command === "equipment_equip" || command === "equipment_unequip") {
    const equipmentId = typeof payload.equipment_id === "string" ? payload.equipment_id : "";
    const item = state.equipmentBag.find((entry) => entry.id === equipmentId);
    if (command === "equipment_equip") {
      if (!item) throw new Error("装备不存在");
      if (!(item.slot in state.equipped)) throw new Error("装备槽不存在");
      if (Object.entries(state.equipped).some(([slot, id]) => slot !== item.slot && id === item.id)) throw new Error("装备已穿戴");
      state.equipped[item.slot] = item.id;
      event = { kind: "equipment", action: "equip", item };
    } else {
      const slot = typeof payload.slot === "string" ? payload.slot : item?.slot;
      if (!slot || !(slot in state.equipped)) throw new Error("装备槽不存在");
      state.equipped[slot] = null;
      event = { kind: "equipment", action: "unequip", slot };
    }
    recalculateStats(state, character.level);
  } else if (command === "equipment_dismantle") {
    const equipmentId = typeof payload.equipment_id === "string" ? payload.equipment_id : "";
    const item = state.equipmentBag.find((entry) => entry.id === equipmentId);
    if (!item || item.locked || Object.values(state.equipped).includes(equipmentId)) throw new Error("装备无法分解");
    state.equipmentBag = state.equipmentBag.filter((entry) => entry.id !== equipmentId);
    returnEquipmentGems(state, item);
    const essence = ESSENCE_BY_QUALITY[Math.max(0, Math.min(4, item.quality))] ?? 1;
    state.dismantleEssence += essence;
    event = { kind: "equipment", action: "dismantle", equipmentId, essence };
  } else if (command === "equipment_dismantle_many") {
    const ids = Array.isArray(payload.equipment_ids) ? payload.equipment_ids.filter((id): id is string => typeof id === "string") : [];
    if (ids.length < 1 || ids.length > 100 || new Set(ids).size !== ids.length) throw new Error("分解数量不正确");
    let essence = 0;
    const removed: string[] = [];
    for (const id of ids) {
      const item = state.equipmentBag.find((entry) => entry.id === id);
      if (!item || item.locked || Object.values(state.equipped).includes(id)) continue;
      essence += ESSENCE_BY_QUALITY[Math.max(0, Math.min(4, item.quality))] ?? 1;
      returnEquipmentGems(state, item);
      removed.push(id);
    }
    if (removed.length === 0) throw new Error("没有可分解的装备");
    state.equipmentBag = state.equipmentBag.filter((entry) => !removed.includes(entry.id));
    state.dismantleEssence += essence;
    event = { kind: "equipment", action: "dismantle_many", equipmentIds: removed, essence };
  } else if (command === "equipment_lock") {
    const equipmentId = typeof payload.equipment_id === "string" ? payload.equipment_id : "";
    const item = state.equipmentBag.find((entry) => entry.id === equipmentId);
    if (!item) throw new Error("装备不存在");
    item.locked = typeof payload.locked === "boolean" ? payload.locked : !item.locked;
    event = { kind: "equipment", action: "lock", equipmentId, locked: item.locked };
  } else if (command === "equipment_enhance") {
    const equipmentId = typeof payload.equipment_id === "string" ? payload.equipment_id : "";
    const legacyItem = state.equipmentBag.find((entry) => entry.id === equipmentId);
    const rawSlots = Array.isArray(payload.slots) ? payload.slots : legacyItem ? [legacyItem.slot] : [];
    const slots = rawSlots.filter((slot): slot is string => typeof slot === "string" && EQUIPMENT_SLOTS.some((entry) => entry.key === slot));
    const levels = numberValue(payload.levels, 1);
    if (slots.length < 1 || slots.length !== rawSlots.length || new Set(slots).size !== slots.length) throw new Error("装备槽位不存在");
    if (!Number.isInteger(levels) || levels < 1 || levels > 5) throw new Error("强化次数需为1至5");
    let price = 0;
    let appliedLevels = 0;
    for (const slot of slots) {
      const current = state.slotEnhance[slot] ?? 0;
      const actual = Math.min(levels, 200 - current);
      for (let offset = 0; offset < actual; offset += 1) price += (current + offset) * 500;
      appliedLevels += actual;
    }
    if (appliedLevels < 1) throw new Error("装备槽位已达到强化上限");
    if (character.gold < price) throw new Error("金币不足");
    character.gold -= price;
    for (const slot of slots) state.slotEnhance[slot] = Math.min(200, (state.slotEnhance[slot] ?? 0) + levels);
    recalculateStats(state, character.level);
    event = { kind: "equipment", action: "enhance", slots, levels, appliedLevels, price, slotEnhance: structuredClone(state.slotEnhance) };
  } else if (command === "equipment_gem_socket" || command === "equipment_gem_unsocket") {
    const equipmentId = typeof payload.equipment_id === "string" ? payload.equipment_id : "";
    const equipment = state.equipmentBag.find((entry) => entry.id === equipmentId);
    const socketIndex = numberValue(payload.socket_index, -1);
    if (!equipment || !Number.isInteger(socketIndex) || socketIndex < 0 || socketIndex >= (equipment.gemSlots ?? 0)) throw new Error("装备孔位不存在");
    const gems = [...(equipment.gems ?? [])];
    while (gems.length < (equipment.gemSlots ?? 0)) gems.push(0);
    const old = gems[socketIndex] ?? 0;
    if (command === "equipment_gem_unsocket") {
      if (old !== 0) { const parsed = gemParts(old); addGem(state, parsed.id, parsed.level, 1, parsed.bound); }
      gems[socketIndex] = 0;
      event = { kind: "equipment", action: "gem_unsocket", equipmentId, socketIndex };
    } else {
      const gemId = numberValue(payload.gem_id, -1);
      const level = numberValue(payload.level, 1);
      const consumed = (!Number.isInteger(gemId) || gemId < 1 || gemId > 8 || !Number.isInteger(level) || level < 1 || level > 10)
        ? { ok: false, bound: false }
        : takeGems(state, gemId, level, 1);
      if (!consumed.ok) throw new Error("宝石数量不足或等级不正确");
      if (old !== 0) { const parsed = gemParts(old); addGem(state, parsed.id, parsed.level, 1, parsed.bound); }
      gems[socketIndex] = { id: gemId, level, ...(consumed.bound ? { bound: true } : {}) };
      event = { kind: "equipment", action: "gem_socket", equipmentId, socketIndex, gemId, level };
    }
    equipment.gems = gems;
    recalculateStats(state, character.level);
  } else if (command === "gem_synthesize") {
    const gemId = numberValue(payload.gem_id, -1);
    const level = numberValue(payload.level, 1);
    if (!Number.isInteger(gemId) || gemId < 1 || gemId > 8 || !Number.isInteger(level) || level < 1 || level >= 10) throw new Error("宝石等级不正确");
    const cost = (level + 1) * 500;
    if (character.gold < cost) throw new Error("金币不足");
    const consumed = takeGems(state, gemId, level, 3);
    if (!consumed.ok) throw new Error("需要3颗同等级宝石");
    character.gold -= cost;
    addGem(state, gemId, level + 1, 1, consumed.bound);
    event = { kind: "gem", action: "synthesize", gemId, fromLevel: level, level: level + 1, cost };
  } else if (command === "equipment_reroll") {
    const equipmentId = typeof payload.equipment_id === "string" ? payload.equipment_id : "";
    const item = state.equipmentBag.find((entry) => entry.id === equipmentId);
    const locked = Array.isArray(payload.locked_indices) ? payload.locked_indices.filter((value): value is number => typeof value === "number" && Number.isInteger(value)) : [];
    if (!item || item.quality < 3 || item.quality > 4 || locked.length !== (Array.isArray(payload.locked_indices) ? payload.locked_indices.length : 0) || new Set(locked).size !== locked.length || locked.length > 2) throw new Error("装备无法重铸");
    const costs = REROLL_COSTS[Math.min(2, locked.length) as 0 | 1 | 2];
    const goldCost = item.quality === 4 ? costs.legendaryGold : costs.epicGold;
    if (state.dismantleEssence < costs.essence) throw new Error("分解精华不足");
    if (character.gold < goldCost) throw new Error("金币不足");
    rerollAffixes(item, locked);
    state.dismantleEssence -= costs.essence;
    character.gold -= goldCost;
    event = { kind: "equipment", action: "reroll", equipmentId, lockedIndices: locked, essence: costs.essence, gold: goldCost, item };
  } else if (command === "auto_dismantle") {
    const enabled = typeof payload.enabled === "boolean" ? payload.enabled : state.autoDismantleEnabled;
    const rules = payload.rules && typeof payload.rules === "object" && !Array.isArray(payload.rules) ? payload.rules as Record<string, unknown> : state.autoDismantleRules;
    if (JSON.stringify(rules).length > 2_000) throw new Error("自动分解规则过长");
    const validValues: Record<string, unknown[]> = {
      qualities: [0, 1, 2, 3, 4], slots: [1, 2, 3, 4, 5, 6, 7, 8],
      affix_types: ["attack", "defense", "universal", "set"],
      initial_sockets: [0, 1, 2, 3], suits: ["none", ...SET_NAMES],
    };
    for (const [key, allowed] of Object.entries(validValues)) {
      if (rules[key] !== undefined && (!Array.isArray(rules[key]) || (rules[key] as unknown[]).some((value) => !allowed.includes(value)))) throw new Error("自动分解规则不正确");
    }
    if (!Number.isInteger(rules.affix_min) || !Number.isInteger(rules.affix_max) || Number(rules.affix_min) < 0 || Number(rules.affix_max) > 8 || Number(rules.affix_min) > Number(rules.affix_max)) throw new Error("词缀数量范围不正确");
    state.autoDismantleEnabled = enabled;
    state.autoDismantleRules = structuredClone(rules);
    event = { kind: "equipment", action: "auto_dismantle", enabled, rules: state.autoDismantleRules };
  } else if (command === "inventory_expand" || command === "equipment_expand") {
    const isEquipment = command === "equipment_expand";
    const capacityKey = isEquipment ? "equipmentCapacity" : "inventoryCapacity";
    const countKey = isEquipment ? "equipmentExpansionCount" : "inventoryExpansionCount";
    if (state[countKey] >= 18 || state[capacityKey] >= 1_000) throw new Error("背包已达到扩容上限");
    const price = expansionCost(state[countKey]);
    if (character.gold < price) throw new Error("金币不足");
    character.gold -= price;
    state[capacityKey] += 50;
    state[countKey] += 1;
    event = { kind: "expand", target: isEquipment ? "equipment" : "inventory", capacity: state[capacityKey], price };
  } else if (command === "skill_unlock") {
    const skillId = numberValue(payload.skill_id, -1);
    const skill = skillById(skillId);
    if (!skill || state.skills.includes(skillId)) throw new Error("技能不存在或已解锁");
    if (character.gold < skill.price) throw new Error("金币不足");
    character.gold -= skill.price;
    state.skills.push(skillId);
    event = { kind: "skill", action: "unlock", skill };
  } else if (command === "skill_slot") {
    const maxSlots = character.level >= 45 ? 6 : character.level >= 35 ? 5 : character.level >= 15 ? 4 : character.level >= 5 ? 3 : 2;
    const slots = Array.isArray(payload.slots) ? payload.slots : [];
    const parsed: number[] = [];
    const priorities: Record<string, number> = {};
    for (const raw of slots.slice(0, maxSlots)) {
      const skillId = typeof raw === "number" ? raw : raw && typeof raw === "object" ? numberValue((raw as Record<string, unknown>).skill_id, -1) : -1;
      if (!state.skills.includes(skillId) || parsed.includes(skillId)) continue;
      parsed.push(skillId);
      const priority = raw && typeof raw === "object" ? numberValue((raw as Record<string, unknown>).priority, 2) : state.skillPriorities[String(skillId)] ?? 2;
      priorities[String(skillId)] = Math.max(1, Math.min(3, Math.floor(priority)));
    }
    state.skillSlots = parsed;
    state.skillPriorities = priorities;
    event = { kind: "skill", action: "slot", slots: state.skillSlots, priorities };
  } else if (command === "skill_cast") {
    const skillId = numberValue(payload.skill_id, -1);
    const skill = skillById(skillId);
    if (!skill || !state.skills.includes(skillId)) throw new Error("技能尚未解锁");
    const healing = skill.healPct ? Math.max(1, Math.floor(state.stats.attack * skill.healPct / 100)) : 0;
    if (healing > 0) state.hp = Math.min(state.maxHp, state.hp + healing);
    event = { kind: "skill", action: "cast", skillId, skillName: skill.name, healing, message: healing > 0 ? `释放${skill.name}，恢复${healing}生命` : `释放了${skill.name}` };
  } else if (command === "attribute_allocate") {
    const aliases: Record<string, keyof FreeAttributes> = {
      atk: "attack",
      attack: "attack",
      def: "defense",
      defense: "defense",
      spd: "speed",
      speed: "speed",
      luk: "luck",
      luck: "luck",
    };
    const key = typeof payload.attribute === "string" ? aliases[payload.attribute] : undefined;
    if (!key) throw new Error("属性不存在");
    if (state.freeAttributePoints < 1) throw new Error("没有可用属性点");
    state.attributes[key] += 1;
    state.freeAttributePoints -= 1;
    event = {
      kind: "attribute",
      action: "allocate",
      attribute: key,
      freeAttributePoints: state.freeAttributePoints,
      attributes: state.attributes,
    };
  } else if (command === "attribute_reset") {
    const allocated = Object.values(state.attributes).reduce((sum, value) => sum + value, 0);
    if (allocated < 1) throw new Error("没有已分配的属性点需要重置");
    const price = character.level * 200;
    if (character.gold < price) throw new Error("金币不足");
    character.gold -= price;
    state.attributes = { attack: 0, defense: 0, speed: 0, luck: 0 };
    state.freeAttributePoints += allocated;
    event = {
      kind: "attribute",
      action: "reset",
      returnedPoints: allocated,
      price,
      freeAttributePoints: state.freeAttributePoints,
      attributes: state.attributes,
    };
  } else {
    throw new Error("不支持的游戏操作");
  }
  if (command === "roll" && rollLotteryDraw) event.lotteryDraw = rollLotteryDraw;
  reconcileAttributePoints(state, character.level);
  recalculateStats(state, character.level);
  return { state, character, event };
}
