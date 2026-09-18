import { EQUIPMENT_SLOTS, MAP_BASE, itemById } from "./game-catalog.js";

export interface InventoryStack {
  itemId: number;
  count: number;
  bound?: boolean;
}

export interface EquipmentItem {
  id: string;
  slot: string;
  name: string;
  quality: number;
  enhance: number;
  mainStat: string;
  mainValue: number;
  locked: boolean;
  bound: boolean;
  baseName?: string;
  icon?: string;
  iconPath?: string;
  slotTypeId?: number;
  affixes?: Array<{ name: string; type: string; value: number; display: string }>;
  gems?: Array<number | { id: number; level?: number; bound?: boolean }>;
  gemSlots?: number;
  initialGemSlots?: number;
  acquiredAt?: number;
  suitName?: string;
  extraSuitName?: string;
  setAffixes?: Array<{ name: string; type: string; description?: string }>;
}

export interface GameStats {
  attack: number;
  defense: number;
  maxHp: number;
  speed: number;
  crit: number;
  critDamage: number;
  hit: number;
  dodge: number;
  block: number;
  skillDamage: number;
  cooldownReduction: number;
  lifesteal: number;
  luck: number;
  goldBonus: number;
  experienceBonus: number;
}

export interface FreeAttributes {
  attack: number;
  defense: number;
  speed: number;
  luck: number;
}

export interface GameState {
  version: 1;
  hp: number;
  maxHp: number;
  reviveCoins: number;
  stats: GameStats;
  freeAttributePoints: number;
  attributes: FreeAttributes;
  gridIndex: number;
  mapTotalGrids: number;
  mapGrids: number[];
  lastDiceRoll: number | null;
  lastDiceSuit: number | null;
  diceHistory: number[];
  pokerRecords: Array<{ value: number; suit: number }>;
  inventory: InventoryStack[];
  inventoryCapacity: number;
  inventoryExpansionCount: number;
  equipmentBag: EquipmentItem[];
  equipmentCapacity: number;
  equipmentExpansionCount: number;
  equipped: Record<string, string | null>;
  slotEnhance: Record<string, number>;
  gemBag: Array<{ gemId: number; level?: number; count: number; bound?: boolean }>;
  lotteryTickets: number;
  lotteryTicketNumbers: number[];
  lotteryLastDrawLap: number;
  skills: number[];
  skillSlots: number[];
  skillPriorities: Record<string, number>;
  buffs: Record<string, number>;
  bossTier: number;
  bossIndex: number;
  weather: string;
  weatherRollCount: number;
  weatherRollTarget: number;
  weatherSunnyBuffer: number;
  nextRollModifier: number;
  hibernateLaps: number;
  deityBuffs: Array<Record<string, unknown>>;
  dismantleEssence: number;
  autoDismantleEnabled: boolean;
  autoDismantleRules: Record<string, unknown>;
  lastGoldPerHour: number;
  lastExpPerHour: number;
  lastOnline: number;
  completedLaps: number;
  activeBattle: null | Record<string, unknown>;
}

export function defaultGameState(): GameState {
  const equipped: Record<string, string | null> = {};
  const slotEnhance: Record<string, number> = {};
  for (const slot of EQUIPMENT_SLOTS) {
    equipped[slot.key] = null;
    slotEnhance[slot.key] = 0;
  }
  return {
    version: 1,
    hp: 500,
    maxHp: 500,
    reviveCoins: 3,
    // 与Godot新档一致：等级1白值，不预发装备或消耗品。
    stats: { attack: 25, defense: 15, maxHp: 500, speed: 0, crit: 0, critDamage: 150, hit: 0, dodge: 0, block: 0, skillDamage: 0, cooldownReduction: 0, lifesteal: 0, luck: 0, goldBonus: 0, experienceBonus: 0 },
    freeAttributePoints: 0,
    attributes: { attack: 0, defense: 0, speed: 0, luck: 0 },
    gridIndex: 0,
    mapTotalGrids: MAP_BASE.length,
    mapGrids: [...MAP_BASE],
    lastDiceRoll: null,
    lastDiceSuit: null,
    diceHistory: [],
    pokerRecords: [],
    inventory: [],
    inventoryCapacity: 100,
    inventoryExpansionCount: 0,
    equipmentBag: [],
    equipmentCapacity: 100,
    equipmentExpansionCount: 0,
    equipped,
    slotEnhance,
    gemBag: [],
    lotteryTickets: 0,
    lotteryTicketNumbers: [],
    lotteryLastDrawLap: 0,
    skills: [1, 22],
    skillSlots: [1, 22],
    skillPriorities: { "1": 2, "22": 2 },
    buffs: {},
    bossTier: 0,
    bossIndex: 1,
    weather: "sunny",
    weatherRollCount: 0,
    weatherRollTarget: 8,
    weatherSunnyBuffer: 10,
    nextRollModifier: 0,
    hibernateLaps: 0,
    deityBuffs: [],
    dismantleEssence: 0,
    autoDismantleEnabled: false,
    autoDismantleRules: {},
    lastGoldPerHour: 0,
    lastExpPerHour: 0,
    lastOnline: Date.now(),
    completedLaps: 0,
    activeBattle: null,
  };
}

