class_name EnemyTimeline
extends RefCounted

## 敌人时间轴的标准操作接口。
## 蓝牌（御）只能通过这里改写敌人时间轴：interrupt / delay / remove_next_hit /
## extend_recovery / suppress_fake / make_blockable / stagger / weaken / widen_window。
## 不允许卡牌直接改 current_intent——敌人一多不会失控，Boss 免疫也只写在一处。

var sim  # BattleSimulation（规则层内部引用，两者同为纯规则对象；
         # 不 preload battle_simulation，避免循环依赖；常量经实例访问）


func _init(owner) -> void:
	sim = owner


func _in_windup() -> bool:
	return sim.state == sim.BattleState.WINDUP


## 打断当前敌招（守灯人免疫）。返回是否生效。
func interrupt() -> bool:
	if not _in_windup() or sim.enemy_id == "lantern_keeper":
		return false
	sim._finish_action([])
	sim.stats.interrupts = int(sim.stats.get("interrupts", 0)) + 1
	return true


## 敌招整体延后 t 秒（多段命中点与收招一起后移）。
func delay(t: float) -> void:
	if not _in_windup() or t <= 0.0:
		return
	var intent: Dictionary = sim.current_intent
	if intent.has("strikes"):
		var arr: Array = []
		for s in intent.strikes:
			arr.append(float(s) + t)
		intent.strikes = arr
	intent.duration = float(intent.duration) + t


## 抹去敌人下一段命中。
func remove_next_hit() -> bool:
	var strikes: Array = sim.current_intent.get("strikes", [])
	if not _in_windup() or sim.strike_index >= strikes.size():
		return false
	sim._skip_next_strike = true
	return true


## 敌招收招拖长（破绽窗口）。
func extend_recovery(t: float) -> void:
	if t <= 0.0:
		return
	sim.current_intent.duration = float(sim.current_intent.duration) + t


## 佯攻失效：假释放提前作废。
func suppress_fake() -> void:
	if not _in_windup():
		return
	sim.current_intent.fake = -1.0
	sim.fake_released = true


## 鬼手化为可防范（安魂）。
func make_blockable() -> bool:
	if not _in_windup() or not bool(sim.current_intent.get("unblockable", false)):
		return false
	sim.current_intent.unblockable = false
	return true


## 凝滞（镇煞/低幡/缚魂索/撞钟）。
func stagger(seconds: float) -> void:
	if not _in_windup() or seconds <= 0.0:
		return
	var amount := seconds * float(sim.run_mods.get("stagger_mul", 1.0))
	sim.stagger_remaining = minf(sim.STAGGER_CAP, sim.stagger_remaining + amount)


## 削弱本招伤害（破胆）。
func weaken(mul: float) -> void:
	sim.podan_mul = mul


## 放宽本招窗口（晃灯/查更）。
func widen_window(amount: float) -> void:
	if amount <= 0.0:
		return
	sim.current_intent.window = float(sim.current_intent.window) + amount


## 斩断鬼手（镇煞对已显形鬼手的特判：算打断成功并奖励还愿）。
func cancel_grab() -> bool:
	if not _in_windup() or not bool(sim.current_intent.get("unblockable", false)) or not sim.fake_released:
		return false
	sim._finish_action([])
	sim.points = mini(sim._max_points(), sim.points + 1)
	return true
