import assert from "node:assert/strict";
import test from "node:test";
import type { WebSocket } from "ws";
import { AppError } from "../src/errors.js";
import { SessionManager } from "../src/session-manager.js";

function fakeSocket(): WebSocket & { sent: string[]; closeCode?: number } {
  const socket: { sent: string[]; closeCode?: number; send(value: string): void; close(code: number): void } = {
    sent: [] as string[],
    send(value: string) {
      this.sent.push(value);
    },
    close(code: number) {
      this.closeCode = code;
    },
  };
  return socket as unknown as WebSocket & { sent: string[]; closeCode?: number };
}

test("the 21st distinct account is rejected while a replacement login is allowed", () => {
  const manager = new SessionManager(20);
  for (let index = 0; index < 20; index += 1) {
    manager.admit(`session-${index}`, `account-${index}`, `token-${index}`);
  }
  assert.equal(manager.onlineCount, 20);
  assert.throws(
    () => manager.admit("session-21", "account-21", "token-21"),
    (error: unknown) => error instanceof AppError && error.code === "SERVER_FULL",
  );
  manager.admit("replacement", "account-0", "replacement-token");
  assert.equal(manager.onlineCount, 20);
});

test("a new login kicks the previous socket for the same account", () => {
  const manager = new SessionManager(1);
  const socket = fakeSocket();
  manager.admit("old-session", "account", "old-token");
  manager.attachSocket("old-token", socket);
  manager.admit("new-session", "account", "new-token");
  assert.equal(socket.closeCode, 4001);
  assert.match(socket.sent[0] ?? "", /其他设备登录/);
  assert.equal(manager.resolveToken("new-token").sessionId, "new-session");
});

test("a disconnected or never-connected session keeps its slot for exactly 30 seconds", () => {
  let current = 1_000;
  const manager = new SessionManager(1, () => current);
  manager.admit("session", "account", "token");
  current += 29_999;
  assert.equal(manager.onlineCount, 1);
  current += 1;
  assert.equal(manager.onlineCount, 0);
  assert.throws(() => manager.resolveToken("token"));
});

test("a session is rejected when its seven-day absolute lifetime ends", () => {
  let current = 1_000;
  const manager = new SessionManager(1, () => current);
  manager.admit("session", "account", "token", current + 7 * 24 * 60 * 60_000);
  current += 7 * 24 * 60 * 60_000;
  assert.equal(manager.onlineCount, 0);
  assert.throws(() => manager.resolveToken("token"));
});
