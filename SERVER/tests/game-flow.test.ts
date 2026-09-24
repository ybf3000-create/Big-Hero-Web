import assert from "node:assert/strict";
import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import { buildApp } from "../src/app.js";
import { BOSS_NAMES } from "../src/game-catalog.js";
import { applyGameCommand, createInitialGameState, equipmentMatchesRule } from "../src/game-engine.js";
import { addItem, parseGameState, recalculateStats, serializeGameState } from "../src/game-state.js";
import { applyMigrations } from "../src/migrations.js";
import { hashSecret } from "../src/security.js";
import { SqliteRepository } from "../src/sqlite-repository.js";
import type { PasswordHasher } from "../src/security.js";

class TestHasher implements PasswordHasher {
  async hash(password: string): Promise<string> { return `test:${password}`; }
  async verify(encoded: string, password: string): Promise<boolean> { return encoded === `test:${password}`; }
}

async function setup() {
  const directory = await mkdtemp(path.join(tmpdir(), "big-hero-game-flow-"));
  const repository = new SqliteRepository(path.join(directory, "game.sqlite"));
  applyMigrations(repository.database, path.resolve("db/migrations"));
  return { directory, repository };
}

function grantItem(repository: SqliteRepository, characterId: string, itemId: number, count: number): void {
  const state = createInitialGameState();
  assert.equal(addItem(state, itemId, count), true);
  repository.database.prepare(
    "UPDATE character_states SET state_json = ?, updated_at = ? WHERE character_id = ?",
  ).run(serializeGameState(state), Date.now(), characterId);
}

test("game state survives commands and repeated roll requests are idempotent", async (context) => {
  const { directory, repository } = await setup();
  context.after(async () => { await repository.close(); await rm(directory, { recursive: true, force: true }); });
  const inviteHash = hashSecret("GAME-FLOW-INVITE");
  repository.insertInviteCode("game-flow-invite", inviteHash);
  const account = await repository.registerAccount({ requestId: "game_register_1", username: "game_hero", passwordHash: "test:Good-password-2026", inviteCodeHash: inviteHash });
  const character = await repository.createCharacter({ id: "game-character", requestId: "game_character_1", accountId: account.id, displayName: "测试勇者", normalizedName: "测试勇者" });
  const before = await repository.getGameState(character.id);
  assert.deepEqual(before.inventory, []);
  assert.equal(before.equipmentBag.length, 1);
  assert.equal(before.equipmentBag[0]?.slot, "weapon");
  assert.equal(before.equipmentBag[0]?.locked, true);
  assert.equal(before.equipmentBag[0]?.bound, true);
  assert.equal(before.equipped.weapon, before.equipmentBag[0]?.id);
  assert.equal(before.stats.attack, 85);
  assert.equal(before.stats.defense, 15);
  assert.equal(before.stats.crit, 0);
  const first = await repository.executeGameCommand({ characterId: character.id, requestId: "game_roll_01", command: "roll", payload: {} });
  const repeated = await repository.executeGameCommand({ characterId: character.id, requestId: "game_roll_01", command: "roll", payload: {} });
  assert.deepEqual(repeated, first);
  assert.equal((await repository.getGameState(character.id)).lastDiceRoll, first.state.lastDiceRoll);
});

test("server-owned auto-play must be enabled before a background roll", () => {
  const initial = createInitialGameState();
  assert.equal(initial.autoPlayEnabled, false);
  assert.throws(
    () => applyGameCommand(initial, { level: 1, experience: 0, gold: 0 }, "auto_roll", {}),
    /自动挂机未开启/,
  );
  const enabled = applyGameCommand(initial, { level: 1, experience: 0, gold: 0 }, "auto_play", { enabled: true });
  assert.equal(enabled.state.autoPlayEnabled, true);
  const rolled = applyGameCommand(enabled.state, enabled.character, "auto_roll", {});
  assert.equal(typeof rolled.event.dice, "number");
  assert.equal(rolled.state.autoPlayEnabled, true);
});

test("a committed battle is recoverable after the response is lost", async (context) => {
  const { directory, repository } = await setup();
  context.after(async () => { await repository.close(); await rm(directory, { recursive: true, force: true }); });
  const inviteHash = hashSecret("BATTLE-RECOVERY-INVITE");
  repository.insertInviteCode("battle-recovery-invite", inviteHash);
  const account = await repository.registerAccount({ requestId: "recovery_register", username: "recovery_hero", passwordHash: "x", inviteCodeHash: inviteHash });
  const character = await repository.createCharacter({ id: "recovery-character", requestId: "recovery_character", accountId: account.id, displayName: "恢复勇者", normalizedName: "恢复勇者" });
  const state = createInitialGameState();
  state.mapGrids = Array.from({ length: state.mapTotalGrids }, () => 1);
  repository.database.prepare("UPDATE character_states SET state_json = ? WHERE character_id = ?").run(serializeGameState(state), character.id);
  const originalRandom = Math.random;
  Math.random = () => 0.5;
  try {
    // Simulate the HTTP response being discarded after the transaction commits.
    const committed = await repository.executeGameCommand({ characterId: character.id, requestId: "recovery_roll_1", command: "roll", payload: {} });
    const recovered = await repository.getGameSnapshot(character.id);
    assert.deepEqual(recovered.state, committed.state);
    assert.equal(recovered.character.level, committed.character.level);
    assert.equal(recovered.character.experience, committed.character.experience);
    assert.equal(recovered.character.gold, String(committed.character.gold));
    assert.equal(recovered.state.hp, committed.state.hp);
  } finally {
    Math.random = originalRandom;
  }
});

test("corrupt stored state fails closed without overwriting player data", async (context) => {
  const { directory, repository } = await setup();
  context.after(async () => { await repository.close(); await rm(directory, { recursive: true, force: true }); });
  const inviteHash = hashSecret("CORRUPT-STATE-INVITE");
  repository.insertInviteCode("corrupt-state-invite", inviteHash);
  const account = await repository.registerAccount({ requestId: "corrupt_register", username: "corrupt_hero", passwordHash: "x", inviteCodeHash: inviteHash });
  const character = await repository.createCharacter({ id: "corrupt-character", requestId: "corrupt_character", accountId: account.id, displayName: "保护勇者", normalizedName: "保护勇者" });
  const corruptJson = JSON.stringify({ version: 99, inventory: [], equipmentBag: [] });
  repository.database.prepare("UPDATE character_states SET state_json = ? WHERE character_id = ?").run(corruptJson, character.id);
  await assert.rejects(repository.getGameState(character.id), /stored game state is invalid/);
  const stored = repository.database.prepare("SELECT state_json FROM character_states WHERE character_id = ?").get(character.id) as { state_json: string };
  assert.equal(stored.state_json, corruptJson);
});

test("dice, skill slots, equipment locks and enhancement limits enforce game rules", () => {
  let state = createInitialGameState();
  const character = { level: 1, experience: 0, gold: 10_000_000 };
  for (let index = 0; index < 100; index += 1) {
    const result = applyGameCommand(state, character, "roll", {});
    state = result.state;
    assert.ok((state.lastDiceRoll ?? 0) >= 1 && (state.lastDiceRoll ?? 7) <= 6);
  }
  state.equipmentBag.push({ id: "test-sword", slot: "weapon", name: "测试长剑", quality: 0, enhance: 0, mainStat: "攻击力", mainValue: 4, locked: false, bound: true });
  const locked = applyGameCommand(state, character, "equipment_lock", { equipment_id: "test-sword", locked: true });
  assert.equal(locked.state.equipmentBag.find((item) => item.id === "test-sword")?.locked, true);
  const maxed = createInitialGameState();
  const sword = { id: "test-sword", slot: "weapon", name: "测试长剑", quality: 0, enhance: 0, mainStat: "攻击力", mainValue: 4, locked: false, bound: true };
  maxed.equipmentBag.push(sword);
  maxed.slotEnhance.weapon = 200;
  assert.throws(() => applyGameCommand(maxed, character, "equipment_enhance", { equipment_id: sword.id }), /强化上限/);
  const limited = { ...createInitialGameState(), skills: [1, 2, 3, 22], skillSlots: [1, 22] };
  const slotted = applyGameCommand(limited, character, "skill_slot", { skill_id: 2, slots: [1, 22, 2] });
  assert.deepEqual(slotted.state.skillSlots, [1, 22]);
});

