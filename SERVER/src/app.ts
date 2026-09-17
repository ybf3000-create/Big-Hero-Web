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
  const sessionManager = new SessionManager(
    maxOnlinePlayers,
    now,
    (sessionId, reason) => {
      void options.repository.revokeSession(sessionId, new Date(now()), reason).catch((error) => {
        app.log.error({ err: error, sessionId, reason }, "failed to persist session removal");
      });
    },
  );
  const chatConnections = new Set<ChatConnection>();
  const lastChatSentAt = new Map<string, number>();
  const cleanupTimer = setInterval(() => sessionManager.cleanupExpired(), 10_000);
  cleanupTimer.unref();

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

  app.post("/api/v1/auth/login", async (request) => {
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

    const loginResult = await loginMutex.runExclusive(async () => {
      if (!sessionManager.canAdmit(account.id)) {
        await recordLoginAttempt(username, request.ip, "server_full");
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
        sessionManager.admit(
          sessionId,
          account.id,
          tokenHash,
          createdAt.getTime() + MAX_SESSION_MS,
        );
      } catch (error) {
        await options.repository.revokeSession(
          sessionId,
          new Date(now()),
          "capacity_race",
        );
        throw error;
      }
      const character = await options.repository.getCharacter(account.id);
      return { sessionId, token, character };
    });

    loginLimiter.recordSuccess(request.ip, username);
    await recordLoginAttempt(username, request.ip, "success");
    return {
      ok: true,
      session: {
        id: loginResult.sessionId,
        token: loginResult.token,
        heartbeat_interval_seconds: 10,
        reconnect_grace_seconds: 30,
      },
      account: {
        id: account.id,
        username: account.username,
        must_change_password: account.mustChangePassword,
      },
      character: loginResult.character,
      rules_version: rulesVersion,
    };
  });

  app.post("/api/v1/auth/logout", async (request) => {
    const identity = authenticateRequest(request);
    await options.repository.revokeSession(
      identity.sessionId,
      new Date(now()),
      "logout",
    );
    sessionManager.revoke(identity.sessionId, "logout");
    return { ok: true };
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
    return { ok: true, character, state: await repository.getGameState!(character.id) };
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
    const updatedCharacter = await options.repository.getCharacter(identity.accountId);
    return { ok: true, character: updatedCharacter, state: result.state, event: result.event };
  };

  app.post("/api/v1/game/roll", async (request) => gameCommand(request, "roll"));
  app.post("/api/v1/game/item/use", async (request) => gameCommand(request, "item_use"));
  app.post("/api/v1/game/equipment/equip", async (request) => gameCommand(request, "equipment_equip"));
  app.post("/api/v1/game/equipment/unequip", async (request) => gameCommand(request, "equipment_unequip"));
  app.post("/api/v1/game/equipment/dismantle", async (request) => gameCommand(request, "equipment_dismantle"));
  app.post("/api/v1/game/equipment/lock", async (request) => gameCommand(request, "equipment_lock"));
  app.post("/api/v1/game/equipment/enhance", async (request) => gameCommand(request, "equipment_enhance"));
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
    const buyoutPrice = Number(body.buyout_price);
    const durationHours = Number(body.duration_hours ?? 24);
    const listing = await options.repository.createAuctionListing({ characterId: character.id, requestId, itemKind, itemId, itemCount, buyoutPrice, durationHours });
    return { ok: true, listing, character: await options.repository.getCharacter(identity.accountId) };
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
    return { ok: true, ...result, character: await options.repository.getCharacter(identity.accountId) };
  });

  app.post("/api/v1/auction/cancel", async (request) => {
    const identity = authenticateRequest(request);
    if (!options.repository.cancelAuctionListing) throw new AppError("SERVICE_UNAVAILABLE", 503, "拍卖行暂时不可用");
    const character = await characterForIdentity(identity);
    const body = bodyObject(request.body);
    if (typeof body.listing_id !== "string" || body.listing_id.length < 8) throw badRequest("订单编号不正确");
    return { ok: true, listing: await options.repository.cancelAuctionListing(character.id, body.listing_id) };
  });

  app.post("/api/v1/auction/claim", async (request) => {
    const identity = authenticateRequest(request);
    if (!options.repository.claimAuctionListing) throw new AppError("SERVICE_UNAVAILABLE", 503, "拍卖行暂时不可用");
    const character = await characterForIdentity(identity);
    const body = bodyObject(request.body);
    if (typeof body.listing_id !== "string" || body.listing_id.length < 8) throw badRequest("订单编号不正确");
    const result = await options.repository.claimAuctionListing(character.id, body.listing_id);
    return { ok: true, ...result, character: await options.repository.getCharacter(identity.accountId) };
  });

  app.get("/ws", { websocket: true }, (socket: WebSocket) => {
    let identity: SessionIdentity | null = null;
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
            socket.close(4003, "SESSION_INVALID");
            return;
          }
          clearTimeout(authenticationTimeout);
          chatConnections.add({ socket, identity });
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
          sessionManager.heartbeat(identity.sessionId);
          const at = new Date(now());
          await options.repository.touchSession(
            identity.sessionId,
            at,
            new Date(at.getTime() + IDLE_SESSION_MS),
          );
          socket.send(JSON.stringify({
            type: "heartbeat_ack",
            server_time: at.toISOString(),
          }));
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

    socket.on("close", () => {
      clearTimeout(authenticationTimeout);
      for (const connection of chatConnections) {
        if (connection.socket === socket) chatConnections.delete(connection);
      }
      if (identity) {
        sessionManager.markDisconnected(identity.sessionId, socket);
      }
    });
  });

  app.addHook("onClose", async () => {
    clearInterval(cleanupTimer);
    sessionManager.shutdown();
    await options.repository.close();
  });

  return app;
}
