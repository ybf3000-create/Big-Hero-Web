import {
  BOSS_MECHANICS,
  BOSS_TEMPLATES,
  CHALLENGE_ENCOUNTERS,
  ELITE_ENCOUNTERS,
  ELITE_PASSIVES,
  MONSTERS,
  NORMAL_ENCOUNTERS,
  type BattleKind,
  type EncounterTemplate,
} from "./battle-catalog.js";

export type RandomSource = () => number;

export interface EncounterUnit {
  id: number;
  name: string;
  display_name: string;
  row: "front" | "back";
  level: number;
  max_hp: number;
  current_hp: number;
  atk: number;
  def: number;
  speed_points: number;
  action_cd: number;
  crit: number;
  critdmg: number;
  hit: number;
  dodge: number;
  block: number;
  skill_ids: number[];
  passives: string[];
  is_elite: boolean;
  is_boss: boolean;
  infinite_hp: boolean;
  template_id: string;
  boss_index?: number;
  boss_mechanic?: Record<string, unknown>;
  asset?: string;
  maxHp?: number;
  currentHp?: number;
  attack?: number;
  defense?: number;
  speed?: number;
  bossIndex?: number;
}

export interface BattleEncounter {
  battle_kind: BattleKind;
  monster_level: number;
  template_id: string;
  template_name: string;
  units: EncounterUnit[];
  formation: { front: number[]; back: number[] };
  duration_limit: number;
  weather: string;
}

const randomInt = (minimum: number, maximum: number, random: RandomSource): number => minimum + Math.floor(random() * (maximum - minimum + 1));
const pick = <T>(values: readonly T[], random: RandomSource): T => values[Math.min(values.length - 1, Math.floor(random() * values.length))]!;

export function speedToCooldown(speedPoints: number): number {
  return 3 * (1 - Math.min(speedPoints * .008, .5));
}

export function areaMinimumLevel(tier: number): number {
  if (tier <= 3) return 1;
  if (tier <= 7) return 6;
  if (tier <= 11) return 13;
  if (tier <= 15) return 21;
  if (tier <= 20) return 31;
  if (tier <= 30) return 46;
  if (tier <= 40) return 71;
  if (tier <= 50) return 101;
  if (tier <= 65) return 141;
  if (tier <= 80) return 201;
  return 281;
}

export function eliteDodgeBlock(tier: number): number {
  return tier <= 7 ? 0 : Math.min(5 + tier * .35, 33);
}

export function bossDodgeBlock(tier: number): number {
  return 10 + Math.min(tier * .5, 25);
}

function rollNormalLevel(playerLevel: number, tier: number, random: RandomSource): number {
  return Math.max(areaMinimumLevel(tier), playerLevel - 3) + randomInt(0, 2, random);
}

function rollEliteLevel(playerLevel: number, tier: number, random: RandomSource): number {
  return Math.max(areaMinimumLevel(tier), playerLevel - 1) + randomInt(0, 1, random);
}

function rollPassives(count: number, random: RandomSource): string[] {
  const pool = [...ELITE_PASSIVES];
  const result: string[] = [];
  while (count > 0 && pool.length > 0) {
    result.push(pool.splice(Math.floor(random() * pool.length), 1)[0]!);
    count -= 1;
  }
  return result;
}

function buildUnit(rawName: string, id: number, row: "front" | "back", level: number, tier: number, kind: BattleKind, infiniteHp: boolean, encounter: EncounterTemplate, random: RandomSource): EncounterUnit | null {
  const isElite = rawName.startsWith("⚔");
  const name = isElite ? rawName.slice(1) : rawName;
  const definition = MONSTERS[name];
  if (!definition) return null;
  const levelScale = 1 + (level - 1) * .15;
  const tierScale = 1 + tier * .02;
  let hp = Math.round(300 * levelScale * tierScale * definition.hpMultiplier * (isElite ? 3 : 1));
  let attack = Math.round(30 * levelScale * tierScale * definition.attackMultiplier * (isElite ? 1.8 : 1));
  let defense = Math.round(20 * levelScale * tierScale * definition.defenseMultiplier);
  if (kind === "battle" && tier === 0 && level <= 3) {
    hp = Math.round(hp * .45);
    attack = Math.round(attack * .55);
    defense = Math.round(defense * .35);
  }
  if (infiniteHp) hp = 99_999_999;
  const avoid = isElite ? eliteDodgeBlock(tier) : 0;
  return {
    id,
    name,
    display_name: rawName,
    row,
    level,
    max_hp: Math.max(1, hp),
    current_hp: Math.max(1, hp),
    atk: Math.max(1, attack),
    def: Math.max(0, defense),
    speed_points: definition.speedPoints,
    action_cd: speedToCooldown(definition.speedPoints),
    crit: 0,
    critdmg: 150,
    hit: 100,
    dodge: avoid,
    block: avoid,
    skill_ids: [definition.skillId],
    passives: isElite ? rollPassives(encounter.eliteBonusCount ?? 1, random) : [],
    is_elite: isElite,
    is_boss: false,
    infinite_hp: infiniteHp,
    template_id: encounter.id,
    asset: isElite ? "char_0007.png" : "char_0001.png",
    maxHp: Math.max(1, hp), currentHp: Math.max(1, hp), attack: Math.max(1, attack), defense: Math.max(0, defense), speed: definition.speedPoints,
  };
}

