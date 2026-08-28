extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const OUTPUT_DIR := "res://validation"

var demo: Node
var checks: Array[Dictionary] = []
var captures: Array[Dictionary] = []
var all_ok := true


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	demo = MAIN_SCENE.instantiate()
	root.add_child(demo)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

	_check("viewport_is_1280x720", root.get_visible_rect().size == Vector2(1280, 720))
	_check("starts_in_automatic_windup", demo.sim.state == demo.sim.BattleState.WINDUP and demo.sim.current_intent.id == "red")
	_check("hand_has_four_slots", demo.sim.hand.size() == 4 and demo.card_buttons.size() == 4)
	_check("cards_inside_viewport", _cards_inside_viewport())
	_check("separate_weapon_is_loaded", demo.weapon_sprite.texture != null)
	_check("cards_have_point_costs", int(demo.sim.CARD_DATA.attack.cost) == 1 and int(demo.sim.CARD_DATA.shatter.cost) == 2 and int(demo.sim.CARD_DATA.guard.cost) == 2 and int(demo.sim.CARD_DATA.shift.cost) == 2)
	_check("unaffordable_hand_card_locked", demo.sim.points == 0 and demo.card_buttons[0].disabled == (int(demo.sim.CARD_DATA[demo.sim.hand[0]].cost) > 0))
	_check("precision_progress_bar_removed", not _contains_progress_bar(demo))
	var player_y_before: float = demo.player_sprite.position.y
	var background_x_before: float = demo.background.position.x
	var rain_y_before: float = demo.rain_drops[0].position.y
	var attack_elapsed_before: float = demo.sim.attack_elapsed
	await create_timer(0.32).timeout
	_check("character_idle_animates", absf(demo.player_sprite.position.y - player_y_before) > 0.05)
	_check("background_drift_animates", absf(demo.background.position.x - background_x_before) > 0.01)
	_check("rain_animates", absf(demo.rain_drops[0].position.y - rain_y_before) > 10.0)
	_check("attack_advances_without_input", demo.sim.attack_elapsed > attack_elapsed_before + 0.20)

	await _send_key(KEY_SPACE)
	_check("early_defense_starts_cooldown", demo.sim.defense_cooldown > 0.60 and demo.sim.queued_defense == demo.sim.DefenseGrade.NONE)
	var cooldown_before: float = demo.sim.defense_cooldown
	await _send_key(KEY_SPACE)
	_check("cooldown_blocks_repeat_defense", demo.sim.defense_cooldown <= cooldown_before and demo.sim.queued_defense == demo.sim.DefenseGrade.NONE)
	await _capture("01_continuous_cooldown")

	_check("red_window_reached", await _wait_for_attack(0, float(demo.sim.current_intent.duration) - 0.20))
	await process_frame
	await RenderingServer.frame_post_draw
	_check("red_commit_is_body_readable", demo.enemy_sprite.position.x < 980.0 and demo.weapon_pivot.rotation > -1.1)
	_check("red_commit_pose_reached", demo.weapon_pivot.rotation > -1.1 and demo.enemy_sprite.position.x < 980.0)
	await _capture("02_red_commit_pose")

	await _send_key(KEY_SPACE)
	_check("space_queues_unified_success", demo.sim.queued_defense == demo.sim.DefenseGrade.SUCCESS)
	_check("red_impact_resolves", await _wait_until(func(): return demo.sim.state == demo.sim.BattleState.RESOLVING))
	_check("successful_defense_grants_point", demo.sim.points >= 1 and demo.sim.points <= 2 and demo.sim.player_hp == 72)
	await RenderingServer.frame_post_draw
	await _capture("03_red_success")

	var enemy_hp_before: int = demo.sim.enemy_hp
	var attack_slot: int = demo.sim.hand.find("attack")
	_check("attack_available_in_hand", attack_slot != -1)
	await _send_key(KEY_1 + attack_slot)
	_check("card_spends_defense_point", demo.sim.points <= 1 and demo.sim.enemy_hp == enemy_hp_before - 5)

	_check("blue_attack_starts_automatically", await _wait_for_attack(1, 0.0))
	_check("blue_first_window_reached", await _wait_for_attack(1, 0.78))
	_check("blue_first_strike_animates", demo.weapon_pivot.rotation > -0.6 and demo.enemy_sprite.position.x < 995.0)
	await _send_key(KEY_SPACE)
	_check("blue_first_uses_same_defense", demo.sim.queued_defense == demo.sim.DefenseGrade.PERFECT)
	_check("blue_first_impact_resolves", await _wait_until(func(): return demo.sim.attack_index == 1 and demo.sim.strike_index == 1))
	_check("perfect_defense_grants_point_and_rage", demo.sim.points >= 1 and demo.sim.points <= 2 and demo.sim.rage >= 1)
	_check("blue_second_window_reached", await _wait_for_attack(1, 1.40))
	_check("blue_second_strike_animates", demo.weapon_pivot.rotation > -0.6 and demo.enemy_sprite.position.x < 995.0)
	await _capture("04_blue_second_strike")
	await _send_key(KEY_SPACE)
	_check("blue_second_uses_same_defense", demo.sim.queued_defense == demo.sim.DefenseGrade.SUCCESS)
	_check("blue_combo_resolves", await _wait_until(func(): return demo.sim.state == demo.sim.BattleState.RESOLVING))
	_check("blue_combo_builds_points", demo.sim.points >= 2 and demo.sim.points <= 3)

	enemy_hp_before = demo.sim.enemy_hp
	var heavy_id: String = "shatter" if demo.sim.hand.has("shatter") else "attack"
	var heavy_slot: int = demo.sim.hand.find(heavy_id)
	var heavy_cost: int = int(demo.sim.CARD_DATA[heavy_id].cost)
	var heavy_damage: int = 12 if heavy_id == "shatter" else 5
	_check("hand_card_available", heavy_slot != -1)
	await _send_key(KEY_1 + heavy_slot)
	_check("hand_card_spends_points", demo.sim.points >= 2 - heavy_cost and demo.sim.points <= 3 - heavy_cost and demo.sim.enemy_hp == enemy_hp_before - heavy_damage)
	await _capture("05_point_card_play")

	if demo.sim.points >= 2 and demo.sim.hand.size() < 4:
		var hand_before: int = demo.sim.hand.size()
		var points_before: int = demo.sim.points
		await _send_key(KEY_5)
		_check("summon_draws_from_piles", demo.sim.hand.size() == hand_before + 1 and demo.sim.points == points_before - 2)
		await _capture("07_summon_talisman")
	else:
		_check("summon_pool_available", demo.sim.draw_pile.size() + demo.sim.discard_pile.size() > 0)

	_check("green_attack_starts_automatically", await _wait_for_attack(2, 0.0))
	_check("green_reveal_reached", await _wait_for_attack(2, float(demo.sim.current_intent.duration) - 0.18))
	_check("green_grab_replaces_fake_blade", demo.ghost_hand.visible and demo.ghost_hand.scale.x > 0.7)
	var guard_slot: int = demo.sim.hand.find("guard")
	if guard_slot != -1 and demo.sim.points >= 2:
		await _send_key(KEY_1 + guard_slot)
		_check("guard_cancels_grab", demo.sim.state == demo.sim.BattleState.RESOLVING and demo.sim.player_hp == 72)
		await _capture("06_green_grab_interrupted")
	else:
		await _capture("06_green_grab_reveal")
		await _send_key(KEY_SPACE)
		_check("green_unblockable", demo.sim.queued_defense == demo.sim.DefenseGrade.NONE and demo.sim.defense_cooldown > 0.5)
		_check("green_grab_resolves", await _wait_until(func(): return demo.sim.state == demo.sim.BattleState.RESOLVING))
		_check("green_grab_deals_damage", demo.sim.player_hp < 72)

	_write_report()
	print("VISUAL_TEST_%s: %d checks, %d captures -> %s" % ["OK" if all_ok else "FAILED", checks.size(), captures.size(), ProjectSettings.globalize_path(OUTPUT_DIR)])
	await create_timer(0.45, true, false, true).timeout
	demo.queue_free()
	await process_frame
	quit(0 if all_ok else 1)


