extends Node

## 正式版骨架：RunFlow 状态机驱动 标题→夜巡（战斗/事件/篝火）→奖励→结算。

enum State { MENU, BATTLE, REWARD, REST, EVENT, GAME_OVER }

const TRANSITIONS := {
	State.MENU: [State.MENU, State.BATTLE],
	State.BATTLE: [State.REWARD, State.REST, State.EVENT, State.GAME_OVER],
	State.REWARD: [State.BATTLE, State.REST, State.EVENT],
	State.REST: [State.BATTLE, State.EVENT, State.REST],
	State.EVENT: [State.BATTLE, State.REST, State.EVENT],
	State.GAME_OVER: [State.MENU],
}

const BattleScene := preload("res://scenes/main.tscn")
const BattleSimulationScript := preload("res://scripts/battle/battle_simulation.gd")
const PresentationCatalog := preload("res://scripts/presentation/presentation_catalog.gd")
const BASE_DECK := ["attack", "attack", "shatter", "guard", "shift"]
const DRAFT_POOL := [
	"attack", "shatter", "duannian", "zhuangzhong", "zhuying", "liebo", "xuezhang", "baiguyin", "shoulian", "shuangdeng", "yuangui", "tianping",
	"guard", "difan", "jieshi", "tongjing", "fuhunsuo", "jiedao", "jinshen", "podan", "duanxiang",
	"shift", "dengxin", "tianyou", "wenlu", "zhima", "changming", "jieshou", "anhun", "tinggeng",
]
const NODE_TABLE := [
	["battle", "lantern_imp"], ["event", "paper_clue"], ["battle", "paper_apprentice"],
	["rest", ""], ["battle", "patrol_corpse"], ["elite", "mortuary_warden"],
	["battle", "gambler_ghost"], ["event", "gambler_debt"], ["rest", ""],
	["battle", "barber_ghost"], ["battle", "well_sisters"], ["boss", "lantern_keeper"],
]
const EVENTS := {
	"paper_clue": {
		"title": "纸人百号", "a": "帮他开脸（+12 灯油）", "b": "婉拒离开（得一张符牌）",
		"body": "学徒的第九十九个纸人还缺一张真脸。三张纸胎上的门牌，都指着义庄 13 号。",
	},
	"gambler_debt": {
		"title": "赌债", "a": "押一局（五五开：赢符牌 / 输 12 灯油）", "b": "不赌",
		"body": "赌鬼把骰子撒在地上：那晚满城都在排队投胎，他押阎王没空管——他输了。",
	},
}

var state: State = State.MENU
var run_deck: Array[String] = []
var run_hp := 72
var node_queue: Array = []
var node_name := ""
var node_enemy := "watchman"
var last_victory := false
var draft_options: Array[String] = []
var rng := RandomNumberGenerator.new()
var battle: Node
var pending_event_id := "paper_clue"

var playtest := "--playtest" in OS.get_cmdline_user_args()
var ai_strategy := {}
var narrated_move := ""
var _beat := 0
var playtest_runs := 0

var demo_mode := false
var demo_hint: Label

var menu_layer: CanvasLayer
var battle_layer: CanvasLayer
var reward_layer: CanvasLayer
var rest_layer: CanvasLayer
var event_layer: CanvasLayer
var over_layer: CanvasLayer
var flow_layer: CanvasLayer
var node_label: Label
var over_title: Label
var over_sub: Label
var reward_title: Label
var rest_body: Label
var event_title: Label
var event_body: Label
var event_choice_a: Button
var event_choice_b: Button


