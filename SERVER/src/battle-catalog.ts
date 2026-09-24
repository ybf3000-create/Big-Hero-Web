export type BattleKind = "battle" | "elite" | "boss" | "challenge";

export interface BattleSkill {
  id: number;
  name: string;
  icon: string;
  target: number;
  actionCd: number;
  damagePct?: number;
  hits?: number;
  control?: number;
  controlDuration?: number;
  shieldPct?: number;
  shieldStat?: "attack" | "defense" | "maxHpPct";
  healPct?: number;
  healStat?: "attack" | "maxHpPct";
  buffEffect?: string;
  buffDuration?: number;
  dotPct?: number;
  dotTickInterval?: number;
  dotTickCount?: number;
  dotType?: string;
  dotMode?: number;
  bonus?: Record<string, unknown>;
}

export const TargetTag = {
  FRONT_LINE: 0,
  BACK_LINE: 1,
  LOWEST_HP: 2,
  LOWEST_HP_PCT: 3,
  HIGHEST_ATK: 4,
  HIGHEST_DEF: 5,
  AOE_FRONT: 6,
  AOE_ALL: 7,
  AOE_BACK: 8,
  PIERCE: 9,
  SELF: 10,
  SELF_HEAL: 11,
} as const;

export const ControlType = {
  NONE: 0,
  FREEZE: 1,
  STUN: 2,
  SILENCE: 3,
  PARALYSIS: 4,
  SLOW: 5,
  ANTI_HEAL: 6,
} as const;

