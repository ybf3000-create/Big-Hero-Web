import { MELEE_SKILL_IDS, MONSTERS, TargetTag, ControlType, battleSkillById, type BattleSkill } from "./battle-catalog.js";
import type { BattleEncounter, EncounterUnit, RandomSource } from "./monster-generator.js";

type Data = Record<string, any>;

export const BattleOutcome = { VICTORY: 0, DEFEAT: 1, DRAW: 2, CHALLENGE_DONE: 3 } as const;

export interface BattlePlayerState {
  name: string;
  level: number;
  currentHp: number;
  maxHp: number;
  attack: number;
  defense: number;
  speedPoints: number;
  crit: number;
  critDamage: number;
  hit: number;
  dodge: number;
  block: number;
  skillDamage: number;
  cooldownReduction: number;
  lifesteal: number;
  freeAttackPct: number;
  freeDefensePct: number;
  goldBonus: number;
  experienceBonus: number;
  luck: number;
  skillSlots: Array<{ skillId: number; priority: number } | null>;
  battleDamageMultiplier: number;
  incomingDamageMultiplier: number;
  passives: string[];
  setCounts: Record<string, number>;
  setAffixes: string[];
  battleGold: number;
}

export interface BattleResult extends Data {
  outcome: number;
  player_hp: number;
  player_start_hp: number;
  player_max_hp: number;
  player_alive: boolean;
  damage_total: number;
  elapsed: number;
  rounds: number;
  log: string[];
  events: Data[];
  battle_kind: string;
  monster_level: number;
  template_id: string;
  template_name: string;
  gold_gain: number;
  exp_gain: number;
  drops: Data[];
  boss_cleared: boolean;
  luxury_gold_spent: number;
}

const BASE_ACTION_COOLDOWN = 3;
const MAX_ROUNDS = 50;
const SHIELD_DURATION = 5;
const REGEN_INTERVAL = 5;

const n = (value: unknown, fallback = 0): number => typeof value === "number" && Number.isFinite(value) ? value : fallback;
const b = (value: unknown): boolean => value === true;
const randomInt = (minimum: number, maximum: number, random: RandomSource): number => minimum + Math.floor(random() * (maximum - minimum + 1));
const summonAsset = (name: string): string => ({
  "史莱姆·战士": "char_0001.png", "骷髅·战士": "char_0007.png", "暗影·盗贼": "char_0016.png", "狼·盗贼": "char_0031.png",
}[name] ?? "char_0001.png");
const pick = <T>(values: readonly T[], random: RandomSource): T => values[Math.min(values.length - 1, Math.floor(random() * values.length))]!;

function actorRef(actor: Data): Data {
  return { side: String(actor.side ?? "enemy"), id: n(actor.id), name: String(actor.name ?? "单位") };
}

function setCount(actor: Data, setName: string): number {
  return n(actor.setCounts?.[setName]);
}

function hasSetAffix(actor: Data, affix: string): boolean {
  return Array.isArray(actor.setAffixes) && actor.setAffixes.includes(affix);
}

function hasPassive(actor: Data, passive: string): boolean {
  return Array.isArray(actor.passives) && actor.passives.includes(passive);
}

function actionCooldown(speedPoints: number): number {
  return BASE_ACTION_COOLDOWN * (1 - Math.min(speedPoints * .008, .5));
}

function actorFromEncounter(unit: EncounterUnit): Data {
  const cooldowns: Record<number, number> = {};
  for (const skillId of unit.skill_ids) if (skillId > 0) cooldowns[skillId] = 0;
  const actor: Data = {
    side: "enemy", id: unit.id, name: unit.name, displayName: unit.display_name, row: unit.row, level: unit.level,
    maxHp: unit.max_hp, currentHp: unit.current_hp, attack: unit.atk, baseAttack: unit.atk, defense: unit.def, baseDefense: unit.def,
    speedPoints: unit.speed_points, crit: unit.crit, critDamage: unit.critdmg, hit: unit.hit, dodge: unit.dodge, block: unit.block,
    // Enemy units use the same arithmetic path as the player. Keep every
    // optional combat modifier explicit so a skill cannot turn into NaN
    // because an enemy does not have a player-only stat.
    skillDamage: 0, cooldownReduction: 0, lifesteal: 0, freeAttackPct: 0, freeDefensePct: 0,
    incomingDamageMultiplier: 1,
    skillIds: [...unit.skill_ids], passives: [...unit.passives], isElite: unit.is_elite, isBoss: unit.is_boss, infiniteHp: unit.infinite_hp,
    bossIndex: unit.boss_index ?? 0, bossMechanic: structuredClone(unit.boss_mechanic ?? {}), cooldowns, shield: 0, shieldTime: 0,
    buffs: {}, controls: {}, dots: [], hots: [], alive: true, undyingUsed: false, battleDamageMultiplier: 1,
    actionCooldown: actionCooldown(unit.speed_points), timeToAct: actionCooldown(unit.speed_points), regenTimer: REGEN_INTERVAL,
    baseActionCooldown: actionCooldown(unit.speed_points),
    mechanicTimer: n(unit.boss_mechanic?.interval), mechanicTriggers: 0, summonCount: 0, trackedAllyDeaths: 0,
    ritualTriggered: false, revivesLeft: n(unit.boss_mechanic?.revives), setCounts: {}, setAffixes: [], setActionCount: 0,
  };
  applyPassiveStart(actor);
  return actor;
}

function buildInitialState(playerState: BattlePlayerState, encounter: BattleEncounter): Data {
  const cooldowns: Record<number, number> = {};
  for (const slot of playerState.skillSlots) if (slot && slot.skillId > 0) cooldowns[slot.skillId] = 0;
  const player: Data = {
    side: "player", id: 0, name: playerState.name, level: playerState.level, maxHp: playerState.maxHp, currentHp: playerState.currentHp,
    attack: playerState.attack, baseAttack: playerState.attack, defense: playerState.defense, baseDefense: playerState.defense,
    speedPoints: playerState.speedPoints, crit: playerState.crit, critDamage: playerState.critDamage, hit: playerState.hit,
    dodge: playerState.dodge, block: playerState.block, skillDamage: playerState.skillDamage, cooldownReduction: playerState.cooldownReduction,
    lifesteal: playerState.lifesteal, freeAttackPct: playerState.freeAttackPct, freeDefensePct: playerState.freeDefensePct,
    goldBonus: playerState.goldBonus, experienceBonus: playerState.experienceBonus, luck: playerState.luck, skillSlots: structuredClone(playerState.skillSlots),
    cooldowns, shield: 0, shieldTime: 0, buffs: {}, controls: {}, dots: [], hots: [], alive: true,
    actionCooldown: actionCooldown(playerState.speedPoints), timeToAct: actionCooldown(playerState.speedPoints), undyingUsed: false,
    baseActionCooldown: actionCooldown(playerState.speedPoints),
    battleDamageMultiplier: playerState.battleDamageMultiplier, incomingDamageMultiplier: playerState.incomingDamageMultiplier,
    healingMultiplier: n(playerState.setCounts?.["自然"]) >= 3 ? 1.2 : 1,
    passives: [...playerState.passives], regenTimer: REGEN_INTERVAL, setCounts: { ...playerState.setCounts },
    setAffixes: [...playerState.setAffixes], battleGold: playerState.battleGold, luxuryGoldSpent: 0, luxuryTimer: 10, setActionCount: 0, thunderTimer: 8,
  };
  if (setCount(player, "暗影") >= 3) player.buffs.shadow_stealth = 5 + (hasSetAffix(player, "【暗影】潜伏") ? 2 : 0);
  applyLuxuryAttack(player);
  const enemies = encounter.units.map(actorFromEncounter);
  applyBossStartEffects(player, enemies);
  applyWeatherStart([player, ...enemies], encounter.weather);
  const state: Data = {
    actors: { player, enemies }, elapsed: 0, rounds: 0, log: [], events: [], damageTotal: 0,
    playerStartHp: player.currentHp, outcome: -1, battleKind: encounter.battle_kind, templateId: encounter.template_id,
    templateName: encounter.template_name, weather: encounter.weather, weatherTimer: weatherInterval(encounter.weather), random: Math.random,
  };
  for (const boss of enemies) {
    if (["command", "vampire", "storm_field", "rock"].includes(String(boss.bossMechanic?.id ?? ""))) {
      emitMechanic(state, boss, `${boss.bossMechanic.name}·生效`);
    }
  }
  return state;
}

