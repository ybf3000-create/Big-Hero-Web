import { readdirSync, readFileSync } from "node:fs";
import path from "node:path";
import type Database from "better-sqlite3";

interface MigrationRow {
  version: string;
}

export function applyMigrations(
  database: Database.Database,
  migrationsDirectory: string,
  onApplied?: (file: string) => void,
): void {
  database.exec(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      version TEXT PRIMARY KEY,
      applied_at INTEGER NOT NULL DEFAULT (unixepoch() * 1000)
    ) STRICT;
  `);

  const applied = new Set(
    database.prepare("SELECT version FROM schema_migrations")
      .all()
      .map((row) => (row as MigrationRow).version),
  );
  const files = readdirSync(migrationsDirectory)
    .filter((file) => file.endsWith(".sql"))
    .sort();

  const applyOne = database.transaction((file: string) => {
    database.exec(readFileSync(path.join(migrationsDirectory, file), "utf8"));
    database.prepare("INSERT INTO schema_migrations (version) VALUES (?)").run(file);
  });

  for (const file of files) {
    if (applied.has(file)) {
      continue;
    }
    applyOne.immediate(file);
    onApplied?.(file);
  }
}
