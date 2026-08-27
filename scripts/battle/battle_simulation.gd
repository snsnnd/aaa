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
	"attack": {"title": "斩纸", "class": "斩", "cost": 1, "damage": 4, "color": Color("d3a44b"), "key": "1"},
	"shatter": {"title": "还刃", "class": "斩", "cost": 3, "damage": 12, "bonus": 6, "color": Color("bd3d45"), "key": "2"},
	"guard": {"title": "镇煞", "class": "御", "cost": 2, "damage": 6, "stagger": 0.35, "color": Color("43a9b2"), "key": "3"},
	"shift": {"title": "续灯", "class": "佑", "cost": 2, "heal": 7, "color": Color("6d9663"), "key": "4"},
}

const INTENTS := [
	{
		"id": "red", "title": "赤·嗔  蓄势慢刀",
		"duration": 2.8, "damage": 16, "window": 0.30, "fake_time": 1.25,
		"color": Color("bd3d45"),
	},
	{
		"id": "blue", "title": "碧·痴  变拍二连",
		"duration": 2.05, "damage": 7, "window": 0.20,
		"strikes": [0.82, 1.56], "color": Color("43a9b2"),
	},
	{
		"id": "green", "title": "青·疑  佯攻擒拿",
		"duration": 1.9, "damage": 18, "window": 0.34, "fake_time": 0.78,
		"color": Color("6d9663"),
	},
]

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
var current_intent: Dictionary = INTENTS[0]


func _init() -> void:
	restart()


func restart() -> void:
	battle_generation += 1
	player_hp = PLAYER_MAX_HP
	enemy_hp = 46
	points = 0
	attack_index = 0
	defense_cooldown = 0.0
	stagger_remaining = 0.0
	perfect_charge = false
	perfects = 0
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
	draw_pile = Array(STARTING_DECK.duplicate(), TYPE_STRING, "", null)
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
	var fake_time: float = current_intent.get("fake_time", -1.0)
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
	if current_intent.id == "green":
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


func _current_impact_time() -> float:
	if current_intent.id == "blue":
		var strikes: Array = current_intent.strikes
		if strike_index < strikes.size():
			return float(strikes[strike_index])
	return float(current_intent.duration)


func _resolve_impact(events: Array) -> void:
	var grade: int = queued_defense
	queued_defense = DefenseGrade.NONE
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
			if state == BattleState.WINDUP and current_intent.id == "green" and fake_released:
				_finish_action(events)
				events.append({"type": "grab_cancelled"})
			elif state == BattleState.WINDUP:
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
	current_intent = INTENTS[attack_index % INTENTS.size()]
