import type { GameCommandResult } from "./game-engine.js";
import type { GameState } from "./game-state.js";

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

export interface GameCommandInput {
  characterId: string;
  requestId: string;
  command: string;
  payload: Record<string, unknown>;
}

export interface AuctionListing {
  id: string;
  sellerCharacterId: string;
  sellerName: string;
  itemKind: "equipment" | "item" | "gem";
  item: Record<string, unknown>;
  itemCount: number;
  buyoutPrice: number;
  status: string;
  createdAt: number;
  expiresAt: number;
  buyerCharacterId: string | null;
  claimCharacterId: string | null;
}

export interface CreateAuctionInput {
  characterId: string;
  requestId: string;
  itemKind: "equipment" | "item" | "gem";
  itemId: string | number;
  itemCount: number;
  buyoutPrice: number;
  durationHours: number;
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
  getGameState?(characterId: string): Promise<GameState>;
  executeGameCommand?(input: GameCommandInput): Promise<GameCommandResult>;
  listAuctionListings?(limit: number): Promise<AuctionListing[]>;
  listMyAuctionListings?(characterId: string, limit: number): Promise<AuctionListing[]>;
  createAuctionListing?(input: CreateAuctionInput): Promise<AuctionListing>;
  buyAuctionListing?(characterId: string, requestId: string, listingId: string): Promise<{ listing: AuctionListing; state: GameState; gold: number }>;
  cancelAuctionListing?(characterId: string, listingId: string): Promise<AuctionListing>;
  claimAuctionListing?(characterId: string, listingId: string): Promise<{ listing: AuctionListing; state: GameState; gold: number }>;
}