func _send_key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame


func _wait_for_attack(index: int, target: float, timeout := 5.0) -> bool:
	return await _wait_until(func():
		return demo.sim.attack_index == index and demo.sim.state == demo.sim.BattleState.WINDUP and demo.sim.attack_elapsed >= target,
		timeout
	)


func _wait_until(condition: Callable, timeout := 5.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000.0)
	while not condition.call():
		if Time.get_ticks_msec() >= deadline:
			return false
		await process_frame
	return true


func _cards_inside_viewport() -> bool:
	var bounds := Rect2(Vector2.ZERO, Vector2(1280, 720))
	for id in demo.card_buttons:
		var button: Button = demo.card_buttons[id]
		if not bounds.encloses(button.get_global_rect()):
			return false
	return true


func _contains_progress_bar(node: Node) -> bool:
	if node is ProgressBar:
		return true
	for child in node.get_children():
		if _contains_progress_bar(child):
			return true
	return false


func _check(name: String, passed: bool) -> void:
	checks.append({"name": name, "passed": passed})
	if not passed:
		all_ok = false
		printerr("VALIDATION FAILED: ", name)


func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [OUTPUT_DIR, name]
	var error := image.save_png(path)
	var metrics := _image_metrics(image)
	metrics["name"] = name
	metrics["path"] = ProjectSettings.globalize_path(path)
	metrics["saved"] = error == OK
	captures.append(metrics)
	_check("capture_%s_saved" % name, error == OK)
	_check("capture_%s_not_black" % name, float(metrics.average_luminance) > 0.025)


func _image_metrics(image: Image) -> Dictionary:
	var luminance := 0.0
	var red_pixels := 0
	var cyan_pixels := 0
	var green_pixels := 0
	var count := 0
	for y in range(0, image.get_height(), 8):
		for x in range(0, image.get_width(), 8):
			var color := image.get_pixel(x, y)
			luminance += color.get_luminance()
			red_pixels += 1 if color.r > color.g * 1.35 and color.r > color.b * 1.25 and color.r > 0.28 else 0
			cyan_pixels += 1 if color.g > color.r * 1.25 and color.b > color.r * 1.25 and color.g > 0.30 else 0
			green_pixels += 1 if color.g > color.r * 1.18 and color.g > color.b * 1.05 and color.g > 0.28 else 0
			count += 1
	return {
		"width": image.get_width(),
		"height": image.get_height(),
		"average_luminance": luminance / maxf(1.0, float(count)),
		"sampled_red_pixels": red_pixels,
		"sampled_cyan_pixels": cyan_pixels,
		"sampled_green_pixels": green_pixels,
	}


func _write_report() -> void:
	var report := {
		"ok": all_ok,
		"engine": Engine.get_version_info().string,
		"checks": checks,
		"captures": captures,
	}
	var file := FileAccess.open("%s/report.json" % OUTPUT_DIR, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "  "))