function resolveActor(state: Data, key: string): Data | null {
  if (key === "player") return state.actors.player;
  const match = /^enemy:(\d+)$/.exec(key);
  return match ? state.actors.enemies[n(Number(match[1]))] ?? null : null;
}

function pickNextActor(state: Data): string {
  let bestKey = state.actors.player.alive ? "player" : "";
  let bestTime = state.actors.player.alive ? n(state.actors.player.timeToAct, Infinity) : Infinity;
  for (const [index, enemy] of state.actors.enemies.entries()) {
    if (!enemy.alive) continue;
    if (n(enemy.timeToAct, Infinity) < bestTime) {
      bestTime = enemy.timeToAct;
      bestKey = `enemy:${index}`;
    }
  }
  return bestKey;
}

function tickActorTimers(state: Data, actor: Data, delta: number): void {
  if (actor.buffs.chaos_attack && actor.buffs.chaos_attack <= delta) actor.attack = actor.baseAttack;
  if (actor.buffs.chaos_defense && actor.buffs.chaos_defense <= delta) actor.defense = actor.baseDefense;
  if (actor.buffs.chaos_speed && actor.buffs.chaos_speed <= delta) actor.actionCooldown = actor.baseActionCooldown;
  if (setCount(actor, "雷霆") >= 4) {
    actor.thunderTimer = n(actor.thunderTimer, 8) - delta;
    if (actor.thunderTimer <= 0) {
      actor.buffs.thunder_frenzy = hasSetAffix(actor, "【雷霆】余震") ? 3 : 2;
      actor.thunderTimer = 8;
    }
  }
  if (actor.shieldTime > 0) {
    actor.shieldTime = Math.max(0, actor.shieldTime - delta);
    if (actor.shieldTime <= 0) actor.shield = 0;
  }
  if (actor.setBurnSpreadTimer !== undefined) {
    actor.setBurnSpreadTimer = Math.max(0, n(actor.setBurnSpreadTimer) - delta);
    if (actor.setBurnSpreadTimer <= 0 && actor.setBurnSpreadSource && actor.alive) {
      const source = actor.setBurnSpreadSource;
      actor.setBurnSpreadTimer = 3;
      if (source?.alive) spreadSetBurn(state, actor, source);
    }
  }
  for (const [key, value] of Object.entries(actor.buffs as Record<string, number>)) {
    actor.buffs[key] = Math.max(0, value - delta);
    if (actor.buffs[key] <= 0) delete actor.buffs[key];
  }
  for (const [key, value] of Object.entries(actor.controls as Record<string, number>)) {
    actor.controls[key] = Math.max(0, value - delta);
    if (actor.controls[key] <= 0) delete actor.controls[key];
  }
  for (let index = actor.dots.length - 1; index >= 0; index -= 1) {
    const dot = actor.dots[index];
    if (!dot) continue;
    dot.tickTimer -= delta;
    while (dot.tickTimer <= 0 && dot.ticksRemaining > 0 && actor.alive) {
      dot.tickTimer += dot.tickInterval;
      tickDot(state, actor, dot);
      dot.ticksRemaining -= 1;
    }
    const currentIndex = actor.dots.indexOf(dot);
    if (currentIndex >= 0 && (dot.ticksRemaining <= 0 || !actor.alive)) actor.dots.splice(currentIndex, 1);
  }
  for (let index = actor.hots.length - 1; index >= 0; index -= 1) {
    const hot = actor.hots[index]!;
    hot.tickTimer -= delta;
    while (hot.tickTimer <= 0 && hot.ticksRemaining > 0 && actor.alive) {
      hot.tickTimer += hot.tickInterval;
      applyHeal(state, actor, actor.maxHp * hot.healPct / 100, "持续治疗");
      hot.ticksRemaining -= 1;
    }
    if (hot.ticksRemaining <= 0) actor.hots.splice(index, 1);
  }
  if (hasPassive(actor, "回复") && actor.alive) {
    actor.regenTimer = n(actor.regenTimer, REGEN_INTERVAL) - delta;
    while (actor.regenTimer <= 0 && actor.alive) {
      actor.regenTimer += REGEN_INTERVAL;
      applyHeal(state, actor, actor.maxHp * .05, "回复");
    }
  }
  if (setCount(actor, "自然") >= 4 && actor.shield > 0 && actor.alive) {
    actor.natureRegenTimer = n(actor.natureRegenTimer, 1) - delta;
    while (actor.natureRegenTimer <= 0) {
      actor.natureRegenTimer += 1;
      applyHeal(state, actor, actor.maxHp * (hasSetAffix(actor, "【自然】繁茂") ? .04 : .02), "自然护盾");
    }
  }
}

function advanceTime(state: Data, delta: number): void {
  state.elapsed += delta;
  for (const actor of [state.actors.player, ...state.actors.enemies]) {
    if (!actor.alive) continue;
    actor.timeToAct = Math.max(0, actor.timeToAct - delta);
    tickActorTimers(state, actor, delta);
  }
  const player = state.actors.player;
  if (setCount(player, "奢侈") >= 3) {
    player.luxuryTimer = n(player.luxuryTimer, 10) - delta;
    while (player.luxuryTimer <= 0) {
      player.luxuryTimer += 10;
      const configuredCost = player.level * (setCount(player, "奢侈") >= 4 ? 100 : 50);
      const cost = Math.min(Math.max(0, n(player.battleGold)), Math.max(0, configuredCost));
      player.battleGold = Math.max(0, n(player.battleGold) - cost);
      player.luxuryGoldSpent = n(player.luxuryGoldSpent) + cost;
      applyLuxuryAttack(player);
    }
  }
  tickBossMechanics(state, delta);
  tickWeather(state, delta);
}

function applyLuxuryAttack(actor: Data): void {
  if (setCount(actor, "奢侈") < 3) return;
  actor.attack = n(actor.baseAttack);
  if (actor.battleGold < 1_000) return;
  let multiplier = setCount(actor, "奢侈") >= 4 ? 1.6 : 1.3;
  if (hasSetAffix(actor, "【奢侈】镀金")) multiplier += .1;
  if (actor.battleGold < 5_000 && hasSetAffix(actor, "【奢侈】挥霍")) multiplier += .2;
  if (actor.battleGold > 10_000 && hasSetAffix(actor, "【奢侈】豪赌")) multiplier += .15;
  if (actor.battleGold < 500 && hasSetAffix(actor, "【奢侈】破产")) multiplier += .4;
  actor.attack = n(actor.baseAttack) * multiplier;
}

function chooseAction(actor: Data): Data {
  if (actor.controls.silence) return { type: "basic" };
  const available: Data[] = [];
  if (actor.side === "player") {
    if (actor.currentHp <= actor.maxHp * .2 && !actor.undyingUsed) {
      for (const slot of actor.skillSlots) if (slot?.skillId === 26 && n(actor.cooldowns[26]) <= 0) available.push({ priority: 99, slot: -1, skillId: 26 });
    }
    for (const [index, slot] of actor.skillSlots.entries()) {
      // 不屈意志 is an automatic emergency trigger, never a normal rotation skill.
      if (slot && slot.skillId > 0 && slot.skillId !== 26 && n(actor.cooldowns[slot.skillId]) <= 0) available.push({ priority: slot.priority, slot: index, skillId: slot.skillId });
    }
  } else {
    for (const skillId of actor.skillIds) if (skillId > 0 && n(actor.cooldowns[skillId]) <= 0) available.push({ priority: 1, slot: 0, skillId });
  }
  available.sort((left, right) => right.priority - left.priority || left.slot - right.slot);
  return available.length > 0 ? { type: "skill", skillId: available[0]!.skillId } : { type: "basic" };
}

