import path from "node:path";
import { fileURLToPath } from "node:url";
import { buildApp } from "./app.js";
import { loadConfig } from "./config.js";
import { Argon2idPasswordHasher } from "./security.js";
import { SqliteRepository } from "./sqlite-repository.js";

const config = loadConfig();
const currentDirectory = path.dirname(fileURLToPath(import.meta.url));
const staticRoot = path.resolve(currentDirectory, "../public");
const repository = new SqliteRepository(config.databasePath);
const app = await buildApp({
  repository,
  passwordHasher: new Argon2idPasswordHasher(),
  rulesVersion: config.rulesVersion,
  maxOnlinePlayers: config.maxOnlinePlayers,
  trustProxy: config.trustProxy,
  logger: { level: config.logLevel },
  staticRoot,
});

const shutdown = async (signal: string): Promise<void> => {
  app.log.info({ signal }, "shutting down");
  await app.close();
  process.exit(0);
};

process.once("SIGINT", () => void shutdown("SIGINT"));
process.once("SIGTERM", () => void shutdown("SIGTERM"));

try {
  await app.listen({ host: config.host, port: config.port });
} catch (error) {
  app.log.error(error);
  await app.close();
  process.exit(1);
}
