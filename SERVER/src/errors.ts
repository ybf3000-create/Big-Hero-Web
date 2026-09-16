export type ErrorCode =
  | "BAD_REQUEST"
  | "RULES_VERSION_MISMATCH"
  | "ACCOUNT_UNAVAILABLE"
  | "INVITE_INVALID"
  | "INVALID_CREDENTIALS"
  | "ACCOUNT_BANNED"
  | "SERVER_FULL"
  | "RATE_LIMITED"
  | "SESSION_INVALID"
  | "CHARACTER_EXISTS"
  | "CHARACTER_NAME_UNAVAILABLE"
  | "CHARACTER_NAME_INVALID"
  | "CHARACTER_REQUIRED"
  | "CHAT_MESSAGE_INVALID"
  | "CHAT_MUTED"
  | "CHAT_RATE_LIMITED"
  | "REQUEST_ID_REUSED"
  | "GAME_COMMAND_INVALID"
  | "AUCTION_INVALID"
  | "AUCTION_LIMIT"
  | "AUCTION_NOT_FOUND"
  | "AUCTION_UNAVAILABLE"
  | "GOLD_INSUFFICIENT"
  | "INVENTORY_FULL"
  | "EQUIPMENT_FULL"
  | "SERVICE_UNAVAILABLE";

export class AppError extends Error {
  constructor(
    public readonly code: ErrorCode,
    public readonly statusCode: number,
    message: string,
    public readonly details?: Record<string, unknown>,
  ) {
    super(message);
    this.name = "AppError";
  }
}

export function badRequest(message: string): AppError {
  return new AppError("BAD_REQUEST", 400, message);
}
