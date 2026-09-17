import { randomUUID } from "node:crypto";
import type Database from "better-sqlite3";
import { AppError } from "./errors.js";
import { applyGameCommand, createInitialGameState } from "./game-engine.js";
import { addItem, parseGameState, reconcileAttributePoints, removeTradableItem, serializeGameState, type EquipmentItem, type GameState } from "./game-state.js";
import type {
  AccountForLogin,
  AccountSummary,
  ChatMessage,
  CharacterSummary,
  CreateChatMessageInput,
  CreateCharacterInput,
  CreateSessionInput,
  CreateRememberedLoginInput,
  GameRepository,
  AuctionListing,
  CreateAuctionInput,
  GameCommandInput,
  OfflineProgressResult,
  RegisterAccountInput,
  RotateRememberedLoginInput,
} from "./repository.js";
import { openSqliteDatabase } from "./sqlite-database.js";

function accountFromRow(row: Record<string, unknown>): AccountForLogin {
  const bannedUntil = row.banned_until;
  return {
    id: String(row.id),
    username: String(row.username),
    passwordHash: String(row.password_hash),
    status: row.status as AccountForLogin["status"],
    bannedUntil: bannedUntil === null ? null : new Date(Number(bannedUntil)),
    mustChangePassword: Number(row.must_change_password) === 1,
  };
}

function characterFromRow(row: Record<string, unknown>): CharacterSummary {
  return {
    id: String(row.id),
    name: String(row.display_name),
    level: Number(row.level),
    experience: Number(row.experience),
    gold: String(row.gold),
    revision: Number(row.revision),
  };
}

function chatMessageFromRow(row: Record<string, unknown>): ChatMessage {
  const channel = String(row.channel);
  return {
    id: Number(row.id),
    channel: channel === "system" ? "system" : "world",
    senderName: row.sender_name === null || row.sender_name === undefined
      ? null
      : String(row.sender_name),
    body: String(row.body),
    createdAt: Number(row.created_at),
  };
}

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

function listingFromRow(row: Record<string, unknown>): AuctionListing {
  return {
    id: String(row.id),
    sellerCharacterId: String(row.seller_character_id),
    sellerName: String(row.seller_name),
    itemKind: row.item_kind as AuctionListing["itemKind"],
    item: JSON.parse(String(row.item_json)) as Record<string, unknown>,
    itemCount: Number(row.item_count),
    buyoutPrice: Number(row.buyout_price),
    status: String(row.status),
    createdAt: Number(row.created_at),
    expiresAt: Number(row.expires_at),
    buyerCharacterId: row.buyer_character_id === null ? null : String(row.buyer_character_id),
    claimCharacterId: row.claim_character_id === null ? null : String(row.claim_character_id),
  };
}

export class SqliteRepository implements GameRepository {
  readonly database: Database.Database;

  constructor(databasePath: string) {
    this.database = openSqliteDatabase(databasePath);
  }

  async ping(): Promise<void> {
    this.database.prepare("SELECT 1").get();
  }

  async close(): Promise<void> {
    if (this.database.open) {
      this.database.close();
    }
  }

  insertInviteCode(id: string, codeHash: string): void {
    this.database.prepare(
      "INSERT INTO invite_codes (id, code_hash) VALUES (?, ?)",
    ).run(id, codeHash);
  }

  async registerAccount(input: RegisterAccountInput): Promise<AccountSummary> {
    const register = this.database.transaction((value: RegisterAccountInput) => {
      const repeated = this.database.prepare(
        `SELECT id, username, username_normalized
           FROM accounts
          WHERE registration_request_id = ?`,
      ).get(value.requestId) as Record<string, unknown> | undefined;
      if (repeated) {
        if (repeated.username_normalized !== value.username) {
          throw new AppError("REQUEST_ID_REUSED", 409, "request_id已用于其他注册请求");
        }
        return { id: String(repeated.id), username: String(repeated.username) };
      }

      const invite = this.database.prepare(
        `SELECT id
           FROM invite_codes
          WHERE code_hash = ? AND status = 'available'`,
      ).get(value.inviteCodeHash) as { id: string } | undefined;
      if (!invite) {
        throw new AppError("INVITE_INVALID", 400, "邀请码无效");
      }

      const accountId = randomUUID();
      this.database.prepare(
        `INSERT INTO accounts (
           id, username, username_normalized, password_hash, registration_request_id
         ) VALUES (?, ?, ?, ?, ?)`,
      ).run(
        accountId,
        value.username,
        value.username,
        value.passwordHash,
        value.requestId,
      );
      const inviteUpdate = this.database.prepare(
        `UPDATE invite_codes
            SET status = 'used', used_at = ?, used_by_account_id = ?
          WHERE id = ? AND status = 'available'`,
      ).run(Date.now(), accountId, invite.id);
      if (inviteUpdate.changes !== 1) {
        throw new AppError("INVITE_INVALID", 400, "邀请码无效");
      }
      this.database.prepare(
        `INSERT INTO audit_events (event_type, target_account_id, details)
         VALUES ('account.registered', ?, ?)`,
      ).run(accountId, JSON.stringify({ request_id: value.requestId }));
      return { id: accountId, username: value.username };
    });

    try {
      return register.immediate(input);
    } catch (error) {
      if (errorMessage(error).includes("UNIQUE constraint failed: accounts.username_normalized")) {
        throw new AppError("ACCOUNT_UNAVAILABLE", 409, "该账号不可用");
      }
      throw error;
    }
  }

  async findAccountForLogin(username: string): Promise<AccountForLogin | null> {
    const row = this.database.prepare(
      `SELECT id, username, password_hash, status, banned_until, must_change_password
         FROM accounts
        WHERE username_normalized = ?`,
    ).get(username) as Record<string, unknown> | undefined;
    return row ? accountFromRow(row) : null;
  }