test("server derived stats include free speed/luck and equipped set bonuses", () => {
  const state = createInitialGameState();
  state.attributes = { attack: 0, defense: 0, speed: 10, luck: 4 };
  const equipment = [
    { id: "dragon-a", slot: "weapon", name: "龙鳞刃", quality: 4, enhance: 0, mainStat: "攻击力", mainValue: 1, locked: false, bound: true, suitName: "龙鳞", setAffixes: [{ name: "【龙鳞】坚韧", type: "set" }] },
    { id: "dragon-b", slot: "armor", name: "龙鳞甲", quality: 4, enhance: 0, mainStat: "防御力", mainValue: 1, locked: false, bound: true, suitName: "龙鳞", setAffixes: [] },
    { id: "flame-a", slot: "shoes", name: "烈焰靴", quality: 4, enhance: 0, mainStat: "攻击力", mainValue: 1, locked: false, bound: true, suitName: "烈焰", setAffixes: [] },
    { id: "flame-b", slot: "ring", name: "烈焰戒", quality: 4, enhance: 0, mainStat: "攻击力", mainValue: 1, locked: false, bound: true, suitName: "烈焰", setAffixes: [] },
    { id: "frost-a", slot: "necklace", name: "冰霜坠", quality: 4, enhance: 0, mainStat: "速度", mainValue: 1, locked: false, bound: true, suitName: "冰霜", setAffixes: [] },
    { id: "frost-b", slot: "cape", name: "冰霜披风", quality: 4, enhance: 0, mainStat: "速度", mainValue: 1, locked: false, bound: true, suitName: "冰霜", setAffixes: [] },
    { id: "wind-a", slot: "helmet", name: "疾风盔", quality: 4, enhance: 0, mainStat: "速度", mainValue: 1, locked: false, bound: true, suitName: "疾风", setAffixes: [{ name: "【疾风】疾行", type: "set" }] },
    { id: "wind-b", slot: "charm", name: "疾风符", quality: 4, enhance: 0, mainStat: "速度", mainValue: 1, locked: false, bound: true, suitName: "疾风", setAffixes: [] },
  ];
  state.equipmentBag.push(...equipment);
  for (const item of equipment) state.equipped[item.slot] = item.id;
  recalculateStats(state, 1);
  assert.equal(state.stats.attack, 30);
  assert.equal(state.stats.defense, 18);
  assert.equal(state.stats.speed, 49);
  assert.equal(state.stats.luck, 4);
  assert.equal(state.stats.block, 3);
  state.attributes.luck = 150;
  recalculateStats(state, 1);
  assert.equal(state.stats.luck, 150);
});

test("equipment percentage affixes multiply accumulated equipment stats", () => {
  const state = createInitialGameState();
  const weapon = {
    id: "percent-weapon", slot: "weapon", name: "百分比武器", quality: 3, enhance: 0,
    mainStat: "攻击力", mainValue: 100, locked: false, bound: true,
    affixes: [{ name: "攻击%", type: "attack", value: 10, display: "+10%" }],
  };
  state.equipmentBag.push(weapon);
  state.equipped.weapon = weapon.id;
  recalculateStats(state, 1);
  // (level-1 white attack 25 + weapon 100) * 1.10 = 137.5, floored.
  assert.equal(state.stats.attack, 137);
});

test("free attack points share the additive attack multiplier with equipment percentages", () => {
  const state = createInitialGameState();
  state.attributes.attack = 10;
  const weapon = {
    id: "free-percent-weapon", slot: "weapon", name: "混合攻击武器", quality: 3, enhance: 0,
    mainStat: "攻击力", mainValue: 100, locked: false, bound: true,
    affixes: [{ name: "攻击%", type: "attack", value: 10, display: "+10%" }],
  };
  state.equipmentBag.push(weapon);
  state.equipped.weapon = weapon.id;
  recalculateStats(state, 1);
  // (25 + 100) × (1 + 10% equipment + 18% free) = 160.
  assert.equal(state.stats.attack, 160);
});

test("attribute points are awarded, allocated, reset and repaired for legacy saves", async (context) => {
  const { directory, repository } = await setup();
  context.after(async () => { await repository.close(); await rm(directory, { recursive: true, force: true }); });
  const inviteHash = hashSecret("ATTRIBUTE-FLOW");
  repository.insertInviteCode("attribute-flow", inviteHash);
  const account = await repository.registerAccount({ requestId: "attribute_register_1", username: "attribute_hero", passwordHash: "x", inviteCodeHash: inviteHash });
  const character = await repository.createCharacter({ id: "attribute-character", requestId: "attribute_character_1", accountId: account.id, displayName: "属性勇者", normalizedName: "属性勇者" });
  repository.database.prepare("UPDATE characters SET level = 10, experience = 0, gold = 5000 WHERE id = ?").run(character.id);

  const legacy = JSON.parse(serializeGameState(createInitialGameState())) as Record<string, unknown>;
  delete legacy.freeAttributePoints;
  delete legacy.attributes;
  repository.database.prepare("UPDATE character_states SET state_json = ? WHERE character_id = ?").run(JSON.stringify(legacy), character.id);

  const repaired = await repository.getGameState(character.id);
  assert.equal(repaired.freeAttributePoints, 18);
  assert.deepEqual(repaired.attributes, { attack: 0, defense: 0, speed: 0, luck: 0 });

  const allocated = await repository.executeGameCommand({ characterId: character.id, requestId: "attribute_allocate_1", command: "attribute_allocate", payload: { attribute: "atk" } });
  assert.equal(allocated.state.freeAttributePoints, 17);
  assert.equal(allocated.state.attributes.attack, 1);
  const repeated = await repository.executeGameCommand({ characterId: character.id, requestId: "attribute_allocate_1", command: "attribute_allocate", payload: { attribute: "atk" } });
  assert.equal(repeated.state.attributes.attack, 1);

  const reset = await repository.executeGameCommand({ characterId: character.id, requestId: "attribute_reset_1", command: "attribute_reset", payload: {} });
  assert.equal(reset.state.freeAttributePoints, 18);
  assert.deepEqual(reset.state.attributes, { attack: 0, defense: 0, speed: 0, luck: 0 });
  assert.equal(reset.character.gold, 3000);
  assert.equal((await repository.getGameState(character.id)).freeAttributePoints, 18);

  const levelState = createInitialGameState();
  assert.equal(addItem(levelState, 3, 1), true);
  const leveled = applyGameCommand(levelState, { level: 1, experience: 0, gold: 0 }, "item_use", { item_id: 3 });
  assert.equal(leveled.character.level, 2);
  assert.equal(leveled.state.freeAttributePoints, 2);
});

