import { randomUUID } from "node:crypto";
import type Database from "better-sqlite3";
import { AppError } from "./errors.js";
import type {
  AccountForLogin,
  AccountSummary,
  CharacterSummary,
  CreateCharacterInput,
  CreateSessionInput,
  GameRepository,
  RegisterAccountInput,
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

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
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

  async touchSession(sessionId: string, at: Date, idleExpiresAt: Date): Promise<void> {
    this.database.prepare(
      `UPDATE sessions
          SET last_seen_at = ?, idle_expires_at = ?
        WHERE id = ? AND revoked_at IS NULL`,
    ).run(at.getTime(), idleExpiresAt.getTime(), sessionId);
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
}
