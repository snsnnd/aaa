class_name BattleSimulation
extends RefCounted

const ContentCatalog := preload("res://scripts/battle/content_catalog.gd")
const CardSystemScript := preload("res://scripts/battle/card_system.gd")
const EnemyAIScript := preload("res://scripts/battle/enemy_ai.gd")

## 纯规则层：不含 Node、输入、音频、动画或任何 Godot 场景对象。
## 输入只能是 submit() 的命令，输出只能是事件数组，状态全部可读、可快照。
## 卡牌执行走 CardSystem 效果列表；敌人选招/特质/Boss 阶段走 EnemyAI。

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
var initial_hp := PLAYER_MAX_HP
var player_hp := PLAYER_MAX_HP
var player_max_hp := PLAYER_MAX_HP
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
var ai: EnemyAIScript
## 局外修饰：遗物 mods + 难度修饰 + 反应辅助。由 RunFlow/apply_run_config 写入。
var run_mods: Dictionary = {}
## 剧情旗标（RunState.flags 的只读投影）。
var story_flags: Dictionary = {}
## 问路（scry）待选状态：非空时仅接受 scry_pick 命令。
var scry_options: Array[String] = []
var _begin_events: Array = []
var _skip_next_strike := false
var _cards_played := 0
var _first_miss_used := false
var _next_window_bonus := 0.0


func _init() -> void:
	ai = EnemyAIScript.new()
	restart()


## 玩法内容指纹：仅含规则字段；表现改动不影响此值。
func content_hash() -> int:
	var parts: Array[String] = []
	parts.append("pw=%.3f/gr=%.3f/mc=%d/sc=%d" % [PERFECT_WINDOW, SUCCESS_GRACE, MAX_POINTS, SUMMON_COST])
	parts.append("hp=%d/deck=%s" % [PLAYER_MAX_HP, ",".join(STARTING_DECK)])
	for id in CARD_DATA:
		parts.append("c:%s=%s" % [id, var_to_str(CARD_DATA[id])])
	for mid in MOVES:
		parts.append("m:%s=%s" % [mid, var_to_str(MOVES[mid])])
	for eid in ENEMIES:
		parts.append("e:%s=%s" % [eid, var_to_str(ENEMIES[eid])])
	parts.append("relics=%s" % var_to_str(ContentCatalog.RELICS))
	parts.append("diffs=%s" % var_to_str(ContentCatalog.DIFFICULTIES))
	return hash("\n".join(parts))


func _reset_stats() -> void:
	stats = {
		"defends": 0, "interrupts": 0, "summons": 0, "points_spent": 0,
		"points_spent_summon": 0, "unblocked_hits": 0, "moves_faced": 0,
		"zhan_played": 0, "yu_played": 0, "you_played": 0,
		"cards_played": 0, "damage_dealt": 0, "damage_taken": 0,
		"max_hp_gained": 0, "cards_pulled": 0, "phases_seen": 0,
	}


func _mod(key: String, fallback: Variant) -> Variant:
	return run_mods.get(key, fallback)


func _max_points() -> int:
	return mini(99, MAX_POINTS + int(_mod("max_points_bonus", 0)))


func _rage_threshold() -> int:
	return int(_mod("rage_threshold", 7))


func _reaction_assist() -> float:
	return maxf(0.5, float(_mod("reaction_assist", 1.0)))


func restart(hp: int = -1) -> void:
	## 显式语义：hp < 0 → 恢复到 initial_hp（本战开局血量，由 RunFlow 写入），
	## 因此 Run 内重开只会回到本战起点，不存在恢复满血的风险。
	battle_generation += 1
	player_max_hp = PLAYER_MAX_HP + int(_mod("max_hp_bonus", 0))
	player_hp = initial_hp if hp < 0 else mini(hp, player_max_hp)
	points = mini(int(_mod("start_points", 0)), _max_points())
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
	_cards_played = 0
	_first_miss_used = false
	_next_window_bonus = 0.0
	scry_options.clear()
	_reset_stats()
	defense_log.clear()
	queued_defense = DefenseGrade.NONE
	recovery_remaining = 0.0
	# Seed 管线：RunFlow 传入 battle_seed 时完全由 Run 种子派生；否则用默认偏移（demo/独立战斗）
	if run_mods.has("battle_seed"):
		battle_seed = int(_mod("battle_seed", 0)) + battle_generation
	else:
		battle_seed = 20260828 + battle_generation
	rng_state = battle_seed
	ai.setup(enemy_id)
	ai.rng_state = battle_seed ^ 0x5bf03635
	enemy_max_hp = int(round(float(ENEMIES[enemy_id].hp) * float(_mod("enemy_hp_mul", 1.0))))
	enemy_hp = enemy_max_hp
	_setup_deck()
	_begin_attack()