test("auction purchase transfers an item once and charges the buyer once", async (context) => {
  const { directory, repository } = await setup();
  context.after(async () => { await repository.close(); await rm(directory, { recursive: true, force: true }); });
  const firstInvite = hashSecret("AUCTION-FLOW-1");
  const secondInvite = hashSecret("AUCTION-FLOW-2");
  repository.insertInviteCode("auction-flow-1", firstInvite);
  repository.insertInviteCode("auction-flow-2", secondInvite);
  const seller = await repository.registerAccount({ requestId: "auction_register_1", username: "seller_hero", passwordHash: "x", inviteCodeHash: firstInvite });
  const buyer = await repository.registerAccount({ requestId: "auction_register_2", username: "buyer_hero", passwordHash: "x", inviteCodeHash: secondInvite });
  const sellerCharacter = await repository.createCharacter({ id: "seller-character", requestId: "auction_character_1", accountId: seller.id, displayName: "卖家勇者", normalizedName: "卖家勇者" });
  const buyerCharacter = await repository.createCharacter({ id: "buyer-character", requestId: "auction_character_2", accountId: buyer.id, displayName: "买家勇者", normalizedName: "买家勇者" });
  grantItem(repository, sellerCharacter.id, 6, 1);
  repository.database.prepare("UPDATE characters SET gold = 1000 WHERE id = ?").run(buyerCharacter.id);
  const listing = await repository.createAuctionListing({ characterId: sellerCharacter.id, requestId: "auction_list_1", itemKind: "item", itemId: 6, itemCount: 1, buyoutPrice: 100, durationHours: 24 });
  assert.ok((listing.character?.revision ?? 0) > 0);
  await assert.rejects(repository.buyAuctionListing(sellerCharacter.id, "auction_self_1", listing.id), /不能购买自己的订单/);
  const purchased = await repository.buyAuctionListing(buyerCharacter.id, "auction_buy_1", listing.id);
  const repeated = await repository.buyAuctionListing(buyerCharacter.id, "auction_buy_1", listing.id);
  assert.equal(purchased.gold, 900);
  assert.equal(repeated.gold, 900);
  assert.equal(purchased.listing.status, "sold");
  const boughtTool = (await repository.getGameState(buyerCharacter.id)).inventory.find((item) => item.itemId === 6);
  assert.equal(boughtTool?.count, 1);
  assert.equal(boughtTool?.bound, true);
  const claimed = await repository.claimAuctionListing(sellerCharacter.id, "auction_claim_1", listing.id);
  const claimedRepeated = await repository.claimAuctionListing(sellerCharacter.id, "auction_claim_1", listing.id);
  assert.equal(claimed.gold, 95);
  assert.deepEqual(claimedRepeated, claimed);
});

test("auction cancel is idempotent and returns the transaction character snapshot", async (context) => {
  const { directory, repository } = await setup();
  context.after(async () => { await repository.close(); await rm(directory, { recursive: true, force: true }); });
  const inviteHash = hashSecret("AUCTION-CANCEL-1");
  repository.insertInviteCode("auction-cancel-1", inviteHash);
  const account = await repository.registerAccount({ requestId: "cancel_register", username: "cancel_hero", passwordHash: "x", inviteCodeHash: inviteHash });
  const character = await repository.createCharacter({ id: "cancel-character", requestId: "cancel_character", accountId: account.id, displayName: "取消勇者", normalizedName: "取消勇者" });
  grantItem(repository, character.id, 6, 1);
  const listing = await repository.createAuctionListing({ characterId: character.id, requestId: "cancel_listing", itemKind: "item", itemId: 6, itemCount: 1, buyoutPrice: 100, durationHours: 8 });
  const cancelled = await repository.cancelAuctionListing(character.id, listing.id, "cancel_request_1");
  const repeated = await repository.cancelAuctionListing(character.id, listing.id, "cancel_request_1");
  assert.equal(cancelled.status, "cancelled");
  assert.deepEqual(repeated, cancelled);
  assert.equal(cancelled.character?.revision, (listing.character?.revision ?? 0) + 1);
  await assert.rejects(repository.cancelAuctionListing(character.id, listing.id, "cancel_request_2"), /订单无法取消/);
});

test("auction price and active listing boundaries are enforced", async (context) => {
  const { directory, repository } = await setup();
  context.after(async () => { await repository.close(); await rm(directory, { recursive: true, force: true }); });
  const inviteHash = hashSecret("AUCTION-LIMITS");
  repository.insertInviteCode("auction-limits", inviteHash);
  const account = await repository.registerAccount({ requestId: "limits_register_1", username: "limit_hero", passwordHash: "x", inviteCodeHash: inviteHash });
  const character = await repository.createCharacter({ id: "limit-character", requestId: "limits_character_1", accountId: account.id, displayName: "边界勇者", normalizedName: "边界勇者" });
  grantItem(repository, character.id, 6, 4);
  await assert.rejects(repository.createAuctionListing({ characterId: character.id, requestId: "limits_price_0", itemKind: "item", itemId: 6, itemCount: 1, buyoutPrice: 0, durationHours: 24 }), /价格需为正整数/);
  for (let index = 0; index < 3; index += 1) {
    await repository.createAuctionListing({ characterId: character.id, requestId: `limits_list_${index}`, itemKind: "item", itemId: 6, itemCount: 1, buyoutPrice: index + 1, durationHours: 24 });
  }
  await assert.rejects(repository.createAuctionListing({ characterId: character.id, requestId: "limits_list_4", itemKind: "item", itemId: 6, itemCount: 1, buyoutPrice: 4, durationHours: 24 }), /最多同时上架3件/);
});

test("auction enforces the confirmed trade scope and permanent binding", async (context) => {
  const { directory, repository } = await setup();
  context.after(async () => { await repository.close(); await rm(directory, { recursive: true, force: true }); });
  const firstInvite = hashSecret("TRADE-SCOPE-1");
  const secondInvite = hashSecret("TRADE-SCOPE-2");
  repository.insertInviteCode("trade-scope-1", firstInvite);
  repository.insertInviteCode("trade-scope-2", secondInvite);
  const seller = await repository.registerAccount({ requestId: "scope_register_1", username: "scope_seller", passwordHash: "x", inviteCodeHash: firstInvite });
  const buyer = await repository.registerAccount({ requestId: "scope_register_2", username: "scope_buyer", passwordHash: "x", inviteCodeHash: secondInvite });
  const sellerCharacter = await repository.createCharacter({ id: "scope-seller", requestId: "scope_character_1", accountId: seller.id, displayName: "范围卖家", normalizedName: "范围卖家" });
  const buyerCharacter = await repository.createCharacter({ id: "scope-buyer", requestId: "scope_character_2", accountId: buyer.id, displayName: "范围买家", normalizedName: "范围买家" });
  grantItem(repository, sellerCharacter.id, 1, 1);
  await assert.rejects(repository.createAuctionListing({ characterId: sellerCharacter.id, requestId: "scope_bad_item", itemKind: "item", itemId: 1, itemCount: 1, buyoutPrice: 1, durationHours: 8 }), /只有打孔器/);
  const state = await repository.getGameState(sellerCharacter.id);
  state.gemBag.push({ gemId: 8, level: 3, count: 2 });
  repository.database.prepare("UPDATE character_states SET state_json = ? WHERE character_id = ?").run(serializeGameState(state), sellerCharacter.id);
  repository.database.prepare("UPDATE characters SET gold = 100 WHERE id = ?").run(buyerCharacter.id);
  const listing = await repository.createAuctionListing({ characterId: sellerCharacter.id, requestId: "scope_gem", itemKind: "gem", itemId: 8, itemLevel: 3, itemCount: 2, buyoutPrice: 10, durationHours: 8 });
  await repository.buyAuctionListing(buyerCharacter.id, "scope_buy", listing.id);
  const purchased = (await repository.getGameState(buyerCharacter.id)).gemBag[0]!;
  assert.deepEqual(purchased, { gemId: 8, level: 3, count: 2, bound: true });
});

