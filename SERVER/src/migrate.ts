import path from "node:path";
import { fileURLToPath } from "node:url";
import { loadConfig } from "./config.js";
import { applyMigrations } from "./migrations.js";
import { openSqliteDatabase } from "./sqlite-database.js";

const currentDirectory = path.dirname(fileURLToPath(import.meta.url));
const migrationsDirectory = path.resolve(currentDirectory, "../db/migrations");
const config = loadConfig();
const database = openSqliteDatabase(config.databasePath);

try {
  applyMigrations(database, migrationsDirectory, (file) => {
    process.stdout.write(`Applied ${file}\n`);
  });
} finally {
  database.close();
}
