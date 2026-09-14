class_name DiceRoller
extends RefCounted
## ============================================================
## DiceRoller - 骰子系统 v0.1
## 管理掷骰逻辑、动画帧、冷却机制
## ============================================================

## 骰子面数配置
var dice_min: int = 1
var dice_max: int = 6

## 上次掷骰结果
var last_result: int = 0

## 掷骰冷却（秒），0 表示无冷却
var cooldown: float = 0.0
var _cooldown_remaining: float = 0.0

## 掷骰次数统计
var total_rolls: int = 0
var roll_history: Array[int] = []

## 骰子动画中间帧（模拟滚动效果）
const FRAME_COUNT: int = 10
const FRAME_INTERVAL: float = 0.08


## 掷骰，返回 1~dice_max
func roll() -> int:
	var result: int = randi_range(dice_min, dice_max)
	last_result = result
	total_rolls += 1
	roll_history.append(result)
	return result


## 获取滚动动画的中间帧序列（用于 UI 动画）
func get_animation_frames() -> Array[int]:
	var frames: Array[int] = []
	for _i in range(FRAME_COUNT):
		frames.append(randi_range(dice_min, dice_max))
	frames.append(last_result)
	return frames


## 检查是否在冷却中
func is_on_cooldown() -> bool:
	return _cooldown_remaining > 0.0


## 更新冷却计时（由外部 delta 驱动）
func update_cooldown(delta: float) -> void:
	if _cooldown_remaining > 0.0:
		_cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)