function resetAfterTurn(actor: Data, random: RandomSource): void {
  let next = actor.actionCooldown * (actor.controls.slow ? 1.5 : 1);
  actor.setActionCount = n(actor.setActionCount) + 1;
  if (setCount(actor, "疾风") >= 3) {
    const threshold = hasSetAffix(actor, "【疾风】步法") ? 2 : 3;
    if (actor.setActionCount % threshold === 0) {
      next = .01;
      actor.buffs.wind_second = 10;
      if (setCount(actor, "疾风") >= 4) resetRandomCooldown(actor, random);
      if (hasSetAffix(actor, "【疾风】回响")) resetRandomCooldown(actor, random);
    }
  }
  actor.timeToAct = next;
}

function resetRandomCooldown(actor: Data, random: RandomSource): void {
  const active = Object.keys(actor.cooldowns).filter((key) => n(actor.cooldowns[key]) > 0);
  if (active.length > 0) actor.cooldowns[pick(active, random)!] = 0;
}

function opponents(state: Data, actor: Data): Data[] {
  return actor.side === "player" ? state.actors.enemies : [state.actors.player];
}

function livingEnemies(state: Data): Data[] {
  return state.actors.enemies.filter((enemy: Data) => enemy.alive);
}

function selectTargets(state: Data, actor: Data, targetTag: number, skill?: BattleSkill): Data[] {
  if (actor.side === "enemy") {
    if (targetTag === TargetTag.SELF || targetTag === TargetTag.SELF_HEAL) return [actor];
    return state.actors.player.alive ? [state.actors.player] : [];
  }
  const enemies = livingEnemies(state);
  if (enemies.length === 0) return [];
  const front = enemies.filter((enemy) => enemy.row === "front");
  const back = enemies.filter((enemy) => enemy.row !== "front");
  const first = (preferred: Data[], fallback: Data[]): Data[] => [preferred[0] ?? fallback[0]!];
  if (targetTag === TargetTag.FRONT_LINE) return first(front, back);
  if (targetTag === TargetTag.BACK_LINE) return first(back, front);
  if (targetTag === TargetTag.LOWEST_HP) return [[...enemies].sort((a, z) => a.currentHp - z.currentHp)[0]!];
  if (targetTag === TargetTag.LOWEST_HP_PCT) return [[...enemies].sort((a, z) => a.currentHp / a.maxHp - z.currentHp / z.maxHp)[0]!];
  if (targetTag === TargetTag.HIGHEST_ATK) return [[...enemies].sort((a, z) => z.attack - a.attack)[0]!];
  if (targetTag === TargetTag.HIGHEST_DEF) return [[...enemies].sort((a, z) => z.defense - a.defense)[0]!];
  if (targetTag === TargetTag.AOE_FRONT) return front.length > 0 ? front : back;
  if (targetTag === TargetTag.AOE_BACK) return back.length > 0 ? back : front;
  if (targetTag === TargetTag.AOE_ALL) return n(skill?.bonus?.maxTargets) > 0 ? enemies.slice(0, n(skill?.bonus?.maxTargets)) : enemies;
  if (targetTag === TargetTag.PIERCE) {
    if (front.length === 0) return [back[0]!];
    const index = front.indexOf(front[0]!);
    return back[index] ? [front[0]!, back[index]!] : [front[0]!];
  }
  return [];
}

function castEvent(actor: Data, targets: Data[], skillId: number, label: string, visual: string): Data {
  return { type: "cast", source: actorRef(actor), targets: targets.map(actorRef), skill_id: skillId, label, visual };
}

function skillVisual(skill: BattleSkill): string {
  if (MELEE_SKILL_IDS.has(skill.id)) return "melee";
  if (skill.healPct !== undefined) return "heal";
  if (skill.shieldPct !== undefined || skill.buffEffect) return "buff";
  if (skill.dotPct !== undefined) return skill.dotType === "burn" ? "fire" : skill.dotType === "poison" ? "poison" : skill.dotType === "bleed" ? "blood" : "dot";
  if (skill.control !== undefined) return skill.control === ControlType.FREEZE || skill.control === ControlType.SLOW ? "ice" : skill.control === ControlType.PARALYSIS ? "thunder" : "control";
  if ([TargetTag.AOE_FRONT, TargetTag.AOE_ALL, TargetTag.AOE_BACK].includes(skill.target as 6 | 7 | 8)) return "aoe";
  return "projectile";
}

function resolveHit(actor: Data, target: Data, random: RandomSource): Data {
  let dodgeMultiplier = target.buffs.phantom_step ? 2 : 1;
  let crit = actor.crit;
  let hit = actor.hit;
  if (actor.buffs.shadow_stealth) { crit += 30; hit += 20; }
  if (actor.buffs.thunder_frenzy || actor.buffs.shadow_strike) crit = 100;
  return { hit: random() * 100 >= Math.max(0, target.dodge - hit) * dodgeMultiplier, crit: random() * 100 < crit, block: random() * 100 < target.block };
}

function defenseDamage(attacker: Data, target: Data, damage: number, ignoreDefensePct: number): number {
  const safeDamage = Math.max(0, n(damage));
  const safeIgnoreDefense = Math.max(0, Math.min(100, n(ignoreDefensePct)));
  let defense = Math.max(0, n(target.defense)) * (target.buffs.def_x2 ? 2 : 1) * (1 - safeIgnoreDefense / 100);
  const attackerLevel = Math.max(1, n(attacker.level, 1));
  let result = safeDamage * Math.max(.05, 1 - defense / (defense + 85 * attackerLevel + 400));
  if (target.side === "player") result *= (1 - Math.min(n(target.freeDefensePct), .5)) * n(target.incomingDamageMultiplier, 1);
  if (target.buffs.tenacity) result *= .6;
  if (target.buffs.dragon_guard) result *= .7;
  if (target.controls.paralysis) result *= 1.2;
  if (target.bossMechanic?.id === "rock") result *= 1 - n(target.bossMechanic.damageReduction, .3);
  return Math.max(result, 1);
}

function applyFinalDamage(state: Data, target: Data, damage: number, meta: Data): number {
  let remaining = Math.max(0, n(damage)) * (hasSetAffix(target, "【龙鳞】硬皮") ? .96 : 1);
  let absorbed = 0;
  if (!meta.ignoreShield && target.shield > 0) {
    absorbed = Math.min(target.shield, remaining);
    target.shield -= absorbed;
    if (target.frostShieldAmount > 0) target.frostShieldAmount = Math.max(0, target.frostShieldAmount - Math.min(target.frostShieldAmount, absorbed));
    remaining -= absorbed;
  }
  const before = target.currentHp;
  if (remaining > 0) target.currentHp = Math.max(0, before - remaining);
  const dealtHp = Math.max(0, before - target.currentHp);
  if (target.currentHp <= 0) {
    if (target.buffs.undying) {
      target.currentHp = 1;
      delete target.buffs.undying;
    } else if (target.revivesLeft > 0) {
      target.revivesLeft -= 1;
      target.currentHp = target.maxHp;
      target.alive = true;
      state.events.push({ type: "status", target: actorRef(target), status: "生命之种·复活", duration: 0 });
    } else if (target.infiniteHp) {
      target.currentHp = Math.max(1, target.currentHp);
    } else {
      target.alive = false;
      target.dots = [];
      if (hasPassive(target, "诅咒") && meta.owner) {
        meta.owner.controls.anti_heal = 5;
        state.log.push(`${target.name} 的诅咒触发，${meta.owner.name} 被禁疗 5 秒`);
      }
    }
  }
  // Lifesteal is based on final damage before the target's shield absorbs it.
  // A shield should protect HP, but must not make an otherwise valid hit
  // produce zero healing.
  const total = dealtHp + absorbed;
  if (meta.owner && meta.owner.lifesteal > 0 && total > 0) applyHeal(state, meta.owner, total * meta.owner.lifesteal / 100, "吸血");
  handleBossHpTriggers(state, target);
  if (meta.owner?.side === "player") state.damageTotal += Math.max(0, total);
  return total;
}

