class_name ActionState
extends RefCounted

## 玩家当前动作状态：连招、连势、姿态的唯一事实源。
## 防反成功直接写入 parry_exit 姿态并打开连招窗口——防反天然成为连招起手。

var current_pose := "neutral"
var current_action := ""
var combo_level := 0
var combo_timer := 0.0
var momentum := 0            # 连势 0-5：顺畅衔接上升；受伤/失误清空；停顿衰减
var can_cancel := false
var active_tags: Array[String] = []


func reset() -> void:
	current_pose = "neutral"
	current_action = ""
	combo_level = 0
	combo_timer = 0.0
	momentum = 0
	can_cancel = false
	active_tags.clear()


func is_chain_open() -> bool:
	return combo_timer > 0.0 and combo_level > 0


## 防反成功：连招起手。perfect 提供更强起势与连势。
func on_defense(grade: int, window: float) -> Dictionary:
	current_pose = "parry_exit"
	current_action = ""
	combo_timer = window
	can_cancel = true
	if grade == 2:  # PERFECT
		combo_level = mini(5, combo_level + 2)
		momentum = mini(5, momentum + 1)
		return {"combo_level": combo_level, "momentum": momentum, "perfect": true}
	combo_level = mini(5, combo_level + 1)
	return {"combo_level": combo_level, "momentum": momentum, "perfect": false}


## 连招窗口关闭：连势软衰减（停顿过久）。
func tick(delta: float) -> bool:
	if combo_timer > 0.0:
		combo_timer = maxf(0.0, combo_timer - delta)
		if combo_timer == 0.0:
			can_cancel = false
			if combo_level > 0:
				combo_level = 0
			momentum = maxi(0, momentum - 1)
			current_pose = "neutral"
			return true  # 发生重置
	return false


## 受击：连势清空（设计第 8 点）。
func on_player_hit() -> void:
	reset()


## 防反失败：连势清空。
func on_defense_miss() -> void:
	momentum = 0
	combo_level = 0
	combo_timer = 0.0
	current_pose = "neutral"
	can_cancel = false
