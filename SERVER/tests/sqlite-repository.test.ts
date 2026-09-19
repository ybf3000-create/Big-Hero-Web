import assert from "node:assert/strict";
import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";
import { AppError } from "../src/errors.js";
import { applyMigrations } from "../src/migrations.js";
import { hashSecret } from "../src/security.js";
import { SqliteRepository } from "../src/sqlite-repository.js";

const migrationsDirectory = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../db/migrations",
);

async function createTestRepository(): Promise<{
  directory: string;
  repository: SqliteRepository;
}> {
  const directory = await mkdtemp(path.join(tmpdir(), "big-hero-sqlite-"));
  const repository = new SqliteRepository(path.join(directory, "game.sqlite"));
  applyMigrations(repository.database, migrationsDirectory);
  return { directory, repository };
}

function appErrorCode(code: string): (error: unknown) => boolean {
  return (error) => error instanceof AppError && error.code === code;
}

test("SQLite migrations and durability settings are active", async (context) => {
  const { directory, repository } = await createTestRepository();
  context.after(async () => {
    await repository.close();
    await rm(directory, { recursive: true, force: true });
  });

  applyMigrations(repository.database, migrationsDirectory);
  assert.equal(repository.database.pragma("journal_mode", { simple: true }), "wal");
  assert.equal(repository.database.pragma("foreign_keys", { simple: true }), 1);
  assert.equal(repository.database.pragma("busy_timeout", { simple: true }), 5_000);
  assert.equal(repository.database.pragma("synchronous", { simple: true }), 2);
  assert.ok(
    (repository.database.prepare(
      "SELECT count(*) AS count FROM schema_migrations",
    ).get() as { count: number }).count >= 3,
  );
});

test("SQLite account registration is idempotent and rolls back failed inserts", async (context) => {
  const { directory, repository } = await createTestRepository();
  context.after(async () => {
    await repository.close();
    await rm(directory, { recursive: true, force: true });
  });

  const firstInvite = hashSecret("SQLITE-FIRST");
  const duplicateInvite = hashSecret("SQLITE-DUPLICATE");
  repository.insertInviteCode("invite-first", firstInvite);
  repository.insertInviteCode("invite-duplicate", duplicateInvite);

  const first = await repository.registerAccount({
    requestId: "sqlite_register_1",
    username: "sqlite_hero",
    passwordHash: "hash:first",
    inviteCodeHash: firstInvite,
  });
  const repeated = await repository.registerAccount({
    requestId: "sqlite_register_1",
    username: "sqlite_hero",
    passwordHash: "hash:first",
    inviteCodeHash: firstInvite,
  });
  assert.deepEqual(repeated, first);

  await assert.rejects(
    repository.registerAccount({
      requestId: "sqlite_register_2",
      username: "sqlite_hero",
      passwordHash: "hash:second",
      inviteCodeHash: duplicateInvite,
    }),
    appErrorCode("ACCOUNT_UNAVAILABLE"),
  );
  const invite = repository.database.prepare(
    "SELECT status FROM invite_codes WHERE id = ?",
  ).get("invite-duplicate") as { status: string };
  assert.equal(invite.status, "available");
});

test("SQLite enforces single-character and single-active-session rules", async (context) => {
  const { directory, repository } = await createTestRepository();
  context.after(async () => {
    await repository.close();
    await rm(directory, { recursive: true, force: true });
  });

  const inviteHash = hashSecret("SQLITE-ASSETS");
  repository.insertInviteCode("invite-assets", inviteHash);
  const account = await repository.registerAccount({
    requestId: "sqlite_register_assets",
    username: "asset_hero",
    passwordHash: "hash:assets",
    inviteCodeHash: inviteHash,
  });

  const character = await repository.createCharacter({
    id: "character-first",
    requestId: "sqlite_character_1",
    accountId: account.id,
    displayName: "资产勇者",
    normalizedName: "资产勇者",
  });
  assert.equal(character.gold, "0");
  await assert.rejects(
    repository.createCharacter({
      id: "character-second",
      requestId: "sqlite_character_2",
      accountId: account.id,
      displayName: "第二勇者",
      normalizedName: "第二勇者",
    }),
    appErrorCode("CHARACTER_EXISTS"),
  );

  const createdAt = new Date("2026-09-14T00:00:00.000Z");
  await repository.createSession({
    id: "session-old",
    accountId: account.id,
    tokenHash: hashSecret("token-old"),
    createdAt,
    idleExpiresAt: new Date(createdAt.getTime() + 30 * 60_000),
    expiresAt: new Date(createdAt.getTime() + 7 * 24 * 60 * 60_000),
  });
  await repository.createSession({
    id: "session-new",
    accountId: account.id,
    tokenHash: hashSecret("token-new"),
    createdAt: new Date(createdAt.getTime() + 1_000),
    idleExpiresAt: new Date(createdAt.getTime() + 30 * 60_000),
    expiresAt: new Date(createdAt.getTime() + 7 * 24 * 60 * 60_000),
  });

  const sessions = repository.database.prepare(
    `SELECT id, revoked_at, revoke_reason
       FROM sessions
      WHERE account_id = ?
      ORDER BY created_at`,
  ).all(account.id) as Array<{
    id: string;
    revoked_at: number | null;
    revoke_reason: string | null;
  }>;
  assert.equal(sessions.length, 2);
  assert.equal(sessions[0]?.revoke_reason, "replaced_by_new_login");
  assert.equal(sessions[1]?.revoked_at, null);
});