function applyHeal(state: Data, actor: Data, amount: number, label: string): void {
  const actual = Math.max(0, n(amount)) * n(actor.weatherHealMultiplier, 1) * n(actor.healingMultiplier, 1) * (actor.controls.anti_heal ? .5 : 1);
  const before = actor.currentHp;
  actor.currentHp = Math.min(actor.maxHp, before + actual);
  const healed = actor.currentHp - before;
  const overflow = Math.max(0, actual - healed);
  if (overflow > 0 && setCount(actor, "自然") >= 4) {
    const cap = actor.maxHp * (hasSetAffix(actor, "【自然】庇护") ? .45 : .3);
    actor.shield = Math.min(cap, actor.shield + overflow);
    actor.shieldTime = Math.max(actor.shieldTime, SHIELD_DURATION);
  }
  // Keep a no-op heal in the authoritative timeline for replay/debugging, but
  // mark it ineffective so the client does not show a misleading "+0" pop-up.
  const effective = healed > 0 || overflow > 0;
  state.log.push(`${actor.name} ${label} ${Math.round(healed)}`);
  state.events.push({ type: "heal", target: actorRef(actor), amount: Math.round(healed), hp: Math.round(actor.currentHp), max_hp: actor.maxHp, label, effective });
}

function applyShield(state: Data, actor: Data, skill: BattleSkill): void {
  const basis = skill.shieldStat === "attack" ? actor.attack : skill.shieldStat === "maxHpPct" ? actor.maxHp : actor.defense;
  const amount = basis * n(skill.shieldPct) / 100 * n(actor.weatherShieldMultiplier, 1);
  actor.shield += amount;
  actor.shieldTime = SHIELD_DURATION;
  state.events.push({ type: "shield", target: actorRef(actor), amount: Math.round(amount), shield: Math.round(actor.shield), max_hp: actor.maxHp, label: skill.name });
}

function applyControl(state: Data, target: Data, skill: BattleSkill): void {
  if (target.buffs.tenacity || target.bossMechanic?.controlImmune) return;
  const duration = n(skill.controlDuration) * (target.isBoss ? .5 : 1);
  const keys = ["", "freeze", "stun", "silence", "paralysis", "slow", "anti_heal"];
  const names = ["", "冻结", "眩晕", "沉默", "麻痹", "减速", "禁疗"];
  const key = keys[skill.control ?? 0];
  if (!key || duration <= 0) return;
  target.controls[key] = duration;
  state.events.push({ type: "status", target: actorRef(target), status: names[skill.control ?? 0], duration });
}

function tickDot(state: Data, target: Data, dot: Data): void {
  const dealt = applyFinalDamage(state, target, dot.damage, { source: dot.sourceName, dot: true });
  state.events.push({ type: "damage", target: actorRef(target), amount: Math.round(dealt), hp: Math.round(target.currentHp), max_hp: target.maxHp, shield: Math.round(target.shield), crit: false, block: false, dot: true, label: dot.sourceName });
  if (dot.sourceSide === "player") state.damageTotal += Math.max(0, dealt);
}

function applyDot(state: Data, target: Data, actor: Data, skill: BattleSkill): void {
  const entry: Data = { sourceName: skill.name, damage: actor.attack * n(skill.dotPct) / 100 * actor.battleDamageMultiplier, ticksRemaining: Math.max(1, n(skill.dotTickCount, 1)), tickInterval: Math.max(.01, n(skill.dotTickInterval, 1)), tickTimer: Math.max(.01, n(skill.dotTickInterval, 1)), dotType: skill.dotType ?? "dot", sourceSide: actor.side };
  if ((skill.dotMode ?? 0) === 0) {
    const current = target.dots.find((dot: Data) => dot.sourceName === entry.sourceName);
    if (current) {
      Object.assign(current, entry);
      tickDot(state, target, current);
      current.ticksRemaining -= 1;
      return;
    }
  }
  if (target.dots.length >= 10) target.dots.shift();
  target.dots.push(entry);
  tickDot(state, target, entry);
  entry.ticksRemaining -= 1;
}

function applySetBurn(state: Data, target: Data, actor: Data): void {
  const burns = target.dots.filter((dot: Data) => dot.dotType === "set_burn").length;
  if (burns < 3) target.setBurnDetonated = false;
  if (burns >= (hasSetAffix(actor, "【烈焰】核心") ? 4 : 3)) return;
  const entry: Data = { sourceName: "烈焰套·灼烧", damage: actor.attack * (hasSetAffix(actor, "【烈焰】灼烧") ? .3 : .2), ticksRemaining: 3, tickInterval: 1, tickTimer: 1, dotType: "set_burn", sourceSide: actor.side };
  target.setBurnDamageTaken = true;
  target.dots.push(entry);
  tickDot(state, target, entry);
  entry.ticksRemaining -= 1;
}

function spreadSetBurn(state: Data, sourceTarget: Data, actor: Data): void {
  const spreadTargets = opponents(state, actor).filter((candidate) => candidate !== sourceTarget && candidate.alive).slice(0, 2);
  for (const spread of spreadTargets) applySetBurn(state, spread, actor);
}

function triggerChainLightning(state: Data, actor: Data, primary: Data): void {
  let maxTargets = 2 + (hasSetAffix(actor, "【雷霆】之速") ? 1 : 0);
  for (const target of opponents(state, actor)) {
    if (target === primary || !target.alive || maxTargets <= 0) continue;
    const dealt = applyFinalDamage(state, target, actor.attack * (hasSetAffix(actor, "【雷霆】轰鸣") ? 1.95 : 1.5), { source: "雷霆套·连锁闪电", owner: actor });
    state.events.push({ type: "damage", source: actorRef(actor), target: actorRef(target), amount: Math.round(dealt), hp: Math.round(target.currentHp), max_hp: target.maxHp, shield: Math.round(target.shield), crit: false, block: false, dot: false, label: "连锁闪电" });
    maxTargets -= 1;
  }
}

function handleSetKill(state: Data, actor: Data): void {
  if (setCount(actor, "暗影") >= 4) {
    actor.buffs.shadow_strike = hasSetAffix(actor, "【暗影】疾影") ? 6 : 4;
    actor.timeToAct = 0;
  }
  if (setCount(actor, "自然") >= 3) applyHeal(state, actor, actor.maxHp * (hasSetAffix(actor, "【自然】恩赐") ? .13 : .08), "自然套·生机");
}