test("game HTTP endpoints expose state and roll result", async (context) => {
  const { directory, repository } = await setup();
  context.after(async () => { await repository.close(); await rm(directory, { recursive: true, force: true }); });
  repository.insertInviteCode("http-flow-invite", hashSecret("HTTPFLOWINVITE"));
  const app = await buildApp({ repository, passwordHasher: new TestHasher() });
  const register = await app.inject({ method: "POST", url: "/api/v1/auth/register", payload: { rules_version: "network-1", request_id: "http_register_1", invite_code: "HTTP-FLOW-INVITE", username: "http_hero", password: "Good-password-2026", password_confirm: "Good-password-2026" } });
  assert.equal(register.statusCode, 201);
  const login = await app.inject({ method: "POST", url: "/api/v1/auth/login", payload: { rules_version: "network-1", username: "http_hero", password: "Good-password-2026" } });
  const token = login.json().session.token as string;
  await app.inject({ method: "POST", url: "/api/v1/characters", headers: { authorization: `Bearer ${token}` }, payload: { rules_version: "network-1", request_id: "http_character_1", name: "网页勇者" } });
  const character = await repository.getCharacter(login.json().account.id as string);
  repository.database.prepare("UPDATE characters SET level = 10 WHERE id = ?").run(character?.id);
  const state = await app.inject({ method: "GET", url: "/api/v1/game/state", headers: { authorization: `Bearer ${token}` } });
  assert.equal(state.statusCode, 200);
  assert.equal(state.json().state.freeAttributePoints, 18);
  const allocate = await app.inject({ method: "POST", url: "/api/v1/game/attributes/allocate", headers: { authorization: `Bearer ${token}` }, payload: { rules_version: "network-1", request_id: "http_attribute_01", payload: { attribute: "luck" } } });
  assert.equal(allocate.statusCode, 200);
  assert.equal(allocate.json().state.freeAttributePoints, 17);
  assert.equal(allocate.json().state.attributes.luck, 1);
  const gemState = await repository.getGameState(character!.id);
  gemState.gemBag.push({ gemId: 1, level: 1, count: 3 });
  repository.database.prepare("UPDATE character_states SET state_json = ? WHERE character_id = ?").run(serializeGameState(gemState), character!.id);
  repository.database.prepare("UPDATE characters SET gold = 10000 WHERE id = ?").run(character!.id);
  const synthesizeAll = await app.inject({ method: "POST", url: "/api/v1/game/gem/synthesize-all", headers: { authorization: `Bearer ${token}` }, payload: { rules_version: "network-1", request_id: "http_gem_all_01", payload: {} } });
  assert.equal(synthesizeAll.statusCode, 200);
  assert.equal(synthesizeAll.json().event.synthesisCount, 1);
  assert.equal(Number(synthesizeAll.json().character.gold), 9_000);
  assert.equal(synthesizeAll.json().state.gemBag.find((gem: { gemId: number; level: number }) => gem.gemId === 1 && gem.level === 2)?.count, 1);
  const roll = await app.inject({ method: "POST", url: "/api/v1/game/roll", headers: { authorization: `Bearer ${token}` }, payload: { rules_version: "network-1", request_id: "http_roll_01", payload: {} } });
  assert.equal(roll.statusCode, 200);
  assert.equal(typeof roll.json().event.dice, "number");
  const backgroundState = await repository.getGameState(character!.id);
  backgroundState.mapGrids = backgroundState.mapGrids.map(() => 0);
  backgroundState.pendingConstruction = null;
  repository.database.prepare("UPDATE character_states SET state_json = ? WHERE character_id = ?").run(serializeGameState(backgroundState), character!.id);
  const enabled = await app.inject({ method: "POST", url: "/api/v1/game/auto-play", headers: { authorization: `Bearer ${token}` }, payload: { rules_version: "network-1", request_id: "http_auto_play_1", payload: { enabled: true } } });
  assert.equal(enabled.statusCode, 200);
  assert.equal(enabled.json().state.autoPlayEnabled, true);
  const beforeBackgroundRevision = (await repository.getCharacter(login.json().account.id as string))!.revision;
  const presence = await app.inject({ method: "POST", url: "/api/v1/game/auto-play/presence", headers: { authorization: `Bearer ${token}` }, payload: { background: true } });
  assert.equal(presence.statusCode, 200);
  await new Promise((resolve) => setTimeout(resolve, 2_100));
  const afterBackground = await repository.getCharacter(login.json().account.id as string);
  assert.ok(afterBackground!.revision > beforeBackgroundRevision);
  assert.notEqual((await repository.getGameState(character!.id)).lastDiceRoll, null);
  await app.close();
});

test("deleted character can be recreated and immediately load authoritative game state", async (context) => {
  const { directory, repository } = await setup();
  context.after(async () => { await repository.close(); await rm(directory, { recursive: true, force: true }); });
  repository.insertInviteCode("recreate-flow-invite", hashSecret("RECREATEFLOWINVITE"));
  const app = await buildApp({ repository, passwordHasher: new TestHasher() });
  const register = await app.inject({ method: "POST", url: "/api/v1/auth/register", payload: { rules_version: "network-1", request_id: "recreate_register", invite_code: "RECREATE-FLOW-INVITE", username: "recreate_hero", password: "Good-password-2026", password_confirm: "Good-password-2026" } });
  assert.equal(register.statusCode, 201);
  const login = await app.inject({ method: "POST", url: "/api/v1/auth/login", payload: { rules_version: "network-1", username: "recreate_hero", password: "Good-password-2026" } });
  const token = login.json().session.token as string;
  const headers = { authorization: `Bearer ${token}` };
  const first = await app.inject({ method: "POST", url: "/api/v1/characters", headers, payload: { rules_version: "network-1", request_id: "recreate_character_1", name: "重建勇者" } });
  assert.equal(first.statusCode, 201);
  const deleted = await app.inject({ method: "POST", url: "/api/v1/characters/delete", headers, payload: { rules_version: "network-1", confirm_name: "重建勇者" } });
  assert.equal(deleted.statusCode, 200);
  const recreated = await app.inject({ method: "POST", url: "/api/v1/characters", headers, payload: { rules_version: "network-1", request_id: "recreate_character_2", name: "重建勇者" } });
  assert.equal(recreated.statusCode, 201);
  const state = await app.inject({ method: "GET", url: "/api/v1/game/state", headers });
  assert.equal(state.statusCode, 200);
  assert.equal(state.json().character.id, recreated.json().character.id);
  assert.equal(state.json().state.version, 1);
  await app.close();
});

test("battle grids return a browser-playable combat timeline", () => {
  let state = createInitialGameState();
  state.mapGrids = state.mapGrids.map(() => 1);
  state.gridIndex = 0;
  const character = { level: 1, experience: 0, gold: 0 };
  const result = applyGameCommand(state, character, "roll", {});
  assert.equal(result.event.kind, "battle");
  assert.ok(Array.isArray(result.event.events));
  assert.ok((result.event.events as Array<unknown>).length >= 2);
  const encounter = result.event.encounter as { units: Array<{ asset: string }> };
  assert.ok(encounter.units.length >= 1);
  assert.match(encounter.units[0]?.asset ?? "", /\.png$/);
});

test("every independent battle starts and returns to the map at full HP", () => {
  const originalRandom = Math.random;
  Math.random = () => 0.5;
  try {
    const cases = [
      { gridType: 1, battleKind: "battle" },
      { gridType: 2, battleKind: "elite" },
      { gridType: 3, battleKind: "challenge" },
      { gridType: 11, battleKind: "boss" },
    ] as const;
    for (const fixture of cases) {
      const state = createInitialGameState();
      state.mapGrids = Array.from({ length: state.mapTotalGrids }, () => fixture.gridType);
      state.hp = 1;
      const result = applyGameCommand(state, { level: 1, experience: 0, gold: 100 }, "roll", {});
      const battle = result.event.battle_result as { player_start_hp: number; player_max_hp: number };
      assert.equal(result.event.battleKind, fixture.battleKind);
      assert.equal(battle.player_start_hp, battle.player_max_hp, `${fixture.battleKind} should start at full HP`);
      assert.equal(result.state.hp, result.state.maxHp, `${fixture.battleKind} should return to the map at full HP`);
    }
  } finally {
    Math.random = originalRandom;
  }
});

