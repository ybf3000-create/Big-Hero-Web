import assert from "node:assert/strict";
import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import { buildApp } from "../src/app.js";
import { applyGameCommand, createInitialGameState } from "../src/game-engine.js";
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

test("game state survives commands and repeated roll requests are idempotent", async (context) => {
  const { directory, repository } = await setup();
  context.after(async () => { await repository.close(); await rm(directory, { recursive: true, force: true }); });
  const inviteHash = hashSecret("GAME-FLOW-INVITE");
  repository.insertInviteCode("game-flow-invite", inviteHash);
  const account = await repository.registerAccount({ requestId: "game_register_1", username: "game_hero", passwordHash: "test:Good-password-2026", inviteCodeHash: inviteHash });
  const character = await repository.createCharacter({ id: "game-character", requestId: "game_character_1", accountId: account.id, displayName: "测试勇者", normalizedName: "测试勇者" });
  const before = await repository.getGameState(character.id);
  assert.equal(before.inventory[0]?.count, 3);
  const first = await repository.executeGameCommand({ characterId: character.id, requestId: "game_roll_01", command: "roll", payload: {} });
  const repeated = await repository.executeGameCommand({ characterId: character.id, requestId: "game_roll_01", command: "roll", payload: {} });
  assert.deepEqual(repeated, first);
  assert.equal((await repository.getGameState(character.id)).lastDiceRoll, first.state.lastDiceRoll);
});

test("dice, skill slots, equipment locks and enhancement limits enforce game rules", () => {
  let state = createInitialGameState();
  const character = { level: 1, experience: 0, gold: 10_000_000 };
  for (let index = 0; index < 100; index += 1) {
    const result = applyGameCommand(state, character, "roll", {});
    state = result.state;
    assert.ok((state.lastDiceRoll ?? 0) >= 1 && (state.lastDiceRoll ?? 7) <= 6);
  }
  const locked = applyGameCommand(state, character, "equipment_lock", { equipment_id: "starter-sword", locked: true });
  assert.equal(locked.state.equipmentBag.find((item) => item.id === "starter-sword")?.locked, true);
  const maxed = createInitialGameState();
  const sword = maxed.equipmentBag.find((item) => item.id === "starter-sword");
  assert.ok(sword);
  maxed.slotEnhance.weapon = 200;
  assert.throws(() => applyGameCommand(maxed, character, "equipment_enhance", { equipment_id: sword.id }), /强化上限/);
  const limited = { ...createInitialGameState(), skills: [1, 2, 3, 22], skillSlots: [1, 22] };
  const slotted = applyGameCommand(limited, character, "skill_slot", { skill_id: 2, slots: [1, 22, 2] });
  assert.deepEqual(slotted.state.skillSlots, [1, 22]);
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
  repository.database.prepare("UPDATE characters SET gold = 1000 WHERE id = ?").run(buyerCharacter.id);
  const listing = await repository.createAuctionListing({ characterId: sellerCharacter.id, requestId: "auction_list_1", itemKind: "item", itemId: 1, itemCount: 1, buyoutPrice: 100, durationHours: 24 });
  await assert.rejects(repository.buyAuctionListing(sellerCharacter.id, "auction_self_1", listing.id), /不能购买自己的订单/);
  const purchased = await repository.buyAuctionListing(buyerCharacter.id, "auction_buy_1", listing.id);
  const repeated = await repository.buyAuctionListing(buyerCharacter.id, "auction_buy_1", listing.id);
  assert.equal(purchased.gold, 900);
  assert.equal(repeated.gold, 900);
  assert.equal(purchased.listing.status, "sold");
  assert.equal((await repository.getGameState(buyerCharacter.id)).inventory.find((item) => item.itemId === 1)?.count, 4);
  const claimed = await repository.claimAuctionListing(sellerCharacter.id, listing.id);
  assert.equal(claimed.gold, 95);
});

test("auction price and active listing boundaries are enforced", async (context) => {
  const { directory, repository } = await setup();
  context.after(async () => { await repository.close(); await rm(directory, { recursive: true, force: true }); });
  const inviteHash = hashSecret("AUCTION-LIMITS");
  repository.insertInviteCode("auction-limits", inviteHash);
  const account = await repository.registerAccount({ requestId: "limits_register_1", username: "limit_hero", passwordHash: "x", inviteCodeHash: inviteHash });
  const character = await repository.createCharacter({ id: "limit-character", requestId: "limits_character_1", accountId: account.id, displayName: "边界勇者", normalizedName: "边界勇者" });
  await assert.rejects(repository.createAuctionListing({ characterId: character.id, requestId: "limits_price_0", itemKind: "item", itemId: 1, itemCount: 1, buyoutPrice: 0, durationHours: 24 }), /价格需为正整数/);
  for (let index = 0; index < 3; index += 1) {
    await repository.createAuctionListing({ characterId: character.id, requestId: `limits_list_${index}`, itemKind: "item", itemId: 1, itemCount: 1, buyoutPrice: index + 1, durationHours: 24 });
  }
  await assert.rejects(repository.createAuctionListing({ characterId: character.id, requestId: "limits_list_4", itemKind: "item", itemId: 1, itemCount: 1, buyoutPrice: 4, durationHours: 24 }), /最多同时上架3件/);
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
  const state = await app.inject({ method: "GET", url: "/api/v1/game/state", headers: { authorization: `Bearer ${token}` } });
  assert.equal(state.statusCode, 200);
  const roll = await app.inject({ method: "POST", url: "/api/v1/game/roll", headers: { authorization: `Bearer ${token}` }, payload: { rules_version: "network-1", request_id: "http_roll_01", payload: {} } });
  assert.equal(roll.statusCode, 200);
  assert.equal(typeof roll.json().event.dice, "number");
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
