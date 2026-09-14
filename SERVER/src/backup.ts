import { mkdirSync } from "node:fs";
import path from "node:path";
import { loadConfig } from "./config.js";
import { openSqliteDatabase } from "./sqlite-database.js";

const config = loadConfig();
const backupDirectory = path.resolve(config.backupDirectory);
mkdirSync(backupDirectory, { recursive: true });

const timestamp = new Date().toISOString().replaceAll(":", "-");
const destination = path.join(backupDirectory, `big-hero-${timestamp}.sqlite`);
const database = openSqliteDatabase(config.databasePath);

try {
  await database.backup(destination);
  process.stdout.write(`Backup created: ${destination}\n`);
} finally {
  database.close();
}
