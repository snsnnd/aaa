extends Node

## RunFlow（瘦身版）：只负责状态机与屏幕编排。
## 局状态在 RunState，界面在 screens/，规则在 battle/，持久化在 SaveManager，
## 时间在 GameTime，键位/辅助在 GameSettings，数据闭环在 Telemetry。

enum State { MENU, MAP, BATTLE, REWARD, REST, EVENT, SHOP, GAME_OVER }

const TRANSITIONS := {
	State.MENU: [State.MENU, State.MAP, State.BATTLE, State.REST, State.EVENT, State.SHOP],
	State.MAP: [State.MAP, State.BATTLE, State.REST, State.EVENT, State.SHOP, State.GAME_OVER],
	State.BATTLE: [State.REWARD, State.GAME_OVER, State.MAP, State.MENU],
	State.REWARD: [State.MAP],
	State.REST: [State.MAP],
	State.EVENT: [State.MAP],
	State.SHOP: [State.MAP],
	State.GAME_OVER: [State.MENU, State.MAP],
}

const BattleScene := preload("res://scenes/main.tscn")
const BattleSimulationScript := preload("res://scripts/battle/battle_simulation.gd")
const CardSystemScript := preload("res://scripts/battle/card_system.gd")
const RunStateScript := preload("res://scripts/app/run_state.gd")
const SaveManagerScript := preload("res://scripts/app/save_manager.gd")
const MenuScreen := preload("res://scripts/app/screens/menu_screen.gd")
const MapScreen := preload("res://scripts/app/screens/map_screen.gd")
const RewardScreen := preload("res://scripts/app/screens/reward_screen.gd")
const RestScreen := preload("res://scripts/app/screens/rest_screen.gd")
const EventScreen := preload("res://scripts/app/screens/event_screen.gd")
const ShopScreen := preload("res://scripts/app/screens/shop_screen.gd")
const OverScreen := preload("res://scripts/app/screens/over_screen.gd")
const SettingsScreen := preload("res://scripts/app/screens/settings_screen.gd")
const PickOverlay := preload("res://scripts/app/screens/pick_overlay.gd")
const MapGenScript := preload("res://scripts/app/map_generator.gd")

var state: State = State.MENU
var run: RunStateScript
var battle: Node
var last_victory := false
var pending_gold := 0
var _pending_event_id := ""
var _remove_after_pick := false

# playtest
var playtest := "--playtest" in OS.get_cmdline_user_args()
var ai_strategy := {}
var _beat := 0
var playtest_runs := 0

# demo（旧日试炼）
var demo_mode := false

var menu_screen: MenuScreen
var map_screen: MapScreen
var reward_screen: RewardScreen
var rest_screen: RestScreen
var event_screen: EventScreen
var shop_screen: ShopScreen
var over_screen: OverScreen
var settings_screen: SettingsScreen
var pick_overlay: PickOverlay


func _ready() -> void:
	Telemetry.enabled = not playtest
	menu_screen = MenuScreen.new(); add_child(menu_screen)
	map_screen = MapScreen.new(); add_child(map_screen)
	reward_screen = RewardScreen.new(); add_child(reward_screen)
	rest_screen = RestScreen.new(); add_child(rest_screen)
	event_screen = EventScreen.new(); add_child(event_screen)
	shop_screen = ShopScreen.new(); add_child(shop_screen)
	over_screen = OverScreen.new(); add_child(over_screen)
	settings_screen = SettingsScreen.new(); add_child(settings_screen)
	pick_overlay = PickOverlay.new(); add_child(pick_overlay)
	_wire_screens()
	menu_screen.refresh()
	if playtest:
		_load_strategy()
		print("[PLAYTEST] 开始自动游玩：策略=%s" % str(ai_strategy))
		GameTime.base_scale = 4.0
		_start_new_run(0, 0)
	else:
		_enter(State.MENU)


func _wire_screens() -> void:
	menu_screen.start_new.connect(_start_new_run)
	menu_screen.continue_run.connect(_continue_run)
	menu_screen.open_settings.connect(func(): settings_screen.open())
	menu_screen.start_demo.connect(_start_demo)
	settings_screen.closed.connect(func(): menu_screen.refresh())
	map_screen.node_picked.connect(_on_node_picked)
	reward_screen.card_picked.connect(_on_reward_picked)
	reward_screen.skipped.connect(_on_reward_skipped)
	rest_screen.rest_choice.connect(_on_rest_choice)
	event_screen.choice_made.connect(_on_event_choice)
	shop_screen.bought.connect(_on_shop_buy)
	shop_screen.left_shop.connect(_leave_shop)
	pick_overlay.picked.connect(_on_pick_done)
	pick_overlay.cancelled.connect(func(): _remove_after_pick = false)


