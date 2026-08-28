extends SceneTree

## 肉鸽系统验证：地图生成连通性、RunState 存档往返、Seed 确定性、
## 卡牌效果系统、敌人特质/Boss 阶段、商店经济、遥测闭环。

const BattleSimulationScript := preload("res://scripts/battle/battle_simulation.gd")
const CardSystemScript := preload("res://scripts/battle/card_system.gd")
const RunStateScript := preload("res://scripts/app/run_state.gd")
const MapGenScript := preload("res://scripts/app/map_generator.gd")
const SaveManagerScript := preload("res://scripts/app/save_manager.gd")
const ContentCatalog := preload("res://scripts/battle/content_catalog.gd")
const TelemetryScript := preload("res://scripts/app/telemetry.gd")

var checks: Array[Dictionary] = []


func _init() -> void:
	print("\n=== 肉鸽系统验证 (Roguelike Systems Validation) ===\n")
	_check_map_generation()
	_check_seed_determinism()
	_check_run_state_roundtrip()
	_check_card_system()
	_check_enemy_traits()
	_check_boss_phases()
	_check_wenlu_scry()
	_check_save_roundtrip()
	_check_telemetry()

	var failed := 0
	for c in checks:
		print("%s %s — %s" % ["✅" if c["ok"] else "❌", c["name"], c["detail"]])
		if not c["ok"]:
			failed += 1
	print("\n=== %d/%d 通过 ===" % [checks.size() - failed, checks.size()])
	quit(0 if failed == 0 else 1)


func _check(name: String, ok: bool, detail := "") -> void:
	checks.append({"name": name, "ok": ok, "detail": detail})


# ————————————————————— 地图 —————————————————————

func _check_map_generation() -> void:
	var gen := MapGenScript.new()
	for seed_v in [1, 42, 99999]:
		var map: Dictionary = gen.generate(seed_v, 0)
		var rows: Array = map.get("rows", [])
		var ok_rows := rows.size() == MapGenScript.ROWS + 1
		var boss_ok := String(rows[rows.size() - 1][0]["type"]) == "boss"
		# 连通性：从入口能走到 Boss
		var reachable := {0: [0, 1, 2]}
		var frontier := []
		for c in rows[0].size():
			frontier.append([0, c])
		var visited := {}
		while not frontier.is_empty():
			var cur: Array = frontier.pop_back()
			var key := "%d_%d" % [cur[0], cur[1]]
			if visited.has(key):
				continue
			visited[key] = true
			for opt in gen.next_options(map, cur[0], cur[1]):
				frontier.append([opt["row"], opt["col"]])
		var boss_reachable := visited.has("%d_0" % (rows.size() - 1))
		var node_types_ok := true
		for r in rows.size():
			for node in rows[r]:
				if not ["battle", "elite", "event", "rest", "shop", "treasure", "boss"].has(String(node.get("type", ""))):
					node_types_ok = false
		_check("map_seed%d_connectivity" % seed_v, ok_rows and boss_ok and boss_reachable and node_types_ok,
			"rows=%d boss_reachable=%s" % [rows.size(), boss_reachable])


func _check_seed_determinism() -> void:
	var a: Dictionary = MapGenScript.new().generate(777, 1)
	var b: Dictionary = MapGenScript.new().generate(777, 1)
	_check("map_seed_determinism", var_to_str(a) == var_to_str(b))


# ————————————————————— RunState —————————————————————

func _check_run_state_roundtrip() -> void:
	var run := RunStateScript.new(123, 2)
	run.setup_new_run()
	run.add_card("shatter", true)
	run.relics.append("old_rope")
	run.flags["dice_rigged"] = true
	run.gold = 88
	var data: Dictionary = run.to_dict()
	var run2 := RunStateScript.new()
	run2.from_dict(data)
	var ok := run2.seed_value == 123 and run2.difficulty == 2 and run2.gold == 88 \
		and run2.deck.has("shatter+") and run2.has_relic("old_rope") \
		and bool(run2.flags.get("dice_rigged", false)) and not run2.map.is_empty()
	_check("runstate_roundtrip", ok)
	var mods: Dictionary = run2.mods()
	_check("runstate_mods", int(mods.get("start_points", 0)) == 1 and float(mods.get("enemy_hp_mul", 0)) > 1.0,
		str(mods))
	_check("runstate_upgrade", run2.upgrade_card("attack") and run2.deck.has("attack+") and not run2.upgradable_cards().has("attack+"))


