import type { WebSocket } from "ws";
import { AppError } from "./errors.js";

const RECONNECT_GRACE_MS = 30_000;
const HEARTBEAT_TIMEOUT_MS = 30_000;

interface SessionEntry {
  id: string;
  accountId: string;
  tokenHash: string;
  lastSeenAt: number;
  expiresAt: number;
  graceUntil: number | null;
  socket: WebSocket | null;
}

export type SessionRemovalReason =
  | "logout"
  | "replaced_by_new_login"
  | "reconnect_timeout"
  | "heartbeat_timeout"
  | "session_expired"
  | "server_shutdown";

export interface SessionIdentity {
  sessionId: string;
  accountId: string;
}

export class SessionManager {
  private readonly bySession = new Map<string, SessionEntry>();
  private readonly byAccount = new Map<string, SessionEntry>();
  private readonly byTokenHash = new Map<string, SessionEntry>();

  constructor(
    private readonly maxOnline: number,
    private readonly now: () => number = Date.now,
    private readonly onRemoved?: (sessionId: string, reason: SessionRemovalReason) => void,
  ) {}

  get onlineCount(): number {
    this.cleanupExpired();
    return this.byAccount.size;
  }

  canAdmit(accountId: string): boolean {
    this.cleanupExpired();
    return this.byAccount.has(accountId) || this.byAccount.size < this.maxOnline;
  }

  admit(sessionId: string, accountId: string, tokenHash: string, expiresAt?: number): void {
    this.cleanupExpired();
    const previous = this.byAccount.get(accountId);
    if (!previous && this.byAccount.size >= this.maxOnline) {
      throw new AppError("SERVER_FULL", 503, "服务器人数已满，请稍后登录");
    }
    if (previous) {
      this.remove(previous, "replaced_by_new_login", true);
    }

    const entry: SessionEntry = {
      id: sessionId,
      accountId,
      tokenHash,
      lastSeenAt: this.now(),
      expiresAt: expiresAt ?? this.now() + 7 * 24 * 60 * 60_000,
      graceUntil: this.now() + RECONNECT_GRACE_MS,
      socket: null,
    };
    this.bySession.set(sessionId, entry);
    this.byAccount.set(accountId, entry);
    this.byTokenHash.set(tokenHash, entry);
  }

  resolveToken(tokenHash: string): SessionIdentity {
    this.cleanupExpired();
    const entry = this.byTokenHash.get(tokenHash);
    if (!entry) {
      throw new AppError("SESSION_INVALID", 401, "登录已失效，请重新登录");
    }
    entry.lastSeenAt = this.now();
    return { sessionId: entry.id, accountId: entry.accountId };
  }

  attachSocket(tokenHash: string, socket: WebSocket): SessionIdentity {
    const identity = this.resolveToken(tokenHash);
    const entry = this.bySession.get(identity.sessionId);
    if (!entry) {
      throw new AppError("SESSION_INVALID", 401, "登录已失效，请重新登录");
    }
    if (entry.socket && entry.socket !== socket) {
      this.sendAndClose(entry.socket, "KICKED", "账号已在其他页面连接");
    }
    entry.socket = socket;
    entry.graceUntil = null;
    entry.lastSeenAt = this.now();
    return identity;
  }

  heartbeat(sessionId: string): void {
    const entry = this.bySession.get(sessionId);
    if (!entry) {
      throw new AppError("SESSION_INVALID", 401, "登录已失效，请重新登录");
    }
    entry.lastSeenAt = this.now();
  }

  markDisconnected(sessionId: string, socket: WebSocket): void {
    const entry = this.bySession.get(sessionId);
    if (!entry || entry.socket !== socket) {
      return;
    }
    entry.socket = null;
    entry.graceUntil = this.now() + RECONNECT_GRACE_MS;
  }

  revoke(sessionId: string, reason: SessionRemovalReason = "logout"): void {
    const entry = this.bySession.get(sessionId);
    if (entry) {
      this.remove(entry, reason, true);
    }
  }

  cleanupExpired(): void {
    const current = this.now();
    for (const entry of Array.from(this.bySession.values())) {
      if (current >= entry.expiresAt) {
        this.remove(entry, "session_expired", true);
      } else if (entry.socket && current - entry.lastSeenAt >= HEARTBEAT_TIMEOUT_MS) {
        this.remove(entry, "heartbeat_timeout", true);
      } else if (!entry.socket && entry.graceUntil !== null && current >= entry.graceUntil) {
        this.remove(entry, "reconnect_timeout", false);
      }
    }
  }

  shutdown(): void {
    for (const entry of Array.from(this.bySession.values())) {
      this.remove(entry, "server_shutdown", true);
    }
  }

  private remove(entry: SessionEntry, reason: SessionRemovalReason, notify: boolean): void {
    if (this.bySession.get(entry.id) !== entry) {
      return;
    }
    this.bySession.delete(entry.id);
    this.byTokenHash.delete(entry.tokenHash);
    if (this.byAccount.get(entry.accountId) === entry) {
      this.byAccount.delete(entry.accountId);
    }
    if (notify && entry.socket) {
      const message = reason === "replaced_by_new_login"
        ? "账号已在其他设备登录"
        : "连接已结束，请重新登录";
      this.sendAndClose(entry.socket, reason.toUpperCase(), message);
    }
    this.onRemoved?.(entry.id, reason);
  }

  private sendAndClose(socket: WebSocket, code: string, message: string): void {
    try {
      socket.send(JSON.stringify({ type: "error", code, message }));
    } finally {
      socket.close(4001, code);
    }
  }
}