## 战斗开场事件（特质播报/骰运等）：由表现层在开局后主动取走。
func drain_begin_events() -> Array:
	var out := _begin_events.duplicate()
	_begin_events.clear()
	return out


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


func _refill_draw_pile() -> void:
	if draw_pile.is_empty() and not discard_pile.is_empty():
		draw_pile = Array(discard_pile.duplicate(), TYPE_STRING, "", null)
		discard_pile.clear()
		_shuffle(draw_pile)


## 命令入口：{type:"defend"} / {type:"play_card", id:...} / {type:"summon"} / {type:"scry_pick", index:n}。
## 返回本命令立刻产生的事件；延迟事件随 step() 返回。
func submit(command: Dictionary) -> Array:
	match String(command.get("type", "")):
		"defend":
			return _attempt_defense()
		"play_card":
			return _play_card(String(command.get("id", "")))
		"summon":
			return _summon_card()
		"scry_pick":
			return _scry_pick(int(command.get("index", 0)))
	return []


func _scry_pick(index: int) -> Array:
	var events: Array = []
	if scry_options.is_empty():
		return events
	index = clampi(index, 0, scry_options.size() - 1)
	var picked: String = scry_options[index]
	scry_options.remove_at(index)
	for remaining in scry_options:
		draw_pile.append(remaining)
	hand.append(picked)
	scry_options.clear()
	events.append({"type": "card_played", "id": "wenlu", "draw": 1})
	events.append({"type": "hand_changed"})
	events.append({"type": "scry_done", "picked": picked})
	return events


func _summon_card() -> Array:
	var events: Array = []
	if state == BattleState.VICTORY or state == BattleState.DEFEAT:
		events.append({"type": "summon_rejected", "reason": "ended"})
		return events
	if hand.size() >= HAND_SIZE:
		events.append({"type": "summon_rejected", "reason": "hand_full"})
		return events
	var scost := SUMMON_COST - (1 if perfect_charge else 0)
	if points < scost:
		events.append({"type": "summon_rejected", "reason": "points"})
		return events
	var pool: Array[String] = []
	pool.append_array(draw_pile)
	pool.append_array(discard_pile)
	if pool.is_empty():
		events.append({"type": "summon_rejected", "reason": "empty"})
		return events
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
		if _skip_next_strike:
			_skip_next_strike = false
			queued_defense = DefenseGrade.NONE
			events.append({"type": "strike_skipped", "index": strike_index})
		else:
			_resolve_impact(events)
		strike_index += 1
	if state == BattleState.WINDUP and not strikes.is_empty() and strike_index >= strikes.size():
		_finish_action(events)
	if state == BattleState.WINDUP and strikes.is_empty() and attack_elapsed >= float(current_intent.duration):
		_resolve_impact(events)
		if state == BattleState.WINDUP:
			_finish_action(events)


