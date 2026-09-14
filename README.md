---
version: v0.1
status: 开发中
---

# Big Hero Web

《大勇者》网页网络版单体仓库，面向最多20名玩家同时在线的个人服务器。

## 目录

| 目录 | 内容 |
|------|------|
| `client/` | Godot 4.4网页客户端及游戏内容 |
| `SERVER/` | TypeScript服务端、SQLite迁移与自动测试 |

## 本地运行

```powershell
cd SERVER
Copy-Item .env.example .env
npm install
npm run migrate
npm run dev
```

Godot Web导出到`SERVER/public/game/`后，使用Chrome或Edge访问`http://127.0.0.1:3000/game/`。详细部署、测试和备份说明见[`SERVER/README.md`](SERVER/README.md)。

## 安全边界

`.env`、SQLite运行库、备份、`node_modules`、构建结果和Godot导入缓存均不进入Git。公网部署必须使用HTTPS/WSS入口。

## 许可证

项目代码采用[MIT License](LICENSE)。字体和其他第三方资源继续遵循其各自许可证；`client/assets/fonts/NotoSansHans-LICENSE.txt`适用于仓库中的Noto Sans Hans字体。

---

## 附录：变更记录

| 版本 | 日期 | 变更内容 |
|------|------|---------|
| v0.1 | 2026-09-14 | 建立客户端与服务端单仓库说明、运行入口及许可证边界 |
