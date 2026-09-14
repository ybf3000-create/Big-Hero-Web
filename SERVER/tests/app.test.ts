import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { once } from "node:events";
import test from "node:test";
import { buildApp } from "../src/app.js";
import { AppError } from "../src/errors.js";
import type {
  AccountForLogin,
  AccountSummary,
  CharacterSummary,
  CreateCharacterInput,
  CreateSessionInput,
  GameRepository,
  RegisterAccountInput,
} from "../src/repository.js";
import { hashSecret, type PasswordHasher } from "../src/security.js";

class FakeHasher implements PasswordHasher {
  async hash(password: string): Promise<string> {
    return `hash:${password}`;
  }

  async verify(encodedHash: string, password: string): Promise<boolean> {
    return encodedHash === `hash:${password}`;
  }
}

class MemoryRepository implements GameRepository {
  readonly invites = new Set<string>();
  readonly accounts = new Map<string, AccountForLogin>();
  readonly registrationRequests = new Map<string, AccountSummary>();
  readonly characters = new Map<string, CharacterSummary>();
  readonly creationRequests = new Map<string, CharacterSummary>();
  readonly sessions = new Map<string, CreateSessionInput>();
  failLoginAudit = false;

  async ping(): Promise<void> {}
  async close(): Promise<void> {}

  async registerAccount(input: RegisterAccountInput): Promise<AccountSummary> {
    const repeated = this.registrationRequests.get(input.requestId);
    if (repeated) {
      if (repeated.username !== input.username) {
        throw new AppError("REQUEST_ID_REUSED", 409, "request_id已被使用");
      }
      return repeated;
    }
    if (!this.invites.delete(input.inviteCodeHash)) {
      throw new AppError("INVITE_INVALID", 400, "邀请码无效");
    }
    if (this.accounts.has(input.username)) {
      throw new AppError("ACCOUNT_UNAVAILABLE", 409, "该账号不可用");
    }
    const account: AccountForLogin = {
      id: randomUUID(),
      username: input.username,
      passwordHash: input.passwordHash,
      status: "normal",
      bannedUntil: null,
      mustChangePassword: false,
    };
    this.accounts.set(input.username, account);
    const summary = { id: account.id, username: account.username };
    this.registrationRequests.set(input.requestId, summary);
    return summary;
  }

  async findAccountForLogin(username: string): Promise<AccountForLogin | null> {
    return this.accounts.get(username) ?? null;
  }

  async createSession(input: CreateSessionInput): Promise<void> {
    for (const [id, session] of this.sessions) {
      if (session.accountId === input.accountId) {
        this.sessions.delete(id);
      }
    }
    this.sessions.set(input.id, input);
  }

  async touchSession(): Promise<void> {}

  async revokeSession(sessionId: string): Promise<void> {
    this.sessions.delete(sessionId);
  }

  async revokeAccountSessions(accountId: string): Promise<void> {
    for (const [id, session] of this.sessions) {
      if (session.accountId === accountId) {
        this.sessions.delete(id);
      }
    }
  }

  async recordLoginAttempt(): Promise<void> {
    if (this.failLoginAudit) {
      throw new Error("login audit unavailable");
    }
  }

  async getCharacter(accountId: string): Promise<CharacterSummary | null> {
    return this.characters.get(accountId) ?? null;
  }

  async createCharacter(input: CreateCharacterInput): Promise<CharacterSummary> {
    const repeated = this.creationRequests.get(input.requestId);
    if (repeated) {
      return repeated;
    }
    if (this.characters.has(input.accountId)) {
      throw new AppError("CHARACTER_EXISTS", 409, "每个账号只能创建一个角色");
    }
    for (const character of this.characters.values()) {
      if (character.name.toLowerCase() === input.normalizedName) {
        throw new AppError("CHARACTER_NAME_UNAVAILABLE", 409, "该角色名已被使用");
      }
    }
    const character: CharacterSummary = {
      id: input.id,
      name: input.displayName,
      level: 1,
      experience: 0,
      gold: "0",
      revision: 1,
    };
    this.characters.set(input.accountId, character);
    this.creationRequests.set(input.requestId, character);
    return character;
  }
}

async function register(
  app: Awaited<ReturnType<typeof buildApp>>,
  inviteCode: string,
  username: string,
  requestId: string,
) {
  return app.inject({
    method: "POST",
    url: "/api/v1/auth/register",
    payload: {
      request_id: requestId,
      rules_version: "network-1",
      invite_code: inviteCode,
      username,
      password: "Good-password-2026",
      password_confirm: "Good-password-2026",
    },
  });
}

