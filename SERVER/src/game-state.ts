import { EQUIPMENT_SLOTS, MAP_BASE, itemById } from "./game-catalog.js";

export interface InventoryStack {
  itemId: number;
  count: number;
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
}

export interface GameStats {
  attack: number;
  defense: number;
  maxHp: number;
  speed: number;
  crit: number;
  skillDamage: number;
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
  inventory: InventoryStack[];
  inventoryCapacity: number;
  inventoryExpansionCount: number;
  equipmentBag: EquipmentItem[];
  equipmentCapacity: number;
  equipmentExpansionCount: number;
  equipped: Record<string, string | null>;
  slotEnhance: Record<string, number>;
  gemBag: Array<{ gemId: number; count: number }>;
  lotteryTickets: number;
  skills: number[];
  skillSlots: number[];
  buffs: Record<string, number>;
  bossTier: number;
  bossIndex: number;
  weather: string;
  completedLaps: number;
  activeBattle: null;
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
    stats: { attack: 25, defense: 15, maxHp: 500, speed: 0, crit: 0, skillDamage: 0 },
    freeAttributePoints: 0,
    attributes: { attack: 0, defense: 0, speed: 0, luck: 0 },
    gridIndex: 0,
    mapTotalGrids: MAP_BASE.length,
    mapGrids: [...MAP_BASE],
    lastDiceRoll: null,
    lastDiceSuit: null,
    diceHistory: [],
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
    skills: [1, 22],
    skillSlots: [1, 22],
    buffs: {},
    bossTier: 1,
    bossIndex: 0,
    weather: "晴朗",
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
    return {
      ...fallback,
      ...parsed,
      stats: { ...fallback.stats, ...(parsed.stats ?? {}) },
      attributes: { ...fallback.attributes, ...(parsed.attributes ?? {}) },
      equipped: { ...fallback.equipped, ...(parsed.equipped ?? {}) },
      slotEnhance: { ...fallback.slotEnhance, ...(parsed.slotEnhance ?? {}) },
      mapGrids: Array.isArray(parsed.mapGrids) && parsed.mapGrids.length > 0 ? parsed.mapGrids : fallback.mapGrids,
    } as GameState;
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

export function addItem(state: GameState, itemId: number, count: number): boolean {
  if (!Number.isInteger(itemId) || !Number.isInteger(count) || count < 1) return false;
  const stackMax = itemById(itemId)?.stackMax ?? 1;
  const room = state.inventory.filter((stack) => stack.itemId === itemId).reduce((sum, stack) => sum + Math.max(0, stackMax - stack.count), 0)
    + Math.max(0, state.inventoryCapacity - state.inventory.length) * stackMax;
  if (room < count) return false;
  let remaining = count;
  for (const stack of state.inventory) {
    if (stack.itemId !== itemId || stack.count >= stackMax) continue;
    const taken = Math.min(remaining, stackMax - stack.count);
    stack.count += taken;
    remaining -= taken;
    if (remaining === 0) return true;
  }
  while (remaining > 0) {
    const taken = Math.min(remaining, stackMax);
    state.inventory.push({ itemId, count: taken });
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

export function recalculateStats(state: GameState): void {
  const base = { attack: 25, defense: 15, maxHp: 500, speed: 0, crit: 0, skillDamage: 0 };
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
    if (item.mainStat === "技能伤害") base.skillDamage += value;
  }
  state.stats = base;
  state.maxHp = base.maxHp;
  state.hp = Math.min(state.hp, state.maxHp);
}
