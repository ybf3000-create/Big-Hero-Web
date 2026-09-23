import path from "node:path";
import { randomUUID } from "node:crypto";
import Fastify, { type FastifyInstance, type FastifyRequest } from "fastify";
import fastifyStatic from "@fastify/static";
import websocket from "@fastify/websocket";
import type { WebSocket } from "ws";
import { AsyncMutex } from "./async-mutex.js";
import { AppError, badRequest } from "./errors.js";
import { LoginLimiter } from "./login-limiter.js";
import type { GameRepository } from "./repository.js";
import {
  generateSessionToken,
  hashSecret,
  normalizeInviteCode,
  type PasswordHasher,
} from "./security.js";
import { SessionManager, type SessionIdentity } from "./session-manager.js";
import { WorkLimiter } from "./work-limiter.js";
import {
  normalizeUsername,
  validateCharacterName,
  validatePassword,
  validateRequestId,
  validateRulesVersion,
  validateUsername,
} from "./validation.js";

const IDLE_SESSION_MS = 30 * 60_000;
const MAX_SESSION_MS = 7 * 24 * 60 * 60_000;
const REMEMBER_MS = 30 * 24 * 60 * 60_000;
const REMEMBER_COOKIE = "big_hero_remember";
const BACKGROUND_AUTO_PLAY_INTERVAL_MS = 2_000;

interface BuildAppOptions {
  repository: GameRepository;
  passwordHasher: PasswordHasher;
  rulesVersion?: string;
  maxOnlinePlayers?: number;
  trustProxy?: boolean;
  logger?: boolean | Record<string, unknown>;
  staticRoot?: string;
  now?: () => number;
}

interface JsonObject {
  [key: string]: unknown;
}

interface ChatConnection {
  socket: WebSocket;
  identity: SessionIdentity;
  transportAlive: boolean;
}

function bodyObject(body: unknown): JsonObject {
  if (!body || typeof body !== "object" || Array.isArray(body)) {
    throw badRequest("请求内容格式不正确");
  }
  return body as JsonObject;
}

function loginPassword(value: unknown): string {
  if (typeof value !== "string" || value.length === 0 || Buffer.byteLength(value, "utf8") > 256) {
    throw new AppError("INVALID_CREDENTIALS", 401, "账号或密码错误");
  }
  return value;
}

function bearerToken(request: FastifyRequest): string {
  const authorization = request.headers.authorization;
  if (!authorization?.startsWith("Bearer ")) {
    throw new AppError("SESSION_INVALID", 401, "登录已失效，请重新登录");
  }
  const token = authorization.slice("Bearer ".length);
  if (!/^[A-Za-z0-9_-]{40,64}$/.test(token)) {
    throw new AppError("SESSION_INVALID", 401, "登录已失效，请重新登录");
  }
  return token;
}

function rememberedToken(request: FastifyRequest): string | null {
  const cookie = request.headers.cookie?.split(";").map((part) => part.trim())
    .find((part) => part.startsWith(`${REMEMBER_COOKIE}=`));
  const token = cookie?.slice(REMEMBER_COOKIE.length + 1);
  return token && /^[A-Za-z0-9_-]{40,64}$/.test(token) ? token : null;
}

function rememberCookie(request: FastifyRequest, token: string | null): string {
  const secure = request.protocol === "https" ? "; Secure" : "";
  return `${REMEMBER_COOKIE}=${token ?? ""}; Path=/api/v1/auth; HttpOnly; SameSite=Strict${secure}; Max-Age=${token ? Math.floor(REMEMBER_MS / 1000) : 0}`;
}