test("register, login and single-character flow uses stable public contracts", async () => {
  const repository = new MemoryRepository();
  repository.invites.add(hashSecret("FIRSTINVITE"));
  repository.invites.add(hashSecret("SECONDINVITE"));
  const app = await buildApp({
    repository,
    passwordHasher: new FakeHasher(),
    maxOnlinePlayers: 1,
  });

  const registered = await register(app, "FIRSTINVITE", "Hero_01", "register_001");
  assert.equal(registered.statusCode, 201);

  const login = await app.inject({
    method: "POST",
    url: "/api/v1/auth/login",
    payload: {
      rules_version: "network-1",
      username: "hero_01",
      password: "Good-password-2026",
    },
  });
  assert.equal(login.statusCode, 200);
  const token = login.json().session.token as string;
  const websocket = await app.injectWS("/ws");
  websocket.send(JSON.stringify({ type: "authenticate", token }));
  const [authenticationPacket] = await once(websocket, "message");
  assert.equal(
    JSON.parse(authenticationPacket.toString()).type,
    "authenticated",
  );
  websocket.send(JSON.stringify({ type: "heartbeat" }));
  const [heartbeatPacket] = await once(websocket, "message");
  assert.equal(JSON.parse(heartbeatPacket.toString()).type, "heartbeat_ack");
  const closed = once(websocket, "close");
  websocket.terminate();
  await closed;

  const character = await app.inject({
    method: "POST",
    url: "/api/v1/characters",
    headers: { authorization: `Bearer ${token}` },
    payload: {
      request_id: "character_001",
      rules_version: "network-1",
      name: "勇者Hero2026",
    },
  });
  assert.equal(character.statusCode, 201);
  assert.equal(character.json().character.name, "勇者Hero2026");

  const duplicateCharacter = await app.inject({
    method: "POST",
    url: "/api/v1/characters",
    headers: { authorization: `Bearer ${token}` },
    payload: {
      request_id: "character_002",
      rules_version: "network-1",
      name: "另一个名字",
    },
  });
  assert.equal(duplicateCharacter.statusCode, 409);
  assert.equal(duplicateCharacter.json().error.code, "CHARACTER_EXISTS");

  assert.equal((await register(app, "SECONDINVITE", "Hero_02", "register_002")).statusCode, 201);
  const full = await app.inject({
    method: "POST",
    url: "/api/v1/auth/login",
    payload: {
      rules_version: "network-1",
      username: "hero_02",
      password: "Good-password-2026",
    },
  });
  assert.equal(full.statusCode, 503);
  assert.equal(full.json().error.code, "SERVER_FULL");

  const replacement = await app.inject({
    method: "POST",
    url: "/api/v1/auth/login",
    payload: {
      rules_version: "network-1",
      username: "hero_01",
      password: "Good-password-2026",
    },
  });
  assert.equal(replacement.statusCode, 200);
  await app.close();
});

test("login audit failures do not change authentication results", async () => {
  const repository = new MemoryRepository();
  repository.invites.add(hashSecret("AUDITINVITE"));
  const app = await buildApp({
    repository,
    passwordHasher: new FakeHasher(),
  });

  assert.equal(
    (await register(app, "AUDITINVITE", "Audit_Hero", "register_audit")).statusCode,
    201,
  );
  repository.failLoginAudit = true;

  const success = await app.inject({
    method: "POST",
    url: "/api/v1/auth/login",
    payload: {
      rules_version: "network-1",
      username: "audit_hero",
      password: "Good-password-2026",
    },
  });
  assert.equal(success.statusCode, 200);
  assert.equal(repository.sessions.size, 1);

  const rejected = await app.inject({
    method: "POST",
    url: "/api/v1/auth/login",
    payload: {
      rules_version: "network-1",
      username: "missing_hero",
      password: "wrong-password",
    },
  });
  assert.equal(rejected.statusCode, 401);
  assert.equal(rejected.json().error.code, "INVALID_CREDENTIALS");

  await app.close();
});

test("client request format errors remain 4xx responses", async () => {
  const app = await buildApp({
    repository: new MemoryRepository(),
    passwordHasher: new FakeHasher(),
  });

  const response = await app.inject({
    method: "POST",
    url: "/api/v1/auth/logout",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    payload: "",
  });
  assert.equal(response.statusCode, 415);
  assert.equal(response.json().error.code, "UNSUPPORTED_MEDIA_TYPE");

  await app.close();
});
