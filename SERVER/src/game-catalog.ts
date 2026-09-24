import { readdirSync } from "node:fs";
import { fileURLToPath } from "node:url";

export interface ItemDefinition {
  id: number;
  name: string;
  type: "consumable" | "material";
  icon: string;
  description: string;
  price: number;
  stackMax: number;
  stats: Record<string, number>;
}

export const ITEMS: ItemDefinition[] = [
  { id: 1, name: "回复药水", type: "consumable", icon: "🧪", description: "恢复50 HP", price: 30, stackMax: 99, stats: { heal: 50 } },
  { id: 2, name: "大回复药", type: "consumable", icon: "🧴", description: "恢复200 HP", price: 100, stackMax: 50, stats: { heal: 200 } },
  { id: 3, name: "经验卷轴", type: "consumable", icon: "📜", description: "获得100经验", price: 80, stackMax: 20, stats: { experience: 100 } },
  { id: 4, name: "金币袋", type: "consumable", icon: "💰", description: "获得200金币", price: 0, stackMax: 30, stats: { gold: 200 } },
  { id: 5, name: "天命卡", type: "consumable", icon: "🃏", description: "随机触发一次命运事件", price: 0, stackMax: 99, stats: { fate: 1 } },
  { id: 6, name: "打孔器", type: "consumable", icon: "🛠", description: "为史诗或传说装备增加一个宝石孔", price: 0, stackMax: 99, stats: { socketTool: 1 } },
  { id: 90, name: "铁矿石", type: "material", icon: "⛰", description: "锻造材料", price: 15, stackMax: 99, stats: {} },
  { id: 91, name: "龙鳞片", type: "material", icon: "🪶", description: "稀有材料", price: 50, stackMax: 50, stats: {} },
];

export const GEMS = [
  { id: 1, name: "红宝石", icon: "🔴", description: "攻击力 +10/级" },
  { id: 2, name: "蓝宝石", icon: "🔵", description: "防御力 +10/级" },
  { id: 3, name: "绿宝石", icon: "🟢", description: "生命值 +50/级" },
  { id: 4, name: "黄宝石", icon: "🟡", description: "暴击率 +0.5%/级" },
  { id: 5, name: "紫宝石", icon: "🟣", description: "技能伤害 +0.5%/级" },
  { id: 6, name: "钻石", icon: "💎", description: "命中率 +0.5%/级" },
  { id: 7, name: "橙宝石", icon: "🟠", description: "暴击伤害 +2%/级" },
  { id: 8, name: "银宝石", icon: "⚪", description: "格挡率 +0.5%/级" },
];

export const EQUIPMENT_SLOTS = [
  { key: "weapon", name: "武器", typeId: 1, icon: "⚔️", mainStat: "攻击力", base: 40 },
  { key: "armor", name: "防具", typeId: 2, icon: "🛡️", mainStat: "防御力", base: 30 },
  { key: "shoes", name: "鞋子", typeId: 3, icon: "👟", mainStat: "闪避率", base: 4 },
  { key: "ring", name: "戒指", typeId: 4, icon: "💍", mainStat: "暴击率", base: 2 },
  { key: "necklace", name: "项链", typeId: 5, icon: "📿", mainStat: "技能伤害", base: 3 },
  { key: "cape", name: "披风", typeId: 6, icon: "🧣", mainStat: "速度", base: 5 },
  { key: "helmet", name: "头盔", typeId: 7, icon: "⛑️", mainStat: "格挡率", base: 2 },
  { key: "charm", name: "护符", typeId: 8, icon: "🍀", mainStat: "生命值", base: 100 },
] as const;

const EQUIPMENT_ICON_FOLDERS: Record<string, string> = {
  weapon: "weapon",
  armor: "armor",
  cape: "armor",
  shoes: "shoes",
  ring: "ring",
  necklace: "charm",
  charm: "charm",
  helmet: "helmet",
};

const EQUIPMENT_ICON_FALLBACKS: Record<string, string> = {
  weapon: "icon_0033.png",
  armor: "icon_0422.png",
  shoes: "icon_0436.png",
  ring: "icon_0462.png",
  charm: "icon_0036.png",
  helmet: "icon_0439.png",
};

const equipmentIconFiles = new Map<string, string[]>();

