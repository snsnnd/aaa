extends Node

## Telemetry（autoload "Telemetry"）：真人验证数据闭环。
## 自动 Playtest 只能证明"系统可运行"，这里收集的是"人玩得如何"：
##   哪个敌招误判最高 / 首次死亡位置 / 卡牌选择率 / 召符资源占比 /
##   构筑胜率 / 在哪个节点退出。
## 每局结束（胜/负/中途退出）落盘 user://telemetry/run_*.json，
## 聚合写 user://telemetry/summary.json，供离线分析。

const DIR := "user://telemetry"

const ContentCatalog := preload("res://scripts/battle/content_catalog.gd")

var run_data: Dictionary = {}
var enabled := true
var move_defense: Dictionary = {}    # 招式 → {attempt, perfect, success, miss}
var card_plays: Dictionary = {}      # 卡牌 → 次数
var card_costs: Dictionary = {}      # 卡牌 → 消耗还愿合计
var summon_cost := 0
var points_spent := 0


func start_run(seed_value: int, difficulty: int) -> void:
	if not enabled:
		return
	run_data = {
		"seed": seed_value, "difficulty": difficulty,
		"start_time": Time.get_datetime_string_from_system(),
		"nodes": [], "battles": [], "drafts": [], "events": [],
		"first_death": {}, "end_reason": "", "end_node": "",
	}
	move_defense.clear()
	card_plays.clear()
	card_costs.clear()
	summon_cost = 0
	points_spent = 0


func record_node(node_type: String, enemy: String, row: int) -> void:
	if not enabled or run_data.is_empty():
		return
	run_data["nodes"].append({"type": node_type, "enemy": enemy, "row": row})


func record_battle(enemy_id: String, victory: bool, hp_left: int, moves_faced: int, sim_stats: Dictionary) -> void:
	if not enabled or run_data.is_empty():
		return
	run_data["battles"].append({
		"enemy": enemy_id, "victory": victory, "hp_left": hp_left,
		"moves_faced": moves_faced, "stats": sim_stats,
	})
	if not victory and run_data["first_death"].is_empty():
		run_data["first_death"] = {"enemy": enemy_id, "nodes_seen": run_data["nodes"].size()}


func record_defense(move_id: String, grade: int) -> void:
	if not enabled:
		return
	# grade: 0 miss 1 success 2 perfect（ DefenseGrade 枚举序）
	var entry: Dictionary = move_defense.get(move_id, {"attempt": 0, "perfect": 0, "success": 0, "miss": 0})
	entry["attempt"] = int(entry["attempt"]) + 1
	match grade:
		2: entry["perfect"] = int(entry["perfect"]) + 1
		1: entry["success"] = int(entry["success"]) + 1
		_: entry["miss"] = int(entry["miss"]) + 1
	move_defense[move_id] = entry


func record_card_play(card_id: String, cost: int) -> void:
	if not enabled:
		return
	card_plays[card_id] = int(card_plays.get(card_id, 0)) + 1
	card_costs[card_id] = int(card_costs.get(card_id, 0)) + cost
	points_spent += cost


func record_summon(cost: int) -> void:
	if not enabled:
		return
	summon_cost += cost
	points_spent += cost


func record_draft(picked: String, options: Array, picked_any: bool) -> void:
	if not enabled or run_data.is_empty():
		return
	run_data["drafts"].append({"picked": picked if picked_any else "", "skipped": not picked_any, "options": options})


func record_event(event_id: String, choice: int) -> void:
	if not enabled or run_data.is_empty():
		return
	run_data["events"].append({"event": event_id, "choice": choice})


func end_run(reason: String, node_label: String, deck: Array, victory: bool) -> void:
	if not enabled or run_data.is_empty():
		return
	run_data["end_reason"] = reason  # victory / death / abandon
	run_data["end_node"] = node_label
	run_data["victory"] = victory
	run_data["deck"] = deck
	run_data["defense_by_move"] = move_defense
	run_data["card_plays"] = card_plays
	run_data["card_costs"] = card_costs
	run_data["summon_cost"] = summon_cost
	run_data["points_spent"] = points_spent
	if points_spent + summon_cost > 0:
		run_data["summon_share"] = float(summon_cost) / float(summon_cost + points_spent)
	DirAccess.make_dir_recursive_absolute(DIR)
	var fname := "run_%s_%d.json" % [Time.get_datetime_string_from_system().replace(":", ""), randi() % 1000]
	var f := FileAccess.open("%s/%s" % [DIR, fname], FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(run_data, "  "))
		f.close()
	_update_summary(victory)
	run_data = {}


func _update_summary(victory: bool) -> void:
	var summary := load_summary()
	summary["runs"] = int(summary.get("runs", 0)) + 1
	if victory:
		summary["wins"] = int(summary.get("wins", 0)) + 1
	# 构筑分类：按牌组主类占比粗分
	var counts := {"斩": 0, "御": 0, "佑": 0}
	for slot in run_data.get("deck", []):
		var id := String(slot).trim_suffix("+")
		if ContentCatalog.CARD_DATA.has(id):
			counts[String(ContentCatalog.CARD_DATA[id]["class"])] = counts[String(ContentCatalog.CARD_DATA[id]["class"])] + 1
	var build: String = counts.keys()[counts.values().find(counts.values().max())]
	if not summary.has("build_wins"):
		summary["build_wins"] = {}
	if not summary.has("build_runs"):
		summary["build_runs"] = {}
	summary["build_runs"][build] = int(summary["build_runs"].get(build, 0)) + 1
	if victory:
		summary["build_wins"][build] = int(summary["build_wins"].get(build, 0)) + 1
	# 招式误判率
	var md: Dictionary = run_data.get("defense_by_move", {})
	for move_id in md:
		if not summary.has("move_defense"):
			summary["move_defense"] = {}
		var agg: Dictionary = summary["move_defense"].get(move_id, {"attempt": 0, "perfect": 0, "success": 0, "miss": 0})
		for k in ["attempt", "perfect", "success", "miss"]:
			agg[k] = int(agg[k]) + int(md[move_id].get(k, 0))
		summary["move_defense"][move_id] = agg
	# 卡牌选择率 / 首死 / 退出节点
	if not summary.has("draft_picks"):
		summary["draft_picks"] = {}
	for d in run_data.get("drafts", []):
		var key := String(d["picked"]) if not bool(d["skipped"]) else "_skip"
		summary["draft_picks"][key] = int(summary["draft_picks"].get(key, 0)) + 1
	var first_death: Dictionary = run_data.get("first_death", {})
	if not first_death.is_empty():
		var fd_key := "%s@%s" % [first_death.get("enemy", "?"), first_death.get("nodes_seen", 0)]
		if not summary.has("first_deaths"):
			summary["first_deaths"] = {}
		summary["first_deaths"][fd_key] = int(summary["first_deaths"].get(fd_key, 0)) + 1
	if String(run_data.get("end_reason", "")) == "abandon":
		var q := String(run_data.get("end_node", "?"))
		if not summary.has("quit_nodes"):
			summary["quit_nodes"] = {}
		summary["quit_nodes"][q] = int(summary["quit_nodes"].get(q, 0)) + 1
	summary["updated"] = Time.get_datetime_string_from_system()
	var f := FileAccess.open(DIR + "/summary.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(summary, "  "))
		f.close()


func load_summary() -> Dictionary:
	if not FileAccess.file_exists(DIR + "/summary.json"):
		return {}
	var f := FileAccess.open(DIR + "/summary.json", FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if parsed is Dictionary else {}