  async createSession(input: CreateSessionInput): Promise<void> {
    const create = this.database.transaction((value: CreateSessionInput) => {
      this.database.prepare(
        `UPDATE sessions
            SET revoked_at = ?, revoke_reason = 'replaced_by_new_login'
          WHERE account_id = ? AND revoked_at IS NULL`,
      ).run(value.createdAt.getTime(), value.accountId);
      this.database.prepare(
        `INSERT INTO sessions (
           id, token_hash, account_id, created_at, last_seen_at,
           idle_expires_at, expires_at
         ) VALUES (?, ?, ?, ?, ?, ?, ?)`,
      ).run(
        value.id,
        value.tokenHash,
        value.accountId,
        value.createdAt.getTime(),
        value.createdAt.getTime(),
        value.idleExpiresAt.getTime(),
        value.expiresAt.getTime(),
      );
    });
    create.immediate(input);
  }

  async createRememberedLogin(input: CreateRememberedLoginInput): Promise<void> {
    const create = this.database.transaction((value: CreateRememberedLoginInput) => {
      this.database.prepare(
        `UPDATE remembered_logins
            SET revoked_at = ?, revoke_reason = 'replaced_by_new_remembered_login'
          WHERE account_id = ? AND revoked_at IS NULL`,
      ).run(value.createdAt.getTime(), value.accountId);
      this.database.prepare(
        `INSERT INTO remembered_logins (
           id, token_hash, account_id, created_at, last_used_at, expires_at
         ) VALUES (?, ?, ?, ?, ?, ?)`,
      ).run(
        value.id,
        value.tokenHash,
        value.accountId,
        value.createdAt.getTime(),
        value.createdAt.getTime(),
        value.expiresAt.getTime(),
      );
    });
    create.immediate(input);
  }

  async findAccountForRememberedLogin(tokenHash: string, at: Date): Promise<AccountForLogin | null> {
    const row = this.database.prepare(
      `SELECT a.id, a.username, a.password_hash, a.status, a.banned_until,
              a.must_change_password
         FROM remembered_logins r
         JOIN accounts a ON a.id = r.account_id
        WHERE r.token_hash = ?
          AND r.revoked_at IS NULL
          AND r.expires_at > ?
          AND a.status != 'deleted'`,
    ).get(tokenHash, at.getTime()) as Record<string, unknown> | undefined;
    return row ? accountFromRow(row) : null;
  }

  async rotateRememberedLogin(input: RotateRememberedLoginInput): Promise<boolean> {
    const rotate = this.database.transaction((value: RotateRememberedLoginInput) => {
      const revoked = this.database.prepare(
        `UPDATE remembered_logins
            SET revoked_at = ?, revoke_reason = 'rotated'
          WHERE token_hash = ? AND revoked_at IS NULL AND expires_at > ?`,
      ).run(
        value.createdAt.getTime(),
        value.previousTokenHash,
        value.createdAt.getTime(),
      );
      if (revoked.changes !== 1) return false;
      this.database.prepare(
        `INSERT INTO remembered_logins (
           id, token_hash, account_id, created_at, last_used_at, expires_at
         ) VALUES (?, ?, ?, ?, ?, ?)`,
      ).run(
        value.id,
        value.tokenHash,
        value.accountId,
        value.createdAt.getTime(),
        value.createdAt.getTime(),
        value.expiresAt.getTime(),
      );
      return true;
    });
    return rotate.immediate(input);
  }

  async revokeRememberedLogin(tokenHash: string, at: Date, reason: string): Promise<void> {
    this.database.prepare(
      `UPDATE remembered_logins
          SET revoked_at = COALESCE(revoked_at, ?),
              revoke_reason = COALESCE(revoke_reason, ?)
        WHERE token_hash = ?`,
    ).run(at.getTime(), reason, tokenHash);
  }

  async revokeAccountRememberedLogins(accountId: string, at: Date, reason: string): Promise<void> {
    this.database.prepare(
      `UPDATE remembered_logins
          SET revoked_at = COALESCE(revoked_at, ?),
              revoke_reason = COALESCE(revoke_reason, ?)
        WHERE account_id = ? AND revoked_at IS NULL`,
    ).run(at.getTime(), reason, accountId);
  }

  async touchSession(sessionId: string, at: Date, idleExpiresAt: Date): Promise<void> {
    const touch = this.database.transaction(() => {
      this.database.prepare(
        `UPDATE sessions
            SET last_seen_at = ?, idle_expires_at = ?
          WHERE id = ? AND revoked_at IS NULL`,
      ).run(at.getTime(), idleExpiresAt.getTime(), sessionId);
      const row = this.database.prepare(
        `SELECT cs.character_id, cs.state_json
           FROM sessions s
           JOIN characters c ON c.account_id = s.account_id AND c.deleted_at IS NULL
           JOIN character_states cs ON cs.character_id = c.id
          WHERE s.id = ? AND s.revoked_at IS NULL`,
      ).get(sessionId) as { character_id: string; state_json: string } | undefined;
      if (row) {
        const state = parseGameState(row.state_json);
        state.lastOnline = at.getTime();
        this.database.prepare(
          `UPDATE character_states SET state_json = ?, updated_at = ? WHERE character_id = ?`,
        ).run(serializeGameState(state), at.getTime(), row.character_id);
      }
    });
    touch.immediate();
  }

  async revokeSession(sessionId: string, at: Date, reason: string): Promise<void> {
    this.database.prepare(
      `UPDATE sessions
          SET revoked_at = COALESCE(revoked_at, ?),
              revoke_reason = COALESCE(revoke_reason, ?)
        WHERE id = ?`,
    ).run(at.getTime(), reason, sessionId);
  }