export const BATTLE_SKILLS: BattleSkill[] = [
  { id: 1, name: "重击", icon: "⚔", target: 0, actionCd: 4, damagePct: 150, hits: 1 },
  { id: 2, name: "猛力一击", icon: "💥", target: 0, actionCd: 6, damagePct: 250, hits: 1 },
  { id: 3, name: "蓄力斩", icon: "⚡", target: 0, actionCd: 8, damagePct: 400, hits: 1 },
  { id: 4, name: "碎裂打击", icon: "🪨", target: 5, actionCd: 6, damagePct: 180, hits: 1, bonus: { ignoreDefPct: 20 } },
  { id: 5, name: "致命一击", icon: "🗡", target: 2, actionCd: 9, damagePct: 500, hits: 1, bonus: { executeThreshold: 0.3, executeMultiplier: 2 } },
  { id: 6, name: "终结技", icon: "🎯", target: 3, actionCd: 10, damagePct: 300, hits: 1, bonus: { missingHpScale: 1 } },
  { id: 7, name: "快速打击", icon: "⚡", target: 0, actionCd: 4, damagePct: 110, hits: 1, bonus: { ignoreDefPct: 10 } },
  { id: 8, name: "连击", icon: "💥", target: 0, actionCd: 5, damagePct: 55, hits: 2 },
  { id: 9, name: "旋风斩", icon: "🌀", target: 7, actionCd: 7, damagePct: 90, hits: 1 },
  { id: 10, name: "连射", icon: "🏹", target: 0, actionCd: 7, damagePct: 40, hits: 3 },
  { id: 11, name: "回旋镖", icon: "🪃", target: 7, actionCd: 7, damagePct: 110, hits: 1, bonus: { maxTargets: 2 } },
  { id: 12, name: "无尽打击", icon: "♾", target: 0, actionCd: 8, damagePct: 90, hits: 1, bonus: { stackStepPct: 10, maxStacks: 10 } },
  { id: 13, name: "冰冻射击", icon: "❄", target: 0, actionCd: 6, damagePct: 100, hits: 1, control: 1, controlDuration: 4 },
  { id: 14, name: "冰霜新星", icon: "🧊", target: 7, actionCd: 8, damagePct: 80, hits: 1, control: 5, controlDuration: 6 },
  { id: 15, name: "眩晕锤", icon: "🔨", target: 0, actionCd: 7, damagePct: 120, hits: 1, control: 2, controlDuration: 4 },
  { id: 16, name: "雷霆一击", icon: "⚡", target: 0, actionCd: 7, damagePct: 130, hits: 1, control: 4, controlDuration: 6 },
  { id: 17, name: "静默领域", icon: "🔇", target: 7, actionCd: 8, damagePct: 60, hits: 1, control: 3, controlDuration: 5 },
  { id: 18, name: "深度冻结", icon: "❄️", target: 0, actionCd: 9, damagePct: 200, hits: 1, control: 1, controlDuration: 6 },
  { id: 19, name: "腐蚀之触", icon: "💀", target: 4, actionCd: 8, damagePct: 100, hits: 1, control: 6, controlDuration: 8 },
  { id: 20, name: "时间凝滞", icon: "⏳", target: 7, actionCd: 10, damagePct: 50, hits: 1, control: 4, controlDuration: 6 },
  { id: 21, name: "护盾", icon: "🛡", target: 10, actionCd: 6, shieldPct: 300, shieldStat: "defense" },
  { id: 22, name: "治疗波", icon: "💚", target: 11, actionCd: 6, healPct: 150, healStat: "attack" },
  { id: 23, name: "铁壁姿态", icon: "🏰", target: 10, actionCd: 7, buffEffect: "def_x2", buffDuration: 4 },
  { id: 24, name: "坚毅", icon: "💪", target: 10, actionCd: 7, buffEffect: "tenacity", buffDuration: 4 },
  { id: 25, name: "生命绽放", icon: "🌿", target: 11, actionCd: 8, healPct: 5, healStat: "maxHpPct", bonus: { tickInterval: 1, tickCount: 5 } },
  { id: 26, name: "不屈意志", icon: "❤️‍🔥", target: 10, actionCd: 8, buffEffect: "undying", buffDuration: 4, bonus: { triggerHpPct: 0.2 } },
  { id: 27, name: "毒刃", icon: "🗡", target: 0, actionCd: 5, damagePct: 80, hits: 1, dotPct: 30, dotTickInterval: 2, dotTickCount: 4, dotType: "poison", dotMode: 0 },
  { id: 28, name: "烈焰灼烧", icon: "🔥", target: 7, actionCd: 7, damagePct: 60, hits: 1, dotPct: 30, dotTickInterval: 2, dotTickCount: 4, dotType: "burn", dotMode: 0 },
  { id: 29, name: "撕裂", icon: "🩸", target: 0, actionCd: 5, damagePct: 120, hits: 1, dotPct: 20, dotTickInterval: 2, dotTickCount: 3, dotType: "bleed", dotMode: 0 },
  { id: 30, name: "毒雾", icon: "☁️", target: 7, actionCd: 8, damagePct: 40, hits: 1, dotPct: 35, dotTickInterval: 2, dotTickCount: 5, dotType: "poison", dotMode: 0 },
  { id: 31, name: "剧毒爆发", icon: "💚", target: 0, actionCd: 9, bonus: { detonateDot: 1.5 } },
  { id: 32, name: "瘟疫传播", icon: "🦠", target: 7, actionCd: 10, bonus: { spreadDot: true } },
  { id: 33, name: "穿刺射击", icon: "🏹", target: 9, actionCd: 6, damagePct: 120, hits: 1, bonus: { pierceBackDamage: 80 } },
  { id: 34, name: "裂地斩", icon: "🌍", target: 9, actionCd: 8, damagePct: 180, hits: 1, bonus: { pierceBackDamage: 120, pierceBackSlow: 8 } },
  { id: 35, name: "穿透箭雨", icon: "🌧", target: 9, actionCd: 7, damagePct: 90, hits: 1, bonus: { pierceBackDamage: 90 } },
  { id: 36, name: "暗影突袭", icon: "🌑", target: 9, actionCd: 9, damagePct: 150, hits: 1, bonus: { pierceBackDamage: 100, pierceBackExecute: { threshold: 0.3, multiplier: 1.5 } } },
];

export const MELEE_SKILL_IDS = new Set([1, 2, 3, 4, 5, 6, 7, 8, 9, 12, 15, 16, 19, 27, 29, 34, 36]);

export interface MonsterDefinition {
  hpMultiplier: number;
  attackMultiplier: number;
  defenseMultiplier: number;
  speedPoints: number;
  skillId: number;
}

const monster = (hpMultiplier: number, attackMultiplier: number, defenseMultiplier: number, speedPoints: number, skillId: number): MonsterDefinition => ({ hpMultiplier, attackMultiplier, defenseMultiplier, speedPoints, skillId });

