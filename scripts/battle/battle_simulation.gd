class_name BattleSimulation
extends RefCounted

## 纯规则层：不含 Node、输入、音频、动画或任何 Godot 场景对象。
## 输入只能是 submit() 的命令，输出只能是事件数组，状态全部可读、可快照。

enum BattleState { WINDUP, RESOLVING, VICTORY, DEFEAT }
enum DefenseGrade { NONE, SUCCESS, PERFECT }

const PERFECT_WINDOW := 0.09
const SUCCESS_GRACE := 0.05
const MISS_COOLDOWN := 0.75
const MAX_POINTS := 9
const STAGGER_CAP := 0.6
const ATTACK_RECOVERY := 0.62
const PARRY_STAGGER := 0.8
const HAND_SIZE := 4
const STARTING_DECK := ["attack", "attack", "shatter", "guard", "shift"]
const SUMMON_COST := 2
const PLAYER_MAX_HP := 72

const CARD_DATA := {
	"attack": {"title": "斩纸", "class": "斩", "cost": 1, "damage": 5, "color": Color("d3a44b"), "key": "1"},
	"shatter": {"title": "还刃", "class": "斩", "cost": 3, "damage": 12, "bonus": 6, "color": Color("bd3d45"), "key": "2"},
	"guard": {"title": "镇煞", "class": "御", "cost": 2, "damage": 6, "stagger": 0.35, "color": Color("43a9b2"), "key": "3"},
	"shift": {"title": "续灯", "class": "佑", "cost": 2, "heal": 7, "color": Color("6d9663"), "key": "4"},
	"duannian": {"title": "断念", "class": "斩", "cost": 2, "damage": 8, "discard_random": true, "color": Color("c98862"), "key": ""},
	"dengxin": {"title": "灯芯", "class": "佑", "cost": 1, "heal": 4, "color": Color("8fae72"), "key": ""},
	"zhuangzhong": {"title": "撞钟", "class": "斩", "cost": 2, "damage": 5, "stagger": 0.2, "color": Color("b0925c"), "key": ""},
}

## 敌招阶段表：每招一段可学习的时间线。unblockable 招不可防范。
const MOVES := {
	"red": {
		"id": "red", "title": "蓄势慢刀", "duration": 2.8, "damage": 16,
		"window": 0.30, "fake": 1.25, "color": Color("bd3d45"),
		"phases": [
			{"name": "raise", "until": 1.00},
			{"name": "hold", "until": 1.90, "cue": true},
			{"name": "commit", "until": 2.80, "cue": true},
			{"name": "recover", "until": 3.42},
		],
	},
	"blue": {
		"id": "blue", "title": "变拍二连", "duration": 2.05, "damage": 7,
		"window": 0.20, "strikes": [0.82, 1.56], "color": Color("43a9b2"),
		"phases": [
			{"name": "raise", "until": 0.69},
			{"name": "commit", "until": 0.82, "cue": true},
			{"name": "reset", "until": 1.43},
			{"name": "commit", "until": 1.56, "cue": true},
			{"name": "recover", "until": 2.26},
		],
	},
	"green": {
		"id": "green", "title": "佯攻擒拿", "duration": 1.9, "damage": 14,
		"window": 0.34, "fake": 0.78, "unblockable": true, "color": Color("6d9663"),
		"phases": [
			{"name": "feint", "until": 0.79},
			{"name": "reveal", "until": 1.14, "cue": true},
			{"name": "reach", "until": 1.90},
			{"name": "recover", "until": 2.52},
		],
	},
	"quick": {
		"id": "quick", "title": "疾斩", "duration": 1.0, "damage": 9,
		"window": 0.22, "strikes": [0.90], "color": Color("d0a45c"),
		"phases": [
			{"name": "raise", "until": 0.55},
			{"name": "commit", "until": 0.90, "cue": true},
			{"name": "recover", "until": 1.32},
		],
	},
}

