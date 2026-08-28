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
	_check_combo_system()
	_check_effect_floats()
	_check_boss_phase_order()
	_check_battle_seed_determinism()
	_check_wiring_audit()
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
	# 拖拽：井姐 unblockable 命中拉牌（确定性构造：直接注入沉井拖拽意图）
	var sim4 := BattleSimulationScript.new()
	sim4.enemy_id = "well_sisters"
	sim4.deck_config = Array(["attack", "attack", "shatter", "guard", "shift"], TYPE_STRING, "", null)
	sim4.restart()
	sim4.current_intent = BattleSimulationScript.MOVES["sisters_drag"].duplicate()
	sim4.attack_elapsed = 1.99  # 一步跨过 2.0s 命中点
	var pulled := false
	var pulled_id := ""
	for ev in sim4.step(1.0 / 60.0):
		if String(ev.get("type", "")) == "card_pulled":
			pulled = true
			pulled_id = String(ev.get("id", ""))
	# 注意：finish_action 会补牌，所以验证"被拉走的牌进了弃牌堆"而不是手牌数量
	_check("trait_pull_discards", pulled and pulled_id != "" and sim4.discard_pile.has(pulled_id),
		"pulled=%s" % pulled_id)
	# 记仇：防范失误后下一招 vengeance_bonus=6
	var sim5 := BattleSimulationScript.new()
	sim5.enemy_id = "mortuary_warden"
	sim5.restart()
	sim5.ai.last_defense_missed = false
	sim5.attack_elapsed = 0.1
	sim5.submit({"type": "defend"})  # 过早 → miss
	sim5.defense_cooldown = 0.0
	sim5._finish_action([])
	sim5.attack_index += 1
	sim5._begin_attack()
	_check("trait_vengeance_armed", int(sim5.current_intent.get("vengeance_bonus", 0)) == 6,
		str(sim5.current_intent.get("vengeance_bonus", -1)))
	# 红绳遗物：首误豁免冷却，第二误仍进入冷却
	var sim6 := BattleSimulationScript.new()
	sim6.run_mods = {"first_miss_free": true}
	sim6.restart()
	sim6.attack_elapsed = 0.1
	sim6.submit({"type": "defend"})
	var first_free: bool = sim6.defense_cooldown == 0.0
	sim6.attack_elapsed = 0.2
	sim6.submit({"type": "defend"})
	var second_cool: bool = sim6.defense_cooldown > 0.0
	_check("relic_first_miss_free", first_free and second_cool,
		"first_free=%s second_cool=%s" % [first_free, second_cool])
	# 剧情旗标"纸人开脸"：纸胎甲 -5 → -2
	var sim7 := BattleSimulationScript.new()
	sim7.enemy_id = "paper_apprentice"
	sim7.story_flags = {"paper_face_done": true}
	sim7.restart()
	sim7.points = 9
	sim7.hand.clear()
	sim7.hand.append("attack")
	var hp_before7: int = sim7.enemy_hp
	sim7.submit({"type": "play_card", "id": "attack"})
	_check("flag_paper_face_done", sim7.enemy_hp == hp_before7 - 3, "dmg=%d" % (hp_before7 - sim7.enemy_hp))


# ————————————————————— 连招/动作层 —————————————————————