func _collect_cue_events(events: Array) -> void:
	var strikes: Array = current_intent.get("strikes", [])
	if not strikes.is_empty():
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
			_register_miss(events, true)
			_log_defense("未处理鬼手")
			events.append({"type": "defense_miss", "unblockable": true, "reason": "points"})
		return events
	var assist := _reaction_assist()
	var time_to_impact := _current_impact_time() - attack_elapsed
	var success_window: float = float(current_intent.window) * assist
	if time_to_impact >= 0.0 and time_to_impact <= success_window:
		queued_defense = DefenseGrade.PERFECT if time_to_impact <= PERFECT_WINDOW * assist else DefenseGrade.SUCCESS
		if force_perfect_next:
			queued_defense = DefenseGrade.PERFECT
			force_perfect_next = false
		_log_defense("乘势借势" if was_last_perfect else ("完美" if queued_defense == DefenseGrade.PERFECT else "成功"), time_to_impact)
	elif time_to_impact < 0.0 and time_to_impact >= -SUCCESS_GRACE:
		queued_defense = DefenseGrade.SUCCESS
	else:
		_register_miss(events, false)
		events.append({"type": "defense_miss"})
		return events
	events.append({"type": "defense_queued", "grade": queued_defense})
	return events


## 防范失误统一登记：红绳遗物首误豁免冷却；义庄看守记仇。
func _register_miss(events: Array, _unblockable: bool) -> void:
	if bool(_mod("first_miss_free", false)) and not _first_miss_used:
		_first_miss_used = true
		events.append({"type": "miss_forgiven"})
	else:
		defense_cooldown = MISS_COOLDOWN
	ai.last_defense_missed = true


## 兼容旧接口：反应式权重查询（冒烟测试使用）。
func _move_weight(mid: String) -> float:
	_sync_ai()
	return ai.move_weight(mid)


func _sync_ai() -> void:
	ai.enemy_hp = enemy_hp
	ai.player_points = points
	ai.player_hp = player_hp
	ai.player_hp_max = player_max_hp
	ai.was_last_perfect = was_last_perfect
	ai.rage = rage


func _log_defense(result: String, tt := 0.0) -> void:
	defense_log.append({"move": current_intent.get("title", "?"), "result": result, "tt": snappedf(tt, 0.01)})
	if defense_log.size() > 3:
		defense_log.pop_front()


func _current_impact_time() -> float:
	var strikes: Array = current_intent.get("strikes", [])
	if not strikes.is_empty() and strike_index < strikes.size():
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
				_damage_enemy(3, events, false)
				events.append({"type": "mirror_counter"})
			points = mini(_max_points(), points + 1)
			perfect_charge = false
			events.append({"type": "impact", "grade": grade, "points": 1})
			events.append({"type": "points_changed"})
		DefenseGrade.PERFECT:
			points = mini(_max_points(), points + int(_mod("perfect_extra_point", 0)) + 1)
			perfect_charge = true
			perfects += 1
			rage = mini(6, rage + 1)
			events.append({"type": "impact", "grade": grade, "points": 1})
			events.append({"type": "points_changed"})
			if current_intent.id == "blue" and strike_index < int(current_intent.get("strikes", []).size()) - 1:
				stagger_remaining = minf(STAGGER_CAP, stagger_remaining + PARRY_STAGGER)
			events.append({"type": "enemy_staggered"})
			_break_armor(events)
		_:
			perfect_charge = false
			var damage := _incoming_damage()
			player_hp = maxi(0, player_hp - damage)
			stats.unblocked_hits = int(stats.get("unblocked_hits", 0)) + 1
			stats.damage_taken = int(stats.get("damage_taken", 0)) + damage
			_log_defense("未防范 " + current_intent.get("title", ""))
			events.append({"type": "impact", "grade": grade, "damage": damage, "enraged": enemy_hp < enemy_max_hp / 2})
			_pull_card(events)
			if player_hp <= 0:
				_end_battle(events)


func _incoming_damage() -> int:
	var strikes: Array = current_intent.get("strikes", [])
	var damage: int = int(current_intent.damage)
	if not strikes.is_empty() and strike_index < int(current_intent.get("strike_damage", []).size()):
		damage = int(current_intent["strike_damage"][strike_index])
	damage = int(round(float(damage) * float(ENEMIES[enemy_id].get("dmg_mul", 1.0)) * float(_mod("enemy_dmg_mul", 1.0))))
	damage += int(current_intent.get("vengeance_bonus", 0))
	if String(ENEMIES[enemy_id].get("trait", "")) == "heavy":
		damage += 4
	if enemy_hp < enemy_max_hp / 2:
		damage = int(round(damage * 1.15))
	if podan_mul < 1.0:
		damage = int(round(damage * podan_mul))
		podan_mul = 1.0
	if golden_body > 0:
		damage = 5
		golden_body -= 1
	return damage


