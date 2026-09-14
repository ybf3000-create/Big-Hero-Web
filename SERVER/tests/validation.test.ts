import assert from "node:assert/strict";
import test from "node:test";
import { auctionTransactionFee } from "../src/economy.js";
import {
  inspectCharacterName,
  validatePassword,
  validateUsername,
} from "../src/validation.js";

test("account names are normalized and validated", () => {
  assert.equal(validateUsername("Hero_01"), "hero_01");
  assert.throws(() => validateUsername("1hero"));
  assert.throws(() => validateUsername("gm"));
});

test("password policy enforces length, byte and weak-password boundaries", () => {
  assert.equal(validatePassword("勇者-pass-2026"), "勇者-pass-2026");
  assert.throws(() => validatePassword("short"));
  assert.throws(() => validatePassword("1234567890"));
});

test("character names use the confirmed weight-14 rule", () => {
  assert.deepEqual(
    inspectCharacterName("七个汉字名字啊"),
    { valid: true, normalized: "七个汉字名字啊", weight: 14 },
  );
  assert.equal(inspectCharacterName("八个汉字名字啊哈").valid, false);
  assert.equal(inspectCharacterName("Hero2026ABCDEF").valid, true);
  assert.equal(inspectCharacterName("勇者Hero2026").weight, 12);
  assert.equal(inspectCharacterName("勇者_01").valid, false);
});

test("auction fee follows option A and floors integer gold", () => {
  assert.equal(auctionTransactionFee(1n), 0n);
  assert.equal(auctionTransactionFee(19n), 0n);
  assert.equal(auctionTransactionFee(20n), 1n);
  assert.equal(auctionTransactionFee(99n), 4n);
  assert.equal(auctionTransactionFee(100n), 5n);
});
