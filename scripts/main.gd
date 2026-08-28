extends Node2D

## 组合根：创建模拟层与表现层、路由输入与事件。
## 规则在 BattleSimulation，世界表现在 BattleView，UI 在 BattleHud。
## 输入统一走 InputMap 动作（GameSettings 管重映射），时间统一走 GameTime。

const BattleSimulationScript := preload("res://scripts/battle/battle_simulation.gd")
const BattleViewScript := preload("res://scripts/presentation/battle_view.gd")
const BattleHudScript := preload("res://scripts/presentation/battle_hud.gd")
const PresentationCatalog := preload("res://scripts/presentation/presentation_catalog.gd")
const CardSystemScript := preload("res://scripts/battle/card_system.gd")
const TutorialScript := preload("res://scripts/app/tutorial.gd")
const EnemyReactionControllerScript := preload("res://scripts/presentation/enemy_reaction_controller.gd")
const PlayerActionControllerScript := preload("res://scripts/presentation/player_action_controller.gd")

var sim: BattleSimulationScript
var view: BattleViewScript
var hud: BattleHudScript
var tutorial: TutorialScript
var enemy_reaction: EnemyReactionControllerScript
var player_action: PlayerActionControllerScript
var ai_mode := false
var ai_wait := false
var ai_defend := ""
var ai_cards: Array = []
var ai_announced_for := -1
const AI_STATE := "res://playtest/ai_state.txt"
const AI_CMD := "res://playtest/ai_cmd.txt"

var enemy_sprite: Sprite2D:
	get:
		return view.enemy_sprite
var player_sprite: Sprite2D:
	get:
		return view.player_sprite
var weapon_pivot: Node2D:
	get:
		return view.weapon_pivot
var weapon_sprite: Sprite2D:
	get:
		return view.weapon_sprite
var ghost_hand: Node2D:
	get:
		return view.ghost_hand
var background: Sprite2D:
	get:
		return view.background
var rain_drops: Array[Line2D]:
	get:
		return view.rain_drops
var card_buttons: Dictionary:
	get:
		return hud.card_buttons


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	sim = BattleSimulationScript.new()
	view = BattleViewScript.new()
	add_child(view)
	view.setup(sim)
	hud = BattleHudScript.new()
	add_child(hud)
	hud.setup(sim, _submit, _restart_battle, _abandon_run)
	tutorial = TutorialScript.new()
	enemy_reaction = EnemyReactionControllerScript.new()
	enemy_reaction.setup(view)
	player_action = PlayerActionControllerScript.new()
	player_action.setup(view)
	_apply_attack_presentation()
	hud.show_message("—— 巡更备战 · 凝神 ——", Color("e2cf9c"), 1.2)
	if "--smoke-test" in OS.get_cmdline_user_args():
		call_deferred("_run_smoke_test")
	if "--ai-decide" in OS.get_cmdline_user_args():
		ai_mode = true
		call_deferred("_ai_boot")


func _exit_tree() -> void:
	GameTime.reset()


func _process(delta: float) -> void:
	if ai_mode:
		GameTime.base_scale = 6.0
		if ai_wait:
			if FileAccess.file_exists(AI_CMD):
				_ai_load_cmd()
			return
		view.tick(delta)
		for event: Dictionary in sim.step(delta):
			_handle_event(event)
		_ai_execute()
		_ai_announce_if_needed()
		return
	if hud.menu_open:
		return
	view.tick(delta)
	for event: Dictionary in sim.step(delta):
		_handle_event(event)


func _ai_boot() -> void:
	var cfg := {}
	var path := "res://playtest/ai_scenario.txt"
	if FileAccess.file_exists(path):
		for line in FileAccess.open(path, FileAccess.READ).get_as_text().split("\n"):
			if "=" in line:
				var kv := line.split("=", true, 1)
				cfg[kv[0].strip_edges()] = kv[1].strip_edges()
	sim.enemy_id = String(cfg.get("enemy", "mortuary_warden"))
	var deck: Array[String] = []
	for id in String(cfg.get("deck", "attack,attack,shatter,guard,shift")).split(","):
		deck.append(id.strip_edges())
	sim.deck_config = deck
	sim.restart()
	if cfg.has("hp"):
		sim.player_hp = int(cfg["hp"])
	view.apply_attack_presentation()
	hud.rebuild_hand()
	hud.rebuild_pile_view()
	hud.refresh()