test("a recovered battle response cannot persist battle damage into the next fight", async (context) => {
  const { directory, repository } = await setup();
  context.after(async () => { await repository.close(); await rm(directory, { recursive: true, force: true }); });
  const inviteHash = hashSecret("FULL-HP-RECOVERY-INVITE");
  repository.insertInviteCode("full-hp-recovery-invite", inviteHash);
  const account = await repository.registerAccount({ requestId: "full_hp_register", username: "full_hp_hero", passwordHash: "x", inviteCodeHash: inviteHash });
  const character = await repository.createCharacter({ id: "full-hp-character", requestId: "full_hp_character", accountId: account.id, displayName: "满血勇者", normalizedName: "满血勇者" });
  const state = await repository.getGameState(character.id);
  state.mapGrids = Array.from({ length: state.mapTotalGrids }, () => 1);
  state.hp = 1;
  repository.database.prepare("UPDATE character_states SET state_json = ? WHERE character_id = ?").run(serializeGameState(state), character.id);

  const originalRandom = Math.random;
  Math.random = () => 0.5;
  try {
    const committed = await repository.executeGameCommand({ characterId: character.id, requestId: "full_hp_roll", command: "roll", payload: {} });
    const repeated = await repository.executeGameCommand({ characterId: character.id, requestId: "full_hp_roll", command: "roll", payload: {} });
    const battle = committed.event.battle_result as { player_start_hp: number; player_max_hp: number };
    assert.equal(battle.player_start_hp, battle.player_max_hp);
    assert.deepEqual(repeated, committed);
    const recovered = await repository.getGameState(character.id);
    assert.equal(recovered.hp, recovered.maxHp);
  } finally {
    Math.random = originalRandom;
  }
});

test("boss battle triggers only when the final landing grid is the boss grid", () => {
  const originalRandom = Math.random;
  try {
    // Roll 2: the path passes through index 1 (Boss), but ends on index 2.
    Math.random = () => 0.2;
    const passedState = createInitialGameState();
    passedState.mapTotalGrids = 3;
    passedState.mapGrids = [0, 11, 0];
    passedState.gridIndex = 0;
    const passed = applyGameCommand(passedState, { level: 1, experience: 0, gold: 0 }, "roll", {});
    assert.equal(passed.state.gridIndex, 2);
    assert.equal(passed.event.gridType, 0);
    assert.equal(passed.event.kind, "home");
    assert.notEqual(passed.event.battleKind, "boss");

    // Roll 1: the final landing grid is index 1, so the Boss battle starts.
    let randomCalls = 0;
    Math.random = () => randomCalls++ === 0 ? 0 : 0.5;
    const landedState = createInitialGameState();
    landedState.mapTotalGrids = 3;
    landedState.mapGrids = [0, 11, 0];
    landedState.gridIndex = 0;
    const landed = applyGameCommand(landedState, { level: 1, experience: 0, gold: 0 }, "roll", {});
    assert.equal(landed.state.gridIndex, 1);
    assert.equal(landed.event.gridType, 11);
    assert.equal(landed.event.battleKind, "boss");
  } finally {
    Math.random = originalRandom;
  }
});

test("boss progression and formulas use the confirmed 200-tier rules", () => {
  const originalRandom = Math.random;
  Math.random = () => 0.5;
  try {
    const state = createInitialGameState();
    state.mapGrids = state.mapGrids.map(() => 11);
    state.bossTier = 199;
    state.bossIndex = 200;
    state.mapTotalGrids = 128;
    state.mapGrids = Array.from({ length: 128 }, () => 11);
    state.equipmentBag.push({ id: "boss-weapon", slot: "weapon", name: "测试武器", quality: 4, enhance: 0, mainStat: "攻击力", mainValue: 1_000_000_000, locked: true, bound: true });
    // Keep the progression fixture focused on the 200-tier formulas while
    // giving the player enough survivability to take a turn now that enemy
    // skill damage is authoritative instead of the old NaN/zero result.
    state.equipmentBag.push({ id: "boss-armor", slot: "armor", name: "测试护甲", quality: 4, enhance: 0, mainStat: "生命值", mainValue: 1_000_000_000, locked: true, bound: true });
    state.equipped.weapon = "boss-weapon";
    state.equipped.armor = "boss-armor";
    state.hp = 1_000_000_000;
    const result = applyGameCommand(state, { level: 100, experience: 0, gold: 0 }, "roll", {});
    const encounter = result.event.encounter as { units: Array<Record<string, unknown>> };
    const boss = encounter.units[0]!;
    assert.equal(boss.bossIndex, 200);
    assert.equal(boss.maxHp, Math.round((500 + 101 * 80) * (8 + 200 * 0.15)));
    assert.equal(boss.attack, Math.round((25 + 101 * 2) * (1.5 + 200 * 0.003)));
    assert.equal(boss.defense, Math.round((15 + 101) * (1.5 + 200 * 0.005)));
    assert.equal(boss.speed, 35);
    assert.equal(result.state.bossTier, 200);
    assert.equal(result.state.bossIndex, 200);
    assert.equal(result.state.mapTotalGrids, 128);
  } finally {
    Math.random = originalRandom;
  }
});

test("boss 20 finishes map expansion and boss 21 only advances difficulty", () => {
  let state = createInitialGameState();
  state.bossTier = 19;
  state.bossIndex = 20;
  state.mapTotalGrids = 123;
  state.mapGrids = Array.from({ length: 123 }, () => 11);
  state.equipmentBag.push({ id: "map-weapon", slot: "weapon", name: "测试武器", quality: 4, enhance: 0, mainStat: "攻击力", mainValue: 1_000_000_000, locked: true, bound: true });
  state.equipmentBag.push({ id: "map-armor", slot: "armor", name: "测试护甲", quality: 4, enhance: 0, mainStat: "生命值", mainValue: 1_000_000_000, locked: true, bound: true });
  state.equipped.weapon = "map-weapon";
  state.equipped.armor = "map-armor";
  state.hp = 1_000_000_000;
  const boss20 = applyGameCommand(state, { level: 100, experience: 0, gold: 0 }, "roll", {});
  assert.equal(boss20.state.bossTier, 20);
  assert.equal(boss20.state.bossIndex, 21);
  assert.equal(boss20.state.mapTotalGrids, 128);
  boss20.state.mapGrids = boss20.state.mapGrids.map(() => 11);
  const boss21 = applyGameCommand(boss20.state, boss20.character, "roll", {});
  assert.equal(boss21.state.bossTier, 21);
  assert.equal(boss21.state.bossIndex, 22);
  assert.equal(boss21.state.mapTotalGrids, 128);
  assert.equal((boss21.event.enemy as string[])[0], BOSS_NAMES[19]);
});

test("construction grids are server-owned, persistent, and upgrade only while occupied", () => {
  const originalRandom = Math.random;
  try {
    Math.random = () => 0;
    const state = createInitialGameState();
    state.mapGrids[1] = 15;
    const character = { level: 10, experience: 0, gold: 10_000 };
    const pending = applyGameCommand(state, character, "roll", {});
    assert.equal(pending.state.gridIndex, 1);
    assert.equal((pending.event as Record<string, unknown>).action, "choose");
    assert.ok(pending.state.pendingConstruction);

    const built = applyGameCommand(pending.state, pending.character, "construction_choose", { grid_index: 1, type: "shop" });
    assert.equal(built.character.gold, 5_000);
    assert.deepEqual(built.state.constructionBuildings["1"], { type: "shop", level: 1, lastCollectTurn: 0 });

    const upgraded = applyGameCommand(built.state, built.character, "construction_upgrade", { grid_index: 1 });
    assert.equal(upgraded.state.constructionBuildings["1"]?.level, 2);
    assert.equal(upgraded.character.gold, 3_500);

    upgraded.state.mapGrids[2] = 15;
    upgraded.state.gridIndex = 1;
    upgraded.state.completedLaps = 2;
    const passed = applyGameCommand(upgraded.state, upgraded.character, "roll", {});
    assert.equal((passed.event.pathEvents as Array<Record<string, unknown>> | undefined)?.length ?? 0, 0);
    const demolished = applyGameCommand(upgraded.state, upgraded.character, "construction_demolish", { grid_index: 1 });
    assert.equal(demolished.state.constructionBuildings["1"], undefined);

    const timeoutState = createInitialGameState();
    timeoutState.mapGrids[1] = 15;
    timeoutState.pendingConstruction = { gridIndex: 1, expiresAt: Date.now() - 1 };
    const timedOut = applyGameCommand(timeoutState, { level: 1, experience: 0, gold: 5_000 }, "construction_resolve", {});
    assert.equal(timedOut.state.pendingConstruction, null);
    assert.ok(timedOut.state.constructionBuildings["1"]);
  } finally {
    Math.random = originalRandom;
  }
});