function stableStringHash(value: string): number {
  let hash = 2166136261;
  for (const character of value) {
    hash ^= character.codePointAt(0) ?? 0;
    hash = Math.imul(hash, 16777619);
  }
  return hash >>> 0;
}

export function equipmentIconPath(slot: string, identity = ""): string {
  const folder = EQUIPMENT_ICON_FOLDERS[slot];
  if (!folder) return "";
  let files = equipmentIconFiles.get(folder);
  if (!files) {
    try {
      const directory = fileURLToPath(new URL(`../../client/assets/equipment_icons/${folder}/`, import.meta.url));
      files = readdirSync(directory).filter((file) => /\.(?:png|jpe?g|webp|svg)$/i.test(file)).sort();
    } catch {
      files = [];
    }
    if (files.length === 0 && EQUIPMENT_ICON_FALLBACKS[folder]) files = [EQUIPMENT_ICON_FALLBACKS[folder]];
    equipmentIconFiles.set(folder, files);
  }
  if (files.length === 0) return "";
  const index = identity ? stableStringHash(identity) % files.length : Math.floor(Math.random() * files.length);
  return `res://assets/equipment_icons/${folder}/${files[index]}`;
}

export const QUALITY_NAMES = ["普通", "精良", "稀有", "史诗", "传说"] as const;
export const QUALITY_COLORS = ["#999999", "#33cc33", "#3366ff", "#b333ff", "#ff9911"] as const;
export const QUALITY_WEIGHTS = [0.60, 0.28, 0.10, 0.017, 0.003] as const;
export const AFFIX_COUNTS = [1, 2, 3, 4, 5] as const;
export const SET_NAMES = ["龙鳞", "烈焰", "冰霜", "雷霆", "疾风", "铁壁", "暗影", "自然", "引力", "星辰", "幻影", "口才", "奢侈"] as const;
export const SET_AFFIXES: Record<string, string[]> = {
  龙鳞: ["【龙鳞】硬皮", "【龙鳞】再生", "【龙鳞】坚韧", "【龙鳞】龙威"],
  烈焰: ["【烈焰】灼烧", "【烈焰】核心", "【烈焰】燎原", "【烈焰】引爆"],
  冰霜: ["【冰霜】蔓延", "【冰霜】护盾", "【冰霜】寒甲", "【冰霜】极寒"],
  雷霆: ["【雷霆】之速", "【雷霆】余震", "【雷霆】蓄能", "【雷霆】轰鸣"],
  疾风: ["【疾风】步法", "【疾风】回响", "【疾风】疾行", "【疾风】连击"],
  铁壁: ["【铁壁】堡垒", "【铁壁】反击", "【铁壁】坚壁", "【铁壁】铁甲"],
  暗影: ["【暗影】之刃", "【暗影】潜伏", "【暗影】杀意", "【暗影】疾影"],
  自然: ["【自然】恩赐", "【自然】庇护", "【自然】繁茂", "【自然】生根"],
  引力: ["【引力】吸引", "【引力】护符", "【引力】磁力", "【引力】万有"],
  星辰: ["【星辰】专注", "【星辰】涌动", "【星辰】辉光", "【星辰】流转"],
  幻影: ["【幻影】步法", "【幻影】迷踪", "【幻影】残影", "【幻影】灵动"],
  口才: ["【口才】魅力", "【口才】超级魅力", "【口才】雄辩", "【口才】超级雄辩"],
  奢侈: ["【奢侈】镀金", "【奢侈】挥霍", "【奢侈】豪赌", "【奢侈】破产"],
};

export interface SkillDefinition {
  id: number;
  name: string;
  icon: string;
  school: number;
  target: number | string;
  actionCd: number;
  price: number;
  description: string;
  damagePct?: number;
  hits?: number;
  control?: string;
  controlDuration?: number;
  healPct?: number;
  shieldPct?: number;
  buffEffect?: string;
  dotPct?: number;
  dotTicks?: number;
  bonus?: Record<string, number | string | boolean>;
}