func _ready() -> void:
	rng.randomize()
	menu_layer = CanvasLayer.new(); menu_layer.layer = 5; menu_layer.visible = false; add_child(menu_layer)
	battle_layer = CanvasLayer.new(); battle_layer.layer = 1; battle_layer.visible = false; add_child(battle_layer)
	reward_layer = CanvasLayer.new(); reward_layer.layer = 6; reward_layer.visible = false; add_child(reward_layer)
	rest_layer = CanvasLayer.new(); rest_layer.layer = 6; rest_layer.visible = false; add_child(rest_layer)
	event_layer = CanvasLayer.new(); event_layer.layer = 6; event_layer.visible = false; add_child(event_layer)
	over_layer = CanvasLayer.new(); over_layer.layer = 7; over_layer.visible = false; add_child(over_layer)
	flow_layer = CanvasLayer.new(); flow_layer.layer = 4; flow_layer.visible = false; add_child(flow_layer)
	node_label = _label(Vector2(520, 40), Vector2(240, 30), 20, Color("c8bb9d"), true)
	node_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flow_layer.add_child(node_label)
	_build_menu()
	_build_reward()
	_build_flow_ui()
	_build_over()
	if playtest:
		_load_strategy()
		print("[PLAYTEST] 开始自动游玩：策略=%s" % str(ai_strategy))
		Engine.time_scale = 4.0
		start_run()
	else:
		_enter(State.MENU)


func _can_enter(to: State) -> bool:
	return to in TRANSITIONS[state]


func _enter(to: State) -> void:
	assert(_can_enter(to), "非法状态转移 %s -> %s" % [State.keys()[state], State.keys()[to]])
	state = to
	match to:
		State.MENU:
			_show_menu()
		State.BATTLE:
			_show_battle()
		State.REWARD:
			_show_reward()
		State.REST:
			_show_rest()
		State.EVENT:
			_show_event()
		State.GAME_OVER:
			_show_over()


func _process(_delta: float) -> void:
	if playtest:
		Engine.time_scale = 4.0
		if state == State.REWARD:
			_on_reward_picked(0)
		elif state == State.EVENT:
			_on_event_choice(0)
		elif state == State.REST:
			_advance_node()
	if demo_mode:
		return
	if playtest:
		_beat += 1
		if _beat % 120 == 0:
			var bs = battle.sim if battle else null
			print("[HB] state=%s node=%s battle=%s simstate=%s ehp=%s pts=%s hand=%s" % [
				State.keys()[state], node_name, battle != null,
				bs.state if bs else "-", bs.enemy_hp if bs else "-",
				bs.points if bs else "-", str(bs.hand) if bs else "-"])
	if playtest and state == State.BATTLE:
		_bot_tick()
	if state != State.BATTLE or battle == null:
		return
	var sim_state: int = battle.sim.state
	if sim_state == BattleSimulationScript.BattleState.VICTORY:
		_finish_battle(true)
	elif sim_state == BattleSimulationScript.BattleState.DEFEAT:
		_finish_battle(false)


func _input(event: InputEvent) -> void:
	if demo_mode and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_end_demo()
		get_viewport().set_input_as_handled()


func _show_menu() -> void:
	_free_battle()
	menu_layer.visible = true
	reward_layer.visible = false
	over_layer.visible = false
	rest_layer.visible = false
	event_layer.visible = false
	battle_layer.visible = false
	flow_layer.visible = false


func _show_battle() -> void:
	menu_layer.visible = false
	reward_layer.visible = false
	over_layer.visible = false
	rest_layer.visible = false
	event_layer.visible = false
	battle_layer.visible = true
	flow_layer.visible = true
	battle = BattleScene.instantiate()
	battle_layer.add_child(battle)
	battle.apply_run_config(node_enemy, run_deck.duplicate())
	battle.sim.player_hp = run_hp
	node_label.text = {"elite": "精英战", "boss": "头目战"}.get(node_name, "第 %d 场" % (_cleared_count() + 1))


func _cleared_count() -> int:
	return NODE_TABLE.size() - node_queue.size() - 1