export function parseGameState(value: string | null | undefined): GameState {
  if (!value) return defaultGameState();
  try {
    const parsed = JSON.parse(value) as Partial<GameState>;
    const fallback = defaultGameState();
    if (parsed.version !== 1 || !Array.isArray(parsed.inventory) || !Array.isArray(parsed.equipmentBag)) return fallback;
    const state = {
      ...fallback,
      ...parsed,
      stats: { ...fallback.stats, ...(parsed.stats ?? {}) },
      attributes: { ...fallback.attributes, ...(parsed.attributes ?? {}) },
      equipped: { ...fallback.equipped, ...(parsed.equipped ?? {}) },
      slotEnhance: { ...fallback.slotEnhance, ...(parsed.slotEnhance ?? {}) },
      mapGrids: Array.isArray(parsed.mapGrids) && parsed.mapGrids.length > 0 ? parsed.mapGrids : fallback.mapGrids,
      pokerRecords: Array.isArray(parsed.pokerRecords) ? parsed.pokerRecords : fallback.pokerRecords,
      lotteryTicketNumbers: Array.isArray(parsed.lotteryTicketNumbers) ? parsed.lotteryTicketNumbers : fallback.lotteryTicketNumbers,
      deityBuffs: Array.isArray(parsed.deityBuffs) ? parsed.deityBuffs : fallback.deityBuffs,
      autoDismantleRules: parsed.autoDismantleRules && typeof parsed.autoDismantleRules === "object" && !Array.isArray(parsed.autoDismantleRules)
        ? parsed.autoDismantleRules
        : fallback.autoDismantleRules,
      skillPriorities: parsed.skillPriorities && typeof parsed.skillPriorities === "object" && !Array.isArray(parsed.skillPriorities)
        ? parsed.skillPriorities
        : fallback.skillPriorities,
    } as GameState;
    state.mapTotalGrids = Math.max(1, Math.min(128, Math.floor(Number(state.mapTotalGrids) || fallback.mapTotalGrids)));
    state.mapGrids = state.mapGrids.map((entry) => Number.isInteger(entry) ? entry : 1).slice(0, state.mapTotalGrids);
    while (state.mapGrids.length < state.mapTotalGrids) state.mapGrids.push(1);
    state.bossTier = Math.max(0, Math.min(200, Math.floor(Number(state.bossTier) || 0)));
    state.bossIndex = Math.max(1, Math.min(200, Math.floor(Number(state.bossIndex) || state.bossTier + 1)));
    return state;
  } catch {
    return defaultGameState();
  }
}

function nonNegativeInteger(value: unknown): number {
  return typeof value === "number" && Number.isSafeInteger(value) && value >= 0 ? value : 0;
}

export function earnedAttributePoints(level: number): number {
  const safeLevel = Math.max(1, Math.min(100, Math.floor(level)));
  return (safeLevel - 1) * 2;
}

export function reconcileAttributePoints(state: GameState, level: number): boolean {
  const previous = JSON.stringify({ free: state.freeAttributePoints, attributes: state.attributes });
  const normalized: FreeAttributes = {
    attack: nonNegativeInteger(state.attributes?.attack),
    defense: nonNegativeInteger(state.attributes?.defense),
    speed: nonNegativeInteger(state.attributes?.speed),
    luck: nonNegativeInteger(state.attributes?.luck),
  };
  const earned = earnedAttributePoints(level);
  const allocated = Object.values(normalized).reduce((sum, value) => sum + value, 0);
  state.attributes = allocated <= earned
    ? normalized
    : { attack: 0, defense: 0, speed: 0, luck: 0 };
  const validAllocated = Object.values(state.attributes).reduce((sum, value) => sum + value, 0);
  state.freeAttributePoints = earned - validAllocated;
  return previous !== JSON.stringify({ free: state.freeAttributePoints, attributes: state.attributes });
}