export const SKILLS: SkillDefinition[] = [
  { id: 1, name: "重击", icon: "⚔", school: 0, target: 0, actionCd: 4, price: 0, description: "攻击力×150%单体伤害", damagePct: 150, hits: 1 },
  { id: 2, name: "猛力一击", icon: "💥", school: 0, target: 0, actionCd: 6, price: 1000, description: "攻击力×250%单体重击", damagePct: 250, hits: 1 },
  { id: 3, name: "蓄力斩", icon: "⚡", school: 0, target: 0, actionCd: 8, price: 10000, description: "攻击力×400%蓄力一击", damagePct: 400, hits: 1 },
  { id: 4, name: "碎裂打击", icon: "🪨", school: 0, target: 5, actionCd: 6, price: 10000, description: "攻击力×180%，无视20%防御", damagePct: 180, hits: 1, bonus: { ignoreDefPct: 20 } },
  { id: 5, name: "致命一击", icon: "🗡", school: 0, target: 2, actionCd: 9, price: 100000, description: "攻击力×500%，目标低血量时翻倍", damagePct: 500, hits: 1, bonus: { execute: 0.3 } },
  { id: 6, name: "终结技", icon: "🎯", school: 0, target: 3, actionCd: 10, price: 100000, description: "攻击力×300%，自身损血增伤", damagePct: 300, hits: 1 },
  { id: 7, name: "快速打击", icon: "⚡", school: 1, target: 0, actionCd: 4, price: 1000, description: "攻击力×110%，无视10%防御", damagePct: 110, hits: 1, bonus: { ignoreDefPct: 10 } },
  { id: 8, name: "连击", icon: "💥", school: 1, target: 0, actionCd: 5, price: 1000, description: "攻击力×55%两次", damagePct: 55, hits: 2 },
  { id: 9, name: "旋风斩", icon: "🌀", school: 1, target: 7, actionCd: 7, price: 10000, description: "攻击力×90%敌方全体", damagePct: 90, hits: 1 },
  { id: 10, name: "连射", icon: "🏹", school: 1, target: 0, actionCd: 7, price: 10000, description: "攻击力×40%三次", damagePct: 40, hits: 3 },
  { id: 11, name: "回旋镖", icon: "🪃", school: 1, target: 7, actionCd: 7, price: 10000, description: "攻击力×110%，最多两个目标", damagePct: 110, hits: 1, bonus: { maxTargets: 2 } },
  { id: 12, name: "无尽打击", icon: "♾", school: 1, target: 0, actionCd: 8, price: 50000, description: "首击90%，连续使用逐步增加", damagePct: 90, hits: 1 },
  { id: 13, name: "冰冻射击", icon: "❄", school: 2, target: 0, actionCd: 6, price: 10000, description: "攻击力×100%，冻结4秒", damagePct: 100, hits: 1, control: "freeze", controlDuration: 4 },
  { id: 14, name: "冰霜新星", icon: "🧊", school: 2, target: 7, actionCd: 8, price: 50000, description: "攻击力×80%，全体减速6秒", damagePct: 80, hits: 1, control: "slow", controlDuration: 6 },
  { id: 15, name: "眩晕锤", icon: "🔨", school: 2, target: 0, actionCd: 7, price: 10000, description: "攻击力×120%，眩晕4秒", damagePct: 120, hits: 1, control: "stun", controlDuration: 4 },
  { id: 16, name: "雷霆一击", icon: "⚡", school: 2, target: 0, actionCd: 7, price: 10000, description: "攻击力×130%，麻痹6秒", damagePct: 130, hits: 1, control: "paralysis", controlDuration: 6 },
  { id: 17, name: "静默领域", icon: "🔇", school: 2, target: 7, actionCd: 8, price: 50000, description: "攻击力×60%，全体沉默5秒", damagePct: 60, hits: 1, control: "silence", controlDuration: 5 },
  { id: 18, name: "深度冻结", icon: "❄️", school: 2, target: 0, actionCd: 9, price: 100000, description: "攻击力×200%，冻结6秒", damagePct: 200, hits: 1, control: "freeze", controlDuration: 6 },
  { id: 19, name: "腐蚀之触", icon: "💀", school: 2, target: 4, actionCd: 8, price: 50000, description: "攻击力×100%，禁疗8秒", damagePct: 100, hits: 1, control: "anti_heal", controlDuration: 8 },
  { id: 20, name: "时间凝滞", icon: "⏳", school: 2, target: 7, actionCd: 10, price: 100000, description: "攻击力×50%，全体麻痹6秒", damagePct: 50, hits: 1, control: "paralysis", controlDuration: 6 },
  { id: 21, name: "护盾", icon: "🛡", school: 3, target: "self", actionCd: 6, price: 1000, description: "防御力×300%护盾，持续5秒", shieldPct: 300 },
  { id: 22, name: "治疗波", icon: "💚", school: 3, target: "self_heal", actionCd: 6, price: 0, description: "恢复攻击力×150%生命", healPct: 150 },
  { id: 23, name: "铁壁姿态", icon: "🏰", school: 3, target: "self", actionCd: 7, price: 10000, description: "防御翻倍4秒", buffEffect: "def_x2" },
  { id: 24, name: "坚毅", icon: "💪", school: 3, target: "self", actionCd: 7, price: 50000, description: "受伤降低并免疫控制4秒", buffEffect: "tenacity" },
  { id: 25, name: "生命绽放", icon: "🌿", school: 3, target: "self_heal", actionCd: 8, price: 50000, description: "立即及之后恢复生命5次", healPct: 5 },
  { id: 26, name: "不屈意志", icon: "❤️‍🔥", school: 3, target: "self", actionCd: 8, price: 100000, description: "低生命时触发锁血", buffEffect: "undying" },
  { id: 27, name: "毒刃", icon: "🗡", school: 4, target: 0, actionCd: 5, price: 1000, description: "直伤80%并附加毒素", damagePct: 80, hits: 1, dotPct: 30, dotTicks: 4 },
  { id: 28, name: "烈焰灼烧", icon: "🔥", school: 4, target: 7, actionCd: 7, price: 10000, description: "直伤60%并灼烧全体", damagePct: 60, hits: 1, dotPct: 30, dotTicks: 4 },
  { id: 29, name: "撕裂", icon: "🩸", school: 4, target: 0, actionCd: 5, price: 10000, description: "直伤120%并流血", damagePct: 120, hits: 1, dotPct: 20, dotTicks: 3 },
  { id: 30, name: "毒雾", icon: "☁️", school: 4, target: 7, actionCd: 8, price: 50000, description: "直伤40%并全体中毒", damagePct: 40, hits: 1, dotPct: 35, dotTicks: 5 },
  { id: 31, name: "剧毒爆发", icon: "💚", school: 4, target: 0, actionCd: 9, price: 50000, description: "结算目标持续伤害", bonus: { detonate: 1.5 } },
  { id: 32, name: "瘟疫传播", icon: "🦠", school: 4, target: 7, actionCd: 10, price: 100000, description: "将持续伤害复制到敌方全体", bonus: { spread: true } },
  { id: 33, name: "穿刺射击", icon: "🏹", school: 5, target: 9, actionCd: 6, price: 1000, description: "前排120%并贯穿后排80%", damagePct: 120, hits: 1, bonus: { pierceBackPct: 80 } },
  { id: 34, name: "裂地斩", icon: "🌍", school: 5, target: 9, actionCd: 8, price: 50000, description: "前排180%并贯穿后排120%", damagePct: 180, hits: 1, bonus: { pierceBackPct: 120 } },
  { id: 35, name: "穿透箭雨", icon: "🌧", school: 5, target: 9, actionCd: 7, price: 10000, description: "前后排各90%", damagePct: 90, hits: 1, bonus: { pierceBackPct: 90 } },
  { id: 36, name: "暗影突袭", icon: "🌑", school: 5, target: 9, actionCd: 9, price: 100000, description: "前排150%并贯穿后排100%", damagePct: 150, hits: 1, bonus: { pierceBackPct: 100 } },
];