## 敌人表：名称、血量、招式轮换（永不 RNG 抖动）。
const ENEMIES := {
	"watchman": {"name": "前任更夫", "hp": 46, "moves": ["red", "blue", "green"], "opening": "red"},
	"lantern_imp": {"name": "灯笼小鬼", "hp": 30, "moves": ["quick", "red"], "opening": "quick", "reactive": true},
	"patrol_corpse": {"name": "更练尸", "hp": 38, "moves": ["blue", "red"], "opening": "blue", "reactive": true},
	"barber_ghost": {"name": "剃头匠", "hp": 34, "moves": ["blue", "quick"], "opening": "blue", "reactive": true},
	"paper_apprentice": {"name": "纸扎学徒", "hp": 30, "moves": ["red", "green"], "opening": "red", "reactive": true},
	"well_sisters": {"name": "井中姐弟", "hp": 36, "moves": ["blue", "green"], "opening": "blue", "reactive": true},
	"gambler_ghost": {"name": "赌鬼", "hp": 34, "moves": ["quick", "blue", "red"], "opening": "quick", "reactive": true},
	"mortuary_warden": {"name": "义庄看守", "hp": 36, "moves": ["red", "blue", "green", "quick"], "opening": "red", "reactive": true},
	"lantern_keeper": {"name": "守灯人", "hp": 40, "moves": ["red", "quick", "blue", "green"], "opening": "red", "reactive": true},
}

var state: BattleState = BattleState.WINDUP
var player_hp := PLAYER_MAX_HP
var enemy_hp := 46
var points := 0
var attack_index := 0
var attack_elapsed := 0.0
var fake_released := false
var strike_index := 0
var window_announced := false
var blue_cue_index := -1
var queued_defense := DefenseGrade.NONE
var defense_cooldown := 0.0
var stagger_remaining := 0.0
var perfect_charge := false
var perfects := 0
var recovery_remaining := 0.0
var battle_generation := 0
var hand: Array[String] = []
var draw_pile: Array[String] = []
var discard_pile: Array[String] = []
var rng_state := 0
var battle_seed := 0
var deck_config: Array[String] = []
var enemy_id := "watchman"
var enemy_name := "前任更夫"
var enemy_max_hp := 46
var last_move_id := ""
var was_last_perfect := false
var current_intent: Dictionary = {}


func _init() -> void:
	restart()


func restart() -> void:
	battle_generation += 1
	player_hp = PLAYER_MAX_HP
	enemy_hp = int(ENEMIES[enemy_id].hp)
	points = 0
	attack_index = 0
	defense_cooldown = 0.0
	stagger_remaining = 0.0
	perfect_charge = false
	perfects = 0
	last_move_id = ""
	was_last_perfect = false
	queued_defense = DefenseGrade.NONE
	recovery_remaining = 0.0
	battle_seed = 20260828 + battle_generation
	rng_state = battle_seed
	_setup_deck()
	_begin_attack()


