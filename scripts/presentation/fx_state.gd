extends RefCounted

## 表现层共享状态：各动画子模块读写、stage 每帧消费。

var trauma := 0.0
var shake_enabled := true
var glow_boost := 0.0
var impulse_x := 0.0
var impulse_rot := 0.0
var enemy_push := 0.0


func reset() -> void:
	trauma = 0.0
	glow_boost = 0.0
	impulse_x = 0.0
	impulse_rot = 0.0
	enemy_push = 0.0