test("SQLite character deletion is confirmed, complete, and account-preserving", async (context) => {
  const { directory, repository } = await createTestRepository();
  context.after(async () => {
    await repository.close();
    await rm(directory, { recursive: true, force: true });
  });

  const inviteHash = hashSecret("SQLITE-CHARACTER-DELETE");
  repository.insertInviteCode("invite-character-delete", inviteHash);
  const account = await repository.registerAccount({
    requestId: "sqlite_register_character_delete",
    username: "delete_hero",
    passwordHash: "hash:delete",
    inviteCodeHash: inviteHash,
  });
  const hero = await repository.createCharacter({
    id: "character-delete",
    requestId: "sqlite_character_delete",
    accountId: account.id,
    displayName: "待删除勇者",
    normalizedName: "待删除勇者",
  });
  const state = await repository.getGameState(hero.id);
  state.inventory.push({ itemId: 6, count: 1 });
  repository.database.prepare("UPDATE character_states SET state_json = ? WHERE character_id = ?").run(JSON.stringify(state), hero.id);
  const message = await repository.createChatMessage({
    accountId: account.id,
    body: "删除前的聊天记录",
    clientMessageId: "delete-chat-1",
  });
  repository.database.prepare(
    "INSERT INTO chat_blocks (account_id, blocked_character_id) VALUES (?, ?)",
  ).run(account.id, hero.id);
  const listing = await repository.createAuctionListing({
    characterId: hero.id,
    requestId: "delete-listing-1",
    itemKind: "item",
    itemId: 6,
    itemCount: 1,
    buyoutPrice: 100,
    durationHours: 24,
  });
  repository.database.prepare(
    "INSERT INTO game_commands (character_id, request_id, command, result_json) VALUES (?, ?, ?, ?)",
  ).run(hero.id, "delete-command-1", "test", "{}");

  await assert.rejects(
    repository.deleteCharacter(account.id, hero.id, "不是这个角色"),
    appErrorCode("CHARACTER_CONFIRMATION_REQUIRED"),
  );
  assert.equal(await repository.getCharacter(account.id) !== null, true);

  await repository.deleteCharacter(account.id, hero.id, hero.name);
  assert.equal(await repository.getCharacter(account.id), null);
  assert.equal((await repository.findAccountForLogin(account.username))?.id, account.id);
  assert.equal((repository.database.prepare("SELECT count(*) AS count FROM character_states WHERE character_id = ?").get(hero.id) as { count: number }).count, 0);
  assert.equal((repository.database.prepare("SELECT count(*) AS count FROM game_commands WHERE character_id = ?").get(hero.id) as { count: number }).count, 0);
  assert.equal((repository.database.prepare("SELECT count(*) AS count FROM chat_blocks WHERE blocked_character_id = ?").get(hero.id) as { count: number }).count, 0);
  assert.equal((repository.database.prepare("SELECT sender_character_id FROM chat_messages WHERE id = ?").get(message.id) as { sender_character_id: string | null }).sender_character_id, null);
  assert.equal((repository.database.prepare("SELECT count(*) AS count FROM auction_listings WHERE id = ?").get(listing.id) as { count: number }).count, 0);
  assert.equal((repository.database.prepare("SELECT count(*) AS count FROM audit_events WHERE event_type = 'character.deleted'").get() as { count: number }).count, 1);

  const recreated = await repository.createCharacter({
    id: "character-recreated",
    requestId: "sqlite_character_recreated",
    accountId: account.id,
    displayName: hero.name,
    normalizedName: "待删除勇者",
  });
  assert.equal(recreated.name, hero.name);
});