  async revokeAccountSessions(accountId: string, at: Date, reason: string): Promise<void> {
    this.database.prepare(
      `UPDATE sessions
          SET revoked_at = COALESCE(revoked_at, ?),
              revoke_reason = COALESCE(revoke_reason, ?)
        WHERE account_id = ? AND revoked_at IS NULL`,
    ).run(at.getTime(), reason, accountId);
  }

  async updateAccountPassword(accountId: string, passwordHash: string): Promise<void> {
    const update = this.database.transaction(() => {
      const result = this.database.prepare(
        `UPDATE accounts SET password_hash = ?, must_change_password = 0
          WHERE id = ? AND status != 'deleted'`,
      ).run(passwordHash, accountId);
      if (result.changes !== 1) throw new AppError("ACCOUNT_NOT_FOUND", 404, "账号不存在");
      this.database.prepare(
        `UPDATE remembered_logins
            SET revoked_at = COALESCE(revoked_at, ?),
                revoke_reason = COALESCE(revoke_reason, 'password_changed')
          WHERE account_id = ? AND revoked_at IS NULL`,
      ).run(Date.now(), accountId);
      this.database.prepare(
        `INSERT INTO audit_events (event_type, target_account_id, details)
         VALUES ('account.password_changed', ?, '{}')`,
      ).run(accountId);
    });
    update.immediate();
  }

  listAccountsForAdmin(): Array<{ username: string; status: string; bannedUntil: number | null; mutedUntil: number | null; characterName: string | null }> {
    return this.database.prepare(
      `SELECT a.username, a.status, a.banned_until AS bannedUntil,
              MAX(CASE WHEN m.revoked_at IS NULL AND m.ends_at > ? THEN m.ends_at END) AS mutedUntil,
              c.display_name AS characterName
         FROM accounts a
         LEFT JOIN characters c ON c.account_id = a.id AND c.deleted_at IS NULL
         LEFT JOIN chat_mutes m ON m.account_id = a.id
        GROUP BY a.id
        ORDER BY a.created_at`,
    ).all(Date.now()) as Array<{ username: string; status: string; bannedUntil: number | null; mutedUntil: number | null; characterName: string | null }>;
  }

  async resetPasswordForAdmin(username: string, passwordHash: string, at = new Date()): Promise<void> {
    const reset = this.database.transaction(() => {
      const account = this.database.prepare(
        `SELECT id FROM accounts WHERE username_normalized = ? AND status != 'deleted'`,
      ).get(username) as { id: string } | undefined;
      if (!account) throw new AppError("ACCOUNT_NOT_FOUND", 404, "账号不存在");
      this.database.prepare(
        `UPDATE accounts SET password_hash = ?, must_change_password = 1 WHERE id = ?`,
      ).run(passwordHash, account.id);
      this.database.prepare(
        `UPDATE sessions SET revoked_at = COALESCE(revoked_at, ?), revoke_reason = COALESCE(revoke_reason, 'admin_password_reset')
          WHERE account_id = ? AND revoked_at IS NULL`,
      ).run(at.getTime(), account.id);
      this.database.prepare(
        `UPDATE remembered_logins SET revoked_at = COALESCE(revoked_at, ?), revoke_reason = COALESCE(revoke_reason, 'admin_password_reset')
          WHERE account_id = ? AND revoked_at IS NULL`,
      ).run(at.getTime(), account.id);
      this.database.prepare(
        `INSERT INTO audit_events (event_type, target_account_id, details)
         VALUES ('account.password_reset', ?, '{}')`,
      ).run(account.id);
    });
    reset.immediate();
  }

  setBanForAdmin(username: string, hours: number | null, reason: string, at = new Date()): void {
    if (hours !== null && (!Number.isInteger(hours) || hours < 1 || hours > 72)) throw new Error("封号时长需为1至72小时");
    const change = this.database.transaction(() => {
      const account = this.database.prepare(
        `SELECT id FROM accounts WHERE username_normalized = ? AND status != 'deleted'`,
      ).get(username) as { id: string } | undefined;
      if (!account) throw new AppError("ACCOUNT_NOT_FOUND", 404, "账号不存在");
      const until = hours === null ? null : at.getTime() + hours * 60 * 60_000;
      this.database.prepare(
        `UPDATE accounts SET status = ?, banned_until = ? WHERE id = ?`,
      ).run(hours === null ? "normal" : "banned", until, account.id);
      if (hours !== null) {
        this.database.prepare(
          `UPDATE sessions SET revoked_at = COALESCE(revoked_at, ?), revoke_reason = COALESCE(revoke_reason, 'admin_ban')
            WHERE account_id = ? AND revoked_at IS NULL`,
        ).run(at.getTime(), account.id);
        this.database.prepare(
          `UPDATE remembered_logins SET revoked_at = COALESCE(revoked_at, ?), revoke_reason = COALESCE(revoke_reason, 'admin_ban')
            WHERE account_id = ? AND revoked_at IS NULL`,
        ).run(at.getTime(), account.id);
      }
      this.database.prepare(
        `INSERT INTO audit_events (event_type, target_account_id, details) VALUES (?, ?, ?)`,
      ).run(hours === null ? "account.unbanned" : "account.banned", account.id, JSON.stringify({ hours, reason }));
    });
    change.immediate();
  }

  setMuteForAdmin(username: string, hours: number | null, reason: string, at = new Date()): void {
    if (hours !== null && (!Number.isInteger(hours) || hours < 1 || hours > 72)) throw new Error("禁言时长需为1至72小时");
    const change = this.database.transaction(() => {
      const account = this.database.prepare(
        `SELECT id FROM accounts WHERE username_normalized = ? AND status != 'deleted'`,
      ).get(username) as { id: string } | undefined;
      if (!account) throw new AppError("ACCOUNT_NOT_FOUND", 404, "账号不存在");
      this.database.prepare(
        `UPDATE chat_mutes SET revoked_at = ? WHERE account_id = ? AND revoked_at IS NULL`,
      ).run(at.getTime(), account.id);
      if (hours !== null) {
        this.database.prepare(
          `INSERT INTO chat_mutes (account_id, reason, starts_at, ends_at)
           VALUES (?, ?, ?, ?)`,
        ).run(account.id, reason, at.getTime(), at.getTime() + hours * 60 * 60_000);
      }
      this.database.prepare(
        `INSERT INTO audit_events (event_type, target_account_id, details) VALUES (?, ?, ?)`,
      ).run(hours === null ? "chat.unmuted" : "chat.muted", account.id, JSON.stringify({ hours, reason }));
    });
    change.immediate();
  }