func _show_reward() -> void:
	rest_layer.visible = false
	event_layer.visible = false
	reward_layer.visible = true
	draft_options.clear()
	var pool := DRAFT_POOL.duplicate()
	var yu_pool: Array = pool.filter(func(cid: String): return BattleSimulationScript.CARD_DATA[cid]["class"] == "御")
	var yu: String = yu_pool[rng.randi_range(0, yu_pool.size() - 1)]
	draft_options.append(yu)
	pool.erase(yu)
	var zha_pool: Array = pool.filter(func(cid: String): return BattleSimulationScript.CARD_DATA[cid]["class"] == "斩")
	var zha: String = zha_pool[rng.randi_range(0, zha_pool.size() - 1)]
	draft_options.append(zha)
	pool.erase(zha)
	var idx := rng.randi_range(0, pool.size() - 1)
	draft_options.append(pool.pop_at(idx))
	reward_title.text = "怨契三选一｜第 %d / %d 场后" % [_cleared_count(), NODE_TABLE.size()]
	for i in 3:
		var button: Button = reward_layer.get_node("Card%d" % i)
		var pres: Dictionary = PresentationCatalog.CARD_PRESENTATION[draft_options[i]]
		var gdata: Dictionary = BattleSimulationScript.CARD_DATA[draft_options[i]]
		button.text = "%s\n%s·%d点\n%s" % [pres.title, gdata["class"], gdata.cost, _card_flavor(draft_options[i])]
		button.disabled = false


func _show_rest() -> void:
	rest_layer.visible = true
	run_hp = mini(72, run_hp + 20)
	rest_body.text = "长明灯旁添一次油\n灯油 +20（当前 %d/72）" % run_hp
	if playtest:
		print("[PLAYTEST] 篝火歇脚｜灯油回复至 %d/72" % run_hp)


func _show_event() -> void:
	pending_event_id = node_enemy
	var ev: Dictionary = EVENTS.get(pending_event_id, EVENTS.paper_clue)
	rest_layer.visible = false
	event_layer.visible = true
	event_title.text = String(ev.title)
	event_body.text = String(ev.body)
	event_choice_a.text = String(ev.a)
	event_choice_b.text = String(ev.b)
	if playtest:
		print("[PLAYTEST] 事件=%s｜%s" % [ev.title, ev.body])


func _show_over() -> void:
	if playtest:
		playtest_runs += 1
		print("[PLAYTEST] ===第 %d 次尝试结束：%s｜牌组=%s===" % [playtest_runs, "天明" if last_victory else "灯灭", str(run_deck)])
		if playtest_runs < 6 and not last_victory:
			_enter(State.MENU)
			start_run()
			return
		print("[PLAYTEST] 全局结束：%s" % ["通关" if last_victory else "未能通关"])
		get_tree().quit(0)
	over_layer.visible = true
	if last_victory:
		over_title.text = "夜 尽 天 明"
		over_title.add_theme_color_override("font_color", Color("f1d185"))
		over_sub.text = "秤砣归位，众怨过河。你走完了三程路。"
	else:
		over_title.text = "灯 灭 了"
		over_title.add_theme_color_override("font_color", Color("cf5555"))
		over_sub.text = "第 %d 场，执灯人倒在了更路上。" % (_cleared_count() + 1)


func start_run() -> void:
	run_hp = 72
	run_deck.clear()
	for id in BASE_DECK:
		run_deck.append(String(id))
	node_queue = NODE_TABLE.duplicate()
	_advance_node()


func _advance_node() -> void:
	var node: Array = node_queue.pop_front()
	node_name = String(node[0])
	node_enemy = String(node[1])
	match node_name:
		"rest":
			_enter(State.REST)
		"event":
			_enter(State.EVENT)
		_:
			_enter(State.BATTLE)


func _finish_battle(victory: bool) -> void:
	if battle:
		run_hp = battle.sim.player_hp
	last_victory = victory
	if playtest and battle:
		var s = battle.sim
		print("[PLAYTEST] 节点=%s(%s) 敌=%s 结果=%s 灯油=%d/72 完美x%d 历经%d招 敌余血=%d" % [
			node_name, node_enemy, s.enemy_name, "胜" if victory else "负",
			s.player_hp, s.perfects, s.attack_index + 1, maxi(0, s.enemy_hp)])
	if playtest and not victory:
		print("[PLAYTEST] 夜巡失败，结束于第 %d 场" % (_cleared_count() + 1))
	_free_battle()
	if not victory:
		_enter(State.GAME_OVER)
	elif node_queue.is_empty():
		last_victory = true
		_enter(State.GAME_OVER)
	else:
		_enter(State.REWARD)


func _free_battle() -> void:
	if battle:
		battle.queue_free()
		battle = null


