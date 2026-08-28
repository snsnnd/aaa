class_name MotionChannel
extends RefCounted

## 运动通道：同一目标的动作 Tween 独占——新动作接管时 kill 旧 Tween，
## 消除连招加速后多 Tween 竞争同一属性造成的抖动/瞬移。
## 通道按语义划分（player_pivot / enemy_pos / enemy_flash / enemy_weapon / player_flash），
## 不同通道的 Tween 天然并行、互不冲突（godot-tween-animation skill: lifecycle/kill-replace 模式）。

var host: Node  # 用于 create_tween（绑定宿主生命周期）

var _tweens: Dictionary = {}  # 通道名 -> Tween


func setup(host_node: Node) -> void:
	host = host_node


## 在指定通道上播放 Tween。builder(host) -> Tween 由调用方组装（便于传 easing 链）。
func play(channel: String, builder: Callable) -> Tween:
	var old: Tween = _tweens.get(channel)
	if old and old.is_valid():
		old.kill()
	var tw: Tween = builder.call(host)
	_tweens[channel] = tw
	return tw


func stop(channel: String) -> void:
	var old: Tween = _tweens.get(channel)
	if old and old.is_valid():
		old.kill()
	_tweens.erase(channel)


func stop_all() -> void:
	for key in _tweens.keys():
		stop(String(key))