  deleteAccountForAdmin(username: string, reason: string, at = new Date()): void {
    const remove = this.database.transaction(() => {
      const account = this.database.prepare(
        `SELECT id FROM accounts WHERE username_normalized = ? AND status != 'deleted'`,
      ).get(username) as { id: string } | undefined;
      if (!account) throw new AppError("ACCOUNT_NOT_FOUND", 404, "账号不存在");
      const escrow = this.database.prepare(
        `SELECT count(*) AS count FROM auction_listings
          WHERE seller_character_id IN (SELECT id FROM characters WHERE account_id = ?)
            AND status != 'claimed'`,
      ).get(account.id) as { count: number };
      if (escrow.count > 0) throw new AppError("AUCTION_UNAVAILABLE", 409, "账号还有未领取的拍卖订单，请先领取后再删号");
      this.database.prepare(
        `UPDATE sessions SET revoked_at = COALESCE(revoked_at, ?), revoke_reason = COALESCE(revoke_reason, 'admin_delete')
          WHERE account_id = ? AND revoked_at IS NULL`,
      ).run(at.getTime(), account.id);
      this.database.prepare(
        `UPDATE remembered_logins SET revoked_at = COALESCE(revoked_at, ?), revoke_reason = COALESCE(revoke_reason, 'admin_delete')
          WHERE account_id = ? AND revoked_at IS NULL`,
      ).run(at.getTime(), account.id);
      this.database.prepare(
        `UPDATE characters SET deleted_at = ? WHERE account_id = ? AND deleted_at IS NULL`,
      ).run(at.getTime(), account.id);
      this.database.prepare(
        `INSERT INTO audit_events (event_type, target_account_id, details) VALUES ('account.deleted', ?, ?)`,
      ).run(account.id, JSON.stringify({ reason }));
      this.database.prepare(
        `UPDATE accounts SET status = 'deleted', banned_until = NULL, deleted_at = ? WHERE id = ?`,
      ).run(at.getTime(), account.id);
    });
    remove.immediate();
  }

  async recordLoginAttempt(
    loginKeyHash: string,
    ipHash: string,
    result: string,
    at: Date,
  ): Promise<void> {
    this.database.prepare(
      `INSERT INTO login_attempts (login_key_hash, ip_hash, result, created_at)
       VALUES (?, ?, ?, ?)`,
    ).run(loginKeyHash, ipHash, result, at.getTime());
  }

  async getCharacter(accountId: string): Promise<CharacterSummary | null> {
    const row = this.database.prepare(
      `SELECT id, display_name, level, experience, gold, revision
         FROM characters
        WHERE account_id = ? AND deleted_at IS NULL`,
    ).get(accountId) as Record<string, unknown> | undefined;
    return row ? characterFromRow(row) : null;
  }

  async createCharacter(input: CreateCharacterInput): Promise<CharacterSummary> {
    const create = this.database.transaction((value: CreateCharacterInput) => {
      const repeated = this.database.prepare(
        `SELECT id, account_id, display_name, level, experience, gold, revision
           FROM characters
          WHERE creation_request_id = ?`,
      ).get(value.requestId) as Record<string, unknown> | undefined;
      if (repeated) {
        if (repeated.account_id !== value.accountId) {
          throw new AppError("REQUEST_ID_REUSED", 409, "request_id已用于其他角色创建请求");
        }
        return characterFromRow(repeated);
      }

      const id = value.id || randomUUID();
      this.database.prepare(
        `INSERT INTO characters (
           id, account_id, display_name, display_name_normalized, creation_request_id
         ) VALUES (?, ?, ?, ?, ?)`,
      ).run(
        id,
        value.accountId,
        value.displayName,
        value.normalizedName,
        value.requestId,
      );
      this.database.prepare(
        `INSERT INTO character_states (character_id, state_json) VALUES (?, ?)`,
      ).run(id, serializeGameState(createInitialGameState()));
      const inserted = this.database.prepare(
        `SELECT id, display_name, level, experience, gold, revision
           FROM characters
          WHERE id = ?`,
      ).get(id) as Record<string, unknown>;
      return characterFromRow(inserted);
    });

    try {
      return create.immediate(input);
    } catch (error) {
      const message = errorMessage(error);
      if (message.includes("UNIQUE constraint failed: characters.account_id")) {
        throw new AppError("CHARACTER_EXISTS", 409, "每个账号只能创建一个角色");
      }
      if (message.includes("UNIQUE constraint failed: characters.display_name_normalized")) {
        throw new AppError("CHARACTER_NAME_UNAVAILABLE", 409, "该角色名已被使用");
      }
      throw error;
    }
  }

  async getGameState(characterId: string): Promise<GameState> {
    const load = this.database.transaction((id: string) => {
      const character = this.database.prepare(
        `SELECT level FROM characters WHERE id = ? AND deleted_at IS NULL`,
      ).get(id) as { level: number } | undefined;
      if (!character) throw new AppError("CHARACTER_REQUIRED", 409, "请先创建角色");
      const row = this.database.prepare(
        `SELECT state_json FROM character_states WHERE character_id = ?`,
      ).get(id) as { state_json: string } | undefined;
      const state = parseGameState(row?.state_json);
      const changed = reconcileAttributePoints(state, Number(character.level));
      if (!row || changed) {
        this.database.prepare(
          `INSERT INTO character_states (character_id, state_json, updated_at) VALUES (?, ?, ?)
           ON CONFLICT(character_id) DO UPDATE SET state_json = excluded.state_json, updated_at = excluded.updated_at`,
        ).run(id, serializeGameState(state), Date.now());
      }
      return state;
    });
    return load.immediate(characterId);
  }

