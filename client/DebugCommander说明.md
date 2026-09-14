# DebugCommander — Godot 调试命令系统

## 原理

```
AI (WorkBuddy) → godot-mcp debug_cmd → user://debug_cmd.txt → Godot DebugCommander autoload → 模拟 UI 操作
```

无需窗口坐标，通过文本命令精确操控游戏 UI。

## 依赖

- [godot-mcp](https://github.com/bradypp/godot-mcp) (MCP 服务器)
- `scripts/debug_commander.gd` (Godot Autoload)
- `project.godot` 中注册 `DebugCommander="*res://scripts/debug_commander.gd"`

## 可用命令

| 命令 | 参数 | 说明 |
|------|------|------|
| `click_slot` | `slot: 0/1/2` | 点击存档槽 |
| `create_char` | `slot: 0/1/2` | 打开创建角色弹窗 |
| `input_name` | `text: "勇者"` | 输入角色名称 |
| `confirm_create` | — | 点击"开始冒险" |
| `cancel_create` | — | 关闭创建弹窗 |
| `click_delete` | `slot: 0/1/2` | 打开删除确认框 |
| `hold_confirm` | `seconds: 3` | 长按确定按钮 N 秒 |
| `click_cancel` | — | 点击取消按钮 |
| `click_overlay` | — | 点击遮罩关闭 |
| `click_dice` | — | 掷骰 |
| `click_bag` | — | 背包 |
| `click_skill` | — | 技能 |
| `click_log` | — | 日志 |
| `click_home` | — | 返回主界面 |
| `toggle_auto` | — | 切换自动挂机 |

## 使用示例

```json
// 创建角色并进入游戏
{ "action": "click_slot", "slot": 0 }
{ "action": "input_name", "text": "勇者王" }
{ "action": "confirm_create" }

// 主界面操作
{ "action": "click_dice" }
{ "action": "toggle_auto" }

// 删除存档
{ "action": "click_delete", "slot": 0 }
{ "action": "hold_confirm", "seconds": 3 }
```

## 完整自动化测试流程

```bash
# 1. 启动项目
run_project

# 2. 点击空槽位打开创建弹窗
debug_cmd { action: "click_slot", slot: 0 }

# 3. 输入名称
debug_cmd { action: "input_name", text: "测试" }

# 4. 确认创建
debug_cmd { action: "confirm_create" }

# 5. 进入主界面后掷骰
debug_cmd { action: "click_dice" }

# 6. 返回主界面
debug_cmd { action: "click_home" }

# 7. 删除存档测试
debug_cmd { action: "click_delete", slot: 0 }
debug_cmd { action: "hold_confirm", seconds: 3 }

# 8. 检查日志
get_debug_output
```