function wait(milliseconds: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

function chatBody(value: unknown): string {
  if (typeof value !== "string") {
    throw new AppError("CHAT_MESSAGE_INVALID", 400, "聊天内容格式不正确");
  }
  const body = value.trim();
  const length = Array.from(body).length;
  if (length < 1 || length > 120 || Buffer.byteLength(body, "utf8") > 480) {
    throw new AppError("CHAT_MESSAGE_INVALID", 400, "聊天内容需为1～120个字符");
  }
  return body;
}

function chatClientMessageId(value: unknown): string {
  if (typeof value !== "string" || !/^[A-Za-z0-9_-]{8,80}$/.test(value)) {
    throw new AppError("CHAT_MESSAGE_INVALID", 400, "聊天消息编号格式不正确");
  }
  return value;
}

export async function buildApp(options: BuildAppOptions): Promise<FastifyInstance> {
  const rulesVersion = options.rulesVersion ?? "network-1";
  const maxOnlinePlayers = options.maxOnlinePlayers ?? 20;
  const now = options.now ?? Date.now;
  const app = Fastify({
    logger: options.logger ?? false,
    trustProxy: options.trustProxy ?? false,
    bodyLimit: 16 * 1024,
  });
  const loginMutex = new AsyncMutex();
  const loginLimiter = new LoginLimiter(now);
  const passwordWork = new WorkLimiter(4, 32);
  const dummyPasswordHash = await options.passwordHasher.hash(
    "not-a-real-account-password-2026",
  );
  const backgroundAutoCharacters = new Map<string, string>();
  const sessionManager = new SessionManager(
    maxOnlinePlayers,
    now,
    (sessionId, reason) => {
      void options.repository.revokeSession(sessionId, new Date(now()), reason).catch((error) => {
        app.log.error({ err: error, sessionId, reason }, "failed to persist session removal");
      });
    },
    (identity) => {
      void (async () => {
        const character = await options.repository.getCharacter(identity.accountId);
        if (!character || !options.repository.getGameState) return;
        const state = await options.repository.getGameState(character.id);
        if (sessionManager.isBackground(identity.sessionId) && state.autoPlayEnabled) {
          backgroundAutoCharacters.set(identity.accountId, character.id);
        }
      })().catch((error) => {
        app.log.error({ err: error, accountId: identity.accountId }, "failed to enter background auto-play");
      });
    },
  );
  const chatConnections = new Set<ChatConnection>();
  const lastChatSentAt = new Map<string, number>();
  const cleanupTimer = setInterval(() => sessionManager.cleanupExpired(), 10_000);
  cleanupTimer.unref();
  const transportTimer = setInterval(() => {
    for (const connection of Array.from(chatConnections)) {
      if (connection.socket.readyState !== 1) {
        chatConnections.delete(connection);
      } else if (!connection.transportAlive) {
        connection.socket.terminate();
        chatConnections.delete(connection);
      } else {
        connection.transportAlive = false;
        connection.socket.ping();
      }
    }
  }, 15_000);
  transportTimer.unref();
  let autoPlayTickRunning = false;
  const autoPlayTimer = setInterval(() => {
    if (autoPlayTickRunning || !options.repository.executeGameCommand) return;
    autoPlayTickRunning = true;
    void (async () => {
      for (const [accountId, characterId] of Array.from(backgroundAutoCharacters.entries())) {
        if (!sessionManager.isAccountOnline(accountId)) {
          backgroundAutoCharacters.delete(accountId);
          continue;
        }
        try {
          await options.repository.executeGameCommand!({
            characterId,
            requestId: randomUUID(),
            command: "auto_roll",
            payload: {},
          });
        } catch (error) {
          if (error instanceof AppError && error.code === "GAME_COMMAND_INVALID") {
            try {
              const state = await options.repository.getGameState?.(characterId);
              if (!state?.autoPlayEnabled) backgroundAutoCharacters.delete(accountId);
            } catch (stateError) {
              app.log.error({ err: stateError, characterId }, "background auto-play state check failed");
            }
            continue;
          }
          app.log.error({ err: error, characterId }, "background auto-play tick failed");
        }
      }
    })().finally(() => {
      autoPlayTickRunning = false;
    });
  }, BACKGROUND_AUTO_PLAY_INTERVAL_MS);
  autoPlayTimer.unref();

  const recordLoginAttempt = async (
    username: string,
    ip: string,
    result: string,
  ): Promise<void> => {
    try {
      await options.repository.recordLoginAttempt(
        hashSecret(username),
        hashSecret(ip),
        result,
        new Date(now()),
      );
    } catch (error) {
      app.log.error({ err: error, result }, "failed to record login attempt");
    }
  };

  app.setErrorHandler((error, _request, reply) => {
    if (error instanceof AppError) {
      void reply.status(error.statusCode).send({
        ok: false,
        error: {
          code: error.code,
          message: error.message,
          ...(error.details ? { details: error.details } : {}),
        },
      });
      return;
    }
    const statusCode = (error as { statusCode?: unknown }).statusCode;
    if (typeof statusCode === "number" && statusCode >= 400 && statusCode < 500) {
      void reply.status(statusCode).send({
        ok: false,
        error: {
          code: statusCode === 415 ? "UNSUPPORTED_MEDIA_TYPE" : "BAD_REQUEST",
          message: statusCode === 415 ? "请求格式不受支持" : "请求内容格式不正确",
        },
      });
      return;
    }
    app.log.error({ err: error }, "unhandled request error");
    void reply.status(503).send({
      ok: false,
      error: { code: "SERVICE_UNAVAILABLE", message: "服务暂时不可用，请稍后重试" },
    });
  });

  await app.register(websocket, {
    options: { maxPayload: 16 * 1024 },
  });

  if (options.staticRoot) {
    await app.register(fastifyStatic, {
      root: path.resolve(options.staticRoot),
      prefix: "/",
      index: ["index.html"],
      wildcard: false,
    });
  }

  const authenticateRequest = (request: FastifyRequest): SessionIdentity => {
    const token = bearerToken(request);
    return sessionManager.resolveToken(hashSecret(token));
  };

  const startSessionUnlocked = async (account: { id: string }) => {
    if (!sessionManager.canAdmit(account.id)) {
      throw new AppError("SERVER_FULL", 503, "服务器人数已满，请稍后登录");
    }
    const createdAt = new Date(now());
    const sessionId = randomUUID();
    const token = generateSessionToken();
    const tokenHash = hashSecret(token);
    await options.repository.createSession({
      id: sessionId,
      accountId: account.id,
      tokenHash,
      createdAt,
      idleExpiresAt: new Date(createdAt.getTime() + IDLE_SESSION_MS),
      expiresAt: new Date(createdAt.getTime() + MAX_SESSION_MS),
    });
    try {
      sessionManager.admit(sessionId, account.id, tokenHash, createdAt.getTime() + MAX_SESSION_MS);
    } catch (error) {
      await options.repository.revokeSession(sessionId, new Date(now()), "capacity_race");
      throw error;
    }
    try {
      let character = await options.repository.getCharacter(account.id);
      let offlineReward = null;
      if (character && options.repository.claimOfflineProgress) {
        const claimed = await options.repository.claimOfflineProgress(character.id, createdAt);
        character = claimed.character;
        offlineReward = claimed.reward;
      }
      return { sessionId, token, character, offlineReward };
    } catch (error) {
      await options.repository.revokeSession(sessionId, new Date(now()), "session_initialization_failed");
      sessionManager.revoke(sessionId, "session_initialization_failed");
      throw error;
    }
  };

  const startSession = async (account: { id: string }) =>
    loginMutex.runExclusive(() => startSessionUnlocked(account));

  const loginPayload = (
    account: { id: string; username: string; mustChangePassword: boolean },
    result: Awaited<ReturnType<typeof startSession>>,
  ) => ({
    ok: true,
    session: {
      id: result.sessionId,
      token: result.token,
      heartbeat_interval_seconds: 10,
      reconnect_grace_seconds: 30,
    },
    account: {
      id: account.id,
      username: account.username,
      must_change_password: account.mustChangePassword,
    },
    character: result.character,
    offline_reward: result.offlineReward,
    rules_version: rulesVersion,
  });

  app.get("/healthz", async () => {
    await options.repository.ping();
    return {
      ok: true,
      rules_version: rulesVersion,
      online_players: sessionManager.onlineCount,
      max_online_players: maxOnlinePlayers,
      server_time: new Date(now()).toISOString(),
    };
  });

  app.post("/api/v1/auth/register", async (request, reply) => {
    const body = bodyObject(request.body);
    validateRulesVersion(body.rules_version, rulesVersion);
    const requestId = validateRequestId(body.request_id);
    const username = validateUsername(body.username);
    const password = validatePassword(body.password);
    if (body.password_confirm !== password) {
      throw badRequest("两次输入的密码不一致");
    }
    if (typeof body.invite_code !== "string" || normalizeInviteCode(body.invite_code) === "") {
      throw new AppError("INVITE_INVALID", 400, "邀请码无效");
    }

    const passwordHash = await passwordWork.run(() => options.passwordHasher.hash(password));
    const account = await options.repository.registerAccount({
      requestId,
      username,
      passwordHash,
      inviteCodeHash: hashSecret(normalizeInviteCode(body.invite_code)),
    });
    return reply.status(201).send({
      ok: true,
      account: { id: account.id, username: account.username },
      message: "账号创建成功",
    });
  });

  app.post("/api/v1/auth/login", async (request, reply) => {
    const body = bodyObject(request.body);
    validateRulesVersion(body.rules_version, rulesVersion);
    const username = typeof body.username === "string"
      ? normalizeUsername(body.username)
      : "";
    const password = loginPassword(body.password);
    const limit = loginLimiter.check(request.ip, username);
    if (!limit.allowed) {
      throw new AppError(
        "RATE_LIMITED",
        429,
        "尝试过于频繁，请稍后再试",
        { retry_after_seconds: limit.retryAfterSeconds },
      );
    }
    if (limit.delayMs > 0) {
      await wait(limit.delayMs);
    }

    const account = /^[a-z][a-z0-9_]{3,19}$/.test(username)
      ? await options.repository.findAccountForLogin(username)
      : null;
    const passwordMatches = await passwordWork.run(() =>
      options.passwordHasher.verify(
        account?.passwordHash ?? dummyPasswordHash,
        password,
      ),
    );
    if (!account || !passwordMatches || account.status === "deleted") {
      loginLimiter.recordFailure(request.ip, username);
      await recordLoginAttempt(username, request.ip, "invalid_credentials");
      throw new AppError("INVALID_CREDENTIALS", 401, "账号或密码错误");
    }
    if (
      account.status === "banned" &&
      (!account.bannedUntil || account.bannedUntil.getTime() > now())
    ) {
      await recordLoginAttempt(username, request.ip, "banned");
      throw new AppError(
        "ACCOUNT_BANNED",
        403,
        "账号已封禁",
        { banned_until: account.bannedUntil?.toISOString() ?? null },
      );
    }

    let loginResult: Awaited<ReturnType<typeof startSession>>;
    try {
      loginResult = await startSession(account);
    } catch (error) {
      if (error instanceof AppError && error.code === "SERVER_FULL") {
        await recordLoginAttempt(username, request.ip, "server_full");
      }
      throw error;
    }

    if (body.remember_login === true) {
      const token = generateSessionToken();
      try {
        const previous = rememberedToken(request);
        if (previous) await options.repository.revokeRememberedLogin(hashSecret(previous), new Date(now()), "replaced_by_login");
        await options.repository.createRememberedLogin({
          id: randomUUID(), accountId: account.id, tokenHash: hashSecret(token),
          createdAt: new Date(now()), expiresAt: new Date(now() + REMEMBER_MS),
        });
      } catch (error) {
        await options.repository.revokeSession(loginResult.sessionId, new Date(now()), "remember_failed");
        sessionManager.revoke(loginResult.sessionId);
        throw error;
      }
      reply.header("Set-Cookie", rememberCookie(request, token));
    } else {
      const previous = rememberedToken(request);
      if (previous) await options.repository.revokeRememberedLogin(hashSecret(previous), new Date(now()), "not_remembered");
      reply.header("Set-Cookie", rememberCookie(request, null));
    }

    loginLimiter.recordSuccess(request.ip, username);
    await recordLoginAttempt(username, request.ip, "success");
    return loginPayload(account, loginResult);
  });

  app.post("/api/v1/auth/restore", async (request, reply) => {
    reply.header("Cache-Control", "no-store");
    const previous = rememberedToken(request);
    if (!previous) {
      return { ok: false, error: { code: "NO_REMEMBERED_LOGIN", message: "没有可恢复的登录状态" } };
    }
    const restored = await loginMutex.runExclusive(async () => {
      const account = await options.repository.findAccountForRememberedLogin(hashSecret(previous), new Date(now()));
      if (!account || account.mustChangePassword || (account.status === "banned" && (!account.bannedUntil || account.bannedUntil.getTime() > now()))) {
        throw new AppError("SESSION_INVALID", 401, "请重新登录");
      }
      if (!sessionManager.canAdmit(account.id)) {
        throw new AppError("SERVER_FULL", 503, "服务器人数已满，请稍后登录");
      }
      const next = generateSessionToken();
      const rotated = await options.repository.rotateRememberedLogin({
        id: randomUUID(), accountId: account.id, previousTokenHash: hashSecret(previous),
        tokenHash: hashSecret(next), createdAt: new Date(now()),
        expiresAt: new Date(now() + REMEMBER_MS),
      });
      if (!rotated) throw new AppError("SESSION_INVALID", 401, "请重新登录");
      try {
        return { account, next, result: await startSessionUnlocked(account) };
      } catch (error) {
        await options.repository.revokeRememberedLogin(hashSecret(next), new Date(now()), "session_create_failed");
        throw error;
      }
    });
    const { account, next, result } = restored;
    reply.header("Set-Cookie", rememberCookie(request, next));
    return loginPayload(account, result);
  });

  app.post("/api/v1/auth/logout", async (request, reply) => {
    const remembered = rememberedToken(request);
    if (remembered) await options.repository.revokeRememberedLogin(hashSecret(remembered), new Date(now()), "logout");
    reply.header("Set-Cookie", rememberCookie(request, null));
    let identity: SessionIdentity;
    try {
      identity = authenticateRequest(request);
    } catch (error) {
      if (error instanceof AppError && error.code === "SESSION_INVALID") return { ok: true };
      throw error;
    }
    await options.repository.revokeSession(
      identity.sessionId,
      new Date(now()),
      "logout",
    );
    sessionManager.revoke(identity.sessionId, "logout");
    return { ok: true };
  });

  app.post("/api/v1/auth/change-password", async (request, reply) => {
    const identity = authenticateRequest(request);
    if (!options.repository.updateAccountPassword) throw new AppError("SERVICE_UNAVAILABLE", 503, "改密服务暂时不可用");
    const body = bodyObject(request.body);
    validateRulesVersion(body.rules_version, rulesVersion);
    const password = validatePassword(body.password);
    if (body.password_confirm !== password) throw badRequest("两次输入的密码不一致");
    const passwordHash = await passwordWork.run(() => options.passwordHasher.hash(password));
    await options.repository.updateAccountPassword(identity.accountId, passwordHash);
    reply.header("Set-Cookie", rememberCookie(request, null));
    return { ok: true, message: "密码修改成功" };
  });

  app.get("/api/v1/characters/me", async (request) => {
    const identity = authenticateRequest(request);
    return {
      ok: true,
      character: await options.repository.getCharacter(identity.accountId),
    };
  });

  app.get("/api/v1/chat/world", async (request) => {
    authenticateRequest(request);
    if (!options.repository.listChatMessages) {
      throw new AppError("SERVICE_UNAVAILABLE", 503, "聊天服务暂时不可用");
    }
    const query = (request.query && typeof request.query === "object")
      ? request.query as Record<string, unknown>
      : {};
    const rawLimit = query.limit;
    const limit = rawLimit === undefined ? 50 : Number(rawLimit);
    if (!Number.isInteger(limit) || limit < 1 || limit > 100) {
      throw badRequest("limit需为1～100的整数");
    }
    return {
      ok: true,
      messages: await options.repository.listChatMessages("world", limit),
    };
  });

  app.post("/api/v1/characters", async (request, reply) => {
    const identity = authenticateRequest(request);
    const body = bodyObject(request.body);
    validateRulesVersion(body.rules_version, rulesVersion);
    const requestId = validateRequestId(body.request_id);
    const name = validateCharacterName(body.name);
    const character = await options.repository.createCharacter({
      id: randomUUID(),
      requestId,
      accountId: identity.accountId,
      displayName: name.displayName,
      normalizedName: name.normalized,
    });
    return reply.status(201).send({ ok: true, character });
  });

  app.post("/api/v1/characters/delete", async (request) => {
    const identity = authenticateRequest(request);
    if (!options.repository.deleteCharacter) {
      throw new AppError("SERVICE_UNAVAILABLE", 503, "角色服务暂时不可用");
    }
    const body = bodyObject(request.body);
    validateRulesVersion(body.rules_version, rulesVersion);
    const confirmationName = typeof body.confirm_name === "string" ? body.confirm_name.trim() : "";
    if (confirmationName.length < 1 || confirmationName.length > 14) {
      throw badRequest("请输入当前角色名确认删除");
    }
    const character = await characterForIdentity(identity);
    if (confirmationName !== character.name) {
      throw new AppError("CHARACTER_CONFIRMATION_REQUIRED", 400, "角色名不匹配，未执行删除");
    }
    await options.repository.deleteCharacter(identity.accountId, character.id, confirmationName);
    return { ok: true, character: null, message: "角色已删除，可以创建新角色" };
  });

  const requireGameRepository = () => {
    if (!options.repository.getGameState || !options.repository.executeGameCommand) {
      throw new AppError("SERVICE_UNAVAILABLE", 503, "游戏服务暂时不可用");
    }
    return options.repository;
  };
  const characterForIdentity = async (identity: SessionIdentity) => {
    const character = await options.repository.getCharacter(identity.accountId);
    if (!character) throw new AppError("CHARACTER_REQUIRED", 409, "请先创建角色");
    return character;
  };

  app.get("/api/v1/game/state", async (request) => {
    const identity = authenticateRequest(request);
    const repository = requireGameRepository();
    const character = await characterForIdentity(identity);
    if (repository.getGameSnapshot) {
      const snapshot = await repository.getGameSnapshot(character.id);
      return { ok: true, character: snapshot.character, state: snapshot.state };
    }
    return { ok: true, character, state: await repository.getGameState!(character.id) };
  });

  app.post("/api/v1/game/auto-play/presence", async (request) => {
    const identity = authenticateRequest(request);
    const repository = requireGameRepository();
    const character = await characterForIdentity(identity);
    const body = bodyObject(request.body);
    if (typeof body.background !== "boolean") throw badRequest("网页状态不正确");
    sessionManager.setBackground(identity.sessionId, body.background);
    const state = await repository.getGameState!(character.id);
    if (body.background && state.autoPlayEnabled) {
      backgroundAutoCharacters.set(identity.accountId, character.id);
    } else {
      backgroundAutoCharacters.delete(identity.accountId);
    }
    return { ok: true, background: body.background, auto_play_enabled: state.autoPlayEnabled };
  });

  const gameCommand = async (request: FastifyRequest, command: string) => {
    const identity = authenticateRequest(request);
    const repository = requireGameRepository();
    const character = await characterForIdentity(identity);
    const body = bodyObject(request.body);
    validateRulesVersion(body.rules_version, rulesVersion);
    const requestId = validateRequestId(body.request_id);
    const payload = body.payload && typeof body.payload === "object" && !Array.isArray(body.payload)
      ? body.payload as Record<string, unknown>
      : {};
    const result = await repository.executeGameCommand!({ characterId: character.id, requestId, command, payload });
    if (command === "auto_play") {
      if (result.state.autoPlayEnabled && sessionManager.isBackground(identity.sessionId)) {
        backgroundAutoCharacters.set(identity.accountId, character.id);
      } else {
        backgroundAutoCharacters.delete(identity.accountId);
      }
    }
    // SqliteRepository includes the character row captured in the same
    // transaction. Keep the fallback for lightweight test repositories.
    const storedResult = result as typeof result & { characterSnapshot?: unknown };
    const updatedCharacter = storedResult.characterSnapshot ?? { ...character, ...result.character };
    return { ok: true, character: updatedCharacter, state: result.state, event: result.event };
  };

  app.post("/api/v1/game/roll", async (request) => gameCommand(request, "roll"));
  app.post("/api/v1/game/auto-play", async (request) => gameCommand(request, "auto_play"));
  app.post("/api/v1/game/construction/choose", async (request) => gameCommand(request, "construction_choose"));
  app.post("/api/v1/game/construction/resolve", async (request) => gameCommand(request, "construction_resolve"));
  app.post("/api/v1/game/construction/upgrade", async (request) => gameCommand(request, "construction_upgrade"));
  app.post("/api/v1/game/construction/demolish", async (request) => gameCommand(request, "construction_demolish"));
  app.post("/api/v1/game/item/use", async (request) => gameCommand(request, "item_use"));
  app.post("/api/v1/game/equipment/equip", async (request) => gameCommand(request, "equipment_equip"));
  app.post("/api/v1/game/equipment/unequip", async (request) => gameCommand(request, "equipment_unequip"));
  app.post("/api/v1/game/equipment/dismantle", async (request) => gameCommand(request, "equipment_dismantle"));
  app.post("/api/v1/game/equipment/dismantle-many", async (request) => gameCommand(request, "equipment_dismantle_many"));
  app.post("/api/v1/game/equipment/lock", async (request) => gameCommand(request, "equipment_lock"));
  app.post("/api/v1/game/equipment/enhance", async (request) => gameCommand(request, "equipment_enhance"));
  app.post("/api/v1/game/equipment/gem-socket", async (request) => gameCommand(request, "equipment_gem_socket"));
  app.post("/api/v1/game/equipment/gem-unsocket", async (request) => gameCommand(request, "equipment_gem_unsocket"));
  app.post("/api/v1/game/equipment/reroll", async (request) => gameCommand(request, "equipment_reroll"));
  app.post("/api/v1/game/equipment/auto-dismantle", async (request) => gameCommand(request, "auto_dismantle"));
  app.post("/api/v1/game/gem/synthesize", async (request) => gameCommand(request, "gem_synthesize"));
  app.post("/api/v1/game/inventory/expand", async (request) => gameCommand(request, "inventory_expand"));
  app.post("/api/v1/game/equipment/expand", async (request) => gameCommand(request, "equipment_expand"));
  app.post("/api/v1/game/skill/unlock", async (request) => gameCommand(request, "skill_unlock"));
  app.post("/api/v1/game/skill/slot", async (request) => gameCommand(request, "skill_slot"));
  app.post("/api/v1/game/skill/cast", async (request) => gameCommand(request, "skill_cast"));
  app.post("/api/v1/game/attributes/allocate", async (request) => gameCommand(request, "attribute_allocate"));
  app.post("/api/v1/game/attributes/reset", async (request) => gameCommand(request, "attribute_reset"));

  app.get("/api/v1/auction/listings", async (request) => {
    const identity = authenticateRequest(request);
    if (!options.repository.listAuctionListings) throw new AppError("SERVICE_UNAVAILABLE", 503, "拍卖行暂时不可用");
    await characterForIdentity(identity);
    const query = request.query && typeof request.query === "object" ? request.query as Record<string, unknown> : {};
    const limit = query.limit === undefined ? 50 : Number(query.limit);
    if (!Number.isInteger(limit) || limit < 1 || limit > 100) throw badRequest("limit需为1～100的整数");
    return { ok: true, listings: await options.repository.listAuctionListings(limit) };
  });

  app.get("/api/v1/auction/mine", async (request) => {
    const identity = authenticateRequest(request);
    if (!options.repository.listMyAuctionListings) throw new AppError("SERVICE_UNAVAILABLE", 503, "拍卖行暂时不可用");
    const character = await characterForIdentity(identity);
    return { ok: true, listings: await options.repository.listMyAuctionListings(character.id, 100) };
  });

  app.post("/api/v1/auction/list", async (request) => {
    const identity = authenticateRequest(request);
    if (!options.repository.createAuctionListing) throw new AppError("SERVICE_UNAVAILABLE", 503, "拍卖行暂时不可用");
    const character = await characterForIdentity(identity);
    const body = bodyObject(request.body);
    validateRulesVersion(body.rules_version, rulesVersion);
    const requestId = validateRequestId(body.request_id);
    const itemKind = body.item_kind;
    if (itemKind !== "item" && itemKind !== "equipment" && itemKind !== "gem") throw badRequest("物品类型不正确");
    const itemId = typeof body.item_id === "string" || typeof body.item_id === "number" ? body.item_id : "";
    const itemCount = Number(body.item_count ?? 1);
    const itemLevel = body.item_level === undefined ? undefined : Number(body.item_level);
    const buyoutPrice = Number(body.buyout_price);
    const durationHours = Number(body.duration_hours ?? 24);
    const created = await options.repository.createAuctionListing({ characterId: character.id, requestId, itemKind, itemId, itemCount, buyoutPrice, durationHours, ...(itemLevel === undefined ? {} : { itemLevel }) });
    const { character: characterSnapshot, ...listing } = created;
    return { ok: true, listing, character: characterSnapshot ?? await options.repository.getCharacter(identity.accountId) };
  });

  app.post("/api/v1/auction/buy", async (request) => {
    const identity = authenticateRequest(request);
    if (!options.repository.buyAuctionListing) throw new AppError("SERVICE_UNAVAILABLE", 503, "拍卖行暂时不可用");
    const character = await characterForIdentity(identity);
    const body = bodyObject(request.body);
    validateRulesVersion(body.rules_version, rulesVersion);
    const requestId = validateRequestId(body.request_id);
    if (typeof body.listing_id !== "string" || body.listing_id.length < 8) throw badRequest("订单编号不正确");
    const result = await options.repository.buyAuctionListing(character.id, requestId, body.listing_id);
    return { ok: true, ...result };
  });

  app.post("/api/v1/auction/cancel", async (request) => {
    const identity = authenticateRequest(request);
    if (!options.repository.cancelAuctionListing) throw new AppError("SERVICE_UNAVAILABLE", 503, "拍卖行暂时不可用");
    const character = await characterForIdentity(identity);
    const body = bodyObject(request.body);
    validateRulesVersion(body.rules_version, rulesVersion);
    const requestId = validateRequestId(body.request_id);
    if (typeof body.listing_id !== "string" || body.listing_id.length < 8) throw badRequest("订单编号不正确");
    const cancelled = await options.repository.cancelAuctionListing(character.id, body.listing_id, requestId);
    const { character: characterSnapshot, ...listing } = cancelled;
    return { ok: true, listing, ...(characterSnapshot ? { character: characterSnapshot } : {}) };
  });

  app.post("/api/v1/auction/claim", async (request) => {
    const identity = authenticateRequest(request);
    if (!options.repository.claimAuctionListing) throw new AppError("SERVICE_UNAVAILABLE", 503, "拍卖行暂时不可用");
    const character = await characterForIdentity(identity);
    const body = bodyObject(request.body);
    validateRulesVersion(body.rules_version, rulesVersion);
    const requestId = validateRequestId(body.request_id);
    if (typeof body.listing_id !== "string" || body.listing_id.length < 8) throw badRequest("订单编号不正确");
    const result = await options.repository.claimAuctionListing(character.id, requestId, body.listing_id);
    return { ok: true, ...result };
  });

  app.get("/ws", { websocket: true }, (socket: WebSocket) => {
    let identity: SessionIdentity | null = null;
    let connection: ChatConnection | null = null;
    const authenticationTimeout = setTimeout(() => {
      if (!identity) {
        socket.close(4003, "AUTHENTICATION_TIMEOUT");
      }
    }, 5_000);

    socket.on("message", (rawData) => {
      void (async () => {
        let message: JsonObject;
        try {
          const parsed = JSON.parse(rawData.toString()) as unknown;
          message = bodyObject(parsed);
        } catch {
          socket.send(JSON.stringify({
            type: "error",
            code: "BAD_REQUEST",
            message: "消息格式不正确",
          }));
          return;
        }

        if (!identity) {
          if (message.type !== "authenticate" || typeof message.token !== "string") {
            socket.close(4003, "AUTHENTICATION_REQUIRED");
            return;
          }
          try {
            identity = sessionManager.attachSocket(hashSecret(message.token), socket);
          } catch {
            if (socket.readyState === 1) socket.send(JSON.stringify({
              type: "error",
              code: "SESSION_INVALID",
              message: "登录已失效，请重新登录",
            }));
            socket.close(4003, "SESSION_INVALID");
            return;
          }
          clearTimeout(authenticationTimeout);
          connection = { socket, identity, transportAlive: true };
          chatConnections.add(connection);
          socket.send(JSON.stringify({
            type: "authenticated",
            session_id: identity.sessionId,
            rules_version: rulesVersion,
            heartbeat_interval_seconds: 10,
          }));
          if (options.repository.listChatMessages) {
            try {
              const messages = await options.repository.listChatMessages("world", 50);
              if (socket.readyState === 1) {
                socket.send(JSON.stringify({ type: "chat_history", channel: "world", messages }));
              }
            } catch (error) {
              app.log.error({ err: error }, "failed to load chat history");
              if (socket.readyState === 1) {
                socket.send(JSON.stringify({
                  type: "error",
                  code: "SERVICE_UNAVAILABLE",
                  message: "聊天记录暂时不可用",
                }));
              }
            }
          }
          return;
        }

        if (message.type === "heartbeat") {
          const resumedFromBackground = sessionManager.heartbeat(identity.sessionId);
          if (resumedFromBackground) backgroundAutoCharacters.delete(identity.accountId);
          const at = new Date(now());
          await options.repository.touchSession(
            identity.sessionId,
            at,
            new Date(at.getTime() + IDLE_SESSION_MS),
          );
          socket.send(JSON.stringify({
            type: "heartbeat_ack",
            server_time: at.toISOString(),
            resumed_from_background: resumedFromBackground,
          }));
          if (resumedFromBackground) {
            socket.send(JSON.stringify({ type: "background_resumed" }));
          }
          return;
        }

        if (message.type === "chat_send") {
          if (!options.repository.createChatMessage) {
            throw new AppError("SERVICE_UNAVAILABLE", 503, "聊天服务暂时不可用");
          }
          const body = chatBody(message.body);
          const clientMessageId = chatClientMessageId(message.client_message_id);
          const sentAt = now();
          const previousSentAt = lastChatSentAt.get(identity.accountId) ?? 0;
          if (sentAt - previousSentAt < 1_500) {
            throw new AppError("CHAT_RATE_LIMITED", 429, "发言太快了，请稍后再试");
          }
          lastChatSentAt.set(identity.accountId, sentAt);
          const chatMessage = await options.repository.createChatMessage({
            accountId: identity.accountId,
            body,
            clientMessageId,
          });
          const packet = JSON.stringify({ type: "chat_message", message: chatMessage });
          for (const connection of chatConnections) {
            if (connection.socket.readyState === 1) {
              try {
                connection.socket.send(packet);
              } catch {
                chatConnections.delete(connection);
              }
            } else {
              chatConnections.delete(connection);
            }
          }
          return;
        }

        socket.send(JSON.stringify({
          type: "error",
          code: "UNSUPPORTED_MESSAGE",
          message: "当前消息类型不受支持",
        }));
      })().catch((error) => {
        app.log.error({ err: error }, "websocket message failed");
        const packet = error instanceof AppError
          ? { type: "error", code: error.code, message: error.message, ...(error.details ? { details: error.details } : {}) }
          : { type: "error", code: "SERVICE_UNAVAILABLE", message: "服务暂时不可用" };
        if (socket.readyState === 1) socket.send(JSON.stringify(packet));
      });
    });

    socket.on("pong", () => {
      if (connection) connection.transportAlive = true;
    });

    socket.on("close", () => {
      clearTimeout(authenticationTimeout);
      if (connection) chatConnections.delete(connection);
      if (identity) {
        backgroundAutoCharacters.delete(identity.accountId);
        sessionManager.markDisconnected(identity.sessionId, socket);
      }
    });
  });

  app.addHook("onClose", async () => {
    clearInterval(cleanupTimer);
    clearInterval(transportTimer);
    clearInterval(autoPlayTimer);
    sessionManager.shutdown();
    await options.repository.close();
  });

  return app;
}
