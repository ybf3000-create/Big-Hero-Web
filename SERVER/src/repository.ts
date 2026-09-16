export interface AccountForLogin {
  id: string;
  username: string;
  passwordHash: string;
  status: "normal" | "banned" | "deleted";
  bannedUntil: Date | null;
  mustChangePassword: boolean;
}

export interface AccountSummary {
  id: string;
  username: string;
}

export interface CharacterSummary {
  id: string;
  name: string;
  level: number;
  experience: number;
  gold: string;
  revision: number;
}

export interface ChatMessage {
  id: number;
  channel: "world" | "system";
  senderName: string | null;
  body: string;
  createdAt: number;
}

export interface CreateChatMessageInput {
  accountId: string;
  body: string;
  clientMessageId: string;
}

export interface RegisterAccountInput {
  requestId: string;
  username: string;
  passwordHash: string;
  inviteCodeHash: string;
}

export interface CreateSessionInput {
  id: string;
  accountId: string;
  tokenHash: string;
  createdAt: Date;
  idleExpiresAt: Date;
  expiresAt: Date;
}

export interface CreateCharacterInput {
  id: string;
  requestId: string;
  accountId: string;
  displayName: string;
  normalizedName: string;
}

export interface GameRepository {
  ping(): Promise<void>;
  close(): Promise<void>;
  registerAccount(input: RegisterAccountInput): Promise<AccountSummary>;
  findAccountForLogin(username: string): Promise<AccountForLogin | null>;
  createSession(input: CreateSessionInput): Promise<void>;
  touchSession(sessionId: string, at: Date, idleExpiresAt: Date): Promise<void>;
  revokeSession(sessionId: string, at: Date, reason: string): Promise<void>;
  revokeAccountSessions(accountId: string, at: Date, reason: string): Promise<void>;
  recordLoginAttempt(
    loginKeyHash: string,
    ipHash: string,
    result: string,
    at: Date,
  ): Promise<void>;
  getCharacter(accountId: string): Promise<CharacterSummary | null>;
  createCharacter(input: CreateCharacterInput): Promise<CharacterSummary>;
  listChatMessages?(channel: "world" | "system", limit: number): Promise<ChatMessage[]>;
  createChatMessage?(input: CreateChatMessageInput): Promise<ChatMessage>;
}
