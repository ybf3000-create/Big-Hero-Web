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
  | "REQUEST_ID_REUSED"
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