function applyAttack(state: Data, actor: Data, target: Data, damagePct: number, skill: BattleSkill | undefined, label: string, isBasic: boolean, random: RandomSource): void {
  let rawDamage = n(actor.attack) * Math.max(0, n(damagePct)) / 100;
  if (isBasic && actor.controls.silence) rawDamage *= 1.2;
  if (actor.buffs.phantom_step) rawDamage *= hasSetAffix(actor, "【幻影】残影") ? 1.45 : 1.3;
  if (label.includes("暗影突袭") && hasSetAffix(actor, "【暗影】之刃")) rawDamage *= 1.3;
  if (actor.side === "player") rawDamage *= 1 + n(actor.freeAttackPct);
  if (hasPassive(actor, "狂暴") && n(actor.currentHp) / Math.max(1, n(actor.maxHp, 1)) < .5) rawDamage *= 1.5;
  for (let hit = 0; hit < (skill?.hits ?? 1); hit += 1) {
    const result = resolveHit(actor, target, random);
    if (!result.hit) {
      state.events.push({ type: "miss", source: actorRef(actor), target: actorRef(target), label });
      if (setCount(target, "幻影") >= 3) {
        target.buffs.phantom_next = 999;
        target.phantomDodges = n(target.phantomDodges) + 1;
        if (setCount(target, "幻影") >= 4 && target.phantomDodges % 3 === 0) target.buffs.phantom_step = hasSetAffix(target, "【幻影】迷踪") ? 4 : 3;
      }
      continue;
    }
    let damage = rawDamage;
    const phantomBonus = Boolean(actor.buffs.phantom_next);
    if (actor.buffs.phantom_next) delete actor.buffs.phantom_next;
    if (actor.buffs.wind_second) { if (hasSetAffix(actor, "【疾风】连击")) damage *= 1.3; delete actor.buffs.wind_second; }
    const shadowStrikeBonus = Boolean(actor.buffs.shadow_strike && skill);
    damage = defenseDamage(actor, target, damage, n(skill?.bonus?.ignoreDefPct));
    if (result.crit) {
      let criticalDamage = n(actor.critDamage, 150);
      if (label.includes("暗影突袭") && hasSetAffix(actor, "【暗影】杀意")) criticalDamage += 50;
      if (actor.buffs.thunder_frenzy && hasSetAffix(actor, "【雷霆】蓄能")) criticalDamage += 50;
      damage *= criticalDamage / 100;
    }
    if (result.block) {
      let multiplier = setCount(target, "铁壁") >= 3 ? .35 : .5;
      if (hasSetAffix(target, "【铁壁】堡垒")) multiplier = Math.max(0, multiplier - .1);
      damage *= multiplier;
    }
    // Final-damage modifiers are applied after defense, crit and block.
    if (phantomBonus) damage *= hasSetAffix(actor, "【幻影】步法") ? 1.7 : 1.5;
    if (shadowStrikeBonus) damage *= 2.5;
    damage *= n(actor.battleDamageMultiplier, 1);
    // Skill-damage bonuses apply to skills and DoT skills, never to the
    // fallback basic attack.
    if (skill) damage *= 1 + n(actor.skillDamage) / 100;
    if (target.controls.freeze) { damage *= hasSetAffix(actor, "【冰霜】寒甲") ? 1.7 : 1.5; delete target.controls.freeze; }
    const burnCount = target.dots.filter((dot: Data) => dot.dotType === "set_burn").length;
    if (target.setBurnDamageTaken && burnCount > 0) damage *= 1 + Math.min(burnCount, 4) * .12;
    if (n(skill?.bonus?.executeThreshold) > 0 && target.currentHp / target.maxHp < n(skill?.bonus?.executeThreshold)) damage *= n(skill?.bonus?.executeMultiplier, 1);
    if (n(skill?.bonus?.missingHpScale) > 0) damage *= 1 + (1 - target.currentHp / target.maxHp) * n(skill?.bonus?.missingHpScale);
    const dealt = applyFinalDamage(state, target, damage, { owner: actor });
    state.events.push({ type: "damage", source: actorRef(actor), target: actorRef(target), amount: Math.round(dealt), hp: Math.round(target.currentHp), max_hp: target.maxHp, shield: Math.round(target.shield), crit: result.crit, block: result.block, dot: false, label });
    if (dealt > 0 && setCount(actor, "烈焰") >= 3 && target.alive) {
      applySetBurn(state, target, actor);
      const activeBurns = target.dots.filter((dot: Data) => dot.dotType === "set_burn").length;
      if (activeBurns >= 3 && hasSetAffix(actor, "【烈焰】引爆") && !target.setBurnDetonated) {
        target.setBurnDetonated = true;
        for (const burnTarget of opponents(state, actor)) if (burnTarget.alive) applyFinalDamage(state, burnTarget, actor.attack * .8, { owner: actor });
      }
      if (hasSetAffix(actor, "【烈焰】燎原") && burnCount + 1 >= 3) {
        target.setBurnSpreadSource = actor;
        if (n(target.setBurnSpreadTimer, 0) <= 0) {
          target.setBurnSpreadTimer = 3;
          spreadSetBurn(state, target, actor);
        }
      }
    }
    if (dealt > 0 && setCount(actor, "冰霜") >= 3 && target.alive && random() < (target.isBoss ? .075 : .15)) {
      const duration = hasSetAffix(actor, "【冰霜】极寒") ? 2 : 1.5;
      target.controls.freeze = duration;
      state.events.push({ type: "status", target: actorRef(target), status: "冻结", duration });
      if (hasSetAffix(actor, "【冰霜】蔓延")) {
        const spread = opponents(state, actor).find((candidate) => candidate !== target && candidate.alive);
        if (spread) { spread.controls.freeze = duration; state.events.push({ type: "status", target: actorRef(spread), status: "冻结", duration }); }
      }
      if (setCount(actor, "冰霜") >= 4) {
        const stacks = Math.min(5, n(actor.frostShieldStacks) + 1);
        actor.frostShieldStacks = stacks;
        const perStack = actor.maxHp * (hasSetAffix(actor, "【冰霜】护盾") ? .16 : .08);
        const previousFrostShield = n(actor.frostShieldAmount);
        const nextFrostShield = Math.min(actor.maxHp * stacks * (hasSetAffix(actor, "【冰霜】护盾") ? .16 : .08), previousFrostShield + perStack);
        actor.frostShieldAmount = nextFrostShield;
        actor.shield += nextFrostShield - previousFrostShield;
      }
    }
    if (result.crit && setCount(actor, "雷霆") >= 3) {
      triggerChainLightning(state, actor, target);
      if (setCount(actor, "雷霆") >= 4 && actor.buffs.thunder_frenzy) triggerChainLightning(state, actor, target);
    }
    if (result.block && hasSetAffix(target, "【铁壁】反击") && actor.alive) {
      const counter = applyFinalDamage(state, actor, target.attack * .3, { owner: target });
      state.events.push({ type: "damage", source: actorRef(target), target: actorRef(actor), amount: Math.round(counter), hp: Math.round(actor.currentHp), max_hp: actor.maxHp, shield: Math.round(actor.shield), crit: false, block: false, dot: false, label: "铁壁反击" });
    }
    if (result.block && setCount(target, "铁壁") >= 4) {
      target.setBlockCount = n(target.setBlockCount) + 1;
      if (target.setBlockCount % 3 === 0) {
        const reflectRaw = target.currentHp * (hasSetAffix(target, "【铁壁】坚壁") ? .6 : .5);
        const reflect = defenseDamage(target, actor, reflectRaw, 0);
        const reflected = applyFinalDamage(state, actor, reflect, { owner: target });
        state.events.push({ type: "damage", source: actorRef(target), target: actorRef(actor), amount: Math.round(reflected), hp: Math.round(actor.currentHp), max_hp: actor.maxHp, shield: Math.round(actor.shield), crit: false, block: false, dot: false, label: "铁壁·生命反伤" });
        target.shield += target.maxHp * .15;
      }
    }
    if (dealt > 0 && setCount(target, "龙鳞") >= 3 && random() < .2) applyFinalDamage(state, actor, dealt * (hasSetAffix(target, "【龙鳞】再生") ? .4 : .3), { owner: target });
    if (dealt > 0 && setCount(target, "龙鳞") >= 4) {
      target.dragonHits = n(target.dragonHits) + 1;
      if (target.dragonHits % 5 === 0) {
        target.buffs.dragon_guard = 4;
        for (const foe of opponents(state, target)) if (foe.alive) applyFinalDamage(state, foe, target.attack * (hasSetAffix(target, "【龙鳞】龙威") ? 2.6 : 2), { owner: target });
      }
    }
    if (!target.alive) handleSetKill(state, actor);
    if (dealt > 0 && hasPassive(target, "荆棘") && actor.alive) applyFinalDamage(state, actor, dealt * .15, {});
    if (dealt > 0 && isBasic && hasPassive(actor, "毒素") && target.alive) applyPassivePoison(state, target, actor);
  }
}

function executeBasic(state: Data, actor: Data, random: RandomSource): void {
  const targets = selectTargets(state, actor, TargetTag.FRONT_LINE);
  if (targets.length === 0) return;
  state.events.push(castEvent(actor, targets, 0, "普攻", "basic"));
  applyAttack(state, actor, targets[0]!, 100, undefined, "普攻", true, random);
}

