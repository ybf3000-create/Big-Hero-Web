---
tags: [服务端, 部署, SQLite, 网页游戏, 大勇者]
parent: "[[网页网络游戏改造总案【定案】]]"
created: 2026-09-11
version: v0.7
status: Godot网页客户端支持ZeroTier HTTP访问
---

# 大勇者服务端 v0.7

本目录是网页网络版的单体服务。当前代码覆盖邀请码注册、账号密码登录、最多20个账号同时在线、同账号新端踢旧端、30秒断线恢复、每账号1个角色、WebSocket心跳和世界聊天持久化广播。服务端还负责28格地图、装备与技能权威状态、战斗时间线、拍卖行交易和SQLite持久化。

## 1. 运行条件

| 软件 | 要求 | 当前开发机 |
|------|------|-----------|
| Node.js | 22或更高 | 已安装24.13.1 |
| SQLite | 由服务端内置，无需单独安装 | 已完成真实数据库验收 |
| 浏览器 | Chrome或Edge | 访问服务器网页即可 |

SQLite只允许单个游戏服务进程读写。运行库使用WAL、外键、5秒写锁等待和强同步；ZeroTier网络只暴露游戏HTTP端口，不提供数据库访问入口。ZeroTier负责网络连通和加密，浏览器不需要额外证书或命令。

## 2. 首次启动

```powershell
cd D:\onedrive\note\Game\Game-大勇者\SERVER
Copy-Item .env.example .env
npm ci --include=dev --ignore-scripts
npm run migrate
npm run invite:create -- --count=5
```

无需安装数据库服务。迁移脚本会创建`.env`中`DATABASE_PATH`指定的数据库和目录。运行中的SQLite文件不得放在OneDrive等云同步目录；当前本机使用`C:\BigHeroData\big-hero.sqlite`。邀请码只在生成时显示一次，数据库只保存摘要。准备完成后双击 `start-server.bat`，本机访问`http://127.0.0.1:3000/game/`，其他已加入同一 ZeroTier 网络的电脑访问`http://服务器的ZeroTier地址:3000/game/`。若超过20个不同账号同时在线，第21个账号收到“服务器人数已满，请稍后登录”；同账号重新登录则替换旧连接，不额外占用名额。

失败处理：

| 情况 | 处理 |
|------|------|
| 数据库文件无法创建或打开 | 服务不进入可用状态；检查`.env`路径和目录写入权限 |
| 迁移执行失败 | 当前迁移事务回滚；修复原因后重新执行`npm run migrate` |
| 邀请码生成失败 | 不产生半条邀请码；确认迁移完成后重试 |
| 端口占用 | 修改`.env`中的`PORT`，客户端桌面调试地址同步修改 |

## 3. 数据备份

```powershell
npm run backup
```

该命令使用SQLite在线备份接口，把一致性快照写入`BACKUP_DIRECTORY`。服务器运行时不要直接复制`.sqlite`、`.sqlite-wal`和`.sqlite-shm`文件。当前备份目录为`C:\BigHeroBackups`；自动定时备份与恢复演练在N7完成。

## 4. Godot网页客户端

服务器直接发布`SERVER/public/game/`中的Godot 4.4 Web构建。服务器电脑只需Git和Node.js，不需要安装Godot。玩家电脑只需加入同一个ZeroTier网络并使用新版Chrome或Edge，不需要安装证书，也不需要执行额外命令。

本项目导出时必须保持`client/export_presets.cfg`中的`variant/thread_support=false`。无多线程构建不依赖`SharedArrayBuffer`，兼容工具会让普通HTTP跳过Godot模板多余的安全上下文拦截；HTTP环境没有`AudioWorklet`时，音频自动使用Godot自带的`ScriptProcessor`后备。若浏览器两种音频接口都不支持，则游戏仍可显示，但无声音。

Godot重新导出后执行：

```powershell
cd D:\onedrive\note\Game\Game-大勇者\SERVER
npm run web:patch
npm run check
```

兼容工具具备幂等检查：已处理的发布包不会重复修改；若导出模板结构改变、线程被开启或补丁缺失，检查失败并阻止误发布。浏览器客户端使用同源`/api/v1`和`/ws`，因此账号登录和实时连接自动指向玩家当前打开的ZeroTier地址，会话令牌不放进URL。

| 访问情况 | 结果 |
|------|------|
| 已加入同一ZeroTier网络，地址和端口正确 | 加载Godot客户端并连接同源账号服务 |
| 未加入ZeroTier网络或服务器离线 | 浏览器无法连接；不会回退到公网地址 |
| Godot误导出为多线程版本 | `npm run web:check`失败；必须重新导出无多线程版本 |
| 未来改为真正公网开放 | 当前HTTP方案不适用；需配置可信HTTPS证书和WSS |

> 设计柱检验：Godot客户端复用原版地图、装备与战斗表现；同源单端口减少玩家和服主操作；失败状态明确且不静默降级，符合柱2、柱5与柱6。

## 5. 检查

```powershell
npm run check
npm audit --omit=dev
```

检查覆盖账号与角色输入、Q32手续费边界、20/21人容量、同账号替换会话、30秒断线名额、注册登录角色主流程、请求格式、登录审计故障隔离、WebSocket聊天广播，以及SQLite迁移、WAL/外键/强同步、事务幂等和失败回滚。当前共18项自动测试；真实SQLite注册、登录、角色创建和聊天已通过。

> 设计柱检验：服务端权威资产保护柱2与柱6；20人硬上限、单体部署和确定性失败处理控制维护成本，符合柱5。

---

## 附录：变更记录

| 版本 | 日期 | 变更内容 |
|------|------|---------|
| v0.1 | 2026-09-11 | 建立TypeScript/PostgreSQL服务底座、运行步骤、Web导出步骤和首批检查口径 |
| v0.2 | 2026-09-11 | Web模板安装并导出成功；浏览器验证中文字体、登录页和邀请码注册页正常 |
| v0.3 | 2026-09-11 | 登录审计失败不再改变玩家应收到的登录结果；自动测试增至12项并重新导出Web包 |
| v0.4 | 2026-09-14 | PostgreSQL改为SQLite；完成真实迁移与注册登录角色验收，增加在线备份命令，自动测试增至16项 |
| v0.5 | 2026-09-16 | 切换原生网页入口；接入世界聊天持久化、历史推送、广播、防刷与禁言检查；增加网页联调测试 |
| v0.6 | 2026-09-16 | 恢复原版主界面结构、装备图标与八部位穿戴界面；服务端输出可播放战斗时间线，网页端加入战斗舞台、血条、飘字、日志和结算 |
| v0.7 | 2026-09-16 | 恢复Godot网页发布包；验证ZeroTier普通HTTP登录、WebSocket在线和大地图；加入安全上下文与音频后备兼容检查 |