export function serializeGameState(state: GameState): string {
  return JSON.stringify(state);
}

export function inventoryCount(state: GameState): number {
  return state.inventory.length;
}

export function addItem(state: GameState, itemId: number, count: number, bound = false): boolean {
  if (!Number.isInteger(itemId) || !Number.isInteger(count) || count < 1) return false;
  const stackMax = itemById(itemId)?.stackMax ?? 1;
  const room = state.inventory.filter((stack) => stack.itemId === itemId && Boolean(stack.bound) === bound).reduce((sum, stack) => sum + Math.max(0, stackMax - stack.count), 0)
    + Math.max(0, state.inventoryCapacity - state.inventory.length) * stackMax;
  if (room < count) return false;
  let remaining = count;
  for (const stack of state.inventory) {
    if (stack.itemId !== itemId || Boolean(stack.bound) !== bound || stack.count >= stackMax) continue;
    const taken = Math.min(remaining, stackMax - stack.count);
    stack.count += taken;
    remaining -= taken;
    if (remaining === 0) return true;
  }
  while (remaining > 0) {
    const taken = Math.min(remaining, stackMax);
    state.inventory.push({ itemId, count: taken, ...(bound ? { bound: true } : {}) });
    remaining -= taken;
  }
  return true;
}

export function removeItem(state: GameState, itemId: number, count: number): boolean {
  if (state.inventory.filter((entry) => entry.itemId === itemId).reduce((sum, entry) => sum + entry.count, 0) < count) return false;
  let remaining = count;
  for (const stack of state.inventory) {
    if (stack.itemId !== itemId || remaining === 0) continue;
    const taken = Math.min(remaining, stack.count);
    stack.count -= taken;
    remaining -= taken;
  }
  state.inventory = state.inventory.filter((entry) => entry.count > 0);
  return true;
}

export function removeTradableItem(state: GameState, itemId: number, count: number): boolean {
  if (state.inventory.filter((entry) => entry.itemId === itemId && !entry.bound).reduce((sum, entry) => sum + entry.count, 0) < count) return false;
  let remaining = count;
  for (const stack of state.inventory) {
    if (stack.itemId !== itemId || stack.bound || remaining === 0) continue;
    const taken = Math.min(remaining, stack.count);
    stack.count -= taken;
    remaining -= taken;
  }
  state.inventory = state.inventory.filter((entry) => entry.count > 0);
  return true;
}