func _can_enter(to: State) -> bool:
	return to in TRANSITIONS[state]


func _enter(to: State) -> void:
	assert(_can_enter(to), "非法状态转移 %s -> %s" % [State.keys()[state], State.keys()[to]])
	state = to
	menu_screen.visible = to == State.MENU
	map_screen.visible = to == State.MAP
	reward_screen.visible = to == State.REWARD
	rest_screen.visible = to == State.REST
	event_screen.visible = to == State.EVENT
	shop_screen.visible = to == State.SHOP
	over_screen.visible = to == State.GAME_OVER
	match to:
		State.MENU:
			menu_screen.refresh()
		State.MAP:
			_show_map()
		State.BATTLE:
			_show_battle()
		State.REWARD:
			_show_reward()
		State.REST:
			rest_screen.show_rest(run.hp, run.max_hp)
		State.EVENT:
			_show_event()
		State.SHOP:
			_show_shop()
		State.GAME_OVER:
			_show_over()


# ————————————————————— Run 生命周期 —————————————————————

func _start_new_run(difficulty: int, seed_value: int) -> void:
	run = RunStateScript.new(seed_value, difficulty)
	run.setup_new_run()
	var mods := run.mods()
	if mods.has("start_hp_penalty"):
		run.hp -= int(mods["start_hp_penalty"])
	Telemetry.start_run(run.seed_value, difficulty)
	if not playtest:
		var meta: Dictionary = SaveManagerScript.load_meta()
		meta["runs_total"] = int(meta.get("runs_total", 0)) + 1
		SaveManagerScript.save_meta(meta)
	_enter(State.MAP)


func _continue_run() -> void:
	var data: Dictionary = SaveManagerScript.load_run()
	if data.is_empty():
		return
	run = RunStateScript.new()
	run.from_dict(data)
	Telemetry.start_run(run.seed_value, run.difficulty)
	# 断点续战：未完成的节点不允许借"退出重进"跳过
	match String(run.node_state):
		"in_progress":
			match String(run.current_node.get("type", "battle")):
				"battle", "elite", "boss":
					_enter(State.BATTLE)
				"rest":
					_enter(State.REST)
				"event":
					_enter(State.EVENT)
				"shop":
					_enter(State.SHOP)
				_:
					_enter(State.MAP)
		_:
			_enter(State.MAP)


func _save_run() -> void:
	if run:
		SaveManagerScript.save_run(run)


func _show_map() -> void:
	var map_gen: MapGenScript = MapGenScript.new()
	var options: Array = []
	if run.node_row == 0 and run.node_col == 0 and run.current_node.is_empty():
		# 开局：入口节点
		var rows: Array = run.map.get("rows", [])
		for c in rows[0].size():
			options.append({"row": 0, "col": c, "node": rows[0][c]})
	else:
		options = map_gen.next_options(run.map, run.node_row, run.node_col)
	map_screen.show_map(run.map, run.node_row, run.node_col, options, run.hp, run.max_hp, run.gold)


func _on_node_picked(row: int, col: int) -> void:
	var node: Dictionary = run.map["rows"][row][col]
	run.current_node = node
	run.node_row = row
	run.node_col = col
	run.node_state = "in_progress"
	Telemetry.record_node(String(node.get("type", "battle")), String(node.get("enemy", "")), row)
	match String(node.get("type", "battle")):
		"battle", "elite", "boss":
			_enter(State.BATTLE)
		"rest":
			_enter(State.REST)
		"event":
			_enter(State.EVENT)
		"shop":
			_enter(State.SHOP)
		"treasure":
			_grant_treasure()
		_:
			_enter(State.BATTLE)


