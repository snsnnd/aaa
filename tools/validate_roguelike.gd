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
	_check_action_permissions()
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
	sim.step(0.5)  # 命中帧结算
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
	sim2.step(0.5)  # 命中帧结算
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
	sim.step(0.5)  # 命中帧结算
	_check("trait_paper_armor", sim.enemy_hp == hp_before - 1, "armor reduces 5->min1")
	# 破甲后恢复
	sim.perfect_charge = false
	sim.ai.armor_broken = true
	sim.hand.append("attack")
	sim.points = 9
	hp_before = sim.enemy_hp
	sim.submit({"type": "play_card", "id": "attack"})
	sim.step(0.5)
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
	sim7.step(0.5)
	_check("flag_paper_face_done", sim7.enemy_hp == hp_before7 - 3, "dmg=%d" % (hp_before7 - sim7.enemy_hp))


# ————————————————————— 连招/动作层 —————————————————————

func _check_combo_system() -> void:
	var ComboSys: GDScript = preload("res://scripts/battle/combo_system.gd")
	var ActionStateCls: GDScript = preload("res://scripts/battle/action_state.gd")
	var ActionCatalogScript: GDScript = preload("res://scripts/battle/action_catalog.gd")
	# 1) 防反=连招起手：命中结算写入 parry_exit 且起手窗口打开
	var sim := BattleSimulationScript.new()
	sim.restart()
	sim.attack_elapsed = float(sim.current_intent.duration) - 0.20
	sim.submit({"type": "defend"})
	sim.step(0.21)  # 红刀命中（2.8）结算成功防范
	_check("combo_parry_opens", sim.action_state.current_pose == "parry_exit" and sim.action_state.is_chain_open(),
		"pose=%s timer=%.2f lvl=%d" % [sim.action_state.current_pose, sim.action_state.combo_timer, sim.action_state.combo_level])
	# 2) 完整链路：防反 → 起手 → 命中帧 → 取消衔接 → 预输入 → 受击反应 → 连势清空 → 继续
	var sim2 := BattleSimulationScript.new()
	sim2.deck_config = Array(["attack", "zhuying", "liebo", "shatter", "attack", "guard"], TYPE_STRING, "", null)
	sim2.restart()
	sim2.hand.clear()
	for cid in ["attack", "zhuying", "liebo", "shatter", "attack"]:
		sim2.hand.append(cid)
	sim2.points = 9
	# 2a) 真实防反：红刀命中结算 → 蓝起手（elapsed≈0.10）→ 防反起手窗口打开
	sim2.attack_elapsed = float(sim2.current_intent.duration) - 0.20
	sim2.submit({"type": "defend"})
	sim2.step(0.30)
	_check("chain_parry_opens", sim2.action_state.is_chain_open() and sim2.action_state.current_pose == "parry_exit",
		"pose=%s" % sim2.action_state.current_pose)
	var ev_a := sim2.submit({"type": "play_card", "id": "attack"})
	var started_a := false
	for ev in ev_a:
		if String(ev.get("type", "")) == "action_started":
			started_a = true
	_check("chain_startup_delayed", started_a and sim2.p_phase == BattleSimulationScript.PlayerActionPhase.STARTUP and sim2.enemy_hp == 46,
		"hp=%d(未结算) phase=%d" % [sim2.enemy_hp, sim2.p_phase])
	# 2b) 命中帧结算（seamless 把收招缩到 0.238——步长必须落在取消窗口内）
	var ev_b := sim2.step(0.23)
	var impact_b := false
	var reaction_b := ""
	for ev in ev_b:
		if String(ev.get("type", "")) == "action_impact":
			impact_b = true
			reaction_b = String(ev.get("level", ""))
	_check("chain_impact_frame", impact_b and reaction_b == "LIGHT" and sim2.enemy_hp == 41,
		"hp=%d level=%s" % [sim2.enemy_hp, reaction_b])
	# 2c) 取消窗口衔接：attack 收招中提交 zhuying
	var ev_c := sim2.submit({"type": "play_card", "id": "zhuying"})
	var canceled := false
	var seamless := false
	for ev in ev_c:
		if String(ev.get("type", "")) == "action_canceled":
			canceled = true
		if String(ev.get("type", "")) == "action_started" and String(ev.get("transition", "")) == "seamless":
			seamless = true
	_check("chain_cancel_link", canceled and seamless, "canceled=%s seamless=%s" % [canceled, seamless])
	sim2.step(0.20)  # zhuying 命中（0.20）
	_check("chain_link_damage", sim2.enemy_hp == 37, "hp=%d" % sim2.enemy_hp)
	# 2d) 预输入：liebo 前摇中提交 shatter → 缓冲，取消窗口开启时执行
	sim2.submit({"type": "play_card", "id": "liebo"})
	var buffered := false
	for ev in sim2.submit({"type": "play_card", "id": "shatter"}):
		if String(ev.get("type", "")) == "action_buffered":
			buffered = true
	_check("chain_preinput_buffer", buffered and sim2.p_queued == "shatter")
	# 2e) 缓冲在取消窗口开启瞬间执行；层级随连招升级（MEDIUM→HEAVY）
	var ev_e := sim2.step(0.24)
	var shatter_started := false
	var liebo_level := ""
	for ev in ev_e:
		if String(ev.get("type", "")) == "action_started" and String(ev.get("id", "")) == "shatter":
			shatter_started = true
		if String(ev.get("type", "")) == "action_impact" and String(ev.get("id", "")) == "liebo":
			liebo_level = String(ev.get("level", ""))
	_check("chain_buffer_executes", shatter_started and sim2.p_card == "shatter", "p_card=%s" % sim2.p_card)
	_check("chain_impact_upgrade", liebo_level == "BREAK", liebo_level)
	# 2f) 缓冲的 shatter 在命中帧结算（敌收招 0.62s 使蓝刀后移，链路自然落在蓝时间轴上）
	var ev_f := sim2.step(0.60)
	var shatter_impact := false
	for ev in ev_f:
		if String(ev.get("type", "")) == "action_impact" and String(ev.get("id", "")) == "shatter":
			shatter_impact = true
	_check("chain_continues_after_hit", shatter_impact and sim2.enemy_hp == 19, "hp=%d" % sim2.enemy_hp)
	# 2g) 蓝·变拍二连 0.82 命中 → 未防范 → 受击清空连势
	#     敌人残血（19<23）触发 ×1.15 强化：7 → 8 伤
	sim2.step(0.30)
	_check("chain_hit_clears_momentum", sim2.action_state.momentum == 0 and sim2.player_hp == 64,
		"momentum=%d hp=%d" % [sim2.action_state.momentum, sim2.player_hp])
	# 3) 防反失误清空连势
	sim2.action_state.momentum = 2
	sim2.action_state.on_defense_miss()
	_check("combo_miss_clears", sim2.action_state.momentum == 0)
	# 4) 终结门控（纯解析器）
	var st = ActionStateCls.new()
	st.combo_level = 3
	st.current_pose = "low"
	st.combo_timer = 1.0
	var fin_action: Dictionary = ActionCatalogScript.ACTIONS["act_tianping"]
	var res: Dictionary = ComboSys.new().resolve(st, fin_action, true, ComboSys.FINISHER_LEVEL)
	_check("combo_finisher_gate", bool(res["finisher_available"]), str(res))
	st.combo_level = 1
	res = ComboSys.new().resolve(st, fin_action, true, ComboSys.FINISHER_LEVEL)
	_check("combo_finisher_gate_low", not bool(res["finisher_available"]), str(res["combo_level"]))
	# 5) 层级升级
	var cs = ComboSys.new()
	_check("combo_impact_upgrade", String(cs.pick_impact_level("MEDIUM", 3, 0, false)) == "HEAVY",
		cs.pick_impact_level("MEDIUM", 3, 0, false))
	_check("combo_impact_upgrade_momentum", String(cs.pick_impact_level("MEDIUM", 3, 2, false)) == "BREAK",
		cs.pick_impact_level("MEDIUM", 3, 2, false))
	# 6) 蓝牌走 EnemyTimeline：延灯命中帧改写时间轴；借刀打断；Boss 免疫
	var sim3 := BattleSimulationScript.new()
	sim3.restart()
	sim3.points = 9
	sim3.hand.clear()
	sim3.hand.append("yandeng")
	var strikes_before: Array = sim3.current_intent.get("strikes", []).duplicate()
	var dur_before: float = float(sim3.current_intent.duration)
	sim3.submit({"type": "play_card", "id": "yandeng"})
	sim3.step(0.4)
	var ok_delay: bool = absf(float(sim3.current_intent.duration) - dur_before - 0.4) < 0.001
	if not strikes_before.is_empty():
		ok_delay = ok_delay and absf(float(sim3.current_intent["strikes"][0]) - float(strikes_before[0]) - 0.4) < 0.001
	_check("combo_enemy_timeline_delay", ok_delay)
	var sim4 := BattleSimulationScript.new()
	sim4.restart()
	sim4.points = 9
	sim4.hand.clear()
	sim4.hand.append("jiedao")
	var evs4 := sim4.submit({"type": "play_card", "id": "jiedao"})
	evs4.append_array(sim4.step(0.3))
	var interrupted := false
	for ev in evs4:
		if String(ev.get("type", "")) == "action_interrupted":
			interrupted = true
	_check("combo_enemy_timeline_interrupt", interrupted and sim4.state == BattleSimulationScript.BattleState.RESOLVING)
	var sim5 := BattleSimulationScript.new()
	sim5.enemy_id = "lantern_keeper"
	sim5.restart()
	sim5.points = 9
	sim5.hand.clear()
	sim5.hand.append("jiedao")
	var evs5 := sim5.submit({"type": "play_card", "id": "jiedao"})
	evs5.append_array(sim5.step(0.3))
	var boss_interrupted := false
	for ev in evs5:
		if String(ev.get("type", "")) == "action_interrupted":
			boss_interrupted = true
	_check("combo_boss_interrupt_immune", not boss_interrupted and sim5.state == BattleSimulationScript.BattleState.WINDUP)