function buildFromTemplate(template: EncounterTemplate, kind: BattleKind, level: number, tier: number, infiniteHp: boolean, random: RandomSource): BattleEncounter {
  const units: EncounterUnit[] = [];
  const front: number[] = [];
  const back: number[] = [];
  for (const [row, names] of [["front", template.front], ["back", template.back]] as const) {
    for (const name of names) {
      const unit = buildUnit(name, units.length + 1, row, level, tier, kind, infiniteHp, template, random);
      if (!unit) continue;
      units.push(unit);
      (row === "front" ? front : back).push(unit.id);
    }
  }
  return {
    battle_kind: kind,
    monster_level: level,
    template_id: template.id,
    template_name: template.name,
    units,
    formation: { front, back },
    duration_limit: kind === "challenge" ? 60 : 0,
    weather: "sunny",
  };
}

function buildBossUnit(id: number, name: string, level: number, tier: number, bossIndex: number): EncounterUnit {
  const baseHp = 500 + (level - 1) * 80;
  const baseAttack = 25 + (level - 1) * 2;
  const baseDefense = 15 + (level - 1);
  const canonicalMechanicIndex = Math.min(20, Math.max(1, bossIndex));
  const speedPoints = bossIndex <= 15 ? 15 : bossIndex <= 50 ? 25 : 35;
  return {
    id,
    name,
    display_name: name,
    row: "front",
    level,
    max_hp: Math.round(baseHp * (8 + bossIndex * .15)),
    current_hp: Math.round(baseHp * (8 + bossIndex * .15)),
    atk: Math.round(baseAttack * (1.5 + bossIndex * .003)),
    def: Math.round(baseDefense * (1.5 + bossIndex * .005)),
    speed_points: speedPoints,
    action_cd: speedToCooldown(speedPoints),
    crit: 0,
    critdmg: 150,
    hit: 100,
    dodge: bossDodgeBlock(tier),
    block: bossDodgeBlock(tier),
    skill_ids: [],
    passives: [],
    is_elite: false,
    is_boss: true,
    infinite_hp: false,
    template_id: `Boss${bossIndex}`,
    boss_index: bossIndex,
    boss_mechanic: structuredClone(BOSS_MECHANICS[canonicalMechanicIndex - 1] ?? {}),
    asset: `${name}.png`, maxHp: Math.round(baseHp * (8 + bossIndex * .15)), currentHp: Math.round(baseHp * (8 + bossIndex * .15)),
    attack: Math.round(baseAttack * (1.5 + bossIndex * .003)), defense: Math.round(baseDefense * (1.5 + bossIndex * .005)), speed: speedPoints, bossIndex,
  };
}

function buildBossEncounter(playerLevel: number, tier: number, bossIndex: number, weather: string, random: RandomSource): BattleEncounter {
  const templateIndex = Math.min(20, Math.max(1, bossIndex)) - 1;
  const template = BOSS_TEMPLATES[templateIndex] ?? BOSS_TEMPLATES[19]!;
  const bossLevel = playerLevel + 2;
  const units: EncounterUnit[] = [];
  const front: number[] = [];
  const back: number[] = [];
  const encounterTemplate: EncounterTemplate = { id: `Boss${bossIndex}`, name: template.name, front: template.front, back: template.back };
  for (const [row, names] of [["front", template.front], ["back", template.back]] as const) {
    for (const name of names) {
      const id = units.length + 1;
      const unit = name === "Boss"
        ? buildBossUnit(id, template.name, bossLevel, tier, bossIndex)
        : buildUnit(name, id, row, rollEliteLevel(playerLevel, tier, random), tier, "boss", false, encounterTemplate, random);
      if (!unit) continue;
      units.push(unit);
      (row === "front" ? front : back).push(unit.id);
    }
  }
  return { battle_kind: "boss", monster_level: bossLevel, template_id: `Boss${bossIndex}`, template_name: template.name, units, formation: { front, back }, duration_limit: 0, weather };
}

export function generateEncounter(kind: BattleKind, playerLevel: number, bossTier: number, bossIndex: number, weather: string, random: RandomSource = Math.random): BattleEncounter {
  if (kind === "boss") return buildBossEncounter(playerLevel, bossTier, Math.min(200, Math.max(1, bossIndex)), weather, random);
  const source = kind === "battle" ? NORMAL_ENCOUNTERS : kind === "elite" ? ELITE_ENCOUNTERS : CHALLENGE_ENCOUNTERS;
  const pool = source.filter((entry) => bossTier >= (entry.minimumTier ?? 0));
  const selected = pick(pool.length > 0 ? pool : source, random);
  const level = kind === "battle" ? rollNormalLevel(playerLevel, bossTier, random) : rollEliteLevel(playerLevel, bossTier, random);
  const encounter = buildFromTemplate(selected, kind, level, bossTier, kind === "challenge", random);
  encounter.weather = weather;
  return encounter;
}