test("server battle defeat atomically applies revival or home penalty state", () => {
  const originalRandom = Math.random;
  Math.random = () => 0.5;
  try {
    const state = createInitialGameState();
    state.mapGrids = Array.from({ length: state.mapTotalGrids }, () => 11);
    state.gridIndex = 0;
    state.bossTier = 199;
    state.bossIndex = 200;
    state.reviveCoins = 0;
    state.hp = state.maxHp;
    const result = applyGameCommand(state, { level: 1, experience: 0, gold: 100 }, "roll", {});
    assert.equal(result.event.battle_result?.outcome, 1);
    assert.equal(result.event.battle_result?.force_home, true);
    assert.equal(result.event.battle_result?.gold_penalty, 15);
    assert.equal(result.state.hp, result.state.maxHp);
    assert.equal(result.state.reviveCoins, 3);
    assert.equal(result.character.gold, 85);
  } finally {
    Math.random = originalRandom;
  }
});

test("the silver gem participates in the ordinary treasure pool", () => {
  const originalRandom = Math.random;
  Math.random = () => 0.99;
  try {
    const state = createInitialGameState();
    state.mapGrids = state.mapGrids.map(() => 5);
    const result = applyGameCommand(state, { level: 1, experience: 0, gold: 0 }, "roll", {});
    assert.equal(result.event.gemId, 8);
    assert.equal(result.state.gemBag.find((gem) => gem.gemId === 8)?.count, 1);
  } finally {
    Math.random = originalRandom;
  }
});

