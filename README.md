---
version: v0.3
status: 原生网页完整玩法界面可运行
---

# Big Hero Web

《大勇者》网页网络版单体仓库，面向最多20名玩家同时在线的个人服务器。玩家只需安装并加入同一个 ZeroTier 网络，然后在浏览器打开服务器地址即可进入原生网页客户端。

## 目录

| 目录 | 内容 |
|------|------|
| `client/` | Godot 4.4旧版客户端源码及游戏内容，作为后续玩法移植参考 |
| `web-client/` | 原生 HTML/CSS/JavaScript 客户端源码与构建入口 |
| `SERVER/` | TypeScript服务端、SQLite迁移、网页静态文件与自动测试 |

## 本地运行

服务器电脑首次部署：

```powershell
cd SERVER
Copy-Item .env.example .env
npm ci --include=dev --ignore-scripts
npm run migrate
npm run invite:create -- --count=5
```

之后双击 `SERVER/start-server.bat`，保持窗口运行。服务器本机访问 `http://127.0.0.1:3000/game/`；同一 ZeroTier 网络中的其他电脑访问 `http://服务器的ZeroTier地址:3000/game/`。不需要安装 Godot、不需要启动前端开发服务器，也不需要输入端口转发命令。

网页源码改变后，在仓库根目录执行 `cd web-client` 和 `npm run build`，构建结果会更新到 `SERVER/public/game/`。详细部署、测试和备份说明见[`SERVER/README.md`](SERVER/README.md)。

当前网页包含登录、邀请码注册、单角色创建、会话恢复、20人在线上限、世界聊天、28格地图、掷骰冒险、装备与八部位穿戴、技能配置、战斗表现、拍卖行和SQLite持久化。Godot版仍保留在`client/`作为规则与素材参考，网页端的战斗结算仍由服务端权威计算。

## 安全边界

`.env`、SQLite运行库、备份、`node_modules`和Godot导入缓存均不进入Git；`SERVER/public/game/`中的轻量网页发布文件会进入Git，确保服务器电脑克隆后即可启动。ZeroTier内网访问使用HTTP即可；若日后改为真正公网部署，再增加HTTPS/WSS反向代理。

## 许可证

项目代码采用[MIT License](LICENSE)。字体和其他第三方资源继续遵循其各自许可证；`client/assets/fonts/NotoSansHans-LICENSE.txt`适用于仓库中的Noto Sans Hans字体。

---

## 附录：变更记录

| 版本 | 日期 | 变更内容 |
|------|------|---------|
| v0.1 | 2026-09-14 | 建立客户端与服务端单仓库说明、运行入口及许可证边界 |
| v0.2 | 2026-09-16 | 增加原生网页客户端、世界聊天和ZeroTier直接访问说明，移除Godot网页导出运行依赖 |
| v0.3 | 2026-09-16 | 网页端恢复原版主界面、装备槽与装备图标、技能面板和可播放战斗表现 |