## 未防范命中且招式带 pull：拖走玩家一张手牌（井中姐弟 / 守灯人三阶段）。
func _pull_card(events: Array) -> void:
	if not bool(current_intent.get("pull", false)) or hand.is_empty():
		return
	var victim: String = hand[int(_next_rand() * float(hand.size()))]
	hand.erase(victim)
	discard_pile.append(victim)
	stats.cards_pulled = int(stats.get("cards_pulled", 0)) + 1
	events.append({"type": "card_pulled", "id": victim})
	events.append({"type": "hand_changed"})


func _break_armor(events: Array) -> void:
	if String(ENEMIES[enemy_id].get("trait", "")) == "paper_armor" and not ai.armor_broken:
		ai.armor_broken = true
		events.append({"type": "armor_broken"})


func _damage_enemy(amount: int, events: Array, from_card: bool) -> void:
	var dealt := amount
	if from_card:
		var armor_mod := ai.card_damage_modifier()
		# 剧情旗标"纸人开脸"：学徒纸胎甲减伤从 -5 降为 -2
		if armor_mod != 0 and bool(story_flags.get("paper_face_done", false)):
			armor_mod = -2
		dealt = maxi(1, amount + armor_mod)
	enemy_hp -= dealt
	stats.damage_dealt = int(stats.get("damage_dealt", 0)) + dealt
	if enemy_hp <= 0:
		_end_battle(events)
		return
	# Boss 阶段切换（血量阈值）
	_sync_ai()
	for ev: Dictionary in ai.check_phase([]):
		stagger_remaining = maxf(stagger_remaining, float(ev.get("stagger", 1.0)))
		stats.phases_seen = int(stats.get("phases_seen", 0)) + 1
		events.append(ev)


func _play_card(id: String) -> Array:
	var events: Array = []
	if state == BattleState.VICTORY or state == BattleState.DEFEAT:
		events.append({"type": "card_rejected", "id": id, "reason": "ended"})
		return events
	if not scry_options.is_empty():
		events.append({"type": "card_rejected", "id": id, "reason": "scrying"})
		return events
	if not hand.has(id):
		events.append({"type": "card_rejected", "id": id, "reason": "not_in_hand"})
		return events
	var def: Dictionary = CardSystemScript.effective_def(id)
	if def.is_empty():
		return events
	var cost := int(def.cost)
	if _cards_played == 0 and bool(_mod("first_card_free", false)):
		cost = 0
	if points < cost:
		events.append({"type": "card_rejected", "id": id, "reason": "points"})
		return events
	points -= cost
	stats.points_spent = int(stats.get("points_spent", 0)) + cost
	stats.cards_played = _cards_played + 1
	_cards_played += 1
	match String(def["class"]):
		"斩":
			stats.zhan_played = int(stats.get("zhan_played", 0)) + 1
		"御":
			stats.yu_played = int(stats.get("yu_played", 0)) + 1
		"佑":
			stats.you_played = int(stats.get("you_played", 0)) + 1
	for eff: Dictionary in CardSystemScript.effects_of(id):
		_apply_effect(eff, id, events)
	hand.erase(id)
	discard_pile.append(id)
	if enemy_hp <= 0 and state not in [BattleState.VICTORY, BattleState.DEFEAT]:
		_end_battle(events)
	return events