export const MONSTERS: Record<string, MonsterDefinition> = {
  "史莱姆·战士": monster(1.5, .7, 1.2, 5, 21), "史莱姆·射手": monster(.8, 1.4, .6, 25, 10), "史莱姆·法师": monster(.7, 1.6, .5, 8, 28), "史莱姆·盗贼": monster(.6, 1.3, .4, 35, 27),
  "哥布林·战士": monster(1.3, .9, 1.3, 8, 23), "哥布林·射手": monster(.8, 1.5, .5, 25, 10), "哥布林·法师": monster(.7, 1.7, .4, 8, 16), "哥布林·祭祀": monster(1, .6, .8, 8, 22), "哥布林·盗贼": monster(.7, 1.2, .5, 35, 7),
  "骷髅·战士": monster(1.1, 1, 1.1, 15, 8), "骷髅·射手": monster(.7, 1.6, .4, 25, 33), "骷髅·法师": monster(.6, 1.8, .3, 5, 18), "骷髅·祭祀": monster(1, .6, .8, 8, 22),
  "狼·战士": monster(1.2, 1.1, .9, 25, 9), "狼·射手": monster(.9, 1.3, .5, 25, 35), "狼·盗贼": monster(.6, 1.4, .3, 35, 29), "狼·祭祀": monster(1, .7, .7, 15, 25),
  "蝙蝠·战士": monster(1, 1.2, .6, 35, 12), "蝙蝠·射手": monster(.7, 1.4, .4, 25, 11), "蝙蝠·法师": monster(.6, 1.6, .3, 15, 30), "蝙蝠·盗贼": monster(.5, 1.2, .3, 35, 27),
  "蜘蛛·战士": monster(1.4, .8, 1.4, 5, 23), "蜘蛛·射手": monster(.8, 1.5, .5, 25, 27), "蜘蛛·法师": monster(.9, 1.3, .6, 8, 17), "蜘蛛·盗贼": monster(.5, 1.3, .3, 35, 36),
  "树精·战士": monster(1.8, .5, 1.5, 5, 26), "树精·法师": monster(1.1, 1.3, .8, 8, 31), "树精·祭祀": monster(1.3, .4, .8, 5, 25), "树精·射手": monster(1, 1.4, .7, 8, 33),
  "石魔·战士": monster(2, .6, 1.8, 5, 15), "石魔·法师": monster(1.2, 1.5, 1, 8, 14), "石魔·射手": monster(1, 1.3, 1, 15, 34), "石魔·盗贼": monster(.8, 1, .8, 25, 7),
  "鹰身女妖·战士": monster(.9, 1.4, .5, 35, 8), "鹰身女妖·射手": monster(.7, 1.6, .4, 25, 35), "鹰身女妖·法师": monster(.6, 1.7, .3, 15, 16), "鹰身女妖·祭祀": monster(.8, .7, .5, 25, 22),
  "暗影·战士": monster(1, 1.2, .8, 15, 36), "暗影·法师": monster(.7, 1.8, .3, 8, 19), "暗影·盗贼": monster(.5, 1.5, .2, 35, 36), "暗影·祭祀": monster(.9, .8, .6, 15, 24),
};

export interface EncounterTemplate {
  id: string;
  name: string;
  front: string[];
  back: string[];
  minimumTier?: number;
  eliteBonusCount?: number;
}

const template = (id: string, name: string, front: string[], back: string[], minimumTier = 0, eliteBonusCount = 1): EncounterTemplate => ({ id, name, front, back, minimumTier, eliteBonusCount });

