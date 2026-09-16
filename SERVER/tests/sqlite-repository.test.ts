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
    ).get() as { count: number }).count >= 2,
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
