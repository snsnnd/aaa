class_name EnemyAI
extends RefCounted

## 敌人规则层：反应式选招、专属特质、Boss 阶段切换。
## 从 BattleSimulation 拆出，让每种敌人有"记忆点"而不只是血量倍率差异。

const ContentCatalog := preload("res://scripts/battle/content_catalog.gd")

const MOVES := ContentCatalog.MOVES
const ENEMIES := ContentCatalog.ENEMIES

var enemy_id := "watchman"
var enemy_hp := 46
var player_points := 0
var player_hp := 72
var player_hp_max := 72
var was_last_perfect := false
var last_defense_missed := false
var rng_state := 12345
# 特质运行时状态
var tempo_count := 0        # barber: 出招次数
var armor_broken := false   # paper_apprentice: 纸胎甲已破
var pending_phase := -1     # 待应用的阶段索引


func setup(id: String) -> void:
	enemy_id = id
	tempo_count = 0
	armor_broken = false
	pending_phase = -1


func enemy_def() -> Dictionary:
	return ENEMIES[enemy_id]


func hp_of() -> int:
	return int(enemy_def().hp)


## 当前阶段（Boss 按血量切换；普通敌人恒 -1）。
func current_phase() -> int:
	var phases: Array = enemy_def().get("phases", [])
	if phases.is_empty():
		return -1
	for i in phases.size():
		if enemy_hp <= int(enemy_def().hp) * float(phases[i]["below"]):
			return i
	return -1


## 返回阶段切换事件；未切换返回 []。
func check_phase(events: Array) -> Array:
	var phase := current_phase()
	if phase < 0 or phase <= pending_phase:
		return []
	pending_phase = phase
	var p: Dictionary = enemy_def()["phases"][phase]
	var ev := {
		"type": "enemy_phase",
		"phase": phase,
		"title": String(p.get("title", "")),
		"announce": String(p.get("announce", "")),
		"stagger": 1.0,
	}
	events.append(ev)
	return [ev]


func moves_of() -> Array:
	var phase := current_phase()
	if phase >= 0:
		return enemy_def()["phases"][phase]["moves"]
	return enemy_def().moves


## 完整选招：opening → 反应式加权 → 特质覆盖。
func pick_move(attack_index: int) -> String:
	var enemy: Dictionary = enemy_def()
	var move_id: String
	if attack_index == 0 or not bool(enemy.get("reactive", false)):
		move_id = String(enemy.opening if attack_index == 0 else moves_of()[attack_index % moves_of().size()])
	else:
		move_id = _pick_reactive()
	# 特质覆盖
	match String(enemy.get("trait", "")):
		"skittish":
			if was_last_perfect:
				move_id = "quick"
		"dice":
			if enemy_hp < hp_of() / 2 and moves_of().has("gamble_flip") and attack_index > 0:
				move_id = "gamble_flip"
	return move_id


func _pick_reactive() -> String:
	var pool: Array = moves_of()
	if pool.size() == 1:
		return String(pool[0])
	var weights: Array[float] = []
	var total := 0.0
	for mid in pool:
		var w := move_weight(String(mid))
		weights.append(w)
		total += w
	var roll := _next_rand() * total
	for i in pool.size():
		roll -= weights[i]
		if roll <= 0.0:
			return String(pool[i])
	return String(pool[pool.size() - 1])


func move_weight(mid: String) -> float:
	var move: Dictionary = MOVES[mid]
	var w := 1.0
	if String(mid) == last_move_id:
		w = 0.0
	if String(mid) == second_last_move_id() and moves_of().size() == 2:
		w *= 0.15
	if bool(move.get("unblockable", false)):
		if player_points >= 7 or rage >= 2:
			w += 0.9
		if enemy_hp >= hp_of() * 0.6 and enemy_id != "lantern_keeper":
			w *= 0.5
	if int(move.damage) >= 12 and player_hp <= 24:
		w += 0.6
	if float(move.window) <= 0.22 and was_last_perfect:
		w += 0.5
	if enemy_hp < hp_of() / 2 and int(move.damage) >= 12:
		w += 0.4
	return w


var last_move_id := ""
var second_last_move_id_cache := ""
var rage := 0


func second_last_move_id() -> String:
	return second_last_move_id_cache


func remember_move(move_id: String) -> void:
	second_last_move_id_cache = last_move_id
	last_move_id = move_id


func _next_rand() -> float:
	rng_state = (rng_state + 0x6D2B79F5) & 0xFFFFFFFF
	var t := rng_state
	t = ((t ^ (t >> 15)) * (t | 1)) & 0xFFFFFFFF
	t = (t ^ (t + ((t ^ (t >> 7)) * (t | 61)))) & 0xFFFFFFFF
	return float((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296.0


## 骰运（赌鬼）：返回 {"roll": 1-6, "dmg_mul": x, "window_mul": x, "text": "..."}。
## flags.dice_rigged（赌债事件押过局）时最低 4 点。
func roll_dice(rigged: bool) -> Dictionary:
	var roll := 0
	if rigged:
		roll = 4 + int(_next_rand() * 3.0)
	else:
		if player_points >= 5:
			roll = 6
		else:
			roll = 1 + int(_next_rand() * 6.0)
	var result := {"roll": roll, "dmg_mul": 1.0, "window_mul": 1.0, "text": ""}
	match roll:
		1, 2:
			result.dmg_mul = 0.5
			result.window_mul = 1.3
			result.text = "骰落两点——赌鬼心虚，这一下不疼"
		3, 4:
			result.text = "骰落平点"
		5, 6:
			result.dmg_mul = 1.5
			result.window_mul = 0.85
			result.text = "骰落大点——赌鬼狞笑，刀势陡然凶狠"
	return result


## 招式开工修饰：tempo（剃头匠）收窄窗口并提前命中。
func apply_tempo(intent: Dictionary) -> void:
	var tempo: float = float(intent.get("tempo", 0.0))
	if tempo <= 0.0:
		return
	var shrink := minf(0.4, tempo * tempo_count)
	intent.window = maxf(0.12, float(intent.window) - shrink)
	if intent.has("strikes"):
		var arr: Array = []
		for s in intent.strikes:
			arr.append(maxf(0.3, float(s) * (1.0 - shrink * 0.6)))
		intent.strikes = arr
		intent.duration = maxf(0.8, float(intent.duration) * (1.0 - shrink * 0.6))


## 纸胎甲：返回卡牌伤害修正（完美弹反后破甲）。
func card_damage_modifier() -> int:
	if String(enemy_def().get("trait", "")) == "paper_armor" and not armor_broken:
		return -5
	return 0


## 战斗开场特质播报。
func trait_intro() -> String:
	match String(enemy_def().get("trait", "")):
		"paper_armor":
			return "纸胎裹身——破甲前，符牌伤害被纸层吞去 5 点"
		"tempo":
			return "剃刀越转越急——他的招会越来越快"
		"dice":
			return "骰子在指间打转——他的每一招都押着点数"
		"heavy":
			return "尸身沉坠——挨上一下要多疼 4 点"
		"vengeance":
			return "看守记仇——你失手一次，下一刀就重 6 点"
		"pull":
			return "水下的手很长——小心它拖走你的符牌"
		"skittish":
			return "灯影里的小东西——接准一次，它就只会窜"
	return ""