func _check_combo_system() -> void:
	var ComboSys: GDScript = preload("res://scripts/battle/combo_system.gd")
	var ActionStateCls: GDScript = preload("res://scripts/battle/action_state.gd")
	var ActionCat: GDScript = preload("res://scripts/battle/action_catalog.gd")
	# 1) 防反=连招起手：成功写入 parry_exit 且窗口打开
	var sim := BattleSimulationScript.new()
	sim.restart()
	sim.attack_elapsed = float(sim.current_intent.duration) - 0.20
	sim.submit({"type": "defend"})
	sim.step(1.0)  # 结算成功防范
	_check("combo_parry_opens", sim.action_state.current_pose == "parry_exit" and sim.action_state.is_chain_open(),
		"pose=%s timer=%.2f lvl=%d" % [sim.action_state.current_pose, sim.action_state.combo_timer, sim.action_state.combo_level])
	# 2) 连招窗口内出牌：产生 action_started 且顺势衔接涨连势
	var act_events := []
	for card_id in ["attack", "zhuying", "liebo"]:
		if sim.action_state.combo_timer <= 0.0:
			sim.action_state.combo_timer = ActionCat.COMBO_WINDOW
		sim.points = 9
		if not sim.hand.has(card_id):
			sim.hand.append(card_id)
		for ev in sim.submit({"type": "play_card", "id": card_id}):
			act_events.append(ev)
	var started := act_events.filter(func(e): return String(e.get("type", "")) == "action_started")
	var seamless := act_events.filter(func(e): return String(e.get("type", "")) == "action_started" and String(e.get("transition", "")) == "seamless")
	var impacts := act_events.filter(func(e): return String(e.get("type", "")) == "action_impact")
	var reactions := act_events.filter(func(e): return String(e.get("type", "")) == "enemy_reaction")
	_check("combo_action_events", started.size() == 3 and impacts.size() == 3 and reactions.size() == 3,
		"started=%d impacts=%d reactions=%d" % [started.size(), impacts.size(), reactions.size()])
	_check("combo_seamless_chain", seamless.size() >= 1 and sim.action_state.momentum >= 1,
		"seamless=%d momentum=%d lvl=%d" % [seamless.size(), sim.action_state.momentum, sim.action_state.combo_level])
	# 3) 受击清空连势
	sim.action_state.momentum = 3
	sim.action_state.on_player_hit()
	_check("combo_hit_clears", sim.action_state.momentum == 0 and not sim.action_state.is_chain_open())
	# 4) 防反失误清空连势
	sim.action_state.momentum = 2
	sim.action_state.on_defense_miss()
	_check("combo_miss_clears", sim.action_state.momentum == 0)
	# 5) 终结开放：连招等级≥3 且卡带 finisher 标签 → FINISHER 层级
	var st = ActionStateCls.new()
	st.combo_level = 3
	st.current_pose = "low"
	st.combo_timer = 1.0
	var fin_action: Dictionary = ActionCat.ACTIONS["act_tianping"]
	var res: Dictionary = ComboSys.new().resolve(st, fin_action, true, ComboSys.FINISHER_LEVEL)
	_check("combo_finisher_gate", bool(res["finisher_available"]), str(res))
	# 连招等级不足时不开放（1 级顺势 +1 → 2 级，仍不到 3）
	st.combo_level = 1
	res = ComboSys.new().resolve(st, fin_action, true, ComboSys.FINISHER_LEVEL)
	_check("combo_finisher_gate_low", not bool(res["finisher_available"]), str(res["combo_level"]))
	# 6) 层级升级：连招≥3 → MEDIUM→HEAVY；连势≥2 再升一级 → BREAK
	var cs = ComboSys.new()
	_check("combo_impact_upgrade", String(cs.pick_impact_level("MEDIUM", 3, 0, false)) == "HEAVY",
		cs.pick_impact_level("MEDIUM", 3, 0, false))
	_check("combo_impact_upgrade_momentum", String(cs.pick_impact_level("MEDIUM", 3, 2, false)) == "BREAK",
		cs.pick_impact_level("MEDIUM", 3, 2, false))
	# 7) 蓝牌走 EnemyTimeline：延灯经标准接口改时间轴（命中点后移）
	var sim2 := BattleSimulationScript.new()
	sim2.restart()
	sim2.points = 9
	sim2.hand.clear()
	sim2.hand.append("yandeng")
	var dur_before: float = float(sim2.current_intent.duration)
	var strikes_before: Array = sim2.current_intent.get("strikes", []).duplicate()
	sim2.submit({"type": "play_card", "id": "yandeng"})
	var ok_delay: bool = absf(float(sim2.current_intent.duration) - dur_before - 0.4) < 0.001
	if not strikes_before.is_empty():
		ok_delay = ok_delay and absf(float(sim2.current_intent["strikes"][0]) - float(strikes_before[0]) - 0.4) < 0.001
	_check("combo_enemy_timeline_delay", ok_delay)
	# 8) 借刀经标准接口打断（守灯人免疫保持）
	var sim3 := BattleSimulationScript.new()
	sim3.restart()
	sim3.points = 9
	sim3.hand.clear()
	sim3.hand.append("jiedao")
	var evs3 := sim3.submit({"type": "play_card", "id": "jiedao"})
	var interrupted := false
	for ev in evs3:
		if String(ev.get("type", "")) == "action_interrupted":
			interrupted = true
	_check("combo_enemy_timeline_interrupt", interrupted and sim3.state == BattleSimulationScript.BattleState.RESOLVING)
	# 9) Boss 免疫：守灯人不可被借刀打断
	var sim4 := BattleSimulationScript.new()
	sim4.enemy_id = "lantern_keeper"
	sim4.restart()
	sim4.points = 9
	sim4.hand.clear()
	sim4.hand.append("jiedao")
	var evs4 := sim4.submit({"type": "play_card", "id": "jiedao"})
	var boss_interrupted := false
	for ev in evs4:
		if String(ev.get("type", "")) == "action_interrupted":
			boss_interrupted = true
	_check("combo_boss_interrupt_immune", not boss_interrupted and sim4.state == BattleSimulationScript.BattleState.WINDUP)


