import { AppError, badRequest } from "./errors.js";

const USERNAME_PATTERN = /^[a-z][a-z0-9_]{3,19}$/;
const RESERVED_USERNAMES = new Set(["admin", "administrator", "system", "gm", "moderator"]);
const WEAK_PASSWORDS = new Set([
  "1234567890",
  "password123",
  "qwerty1234",
  "1111111111",
  "0000000000",
]);

export interface CharacterNameValidation {
  valid: boolean;
  normalized: string;
  weight: number;
  error?: string;
}

export function normalizeUsername(value: string): string {
  return value.toLowerCase();
}

export function validateUsername(value: unknown): string {
  if (typeof value !== "string") {
    throw badRequest("账号格式不正确");
  }
  const normalized = normalizeUsername(value);
  if (!USERNAME_PATTERN.test(normalized) || RESERVED_USERNAMES.has(normalized)) {
    throw badRequest("账号需为4～20位，以字母开头，只能使用小写字母、数字和下划线");
  }
  return normalized;
}

export function validatePassword(value: unknown): string {
  if (typeof value !== "string") {
    throw badRequest("密码格式不正确");
  }
  const characterCount = Array.from(value).length;
  const byteCount = Buffer.byteLength(value, "utf8");
  if (characterCount < 10 || characterCount > 64 || byteCount > 256) {
    throw badRequest("密码长度需为10～64个字符");
  }
  if (value.trim().length === 0 || WEAK_PASSWORDS.has(value.toLowerCase())) {
    throw badRequest("密码过于简单");
  }
  for (const character of value) {
    const codePoint = character.codePointAt(0) ?? 0;
    if (codePoint < 0x20 || codePoint === 0x7f) {
      throw badRequest("密码不能包含控制字符");
    }
  }
  return value;
}

export function validateRequestId(value: unknown): string {
  if (typeof value !== "string" || !/^[A-Za-z0-9_-]{8,64}$/.test(value)) {
    throw badRequest("request_id格式不正确");
  }
  return value;
}

export function validateRulesVersion(value: unknown, expected: string): void {
  if (value !== expected) {
    throw new AppError(
      "RULES_VERSION_MISMATCH",
      409,
      "游戏已更新，请刷新页面",
      { expected_rules_version: expected },
    );
  }
}

function isCjk(codePoint: number): boolean {
  return (
    (codePoint >= 0x3400 && codePoint <= 0x4dbf) ||
    (codePoint >= 0x4e00 && codePoint <= 0x9fff) ||
    (codePoint >= 0xf900 && codePoint <= 0xfaff)
  );
}

function isAsciiLetterOrDigit(codePoint: number): boolean {
  return (
    (codePoint >= 48 && codePoint <= 57) ||
    (codePoint >= 65 && codePoint <= 90) ||
    (codePoint >= 97 && codePoint <= 122)
  );
}

export function inspectCharacterName(value: unknown): CharacterNameValidation {
  if (typeof value !== "string" || value.length === 0) {
    return { valid: false, normalized: "", weight: 0, error: "角色名不能为空" };
  }
  if (value.trim() !== value) {
    return { valid: false, normalized: value.toLowerCase(), weight: 0, error: "角色名不能包含空格" };
  }

  let weight = 0;
  for (const character of value) {
    const codePoint = character.codePointAt(0) ?? 0;
    if (isAsciiLetterOrDigit(codePoint)) {
      weight += 1;
    } else if (isCjk(codePoint)) {
      weight += 2;
    } else {
      return {
        valid: false,
        normalized: value.toLowerCase(),
        weight,
        error: "角色名只能使用汉字、英文字母和数字",
      };
    }
    if (weight > 14) {
      return {
        valid: false,
        normalized: value.toLowerCase(),
        weight,
        error: "角色名最多7个汉字或14个字母/数字",
      };
    }
  }

  return { valid: true, normalized: value.toLowerCase(), weight };
}

export function validateCharacterName(value: unknown): { displayName: string; normalized: string } {
  const result = inspectCharacterName(value);
  if (!result.valid) {
    throw new AppError(
      "CHARACTER_NAME_INVALID",
      400,
      result.error ?? "角色名格式不正确",
    );
  }
  return { displayName: value as string, normalized: result.normalized };
}
