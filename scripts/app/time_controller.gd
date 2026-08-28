extends Node

## TimeController（autoload "Time"）：统一管理 Engine.time_scale。
## 之前 hit-stop、慢动作、测试加速、卡牌悬停减速各自直接改 time_scale 互相打架，
## 现在全部经过这里：claim(用途, 倍率) / release(用途)，
## 生效倍率 = 各活跃 claim 的最小值，全部释放后回到基准倍率。

var base_scale := 1.0
var _claims: Dictionary = {}

var scale: float:
	get:
		var s := base_scale
		for v: float in _claims.values():
			s = minf(s, v)
		return s


func _process(_delta: float) -> void:
	Engine.time_scale = scale


func claim(purpose: String, value: float) -> void:
	_claims[purpose] = value


func release(purpose: String) -> void:
	_claims.erase(purpose)


func hitstop(duration: float, value := 0.05) -> void:
	## 短促顿帧：由 tween 在 ignore_time_scale 时间轴上恢复。
	claim("hitstop", value)
	var timer := get_tree().create_timer(duration, true, false, true)
	timer.timeout.connect(func(): release("hitstop"))


func slowmo(scale_value: float, duration: float) -> void:
	claim("slowmo", scale_value)
	var timer := get_tree().create_timer(duration, true, false, true)
	timer.timeout.connect(func(): release("slowmo"))


func set_playtest_speed(value: float) -> void:
	if value <= 1.0:
		base_scale = 1.0
	else:
		base_scale = value


func reset() -> void:
	_claims.clear()
	base_scale = 1.0
