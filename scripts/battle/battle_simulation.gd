class_name BattleSimulation
extends RefCounted

const ContentCatalog := preload("res://scripts/battle/content_catalog.gd")

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

const CARD_DATA := ContentCatalog.CARD_DATA

const MOVES := ContentCatalog.MOVES

const ENEMIES := ContentCatalog.ENEMIES

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
var second_last_move_id := ""
var was_last_perfect := false
var rage := 0
var rage_half_applied := false
var moves_completed := 0
var force_perfect_next := false
var mirror_charges := 0
var podan_mul := 1.0
var golden_body := 0
var stats := {}
var defense_log: Array[Dictionary] = []
var current_intent: Dictionary = {}


func content_hash() -> int:
	## 玩法内容指纹：仅含规则字段；表现改动不影响此值。
	var parts: Array[String] = []
	parts.append("pw=%d/gr=%d/mc=%d/sc=%d" % [PERFECT_WINDOW, SUCCESS_GRACE, MAX_POINTS, SUMMON_COST])
	parts.append("hp=%d/deck=%s" % [PLAYER_MAX_HP, ",".join(STARTING_DECK)])
	for id in CARD_DATA:
		var c: Dictionary = CARD_DATA[id]
		parts.append("c:%s=%d/%s/%s" % [id, int(c.cost), String(c["class"]), str(c.get("damage", c.get("heal", 0)))])
	for mid in MOVES:
		var m: Dictionary = MOVES[mid]
		parts.append("m:%s=%s/%d/%d/%s" % [mid, str(m.get("strikes", [])), int(m.duration), int(m.damage), str(bool(m.get("unblockable", false)))])
	for eid in ENEMIES:
		var e: Dictionary = ENEMIES[eid]
		parts.append("e:%s=%d/%s/%s" % [eid, int(e.hp), str(e.moves), str(e.get("dmg_mul", 1.0))])
	return hash("\n".join(parts))
var _begin_events: Array = []


func _reset_stats() -> void:
	stats = {
		"defends": 0, "interrupts": 0, "summons": 0, "points_spent": 0,
		"points_spent_summon": 0, "unblocked_hits": 0, "moves_faced": 0,
		"zhan_played": 0, "yu_played": 0, "you_played": 0,
	}


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
	second_last_move_id = ""
	was_last_perfect = false
	rage = 0
	rage_half_applied = false
	moves_completed = 0
	force_perfect_next = false
	mirror_charges = 0
	podan_mul = 1.0
	golden_body = 0
	_reset_stats()
	defense_log.clear()
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
	var scost := SUMMON_COST - (1 if perfect_charge else 0)
	points -= scost
	stats.summons = int(stats.get("summons", 0)) + 1
	stats.points_spent = int(stats.get("points_spent", 0)) + scost
	stats.points_spent_summon = int(stats.get("points_spent_summon", 0)) + scost
	var idx := int(_next_rand() * float(pool.size()))
	var id: String = pool[idx]
	if idx < draw_pile.size():
		draw_pile.erase(id)
	else:
		discard_pile.erase(id)
	hand.append(id)
	events.append({"type": "card_summoned", "id": id, "cost": scost})
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
				events.append_array(_begin_events)
				_begin_events.clear()
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
			events.append({"type": "commit_cue", "intent": current_intent.id, "enemy": enemy_id})
		return
	if not window_announced and attack_elapsed >= float(current_intent.duration) - float(current_intent.window):
		window_announced = true
		events.append({"type": "commit_cue", "intent": current_intent.id, "enemy": enemy_id})


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
		if points >= 2:
			points -= 2
			rage = maxi(0, rage - 1)
			stats.points_spent = int(stats.get("points_spent", 0)) + 2
			current_intent.unblockable = false
			_finish_action(events)
			_log_defense("基础镇煞")
			events.append({"type": "basic_dispel"})
		else:
			defense_cooldown = MISS_COOLDOWN
			_log_defense("未处理鬼手")
			events.append({"type": "defense_miss", "unblockable": true, "reason": "points"})
		return events
	var time_to_impact := _current_impact_time() - attack_elapsed
	var success_window: float = current_intent.window
	if time_to_impact >= 0.0 and time_to_impact <= success_window:
		queued_defense = DefenseGrade.PERFECT if time_to_impact <= PERFECT_WINDOW else DefenseGrade.SUCCESS
		if force_perfect_next:
			queued_defense = DefenseGrade.PERFECT
			force_perfect_next = false
		_log_defense("乘势借势" if was_last_perfect else ("完美" if queued_defense == DefenseGrade.PERFECT else "成功"), time_to_impact)
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
	if String(mid) == second_last_move_id and int(ENEMIES[enemy_id].moves.size()) == 2:
		w *= 0.15
	if bool(move.get("unblockable", false)):
		if points >= 7 or rage >= 2:
			w += 0.9
		if enemy_hp >= int(ENEMIES[enemy_id].hp) * 0.6 and enemy_id != "lantern_keeper":
			w *= 0.5
	if int(move.damage) >= 12 and player_hp <= 24:
		w += 0.6
	if float(move.window) <= 0.22 and was_last_perfect:
		w += 0.5
	if enemy_hp < int(ENEMIES[enemy_id].hp) / 2 and int(move.damage) >= 12:
		w += 0.4
	return w