function executeSkill(state: Data, actor: Data, skillId: number, random: RandomSource): void {
  const original = battleSkillById(skillId);
  if (!original) { executeBasic(state, actor, random); return; }
  const skill = structuredClone(original);
  const hadShadowStrike = Boolean(actor.buffs.shadow_strike);
  if (skillId === 12) {
    const count = Math.min(n(actor.endlessStrikeCount) + 1, n(skill.bonus?.maxStacks, 10));
    skill.damagePct = n(skill.damagePct) + (count - 1) * n(skill.bonus?.stackStepPct, 10);
    actor.endlessStrikeCount = count;
  }
  const targets = selectTargets(state, actor, skill.target, skill);
  state.events.push(castEvent(actor, targets, skill.id, skill.name, skillVisual(skill)));
  if (skill.shieldPct !== undefined) applyShield(state, actor, skill);
  if (skill.healPct !== undefined && [TargetTag.SELF, TargetTag.SELF_HEAL].includes(skill.target as 10 | 11)) {
    const basis = skill.healStat === "maxHpPct" ? actor.maxHp : actor.attack;
    applyHeal(state, actor, basis * skill.healPct / 100, skill.name);
  }
  if (skillId === 25 && n(skill.bonus?.tickCount, 5) > 1) actor.hots.push({ healPct: skill.healPct, ticksRemaining: n(skill.bonus?.tickCount, 5) - 1, tickInterval: n(skill.bonus?.tickInterval, 1), tickTimer: n(skill.bonus?.tickInterval, 1) });
  if (skill.buffEffect && n(skill.buffDuration) > 0) actor.buffs[skill.buffEffect] = skill.buffDuration;
  if (skillId === 26) actor.undyingUsed = true;
  if (n(skill.bonus?.pierceBackDamage) > 0 && targets.length > 0) {
    applyAttack(state, actor, targets[0]!, n(skill.damagePct), skill, skill.name, false, random);
    if (targets[1]?.alive) {
      const back = structuredClone(skill);
      const execute = skill.bonus?.pierceBackExecute as Data | undefined;
      back.damagePct = execute && targets[1].currentHp / targets[1].maxHp < n(execute.threshold)
        ? n(execute.multiplier, n(skill.bonus?.pierceBackDamage))
        : n(skill.bonus?.pierceBackDamage);
      if (n(skill.bonus?.pierceBackSlow) > 0) { back.control = ControlType.SLOW; back.controlDuration = n(skill.bonus?.pierceBackSlow); }
      applyAttack(state, actor, targets[1], n(back.damagePct), back, `${skill.name}(贯穿)`, false, random);
    }
    if (skill.control !== undefined) applyControl(state, targets[0]!, skill);
  } else {
    for (const target of targets) {
      if (!target.alive) continue;
      if (skill.damagePct !== undefined) applyAttack(state, actor, target, skill.damagePct, skill, skill.name, false, random);
      if (skill.control !== undefined) applyControl(state, target, skill);
    }
  }
  for (const target of targets) {
    if (!target.alive) continue;
    if (skill.dotPct !== undefined) applyDot(state, target, actor, skill);
    if (skillId === 31) {
      const total = target.dots.reduce((sum: number, dot: Data) => sum + dot.damage * dot.ticksRemaining, 0);
      const dealt = applyFinalDamage(state, target, total * n(skill.bonus?.detonateDot, 1.5), { owner: actor });
      if (dealt > 0) state.events.push({ type: "damage", source: actorRef(actor), target: actorRef(target), amount: Math.round(dealt), hp: Math.round(target.currentHp), max_hp: target.maxHp, shield: Math.round(target.shield), crit: false, block: false, dot: false, label: "剧毒爆发" });
    }
    if (skillId === 32) for (const enemy of state.actors.enemies) if (enemy !== target && enemy.alive) enemy.dots.push(...target.dots.map((dot: Data) => structuredClone(dot)).slice(0, Math.max(0, 10 - enemy.dots.length)));
  }
  const reduction = Math.min(Math.max(0, n(actor.cooldownReduction)) / 100, .5);
  actor.cooldowns[skillId] = Math.max(1, skill.actionCd * (1 - reduction) * (actor.controls.paralysis ? 1.3 : 1));
  const resetChance = .25 + (hasSetAffix(actor, "【星辰】专注") ? .1 : 0);
  if (setCount(actor, "星辰") >= 3 && random() < resetChance) {
    actor.cooldowns[skillId] = 0;
    actor.starEnergy = n(actor.starEnergy) + (hasSetAffix(actor, "【星辰】流转") ? 2 : 1);
    const required = hasSetAffix(actor, "【星辰】涌动") ? 4 : 5;
    if (setCount(actor, "星辰") >= 4 && actor.starEnergy >= required) {
      actor.starEnergy = 0;
      for (const enemy of opponents(state, actor)) if (enemy.alive) {
        const dealt = applyFinalDamage(state, enemy, actor.attack * (hasSetAffix(actor, "【星辰】辉光") ? 6 : 4), { owner: actor });
        state.events.push({ type: "damage", source: actorRef(actor), target: actorRef(enemy), amount: Math.round(dealt), hp: Math.round(enemy.currentHp), max_hp: enemy.maxHp, shield: Math.round(enemy.shield), crit: false, block: false, dot: false, label: "星辰坠落" });
      }
      for (const id of Object.keys(actor.cooldowns)) actor.cooldowns[id] = 0;
    }
  }
  if (hadShadowStrike) delete actor.buffs.shadow_strike;
}

function processTurn(state: Data, key: string, random: RandomSource): void {
  const actor = resolveActor(state, key);
  if (!actor?.alive) return;
  if (actor.controls.freeze || actor.controls.stun) {
    // A controlled turn is skipped, but it is not a real action: cooldowns,
    // set action counters and extra-action effects must not advance.
    actor.timeToAct = Math.max(n(actor.controls.freeze), n(actor.controls.stun), .01);
    return;
  }
  for (const skillId of Object.keys(actor.cooldowns)) actor.cooldowns[skillId] = Math.max(0, n(actor.cooldowns[skillId]) - 1);
  const action = chooseAction(actor);
  if (action.type === "skill") executeSkill(state, actor, action.skillId, random); else executeBasic(state, actor, random);
  resetAfterTurn(actor, random);
}

function applyPassiveStart(actor: Data): void {
  if (hasPassive(actor, "铁壁")) { actor.defense *= 1.3; actor.baseDefense = actor.defense; }
  if (hasPassive(actor, "迅捷")) { actor.actionCooldown = Math.max(.5, actor.actionCooldown - .3); actor.timeToAct = actor.actionCooldown; }
  if (hasPassive(actor, "护盾")) { actor.shield = actor.maxHp * .2; actor.shieldTime = SHIELD_DURATION; }
}

function applyPassivePoison(state: Data, target: Data, actor: Data): void {
  const name = `${actor.name}·毒素`;
  const current = target.dots.find((dot: Data) => dot.sourceName === name);
  const entry = { sourceName: name, damage: actor.attack * .15, ticksRemaining: 5, tickInterval: 1, tickTimer: 1, dotType: "poison", sourceSide: actor.side };
  if (current) Object.assign(current, entry); else { if (target.dots.length >= 10) target.dots.shift(); target.dots.push(entry); }
  const dot = current ?? entry;
  tickDot(state, target, dot);
  dot.ticksRemaining -= 1;
}

function applyBossStartEffects(player: Data, enemies: Data[]): void {
  for (const boss of enemies) {
    if (boss.bossMechanic.id === "command") for (const ally of enemies) if (ally.row === "back" && !ally.isBoss) { ally.attack *= n(boss.bossMechanic.backAttackMultiplier, 1.3); ally.baseAttack = ally.attack; }
    if (boss.bossMechanic.id === "vampire") boss.lifesteal = n(boss.bossMechanic.lifesteal, 20);
    if (boss.bossMechanic.id === "storm_field") { player.actionCooldown += n(boss.bossMechanic.playerCooldownAdd, .6); player.timeToAct = player.actionCooldown; }
  }
}

