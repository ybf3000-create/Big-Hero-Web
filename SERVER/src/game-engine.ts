import { randomUUID } from "node:crypto";
import { BOSS_NAMES, ELITE_TEMPLATES, EQUIPMENT_SLOTS, GRID_ICONS, GRID_NAMES, MONSTER_DEFS, NORMAL_TEMPLATES, QUALITY_NAMES, QUALITY_WEIGHTS, itemById, skillById } from "./game-catalog.js";
import { addItem, defaultGameState, recalculateStats, removeItem, type EquipmentItem, type GameState } from "./game-state.js";

export interface CharacterProgress {
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

function expansionCost(count: number): number {
  if (count < EXPANSION_COSTS.length) return EXPANSION_COSTS[count] ?? 5_000;
  return Math.floor((EXPANSION_COSTS.at(-1) ?? 1_500_000) * (1.3 ** (count - EXPANSION_COSTS.length + 1)));
}

function numberValue(value: unknown, fallback = 0): number {
  return typeof value === "number" && Number.isFinite(value) ? value : fallback;
}

function levelUp(character: CharacterProgress): string[] {
  const messages: string[] = [];
  while (character.level < 100 && character.experience >= character.level * 100) {
    character.experience -= character.level * 100;
    character.level += 1;
    messages.push(`等级提升至 ${character.level}`);
  }
  return messages;
}

function reward(state: GameState, character: CharacterProgress, gold: number, experience: number): string[] {
  character.gold = Math.min(9_000_000_000_000_000, character.gold + Math.max(0, Math.floor(gold)));
  character.experience += Math.max(0, Math.floor(experience));
  return levelUp(character);
}

function qualityRoll(): number {
  const roll = Math.random();
  let cursor = 0;
  for (let index = 0; index < QUALITY_WEIGHTS.length; index += 1) {
    cursor += QUALITY_WEIGHTS[index] ?? 0;
    if (roll <= cursor) return index;
  }
  return 0;
}

function generateEquipment(level: number): EquipmentItem {
  const slot = EQUIPMENT_SLOTS[Math.floor(Math.random() * EQUIPMENT_SLOTS.length)] ?? EQUIPMENT_SLOTS[0];
  const quality = qualityRoll();
  const base = Math.max(1, Math.round(slot.base * (1 + level * .08) * (1 + quality * .35)));
  return {
    id: randomUUID(),
    slot: slot.key,
    name: `${QUALITY_NAMES[quality]}${slot.name}`,
    quality,
    enhance: 0,
    mainStat: slot.mainStat,
    mainValue: base,
    locked: false,
    bound: false,
  };
}

function fateEvent(state: GameState, character: CharacterProgress): Record<string, unknown> {
  const roll = Math.floor(Math.random() * 10);
  if (roll === 0) {
    const gold = Math.max(100, Math.min(50_000, Math.floor(character.gold * .05)));
    character.gold += gold;
    return { name: "股市大涨", gold, message: `股市大涨！+${gold} 金币` };
  }
  if (roll === 1) {
    const gold = Math.min(character.gold, Math.max(100, Math.min(10_000, Math.floor(character.gold * .05))));
    character.gold -= gold;
    return { name: "股市崩盘", gold: -gold, message: `股市崩盘！-${gold} 金币` };
  }
  if (roll === 2) {
    const healing = Math.floor(state.maxHp / 2);
    state.hp = Math.min(state.maxHp, state.hp + healing);
    return { name: "小憩", healing, message: "小憩恢复50%生命" };
  }
  if (roll === 3) {
    const gemId = Math.floor(Math.random() * 8) + 1;
    const gem = state.gemBag.find((entry) => entry.gemId === gemId);
    if (gem) gem.count += 1; else state.gemBag.push({ gemId, count: 1 });
    return { name: "获得宝石", gemId, message: `获得宝石 #${gemId}` };
  }
  if (roll === 4) {
    addItem(state, 6, 1);
    return { name: "获得打孔器", itemId: 6, message: "获得打孔器×1" };
  }
  if (roll === 5) {
    state.buffs.skillBoost = 3;
    return { name: "技能大赛", message: "未来3场战斗伤害+30%" };
  }
  if (roll === 6) {
    state.buffs.damagePenalty = 3;
    return { name: "诅咒降临", message: "未来3场战斗伤害-30%" };
  }
  if (roll === 7) {
    addItem(state, 5, 1);
    return { name: "天命降临", itemId: 5, message: "获得天命卡×1" };
  }
  if (roll === 8 && state.equipmentBag.length < state.equipmentCapacity) {
    const equipment = generateEquipment(character.level);
    if (equipment.quality === 0) equipment.quality = 1;
    equipment.name = `${QUALITY_NAMES[equipment.quality]}${EQUIPMENT_SLOTS.find((slot) => slot.key === equipment.slot)?.name ?? "装备"}`;
    state.equipmentBag.push(equipment);
    return { name: "装备促销", equipment, message: `装备促销：获得${equipment.name}` };
  }
  const healing = state.maxHp - state.hp;
  state.hp = state.maxHp;
  return { name: "命运逆转", healing, message: `命运逆转：恢复${healing}生命` };
}

function battle(state: GameState, character: CharacterProgress, kind: "normal" | "elite" | "boss"): Record<string, unknown> {
  const templates = kind === "normal" ? NORMAL_TEMPLATES : kind === "elite" ? ELITE_TEMPLATES : [[BOSS_NAMES[state.bossIndex % BOSS_NAMES.length]]];
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
    const unitHp = Math.max(50, Math.floor(base.hp * 300 * scale));
    const unitAttack = Math.max(1, Math.floor(base.atk * 35 * scale));
    enemyHp += unitHp;
    enemyAttack += unitAttack;
    enemyDefense += base.def * 12 * scale;
    units.push({
      id: index + 1,
      name,
      displayName: name.replace("·", " "),
      row: index > 1 ? "back" : "front",
      maxHp: unitHp,
      currentHp: unitHp,
      attack: unitAttack,
      isBoss: kind === "boss",
      asset: kind === "boss" ? `${name}.png` : MONSTER_ASSETS[Math.abs([...name].reduce((sum, char) => sum + (char.codePointAt(0) ?? 0), 0)) % MONSTER_ASSETS.length],
    });
  }
  const selectedSkills = state.skillSlots.map((id) => skillById(id)).filter((skill) => skill !== undefined);
  const strongestSkill = selectedSkills.reduce((best, skill) => Math.max(best, (skill.damagePct ?? 100) * (skill.hits ?? 1)), 100);
  const buffMultiplier = (state.buffs.skillBoost ?? 0) > 0 ? 1.3 : (state.buffs.damagePenalty ?? 0) > 0 ? .7 : 1;
  const playerAttack = state.stats.attack * strongestSkill / 100 * (1 + state.stats.skillDamage / 100) * buffMultiplier;
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
      const incoming = Math.max(1, Math.floor(enemyAttack - playerDefense * 0.35));
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
    const equipment = Math.random() < dropChance && state.equipmentBag.length < state.equipmentCapacity ? generateEquipment(character.level) : null;
    if (equipment) state.equipmentBag.push(equipment);
    const passiveHeal = selectedSkills.filter((skill) => skill.healPct).reduce((sum, skill) => sum + Math.floor(state.stats.attack * (skill.healPct ?? 0) / 100), 0);
    if (passiveHeal > 0) state.hp = Math.min(state.maxHp, state.hp + passiveHeal);
    if (kind === "boss") state.bossIndex = (state.bossIndex + 1) % BOSS_NAMES.length;
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

export function createInitialGameState(): GameState {
  const state = defaultGameState();
  recalculateStats(state);
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
  recalculateStats(state);
  let event: Record<string, unknown>;
  if (command === "roll") {
    const dice = Math.floor(Math.random() * 6) + 1;
    const previous = state.gridIndex;
    const next = (previous + dice) % state.mapTotalGrids;
    state.gridIndex = next;
    state.lastDiceRoll = dice;
    state.lastDiceSuit = Math.floor(Math.random() * 4);
    state.diceHistory = [...state.diceHistory.slice(-19), dice];
    if (previous + dice >= state.mapTotalGrids) state.completedLaps += 1;
    const gridType = state.mapGrids[next] ?? 12;
    const eventName = GRID_NAMES[gridType] ?? "空地";
    if (gridType === 1 || gridType === 2 || gridType === 11) {
      event = { ...battle(state, character, gridType === 11 ? "boss" : gridType === 2 ? "elite" : "normal"), dice, from: previous, to: next, gridType, gridName: eventName, icon: GRID_ICONS[gridType] };
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
        const equipment = generateEquipment(character.level);
        state.equipmentBag.push(equipment);
        event = { kind: "chest", dice, from: previous, to: next, gridType, gridName: eventName, equipment, message: `宝箱获得：${equipment.name}` };
      } else if (chestRoll < .92) {
        addItem(state, 5, 1);
        event = { kind: "chest", dice, from: previous, to: next, gridType, gridName: eventName, itemId: 5, itemName: itemById(5)?.name, message: "宝箱开出天命卡×1" };
      } else {
        const gemId = Math.floor(Math.random() * 7) + 1;
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
        else { character.gold -= cost; state.slotEnhance[slot] = level + 1; recalculateStats(state); event = { kind: "forge", dice, from: previous, to: next, gridType, gridName: eventName, slot, enhance: level + 1, cost, message: `${slot} +${level} → +${level + 1}（-${cost}金）` }; }
      }
    } else if (gridType === 7) {
      event = { kind: "fate", dice, from: previous, to: next, gridType, gridName: eventName, ...fateEvent(state, character) };
    } else if (gridType === 0) {
      state.hp = state.maxHp;
      event = { kind: "home", dice, from: previous, to: next, gridType, gridName: eventName, message: "回到勇者之家，状态已整备" };
    } else {
      const gold = Math.max(1, Math.floor(Math.min(character.level, 100) * (.3 + Math.random() * .5)));
      character.gold += gold;
      event = { kind: "move", dice, from: previous, to: next, gridType, gridName: eventName, gold, message: `+${gold} 金币` };
    }
  } else if (command === "item_use") {
    const itemId = numberValue(payload.item_id, -1);
    const item = itemById(itemId);
    if (!item || !removeItem(state, itemId, 1)) throw new Error("物品不足或不存在");
    const effect = item.stats;
    if (effect.heal) state.hp = Math.min(state.maxHp, state.hp + effect.heal);
    if (effect.experience) character.experience += effect.experience;
    if (effect.gold) character.gold += effect.gold;
    const messages = levelUp(character);
    event = { kind: "item_use", itemId, itemName: item.name, messages, message: `使用了${item.name}` };
  } else if (command === "equipment_equip" || command === "equipment_unequip") {
    const equipmentId = typeof payload.equipment_id === "string" ? payload.equipment_id : "";
    const item = state.equipmentBag.find((entry) => entry.id === equipmentId);
    if (command === "equipment_equip") {
      if (!item) throw new Error("装备不存在");
      state.equipped[item.slot] = item.id;
      event = { kind: "equipment", action: "equip", item };
    } else {
      const slot = typeof payload.slot === "string" ? payload.slot : item?.slot;
      if (!slot || !(slot in state.equipped)) throw new Error("装备槽不存在");
      state.equipped[slot] = null;
      event = { kind: "equipment", action: "unequip", slot };
    }
    recalculateStats(state);
  } else if (command === "equipment_dismantle") {
    const equipmentId = typeof payload.equipment_id === "string" ? payload.equipment_id : "";
    const item = state.equipmentBag.find((entry) => entry.id === equipmentId);
    if (!item || item.locked || Object.values(state.equipped).includes(equipmentId)) throw new Error("装备无法分解");
    state.equipmentBag = state.equipmentBag.filter((entry) => entry.id !== equipmentId);
    character.gold += 20 + item.quality * 40;
    event = { kind: "equipment", action: "dismantle", equipmentId, gold: 20 + item.quality * 40 };
  } else if (command === "equipment_lock") {
    const equipmentId = typeof payload.equipment_id === "string" ? payload.equipment_id : "";
    const item = state.equipmentBag.find((entry) => entry.id === equipmentId);
    if (!item) throw new Error("装备不存在");
    item.locked = typeof payload.locked === "boolean" ? payload.locked : !item.locked;
    event = { kind: "equipment", action: "lock", equipmentId, locked: item.locked };
  } else if (command === "equipment_enhance") {
    const equipmentId = typeof payload.equipment_id === "string" ? payload.equipment_id : "";
    const item = state.equipmentBag.find((entry) => entry.id === equipmentId);
    if (!item) throw new Error("装备不存在");
    const level = state.slotEnhance[item.slot] ?? 0;
    if (level >= 200) throw new Error("装备槽位已达到强化上限");
    const price = level * 500;
    if (character.gold < price) throw new Error("金币不足");
    character.gold -= price;
    state.slotEnhance[item.slot] = level + 1;
    recalculateStats(state);
    event = { kind: "equipment", action: "enhance", equipmentId, slot: item.slot, enhance: level + 1, price };
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
    const skillId = numberValue(payload.skill_id, -1);
    if (!state.skills.includes(skillId)) throw new Error("技能尚未解锁");
    const maxSlots = character.level >= 45 ? 6 : character.level >= 35 ? 5 : character.level >= 15 ? 4 : character.level >= 5 ? 3 : 2;
    const slots = Array.isArray(payload.slots) ? payload.slots.filter((id): id is number => typeof id === "number" && state.skills.includes(id)).slice(0, maxSlots) : [...state.skillSlots];
    if (!slots.includes(skillId)) slots.push(skillId);
    state.skillSlots = [...new Set(slots)].slice(0, maxSlots);
    event = { kind: "skill", action: "slot", slots: state.skillSlots };
  } else if (command === "skill_cast") {
    const skillId = numberValue(payload.skill_id, -1);
    const skill = skillById(skillId);
    if (!skill || !state.skills.includes(skillId)) throw new Error("技能尚未解锁");
    const healing = skill.healPct ? Math.max(1, Math.floor(state.stats.attack * skill.healPct / 100)) : 0;
    if (healing > 0) state.hp = Math.min(state.maxHp, state.hp + healing);
    event = { kind: "skill", action: "cast", skillId, skillName: skill.name, healing, message: healing > 0 ? `释放${skill.name}，恢复${healing}生命` : `释放了${skill.name}` };
  } else {
    throw new Error("不支持的游戏操作");
  }
  return { state, character, event };
}
