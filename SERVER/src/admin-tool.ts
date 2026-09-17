import { randomUUID } from "node:crypto";
import { createInterface } from "node:readline/promises";
import { stdin, stdout } from "node:process";
import { loadConfig } from "./config.js";
import { generateInviteCode, hashSecret, Argon2idPasswordHasher } from "./security.js";
import { normalizeUsername, validatePassword } from "./validation.js";
import { SqliteRepository } from "./sqlite-repository.js";

const repository = new SqliteRepository(loadConfig().databasePath);
const passwordHasher = new Argon2idPasswordHasher();
const input = createInterface({ input: stdin, output: stdout });

async function ask(label: string): Promise<string> {
  return (await input.question(label)).trim();
}

async function username(): Promise<string> {
  const value = normalizeUsername(await ask("账号："));
  if (!/^[a-z][a-z0-9_]{3,19}$/.test(value)) throw new Error("账号格式不正确");
  return value;
}

async function hours(label: string): Promise<number> {
  const value = Number(await ask(label));
  if (!Number.isInteger(value) || value < 1 || value > 72) throw new Error("时长需为1至72小时");
  return value;
}

async function main(): Promise<void> {
  stdout.write("\n大勇者本机管理员工具（操作前请先关闭游戏服务器）\n");
  for (;;) {
    stdout.write("\n1. 查看账号  2. 生成邀请码  3. 重置临时密码  4. 封号  5. 解封\n6. 禁言  7. 解除禁言  8. 删除账号  0. 退出\n");
    const action = await ask("请选择：");
    try {
      if (action === "0") return;
      if (action === "1") {
        const accounts = repository.listAccountsForAdmin();
        if (accounts.length === 0) stdout.write("当前没有账号。\n");
        for (const account of accounts) {
          const banned = account.bannedUntil && account.bannedUntil > Date.now() ? `，封号至 ${new Date(account.bannedUntil).toLocaleString("zh-CN")}` : "";
          const muted = account.mutedUntil && account.mutedUntil > Date.now() ? `，禁言至 ${new Date(account.mutedUntil).toLocaleString("zh-CN")}` : "";
          stdout.write(`${account.username}｜${account.characterName ?? "未创建角色"}｜${account.status}${banned}${muted}\n`);
        }
      } else if (action === "2") {
        const count = Number(await ask("生成数量（1至100）："));
        if (!Number.isInteger(count) || count < 1 || count > 100) throw new Error("数量需为1至100");
        for (let index = 0; index < count; index += 1) {
          const code = generateInviteCode();
          repository.insertInviteCode(randomUUID(), hashSecret(code));
          stdout.write(`${code}\n`);
        }
      } else if (action === "3") {
        const target = await username();
        const temporaryPassword = validatePassword(await ask("临时密码："));
        await repository.resetPasswordForAdmin(target, await passwordHasher.hash(temporaryPassword));
        stdout.write("临时密码已设置；玩家下次登录后必须修改密码。\n");
      } else if (action === "4") {
        repository.setBanForAdmin(await username(), await hours("封号小时（1至72）："), await ask("原因："));
        stdout.write("封号已生效。\n");
      } else if (action === "5") {
        repository.setBanForAdmin(await username(), null, await ask("原因："));
        stdout.write("账号已解封。\n");
      } else if (action === "6") {
        repository.setMuteForAdmin(await username(), await hours("禁言小时（1至72）："), await ask("原因："));
        stdout.write("禁言已生效。\n");
      } else if (action === "7") {
        repository.setMuteForAdmin(await username(), null, await ask("原因："));
        stdout.write("禁言已解除。\n");
      } else if (action === "8") {
        const target = await username();
        if (await ask(`输入账号 ${target} 再次确认删除：`) !== target) throw new Error("确认内容不一致，已取消");
        repository.deleteAccountForAdmin(target, await ask("删除原因："));
        stdout.write("账号和角色已逻辑删除。\n");
      } else {
        stdout.write("没有这个选项。\n");
      }
    } catch (error) {
      stdout.write(`操作失败：${error instanceof Error ? error.message : String(error)}\n`);
    }
  }
}

try {
  await main();
} finally {
  input.close();
  await repository.close();
}
