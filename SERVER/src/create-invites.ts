import { randomUUID } from "node:crypto";
import { loadConfig } from "./config.js";
import { generateInviteCode, hashSecret } from "./security.js";
import { SqliteRepository } from "./sqlite-repository.js";

const countArgument = process.argv.find((argument) => argument.startsWith("--count="));
const count = countArgument ? Number(countArgument.slice("--count=".length)) : 1;
if (!Number.isInteger(count) || count < 1 || count > 100) {
  throw new Error("--count must be an integer between 1 and 100");
}

const config = loadConfig();
const repository = new SqliteRepository(config.databasePath);
const codes: string[] = [];

try {
  for (let index = 0; index < count; index += 1) {
    let created = false;
    for (let attempt = 0; attempt < 3 && !created; attempt += 1) {
      const code = generateInviteCode();
      try {
        repository.insertInviteCode(randomUUID(), hashSecret(code));
        codes.push(code);
        created = true;
      } catch (error) {
        if ((error as { code?: string }).code !== "SQLITE_CONSTRAINT_UNIQUE") {
          throw error;
        }
      }
    }
    if (!created) {
      throw new Error("Unable to generate a unique invite code after 3 attempts");
    }
  }
  process.stdout.write(codes.join("\n") + "\n");
} finally {
  await repository.close();
}
