import { Algorithm, hash, verify, Version } from "@node-rs/argon2";
import { createHash, randomBytes } from "node:crypto";

export interface PasswordHasher {
  hash(password: string): Promise<string>;
  verify(encodedHash: string, password: string): Promise<boolean>;
}

export class Argon2idPasswordHasher implements PasswordHasher {
  async hash(password: string): Promise<string> {
    return hash(password, {
      algorithm: Algorithm.Argon2id,
      version: Version.V0x13,
      memoryCost: 19_456,
      timeCost: 2,
      parallelism: 1,
      outputLen: 32,
    });
  }

  async verify(encodedHash: string, password: string): Promise<boolean> {
    try {
      return await verify(encodedHash, password);
    } catch {
      return false;
    }
  }
}

export function generateSessionToken(): string {
  return randomBytes(32).toString("base64url");
}

export function hashSecret(value: string): string {
  return createHash("sha256").update(value, "utf8").digest("hex");
}

const INVITE_ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";

export function generateInviteCode(): string {
  const random = randomBytes(26);
  let result = "";
  for (const byte of random) {
    result += INVITE_ALPHABET[byte & 31];
  }
  return result;
}

export function normalizeInviteCode(value: string): string {
  return value.replaceAll("-", "").trim().toUpperCase();
}