export const MAP_BASE = [0, 1, 5, 1, 7, 2, 1, 4, 1, 6, 5, 1, 7, 2, 1, 12, 1, 5, 1, 4, 2, 1, 7, 6, 1, 12, 1, 11];
export const GRID_NAMES = ["勇者之家", "战斗格", "精英战斗", "挑战格", "休息格", "宝箱格", "锻造格", "命运格", "神祇格", "合成格", "闪电格", "Boss格", "空地", "空地2", "彩票格", "建设格"];
export const GRID_ICONS = ["🏠", "⚔️", "🗡️", "🏆", "🛌", "🎁", "🔨", "🎲", "🏛", "🔮", "⚡", "💀", "🟩", "💰", "🎰", "🔧"];

export const MONSTER_DEFS: Record<string, { hp: number; atk: number; def: number; speed: number }> = {
  "史莱姆·战士": { hp: 1.5, atk: .7, def: 1.2, speed: 5 }, "史莱姆·射手": { hp: .8, atk: 1.4, def: .6, speed: 25 }, "史莱姆·法师": { hp: .7, atk: 1.6, def: .5, speed: 8 },
  "哥布林·战士": { hp: 1.3, atk: .9, def: 1.3, speed: 8 }, "哥布林·射手": { hp: .8, atk: 1.5, def: .5, speed: 25 }, "哥布林·法师": { hp: .7, atk: 1.7, def: .4, speed: 8 },
  "骷髅·战士": { hp: 1.1, atk: 1, def: 1.1, speed: 15 }, "骷髅·射手": { hp: .7, atk: 1.6, def: .4, speed: 25 }, "骷髅·法师": { hp: .6, atk: 1.8, def: .3, speed: 5 },
  "狼·战士": { hp: 1.2, atk: 1.1, def: .9, speed: 25 }, "狼·射手": { hp: .9, atk: 1.3, def: .5, speed: 25 }, "狼·盗贼": { hp: .6, atk: 1.4, def: .3, speed: 35 },
  "蝙蝠·战士": { hp: 1, atk: 1.2, def: .6, speed: 35 }, "蝙蝠·射手": { hp: .7, atk: 1.4, def: .4, speed: 25 }, "蝙蝠·盗贼": { hp: .5, atk: 1.2, def: .3, speed: 35 },
  "蜘蛛·战士": { hp: 1.4, atk: .8, def: 1.4, speed: 5 }, "蜘蛛·射手": { hp: .8, atk: 1.5, def: .5, speed: 25 }, "蜘蛛·法师": { hp: .9, atk: 1.3, def: .6, speed: 8 },
  "树精·战士": { hp: 1.8, atk: .5, def: 1.5, speed: 5 }, "树精·射手": { hp: 1, atk: 1.4, def: .7, speed: 8 }, "树精·祭祀": { hp: 1.3, atk: .4, def: .8, speed: 5 },
  "石魔·战士": { hp: 2, atk: .6, def: 1.8, speed: 5 }, "石魔·法师": { hp: 1.2, atk: 1.5, def: 1, speed: 8 }, "石魔·射手": { hp: 1, atk: 1.3, def: 1, speed: 15 },
  "暗影·战士": { hp: 1, atk: 1.2, def: .8, speed: 15 }, "暗影·法师": { hp: .7, atk: 1.8, def: .3, speed: 8 }, "暗影·盗贼": { hp: .5, atk: 1.5, def: .2, speed: 35 },
};

