---
version: v0.4
status: Godot网页客户端支持ZeroTier HTTP访问
---

# Big Hero Web

《大勇者》网页网络版单体仓库，面向最多20名玩家同时在线的个人服务器。玩家只需安装并加入同一个 ZeroTier 网络，然后在浏览器打开服务器地址即可进入 Godot 网页客户端。

## 目录

| 目录 | 内容 |
|------|------|
| `client/` | Godot 4.4客户端源码、完整游戏内容和Web导出兼容工具 |
| `web-client/` | 已停用的原生网页原型，仅保留作历史对照，不参与服务器启动 |
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

玩家页面由 Godot 4.4 无多线程Web导出生成，发布文件位于 `SERVER/public/game/`。Godot重新导出后，在 `SERVER` 目录执行 `npm run web:patch`，再执行 `npm run check`；兼容工具会保留HTTPS能力，同时允许无多线程版本通过 ZeroTier 私网HTTP启动。详细部署、测试和备份说明见[`SERVER/README.md`](SERVER/README.md)。

当前网页恢复 Godot 原版登录界面、9格透视地图、逐格移动、背包、装备、技能与战斗表现。账号、单角色创建、20人在线上限和WebSocket会话由服务端提供；世界聊天、拍卖行以及全部玩法资产的服务端权威化仍按策划案继续开发。

## 安全边界

`.env`、SQLite运行库、备份、`node_modules`和Godot导入缓存均不进入Git；`SERVER/public/game/`中的Godot发布文件会进入Git，确保服务器电脑克隆后无需安装Godot即可启动。ZeroTier传输层本身提供端到端加密；当前无多线程Godot导出可使用HTTP和`ws://`。若日后改为真正公网部署，必须增加HTTPS/WSS反向代理。

> 设计柱检验：直接复用已验证的Godot客户端保护原版表现与规则一致性；单端口同源部署和自动兼容检查控制20人个人服务器的维护成本，符合柱2、柱5与柱6。

## 许可证

项目代码采用[MIT License](LICENSE)。字体和其他第三方资源继续遵循其各自许可证；`client/assets/fonts/NotoSansHans-LICENSE.txt`适用于仓库中的Noto Sans Hans字体。

---

## 附录：变更记录

| 版本 | 日期 | 变更内容 |
|------|------|---------|
| v0.1 | 2026-09-14 | 建立客户端与服务端单仓库说明、运行入口及许可证边界 |
| v0.2 | 2026-09-16 | 增加原生网页客户端、世界聊天和ZeroTier直接访问说明，移除Godot网页导出运行依赖 |
| v0.3 | 2026-09-16 | 网页端恢复原版主界面、装备槽与装备图标、技能面板和可播放战斗表现 |
| v0.4 | 2026-09-16 | 恢复Godot网页发布包；加入无多线程HTTP与音频后备兼容检查；停用启动时覆盖Godot包的原生网页构建 |