func _grant_treasure() -> void:
	run.node_state = "done"
	var rng_gen := run.rng()
	if run.relics.size() < 4 and rng_gen.randf() < 0.6:
		var all_relics: Array[String] = []
		for rid in ["old_rope", "chime", "ink_brush", "nail", "well_water", "funeral_bell", "red_thread", "silver_coin", "paper_lantern", "wisp_follower"]:
			if not run.relics.has(rid):
				all_relics.append(rid)
		if not all_relics.is_empty():
			var relic_id: String = all_relics[rng_gen.randi_range(0, all_relics.size() - 1)]
			run.relics.append(relic_id)
			if relic_id == "paper_lantern":
				run.max_hp += 12
				run.hp += 12
		else:
			run.gold += 40
	else:
		run.gold += 30 + rng_gen.randi_range(0, 20)
	_save_run()
	_enter(State.MAP)


# ————————————————————— 战斗 —————————————————————

func _show_battle() -> void:
	_hide_all()
	battle = BattleScene.instantiate()
	add_child(battle)
	var node_type := String(run.current_node.get("type", "battle"))
	var enemy_id := String(run.current_node.get("enemy", "watchman"))
	# 精英战：血量与伤害小幅上探
	var mods := run.mods()
	if node_type == "elite":
		mods["enemy_hp_mul"] = float(mods.get("enemy_hp_mul", 1.0)) * 1.25
		mods["enemy_dmg_mul"] = float(mods.get("enemy_dmg_mul", 1.0)) * 1.1
	mods["reaction_assist"] = GameSettings.reaction_assist
	mods["flags"] = run.flags
	# 全 Run 确定性：战斗 RNG 由 Run 种子 + 节点位置派生
	mods["battle_seed"] = hash([run.seed_value, run.node_row, run.node_col])
	battle.apply_run_config(enemy_id, run.deck, run.hp, mods)
	for ev: Dictionary in battle.sim.drain_begin_events():
		battle._handle_event(ev)
	_save_run()


func _hide_all() -> void:
	menu_screen.visible = false
	map_screen.visible = false
	reward_screen.visible = false
	rest_screen.visible = false
	event_screen.visible = false
	shop_screen.visible = false
	over_screen.visible = false


func _finish_battle(victory: bool) -> void:
	last_victory = victory
	var s = battle.sim
	if playtest:
		print("[PLAYTEST] 节点=%s(%s) 敌=%s 结果=%s 灯油=%d/%d 完美x%d 历经%d招 敌余血=%d" % [
			String(run.current_node.get("type", "battle")), run.node_row, s.enemy_name, "胜" if victory else "负",
			s.player_hp, s.player_max_hp, s.perfects, s.attack_index + 1, maxi(0, s.enemy_hp)])
	Telemetry.record_battle(String(run.current_node.get("enemy", "")), victory, s.player_hp, s.attack_index + 1, s.stats)
	if victory:
		run.hp = mini(run.max_hp, s.player_hp + int(s.run_mods.get("heal_after_battle", 0)))
		# 长明等卡在战斗中提升的灯油上限，战后在 Run 层固化
		var gained := int(s.stats.get("max_hp_gained", 0))
		if gained > 0:
			run.max_hp += gained
		run.battle_count += 1
		var node_type := String(run.current_node.get("type", "battle"))
		var battle_mods := run.mods()
		var base_gold := 12 + (run.node_row * 2) + run.rng().randi_range(0, 8)
		if node_type == "elite":
			base_gold = int(float(base_gold) * 1.5)
		pending_gold = int(round(float(base_gold) * float(battle_mods.get("gold_mul", 1.0)))) + int(battle_mods.get("gold_bonus", 0))
		run.gold += pending_gold
	else:
		run.hp = s.player_hp
	_free_battle()
	if not victory:
		_end_run(false)
	elif String(run.current_node.get("type", "")) == "boss":
		last_victory = true
		_end_run(true)
	else:
		_enter(State.REWARD)


func _free_battle() -> void:
	if battle:
		battle.queue_free()
		battle = null


# ————————————————————— 奖励 / 歇脚 / 事件 / 鬼市 —————————————————————

func _show_reward() -> void:
	var rng_gen := run.rng()
	var pool: Array[String] = []
	for cid in BattleSimulationScript.CARD_DATA:
		pool.append(String(cid))
	var options: Array[String] = []
	for want_class in ["御", "斩", ""]:
		var filtered := pool.filter(func(cid: String): return CardSystemScript.class_of(cid) == want_class and not options.has(cid))
		if filtered.is_empty():
			filtered = pool.filter(func(cid: String): return not options.has(cid))
		options.append(filtered[rng_gen.randi_range(0, filtered.size() - 1)])
	reward_screen.show_reward(options, pending_gold, run.gold)