function mechanicVisual(id: string): string {
  if (["web", "charm"].includes(id)) return "control";
  if (id === "poison_aura") return "poison";
  if (id === "earthquake") return "thunder";
  if (id === "dragon_breath") return "fire";
  if (["nature_guard", "life_seed"].includes(id)) return "heal";
  return "control";
}

function emitMechanic(state: Data, boss: Data, label: string, statusTarget: Data | null = boss, targets: Data[] = []): void {
  const mechanicId = String(boss.bossMechanic?.id ?? "");
  state.events.push({ type: "cast", source: actorRef(boss), targets: targets.map(actorRef), skill_id: 0, label, visual: mechanicVisual(mechanicId), mechanic: mechanicId });
  if (statusTarget) state.events.push({ type: "status", target: actorRef(statusTarget), status: label, duration: 0, mechanic: mechanicId });
  state.log.push(`${boss.name} 触发 ${label}`);
}

function summon(state: Data, boss: Data, name: string, hpMultiplier: number, maximum: number, ignoreBossAlive = false): void {
  if ((!ignoreBossAlive && !boss.alive) || boss.summonCount >= maximum || state.actors.enemies.filter((enemy: Data) => enemy.alive).length >= 6) return;
  const id = state.actors.enemies.reduce((value: number, enemy: Data) => Math.max(value, enemy.id + 1), 1);
  const maxHp = Math.max(1, Math.round(boss.maxHp * Math.max(hpMultiplier, .01)));
  const summonSkillId = MONSTERS[name]?.skillId ?? 0;
  state.actors.enemies.push({ side: "enemy", id, name, displayName: name, row: "front", level: boss.level, maxHp, currentHp: maxHp, attack: boss.baseAttack * .45, baseAttack: boss.baseAttack * .45, defense: boss.baseDefense * .6, baseDefense: boss.baseDefense * .6, speedPoints: 20, actionCooldown: actionCooldown(20), timeToAct: actionCooldown(20), crit: 0, critDamage: 150, hit: 100, dodge: 0, block: 0, skillDamage: 0, cooldownReduction: 0, lifesteal: 0, freeAttackPct: 0, freeDefensePct: 0, incomingDamageMultiplier: 1, skillIds: [], passives: [], shield: 0, shieldTime: 0, buffs: {}, controls: {}, dots: [], hots: [], cooldowns: {}, alive: true, isBoss: false, isElite: false, infiniteHp: false, regenTimer: REGEN_INTERVAL, setCounts: {}, setAffixes: [], setActionCount: 0, battleDamageMultiplier: 1 });
  state.actors.enemies.at(-1)!.skillIds = summonSkillId > 0 ? [summonSkillId] : [];
  state.events.push({ type: "summon", source: actorRef(boss), unit: { side: "enemy", id, name, display_name: name, row: "front", level: boss.level, max_hp: maxHp, current_hp: maxHp, skill_ids: summonSkillId > 0 ? [summonSkillId] : [], asset: summonAsset(name), is_boss: false, is_elite: false } });
  boss.summonCount += 1;
  emitMechanic(state, boss, `${boss.bossMechanic.name ?? "召唤"}·召唤${name}`);
}

function mechanicDamage(state: Data, source: Data, target: Data, amount: number, label: string, absolute = false): void {
  if (!target.alive) return;
  // “绝对伤害” bypasses defense, but it is still final damage and therefore
  // must be absorbed by an active shield before HP, just like Dot and skills.
  const dealt = applyFinalDamage(state, target, absolute ? amount : defenseDamage(source, target, amount, 0), { owner: source });
  state.events.push({ type: "damage", source: actorRef(source), target: actorRef(target), amount: Math.round(dealt), hp: Math.round(target.currentHp), max_hp: target.maxHp, shield: Math.round(target.shield), crit: false, block: false, dot: false, label });
}

function tickBossMechanics(state: Data, delta: number): void {
  const player = state.actors.player;
  for (const boss of [...state.actors.enemies]) {
    if (!boss.alive || !boss.bossMechanic?.id) continue;
    const mechanic = boss.bossMechanic;
    if (mechanic.id === "leadership") {
      const deaths = state.actors.enemies.filter((ally: Data) => ally !== boss && !ally.alive).length;
      if (deaths > boss.trackedAllyDeaths) { boss.attack *= (1 + n(mechanic.attackPerDeath, .15)) ** (deaths - boss.trackedAllyDeaths); boss.trackedAllyDeaths = deaths; emitMechanic(state, boss, "统率·攻击提升"); }
    }
    if (mechanic.id === "shadow_ritual" && !boss.ritualTriggered && !state.actors.enemies.some((ally: Data) => ally !== boss && ally.alive)) { boss.attack *= n(mechanic.attackMultiplier, 2); boss.ritualTriggered = true; emitMechanic(state, boss, "暗影仪式·攻击翻倍"); }
    if (n(mechanic.interval) <= 0) continue;
    boss.mechanicTimer -= delta;
    while (boss.mechanicTimer <= 0 && boss.alive) {
      boss.mechanicTimer += mechanic.interval;
      if (["web", "charm"].includes(mechanic.id)) {
        const immune = Boolean(player.buffs.tenacity);
        if (!immune) player.controls.stun = n(mechanic.stun, 3);
        emitMechanic(state, boss, String(mechanic.name), immune ? null : player, [player]);
      }
      else if (mechanic.id === "nature_guard") {
        const livingAllies = state.actors.enemies.filter((ally: Data) => ally.alive);
        emitMechanic(state, boss, String(mechanic.name), boss, livingAllies);
        for (const ally of livingAllies) applyHeal(state, ally, ally.maxHp * n(mechanic.healPct, 15) / 100, "自然守护");
      }
      else if (mechanic.id === "death_summon" && boss.currentHp / boss.maxHp < n(mechanic.threshold, .5)) summon(state, boss, "骷髅·战士", 1, n(mechanic.maxSummons, 3));
      else if (mechanic.id === "shadow_clone") summon(state, boss, "暗影分身", n(mechanic.hpMultiplier, .5), n(mechanic.maxSummons, 2));
      else if (mechanic.id === "poison_aura") { emitMechanic(state, boss, String(mechanic.name), player, [player]); mechanicDamage(state, boss, player, boss.attack * n(mechanic.damagePct, 10) / 100, "剧毒光环"); }
      else if (["earthquake", "dragon_breath"].includes(mechanic.id)) { emitMechanic(state, boss, String(mechanic.name), player, [player]); mechanicDamage(state, boss, player, boss.attack * n(mechanic.damageMultiplier, 1.5), String(mechanic.name)); }
      else if (mechanic.id === "wolf_summon") summon(state, boss, "狼·盗贼", .35, n(mechanic.maxSummons, 4));
      else if (mechanic.id === "chaos_field") {
        const choice = randomInt(0, 2, state.random);
        delete boss.buffs.chaos_attack;
        delete boss.buffs.chaos_defense;
        delete boss.buffs.chaos_speed;
        boss.attack = boss.baseAttack;
        boss.defense = boss.baseDefense;
        boss.actionCooldown = boss.baseActionCooldown;
        if (choice === 0) { boss.attack = boss.baseAttack * n(mechanic.buffMultiplier, 1.5); boss.buffs.chaos_attack = 10; }
        else if (choice === 1) { boss.defense = boss.baseDefense * n(mechanic.buffMultiplier, 1.5); boss.buffs.chaos_defense = 10; }
        else { boss.actionCooldown = boss.baseActionCooldown / n(mechanic.buffMultiplier, 1.5); boss.timeToAct = Math.min(boss.timeToAct, boss.actionCooldown); boss.buffs.chaos_speed = 10; }
        emitMechanic(state, boss, "混沌领域");
      }
    }
  }
}