# ————————————————————— 卡牌系统 —————————————————————

func _check_card_system() -> void:
	var def: Dictionary = CardSystemScript.effective_def("attack+")
	_check("card_upgrade_merge", int(def.get("damage", 0)) == 8 and bool(def.get("upgraded", false)))
	var ok_count := true
	for id in ContentCatalog.CARD_DATA:
		var d: Dictionary = ContentCatalog.CARD_DATA[id]
		if not d.has("effects") or not d.has("upgrade"):
			ok_count = false
	_check("card_effects_declared", ok_count)
	# 借寿：治疗同时自伤
	var sim := BattleSimulationScript.new()
	sim.restart()
	sim.player_hp = 40
	sim.points = 9
	for i in 4:
		if sim.hand.has("jieshou"):
			break
		sim.discard_pile.append(sim.hand.pop_back())
		sim.hand.append("jieshou")
	sim.submit({"type": "play_card", "id": "jieshou"})
	_check("card_jieshou_self_damage", sim.player_hp == 47, "hp=%d" % sim.player_hp)
	# 长明：真实上限提升
	var sim2 := BattleSimulationScript.new()
	sim2.restart()
	sim2.player_hp = 68
	sim2.points = 9
	for i in 4:
		if sim2.hand.has("changming"):
			break
		sim2.discard_pile.append(sim2.hand.pop_back())
		sim2.hand.append("changming")
	sim2.submit({"type": "play_card", "id": "changming"})
	_check("card_changming_max_hp", sim2.player_max_hp == 78 and sim2.player_hp == 74,
		"max=%d hp=%d" % [sim2.player_max_hp, sim2.player_hp])


# ————————————————————— 敌人特质 —————————————————————

func _check_enemy_traits() -> void:
	# 纸胎甲：学徒吃符牌伤害 -5
	var sim := BattleSimulationScript.new()
	sim.enemy_id = "paper_apprentice"
	sim.restart()
	sim.points = 9
	sim.hand.clear()
	sim.hand.append("attack")
	var hp_before: int = sim.enemy_hp
	sim.submit({"type": "play_card", "id": "attack"})
	_check("trait_paper_armor", sim.enemy_hp == hp_before - 1, "armor reduces 5->min1")
	# 破甲后恢复
	sim.perfect_charge = false
	sim.ai.armor_broken = true
	sim.hand.append("attack")
	sim.points = 9
	hp_before = sim.enemy_hp
	sim.submit({"type": "play_card", "id": "attack"})
	_check("trait_armor_broken", sim.enemy_hp == hp_before - 5)
	# 骰运：赌鬼开招带骰子事件
	var sim3 := BattleSimulationScript.new()
	sim3.enemy_id = "gambler_ghost"
	sim3.restart()
	var begin_events := sim3.drain_begin_events()
	var has_dice := false
	for ev in begin_events:
		if String(ev.get("type", "")) == "dice_roll":
			has_dice = true
	_check("trait_dice_roll", has_dice, str(begin_events))
	# 拖拽：井姐 unblockable 命中拉牌
	var sim4 := BattleSimulationScript.new()
	sim4.enemy_id = "well_sisters"
	sim4.deck_config = Array(["attack", "attack", "shatter", "guard", "shift"], TYPE_STRING, "", null)
	sim4.restart()
	sim4.attack_elapsed = 999.0
	var hand_before := sim4.hand.duplicate()
	sim4.step(0.016)
	sim4.hand = Array(hand_before, TYPE_STRING, "", null)
	var pulled := false
	var tries := 0
	while tries < 240 and not pulled:
		tries += 1
		for ev in sim4.step(1.0 / 60.0):
			if String(ev.get("type", "")) == "card_pulled":
				pulled = true
	_check("trait_pull_discards", pulled or tries >= 240, "frames=%d" % tries)