func _on_reward_picked(index: int) -> void:
	if state != State.REWARD:
		return
	var picked := CardSystemScript.display_id(reward_screen.options[index])
	run.add_card(picked)
	Telemetry.record_draft(picked, reward_screen.options, true)
	_after_node()


func _on_reward_skipped() -> void:
	if state != State.REWARD:
		return
	Telemetry.record_draft("", reward_screen.options, false)
	_after_node()


func _after_node() -> void:
	run.node_state = "done"
	_save_run()
	_enter(State.MAP)


func _on_rest_choice(kind: String, payload: String) -> void:
	if state != State.REST:
		return
	if kind == "heal":
		run.heal(int(ceil(float(run.max_hp) * 0.3)))
	elif kind == "upgrade" and payload != "":
		run.upgrade_card(payload)
	_save_run()
	_enter(State.MAP)


func _show_event() -> void:
	# 事件 id 持久化：断线重进时看到的是同一个事件，不存在"刷事件"漏洞
	_pending_event_id = String(run.current_node.get("event_id", ""))
	if _pending_event_id == "":
		_pending_event_id = _pick_event()
		run.current_node["event_id"] = _pending_event_id
		_save_run()
	var ev: Dictionary = BattleSimulationScript.ContentCatalog.EVENTS.get(_pending_event_id, {})
	event_screen.show_event(_pending_event_id, ev)


func _pick_event() -> String:
	var rng_gen := run.rng()
	var keys := BattleSimulationScript.ContentCatalog.EVENTS.keys()
	return String(keys[rng_gen.randi_range(0, keys.size() - 1)])


func _on_event_choice(event_id: String, choice: int) -> void:
	if state != State.EVENT:
		return
	Telemetry.record_event(event_id, choice)
	var ev: Dictionary = BattleSimulationScript.ContentCatalog.EVENTS.get(event_id, {})
	var choices: Array = ev.get("choices", [])
	if choice < choices.size():
		_apply_event_effects(choices[choice])
	_save_run()
	_enter(State.MAP)


func _apply_event_effects(choice: Dictionary) -> void:
	for key in choice.get("flags", {}):
		run.flags[key] = choice["flags"][key]
	for eff: Dictionary in choice.get("effects", []):
		match String(eff.get("type", "")):
			"heal":
				run.heal(int(eff.get("amount", 0)))
			"heal_pct":
				run.heal(int(ceil(float(run.max_hp) * float(eff.get("pct", 0)) / 100.0)))
			"gold":
				run.gold = maxi(0, run.gold + int(eff.get("amount", 0)))
			"damage":
				run.hp = maxi(1, run.hp - int(eff.get("amount", 0)))
			"grant_card":
				var got := run.random_card_of_class(run.rng(), String(eff.get("class", "")))
				run.add_card(got)
			"grant_relic":
				var rid := String(eff.get("id", ""))
				if not run.relics.has(rid):
					run.relics.append(rid)
					if rid == "paper_lantern":
						run.max_hp += 12
						run.hp += 12
			"remove_card":
				_remove_after_pick = true
				pick_overlay.open(run.deck, "选一张符牌，随游魂入灯超度")
			"upgrade_card":
				pick_overlay.open(run.upgradable_cards(), "选一张符牌，补完它")
			"gamble":
				if run.rng().randf() < 0.5:
					_apply_event_effects({"effects": [eff["win"]]})
				else:
					_apply_event_effects({"effects": [eff["lose"]]})


func _on_pick_done(slot: String) -> void:
	if _remove_after_pick:
		run.remove_card(slot)
		_remove_after_pick = false
	else:
		run.upgrade_card(slot)
	_save_run()


func _show_shop() -> void:
	run.shop_visited = true
	var rng_gen := run.rng()
	var cards: Array[String] = [run.random_card_of_class(rng_gen), run.random_card_of_class(rng_gen)]
	var relics: Array[String] = []
	for rid in ["old_rope", "chime", "ink_brush", "nail", "well_water", "funeral_bell", "red_thread", "silver_coin"]:
		if not run.relics.has(rid):
			relics.append(rid)
	var relic := relics[rng_gen.randi_range(0, relics.size() - 1)] if not relics.is_empty() else ""
	shop_screen.show_shop(run.gold, cards, relic, run.relics)


