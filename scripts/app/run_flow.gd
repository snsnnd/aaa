extends Node

## 正式版骨架：RunFlow 状态机驱动 菜单→战斗→奖励→结算 的单局循环。
## 战斗本身的状态机在 battle_simulation.gd；敌招阶段机见 GAME_PLAN M1。

enum State { MENU, BATTLE, REWARD, GAME_OVER }

const TRANSITIONS := {
	State.MENU: [State.MENU, State.BATTLE],
	State.BATTLE: [State.REWARD, State.GAME_OVER],
	State.REWARD: [State.BATTLE],
	State.GAME_OVER: [State.MENU],
}

const BattleScene := preload("res://scenes/main.tscn")
const BattleSimulationScript := preload("res://scripts/battle/battle_simulation.gd")
const BASE_DECK := ["attack", "attack", "shatter", "guard", "shift"]
const DRAFT_POOL := ["attack", "shatter", "guard", "shift", "duannian", "dengxin", "zhuangzhong"]
const NODE_TABLE := [["battle", "lantern_imp"], ["battle", "patrol_corpse"], ["elite", "mortuary_warden"], ["battle", "gambler_ghost"], ["boss", "lantern_keeper"]]

var state: State = State.MENU
var run_deck: Array[String] = []
var node_queue: Array = []
var node_name := ""
var node_enemy := "watchman"
var last_victory := false
var draft_options: Array[String] = []
var rng := RandomNumberGenerator.new()
var battle: Node

var menu_layer: CanvasLayer
var battle_layer: CanvasLayer
var reward_layer: CanvasLayer
var over_layer: CanvasLayer
var node_label: Label
var over_title: Label
var over_sub: Label
var reward_title: Label
var demo_mode := false
var demo_hint: Label


func _ready() -> void:
	rng.randomize()
	menu_layer = CanvasLayer.new(); menu_layer.layer = 5; add_child(menu_layer)
	battle_layer = CanvasLayer.new(); battle_layer.layer = 1; add_child(battle_layer)
	reward_layer = CanvasLayer.new(); reward_layer.layer = 6; add_child(reward_layer)
	over_layer = CanvasLayer.new(); over_layer.layer = 7; add_child(over_layer)
	_build_menu()
	_build_reward()
	_build_over()
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
		State.GAME_OVER:
			_show_over()


func _show_menu() -> void:
	if battle:
		battle.queue_free()
		battle = null
	menu_layer.visible = true
	reward_layer.visible = false
	over_layer.visible = false
	battle_layer.visible = false


func _show_battle() -> void:
	menu_layer.visible = false
	reward_layer.visible = false
	over_layer.visible = false
	battle_layer.visible = true
	battle = BattleScene.instantiate()
	battle_layer.add_child(battle)
	battle.apply_run_config(node_enemy, run_deck.duplicate())
	node_label.text = {"battle": "第 %d 场" % (NODE_TABLE.size() - node_queue.size()), "elite": "精英战", "boss": "头目战"}.get(node_name, "")


func _show_reward() -> void:
	reward_layer.visible = true
	draft_options.clear()
	var pool := DRAFT_POOL.duplicate()
	for i in 3:
		var idx := rng.randi_range(0, pool.size() - 1)
		draft_options.append(pool.pop_at(idx))
	reward_title.text = "怨契三选一｜第 %d / %d 场后" % [NODE_TABLE.size() - node_queue.size(), NODE_TABLE.size()]
	for i in 3:
		var button: Button = reward_layer.get_node("Card%d" % i)
		var data: Dictionary = BattleSimulationScript.CARD_DATA[draft_options[i]]
		button.text = "%s\n%s·%d点\n%s" % [data.title, data["class"], data.cost, _card_flavor(draft_options[i])]
		button.disabled = false


func _show_over() -> void:
	over_layer.visible = true
	if last_victory:
		over_title.text = "夜 尽 天 明"
		over_sub.text = "秤砣归位，众怨过河。你走完了三程路。" if node_queue.is_empty() else "这一夜，到这里为止。"
	else:
		over_title.text = "灯 灭 了"
		over_sub.text = "第 %d 场，执灯人倒在了更路上。" % (NODE_TABLE.size() - node_queue.size())


func _process(_delta: float) -> void:
	if demo_mode or state != State.BATTLE or battle == null:
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


func _start_demo() -> void:
	menu_layer.visible = false
	reward_layer.visible = false
	over_layer.visible = false
	battle_layer.visible = true
	demo_mode = true
	demo_hint.visible = true
	battle = BattleScene.instantiate()
	battle_layer.add_child(battle)


func _end_demo() -> void:
	demo_mode = false
	demo_hint.visible = false
	if battle:
		battle.queue_free()
		battle = null
	_enter(State.MENU)


func _finish_battle(victory: bool) -> void:
	last_victory = victory
	if battle:
		battle.queue_free()
		battle = null
	if not victory:
		_enter(State.GAME_OVER)
	elif node_queue.is_empty():
		last_victory = true
		node_queue = []
		_enter(State.GAME_OVER)
	else:
		_enter(State.REWARD)


func start_run() -> void:
	run_deck = BASE_DECK.duplicate()
	node_queue = NODE_TABLE.duplicate()
	_advance_node()


func _advance_node() -> void:
	var node: Array = node_queue.pop_front()
	node_name = String(node[0])
	node_enemy = String(node[1])
	_enter(State.BATTLE)


func _on_reward_picked(index: int) -> void:
	if state != State.REWARD or index >= draft_options.size():
		return
	run_deck.append(draft_options[index])
	_advance_node()


func _on_reward_skipped() -> void:
	if state != State.REWARD:
		return
	_advance_node()


func _card_flavor(id: String) -> String:
	var flavors := {
		"attack": "散去 4 点怨气", "shatter": "12 伤·僵直中 +6", "guard": "6 伤·凝滞", "shift": "回 7 灯油",
		"duannian": "8 伤·弃一张手牌", "dengxin": "回 4 灯油", "zhuangzhong": "5 伤·凝滞 0.2s",
	}
	return flavors.get(id, "")


func _build_menu() -> void:
	var dim := _dim(Color(0.02, 0.02, 0.03))
	menu_layer.add_child(dim)
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
	reward_layer.visible = false
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


func _build_over() -> void:
	over_layer.visible = false
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
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("2c211d")
	sb.border_color = Color("bd8b45")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	button.add_theme_stylebox_override("normal", sb)
	var sb_hover := sb.duplicate()
	sb_hover.bg_color = Color("493126")
	sb_hover.border_color = Color("e0ad58")
	button.add_theme_stylebox_override("hover", sb_hover)
	return button
