import { mkdirSync } from "node:fs";
import path from "node:path";
import Database from "better-sqlite3";

export function resolveDatabasePath(databasePath: string): string {
  return databasePath === ":memory:" ? databasePath : path.resolve(databasePath);
}

export function openSqliteDatabase(databasePath: string): Database.Database {
  const resolvedPath = resolveDatabasePath(databasePath);
  if (resolvedPath !== ":memory:") {
    mkdirSync(path.dirname(resolvedPath), { recursive: true });
  }

  const database = new Database(resolvedPath, { timeout: 5_000 });
  database.pragma("foreign_keys = ON");
  database.pragma("busy_timeout = 5000");
  database.pragma("synchronous = FULL");
  if (resolvedPath !== ":memory:") {
    database.pragma("journal_mode = WAL");
  }
  return database;
}
