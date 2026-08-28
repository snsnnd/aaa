extends Node2D

## 组合根：创建模拟层与表现层、路由输入与事件。
## 规则在 BattleSimulation，世界表现在 BattleView，UI 在 BattleHud。

const BattleSimulationScript := preload("res://scripts/battle/battle_simulation.gd")
const BattleViewScript := preload("res://scripts/presentation/battle_view.gd")
const BattleHudScript := preload("res://scripts/presentation/battle_hud.gd")

var sim: BattleSimulationScript
var view: BattleViewScript
var hud: BattleHudScript

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
var attack_trail: Line2D:
	get:
		return view.attack_trail
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
	hud.setup(sim, _submit, _restart_battle)
	_apply_attack_presentation()
	if "--smoke-test" in OS.get_cmdline_user_args():
		call_deferred("_run_smoke_test")


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _process(delta: float) -> void:
	if hud.menu_open:
		return
	view.tick(delta)
	for event: Dictionary in sim.step(delta):
		_handle_event(event)


func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	if not event.pressed or event.echo:
		return
	if _handle_shortcut(event.keycode):
		get_viewport().set_input_as_handled()


func _handle_shortcut(keycode: Key) -> bool:
	if hud.menu_open:
		match keycode:
			KEY_ESCAPE:
				hud.toggle_menu()
			KEY_R:
				_restart_battle()
			_:
				return false
		return true
	match keycode:
		KEY_1:
			_play_hand_slot(0)
		KEY_2:
			_play_hand_slot(1)
		KEY_3:
			_play_hand_slot(2)
		KEY_4:
			_play_hand_slot(3)
		KEY_5:
			_submit({"type": "summon"})
		KEY_SPACE:
			_submit({"type": "defend"})
		KEY_ESCAPE:
			hud.toggle_menu()
		KEY_R:
			_restart_battle()
		_:
			return false
	return true


func _play_hand_slot(slot: int) -> void:
	if slot >= 0 and slot < sim.hand.size():
		_submit({"type": "play_card", "id": sim.hand[slot]})


func _submit(command: Dictionary) -> void:
	for event: Dictionary in sim.submit(command):
		_handle_event(event)


func _handle_event(event: Dictionary) -> void:
	match String(event.get("type", "")):
		"attack_started":
			_apply_attack_presentation()
			hud.refresh()
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
			hud.show_message("鬼手被斩断！", Color("7fc5cd"), 0.8)
		"card_played":
			_present_card(event)
			hud.rebuild_pile_view()
		"card_summoned":
			view.pulse_glow(0.5)
			view.summon_vfx(String(event.id))
			hud.show_message("召符·%s" % BattleSimulationScript.CARD_DATA[String(event.id)].title, Color("f2d487"), 0.7)
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
			hud.flash(Color(1.0, 0.88, 0.56), 0.68, 0.18)
			hud.show_message("完美接刀｜还愿 +2", Color("f2d487"), 0.8)
		_:
			view.take_hit(int(event.damage))
			hud.flash(Color(0.75, 0.08, 0.08), 0.30, 0.22)
			hud.show_message("灯油 -%d" % int(event.damage), Color("d85151"), 0.75)
	hud.refresh()


func _present_card(event: Dictionary) -> void:
	view.play_card_sfx()
	var id := String(event.id)
	view.spawn_talisman(id)
	var data: Dictionary = BattleSimulationScript.CARD_DATA[id]
	match id:
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
		"dengxin":
			view.embers()
			view.pulse_glow(0.35)
		"zhuangzhong":
			view.bell_wave()
	if id == "shift":
		if int(event.healed) > 0:
			hud.show_message("续灯｜灯油 +%d" % int(event.healed), data.color, 0.7)
		else:
			hud.show_message("灯火已盈", data.color, 0.5)
	elif id == "shatter" and bool(event.get("charged", false)):
		view.small_enemy_hit(0.32)
		hud.show_message("还刃·乘势｜怨气 -%d" % int(event.damage), data.color, 0.8)
	elif id == "guard":
		hud.show_message("镇煞｜怨气 -%d，鬼招凝滞" % int(event.damage), data.color, 0.7)
	else:
		view.small_enemy_hit(0.16)
		hud.show_message("%s｜散去 %d 点怨气" % [data.title, int(event.damage)], data.color, 0.6)
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


func apply_run_config(enemy_id: String, deck: Array) -> void:
	sim.enemy_id = enemy_id
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
	hud.close_menu()
	hud.hide_settlement()
	view.restart_fx()
	sim.restart()
	_apply_attack_presentation()
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
	assert(s.points == 1 and s.player_hp == BattleSimulationScript.PLAYER_MAX_HP)
	_assert_has(events, "impact")
	events = s.submit({"type": "play_card", "id": "attack"})
	assert(s.points == 0 and s.enemy_hp == 41)
	assert(not s.hand.has("attack") and s.hand.size() == 3)
	var evs_summon: Array = s.submit({"type": "summon"})
	assert(s.points == 0 and s.hand.size() == 3)
	_assert_has(evs_summon, "summon_rejected")
	s.restart()
	s.attack_index = 1
	s._begin_attack()
	s.attack_elapsed = 0.82 - 0.04
	s.submit({"type": "defend"})
	assert(s.queued_defense == BattleSimulationScript.DefenseGrade.PERFECT)
	s.step(0.4)
	assert(s.points == 2 and s.strike_index == 1 and s.perfects == 1)
	s.attack_elapsed = 1.56 - 0.14
	s.submit({"type": "defend"})
	assert(s.queued_defense == BattleSimulationScript.DefenseGrade.SUCCESS)
	s.step(0.4)
	assert(s.points == 2 and s.stagger_remaining > 0.0)
	s.step(0.4)
	assert(s.points == 2)
	s.step(0.4)
	assert(s.points == 3)
	if s.hand.has("shatter"):
		var shatter_before: int = s.hand.count("shatter")
		s.perfect_charge = true
		s.submit({"type": "play_card", "id": "shatter"})
		assert(s.enemy_hp == 46 - 18 and s.points == 0 and not s.perfect_charge)
		assert(s.hand.count("shatter") == shatter_before - 1)
	else:
		var attack_before: int = s.hand.count("attack")
		s.submit({"type": "play_card", "id": "attack"})
		assert(s.enemy_hp == 46 - 5 and s.points == 2)
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
	assert(s2._move_weight(picked) == 0.0 and s2._move_weight("quick") >= 1.0)
	print("SMOKE_TEST_OK: simulation, unblockable grab, stagger window, cards, summons, reactive enemies")
	s.battle_generation += 1
	await get_tree().create_timer(0.4, true, false, true).timeout
	for tween in get_tree().get_processed_tweens():
		tween.kill()
	for player: AudioStreamPlayer in [view.parry_audio, view.hurt_audio, view.card_audio, view.warning_audio]:
		player.stop()
	Engine.time_scale = 1.0
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0)


func _assert_has(events: Array, type: String) -> void:
	for event: Dictionary in events:
		if String(event.get("type", "")) == type:
			return
	assert(false)