test("server-generated equipment preserves original build fields", () => {
  const originalRandom = Math.random;
  Math.random = () => 0.7;
  try {
    const state = createInitialGameState();
    state.mapGrids = state.mapGrids.map(() => 5);
    const result = applyGameCommand(state, { level: 20, experience: 0, gold: 0 }, "roll", {});
    const equipment = result.event.equipment as Record<string, unknown>;
    assert.ok(Number(equipment.quality) >= 1);
    assert.ok((equipment.affixes as unknown[]).length >= 1);
    assert.ok((equipment.affixes as unknown[]).length <= 3);
    assert.ok(typeof equipment.slotTypeId === "number");
    assert.match(String(equipment.iconPath), /^res:\/\/assets\/equipment_icons\//);
    assert.ok(Array.isArray(equipment.gems));
    assert.ok(typeof equipment.suitName === "string");
    assert.equal(result.state.equipmentBag.length, 2);
    assert.equal(equipment.slot, "armor");
  } finally {
    Math.random = originalRandom;
  }
});

test("legacy server equipment receives a stable image path when loaded", () => {
  const state = createInitialGameState();
  state.equipmentBag.push({
    id: "legacy-weapon", slot: "weapon", name: "旧武器", quality: 1, enhance: 0,
    mainStat: "攻击力", mainValue: 40, locked: false, bound: true, iconPath: "",
  });
  const first = parseGameState(serializeGameState(state));
  const second = parseGameState(serializeGameState(state));
  const firstLegacy = first.equipmentBag.find((equipment) => equipment.id === "legacy-weapon");
  const secondLegacy = second.equipmentBag.find((equipment) => equipment.id === "legacy-weapon");
  assert.match(firstLegacy?.iconPath ?? "", /^res:\/\/assets\/equipment_icons\/weapon\/icon_\d+\.png$/);
  assert.equal(firstLegacy?.iconPath, secondLegacy?.iconPath);
});

test("legacy characters without a weapon receive the starter weapon exactly once", () => {
  const legacy = createInitialGameState();
  legacy.equipmentBag = [];
  legacy.equipped.weapon = null;
  delete (legacy as Partial<typeof legacy>).starterWeaponGranted;

  const migrated = parseGameState(serializeGameState(legacy));
  assert.equal(migrated.starterWeaponGranted, true);
  assert.equal(migrated.equipmentBag.length, 1);
  assert.equal(migrated.equipmentBag[0]?.slot, "weapon");
  assert.equal(migrated.equipped.weapon, migrated.equipmentBag[0]?.id);

  const repeatedUnsavedLoad = parseGameState(serializeGameState(legacy));
  assert.equal(repeatedUnsavedLoad.equipmentBag[0]?.id, migrated.equipmentBag[0]?.id);

  const loadedAgain = parseGameState(serializeGameState(migrated));
  assert.equal(loadedAgain.equipmentBag.filter((equipment) => equipment.slot === "weapon").length, 1);
});

test("equipment rewards fill missing slots before returning to random slots", () => {
  const originalRandom = Math.random;
  Math.random = () => .7;
  try {
    const state = createInitialGameState();
    state.mapGrids = state.mapGrids.map(() => 5);
    const armorDrop = applyGameCommand(state, { level: 10, experience: 0, gold: 0 }, "roll", {});
    assert.ok(armorDrop.state.equipmentBag.some((equipment) => equipment.slot === "armor"));
    const shoesDrop = applyGameCommand(armorDrop.state, armorDrop.character, "roll", {});
    assert.ok(shoesDrop.state.equipmentBag.some((equipment) => equipment.slot === "shoes"));
  } finally {
    Math.random = originalRandom;
  }
});

test("server owns gem, socket, dismantle and reroll state transitions", () => {
  const state = createInitialGameState();
  const character = { level: 20, experience: 0, gold: 1_000_000 };
  const equipment = {
    id: "server-equip", slot: "weapon", name: "史诗武器", quality: 3, enhance: 0,
    mainStat: "攻击力", mainValue: 100, locked: false, bound: false, gemSlots: 1, initialGemSlots: 1,
    gems: [], affixes: [{ name: "攻击%", type: "attack", value: 5, display: "+5%" }], setAffixes: [],
  };
  state.equipmentBag.push(equipment);
  state.gemBag.push({ gemId: 8, level: 2, count: 3 });
  const synthesized = applyGameCommand(state, character, "gem_synthesize", { gem_id: 8, level: 2 });
  assert.equal(synthesized.state.gemBag.find((gem) => gem.gemId === 8 && gem.level === 3)?.count, 1);
  const socketed = applyGameCommand(synthesized.state, synthesized.character, "equipment_gem_socket", { equipment_id: equipment.id, socket_index: 0, gem_id: 8, level: 3 });
  assert.deepEqual(socketed.state.equipmentBag.find((item) => item.id === equipment.id)?.gems, [{ id: 8, level: 3 }]);
  const unsocketed = applyGameCommand(socketed.state, socketed.character, "equipment_gem_unsocket", { equipment_id: equipment.id, socket_index: 0 });
  assert.equal(unsocketed.state.gemBag.find((gem) => gem.gemId === 8 && gem.level === 3)?.count, 1);
  unsocketed.state.dismantleEssence = 100;
  const rerolled = applyGameCommand(unsocketed.state, unsocketed.character, "equipment_reroll", { equipment_id: equipment.id, locked_indices: [] });
  assert.equal(rerolled.state.dismantleEssence, 85);
  const dismantled = applyGameCommand(rerolled.state, rerolled.character, "equipment_dismantle", { equipment_id: equipment.id });
  assert.equal(dismantled.state.equipmentBag.some((item) => item.id === equipment.id), false);
  assert.equal(dismantled.state.equipmentBag.length, 1);
  assert.equal(dismantled.state.dismantleEssence, 105);

  const boundState = createInitialGameState();
  boundState.equipmentBag.push({ ...equipment, id: "bound-equip", gems: [] });
  boundState.gemBag.push({ gemId: 8, level: 1, count: 1, bound: true });
  const boundSocketed = applyGameCommand(boundState, character, "equipment_gem_socket", { equipment_id: "bound-equip", socket_index: 0, gem_id: 8, level: 1 });
  assert.deepEqual(boundSocketed.state.equipmentBag.find((item) => item.id === "bound-equip")?.gems, [{ id: 8, level: 1, bound: true }]);
  const boundUnsocketed = applyGameCommand(boundSocketed.state, boundSocketed.character, "equipment_gem_unsocket", { equipment_id: "bound-equip", socket_index: 0 });
  assert.equal(boundUnsocketed.state.gemBag.find((gem) => gem.gemId === 8 && gem.level === 1)?.bound, true);
});

test("one-click gem synthesis cascades all types and preserves server rules", () => {
  const state = createInitialGameState();
  state.gemBag.push(
    { gemId: 1, level: 1, count: 9 },
    { gemId: 2, level: 1, count: 3, bound: true },
    { gemId: 3, level: 9, count: 3 },
    { gemId: 4, level: 10, count: 9 },
  );
  state.gemSynthesisRefunds = 1;
  const result = applyGameCommand(state, { level: 20, experience: 0, gold: 100_000 }, "gem_synthesize_all", {});
  assert.equal(result.event.action, "synthesize_all");
  assert.equal(result.event.synthesisCount, 6);
  assert.equal(result.event.totalCost, 10_500);
  assert.equal(result.event.refundCount, 1);
  assert.equal(result.state.gemSynthesisRefunds, 0);
  assert.equal(result.character.gold, 89_500);
  assert.equal(result.state.gemBag.find((gem) => gem.gemId === 1 && gem.level === 1)?.count, 1);
  assert.equal(result.state.gemBag.some((gem) => gem.gemId === 1 && gem.level === 2), false);
  assert.equal(result.state.gemBag.find((gem) => gem.gemId === 1 && gem.level === 3)?.count, 1);
  assert.equal(result.state.gemBag.find((gem) => gem.gemId === 2 && gem.level === 2)?.bound, true);
  assert.equal(result.state.gemBag.find((gem) => gem.gemId === 3 && gem.level === 10)?.count, 1);
  assert.equal(result.state.gemBag.find((gem) => gem.gemId === 4 && gem.level === 10)?.count, 9);
});

test("one-click gem synthesis stops cleanly when gold runs out", () => {
  const state = createInitialGameState();
  state.gemBag.push({ gemId: 1, level: 1, count: 6 }, { gemId: 2, level: 1, count: 3 });
  const partial = applyGameCommand(state, { level: 1, experience: 0, gold: 1_000 }, "gem_synthesize_all", {});
  assert.equal(partial.event.synthesisCount, 1);
  assert.equal(partial.event.stoppedForGold, true);
  assert.equal(partial.character.gold, 0);
  assert.equal(partial.state.gemBag.find((gem) => gem.gemId === 1 && gem.level === 1)?.count, 3);
  assert.equal(partial.state.gemBag.find((gem) => gem.gemId === 2 && gem.level === 1)?.count, 3);

  const none = applyGameCommand(createInitialGameState(), { level: 1, experience: 0, gold: 0 }, "gem_synthesize_all", {});
  assert.equal(none.event.synthesisCount, 0);
  assert.equal(none.event.stoppedForGold, false);
  assert.equal(none.event.message, "没有可合成的宝石");
});

test("server poker reward consumes exactly three records and auto dismantle is authoritative", () => {
  const state = createInitialGameState();
  state.mapGrids = Array.from({ length: 28 }, () => 12);
  state.pokerRecords = [{ value: 1, suit: 0 }, { value: 2, suit: 0 }];
  state.autoDismantleEnabled = true;
  state.autoDismantleRules = { qualities: [4], affix_min: 0, affix_max: 8 };
  const first = applyGameCommand(state, { level: 1, experience: 0, gold: 0 }, "roll", {});
  assert.deepEqual(first.state.pokerRecords, []);
  assert.equal(typeof (first.event.poker as Record<string, unknown>).matched, "boolean");
  assert.equal((first.event.poker as Record<string, unknown>).records instanceof Array, true);
  assert.equal(((first.event.poker as Record<string, unknown>).records as unknown[]).length, 3);
});

test("auto dismantle rules may constrain only quality or only equipment slot", () => {
  const weapon = {
    id: "quality-only", slot: "weapon", slotTypeId: 1, name: "史诗武器", quality: 3, enhance: 0,
    mainStat: "攻击力", mainValue: 100, locked: false, bound: true,
    affixes: [{ name: "攻击%", type: "attack", value: 5, display: "+5%" }], setAffixes: [], initialGemSlots: 2,
  };
  const armor = { ...weapon, id: "slot-only", slot: "armor", slotTypeId: 2, name: "普通防具", quality: 0 };
  assert.equal(equipmentMatchesRule(weapon, { qualities: [3] }), true);
  assert.equal(equipmentMatchesRule(armor, { qualities: [3] }), false);
  assert.equal(equipmentMatchesRule(armor, { slots: [2] }), true);
  assert.equal(equipmentMatchesRule(weapon, { slots: [2] }), false);
  assert.equal(equipmentMatchesRule(armor, { qualities: [0], slots: [2] }), true);
  assert.equal(equipmentMatchesRule(weapon, { qualities: [3], slots: [2] }), false);
  assert.equal(equipmentMatchesRule(weapon, {}), false);

  const state = createInitialGameState();
  const saved = applyGameCommand(state, { level: 1, experience: 0, gold: 0 }, "auto_dismantle", {
    enabled: true,
    rules: { rules: [{ qualities: [3] }, { slots: [2] }] },
  });
  assert.deepEqual(saved.state.autoDismantleRules, { rules: [{ qualities: [3] }, { slots: [2] }] });
  assert.throws(
    () => applyGameCommand(saved.state, saved.character, "auto_dismantle", { enabled: true, rules: { rules: [{}] } }),
    /至少选择一项/,
  );
});

test("empty slots enhance atomically and skill priorities persist", async (context) => {
  const { directory, repository } = await setup();
  context.after(async () => { await repository.close(); await rm(directory, { recursive: true, force: true }); });
  const inviteHash = hashSecret("SLOT-TEST");
  repository.insertInviteCode("slot-invite", inviteHash);
  const account = await repository.registerAccount({ requestId: "slot_register", username: "slot_hero", passwordHash: "x", inviteCodeHash: inviteHash });
  const hero = await repository.createCharacter({ id: "slot-character", requestId: "slot_create", accountId: account.id, displayName: "槽位勇者", normalizedName: "槽位勇者" });
  repository.database.prepare("UPDATE characters SET level = 45, gold = 50_000 WHERE id = ?").run(hero.id);
  const batch = await repository.executeGameCommand({ characterId: hero.id, requestId: "slot_batch", command: "equipment_enhance", payload: { slots: ["weapon", "armor"], levels: 5 } });
  assert.equal(batch.event.price, 10_000);
  assert.equal(batch.state.slotEnhance.weapon, 5);
  assert.equal(batch.state.slotEnhance.armor, 5);
  assert.equal(batch.character.gold, 40_000);
  const repeated = await repository.executeGameCommand({ characterId: hero.id, requestId: "slot_batch", command: "equipment_enhance", payload: { slots: ["weapon", "armor"], levels: 5 } });
  assert.equal(repeated.state.slotEnhance.weapon, 5);
  await assert.rejects(repository.executeGameCommand({ characterId: hero.id, requestId: "slot_bad", command: "equipment_enhance", payload: { slots: ["weapon", "invalid"], levels: 5 } }), /装备槽位不存在/);
  const slotted = await repository.executeGameCommand({ characterId: hero.id, requestId: "slot_priority", command: "skill_slot", payload: { slots: [{ skill_id: 22, priority: 3 }, { skill_id: 1, priority: 1 }] } });
  assert.deepEqual(slotted.state.skillSlots, [22, 1]);
  assert.deepEqual((await repository.getGameState(hero.id)).skillPriorities, { "1": 1, "22": 3 });
});

test("fate card resolves on the server and empty auto-dismantle rules dismantle drops", () => {
  const random = Math.random;
  try {
    Math.random = () => 0;
    const state = createInitialGameState();
    addItem(state, 5, 1);
    const used = applyGameCommand(state, { level: 1, experience: 0, gold: 0 }, "item_use", { item_id: 5 });
    assert.equal(used.state.inventory.find((item) => item.itemId === 5), undefined);
    assert.equal((used.event.fate as Record<string, unknown>).name, "股市大涨");
    assert.equal(used.character.gold, 100);
    const chest = createInitialGameState();
    chest.autoDismantleEnabled = true;
    chest.autoDismantleRules = { qualities: [], slots: [], affix_types: [], initial_sockets: [], suits: [], affix_min: 0, affix_max: 8 };
    chest.mapGrids = chest.mapGrids.map(() => 5);
    Math.random = () => .7;
    const rolled = applyGameCommand(chest, { level: 1, experience: 0, gold: 0 }, "roll", {});
    assert.equal(rolled.state.equipmentBag.length, 1);
    assert.equal(rolled.state.equipmentBag[0]?.slot, "weapon");
    assert.ok(rolled.state.dismantleEssence > 0);
  } finally {
    Math.random = random;
  }
});

test("new fate card rewards resolve immediately and chain safely", () => {
  const originalRandom = Math.random;
  try {
    // 0.24 selects 天命降临 (the fourth weighted entry); the chained 0 selects 股市大涨.
    const rolls = [0.24, 0];
    Math.random = () => rolls.shift() ?? 0;
    const state = createInitialGameState();
    addItem(state, 5, 1);
    const result = applyGameCommand(state, { level: 1, experience: 0, gold: 1_000 }, "item_use", { item_id: 5 });
    const fate = result.event.fate as Record<string, unknown>;
    assert.equal(result.state.inventory.find((item) => item.itemId === 5), undefined);
    assert.equal(fate.cardConsumed, true);
    assert.equal((fate.chainedFate as Record<string, unknown>).name, "股市大涨");
    assert.equal(result.character.gold, 1_100);
  } finally {
    Math.random = originalRandom;
  }
});

test("fate card chaining stops at ten immediate resolutions", () => {
  const originalRandom = Math.random;
  try {
    // Always select 天命降临 to exercise the hard chain boundary.
    Math.random = () => 0.24;
    const state = createInitialGameState();
    addItem(state, 5, 1);
    const result = applyGameCommand(state, { level: 1, experience: 0, gold: 0 }, "item_use", { item_id: 5 });
    let current = result.event.fate as Record<string, unknown>;
    let count = 1;
    while (current.chainedFate) {
      current = current.chainedFate as Record<string, unknown>;
      count += 1;
    }
    assert.equal(count, 10);
    assert.equal(current.chainLimitReached, true);
    assert.equal(result.state.inventory.find((item) => item.itemId === 5), undefined);
  } finally {
    Math.random = originalRandom;
  }
});

test("demolition fate fallback uses exactly level times fifty gold", () => {
  const originalRandom = Math.random;
  try {
    // 0.72 falls in 拆迁通知 after 命运逆转 was removed (total weight 93).
    Math.random = () => .72;
    const state = createInitialGameState();
    addItem(state, 5, 1);
    const result = applyGameCommand(state, { level: 1, experience: 0, gold: 100 }, "item_use", { item_id: 5 });
    assert.equal(result.character.gold, 50);
    assert.equal((result.event.fate as Record<string, unknown>).gold, -50);
  } finally {
    Math.random = originalRandom;
  }
});

test("repeated fate buffs accumulate with the documented nine-battle cap", () => {
  const originalRandom = Math.random;
  try {
    // 0.15 lands on 技能大赛 in the authoritative weighted event pool.
    Math.random = () => 0.15;
    const state = createInitialGameState();
    addItem(state, 5, 3);
    const character = { level: 1, experience: 0, gold: 0 };
    let current = state;
    let currentCharacter = character;
    for (let index = 0; index < 3; index += 1) {
      const result = applyGameCommand(current, currentCharacter, "item_use", { item_id: 5 });
      current = result.state;
      currentCharacter = result.character;
    }
    assert.equal(current.buffs.skillBoost, 9);
  } finally {
    Math.random = originalRandom;
  }
});

test("offline progress is atomic, capped at 12 hours and cannot be claimed twice", async (context) => {
  const { directory, repository } = await setup();
  context.after(async () => { await repository.close(); await rm(directory, { recursive: true, force: true }); });
  const inviteHash = hashSecret("OFFLINE-TEST");
  repository.insertInviteCode("offline-invite", inviteHash);
  const account = await repository.registerAccount({ requestId: "offline_register", username: "offline_hero", passwordHash: "x", inviteCodeHash: inviteHash });
  const hero = await repository.createCharacter({ id: "offline-character", requestId: "offline_create", accountId: account.id, displayName: "离线勇者", normalizedName: "离线勇者" });
  const now = Date.now();
  const state = createInitialGameState();
  state.lastOnline = now - 36 * 60 * 60_000;
  state.lastGoldPerHour = 1_000;
  state.lastExpPerHour = 2_000;
  repository.database.prepare("UPDATE character_states SET state_json = ? WHERE character_id = ?").run(serializeGameState(state), hero.id);
  const claimed = await repository.claimOfflineProgress(hero.id, new Date(now));
  assert.deepEqual(claimed.reward, { seconds: 43_200, gold: 1_200, experience: 2_400 });
  assert.equal(claimed.character.gold, "1200");
  assert.equal(claimed.state.freeAttributePoints, (claimed.character.level - 1) * 2);
  const repeated = await repository.claimOfflineProgress(hero.id, new Date(now + 1_000));
  assert.equal(repeated.reward, null);
  assert.equal(repeated.character.gold, "1200");
  assert.equal((await repository.getGameState(hero.id)).lastOnline, now + 1_000);
});

test("HTTP login claims offline progress once; state reads and password changes do not reissue it", async (context) => {
  const { directory, repository } = await setup();
  context.after(async () => { await repository.close(); await rm(directory, { recursive: true, force: true }); });
  const inviteHash = hashSecret("HTTP-OFFLINE");
  repository.insertInviteCode("http-offline-invite", inviteHash);
  const account = await repository.registerAccount({ requestId: "http_offline_register", username: "http_offline", passwordHash: "test:Good-password-2026", inviteCodeHash: inviteHash });
  const hero = await repository.createCharacter({ id: "http-offline-character", requestId: "http_offline_create", accountId: account.id, displayName: "网页离线勇者", normalizedName: "网页离线勇者" });
  const now = Date.now();
  const initial = await repository.getGameState(hero.id);
  initial.lastOnline = now - 3_600_000;
  initial.lastGoldPerHour = 1_000;
  initial.lastExpPerHour = 2_000;
  repository.database.prepare("UPDATE character_states SET state_json = ? WHERE character_id = ?").run(serializeGameState(initial), hero.id);
  const app = await buildApp({ repository, passwordHasher: new TestHasher(), now: () => now });
  const login = await app.inject({ method: "POST", url: "/api/v1/auth/login", payload: { rules_version: "network-1", username: "http_offline", password: "Good-password-2026" } });
  assert.equal(login.statusCode, 200);
  assert.deepEqual(login.json().offline_reward, { seconds: 3_600, gold: 100, experience: 200 });
  const headers = { authorization: `Bearer ${login.json().session.token as string}` };
  const first = await app.inject({ method: "GET", url: "/api/v1/game/state", headers });
  const second = await app.inject({ method: "GET", url: "/api/v1/game/state", headers });
  assert.equal(first.statusCode, 200);
  assert.deepEqual(first.json(), second.json());
  assert.equal(first.json().character.gold, "100");
  assert.equal(first.json().offline_reward, undefined);
  const changed = await app.inject({ method: "POST", url: "/api/v1/auth/change-password", headers, payload: { rules_version: "network-1", password: "Different-password-2026", password_confirm: "Different-password-2026" } });
  assert.equal(changed.statusCode, 200);
  assert.equal((await repository.findAccountForLogin(account.username))?.passwordHash, "test:Different-password-2026");
  const again = await app.inject({ method: "POST", url: "/api/v1/auth/login", payload: { rules_version: "network-1", username: "http_offline", password: "Different-password-2026" } });
  assert.equal(again.json().offline_reward, null);
  await app.close();
});