func _ai_announce_if_needed() -> void:
	if sim.state != BattleSimulationScript.BattleState.WINDUP:
		return
	if sim.attack_index == ai_announced_for or sim.attack_elapsed > 0.15:
		return
	ai_announced_for = sim.attack_index
	ai_wait = true
	_ai_dump_state()


func _ai_dump_state() -> void:
	var unblockable := bool(sim.current_intent.get("unblockable", false))
	var impact := sim._current_impact_time()
	var fake: float = sim.current_intent.get("fake", -1.0)
	var hand := []
	for id in sim.hand:
		hand.append("%s(%d点·%s)" % [id, CardSystemScript.cost_of(id), CardSystemScript.class_of(id)])
	var phases := []
	for ph in sim.current_intent.get("phases", []):
		phases.append("%s→%.2f" % [ph.name, float(ph.until)])
	var text := "[决策点] 第%d招\n敌=%s 血=%d/%d\n招式=%s%s\n阶段=%s\n命中@%.2fs 伤=%d %s\n我=灯油%d/%d 还愿%d 冷却%.2f\n手牌=%s\n指令: plan defend_perfect | plan defend_success | card <id> @now|@reveal|@impact-0.05 | summon | restart\n"
	text = text % [
		sim.attack_index + 1, sim.enemy_name, sim.enemy_hp, sim.enemy_max_hp,
		sim.current_intent.title, "【不可防范】" if unblockable else "",
		", ".join(phases), impact, int(sim.current_intent.damage),
		"假释放@%.2f" % fake if fake >= 0 else "",
		sim.player_hp, sim.player_max_hp, sim.points, sim.defense_cooldown, str(hand),
	]
	print(text)
	var f := FileAccess.open(AI_STATE, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _ai_load_cmd() -> void:
	var f := FileAccess.open(AI_CMD, FileAccess.READ)
	var text := f.get_as_text()
	f.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(AI_CMD))
	ai_defend = ""
	ai_cards.clear()
	for line in text.split("\n"):
		line = line.strip_edges()
		if line.begins_with("plan "):
			ai_defend = line.trim_prefix("plan ")
		elif line.begins_with("card "):
			var parts := line.trim_prefix("card ").split("@", false)
			ai_cards.append({"id": parts[0].strip_edges(), "when": parts[1].strip_edges() if parts.size() > 1 else "now", "done": false})
		elif line == "summon":
			ai_cards.append({"id": "summon", "when": "now", "done": false})
		elif line == "restart":
			ai_wait = false
			_restart_battle()
			return
	print("[AI] 指令：%s｜卡=%s" % [ai_defend, str(ai_cards)])
	ai_wait = false


func _ai_execute() -> void:
	if sim.state != BattleSimulationScript.BattleState.WINDUP:
		return
	if ai_defend != "" and sim.queued_defense == BattleSimulationScript.DefenseGrade.NONE and sim.defense_cooldown <= 0.0:
		var tt: float = sim._current_impact_time() - sim.attack_elapsed
		if ai_defend == "perfect" and tt <= 0.06 and tt > -0.05:
			_submit({"type": "defend"})
		elif ai_defend == "success" and tt <= float(sim.current_intent.window) * 0.75 and tt > 0.02:
			_submit({"type": "defend"})
	for card: Dictionary in ai_cards:
		if bool(card.get("done", false)):
			continue
		var id := String(card.id)
		var when := String(card.when)
		var cmd: Dictionary = {"type": "summon"} if id == "summon" else {"type": "play_card", "id": id}
		if when == "now":
			_submit(cmd)
			card.done = true
		elif when == "reveal" and sim.fake_released:
			_submit(cmd)
			card.done = true
		elif when == "impact" and sim._current_impact_time() - sim.attack_elapsed <= 0.0:
			_submit(cmd)
			card.done = true
		elif when.begins_with("impact-") and sim._current_impact_time() - sim.attack_elapsed <= float(when.trim_prefix("impact-")):
			_submit(cmd)
			card.done = true


func _input(event: InputEvent) -> void:
	if hud.menu_open:
		if event.is_action_pressed("pause"):
			hud.toggle_menu()
		elif event.is_action_pressed("restart"):
			_restart_battle()
		return
	if event.is_action_pressed("card_1"):
		_play_hand_slot(0)
	elif event.is_action_pressed("card_2"):
		_play_hand_slot(1)
	elif event.is_action_pressed("card_3"):
		_play_hand_slot(2)
	elif event.is_action_pressed("card_4"):
		_play_hand_slot(3)
	elif event.is_action_pressed("summon"):
		_submit({"type": "summon"})
	elif event.is_action_pressed("defend"):
		_submit({"type": "defend"})
	elif event.is_action_pressed("pause"):
		hud.toggle_menu()
	elif event.is_action_pressed("restart"):
		_restart_battle()