  async claimOfflineProgress(characterId: string, at: Date): Promise<OfflineProgressResult> {
    const claim = this.database.transaction((id: string, now: number) => {
      const characterRow = this.database.prepare(
        `SELECT id, display_name, level, experience, gold, revision
           FROM characters WHERE id = ? AND deleted_at IS NULL`,
      ).get(id) as Record<string, unknown> | undefined;
      if (!characterRow) throw new AppError("CHARACTER_REQUIRED", 409, "请先创建角色");
      const stateRow = this.database.prepare(
        `SELECT state_json FROM character_states WHERE character_id = ?`,
      ).get(id) as { state_json: string } | undefined;
      const state = parseGameState(stateRow?.state_json);
      const elapsed = Math.max(0, Math.min(12 * 60 * 60_000, now - Math.max(0, Number(state.lastOnline) || now)));
      let reward: OfflineProgressResult["reward"] = null;
      let level = Number(characterRow.level);
      let experience = Number(characterRow.experience);
      let gold = Number(characterRow.gold);
      if (elapsed >= 60_000) {
        const seconds = Math.floor(elapsed / 1_000);
        const goldRate = state.lastGoldPerHour > 0 ? state.lastGoldPerHour : Math.max(1, level) * 600;
        const experienceRate = state.lastExpPerHour > 0 ? state.lastExpPerHour : Math.max(1, level) * 720;
        const goldGain = Math.max(0, Math.floor(goldRate * seconds / 3_600 * .1));
        const experienceGain = Math.max(0, Math.floor(experienceRate * seconds / 3_600 * .1));
        gold = Math.min(9_000_000_000_000_000, gold + goldGain);
        experience += experienceGain;
        while (level < 100 && experience >= Math.floor(100 * 1.12 ** (level - 1))) {
          experience -= Math.floor(100 * 1.12 ** (level - 1));
          level += 1;
        }
        if (level >= 100) experience = 0;
        reward = { seconds, gold: goldGain, experience: experienceGain };
      }
      state.lastOnline = now;
      reconcileAttributePoints(state, level);
      this.database.prepare(
        `INSERT INTO character_states (character_id, state_json, updated_at) VALUES (?, ?, ?)
         ON CONFLICT(character_id) DO UPDATE SET state_json = excluded.state_json, updated_at = excluded.updated_at`,
      ).run(id, serializeGameState(state), now);
      if (reward) {
        this.database.prepare(
          `UPDATE characters SET level = ?, experience = ?, gold = ?, revision = revision + 1 WHERE id = ?`,
        ).run(level, experience, gold, id);
      }
      const character = characterFromRow({ ...characterRow, level, experience, gold, revision: Number(characterRow.revision) + (reward ? 1 : 0) });
      return { state, character, reward };
    });
    return claim.immediate(characterId, at.getTime());
  }

  async executeGameCommand(input: GameCommandInput) {
    const execute = this.database.transaction((value: GameCommandInput) => {
      const repeated = this.database.prepare(
        `SELECT command, result_json FROM game_commands WHERE character_id = ? AND request_id = ?`,
      ).get(value.characterId, value.requestId) as { command: string; result_json: string } | undefined;
      if (repeated) {
        if (repeated.command !== value.command) throw new AppError("REQUEST_ID_REUSED", 409, "request_id已用于其他游戏操作");
        return JSON.parse(repeated.result_json) as ReturnType<typeof applyGameCommand>;
      }

      const characterRow = this.database.prepare(
        `SELECT level, experience, gold FROM characters WHERE id = ? AND deleted_at IS NULL`,
      ).get(value.characterId) as { level: number; experience: number; gold: number } | undefined;
      if (!characterRow) throw new AppError("CHARACTER_REQUIRED", 409, "请先创建角色");
      const stateRow = this.database.prepare(
        `SELECT state_json FROM character_states WHERE character_id = ?`,
      ).get(value.characterId) as { state_json: string } | undefined;
      let result: ReturnType<typeof applyGameCommand>;
      try {
        result = applyGameCommand(
          parseGameState(stateRow?.state_json),
          { level: Number(characterRow.level), experience: Number(characterRow.experience), gold: Number(characterRow.gold) },
          value.command,
          value.payload,
        );
      } catch (error) {
        if (error instanceof Error) throw new AppError("GAME_COMMAND_INVALID", 400, error.message);
        throw error;
      }
      result.state.lastOnline = Date.now();
      this.database.prepare(
        `INSERT INTO character_states (character_id, state_json, updated_at) VALUES (?, ?, ?)
         ON CONFLICT(character_id) DO UPDATE SET state_json = excluded.state_json, updated_at = excluded.updated_at`,
      ).run(value.characterId, serializeGameState(result.state), Date.now());
      this.database.prepare(
        `UPDATE characters SET level = ?, experience = ?, gold = ?, revision = revision + 1 WHERE id = ?`,
      ).run(result.character.level, result.character.experience, result.character.gold, value.characterId);
      const stored = { ...result, character: result.character };
      this.database.prepare(
        `INSERT INTO game_commands (character_id, request_id, command, result_json) VALUES (?, ?, ?, ?)`,
      ).run(value.characterId, value.requestId, value.command, JSON.stringify(stored));
      return stored;
    });
    try {
      return execute.immediate(input);
    } catch (error) {
      const message = errorMessage(error);
      if (message.includes("物品不足") || message.includes("金币不足") || message.includes("不存在") || message.includes("无法") || message.includes("不支持") || message.includes("属性点")) {
        throw new AppError("GAME_COMMAND_INVALID", 400, message);
      }
      throw error;
    }
  }