func _on_reward_picked(index: int) -> void:
	if state != State.REWARD or index >= draft_options.size():
		return
	run_deck.append(draft_options[index])
	_advance_node()


func _on_reward_skipped() -> void:
	if state != State.REWARD:
		return
	_advance_node()


func _on_event_choice(choice: int) -> void:
	if state != State.EVENT:
		return
	match pending_event_id:
		"paper_clue":
			if choice == 0:
				run_hp = mini(72, run_hp + 12)
				print("[PLAYTEST] 事件选择 A：灯油 +12")
			else:
				run_deck.append(DRAFT_POOL[rng.randi_range(0, DRAFT_POOL.size() - 1)])
				print("[PLAYTEST] 事件选择 B：符牌入手")
		"gambler_debt":
			if choice == 0:
				if rng.randf() < 0.5:
					run_deck.append(DRAFT_POOL[rng.randi_range(0, DRAFT_POOL.size() - 1)])
					print("[PLAYTEST] 赌局：赢了，得一张符牌")
				else:
					run_hp = maxi(1, run_hp - 12)
					print("[PLAYTEST] 赌局：输了，灯油 -12")
			else:
				print("[PLAYTEST] 不赌，转身离开")
	_advance_node()


func _restart_battle() -> void:
	pass


func _card_flavor(id: String) -> String:
	var flavors := {
		"attack": "散去 5 点怨气", "shatter": "12 伤·僵直中 +6", "guard": "6 伤·凝滞", "shift": "回 7 灯油",
		"duannian": "8 伤·弃一张手牌", "dengxin": "回 4 灯油", "zhuangzhong": "5 伤·凝滞 0.2s",
		"anhun": "净化：鬼手改为可防范",
	}
	return flavors.get(id, "")


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


func _start_demo() -> void:
	menu_layer.visible = false
	reward_layer.visible = false
	over_layer.visible = false
	rest_layer.visible = false
	event_layer.visible = false
	battle_layer.visible = true
	demo_mode = true
	demo_hint.visible = true
	battle = BattleScene.instantiate()
	battle_layer.add_child(battle)


func _end_demo() -> void:
	demo_mode = false
	demo_hint.visible = false
	_free_battle()
	_enter(State.MENU)


func _build_menu() -> void:
	menu_layer.add_child(_dim(Color(0.02, 0.02, 0.03)))
	var title := _label(Vector2(340, 200), Vector2(600, 90), 64, Color("f1d185"), true)
	title.text = "了  断"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_layer.add_child(title)
	var sub := _label(Vector2(340, 300), Vector2(600, 40), 20, Color("9caaa9"), false)
	sub.text = "灯照本相，怨还其身"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_layer.add_child(sub)
	var start := _button(Vector2(490, 400), Vector2(300, 64), "开始夜巡")
	start.pressed.connect(start_run)
	menu_layer.add_child(start)
	var demo := _button(Vector2(490, 478), Vector2(300, 52), "旧日试炼 [开发]")
	demo.pressed.connect(_start_demo)
	menu_layer.add_child(demo)
	var quit := _button(Vector2(490, 544), Vector2(300, 44), "退出")
	quit.pressed.connect(func(): get_tree().quit())
	menu_layer.add_child(quit)
	var controls := _label(Vector2(340, 620), Vector2(600, 30), 16, Color("7a7264"), false)
	controls.text = "Space 防范 · 1-4 符牌 · 5 召符 · Esc 菜单"
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_layer.add_child(controls)
	demo_hint = _label(Vector2(340, 40), Vector2(600, 30), 16, Color("9caaa9"), false)
	demo_hint.text = "旧日试炼（开发验证）· Esc 返回标题"
	demo_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	demo_hint.visible = false
	menu_layer.add_child(demo_hint)