func _play_hand_slot(slot: int) -> void:
	if slot >= 0 and slot < sim.hand.size():
		_submit({"type": "play_card", "id": sim.hand[slot]})


func _submit(command: Dictionary) -> void:
	for event: Dictionary in sim.submit(command):
		_handle_event(event)


func _abandon_run() -> void:
	## 暂停菜单里的"离开夜巡"：保存并回到流程层标题。
	var parent := get_parent()
	if parent and parent.has_method("abandon_run"):
		parent.abandon_run()


func _handle_event(event: Dictionary) -> void:
	# 教学：事件驱动提示
	var hint := tutorial.handle_event(event, sim)
	if hint != "":
		hud.show_message(hint, Color("9ab0a2"), 2.4)
	# 遥测
	match String(event.get("type", "")):
		"defense_miss":
			Telemetry.record_defense(String(sim.current_intent.id), 0)
		"impact":
			Telemetry.record_defense(String(sim.current_intent.id), int(event.grade))
		"card_played":
			Telemetry.record_card_play(String(event.id), CardSystemScript.cost_of(String(event.id)))
		"card_summoned":
			Telemetry.record_summon(int(event.get("cost", 2)))
	match String(event.get("type", "")):
		"action_started":
			player_action.on_action_started(String(event.get("transition", "")), String(event.get("movement", "none")), int(event.get("vfx_tier", 0)),
				float(event.get("startup", 0.1)), float(event.get("impact_time", 0.2)), float(event.get("recovery", 0.3)))
			# 挥砍音：重位移动作用重 whoosh；音调微移在 play_sfx 内做变化
			var swing := "swing_heavy" if String(event.get("movement", "none")) in ["lunge", "leap", "dash"] else "swing_light"
			view.play_sfx(swing, -8.0)
			if String(event.get("transition", "")) == "seamless" and int(event.get("combo_level", 0)) >= 2:
				hud.show_message("连·%d ｜ 连势 %d" % [int(event.combo_level), int(event.momentum)], Color("f2d487"), 0.7)
		"action_buffered":
			view.play_sfx("buffer", -6.0)
			hud.show_message("预输入 · %s" % CardSystemScript.title_of(String(event.id)), Color("9caaa9"), 0.6)
		"action_canceled":
			view.play_sfx("cancel", -6.0)
			hud.show_message("取消衔接 → %s" % CardSystemScript.title_of(String(event.get("by", ""))), Color("7fc5cd"), 0.7)
		"action_impact":
			enemy_reaction.react(String(event.get("level", "LIGHT")), int(event.get("vfx_tier", 0)))
			if bool(event.get("finisher", false)):
				hud.show_message("终结！", Color("f2d487"), 1.0)
		"combo_reset":
			hud.show_message("气息散了", Color("9e8b81"), 0.6)
		"attack_started":
			_apply_attack_presentation()
			hud.refresh()
		"trait_intro":
			hud.show_message(String(event.get("text", "")), Color("c8b46a"), 2.2)
		"enemy_phase":
			view.commit_flash(GameSettings.adjust_color(Color("f2d487")))
			view.add_trauma(0.5)
			hud.show_message("【%s】%s" % [event.get("title", "变"), event.get("announce", "")], Color("f2d487"), 2.6)
		"dice_roll":
			hud.show_message(String(event.get("text", "")), Color("e0b45c"), 1.6)
		"vengeance_up":
			hud.show_message("看守记仇——这一刀重了 6 点", Color("d85151"), 1.4)
		"armor_broken":
			hud.show_message("纸胎甲破！符牌伤害恢复全额", Color("f2d487"), 1.6)
		"card_pulled":
			var pulled_display := CardSystemScript.display_id(String(event.id))
			hud.show_message("你的【%s】被拖进了水里" % PresentationCatalog.CARD_PRESENTATION[pulled_display]["title"], Color("9ab0a2"), 1.6)
		"impact_delayed":
			hud.show_message("鬼招被延后了", Color("7fc5cd"), 0.8)
		"strike_skipped":
			hud.show_message("一段命中被抹去！", Color("7fc5cd"), 0.9)
		"scry_offer":
			hand_view().show_scry(event.get("options", []))
		"scry_done":
			hand_view().close_scry()
		"commit_cue":
			view.commit_flash(view.intent_color())
			view.enemy_cue_fx(String(event.get("enemy", "")), String(event.get("intent", "")))
		"fake_release":
			view.fake_release()
		"defense_queued":
			if int(event.grade) == BattleSimulationScript.DefenseGrade.PERFECT:
				hud.show_message("刀光将落——正是此刻", Color("f2d487"), 0.5)
			view.pulse_glow(0.18)
			view.guard_arc()
			hud.refresh_defense_button()
		"hand_changed":
			hud.rebuild_hand()
			hud.refresh()
		"defense_miss":
			view.defense_miss_fx(bool(event.get("unblockable", false)))
			var unblockable := bool(event.get("unblockable", false))
			hud.show_message("此招不可防范，以符牌应对！" if unblockable else "架势散乱……", Color("c15454"), 0.7 if unblockable else 0.6)
		"impact":
			_present_impact(event)
		"enemy_staggered":
			view.enemy_staggered_fx()
			hud.show_message("鬼身僵直", Color("f2d487"), 0.7)
		"stagger":
			hud.show_message("鬼招凝滞", Color("7fc5cd"), 0.6)
		"grab_cancelled":
			view.snap_ghost_hand_back()
			view.add_trauma(0.3)
			hud.show_message("鬼手被斩断！还愿 +1", Color("7fc5cd"), 0.8)
		"cleansed":
			ghost_hand.modulate = Color("cfeef0")
			hud.show_message("安魂｜鬼手化为可承之怨", Color("9ab0a2"), 0.8)
		"card_played":
			_present_card(event)
			hud.rebuild_pile_view()
		"charged_bonus":
			pass  # 受击层级由 action_impact/enemy_reaction 统一表现
		"card_summoned":
			view.pulse_glow(0.5)
			view.summon_vfx(CardSystemScript.display_id(String(event.id)))
			hud.show_message("召符·%s" % CardSystemScript.title_of(String(event.id)), Color("f2d487"), 0.7)
			hud.rebuild_hand()
			hud.rebuild_pile_view()
			hud.refresh()
		"summon_rejected":
			match String(event.get("reason", "")):
				"hand_full":
					hud.show_message("符位已满", Color("9e8b81"), 0.5)
				"empty":
					hud.show_message("符堆已空", Color("9e8b81"), 0.5)
				"points":
					hud.show_message("愿力不足", Color("c15454"), 0.5)
		"card_rejected":
			if String(event.get("reason", "")) == "ended":
				hud.show_message("胜负已分  [R]", Color("9e8b81"), 0.8)
			else:
				hud.show_message("愿力不足", Color("c15454"), 0.6)
		"action_finished":
			view.finish_action_fx()
		"victory", "defeat":
			_present_battle_end(String(event.get("type", "")) == "victory")