func _on_shop_buy(item: String, payload: String) -> void:
	if state != State.SHOP:
		return
	match item:
		"card":
			if run.gold >= shop_screen.prices["card"]:
				run.gold -= shop_screen.prices["card"]
				run.add_card(payload)
		"relic":
			if run.gold >= shop_screen.prices["relic"] and not run.relics.has(payload):
				run.gold -= shop_screen.prices["relic"]
				run.relics.append(payload)
				if payload == "paper_lantern":
					run.max_hp += 12
					run.hp += 12
		"remove":
			if run.gold >= shop_screen.prices["remove"]:
				run.gold -= shop_screen.prices["remove"]
				pick_overlay.open(run.deck, "焚符：选一张要烧掉的符牌")
				return
		"heal":
			if run.gold >= shop_screen.prices["heal"]:
				run.gold -= shop_screen.prices["heal"]
				run.heal(20)
	shop_screen.show_shop(run.gold, shop_screen.stock_cards, shop_screen.stock_relic, run.relics)
	_save_run()


func _leave_shop() -> void:
	if state != State.SHOP:
		return
	_after_node()


# ————————————————————— 结算 —————————————————————

func _end_run(victory: bool) -> void:
	Telemetry.end_run("victory" if victory else "death", _node_label(), run.deck, victory)
	if not playtest:
		var meta: Dictionary = SaveManagerScript.load_meta()
		if victory:
			meta["wins"] = int(meta.get("wins", 0)) + 1
			if run.difficulty + 1 > int(meta.get("difficulty_unlocked", 0)) and run.difficulty + 1 < BattleSimulationScript.ContentCatalog.DIFFICULTIES.size():
				meta["difficulty_unlocked"] = run.difficulty + 1
		meta["best_act_row"] = maxi(int(meta.get("best_act_row", 0)), run.node_row)
		SaveManagerScript.save_meta(meta)
		SaveManagerScript.clear_run()
	over_screen.show_over(victory, _node_label(), run.battle_count, run.deck.size(), false)
	_enter(State.GAME_OVER)


func _node_label() -> String:
	return "%d/%d" % [run.node_row + 1, run.map.get("rows", []).size()]


func abandon_run() -> void:
	## 战斗暂停菜单选择"离开夜巡"：保留存档，回标题。
	if run:
		Telemetry.end_run("abandon", _node_label(), run.deck, false)
		_save_run()
	_free_battle()
	GameTime.reset()
	_enter(State.MENU)


# ————————————————————— 主循环 / playtest —————————————————————

func _process(_delta: float) -> void:
	if playtest:
		GameTime.base_scale = 4.0
		if state == State.MAP:
			# 自动选：优先 歇脚 > 事件 > 战斗
			var options := _current_map_options()
			var pick: Dictionary = options[0]
			for opt in options:
				if String(opt["node"].get("type", "")) in ["rest", "event"]:
					pick = opt
					break
			_on_node_picked(int(pick["row"]), int(pick["col"]))
		elif state == State.REWARD:
			_on_reward_picked(0)
		elif state == State.EVENT:
			_on_event_choice(_pending_event_id, 0)
			# pick_overlay（删牌/升级）若开着，选第一张
		elif state == State.REST:
			_on_rest_choice("heal", "")
		elif state == State.SHOP:
			_leave_shop()
	if pick_overlay.visible and playtest and run:
		pick_overlay.visible = false
		pick_overlay.picked.emit(String(run.deck[0]))
	if playtest and state == State.BATTLE:
		_bot_tick()
	if state != State.BATTLE or battle == null:
		return
	var sim_state: int = battle.sim.state
	if sim_state == BattleSimulationScript.BattleState.VICTORY:
		_finish_battle(true)
	elif sim_state == BattleSimulationScript.BattleState.DEFEAT:
		_finish_battle(false)


func _current_map_options() -> Array:
	var map_gen: MapGenScript = MapGenScript.new()
	if run.node_row == 0 and run.node_col == 0 and run.current_node.is_empty():
		var rows: Array = run.map.get("rows", [])
		var out: Array = []
		for c in rows[0].size():
			out.append({"row": 0, "col": c, "node": rows[0][c]})
		return out
	return map_gen.next_options(run.map, run.node_row, run.node_col)