func _log_defense(result: String, tt := 0.0) -> void:
	defense_log.append({"move": current_intent.get("title", "?"), "result": result, "tt": snappedf(tt, 0.01)})
	if defense_log.size() > 3:
		defense_log.pop_front()


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
	stats.defends = int(stats.get("defends", 0)) + 1
	match grade:
		DefenseGrade.SUCCESS:
			if mirror_charges > 0:
				mirror_charges -= 1
				enemy_hp -= 3
				events.append({"type": "mirror_counter"})
			points = mini(MAX_POINTS, points + 1)
			perfect_charge = false
			events.append({"type": "impact", "grade": grade, "points": 1})
			events.append({"type": "points_changed"})
		DefenseGrade.PERFECT:
			points = mini(MAX_POINTS, points + 1)
			perfect_charge = true
			perfects += 1
			rage = mini(6, rage + 1)
			events.append({"type": "impact", "grade": grade, "points": 1})
			events.append({"type": "points_changed"})
			if current_intent.id == "blue" and strike_index < int(current_intent.strikes.size()) - 1:
				stagger_remaining = minf(STAGGER_CAP, stagger_remaining + PARRY_STAGGER)
			events.append({"type": "enemy_staggered"})
		_:
			perfect_charge = false
			var damage := int(current_intent.damage)
			damage = int(round(damage * float(ENEMIES[enemy_id].get("dmg_mul", 1.0))))
			var enraged := enemy_hp < int(ENEMIES[enemy_id].hp) / 2
			if enraged:
				damage = int(round(damage * 1.15))
			if podan_mul < 1.0:
				damage = int(round(damage * podan_mul))
				podan_mul = 1.0
			if golden_body > 0:
				damage = 5
				golden_body -= 1
			player_hp = maxi(0, player_hp - damage)
			stats.unblocked_hits = int(stats.get("unblocked_hits", 0)) + 1
			_log_defense("未防范 " + current_intent.get("title", ""))
			events.append({"type": "impact", "grade": grade, "damage": damage, "enraged": enraged})
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
	stats.points_spent = int(stats.get("points_spent", 0)) + cost
	match String(CARD_DATA[id]["class"]):
		"斩":
			stats.zhan_played = int(stats.get("zhan_played", 0)) + 1
		"御":
			stats.yu_played = int(stats.get("yu_played", 0)) + 1
		"佑":
			stats.you_played = int(stats.get("you_played", 0)) + 1
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
				points = mini(MAX_POINTS, points + 1)
				events.append({"type": "grab_cancelled", "points": 1})
				events.append({"type": "points_changed"})
			elif state == BattleState.WINDUP:
				stagger_remaining = minf(STAGGER_CAP, stagger_remaining + float(data.stagger))
				events.append({"type": "stagger", "duration": float(data.stagger)})
			events.append({"type": "card_played", "id": id, "damage": int(data.damage)})
		"duanxiang":
			current_intent.fake = -1.0
			fake_released = true
			events.append({"type": "card_played", "id": id, "damage": 0})
		"tinggeng":
			var enemy: Dictionary = ENEMIES[enemy_id]
			var next_id: String = String(enemy.moves[(attack_index + 1) % enemy.moves.size()])
			events.append({"type": "card_played", "id": id, "next_move": MOVES[next_id].title, "unblockable": bool(MOVES[next_id].get("unblockable", false))})
		"jieshi":
			force_perfect_next = true
			events.append({"type": "card_played", "id": id, "damage": 0})
		"tongjing":
			mirror_charges = mini(3, mirror_charges + 1)
			events.append({"type": "card_played", "id": id, "damage": 0})
		"podan":
			podan_mul = 0.6
			events.append({"type": "card_played", "id": id, "damage": 0})
		"jinshen":
			golden_body += 1
			events.append({"type": "card_played", "id": id, "damage": 0})
		"duannian":
			enemy_hp -= int(data.damage)
			var others: Array[String] = hand.filter(func(cid: String): return cid != id)
			if not others.is_empty():
				var victim: String = others[int(_next_rand() * float(others.size()))]
				hand.erase(victim)
				discard_pile.append(victim)
				events.append({"type": "hand_changed"})
			events.append({"type": "card_played", "id": id, "damage": int(data.damage), "discarded": true})
		"anhun":
			if bool(current_intent.get("unblockable", false)) and state == BattleState.WINDUP:
				current_intent.unblockable = false
				events.append({"type": "cleansed"})
			events.append({"type": "card_played", "id": id, "damage": 0})
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
	var recovery := ATTACK_RECOVERY * (0.8 if rage >= 3 else 1.0)
	recovery_remaining = recovery + (PARRY_STAGGER if perfect_charge else 0.0)
	rage = maxi(0, rage - 1)
	moves_completed += 1
	if hand.size() >= HAND_SIZE:
		points = mini(MAX_POINTS, points + 1)
		events.append({"type": "points_changed"})
	if hand.size() < HAND_SIZE and not (draw_pile.is_empty() and discard_pile.is_empty()):
		if draw_pile.is_empty():
			draw_pile = Array(discard_pile.duplicate(), TYPE_STRING, "", null)
			discard_pile.clear()
			_shuffle(draw_pile)
		hand.append(draw_pile.pop_back())
		events.append({"type": "hand_changed"})
	if moves_completed % 2 == 0:
		var pool: Array[String] = []
		pool.append_array(draw_pile)
		pool.append_array(discard_pile)
		if pool.is_empty():
			pass
		elif hand.size() < HAND_SIZE:
			var id: String = pool[int(_next_rand() * float(pool.size()))]
			if draw_pile.has(id):
				draw_pile.erase(id)
			else:
				discard_pile.erase(id)
			hand.append(id)
			events.append({"type": "hand_changed"})
			events.append({"type": "free_summon", "id": id})
		else:
			var victim := ""
			for cid in hand:
				if String(CARD_DATA[String(cid)]["class"]) != "斩":
					victim = String(cid)
					break
			if victim != "":
				var zha: Array = pool.filter(func(cid: String): return String(CARD_DATA[String(cid)]["class"]) == "斩")
				var pick: String = zha[int(_next_rand() * float(zha.size()))] if not zha.is_empty() else pool[int(_next_rand() * float(pool.size()))]
				if draw_pile.has(pick):
					draw_pile.erase(pick)
				else:
					discard_pile.erase(pick)
				hand.erase(victim)
				discard_pile.append(victim)
				hand.append(pick)
				events.append({"type": "hand_changed"})
				events.append({"type": "free_summon", "id": pick, "swapped": true})
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
	second_last_move_id = last_move_id
	if points >= 7:
		rage = mini(6, rage + 1)
	if enemy_hp < int(ENEMIES[enemy_id].hp) / 2 and not rage_half_applied:
		rage = mini(6, rage + 2)
		rage_half_applied = true
	var frenzied := rage >= 5
	if frenzied:
		rage = 2
	if frenzied and enemy.moves.has("quick"):
		move_id = "quick"
	elif not bool(enemy.get("reactive", false)) or attack_index == 0:
		move_id = String(enemy.moves[attack_index % enemy.moves.size()])
	last_move_id = move_id
	current_intent = MOVES[move_id].duplicate()
	if move_id == "blue" and rage >= 3 and current_intent.strikes.size() >= 2:
		var arr: Array = current_intent.strikes.duplicate()
		arr.append(float(arr[arr.size() - 1]) + 0.64)
		current_intent.strikes = arr
		current_intent.duration = float(arr[arr.size() - 1]) + 0.3
	stats.moves_faced = int(stats.get("moves_faced", 0)) + 1
	if frenzied:
		_begin_events.append({"type": "frenzy"})
	enemy_name = String(enemy.name)
	enemy_max_hp = int(enemy.hp)