export const NORMAL_ENCOUNTERS = [
  template("N-01", "独行肉盾", ["史莱姆·战士"], []), template("N-02", "孤高炮台", ["骷髅·法师"], []), template("N-03", "盾+弓", ["哥布林·战士", "哥布林·射手"], []), template("N-04", "远近夹击", ["狼·战士"], ["狼·射手"]),
  template("N-05", "蝙蝠群", ["蝙蝠·战士", "蝙蝠·盗贼", "蝙蝠·射手"], [], 1), template("N-06", "蛛网防线", ["蜘蛛·战士"], ["蜘蛛·射手", "蜘蛛·法师"], 1), template("N-07", "哥布林小队", ["哥布林·战士", "哥布林·盗贼"], ["哥布林·射手", "哥布林·法师"], 4),
  template("N-08", "亡灵小队", ["骷髅·战士", "骷髅·射手"], ["骷髅·法师", "骷髅·祭祀"], 4), template("N-09", "史莱姆大军", ["史莱姆·战士", "史莱姆·盗贼"], ["史莱姆·射手", "史莱姆·法师", "史莱姆·法师"], 8),
  template("N-10", "石魔军团", ["石魔·战士", "石魔·射手"], ["石魔·法师", "石魔·盗贼", "石魔·射手"], 8), template("N-11", "狼群", ["狼·战士", "狼·盗贼"], ["狼·射手", "狼·射手", "狼·祭祀"], 8), template("N-12", "森林守护", ["树精·战士"], ["树精·射手", "树精·祭祀"], 4),
  template("N-13", "暗影突袭", ["暗影·盗贼", "暗影·战士"], ["暗影·法师", "暗影·祭祀"], 8), template("N-14", "风暴双子", ["鹰身女妖·战士"], ["鹰身女妖·法师"], 8), template("N-15", "混沌联军", ["哥布林·战士", "骷髅·战士"], ["哥布林·射手", "骷髅·法师", "蝙蝠·盗贼"], 8),
];

export const ELITE_ENCOUNTERS = [
  template("E-01", "精英炮台", ["⚔骷髅·法师"], [], 0, 2), template("E-02", "铁壁+炮台", ["⚔石魔·战士"], ["哥布林·法师"]), template("E-03", "双狼精英", ["⚔狼·战士", "⚔狼·盗贼"], []), template("E-04", "精英小队", ["⚔哥布林·战士"], ["⚔哥布林·射手", "哥布林·祭祀"]),
  template("E-05", "暗影精英团", ["⚔暗影·盗贼", "暗影·战士"], ["⚔暗影·法师", "暗影·祭祀"], 4), template("E-06", "风暴精英", ["⚔鹰身女妖·法师"], ["鹰身女妖·祭祀"], 4), template("E-07", "亡灵大军", ["⚔骷髅·战士", "骷髅·射手"], ["⚔骷髅·法师", "骷髅·祭祀", "骷髅·射手"], 4),
  template("E-08", "蛛王禁地", ["⚔蜘蛛·战士"], ["⚔蜘蛛·法师", "⚔蜘蛛·射手"], 4), template("E-09", "荆棘防线", ["⚔树精·战士"], ["⚔树精·射手", "骷髅·法师"], 8), template("E-10", "暗夜突袭", ["⚔蝙蝠·战士", "蝙蝠·盗贼"], ["⚔蝙蝠·法师", "蝙蝠·射手"], 8),
  template("E-11", "晶石阵列", ["⚔石魔·法师"], ["⚔石魔·射手"], 8), template("E-12", "天空霸主", ["⚔鹰身女妖·战士"], ["⚔鹰身女妖·射手", "鹰身女妖·祭祀"], 8), template("E-13", "哥布林部落", ["⚔哥布林·战士", "⚔哥布林·盗贼"], ["哥布林·射手", "⚔哥布林·法师", "哥布林·祭祀"], 16),
  template("E-14", "暗影铁卫", ["⚔暗影·战士"], ["⚔暗影·祭祀"], 16), template("E-15", "蜘蛛巢穴", ["⚔蜘蛛·战士", "蜘蛛·射手"], ["⚔蜘蛛·法师", "蜘蛛·盗贼", "蝙蝠·盗贼"], 16), template("E-16", "古树之怒", ["⚔树精·祭祀", "树精·战士"], ["⚔树精·法师"], 16),
];

export const CHALLENGE_ENCOUNTERS = [
  template("C-01", "木桩阵列", ["⚔石魔·战士"], ["哥布林·射手", "哥布林·法师", "哥布林·祭祀"]),
  template("C-02", "森林试炼", ["⚔树精·战士", "⚔树精·祭祀"], ["骷髅·法师", "骷髅·射手"]),
  template("C-03", "暗影试炼", ["⚔暗影·战士", "暗影·盗贼"], ["⚔暗影·法师", "暗影·祭祀", "蝙蝠·射手"]),
];