func hand_view() -> Control:
	return hud.hand_view


func _apply_attack_presentation() -> void:
	view.apply_attack_presentation()
	view.play_warning()


func _present_impact(event: Dictionary) -> void:
	var grade: int = int(event.grade)
	match grade:
		BattleSimulationScript.DefenseGrade.SUCCESS:
			view.success_impact_fx()
			hud.flash(Color(1.0, 0.88, 0.56), 0.34, 0.10)
			hud.show_message("化解｜还愿 +1", view.intent_color().lightened(0.30), 0.6)
		BattleSimulationScript.DefenseGrade.PERFECT:
			view.perfect_impact_fx()
			view.play_sfx("parry_perfect", 0.0)
			hud.flash(Color(1.0, 0.88, 0.56), 0.68, 0.18)
			hud.show_message("完美接刀｜还愿 +1 · 乘势", Color("f2d487"), 0.8)
		_:
			view.take_hit(int(event.damage))
			hud.flash(Color(0.75, 0.08, 0.08), 0.30, 0.22)
			hud.show_message("灯油 -%d%s" % [int(event.damage), "（怒）" if bool(event.get("enraged", false)) else ""], Color("d85151"), 0.75)
			if bool(event.get("enraged", false)):
				view.rage_flare(enemy_sprite.position)
	hud.refresh()


