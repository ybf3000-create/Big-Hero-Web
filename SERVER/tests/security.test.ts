import assert from "node:assert/strict";
import test from "node:test";
import {
  Argon2idPasswordHasher,
  generateInviteCode,
  generateSessionToken,
} from "../src/security.js";

test("production password hashing uses a verifiable Argon2id encoding", async () => {
  const hasher = new Argon2idPasswordHasher();
  const encoded = await hasher.hash("Good-password-2026");
  assert.match(encoded, /^\$argon2id\$/);
  assert.equal(await hasher.verify(encoded, "Good-password-2026"), true);
  assert.equal(await hasher.verify(encoded, "wrong-password"), false);
});

test("session and invite secrets have the required entropy-bearing lengths", () => {
  assert.match(generateSessionToken(), /^[A-Za-z0-9_-]{43}$/);
  assert.match(generateInviteCode(), /^[0-9A-HJKMNP-TV-Z]{26}$/);
});