# ————————————————————— Effect 数值完整性 —————————————————————

func _check_effect_floats() -> void:
	# 凝滞类卡（0.2/0.25/0.35s）不允许被 int 截断成 0
	var sim := BattleSimulationScript.new()
	sim.restart()
	for cid in ["difan", "zhuangzhong", "guard", "fuhunsuo"]:
		sim.restart()
		sim.points = 9
		sim.hand.clear()
		sim.hand.append(cid)
		sim.submit({"type": "play_card", "id": cid})
		_check("effect_stagger_%s" % cid, sim.stagger_remaining > 0.0,
			"stagger=%.3f" % sim.stagger_remaining)
	# 延灯：命中点整体后移 0.4s
	var sim2 := BattleSimulationScript.new()
	sim2.restart()
	sim2.points = 9
	sim2.hand.clear()
	sim2.hand.append("yandeng")
	var dur_before: float = float(sim2.current_intent.duration)
	var strikes_before: Array = sim2.current_intent.get("strikes", []).duplicate()
	sim2.submit({"type": "play_card", "id": "yandeng"})
	var dur_after: float = float(sim2.current_intent.duration)
	var ok_delay: bool = absf(dur_after - dur_before - 0.4) < 0.001
	if not strikes_before.is_empty():
		ok_delay = ok_delay and absf(float(sim2.current_intent["strikes"][0]) - float(strikes_before[0]) - 0.4) < 0.001
	_check("effect_delay_impact", ok_delay, "dur %.2f→%.2f" % [dur_before, dur_after])


# ————————————————————— Boss 阶段顺序 —————————————————————

func _check_boss_phase_order() -> void:
	var sim := BattleSimulationScript.new()
	sim.enemy_id = "lantern_keeper"
	sim.restart()
	sim.enemy_hp = 5
	sim._sync_ai()
	_check("boss_phase_deep", sim.ai.current_phase() == 1, "phase=%d" % sim.ai.current_phase())


# ————————————————————— 全 Run Seed 确定性 —————————————————————

func _check_battle_seed_determinism() -> void:
	var hands := []
	for _i in 2:
		var sim := BattleSimulationScript.new()
		sim.run_mods = {"battle_seed": 777}
		sim.enemy_id = "gambler_ghost"
		sim.restart()
		hands.append(var_to_str([sim.hand, sim.draw_pile, sim.enemy_hp]))
	_check("battle_seed_determinism", hands[0] == hands[1], str(hands[0].length()))


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
	_check("boss_phase_moves", moves_pool.has("keeper_finale") and moves_pool.has("keeper_wick_snuff"), str(moves_pool))


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


# ————————————————————— 接线审计（防"数据定义了、代码没接"） —————————————————————

func _check_wiring_audit() -> void:
	# 规则层源码里必须真实出现每个遗物 mod 键 / 剧情旗标 / 特质的消费点
	var sim_src := FileAccess.open("res://scripts/battle/battle_simulation.gd", FileAccess.READ).get_as_text()
	var ai_src := FileAccess.open("res://scripts/battle/enemy_ai.gd", FileAccess.READ).get_as_text()
	var timeline_src := FileAccess.open("res://scripts/battle/enemy_timeline.gd", FileAccess.READ).get_as_text()
	var flow_src := FileAccess.open("res://scripts/app/run_flow.gd", FileAccess.READ).get_as_text()
	var combined := sim_src + "\n" + timeline_src + "\n" + flow_src
	var missing: Array[String] = []
	for rid in ContentCatalog.RELICS:
		for key in ContentCatalog.RELICS[rid]["mods"]:
			if not combined.contains(key):
				missing.append("relic:%s" % key)
	var flags := ["paper_face_done", "dice_rigged", "well_blessing", "mourner_song"]
	for flag in flags:
		if not sim_src.contains(flag):
			missing.append("flag:%s" % flag)
	var traits := ["paper_armor", "skittish", "heavy", "tempo", "dice", "vengeance", "pull"]
	for trait_id in traits:
		if not ai_src.contains("\"%s\"" % trait_id):
			missing.append("trait:%s" % trait_id)
	var diff_keys := ["enemy_hp_mul", "enemy_dmg_mul", "gold_mul", "start_hp_penalty"]
	for key in diff_keys:
		if not combined.contains(key):
			missing.append("diff:%s" % key)
	_check("wiring_audit", missing.is_empty(), "missing=%s" % str(missing))


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