# ————————————————————— 权限/中断/缓冲专项 —————————————————————

func _check_action_permissions() -> void:
	var ActionPerm: GDScript = preload("res://scripts/battle/action_permission.gd")
	var ActionCatalogScript: GDScript = preload("res://scripts/battle/action_catalog.gd")
	# A) Buffer 不早于 cancel start：极.天平倒悬 cancel_window=0 → 缓冲永不执行、显式丢弃
	var sim := BattleSimulationScript.new()
	sim.deck_config = Array(["tianping", "attack", "guard", "shift", "attack"], TYPE_STRING, "", null)
	sim.restart()
	sim.points = 9
	sim.hand.clear()
	for cid in ["tianping", "attack"]:
		sim.hand.append(cid)
	sim.submit({"type": "play_card", "id": "tianping"})   # 前摇 0.48 / 收招 0.60 / 窗口 0
	sim.submit({"type": "play_card", "id": "attack"})      # 前摇中提交 → 缓冲
	_check("perm_buffered", sim.p_queued == "attack")
	var ev_a := sim.step(0.70)  # 越过命中(0.48)与收招(0.60)
	ev_a.append_array(sim.step(0.10))  # 收招落账（取消窗口早已关闭）
	var tianping_impact := false
	var attack_started := false
	var dropped := false
	for ev in ev_a:
		if String(ev.get("type", "")) == "action_impact" and String(ev.get("id", "")) == "tianping":
			tianping_impact = true
		if String(ev.get("type", "")) == "action_started" and String(ev.get("id", "")) == "attack":
			attack_started = true
		if String(ev.get("type", "")) == "action_buffered_dropped":
			dropped = true
	_check("perm_zero_window_no_cancel", tianping_impact and not attack_started and dropped,
		"impact=%s attack=%s dropped=%s" % [tianping_impact, attack_started, dropped])
	_check("perm_zero_window_no_damage", sim.enemy_hp == 46 - 30, "hp=%d" % sim.enemy_hp)
	# B) cancel_window == 0 的动作不能在命中帧提前接下一张（无 action_canceled）
	var had_cancel := false
	for ev in ev_a:
		if String(ev.get("type", "")) == "action_canceled":
			had_cancel = true
	_check("perm_no_cancel_on_zero_window", not had_cancel)
	# C) parry_cancel = ANY（RULE 类）：出招中防反 → 立刻弃招转防反
	var sim2 := BattleSimulationScript.new()
	sim2.deck_config = Array(["jieshi", "attack", "guard", "shift", "attack"], TYPE_STRING, "", null)
	sim2.restart()
	sim2.points = 9
	sim2.hand.clear()
	for cid in ["jieshi", "attack"]:
		sim2.hand.append(cid)
	sim2.submit({"type": "play_card", "id": "jieshi"})   # RULE → ANY
	sim2.attack_elapsed = float(sim2.current_intent.duration) - 0.10
	var ev_c := sim2.submit({"type": "defend"})
	var canceled_by_parry := false
	for ev in ev_c:
		if String(ev.get("type", "")) == "action_canceled" and String(ev.get("by", "")) == "parry":
			canceled_by_parry = true
	_check("perm_parry_cancel_any", canceled_by_parry and sim2.p_phase == BattleSimulationScript.PlayerActionPhase.IDLE,
		"canceled=%s phase=%d" % [canceled_by_parry, sim2.p_phase])
	# D) parry_cancel = NONE（还刃）：出招中防反不弃招
	var sim3 := BattleSimulationScript.new()
	sim3.deck_config = Array(["shatter", "attack", "guard", "shift", "attack"], TYPE_STRING, "", null)
	sim3.restart()
	sim3.points = 9
	sim3.hand.clear()
	for cid in ["shatter", "attack"]:
		sim3.hand.append(cid)
	sim3.submit({"type": "play_card", "id": "shatter"})
	sim3.attack_elapsed = float(sim3.current_intent.duration) - 0.10
	var ev_d := sim3.submit({"type": "defend"})
	var shatter_canceled := false
	for ev in ev_d:
		if String(ev.get("type", "")) == "action_canceled":
			shatter_canceled = true
	_check("perm_parry_cancel_none", not shatter_canceled and sim3.p_phase != BattleSimulationScript.PlayerActionPhase.IDLE,
		"canceled=%s" % shatter_canceled)
	# E) NORMAL 动作被击中后不能继续命中：蓝刀先于攻击命中帧落地 → 动作取消、无伤害
	var sim4 := BattleSimulationScript.new()
	sim4.deck_config = Array(["attack", "attack", "guard", "shift", "shatter"], TYPE_STRING, "", null)
	sim4.restart()
	sim4.attack_index = 1
	sim4._begin_attack()  # 蓝·变拍二连，首段 0.82
	sim4.points = 9
	sim4.hand.clear()
	for cid in ["attack", "attack"]:
		sim4.hand.append(cid)
	sim4.attack_elapsed = 0.80
	var ev_e := sim4.submit({"type": "play_card", "id": "attack"})  # 命中帧 0.22 → 蓝 1.02
	ev_e.append_array(sim4.step(0.05))  # 蓝 0.82 先落地
	var attack_impacted := false
	var canceled_by_hit := false
	for ev in ev_e:
		if String(ev.get("type", "")) == "action_impact" and String(ev.get("id", "")) == "attack":
			attack_impacted = true
		if String(ev.get("type", "")) == "action_canceled" and String(ev.get("by", "")) == "hit":
			canceled_by_hit = true
	_check("perm_hit_interrupts_normal", canceled_by_hit and not attack_impacted and sim4.enemy_hp == 46,
		"hit_interrupt=%s impacted=%s hp=%d" % [canceled_by_hit, attack_impacted, sim4.enemy_hp])
	# F) ARMOR：极.天平倒悬被击中仍继续结算
	var sim5 := BattleSimulationScript.new()
	sim5.deck_config = Array(["tianping", "attack", "guard", "shift", "attack"], TYPE_STRING, "", null)
	sim5.restart()
	sim5.attack_index = 1
	sim5._begin_attack()
	sim5.points = 9
	sim5.hand.clear()
	for cid in ["tianping", "attack"]:
		sim5.hand.append(cid)
	sim5.attack_elapsed = 0.80
	sim5.submit({"type": "play_card", "id": "tianping"})  # 命中帧 0.48 → 蓝 1.28
	var took_damage := false
	var tianping_impacted := false
	var was_interrupted := false
	var evs_f := sim5.submit({"type": "play_card", "id": "attack"})  # 缓冲
	evs_f.append_array(sim5.step(0.55))  # 蓝 0.82 命中玩家（霸体不中断）+ 天平命中帧 1.28
	evs_f.append_array(sim5.step(0.10))  # 收招落账
	for ev in evs_f:
		if String(ev.get("type", "")) == "impact":
			took_damage = true
		if String(ev.get("type", "")) == "action_canceled" and String(ev.get("by", "")) == "hit":
			was_interrupted = true
		if String(ev.get("type", "")) == "action_impact" and String(ev.get("id", "")) == "tianping":
			tianping_impacted = true
	# 霸体：吃了伤害、动作未被中断、命中帧照常结算
	_check("perm_armor_continues", took_damage and not was_interrupted and tianping_impacted and sim5.enemy_hp == 16,
		"damage=%s interrupted=%s impacted=%s hp=%d" % [took_damage, was_interrupted, tianping_impacted, sim5.enemy_hp])
	# G) Seamless 确实比普通连接更快：recovery_mul 实际缩放时间轴
	var sim6 := BattleSimulationScript.new()
	sim6.restart()
	var base_recovery := float(ActionCatalogScript.ACTIONS["act_attack"]["recovery"])
	sim6.points = 9
	sim6.hand.clear()
	sim6.hand.append("attack")
	sim6.submit({"type": "play_card", "id": "attack"})  # open：mul 1.0
	_check("perm_open_recovery_base", absf(float(sim6.p_action["recovery"]) - base_recovery) < 0.001,
		"recovery=%.3f" % float(sim6.p_action["recovery"]))
	sim6.action_state.current_pose = "parry_exit"
	sim6.action_state.combo_level = 1
	sim6.action_state.combo_timer = 1.0
	sim6.hand.append("attack")
	sim6.points = 9
	sim6.submit({"type": "play_card", "id": "attack"})  # parry_exit→low seamless：mul 0.85
	_check("perm_seamless_faster", float(sim6.p_action["recovery"]) < base_recovery,
		"recovery=%.3f < %.3f" % [float(sim6.p_action["recovery"]), base_recovery])
	# H) Queued action 不会无故丢失：缓冲恰好执行一次
	var sim7 := BattleSimulationScript.new()
	sim7.deck_config = Array(["attack", "zhuying", "guard", "shift", "attack"], TYPE_STRING, "", null)
	sim7.restart()
	sim7.points = 9
	sim7.hand.clear()
	for cid in ["attack", "zhuying"]:
		sim7.hand.append(cid)
	sim7.submit({"type": "play_card", "id": "attack"})
	sim7.submit({"type": "play_card", "id": "zhuying"})  # 前摇中缓冲
	var started_count := 0
	var impact_count := 0
	var evs_h := sim7.step(0.30)  # 攻击命中帧 0.22 → 缓冲的 zhuying 在取消窗口执行
	for ev in evs_h:
		if String(ev.get("type", "")) == "action_started" and String(ev.get("id", "")) == "zhuying":
			started_count += 1
		if String(ev.get("type", "")) == "action_impact" and String(ev.get("id", "")) == "zhuying":
			impact_count += 1
	_check("perm_queue_executes_once", started_count == 1 and sim7.p_card == "zhuying",
		"started=%d p_card=%s" % [started_count, sim7.p_card])
	sim7.step(0.4)
	_check("perm_queue_impact_once", impact_count == 1 and sim7.enemy_hp == 46 - 5 - 4, "hp=%d" % sim7.enemy_hp)


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
		sim.hand.clear()
		sim.hand.append(cid)
		var evs_st := sim.submit({"type": "play_card", "id": cid})
		evs_st.append_array(sim.step(0.27))  # 命中帧结算（凝滞在命中帧施加）
		var got_stagger := ""
		for ev in evs_st:
			if String(ev.get("type", "")) == "stagger":
				got_stagger = "%.3f" % float(ev.get("duration", 0.0))
		_check("effect_stagger_%s" % cid, got_stagger != "", got_stagger)
	# 延灯：命中点整体后移 0.4s
	var sim2 := BattleSimulationScript.new()
	sim2.restart()
	sim2.points = 9
	sim2.hand.clear()
	sim2.hand.append("yandeng")
	var dur_before: float = float(sim2.current_intent.duration)
	var strikes_before: Array = sim2.current_intent.get("strikes", []).duplicate()
	sim2.submit({"type": "play_card", "id": "yandeng"})
	sim2.step(0.4)  # 命中帧结算（延灯在命中帧改写时间轴）
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
		for ev in sim.step(0.5):  # 命中帧结算
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
	events.append_array(sim.step(0.4))  # 命中帧结算
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