func _present_card(event: Dictionary) -> void:
	view.play_card_sfx()
	var id := String(event.id)
	var display_id := CardSystemScript.display_id(id)
	view.spawn_talisman(display_id)
	var data: Dictionary = PresentationCatalog.CARD_PRESENTATION[display_id]
	match display_id:
		"attack":
			view.paper_burst()
		"shatter":
			view.counter_slash(bool(event.get("charged", false)))
		"guard":
			view.seal_ring()
		"shift":
			view.embers()
		"duannian":
			view.paper_burst(Color("c98a7a"))
		"dengxin", "tianyou", "jieshou":
			view.embers()
			view.pulse_glow(0.35)
		"zhuangzhong":
			view.bell_wave()
		"anhun", "jieshi", "tongjing", "baiguyin", "difan", "fuhunsuo", "jiedao", "jinshen", "podan", "duanxiang", "yandeng", "jiezou", "huangdeng", "chageng", "wenlu", "tinggeng":
			view.seal_ring()
	if event.has("healed") and int(event.healed) > 0:
		hud.show_message("%s｜灯油 +%d" % [data["title"], int(event.healed)], data.color, 0.7)
	elif event.has("max_hp"):
		hud.show_message("长明｜灯油上限 +%d" % int(event.max_hp), data.color, 0.9)
	elif event.has("damage") and int(event.damage) > 0:
		# 敌人受击表现由 enemy_reaction 统一分级处理，这里只报文案
		hud.show_message("%s｜散去 %d 点怨气" % [data["title"], int(event.damage)], data.color, 0.6)
	elif event.has("scry"):
		hud.show_message("问路｜选一张顺手的符牌", data.color, 0.9)
	elif event.has("next_move"):
		var warn := "（不可防范！）" if bool(event.get("unblockable", false)) else ""
		hud.show_message("听更｜下一招：%s%s" % [event.next_move, warn], data.color, 1.2)
	elif event.has("summon"):
		hud.show_message("%s｜召回 %d 张符牌" % [data["title"], int(event.summon)], data.color, 0.7)
	else:
		hud.show_message("%s" % data["title"], data.color, 0.5)
	hud.rebuild_hand()
	hud.refresh()


func _present_battle_end(victory: bool) -> void:
	view.finish_action_fx()
	hud.refresh()
	view.present_death(victory)
	if victory:
		hud.show_message("怨已归还", Color("f1d185"), 2.2)
	else:
		hud.show_message("灯灭了……", Color("cf5555"), 2.2)
	get_tree().create_timer(1.3, true, false, true).timeout.connect(func(): hud.show_settlement(victory))


func apply_run_config(enemy_id: String, deck: Array, current_hp: int = -1, mods: Dictionary = {}) -> void:
	sim.enemy_id = enemy_id
	sim.run_mods = mods
	sim.story_flags = mods.get("flags", {})
	if current_hp > 0:
		sim.initial_hp = current_hp
	var deck_copy: Array[String] = []
	for id in deck:
		deck_copy.append(String(id))
	sim.deck_config = deck_copy
	sim.restart()
	_apply_attack_presentation()
	hud.rebuild_hand()
	hud.rebuild_pile_view()
	hud.refresh()


func _restart_battle() -> void:
	## Run 内重开：回到本战开局的血量（initial_hp），不是满血。
	hud.close_menu()
	hud.hide_settlement()
	view.restart_fx()
	sim.restart()
	_apply_attack_presentation()
	for ev: Dictionary in sim.drain_begin_events():
		_handle_event(ev)
	hud.rebuild_hand()
	hud.rebuild_pile_view()
	hud.refresh()
	hud.show_message("夜还长，刀再来", Color("e2cf9c"), 1.0)