test("SQLite character deletion does not erase a seller order when the deleted role was the buyer", async (context) => {
  const { directory, repository } = await createTestRepository();
  context.after(async () => {
    await repository.close();
    await rm(directory, { recursive: true, force: true });
  });

  const sellerInvite = hashSecret("SQLITE-SELLER");
  const buyerInvite = hashSecret("SQLITE-BUYER");
  repository.insertInviteCode("invite-seller", sellerInvite);
  repository.insertInviteCode("invite-buyer", buyerInvite);
  const sellerAccount = await repository.registerAccount({ requestId: "register-seller", username: "seller_hero", passwordHash: "hash:seller", inviteCodeHash: sellerInvite });
  const buyerAccount = await repository.registerAccount({ requestId: "register-buyer", username: "buyer_hero", passwordHash: "hash:buyer", inviteCodeHash: buyerInvite });
  const seller = await repository.createCharacter({ id: "seller-character", requestId: "create-seller", accountId: sellerAccount.id, displayName: "卖家勇者", normalizedName: "卖家勇者" });
  const buyer = await repository.createCharacter({ id: "buyer-character", requestId: "create-buyer", accountId: buyerAccount.id, displayName: "买家勇者", normalizedName: "买家勇者" });
  const sellerState = await repository.getGameState(seller.id);
  sellerState.inventory.push({ itemId: 6, count: 1 });
  repository.database.prepare("UPDATE character_states SET state_json = ? WHERE character_id = ?").run(JSON.stringify(sellerState), seller.id);
  repository.database.prepare("UPDATE characters SET gold = 1000 WHERE id = ?").run(buyer.id);
  const listing = await repository.createAuctionListing({ characterId: seller.id, requestId: "seller-listing", itemKind: "item", itemId: 6, itemCount: 1, buyoutPrice: 100, durationHours: 24 });
  await repository.buyAuctionListing(buyer.id, "buyer-purchase", listing.id);

  await repository.deleteCharacter(buyerAccount.id, buyer.id, buyer.name);
  const retained = repository.database.prepare("SELECT status, seller_character_id, buyer_character_id, claim_character_id FROM auction_listings WHERE id = ?").get(listing.id) as { status: string; seller_character_id: string; buyer_character_id: string | null; claim_character_id: string };
  assert.equal(retained.status, "sold");
  assert.equal(retained.seller_character_id, seller.id);
  assert.equal(retained.buyer_character_id, null);
  assert.equal(retained.claim_character_id, seller.id);
  assert.equal(await repository.getCharacter(buyerAccount.id), null);
});

test("SQLite stores only remembered-login hashes and invalidates them after password changes", async (context) => {
  const { directory, repository } = await createTestRepository();
  context.after(async () => {
    await repository.close();
    await rm(directory, { recursive: true, force: true });
  });
  const inviteHash = hashSecret("SQLITE-REMEMBER");
  repository.insertInviteCode("invite-remember", inviteHash);
  const account = await repository.registerAccount({
    requestId: "sqlite_register_remember",
    username: "remember_hero",
    passwordHash: "hash:secret-password",
    inviteCodeHash: inviteHash,
  });
  const issuedAt = new Date("2026-09-17T00:00:00.000Z");
  const firstToken = "plain-remember-token";
  await repository.createRememberedLogin({
    id: "remember-first",
    accountId: account.id,
    tokenHash: hashSecret(firstToken),
    createdAt: issuedAt,
    expiresAt: new Date(issuedAt.getTime() + 30 * 24 * 60 * 60_000),
  });
  const stored = repository.database.prepare(
    "SELECT token_hash FROM remembered_logins WHERE id = ?",
  ).get("remember-first") as { token_hash: string };
  assert.notEqual(stored.token_hash, firstToken);
  assert.equal((await repository.findAccountForRememberedLogin(hashSecret(firstToken), issuedAt))?.id, account.id);

  const secondToken = "rotated-remember-token";
  assert.equal(await repository.rotateRememberedLogin({
    id: "remember-second",
    accountId: account.id,
    previousTokenHash: hashSecret(firstToken),
    tokenHash: hashSecret(secondToken),
    createdAt: new Date(issuedAt.getTime() + 1_000),
    expiresAt: new Date(issuedAt.getTime() + 30 * 24 * 60 * 60_000),
  }), true);
  assert.equal(await repository.findAccountForRememberedLogin(hashSecret(firstToken), issuedAt), null);
  assert.equal((await repository.findAccountForRememberedLogin(hashSecret(secondToken), issuedAt))?.id, account.id);

  const replacementToken = "replacement-remember-token";
  await repository.createRememberedLogin({
    id: "remember-replacement",
    accountId: account.id,
    tokenHash: hashSecret(replacementToken),
    createdAt: new Date(issuedAt.getTime() + 2_000),
    expiresAt: new Date(issuedAt.getTime() + 30 * 24 * 60 * 60_000),
  });
  assert.equal(await repository.findAccountForRememberedLogin(hashSecret(secondToken), issuedAt), null);
  assert.equal((await repository.findAccountForRememberedLogin(hashSecret(replacementToken), issuedAt))?.id, account.id);

  await repository.updateAccountPassword(account.id, "hash:new-password");
  assert.equal(await repository.findAccountForRememberedLogin(hashSecret(replacementToken), issuedAt), null);
});