  async listAuctionListings(limit: number): Promise<AuctionListing[]> {
    const safeLimit = Math.max(1, Math.min(Math.floor(limit), 100));
    const now = Date.now();
    this.database.prepare(
      `UPDATE auction_listings SET status = 'expired', claim_character_id = seller_character_id
       WHERE status = 'active' AND expires_at <= ?`,
    ).run(now);
    const rows = this.database.prepare(
      `SELECT * FROM auction_listings WHERE status = 'active' ORDER BY created_at DESC LIMIT ?`,
    ).all(safeLimit) as Record<string, unknown>[];
    return rows.map(listingFromRow);
  }

  async listMyAuctionListings(characterId: string, limit: number): Promise<AuctionListing[]> {
    const safeLimit = Math.max(1, Math.min(Math.floor(limit), 100));
    const now = Date.now();
    this.database.prepare(
      `UPDATE auction_listings SET status = 'expired', claim_character_id = seller_character_id
       WHERE status = 'active' AND expires_at <= ?`,
    ).run(now);
    const rows = this.database.prepare(
      `SELECT * FROM auction_listings WHERE seller_character_id = ? ORDER BY created_at DESC LIMIT ?`,
    ).all(characterId, safeLimit) as Record<string, unknown>[];
    return rows.map(listingFromRow);
  }