function handleBossHpTriggers(state: Data, target: Data): void {
  if (!target.isBoss) return;
  const mechanic = target.bossMechanic ?? {};
  const ratio = target.currentHp / target.maxHp;
  if (mechanic.id === "split" && target.mechanicTriggers === 0 && ratio < n(mechanic.threshold, .3)) {
    target.mechanicTriggers = 1;
    const sharedRatio = target.currentHp / n(mechanic.count, 3) / target.maxHp;
    target.alive = false; target.currentHp = 0;
    for (let count = 0; count < n(mechanic.count, 3); count += 1) summon(state, target, "史莱姆·战士", sharedRatio, 3, true);
    emitMechanic(state, target, "分裂");
  } else if (target.alive && ["blood_rage", "shadow_rule"].includes(mechanic.id)) {
    const expected = Math.min(Math.floor((1 - ratio) / n(mechanic.thresholdStep, .3)), n(mechanic.maxSummons, 99));
    while (target.mechanicTriggers < expected) {
      target.mechanicTriggers += 1;
      if (mechanic.id === "blood_rage") { target.timeToAct = 0; emitMechanic(state, target, "嗜血·立即行动"); }
      else { target.attack *= 1 + n(mechanic.attackPerTrigger, .05); summon(state, target, "暗影·盗贼", .35, n(mechanic.maxSummons, 3)); }
    }
  }
}

function applyWeatherStart(actors: Data[], weather: string): void {
  for (const actor of actors) {
    if (weather === "drizzle") { actor.weatherHealMultiplier = 1.3; actor.weatherShieldMultiplier = 1.3; }
    if (weather === "fog") { actor.hit *= .8; actor.dodge *= 1.2; }
    if (weather === "scorching_sun") { actor.weatherHealMultiplier = .6; actor.weatherShieldMultiplier = .6; }
    if (weather === "sandstorm") actor.block *= .5;
    if (weather === "aurora") {
      actor.crit *= 2;
      actor.dodge *= 2;
      actor.luck = Math.max(0, n(actor.luck)) * 1.5;
    }
  }
}

function weatherInterval(weather: string): number {
  if (["thunderstorm", "sandstorm"].includes(weather)) return 5;
  if (weather === "scorching_sun") return 6;
  if (weather === "blizzard") return 8;
  return 0;
}

function tickWeather(state: Data, delta: number): void {
  const interval = weatherInterval(state.weather);
  if (interval <= 0) return;
  state.weatherTimer -= delta;
  while (state.weatherTimer <= 0) {
    state.weatherTimer += interval;
    const living = [state.actors.player, ...state.actors.enemies].filter((actor: Data) => actor.alive);
    if (living.length === 0) return;
    const source = { side: "weather", id: -1, name: "天气" };
    if (state.weather === "thunderstorm") { const target = pick(living, state.random); mechanicDamage(state, source, target, target.maxHp * .1, "天气·落雷", true); }
    if (state.weather === "blizzard") {
      const weights = living.map((actor: Data) => 1 / Math.max(actor.actionCooldown, .01));
      let roll = state.random() * weights.reduce((sum: number, value: number) => sum + value, 0);
      const target = living[weights.findIndex((weight: number) => (roll -= weight) <= 0)] ?? living[0];
      if (!target.bossMechanic?.controlImmune && !target.buffs.tenacity) { target.controls.freeze = target.isBoss ? 1 : 2; state.events.push({ type: "status", target: actorRef(target), status: "天气·冻结", duration: target.controls.freeze }); }
    }
    if (state.weather === "scorching_sun") for (const target of living) mechanicDamage(state, source, target, target.maxHp * .03, "天气·灼烧", true);
    if (state.weather === "sandstorm") for (const target of living) mechanicDamage(state, source, target, target.maxHp * .015, "天气·沙暴", true);
  }
}

function outcome(state: Data): number {
  if (state.battleKind !== "challenge" && !state.actors.player.alive) return BattleOutcome.DEFEAT;
  if (!state.actors.enemies.some((enemy: Data) => enemy.alive || enemy.infiniteHp)) return BattleOutcome.VICTORY;
  return -1;
}

function victoryRewards(encounter: BattleEncounter, player: Data, random: RandomSource): Data {
  const level = encounter.monster_level;
  const goldMultiplier = 1 + player.goldBonus / 100;
  const experienceMultiplier = 1 + player.experienceBonus / 100;
  if (encounter.battle_kind === "battle") {
    const dropChance = Math.min(1, .15 + Math.max(0, n(player.luck)) * .005);
    return { gold_gain: Math.round(level * (8 + random() * 7) * goldMultiplier), exp_gain: Math.round(level * (10 + random() * 8) * experienceMultiplier), drops: random() < dropChance ? [{ kind: "equip" }] : [] };
  }
  if (encounter.battle_kind === "elite") return { gold_gain: Math.round(level * (20 + random() * 15) * goldMultiplier), exp_gain: Math.round(level * (25 + random() * 15) * experienceMultiplier), drops: [{ kind: "equip", quality_floor: 1 }] };
  if (encounter.battle_kind === "boss") return { gold_gain: Math.round(level * 40 * goldMultiplier), exp_gain: Math.round(level * 50 * experienceMultiplier), drops: [{ kind: "boss" }] };
  return { gold_gain: 0, exp_gain: 0, drops: [] };
}

function challengeRewards(damage: number, level: number, player: Data): Data {
  let gold = 0;
  const drops: Data[] = [];
  if (damage >= 5_000) gold += level * 50;
  if (damage >= 15_000) gold += level * 100;
  if (damage >= 30_000) { gold += level * 200; drops.push({ kind: "equip", quality_floor: 1 }); }
  if (damage >= 60_000) { gold += level * 400; drops.push({ kind: "equip", quality_floor: 2 }); }
  if (damage >= 100_000) { gold += level * 800; drops.push({ kind: "equip", quality_floor: 3 }); }
  gold = Math.round(gold * (1 + n(player.goldBonus) / 100));
  return { gold_gain: gold, drops };
}

function buildResult(state: Data, encounter: BattleEncounter, random: RandomSource): BattleResult {
  const player = state.actors.player;
  const result: BattleResult = {
    outcome: state.outcome, player_hp: Math.round(player.currentHp), player_start_hp: state.playerStartHp, player_max_hp: Math.round(player.maxHp), player_alive: b(player.alive),
    damage_total: Math.round(state.damageTotal), elapsed: state.elapsed, rounds: state.rounds, log: [...state.log], events: structuredClone(state.events),
    battle_kind: encounter.battle_kind, monster_level: encounter.monster_level, template_id: encounter.template_id, template_name: encounter.template_name,
    gold_gain: 0, exp_gain: 0, drops: [], revive_used: false, force_home: false, gold_penalty: 0, boss_cleared: false, luxury_gold_spent: 0,
  };
  result.luxury_gold_spent = Math.floor(n(state.actors.player.luxuryGoldSpent));
  if (encounter.battle_kind === "challenge" && result.outcome === BattleOutcome.CHALLENGE_DONE) Object.assign(result, challengeRewards(result.damage_total, player.level, player));
  else if (result.outcome === BattleOutcome.VICTORY) { Object.assign(result, victoryRewards(encounter, player, random)); result.boss_cleared = encounter.battle_kind === "boss"; }
  return result;
}

export function runBattle(player: BattlePlayerState, encounter: BattleEncounter, random: RandomSource = Math.random): BattleResult {
  const state = buildInitialState(player, encounter);
  state.random = random;
  while (true) {
    if (state.battleKind === "challenge" && state.elapsed >= encounter.duration_limit) { state.outcome = BattleOutcome.CHALLENGE_DONE; break; }
    if (state.rounds >= MAX_ROUNDS) { state.outcome = BattleOutcome.DRAW; break; }
    const key = pickNextActor(state);
    const actor = resolveActor(state, key);
    if (!actor) { state.outcome = BattleOutcome.DRAW; break; }
    advanceTime(state, n(actor.timeToAct));
    if (state.battleKind === "challenge" && state.elapsed >= encounter.duration_limit) { state.outcome = BattleOutcome.CHALLENGE_DONE; break; }
    state.rounds += 1;
    processTurn(state, key, random);
    const current = outcome(state);
    if (current !== -1) { state.outcome = current; break; }
  }
  return buildResult(state, encounter, random);
}