func _build_reward() -> void:
	reward_layer.add_child(_dim(Color(0.05, 0.03, 0.03, 0.86)))
	reward_title = _label(Vector2(240, 130), Vector2(800, 50), 34, Color("f2d487"), true)
	reward_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_layer.add_child(reward_title)
	for i in 3:
		var button := _button(Vector2(240 + i * 280, 260), Vector2(240, 200), "")
		button.name = "Card%d" % i
		button.add_theme_font_size_override("font_size", 24)
		button.pressed.connect(_on_reward_picked.bind(i))
		reward_layer.add_child(button)
	var skip := _button(Vector2(500, 520), Vector2(280, 52), "跳过（继续上路）")
	skip.pressed.connect(_on_reward_skipped)
	reward_layer.add_child(skip)


func _build_flow_ui() -> void:
	flow_layer.visible = false
	rest_layer.add_child(_dim(Color(0.02, 0.03, 0.02, 0.88)))
	var rpanel := Panel.new()
	rpanel.position = Vector2(440, 220)
	rpanel.size = Vector2(400, 260)
	rpanel.add_theme_stylebox_override("panel", _style_box(Color(0.03, 0.03, 0.045, 0.97), Color("6d9663"), 16, 2))
	rest_layer.add_child(rpanel)
	var rtitle := _label(Vector2(20, 40), Vector2(360, 48), 32, Color("aad18f"), true)
	rtitle.text = "城隍歇脚"
	rtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rpanel.add_child(rtitle)
	rest_body = _label(Vector2(20, 110), Vector2(360, 60), 18, Color("c8bb9d"), false)
	rest_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rest_body.text = "长明灯旁添一次油\n灯油 +20"
	rpanel.add_child(rest_body)
	var rgo := _button(Vector2(60, 190), Vector2(280, 48), "继续夜巡")
	rgo.pressed.connect(func(): _advance_node())
	rpanel.add_child(rgo)

	event_layer.add_child(_dim(Color(0.03, 0.02, 0.03, 0.88)))
	var epanel := Panel.new()
	epanel.position = Vector2(390, 170)
	epanel.size = Vector2(500, 360)
	epanel.add_theme_stylebox_override("panel", _style_box(Color(0.03, 0.03, 0.045, 0.97), Color("8a6a3a"), 16, 2))
	event_layer.add_child(epanel)
	event_title = _label(Vector2(20, 34), Vector2(460, 44), 28, Color("f1d185"), true)
	event_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	epanel.add_child(event_title)
	event_body = _label(Vector2(36, 100), Vector2(428, 110), 17, Color("c8bb9d"), false)
	event_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	epanel.add_child(event_body)
	event_choice_a = _button(Vector2(40, 240), Vector2(420, 46), "")
	event_choice_a.pressed.connect(_on_event_choice.bind(0))
	epanel.add_child(event_choice_a)
	event_choice_b = _button(Vector2(40, 296), Vector2(420, 46), "")
	event_choice_b.pressed.connect(_on_event_choice.bind(1))
	epanel.add_child(event_choice_b)


func _build_over() -> void:
	over_layer.add_child(_dim(Color(0.01, 0.01, 0.02, 0.92)))
	over_title = _label(Vector2(240, 220), Vector2(800, 80), 52, Color("f1d185"), true)
	over_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	over_layer.add_child(over_title)
	over_sub = _label(Vector2(240, 330), Vector2(800, 40), 20, Color("c8bb9d"), false)
	over_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	over_layer.add_child(over_sub)
	var menu_btn := _button(Vector2(490, 460), Vector2(300, 60), "回到长夜")
	menu_btn.pressed.connect(func(): _enter(State.MENU))
	over_layer.add_child(menu_btn)


func _dim(color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.color = color
	return rect


func _label(pos: Vector2, size: Vector2, font_size: int, color: Color, bold: bool) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = size
	label.add_theme_font_size_override("font_size", font_size + (1 if bold else 0))
	label.add_theme_color_override("font_color", color)
	return label


func _button(pos: Vector2, size: Vector2, text: String) -> Button:
	var button := Button.new()
	button.position = pos
	button.size = size
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_stylebox_override("normal", _style_box(Color("2c211d"), Color("bd8b45"), 12, 2))
	var sb_hover := _style_box(Color("493126"), Color("e0ad58"), 12, 3)
	button.add_theme_stylebox_override("hover", sb_hover)
	return button


func _style_box(bg: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	return box