func _apply_effect(eff: Dictionary, id: String, events: Array) -> void:
	# amount 统一按 float 读取：0.2/0.35/0.5s 这类时间轴数值不能被 int 截断
	var amt := float(eff.get("amount", 0.0))
	var n := int(amt)
	match String(eff.get("type", "")):
		"damage":
			var dmg := n
			match String(eff.get("bonus_cond", "")):
				"player_wounded":
					if player_hp < player_max_hp:
						dmg += int(eff.get("bonus", 0))
				"enemy_low":
					if enemy_hp < 20:
						dmg += int(eff.get("bonus", 0))
			_damage_enemy(dmg, events, true)
			events.append({"type": "card_played", "id": id, "damage": dmg})
		"charged_bonus":
			var in_stagger_window := state == BattleState.RESOLVING or stagger_remaining > 0.0
			if perfect_charge and in_stagger_window:
				_damage_enemy(n, events, true)
				events.append({"type": "charged_bonus", "id": id, "damage": n})
			perfect_charge = false
		"heal":
			var healed := mini(n, player_max_hp - player_hp)
			player_hp += healed
			events.append({"type": "card_played", "id": id, "healed": healed})
		"max_hp":
			player_max_hp += n
			player_hp = mini(player_max_hp, player_hp + n)
			stats.max_hp_gained = int(stats.get("max_hp_gained", 0)) + n
			events.append({"type": "card_played", "id": id, "max_hp": n})
		"damage_self":
			player_hp = maxi(1, player_hp - n)
			events.append({"type": "card_played", "id": id, "self_damage": n})
		"stagger":
			if state == BattleState.WINDUP and amt > 0.0:
				var amount := amt * float(_mod("stagger_mul", 1.0))
				stagger_remaining = minf(STAGGER_CAP, stagger_remaining + amount)
				events.append({"type": "stagger", "duration": amount})
		"grab_cancel":
			if state == BattleState.WINDUP and bool(current_intent.get("unblockable", false)) and fake_released:
				_finish_action(events)
				points = mini(_max_points(), points + 1)
				events.append({"type": "grab_cancelled", "points": 1})
				events.append({"type": "points_changed"})
		"interrupt":
			if state == BattleState.WINDUP and enemy_id != "lantern_keeper":
				_finish_action(events)
				stats.interrupts = int(stats.get("interrupts", 0)) + 1
				events.append({"type": "action_interrupted"})
		"force_perfect":
			force_perfect_next = true
		"mirror":
			mirror_charges = mini(3, mirror_charges + n)
		"fear":
			podan_mul = float(eff.get("mul", 1.0))
		"golden":
			golden_body += n
		"cleanse":
			if bool(current_intent.get("unblockable", false)) and state == BattleState.WINDUP:
				current_intent.unblockable = false
				events.append({"type": "cleansed"})
		"suppress_fake":
			current_intent.fake = -1.0
			fake_released = true
		"delay_impact":
			var t := amt
			if current_intent.has("strikes"):
				var arr: Array = []
				for s in current_intent.strikes:
					arr.append(float(s) + t)
				current_intent.strikes = arr
			current_intent.duration = float(current_intent.duration) + t
			events.append({"type": "impact_delayed", "amount": t})
		"widen_window":
			current_intent.window = float(current_intent.window) + float(eff.get("amount", 0.0))
		"widen_window_next":
			_next_window_bonus += float(eff.get("amount", 0.0))
		"skip_next_strike":
			if current_intent.get("strikes", []).size() > strike_index:
				_skip_next_strike = true
		"draw":
			for _i in n:
				_refill_draw_pile()
				if hand.size() < HAND_SIZE and not draw_pile.is_empty():
					hand.append(draw_pile.pop_back())
			events.append({"type": "hand_changed"})
		"scry":
			_refill_draw_pile()
			var count := mini(n, draw_pile.size())
			scry_options.clear()
			for _i in count:
				scry_options.append(draw_pile.pop_back())
			if not scry_options.is_empty():
				events.append({"type": "card_played", "id": id, "scry": scry_options.size()})
				events.append({"type": "scry_offer", "options": scry_options.duplicate()})
			else:
				events.append({"type": "card_played", "id": id, "draw": 0})
		"summon_draw":
			for _i in n:
				_refill_draw_pile()
				if hand.size() < HAND_SIZE and not draw_pile.is_empty():
					hand.append(draw_pile.pop_back())
			events.append({"type": "hand_changed"})
			events.append({"type": "card_played", "id": id, "summon": n})
		"discard_random":
			var others: Array[String] = hand.filter(func(cid: String): return cid != id)
			if not others.is_empty() and not bool(eff.get("optional", false)) or (not others.is_empty() and bool(eff.get("optional", false)) and _next_rand() < 0.5):
				var victim: String = others[int(_next_rand() * float(others.size()))]
				hand.erase(victim)
				discard_pile.append(victim)
				events.append({"type": "hand_changed"})
		"points":
			points = mini(_max_points(), points + n)
			events.append({"type": "points_changed"})
		"reveal_next":
			var pool: Array = ai.moves_of()
			var next_id: String = String(pool[(attack_index + 1) % pool.size()])
			events.append({"type": "card_played", "id": id, "next_move": MOVES[next_id].title, "unblockable": bool(MOVES[next_id].get("unblockable", false))})