export const NORMAL_TEMPLATES = [
  ["史莱姆·战士"], ["骷髅·法师"], ["哥布林·战士", "哥布林·射手"], ["狼·战士", "狼·射手"], ["蝙蝠·战士", "蝙蝠·盗贼", "蝙蝠·射手"], ["蜘蛛·战士", "蜘蛛·射手", "蜘蛛·法师"], ["树精·战士", "树精·射手", "树精·祭祀"], ["石魔·战士", "石魔·射手", "石魔·法师"], ["暗影·盗贼", "暗影·战士", "暗影·法师"],
];
export const ELITE_TEMPLATES = [["骷髅·法师"], ["石魔·战士", "哥布林·法师"], ["狼·战士", "狼·盗贼"], ["哥布林·战士", "哥布林·射手", "哥布林·祭祀"], ["暗影·盗贼", "暗影·战士", "暗影·法师"]];
export const BOSS_NAMES = ["史莱姆王", "野人队长", "骷髅将军", "狼王", "史前机兵", "花冠女皇", "树精长老", "石魔巨像", "尸王", "鹰身女王", "暗影领主", "虚假帝皇", "幻蝶", "异化鲨鲨", "暗影大祭司", "狼妄", "骨龙", "绿精", "混沌魔像", "暗影"];

export function itemById(id: number): ItemDefinition | undefined { return ITEMS.find((item) => item.id === id); }
export function skillById(id: number): SkillDefinition | undefined { return SKILLS.find((skill) => skill.id === id); }
export function gemById(id: number): (typeof GEMS)[number] | undefined { return GEMS.find((gem) => gem.id === id); }