export interface BossTemplate { name: string; front: string[]; back: string[] }
export const BOSS_TEMPLATES: BossTemplate[] = [
  { name: "史莱姆王", front: ["Boss"], back: [] }, { name: "野人队长", front: ["Boss"], back: ["哥布林·射手"] }, { name: "骷髅将军", front: ["Boss", "骷髅·战士"], back: ["骷髅·射手"] }, { name: "狼王", front: ["Boss", "狼·战士"], back: [] },
  { name: "史前机兵", front: ["Boss"], back: ["蝙蝠·盗贼", "蝙蝠·射手"] }, { name: "花冠女皇", front: ["Boss"], back: ["蜘蛛·战士", "蜘蛛·射手"] }, { name: "树精长老", front: ["Boss", "树精·战士"], back: ["树精·祭祀"] }, { name: "石魔巨像", front: ["Boss"], back: [] },
  { name: "尸王", front: ["Boss"], back: ["骷髅·战士", "骷髅·法师"] }, { name: "鹰身女王", front: ["Boss", "鹰身女妖·战士"], back: ["鹰身女妖·祭祀"] }, { name: "暗影领主", front: ["Boss", "暗影·盗贼"], back: ["暗影·法师"] }, { name: "虚假帝皇", front: ["Boss", "蜘蛛·法师"], back: ["蜘蛛·战士"] },
  { name: "幻蝶", front: ["Boss"], back: [] }, { name: "异化鲨鲨", front: ["Boss", "石魔·法师"], back: ["石魔·射手"] }, { name: "暗影大祭司", front: ["Boss", "暗影·祭祀"], back: ["暗影·战士", "暗影·盗贼"] }, { name: "狼妄", front: ["Boss", "狼·战士"], back: ["狼·射手", "狼·祭祀"] },
  { name: "骨龙", front: ["Boss", "骷髅·法师"], back: [] }, { name: "绿精", front: ["Boss", "树精·祭祀"], back: ["树精·法师"] }, { name: "混沌魔像", front: ["Boss", "暗影·法师"], back: ["暗影·祭祀"] }, { name: "暗影", front: ["Boss", "暗影·战士"], back: ["暗影·法师", "暗影·祭祀"] },
];

export const BOSS_MECHANICS: Array<Record<string, unknown>> = [
  { id: "split", name: "分裂", threshold: .3, count: 3 }, { id: "command", name: "指挥", backAttackMultiplier: 1.3 }, { id: "leadership", name: "统率", attackPerDeath: .15 }, { id: "blood_rage", name: "嗜血", thresholdStep: .3 },
  { id: "vampire", name: "吸血", lifesteal: 20 }, { id: "web", name: "蛛网", interval: 15, stun: 4 }, { id: "nature_guard", name: "自然守护", interval: 10, healPct: 15 }, { id: "rock", name: "磐石", damageReduction: .3, controlImmune: true },
  { id: "death_summon", name: "死亡召唤", threshold: .5, interval: 8, maxSummons: 3 }, { id: "storm_field", name: "风暴领域", playerCooldownAdd: .6 }, { id: "shadow_clone", name: "暗影分身", interval: 12, maxSummons: 2, hpMultiplier: .5 }, { id: "poison_aura", name: "剧毒光环", interval: 1, damagePct: 10 },
  { id: "charm", name: "魅惑", interval: 20, stun: 3 }, { id: "earthquake", name: "地震", interval: 15, damageMultiplier: 1.5 }, { id: "shadow_ritual", name: "暗影仪式", attackMultiplier: 2 }, { id: "wolf_summon", name: "狼群召唤", interval: 10, maxSummons: 4 },
  { id: "dragon_breath", name: "龙息", interval: 8, damageMultiplier: 2 }, { id: "life_seed", name: "生命之种", revives: 1 }, { id: "chaos_field", name: "混沌领域", interval: 10, buffMultiplier: 1.5 }, { id: "shadow_rule", name: "暗影统御", thresholdStep: .1, maxSummons: 3, attackPerTrigger: .05 },
];

export const ELITE_PASSIVES = ["铁壁", "狂暴", "回复", "荆棘", "迅捷", "毒素", "护盾", "诅咒"] as const;

export function battleSkillById(id: number): BattleSkill | undefined {
  return BATTLE_SKILLS.find((skill) => skill.id === id);
}