export function recalculateStats(state: GameState, level = 1): void {
  const safeLevel = Math.max(1, Math.min(100, Math.floor(level)));
  const rawAttack = 25 + (safeLevel - 1) * 2;
  const rawDefense = 15 + (safeLevel - 1);
  const rawMaxHp = 500 + (safeLevel - 1) * 80;
  const base = {
    attack: rawAttack,
    defense: rawDefense,
    maxHp: rawMaxHp,
    // Free speed points and equipment speed share the same 50% cooldown cap
    // in the battle engine, so keep the total speed in the server snapshot.
    speed: state.attributes.speed,
    crit: 0,
    critDamage: 150,
    hit: 0,
    dodge: 0,
    block: 0,
    skillDamage: 0,
    cooldownReduction: 0,
    lifesteal: 0,
    luck: state.attributes.luck,
    goldBonus: 0,
    experienceBonus: 0,
  };
  for (const itemId of Object.values(state.equipped)) {
    if (!itemId) continue;
    const item = state.equipmentBag.find((entry) => entry.id === itemId);
    if (!item) continue;
    const value = Math.round(item.mainValue * (1 + (state.slotEnhance[item.slot] ?? 0) * .03));
    if (item.mainStat === "攻击力") base.attack += value;
    if (item.mainStat === "防御力") base.defense += value;
    if (item.mainStat === "生命值") base.maxHp += value;
    if (item.mainStat === "速度") base.speed += value;
    if (item.mainStat === "暴击率") base.crit += value;
    if (item.mainStat === "闪避率") base.dodge += value;
    if (item.mainStat === "格挡率") base.block += value;
    if (item.mainStat === "技能伤害") base.skillDamage += value;
    for (const affix of item.affixes ?? []) {
      if (affix.name === "攻击%") base.attack += Math.floor(rawAttack * affix.value / 100);
      if (affix.name === "攻击(数值)") base.attack += Math.floor(affix.value);
      if (affix.name === "防御%") base.defense += Math.floor(rawDefense * affix.value / 100);
      if (affix.name === "防御(数值)") base.defense += Math.floor(affix.value);
      if (affix.name === "生命%") base.maxHp += Math.floor(rawMaxHp * affix.value / 100);
      if (affix.name === "速度") base.speed += affix.value;
      if (affix.name === "幸运") base.luck += affix.value;
      if (affix.name === "暴击率") base.crit += affix.value;
      if (affix.name === "暴击伤害") base.critDamage += affix.value;
      if (affix.name === "技能伤害") base.skillDamage += affix.value;
      if (affix.name === "命中") base.hit += affix.value;
      if (affix.name === "闪避率") base.dodge += affix.value;
      if (affix.name === "格挡率") base.block += affix.value;
      if (affix.name === "冷却缩减") base.cooldownReduction += affix.value;
      if (affix.name === "吸血") base.lifesteal += affix.value;
      if (affix.name === "金币加成") base.goldBonus += affix.value;
      if (affix.name === "经验加成") base.experienceBonus += affix.value;
    }
    for (const rawGem of item.gems ?? []) {
      const gemId = typeof rawGem === "number" ? rawGem : rawGem.id;
      const gemLevel = typeof rawGem === "number" ? 1 : Math.max(1, Math.floor(rawGem.level ?? 1));
      if (gemId === 1) base.attack += 10 * gemLevel;
      if (gemId === 2) base.defense += 10 * gemLevel;
      if (gemId === 3) base.maxHp += 50 * gemLevel;
      if (gemId === 4) base.crit += 0.5 * gemLevel;
      if (gemId === 5) base.skillDamage += 0.5 * gemLevel;
      if (gemId === 6) base.hit += 0.5 * gemLevel;
      if (gemId === 7) base.critDamage += 2 * gemLevel;
      if (gemId === 8) base.block += 0.5 * gemLevel;
    }
  }

  // Set bonuses are derived from equipped server items. They must be applied
  // here, rather than only in the client UI, so battle, drops, and every
  // subsequent command use the same authoritative values.
  const setCounts: Record<string, number> = {};
  const setAffixes = new Set<string>();
  for (const itemId of Object.values(state.equipped)) {
    if (!itemId) continue;
    const item = state.equipmentBag.find((entry) => entry.id === itemId);
    if (!item) continue;
    for (const setName of [item.suitName, item.extraSuitName]) {
      if (setName) setCounts[setName] = (setCounts[setName] ?? 0) + 1;
    }
    for (const affix of item.setAffixes ?? []) {
      if (affix.name) setAffixes.add(affix.name);
    }
  }
  if (setAffixes.has("【龙鳞】坚韧")) base.block += 3;
  if (setAffixes.has("【疾风】疾行")) base.speed += 5;
  if (setAffixes.has("【铁壁】铁甲")) base.block += 3;
  if (setAffixes.has("【自然】生根")) base.lifesteal += 2;
  if (setAffixes.has("【引力】吸引")) base.goldBonus += 10;
  if (setAffixes.has("【引力】万有")) base.luck += 5;
  if (setAffixes.has("【幻影】灵动")) base.dodge += 3;
  if ((setCounts["龙鳞"] ?? 0) >= 2) base.defense += Math.floor(base.defense * .15);
  if ((setCounts["烈焰"] ?? 0) >= 2) base.attack += Math.floor(base.attack * .10);
  if ((setCounts["冰霜"] ?? 0) >= 2) base.speed += 10;
  if ((setCounts["雷霆"] ?? 0) >= 2) base.crit += 8;
  if ((setCounts["疾风"] ?? 0) >= 2) base.speed += 20;
  if ((setCounts["铁壁"] ?? 0) >= 2) base.block += 8;
  if ((setCounts["暗影"] ?? 0) >= 2) base.critDamage += 25;
  if ((setCounts["自然"] ?? 0) >= 2) base.lifesteal += 3;
  if ((setCounts["引力"] ?? 0) >= 2) base.goldBonus += 30;
  if ((setCounts["引力"] ?? 0) >= 3) base.luck += 15;
  if ((setCounts["星辰"] ?? 0) >= 2) base.cooldownReduction += 10;
  if ((setCounts["幻影"] ?? 0) >= 2) base.dodge += 8;
  if ((setCounts["口才"] ?? 0) >= 2) base.luck += 10;
  if ((setCounts["奢侈"] ?? 0) >= 2) base.goldBonus -= 50;
  state.stats = base;
  state.maxHp = base.maxHp;
  state.hp = Math.min(state.hp, state.maxHp);
}
