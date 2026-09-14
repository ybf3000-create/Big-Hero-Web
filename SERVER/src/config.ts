import "dotenv/config";

export interface ServerConfig {
  host: string;
  port: number;
  databasePath: string;
  backupDirectory: string;
  trustProxy: boolean;
  logLevel: string;
  rulesVersion: string;
  maxOnlinePlayers: number;
}

function integerEnv(name: string, fallback: number, minimum: number, maximum: number): number {
  const raw = process.env[name];
  if (raw === undefined || raw === "") {
    return fallback;
  }
  const parsed = Number(raw);
  if (!Number.isInteger(parsed) || parsed < minimum || parsed > maximum) {
    throw new Error(`${name} must be an integer between ${minimum} and ${maximum}`);
  }
  return parsed;
}

function booleanEnv(name: string, fallback: boolean): boolean {
  const raw = process.env[name];
  if (raw === undefined || raw === "") {
    return fallback;
  }
  if (raw === "true") {
    return true;
  }
  if (raw === "false") {
    return false;
  }
  throw new Error(`${name} must be true or false`);
}

export function loadConfig(): ServerConfig {
  const databasePath = process.env.DATABASE_PATH;
  if (!databasePath) {
    throw new Error("DATABASE_PATH is required");
  }

  return {
    host: process.env.HOST ?? "127.0.0.1",
    port: integerEnv("PORT", 3000, 1, 65535),
    databasePath,
    backupDirectory: process.env.BACKUP_DIRECTORY ?? "C:/BigHeroBackups",
    trustProxy: booleanEnv("TRUST_PROXY", false),
    logLevel: process.env.LOG_LEVEL ?? "info",
    rulesVersion: process.env.RULES_VERSION ?? "network-1",
    maxOnlinePlayers: integerEnv("MAX_ONLINE_PLAYERS", 20, 1, 20),
  };
}