func _finish_action(events: Array) -> void:
	state = BattleState.RESOLVING
	var recovery := ATTACK_RECOVERY * (0.8 if rage >= 3 else 1.0)
	recovery_remaining = recovery + (PARRY_STAGGER if perfect_charge else 0.0)
	rage = maxi(0, rage - 1)
	moves_completed += 1
	if String(ENEMIES[enemy_id].get("trait", "")) == "tempo":
		ai.tempo_count += 1
	if hand.size() >= HAND_SIZE:
		points = mini(_max_points(), points + 1)
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
				if String(CardSystemScript.class_of(String(cid))) != "斩":
					victim = String(cid)
					break
			if victim != "":
				var zha: Array = pool.filter(func(cid: String): return String(CardSystemScript.class_of(String(cid))) == "斩")
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
	_skip_next_strike = false
	_sync_ai()
	var enemy: Dictionary = ENEMIES[enemy_id]
	var move_id: String = ai.pick_move(attack_index)
	ai.remember_move(move_id)
	last_move_id = move_id
	second_last_move_id = ai.second_last_move_id()
	if points >= _rage_threshold():
		rage = mini(6, rage + 1)
	if enemy_hp < enemy_max_hp / 2 and not rage_half_applied:
		rage = mini(6, rage + 2)
		rage_half_applied = true
	var frenzied := rage >= 5
	if frenzied:
		rage = 2
	if frenzied and enemy.moves.has("quick"):
		move_id = "quick"
	last_move_id = move_id
	current_intent = MOVES[move_id].duplicate()
	ai.apply_tempo(current_intent)
	current_intent.window = float(current_intent.window) + _next_window_bonus
	_next_window_bonus = 0.0
	var flags := story_flags
	if enemy_id == "well_sisters" and bool(flags.get("well_blessing", false)):
		current_intent.window = float(current_intent.window) * 1.1
	if enemy_id == "lantern_keeper" and ai.current_phase() <= 0 and bool(flags.get("mourner_song", false)):
		current_intent.window = float(current_intent.window) * 1.12
	if bool(current_intent.get("dice", false)):
		var roll: Dictionary = ai.roll_dice(bool(flags.get("dice_rigged", false)))
		current_intent.damage = int(round(float(current_intent.damage) * float(roll.dmg_mul)))
		if current_intent.has("strike_damage"):
			var sd: Array = []
			for d in current_intent.strike_damage:
				sd.append(int(round(float(d) * float(roll.dmg_mul))))
			current_intent.strike_damage = sd
		current_intent.window = float(current_intent.window) * float(roll.window_mul)
		_begin_events.append({"type": "dice_roll", "roll": roll.roll, "text": roll.text})
	if String(enemy.get("trait", "")) == "vengeance" and ai.last_defense_missed:
		current_intent.vengeance_bonus = 6
		ai.last_defense_missed = false
		_begin_events.append({"type": "vengeance_up"})
	else:
		current_intent.vengeance_bonus = 0
	stats.moves_faced = int(stats.get("moves_faced", 0)) + 1
	if frenzied:
		_begin_events.append({"type": "frenzy"})
	enemy_name = String(enemy.name)
	enemy_max_hp = int(round(float(enemy.hp) * float(_mod("enemy_hp_mul", 1.0))))
	if attack_index == 0:
		var intro := ai.trait_intro()
		if intro != "":
			_begin_events.append({"type": "trait_intro", "text": intro})