  async createAuctionListing(input: CreateAuctionInput): Promise<AuctionListing> {
    const create = this.database.transaction((value: CreateAuctionInput) => {
      const repeated = this.database.prepare(
        `SELECT * FROM auction_listings WHERE seller_character_id = ? AND client_request_id = ?`,
      ).get(value.characterId, value.requestId) as Record<string, unknown> | undefined;
      if (repeated) {
        const listing = listingFromRow(repeated);
        const itemId = listing.itemKind === "equipment" ? String(listing.item.id) : listing.itemKind === "item" ? Number(listing.item.itemId) : Number(listing.item.gemId);
        const itemLevelMatches = value.itemKind !== "gem" || Number(listing.item.level ?? 1) === (value.itemLevel ?? 1);
        if (listing.itemKind !== value.itemKind || !itemLevelMatches || itemId !== (value.itemKind === "equipment" ? String(value.itemId) : Number(value.itemId)) || listing.itemCount !== value.itemCount || listing.buyoutPrice !== value.buyoutPrice) {
          throw new AppError("REQUEST_ID_REUSED", 409, "request_id已用于其他上架请求");
        }
        return listing;
      }
      if (![8, 12, 24].includes(value.durationHours)) throw new AppError("AUCTION_INVALID", 400, "上架时长需为8、12或24小时");
      if (!Number.isSafeInteger(value.buyoutPrice) || value.buyoutPrice < 1 || value.buyoutPrice > 9_000_000_000_000_000) throw new AppError("AUCTION_INVALID", 400, "价格需为正整数");
      const count = this.database.prepare(
        `SELECT count(*) AS count FROM auction_listings WHERE seller_character_id = ? AND status = 'active'`,
      ).get(value.characterId) as { count: number };
      if (Number(count.count) >= 3) throw new AppError("AUCTION_LIMIT", 400, "每个角色最多同时上架3件物品");
      const warehouse = this.database.prepare(
        `SELECT count(*) AS count FROM auction_listings
          WHERE seller_character_id = ? AND status IN ('active', 'sold', 'cancelled', 'expired')`,
      ).get(value.characterId) as { count: number };
      if (Number(warehouse.count) >= 30) throw new AppError("AUCTION_LIMIT", 400, "拍卖仓库已满，请先领取订单");
      const character = this.database.prepare(
        `SELECT display_name FROM characters WHERE id = ? AND deleted_at IS NULL`,
      ).get(value.characterId) as { display_name: string } | undefined;
      if (!character) throw new AppError("CHARACTER_REQUIRED", 409, "请先创建角色");
      const stateRow = this.database.prepare(`SELECT state_json FROM character_states WHERE character_id = ?`).get(value.characterId) as { state_json: string } | undefined;
      const state = parseGameState(stateRow?.state_json);
      let item: Record<string, unknown> | undefined;
      if (value.itemKind === "equipment") {
        const id = String(value.itemId);
        const equipment = state.equipmentBag.find((entry) => entry.id === id);
        const isEligible = equipment?.quality === 4 || Boolean(equipment?.suitName);
        if (!equipment || !isEligible || equipment.locked || equipment.bound || Object.values(state.equipped).includes(id) || (equipment.gems ?? []).some((gem) => Number(gem) !== 0)) throw new AppError("AUCTION_INVALID", 400, "仅未绑定、未锁定、未镶嵌的传说或套装装备可以上架");
        if (value.itemCount !== 1) throw new AppError("AUCTION_INVALID", 400, "装备每单只能上架1件");
        item = { ...equipment };
        state.equipmentBag = state.equipmentBag.filter((entry) => entry.id !== id);
      } else if (value.itemKind === "item") {
        const id = Number(value.itemId);
        if (id !== 6) throw new AppError("AUCTION_INVALID", 400, "只有打孔器可以作为道具上架");
        if (!Number.isInteger(value.itemCount) || value.itemCount < 1 || !removeTradableItem(state, id, value.itemCount)) throw new AppError("AUCTION_INVALID", 400, "可交易打孔器数量不足");
        item = { itemId: id, bound: false };
      } else {
        const id = Number(value.itemId);
        const level = value.itemLevel ?? 1;
        if (!Number.isInteger(id) || id < 1 || id > 8 || !Number.isInteger(level) || level < 1 || level > 10 || !Number.isInteger(value.itemCount) || value.itemCount < 1) throw new AppError("AUCTION_INVALID", 400, "宝石参数不正确");
        const gem = state.gemBag.find((entry) => entry.gemId === id && (entry.level ?? 1) === level && !entry.bound);
        if (!gem || gem.count < value.itemCount) throw new AppError("AUCTION_INVALID", 400, "宝石数量不足");
        gem.count -= value.itemCount;
        state.gemBag = state.gemBag.filter((entry) => entry.count > 0);
        item = { gemId: id, level, bound: false };
      }
      const now = Date.now();
      const id = randomUUID();
      this.database.prepare(`UPDATE character_states SET state_json = ?, updated_at = ? WHERE character_id = ?`).run(serializeGameState(state), now, value.characterId);
      this.database.prepare(
        `INSERT INTO auction_listings (id, seller_character_id, seller_name, item_kind, item_json, item_count, buyout_price, created_at, expires_at, client_request_id)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      ).run(id, value.characterId, character.display_name, value.itemKind, JSON.stringify(item), value.itemCount, value.buyoutPrice, now, now + value.durationHours * 60 * 60_000, value.requestId);
      const row = this.database.prepare(`SELECT * FROM auction_listings WHERE id = ?`).get(id) as Record<string, unknown>;
      return listingFromRow(row);
    });
    return create.immediate(input);
  }

  async buyAuctionListing(characterId: string, requestId: string, listingId: string) {
    const buy = this.database.transaction(() => {
      const repeated = this.database.prepare(
        `SELECT result_json FROM game_commands WHERE character_id = ? AND request_id = ? AND command = 'auction_buy'`,
      ).get(characterId, requestId) as { result_json: string } | undefined;
      if (repeated) {
        const result = JSON.parse(repeated.result_json) as { listing: AuctionListing; state: GameState; gold: number };
        if (result.listing.id !== listingId) throw new AppError("REQUEST_ID_REUSED", 409, "request_id已用于其他购买请求");
        return result;
      }
      const listingRow = this.database.prepare(`SELECT * FROM auction_listings WHERE id = ?`).get(listingId) as Record<string, unknown> | undefined;
      if (!listingRow) throw new AppError("AUCTION_NOT_FOUND", 404, "拍卖订单不存在");
      const listing = listingFromRow(listingRow);
      if (listing.sellerCharacterId === characterId) throw new AppError("AUCTION_INVALID", 400, "不能购买自己的订单");
      if (listing.status !== "active" || listing.expiresAt <= Date.now()) throw new AppError("AUCTION_UNAVAILABLE", 409, "订单已不可购买");
      const buyer = this.database.prepare(`SELECT gold FROM characters WHERE id = ?`).get(characterId) as { gold: number } | undefined;
      if (!buyer || buyer.gold < listing.buyoutPrice) throw new AppError("GOLD_INSUFFICIENT", 400, "金币不足");
      const state = parseGameState((this.database.prepare(`SELECT state_json FROM character_states WHERE character_id = ?`).get(characterId) as { state_json: string } | undefined)?.state_json);
      if (listing.itemKind === "item") {
        if (!addItem(state, Number(listing.item.itemId), listing.itemCount, true)) throw new AppError("INVENTORY_FULL", 400, "背包空间不足");
      } else if (listing.itemKind === "gem") {
        const gemId = Number(listing.item.gemId);
        const level = Number(listing.item.level ?? 1);
        const gem = state.gemBag.find((entry) => entry.gemId === gemId && (entry.level ?? 1) === level && entry.bound);
        if (gem) gem.count += listing.itemCount; else state.gemBag.push({ gemId, level, count: listing.itemCount, bound: true });
      } else {
        if (state.equipmentBag.length >= state.equipmentCapacity) throw new AppError("EQUIPMENT_FULL", 400, "装备背包空间不足");
        state.equipmentBag.push({ ...(listing.item as unknown as EquipmentItem), bound: true });
      }
      this.database.prepare(`UPDATE character_states SET state_json = ?, updated_at = ? WHERE character_id = ?`).run(serializeGameState(state), Date.now(), characterId);
      this.database.prepare(`UPDATE characters SET gold = gold - ?, revision = revision + 1 WHERE id = ?`).run(listing.buyoutPrice, characterId);
      this.database.prepare(`UPDATE auction_listings SET status = 'sold', buyer_character_id = ?, claim_character_id = seller_character_id, sold_at = ? WHERE id = ? AND status = 'active'`).run(characterId, Date.now(), listingId);
      const updated = this.database.prepare(`SELECT * FROM auction_listings WHERE id = ?`).get(listingId) as Record<string, unknown>;
      const result = { listing: listingFromRow(updated), state, gold: Number(buyer.gold) - listing.buyoutPrice };
      this.database.prepare(
        `INSERT INTO game_commands (character_id, request_id, command, result_json) VALUES (?, ?, 'auction_buy', ?)`,
      ).run(characterId, requestId, JSON.stringify(result));
      return result;
    });
    return buy.immediate();
  }

  async cancelAuctionListing(characterId: string, listingId: string): Promise<AuctionListing> {
    const cancel = this.database.transaction(() => {
      const row = this.database.prepare(`SELECT * FROM auction_listings WHERE id = ?`).get(listingId) as Record<string, unknown> | undefined;
      if (!row || String(row.seller_character_id) !== characterId || String(row.status) !== "active") throw new AppError("AUCTION_INVALID", 400, "订单无法取消");
      this.database.prepare(`UPDATE auction_listings SET status = 'cancelled', claim_character_id = seller_character_id WHERE id = ?`).run(listingId);
      return listingFromRow(this.database.prepare(`SELECT * FROM auction_listings WHERE id = ?`).get(listingId) as Record<string, unknown>);
    });
    return cancel.immediate();
  }

  async claimAuctionListing(characterId: string, listingId: string) {
    const claim = this.database.transaction(() => {
      const row = this.database.prepare(`SELECT * FROM auction_listings WHERE id = ?`).get(listingId) as Record<string, unknown> | undefined;
      if (!row) throw new AppError("AUCTION_NOT_FOUND", 404, "拍卖订单不存在");
      const listing = listingFromRow(row);
      if (listing.claimCharacterId !== characterId || !["sold", "cancelled", "expired"].includes(listing.status)) throw new AppError("AUCTION_INVALID", 400, "没有可领取的订单");
      const state = parseGameState((this.database.prepare(`SELECT state_json FROM character_states WHERE character_id = ?`).get(characterId) as { state_json: string } | undefined)?.state_json);
      let gold = 0;
      if (listing.status === "sold") gold = Math.max(0, listing.buyoutPrice - Math.floor(listing.buyoutPrice * 5 / 100));
      else if (listing.itemKind === "item") {
        if (!addItem(state, Number(listing.item.itemId), listing.itemCount)) throw new AppError("INVENTORY_FULL", 400, "背包空间不足");
      } else if (listing.itemKind === "equipment") {
        if (state.equipmentBag.length >= state.equipmentCapacity) throw new AppError("EQUIPMENT_FULL", 400, "装备背包空间不足");
        state.equipmentBag.push(listing.item as unknown as EquipmentItem);
      } else {
        const gemId = Number(listing.item.gemId);
        const level = Number(listing.item.level ?? 1);
        const gem = state.gemBag.find((entry) => entry.gemId === gemId && (entry.level ?? 1) === level && !entry.bound);
        if (gem) gem.count += listing.itemCount; else state.gemBag.push({ gemId, level, count: listing.itemCount });
      }
      this.database.prepare(`UPDATE characters SET gold = gold + ?, revision = revision + 1 WHERE id = ?`).run(gold, characterId);
      this.database.prepare(`UPDATE character_states SET state_json = ?, updated_at = ? WHERE character_id = ?`).run(serializeGameState(state), Date.now(), characterId);
      this.database.prepare(`UPDATE auction_listings SET status = 'claimed' WHERE id = ?`).run(listingId);
      return { listing: listingFromRow(this.database.prepare(`SELECT * FROM auction_listings WHERE id = ?`).get(listingId) as Record<string, unknown>), state, gold };
    });
    return claim.immediate();
  }

  async listChatMessages(channel: "world" | "system", limit: number): Promise<ChatMessage[]> {
    const safeLimit = Math.max(1, Math.min(Math.floor(limit), 100));
    const rows = this.database.prepare(
      `SELECT m.id, m.channel, c.display_name AS sender_name, m.body, m.created_at
         FROM chat_messages m
         LEFT JOIN characters c ON c.id = m.sender_character_id
        WHERE m.channel = ?
        ORDER BY m.id DESC
        LIMIT ?`,
    ).all(channel, safeLimit) as Record<string, unknown>[];
    return rows.reverse().map(chatMessageFromRow);
  }

  async createChatMessage(input: CreateChatMessageInput): Promise<ChatMessage> {
    const create = this.database.transaction((value: CreateChatMessageInput) => {
      const character = this.database.prepare(
        `SELECT id FROM characters
          WHERE account_id = ? AND deleted_at IS NULL`,
      ).get(value.accountId) as { id: string } | undefined;
      if (!character) {
        throw new AppError("CHARACTER_REQUIRED", 409, "请先创建角色");
      }

      const repeated = this.database.prepare(
        `SELECT m.id, m.channel, c.display_name AS sender_name, m.body, m.created_at
           FROM chat_messages m
           LEFT JOIN characters c ON c.id = m.sender_character_id
          WHERE m.sender_character_id = ? AND m.client_message_id = ?`,
      ).get(character.id, value.clientMessageId) as Record<string, unknown> | undefined;
      if (repeated) {
        return chatMessageFromRow(repeated);
      }

      const at = Date.now();
      const mute = this.database.prepare(
        `SELECT 1 FROM chat_mutes
          WHERE account_id = ? AND revoked_at IS NULL
            AND starts_at <= ? AND ends_at > ?
          LIMIT 1`,
      ).get(value.accountId, at, at);
      if (mute) {
        throw new AppError("CHAT_MUTED", 403, "你当前被禁言，暂时不能发言");
      }

      this.database.prepare(
        `DELETE FROM chat_messages
          WHERE channel = 'world' AND created_at < ?`,
      ).run(at - 7 * 24 * 60 * 60_000);
      const result = this.database.prepare(
        `INSERT INTO chat_messages (channel, sender_character_id, body, client_message_id, created_at)
         VALUES ('world', ?, ?, ?, ?)`,
      ).run(character.id, value.body, value.clientMessageId, at);
      const inserted = this.database.prepare(
        `SELECT m.id, m.channel, c.display_name AS sender_name, m.body, m.created_at
           FROM chat_messages m
           LEFT JOIN characters c ON c.id = m.sender_character_id
          WHERE m.id = ?`,
      ).get(result.lastInsertRowid) as Record<string, unknown>;
      return chatMessageFromRow(inserted);
    });

    try {
      return create.immediate(input);
    } catch (error) {
      const message = errorMessage(error);
      if (
        message.includes("chat_messages.sender_character_id") &&
        message.includes("chat_messages.client_message_id")
      ) {
        const repeated = this.database.prepare(
          `SELECT m.id, m.channel, c.display_name AS sender_name, m.body, m.created_at
             FROM chat_messages m
             LEFT JOIN characters c ON c.id = m.sender_character_id
            JOIN characters sender ON sender.id = m.sender_character_id
            WHERE sender.account_id = ? AND m.client_message_id = ?`,
        ).get(input.accountId, input.clientMessageId) as Record<string, unknown> | undefined;
        if (repeated) return chatMessageFromRow(repeated);
      }
      throw error;
    }
  }
}