func _run_smoke_test() -> void:
	var s := BattleSimulationScript.new()
	assert(view.background.texture != null and view.player_sprite.texture != null and view.enemy_sprite.texture != null and view.weapon_sprite.texture != null)
	assert(s.state == BattleSimulationScript.BattleState.WINDUP)
	assert(s.points == 0)
	assert(s.hand.size() == 4 and s.hand.has("attack"))
	var events: Array = s.submit({"type": "defend"})
	assert(s.defense_cooldown > 0.0 and s.queued_defense == BattleSimulationScript.DefenseGrade.NONE)
	s.defense_cooldown = 0.0
	s.attack_elapsed = float(s.current_intent.duration) - 0.20
	events = s.submit({"type": "defend"})
	assert(s.queued_defense == BattleSimulationScript.DefenseGrade.SUCCESS)
	events = s.step(1.0)
	assert(s.points >= 1 and s.points <= 2 and s.player_hp == BattleSimulationScript.PLAYER_MAX_HP)
	_assert_has(events, "impact")
	events = s.submit({"type": "play_card", "id": "attack"})
	s.step(0.5)  # 动作时间轴：效果在命中帧（impact_time 0.22）结算
	assert(s.points >= 0 and s.points <= 1 and s.enemy_hp == 41)
	assert(s.hand.size() == 3)
	var evs_summon: Array = s.submit({"type": "summon"})
	assert(s.points <= 1 and s.hand.size() == 3)
	_assert_has(evs_summon, "summon_rejected")
	s.restart()
	s.attack_index = 1
	s._begin_attack()
	s.attack_elapsed = 0.82 - 0.04
	s.submit({"type": "defend"})
	assert(s.queued_defense == BattleSimulationScript.DefenseGrade.PERFECT)
	s.step(0.4)
	assert(s.points >= 1 and s.strike_index == 1 and s.perfects == 1 and s.rage >= 1)
	s.attack_elapsed = 1.56 - 0.14
	s.submit({"type": "defend"})
	assert(s.queued_defense == BattleSimulationScript.DefenseGrade.SUCCESS)
	s.step(0.4)
	assert(s.stagger_remaining > 0.0)
	s.step(0.4)
	s.step(0.4)
	assert(s.points >= 2 and s.points <= 3)
	if s.hand.has("shatter"):
		var shatter_before: int = s.hand.count("shatter")
		s.perfect_charge = true
		s.submit({"type": "play_card", "id": "shatter"})
		s.stagger_remaining = 0.5  # 乘势加成要求命中帧处于僵直窗口
		s.step(0.6)  # 命中帧（0.36）结算 12+6
		assert(s.enemy_hp == 46 - 18 and s.points >= 0 and not s.perfect_charge)
		assert(s.hand.count("shatter") == shatter_before - 1)
	else:
		var attack_before: int = s.hand.count("attack")
		s.submit({"type": "play_card", "id": "attack"})
		s.step(0.5)  # 命中帧结算
		assert(s.enemy_hp == 46 - 5 and s.points >= 0)
		assert(s.hand.count("attack") == attack_before - 1)
	if s.points >= BattleSimulationScript.SUMMON_COST and s.hand.size() < BattleSimulationScript.HAND_SIZE:
		var hand_before: int = s.hand.size()
		var pts_before: int = s.points
		var evs2: Array = s.submit({"type": "summon"})
		assert(s.hand.size() == hand_before + 1 and s.points == pts_before - BattleSimulationScript.SUMMON_COST)
		_assert_has(evs2, "card_summoned")
	s.restart()
	s.attack_index = 2
	s._begin_attack()
	s.attack_elapsed = 1.2
	s.step(0.05)
	s.submit({"type": "defend"})
	assert(s.queued_defense == BattleSimulationScript.DefenseGrade.NONE and s.defense_cooldown > 0.0)
	s.defense_cooldown = 0.0
	s.points = 2
	if s.hand.has("guard"):
		var evs_green: Array = s.submit({"type": "play_card", "id": "guard"})
		evs_green.append_array(s.step(0.5))  # 命中帧（0.18）结算：斩断鬼手
		assert(s.state == BattleSimulationScript.BattleState.RESOLVING and s.player_hp == BattleSimulationScript.PLAYER_MAX_HP)
		_assert_has(evs_green, "grab_cancelled")
	else:
		s.step(1.0)
		assert(s.player_hp == BattleSimulationScript.PLAYER_MAX_HP - int(s.current_intent.damage))
	var s2 := BattleSimulationScript.new()
	s2.enemy_id = "lantern_imp"
	s2.restart()
	assert(s2.current_intent.id == "quick" and s2.enemy_name == "灯笼小鬼" and s2.enemy_hp == 30)
	s2.points = 9
	s2.attack_index = 1
	s2._begin_attack()
	var picked := String(s2.current_intent.id)
	assert(picked != "quick" and (picked == "green" or picked == "red"))
	assert(s2._move_weight("quick") <= 0.2)
	assert(String(s2.last_move_id) == picked and s2.rage >= 1)
	var other := "green" if picked == "red" else "red"
	assert(s2._move_weight(other) >= 0.4)
	print("SMOKE_TEST_OK: simulation, unblockable grab, stagger window, cards, summons, reactive enemies")
	s.battle_generation += 1
	await get_tree().create_timer(0.4, true, false, true).timeout
	for tween in get_tree().get_processed_tweens():
		tween.kill()
	for player: AudioStreamPlayer in [view.parry_audio, view.hurt_audio, view.card_audio, view.warning_audio]:
		player.stop()
	GameTime.reset()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0)


func _assert_has(events: Array, type: String) -> void:
	for event: Dictionary in events:
		if String(event.get("type", "")) == type:
			return
	assert(false)