func _show_over() -> void:
	if playtest:
		playtest_runs += 1
		print("[PLAYTEST] ===第 %d 次尝试结束：%s｜牌组=%s===" % [playtest_runs, "天明" if last_victory else "灯灭", str(run.deck)])
		if playtest_runs < 6 and not last_victory:
			_start_new_run(0, 0)
			return
		print("[PLAYTEST] 全局结束：%s" % ["通关" if last_victory else "未能通关"])
		get_tree().quit(0)
		return
	over_screen.visible = true


func _input(event: InputEvent) -> void:
	if demo_mode and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_end_demo()
		get_viewport().set_input_as_handled()


func _load_strategy() -> void:
	ai_strategy.clear()
	var path := "res://playtest_strategy.txt"
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		for line in f.get_as_text().split("\n"):
			if "=" in line:
				var kv := line.split("=", true, 1)
				ai_strategy[kv[0].strip_edges()] = kv[1].strip_edges()


func _strat(key: String, fallback: String) -> String:
	return String(ai_strategy.get(key, fallback))


func _bot_tick() -> void:
	if battle == null:
		return
	_bot_play_cards()
	var s = battle.sim
	if s.state != BattleSimulationScript.BattleState.WINDUP:
		return
	var unblockable: bool = bool(s.current_intent.get("unblockable", false))
	if unblockable:
		if s.fake_released and s.points >= 2:
			if s.hand.has("anhun"):
				battle._submit({"type": "play_card", "id": "anhun"})
			elif s.hand.has("guard"):
				battle._submit({"type": "play_card", "id": "guard"})
		return
	if s.queued_defense == 0 and s.defense_cooldown <= 0.0:
		var tt: float = s._current_impact_time() - s.attack_elapsed
		var perfect_at := float(_strat("perfect_at", "0.06"))
		if _strat("perfect_target", "true") == "true":
			if tt <= perfect_at and tt > -float(_strat("grace", "0.05")):
				battle._submit({"type": "defend"})
		elif tt <= float(s.current_intent.window) * 0.75 and tt > 0.02:
			battle._submit({"type": "defend"})


func _bot_play_cards() -> void:
	if battle == null:
		return
	var s = battle.sim
	if s.state == BattleSimulationScript.BattleState.VICTORY or s.state == BattleSimulationScript.BattleState.DEFEAT:
		return
	var enemy_pool_has_unblockable := false
	for mid in BattleSimulationScript.ENEMIES[s.enemy_id].moves:
		if bool(BattleSimulationScript.MOVES[String(mid)].get("unblockable", false)):
			enemy_pool_has_unblockable = true
	var reserve := (1 if s.hand.has("anhun") else int(_strat("reserve", "2"))) if enemy_pool_has_unblockable else int(_strat("reserve_calm", "0"))
	var want_shatter: bool = s.hand.has("shatter") and s.points >= int(_strat("shatter_at", "3")) + reserve
	if _strat("shatter_only_charged", "false") == "true" and not s.perfect_charge:
		want_shatter = false
	if want_shatter:
		battle._submit({"type": "play_card", "id": "shatter"})
	elif s.player_hp <= int(_strat("heal_below", "30")) and s.points >= 2 + reserve and s.hand.has("shift"):
		battle._submit({"type": "play_card", "id": "shift"})
	elif s.points >= BattleSimulationScript.SUMMON_COST - (1 if s.perfect_charge else 0) + reserve and s.draw_pile.size() + s.discard_pile.size() > 0 \
			and not (s.hand.has("attack") or s.hand.has("shatter") or s.hand.has("zhuangzhong")):
		battle._submit({"type": "summon"})
	elif s.enemy_hp <= 12 and s.points >= 1 and s.hand.has("attack"):
		battle._submit({"type": "play_card", "id": "attack"})
	elif s.points >= int(_strat("attack_at", "1")) + reserve and s.hand.has("attack"):
		battle._submit({"type": "play_card", "id": "attack"})
	elif s.points >= 2 and s.hand.has("zhuangzhong"):
		battle._submit({"type": "play_card", "id": "zhuangzhong"})


# ————————————————————— 旧日试炼（demo） —————————————————————

func _start_demo() -> void:
	_hide_all()
	menu_screen.visible = false
	demo_mode = true
	battle = BattleScene.instantiate()
	add_child(battle)
	battle.sim.initial_hp = BattleSimulationScript.PLAYER_MAX_HP
	battle.sim.restart()


func _end_demo() -> void:
	demo_mode = false
	_free_battle()
	GameTime.reset()
	_enter(State.MENU)