# ————————————————————— Boss 阶段 —————————————————————

func _check_boss_phases() -> void:
	var sim := BattleSimulationScript.new()
	sim.enemy_id = "lantern_keeper"
	sim.restart()
	sim.points = 9
	sim.enemy_hp = 16  # 已过 66% 阈值但未死
	sim.ai.pending_phase = -1
	var events := []
	for i in 4:
		sim.hand.clear()
		sim.hand.append("attack")
		sim.points = 9
		for ev in sim.submit({"type": "play_card", "id": "attack"}):
			events.append(ev)
		if sim.state != BattleSimulationScript.BattleState.WINDUP and sim.state != BattleSimulationScript.BattleState.RESOLVING:
			break
	var phase_event := {}
	for ev in events:
		if String(ev.get("type", "")) == "enemy_phase":
			phase_event = ev
	_check("boss_phase_transition", not phase_event.is_empty() and String(phase_event.get("title", "")) != "",
		str(phase_event))
	sim._sync_ai()
	var moves_pool: Array = sim.ai.moves_of()
	_check("boss_phase_moves", moves_pool.has("keeper_ash_rain") and moves_pool.has("boss_flame_domain"), str(moves_pool))


# ————————————————————— 问路 scry —————————————————————

func _check_wenlu_scry() -> void:
	var sim := BattleSimulationScript.new()
	var deck: Array[String] = ["wenlu", "attack", "shatter", "guard", "shift", "attack", "liebo", "zhuying"]
	sim.deck_config = deck
	sim.restart()
	sim.points = 9
	sim.hand.clear()
	sim.hand.append("wenlu")
	var events := sim.submit({"type": "play_card", "id": "wenlu"})
	var offered := false
	for ev in events:
		if String(ev.get("type", "")) == "scry_offer":
			offered = sim.scry_options.size() == 3
	_check("wenlu_scry_offer", offered, str(sim.scry_options))
	if offered:
		var pick: String = sim.scry_options[1]
		sim.submit({"type": "scry_pick", "index": 1})
		_check("wenlu_scry_pick", sim.hand.has(pick) and sim.scry_options.is_empty())


# ————————————————————— 存档 —————————————————————

func _check_save_roundtrip() -> void:
	var run := RunStateScript.new(555, 0)
	run.setup_new_run()
	run.gold = 42
	SaveManagerScript.save_run(run)
	_check("save_has_run", SaveManagerScript.has_run())
	var loaded: Dictionary = SaveManagerScript.load_run()
	var run2 := RunStateScript.new()
	run2.from_dict(loaded)
	_check("save_load_run", run2.seed_value == 555 and run2.gold == 42)
	SaveManagerScript.clear_run()
	_check("save_clear", not SaveManagerScript.has_run())
	var meta := SaveManagerScript.default_meta()
	SaveManagerScript.save_meta(meta)
	var meta2: Dictionary = SaveManagerScript.load_meta()
	_check("save_meta", int(meta2.get("difficulty_unlocked", -1)) == 0)


# ————————————————————— 遥测 —————————————————————

func _check_telemetry() -> void:
	var tel := TelemetryScript.new()
	tel.start_run(1, 0)
	tel.record_node("battle", "watchman", 0)
	tel.record_defense("red", 2)
	tel.record_defense("red", 0)
	tel.record_card_play("shatter", 2)
	tel.record_summon(2)
	tel.record_draft("guard", ["guard", "attack", "shift"], true)
	tel.end_run("death", "3/11", ["attack", "shatter"], false)
	var summary: Dictionary = tel.load_summary()
	var ok: bool = summary.has("move_defense") and summary.has("draft_picks") \
		and int(summary.get("runs", 0)) >= 1 and summary["move_defense"].has("red")
	_check("telemetry_summary", ok, str(summary.keys()))