func _next_rand() -> float:
	rng_state = (rng_state + 0x6D2B79F5) & 0xFFFFFFFF
	var t := rng_state
	t = ((t ^ (t >> 15)) * (t | 1)) & 0xFFFFFFFF
	t = (t ^ (t + ((t ^ (t >> 7)) * (t | 61)))) & 0xFFFFFFFF
	return float((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296.0


func _shuffle(pile: Array[String]) -> void:
	for i in range(pile.size() - 1, 0, -1):
		var j := int(_next_rand() * float(i + 1))
		var tmp := pile[i]
		pile[i] = pile[j]
		pile[j] = tmp


func _setup_deck() -> void:
	hand.clear()
	var source: Array = deck_config if not deck_config.is_empty() else STARTING_DECK
	draw_pile = Array(source.duplicate(), TYPE_STRING, "", null)
	discard_pile.clear()
	_shuffle(draw_pile)
	_draw_to_hand()


func _draw_to_hand() -> bool:
	var changed := false
	while hand.size() < HAND_SIZE:
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				break
			draw_pile = Array(discard_pile.duplicate(), TYPE_STRING, "", null)
			discard_pile.clear()
			_shuffle(draw_pile)
		hand.append(draw_pile.pop_back())
		changed = true
	return changed


## 命令入口：{type:"defend"} 或 {type:"play_card", id:"attack"}。
## 返回本命令立刻产生的事件；延迟事件随 step() 返回。
func submit(command: Dictionary) -> Array:
	match String(command.get("type", "")):
		"defend":
			return _attempt_defense()
		"play_card":
			return _play_card(String(command.get("id", "")))
		"summon":
			return _summon_card()
	return []


func _summon_card() -> Array:
	var events: Array = []
	if state == BattleState.VICTORY or state == BattleState.DEFEAT:
		events.append({"type": "summon_rejected", "reason": "ended"})
		return events
	if hand.size() >= HAND_SIZE:
		events.append({"type": "summon_rejected", "reason": "hand_full"})
		return events
	if points < SUMMON_COST:
		events.append({"type": "summon_rejected", "reason": "points"})
		return events
	var pool: Array[String] = []
	pool.append_array(draw_pile)
	pool.append_array(discard_pile)
	if pool.is_empty():
		events.append({"type": "summon_rejected", "reason": "empty"})
		return events
	points -= SUMMON_COST
	var idx := int(_next_rand() * float(pool.size()))
	var id: String = pool[idx]
	if idx < draw_pile.size():
		draw_pile.erase(id)
	else:
		discard_pile.erase(id)
	hand.append(id)
	events.append({"type": "card_summoned", "id": id, "cost": SUMMON_COST})
	return events


## 推进一个渲染帧。返回这一帧发生的事件。
func step(delta: float) -> Array:
	var events: Array = []
	if defense_cooldown > 0.0:
		defense_cooldown = maxf(0.0, defense_cooldown - delta)
		if defense_cooldown == 0.0:
			events.append({"type": "cooldown_expired"})
	match state:
		BattleState.WINDUP:
			_step_windup(delta, events)
		BattleState.RESOLVING:
			recovery_remaining -= delta
			if recovery_remaining <= 0.0:
				attack_index += 1
				_begin_attack()
				events.append({"type": "attack_started", "intent": current_intent.id})
	return events


func _step_windup(delta: float, events: Array) -> void:
	if stagger_remaining > 0.0:
		stagger_remaining = maxf(0.0, stagger_remaining - delta)
		return
	attack_elapsed += delta
	_collect_cue_events(events)
	_collect_fake_events(events)
	var strikes: Array = current_intent.get("strikes", [])
	while state == BattleState.WINDUP and strike_index < strikes.size() and attack_elapsed >= float(strikes[strike_index]):
		_resolve_impact(events)
		strike_index += 1
	if state == BattleState.WINDUP and not strikes.is_empty() and strike_index >= strikes.size():
		_finish_action(events)
	if state == BattleState.WINDUP and strikes.is_empty() and attack_elapsed >= float(current_intent.duration):
		_resolve_impact(events)
		if state == BattleState.WINDUP:
			_finish_action(events)


func _collect_cue_events(events: Array) -> void:
	if current_intent.id == "blue":
		var strikes: Array = current_intent.strikes
		if strike_index < strikes.size() and attack_elapsed >= float(strikes[strike_index]) - 0.13 and blue_cue_index != strike_index:
			blue_cue_index = strike_index
			events.append({"type": "commit_cue", "intent": current_intent.id})
		return
	if not window_announced and attack_elapsed >= float(current_intent.duration) - float(current_intent.window):
		window_announced = true
		events.append({"type": "commit_cue", "intent": current_intent.id})


func _collect_fake_events(events: Array) -> void:
	var fake_time: float = current_intent.get("fake", -1.0)
	if fake_time >= 0.0 and not fake_released and attack_elapsed >= fake_time:
		fake_released = true
		events.append({"type": "fake_release", "intent": current_intent.id})


func _attempt_defense() -> Array:
	var events: Array = []
	if state != BattleState.WINDUP or queued_defense != DefenseGrade.NONE:
		return events
	if defense_cooldown > 0.0:
		events.append({"type": "defense_blocked"})
		return events
	if bool(current_intent.get("unblockable", false)):
		defense_cooldown = MISS_COOLDOWN
		events.append({"type": "defense_miss", "unblockable": true})
		return events
	var time_to_impact := _current_impact_time() - attack_elapsed
	var success_window: float = current_intent.window
	if time_to_impact >= 0.0 and time_to_impact <= success_window:
		queued_defense = DefenseGrade.PERFECT if time_to_impact <= PERFECT_WINDOW else DefenseGrade.SUCCESS
	elif time_to_impact < 0.0 and time_to_impact >= -SUCCESS_GRACE:
		queued_defense = DefenseGrade.SUCCESS
	else:
		defense_cooldown = MISS_COOLDOWN
		events.append({"type": "defense_miss"})
		return events
	events.append({"type": "defense_queued", "grade": queued_defense})
	return events


func _pick_reactive(enemy: Dictionary) -> String:
	var pool: Array = enemy.moves
	if pool.size() == 1:
		return String(pool[0])
	var weights: Array[float] = []
	var total := 0.0
	for mid in pool:
		var w := _move_weight(String(mid))
		weights.append(w)
		total += w
	var roll := _next_rand() * total
	for i in pool.size():
		roll -= weights[i]
		if roll <= 0.0:
			return String(pool[i])
	return String(pool[pool.size() - 1])


func _move_weight(mid: String) -> float:
	var move: Dictionary = MOVES[mid]
	var w := 1.0
	if String(mid) == last_move_id:
		w = 0.0
	if bool(move.get("unblockable", false)) and points >= 7:
		w += 0.9
	if int(move.damage) >= 12 and player_hp <= 24:
		w += 0.6
	if float(move.window) <= 0.22 and was_last_perfect:
		w += 0.5
	if enemy_hp < int(ENEMIES[enemy_id].hp) / 2 and int(move.damage) >= 12:
		w += 0.4
	return w


func _current_impact_time() -> float:
	if current_intent.id == "blue":
		var strikes: Array = current_intent.strikes
		if strike_index < strikes.size():
			return float(strikes[strike_index])
	return float(current_intent.duration)


func _resolve_impact(events: Array) -> void:
	var grade: int = queued_defense
	queued_defense = DefenseGrade.NONE
	was_last_perfect = grade == DefenseGrade.PERFECT
	match grade:
		DefenseGrade.SUCCESS:
			points = mini(MAX_POINTS, points + 1)
			perfect_charge = false
			events.append({"type": "impact", "grade": grade, "points": 1})
			events.append({"type": "points_changed"})
		DefenseGrade.PERFECT:
			points = mini(MAX_POINTS, points + 2)
			perfect_charge = true
			perfects += 1
			events.append({"type": "impact", "grade": grade, "points": 2})
			events.append({"type": "points_changed"})
			if current_intent.id == "blue" and strike_index < int(current_intent.strikes.size()) - 1:
				stagger_remaining = minf(STAGGER_CAP, stagger_remaining + PARRY_STAGGER)
			events.append({"type": "enemy_staggered"})
		_:
			perfect_charge = false
			var damage := int(current_intent.damage)
			player_hp = maxi(0, player_hp - damage)
			events.append({"type": "impact", "grade": grade, "damage": damage})
			if player_hp <= 0:
				_end_battle(events)


func _play_card(id: String) -> Array:
	var events: Array = []
	var data: Dictionary = CARD_DATA.get(id, {})
	if data.is_empty():
		return events
	if state == BattleState.VICTORY or state == BattleState.DEFEAT:
		events.append({"type": "card_rejected", "id": id, "reason": "ended"})
		return events
	if not hand.has(id):
		events.append({"type": "card_rejected", "id": id, "reason": "not_in_hand"})
		return events
	var cost := int(data.cost)
	if points < cost:
		events.append({"type": "card_rejected", "id": id, "reason": "points"})
		return events
	points -= cost
	match id:
		"attack":
			enemy_hp -= int(data.damage)
			events.append({"type": "card_played", "id": id, "damage": int(data.damage)})
		"shatter":
			var in_stagger_window := state == BattleState.RESOLVING or stagger_remaining > 0.0
			var charged := perfect_charge and in_stagger_window
			var total := int(data.damage) + (int(data.bonus) if charged else 0)
			perfect_charge = false
			enemy_hp -= total
			events.append({"type": "card_played", "id": id, "damage": total, "charged": charged})
		"guard":
			enemy_hp -= int(data.damage)
			if state == BattleState.WINDUP and bool(current_intent.get("unblockable", false)) and fake_released:
				_finish_action(events)
				events.append({"type": "grab_cancelled"})
			elif state == BattleState.WINDUP:
				stagger_remaining = minf(STAGGER_CAP, stagger_remaining + float(data.stagger))
				events.append({"type": "stagger", "duration": float(data.stagger)})
			events.append({"type": "card_played", "id": id, "damage": int(data.damage)})
		"duannian":
			enemy_hp -= int(data.damage)
			var others: Array[String] = hand.filter(func(cid: String): return cid != id)
			if not others.is_empty():
				var victim: String = others[int(_next_rand() * float(others.size()))]
				hand.erase(victim)
				discard_pile.append(victim)
				events.append({"type": "hand_changed"})
			events.append({"type": "card_played", "id": id, "damage": int(data.damage), "discarded": true})
		"zhuangzhong":
			enemy_hp -= int(data.damage)
			if state == BattleState.WINDUP:
				stagger_remaining = minf(STAGGER_CAP, stagger_remaining + float(data.stagger))
				events.append({"type": "stagger", "duration": float(data.stagger)})
			events.append({"type": "card_played", "id": id, "damage": int(data.damage)})
		"shift":
			var healed := mini(int(data.heal), PLAYER_MAX_HP - player_hp)
			player_hp += healed
			events.append({"type": "card_played", "id": id, "healed": healed})
	hand.erase(id)
	discard_pile.append(id)
	if enemy_hp <= 0:
		_end_battle(events)
	return events


func _finish_action(events: Array) -> void:
	state = BattleState.RESOLVING
	recovery_remaining = ATTACK_RECOVERY + (PARRY_STAGGER if perfect_charge else 0.0)
	events.append({"type": "action_finished"})


func _end_battle(events: Array) -> void:
	if enemy_hp <= 0:
		state = BattleState.VICTORY
		events.append({"type": "victory"})
	else:
		state = BattleState.DEFEAT
		events.append({"type": "defeat"})


func _begin_attack() -> void:
	state = BattleState.WINDUP
	attack_elapsed = 0.0
	fake_released = false
	strike_index = 0
	window_announced = false
	blue_cue_index = -1
	queued_defense = DefenseGrade.NONE
	stagger_remaining = 0.0
	perfect_charge = false
	var enemy: Dictionary = ENEMIES[enemy_id]
	var move_id: String
	if attack_index == 0 or not bool(enemy.get("reactive", false)):
		move_id = String(enemy.moves[attack_index % enemy.moves.size()])
	else:
		move_id = _pick_reactive(enemy)
	last_move_id = move_id
	current_intent = MOVES[move_id].duplicate()
	enemy_name = String(enemy.name)
	enemy_max_hp = int(enemy.hp)