test("SQLite chat persists messages, supports retries, and honors mutes", async (context) => {
  const { directory, repository } = await createTestRepository();
  context.after(async () => {
    await repository.close();
    await rm(directory, { recursive: true, force: true });
  });

  const inviteHash = hashSecret("SQLITE-CHAT");
  repository.insertInviteCode("invite-chat", inviteHash);
  const account = await repository.registerAccount({
    requestId: "sqlite_register_chat",
    username: "chat_hero",
    passwordHash: "hash:chat",
    inviteCodeHash: inviteHash,
  });
  await repository.createCharacter({
    id: "character-chat",
    requestId: "sqlite_character_chat",
    accountId: account.id,
    displayName: "聊天勇者",
    normalizedName: "聊天勇者",
  });

  const first = await repository.createChatMessage({
    accountId: account.id,
    body: "大家好",
    clientMessageId: "chat_message_1",
  });
  const repeated = await repository.createChatMessage({
    accountId: account.id,
    body: "这条内容不会重复插入",
    clientMessageId: "chat_message_1",
  });
  assert.deepEqual(repeated, first);
  assert.deepEqual(await repository.listChatMessages("world", 10), [first]);

  const now = Date.now();
  repository.database.prepare(
    `INSERT INTO chat_mutes (account_id, reason, starts_at, ends_at)
     VALUES (?, ?, ?, ?)`,
  ).run(account.id, "test", now - 1000, now + 60_000);
  await assert.rejects(
    repository.createChatMessage({
      accountId: account.id,
      body: "不应发送",
      clientMessageId: "chat_message_2",
    }),
    appErrorCode("CHAT_MUTED"),
  );
});

test("local admin enforces 72-hour limits, temporary passwords and auction-safe deletion", async (context) => {
  const { directory, repository } = await createTestRepository();
  context.after(async () => { await repository.close(); await rm(directory, { recursive: true, force: true }); });
  const inviteHash = hashSecret("ADMIN-TEST");
  repository.insertInviteCode("admin-invite", inviteHash);
  const account = await repository.registerAccount({ requestId: "admin_register", username: "admin_hero", passwordHash: "old-hash", inviteCodeHash: inviteHash });
  const hero = await repository.createCharacter({ id: "admin-character", requestId: "admin_create", accountId: account.id, displayName: "管理测试", normalizedName: "管理测试" });
  assert.throws(() => repository.setBanForAdmin(account.username, 73, "over limit"), /1至72/);
  assert.throws(() => repository.setMuteForAdmin(account.username, 0, "under limit"), /1至72/);
  repository.setBanForAdmin(account.username, 72, "test");
  assert.equal((await repository.findAccountForLogin(account.username))?.status, "banned");
  repository.setBanForAdmin(account.username, null, "cleared");
  repository.setMuteForAdmin(account.username, 1, "test");
  await assert.rejects(repository.createChatMessage({ accountId: account.id, body: "禁言中", clientMessageId: "admin_mute_01" }), appErrorCode("CHAT_MUTED"));
  repository.setMuteForAdmin(account.username, null, "cleared");
  await repository.resetPasswordForAdmin(account.username, "temporary-hash");
  assert.equal((await repository.findAccountForLogin(account.username))?.mustChangePassword, true);
  await repository.updateAccountPassword(account.id, "new-hash");
  assert.equal((await repository.findAccountForLogin(account.username))?.mustChangePassword, false);
  const state = await repository.getGameState(hero.id);
  state.inventory.push({ itemId: 6, count: 1 });
  repository.database.prepare("UPDATE character_states SET state_json = ? WHERE character_id = ?").run(JSON.stringify(state), hero.id);
  const listing = await repository.createAuctionListing({ characterId: hero.id, requestId: "admin_listing", itemKind: "item", itemId: 6, itemCount: 1, buyoutPrice: 100, durationHours: 24 });
  assert.throws(() => repository.deleteAccountForAdmin(account.username, "test"), /未领取的拍卖订单/);
  assert.equal((await repository.findAccountForLogin(account.username))?.status, "normal");
  await repository.cancelAuctionListing(hero.id, listing.id);
  await repository.claimAuctionListing(hero.id, "admin_claim", listing.id);
  repository.deleteAccountForAdmin(account.username, "test");
  assert.equal((await repository.findAccountForLogin(account.username))?.status, "deleted");
  assert.equal(await repository.getCharacter(account.id), null);
});
