extends Node2D

## 敌人动画：三套敌招编排、收招回落、受击与凝滞表现。

const BattleSimulationScript := preload("res://scripts/battle/battle_simulation.gd")
const FxState := preload("res://scripts/presentation/fx_state.gd")
const PresentationCatalog := preload("res://scripts/presentation/presentation_catalog.gd")
const CharacterStateMachineScript := preload("res://assets/game/character_showcase/scripts/character_state_machine.gd")
const CharacterAnimProfileScript := preload("res://assets/game/character_showcase/scripts/character_anim_profile.gd")

var enemy_sprite: Sprite2D
var weapon_pivot: Node2D
var weapon_sprite: Sprite2D
var ghost_hand: Node2D
var enemy_aura: Sprite2D
var fx: FxState
var state_machine: CharacterStateMachine
var anim_profile: CharacterAnimProfile


func setup(state: FxState) -> void:
	fx = state
	state_machine = CharacterStateMachineScript.new()
	add_child(state_machine)
	state_machine.setup(self)
	_load_profile()
	enemy_sprite = Sprite2D.new()
	enemy_sprite.position = Vector2(1006, 350)
	enemy_sprite.scale = Vector2(0.49, 0.49)
	enemy_sprite.z_index = 10
	add_child(enemy_sprite)

	weapon_pivot = Node2D.new()
	weapon_pivot.position = enemy_sprite.position + Vector2(38, -28)
	weapon_pivot.rotation = -0.45
	weapon_pivot.z_index = 12
	add_child(weapon_pivot)
	weapon_sprite = Sprite2D.new()
	weapon_sprite.position = Vector2(0, 98)
	weapon_sprite.scale = Vector2(0.49, 0.49)
	weapon_pivot.add_child(weapon_sprite)

	ghost_hand = _create_ghost_hand()
	ghost_hand.position = enemy_sprite.position + Vector2(-6, -8)
	ghost_hand.visible = false
	ghost_hand.z_index = 13
	add_child(ghost_hand)

	enemy_aura = Sprite2D.new()
	enemy_aura.visible = false
	add_child(enemy_aura)


func _make_glow_texture(color: Color) -> ImageTexture:
	var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in 128:
		for x in 128:
			var distance := Vector2(x - 63.5, y - 63.5).length() / 63.5
			var alpha := pow(maxf(0.0, 1.0 - distance), 2.4) * color.a
			image.set_pixel(x, y, Color(color.r, color.g, color.b, alpha))
	return ImageTexture.create_from_image(image)


func _create_ghost_hand() -> Node2D:
	var hand := Node2D.new()
	var palm := Polygon2D.new()
	palm.polygon = PackedVector2Array([Vector2(-72, -34), Vector2(-118, -24), Vector2(-140, 2), Vector2(-112, 30), Vector2(-68, 28), Vector2(-48, 0)])
	palm.color = Color(0.30, 0.55, 0.36, 0.72)
	hand.add_child(palm)
	for i in 4:
		var finger := Line2D.new()
		var y := -25.0 + i * 16.0
		finger.points = PackedVector2Array([Vector2(-105, y), Vector2(-166 - i * 8, y - 18 + i * 9)])
		finger.width = 10.0 - i * 0.8
		finger.default_color = Color(0.42, 0.68, 0.44, 0.78)
		finger.begin_cap_mode = Line2D.LINE_CAP_ROUND
		finger.end_cap_mode = Line2D.LINE_CAP_ROUND
		hand.add_child(finger)
	return hand


func _load_profile() -> void:
	var path := "res://assets/game/character_showcase/profiles/profile_%s.tres" % enemy_id_for_profile()
	if ResourceLoader.exists(path):
		anim_profile = load(path)
	else:
		anim_profile = CharacterAnimProfileScript.new()


func enemy_id_for_profile() -> String:
	return get_parent().sim.enemy_id if get_parent() and get_parent().get("sim") else "watchman"


func load_style(folder: String) -> void:
	weapon_sprite.texture = load("res://assets/%s/enemy_blade.png" % folder)
	weapon_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	load_enemy_texture("watchman")


func load_enemy_texture(id: String) -> void:
	enemy_sprite.texture = load(PresentationCatalog.ENEMY_PRESENTATION[id].texture)
	enemy_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_load_profile()
	# 仅前任更夫使用独立敌刃，其余怪物使用内置专属武器/法术
	weapon_pivot.visible = (id == "watchman")


func sim() -> BattleSimulationScript:
	return get_parent().sim


func apply_presentation() -> void:
	weapon_sprite.modulate = Color.WHITE
	ghost_hand.visible = false
	reset_pose()


func reset_pose() -> void:
	enemy_sprite.position = Vector2(1006, 350)
	enemy_sprite.rotation = 0.0
	weapon_pivot.position = enemy_sprite.position + Vector2(38, -28)
	weapon_pivot.rotation = -0.45
	weapon_sprite.modulate = Color.WHITE
	ghost_hand.position = enemy_sprite.position + Vector2(-6, -8)
	ghost_hand.scale = Vector2.ONE
	ghost_hand.modulate = Color.WHITE
	ghost_hand.visible = false
	var eid := enemy_id_for_profile()
	weapon_pivot.visible = (eid == "watchman")


func finish_action_fx() -> void:
	ghost_hand.visible = false


func commit_flash(color: Color) -> void:
	weapon_sprite.modulate = Color("fff1bd")
	var tween := create_tween().set_ignore_time_scale(true).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(weapon_sprite, "modulate", Color.WHITE, 0.16)
	if sim().current_intent.id == "green" and ghost_hand.visible:
		ghost_hand.modulate = color.lightened(0.35)
		create_tween().set_ignore_time_scale(true).tween_property(ghost_hand, "modulate", Color.WHITE, 0.18)


func fake_release() -> void:
	weapon_sprite.modulate = Color("cf4b4f")
	create_tween().set_ignore_time_scale(true).tween_property(weapon_sprite, "modulate", Color.WHITE, 0.20).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func snap_ghost_hand_back() -> void:
	if not ghost_hand.visible:
		return
	var back := enemy_sprite.position + Vector2(-6, -8)
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(ghost_hand, "position", back, 0.16)
	tw.tween_property(ghost_hand, "scale", Vector2(0.3, 0.6), 0.16)
	tw.chain().tween_callback(func(): ghost_hand.visible = false)


func small_hit() -> void:
	enemy_sprite.modulate = Color("ffd59a")
	create_tween().tween_property(enemy_sprite, "modulate", Color.WHITE, 0.18).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	var original_scale := enemy_sprite.scale
	var recoil: float = anim_profile.hit_recoil_px if anim_profile else 20.0
	var tilt: float = anim_profile.hit_tilt_rad if anim_profile else 0.08
	enemy_sprite.scale = original_scale * Vector2(1.0 + recoil * 0.003, 1.0 - recoil * 0.002)
	enemy_sprite.position.x += recoil * 0.15
	create_tween().tween_property(enemy_sprite, "scale", original_scale, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	create_tween().tween_property(enemy_sprite, "position:x", enemy_sprite.position.x - recoil * 0.15, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func parry_squash() -> void:
	var original_scale := enemy_sprite.scale
	enemy_sprite.scale = original_scale * Vector2(1.08, 0.92)
	create_tween().tween_property(enemy_sprite, "scale", original_scale, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func staggered_fx() -> void:
	enemy_sprite.modulate = Color("ffe9b0")
	create_tween().tween_property(enemy_sprite, "modulate", Color.WHITE, 0.5)


func death_dissolve() -> void:
	enemy_sprite.modulate = Color("cfeef0")
	create_tween().tween_property(enemy_sprite, "modulate:a", 0.0, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func tick(delta: float) -> void:
	var s := sim()
	if state_machine:
		_sync_phase(s)
		state_machine.update(delta)
	if s.state == BattleSimulationScript.BattleState.WINDUP:
		_update_attack_visuals()
		if s.stagger_remaining > 0.0:
			weapon_pivot.rotation = lerpf(weapon_pivot.rotation, 0.62, minf(1.0, delta * 6.0))
			enemy_sprite.rotation = lerpf(enemy_sprite.rotation, 0.06, minf(1.0, delta * 6.0))
	else:
		var settle := minf(1.0, delta * 8.0)
		enemy_sprite.position.x = lerpf(enemy_sprite.position.x, 1006.0 + fx.enemy_push, settle)
		enemy_sprite.rotation = lerpf(enemy_sprite.rotation, 0.0, settle)
		weapon_pivot.position = weapon_pivot.position.lerp(enemy_sprite.position + Vector2(38, -28), settle)
		weapon_pivot.rotation = lerpf(weapon_pivot.rotation, -0.45, settle)
		if s.state != BattleSimulationScript.BattleState.RESOLVING:
			enemy_sprite.position.y = 350.0 + sin(get_parent().view_time() * 1.22 + 1.7) * 5.0
			weapon_pivot.rotation += sin(get_parent().view_time() * 0.88 + 0.7) * -0.006


func _sync_phase(s) -> void:
	if s.state != BattleSimulationScript.BattleState.WINDUP:
		if state_machine.current_state != state_machine.State.IDLE:
			state_machine.transition_to(state_machine.State.IDLE)
		return
	var phases: Array = s.current_intent.get("phases", [])
	if phases.is_empty():
		return
	var elapsed: float = s.attack_elapsed
	var is_staggered: bool = s.stagger_remaining > 0.0
	var current_phase := ""
	var progress := 0.0
	for i in phases.size():
		if elapsed < float(phases[i].until):
			current_phase = String(phases[i].name)
			var prev := 0.0
			if i > 0:
				prev = float(phases[i - 1].until)
			progress = (elapsed - prev) / maxf(0.01, float(phases[i].until) - prev)
			break
	if current_phase == "":
		current_phase = "recover"
		progress = 1.0
	state_machine.sync_move_phase(current_phase, progress, is_staggered)


func _update_attack_visuals() -> void:
	var s := sim()
	var mid := String(s.current_intent.id)
	var anim_cfg: Dictionary = PresentationCatalog.MOVE_ANIMATIONS.get(mid, PresentationCatalog.MOVE_ANIMATIONS["red"])
	var duration: float = s.current_intent.duration
	var ratio := clampf(s.attack_elapsed / duration, 0.0, 1.0)
	
	match String(anim_cfg.get("type", "delayed_strike")):
		"delayed_strike":
			_eval_delayed_strike(anim_cfg, ratio)
		"combo_strikes":
			_eval_combo_strikes(anim_cfg, ratio)
		"grab_reach":
			_eval_grab_reach(anim_cfg, ratio)


func _eval_delayed_strike(cfg: Dictionary, ratio: float) -> void:
	var r_end: float = float(cfg.get("raise_end", 0.36))
	var h_end: float = float(cfg.get("hold_end", 0.82))
	var w_rots: Array = cfg.get("weapon_rot", [-0.45, -2.25, 1.40])
	var b_xs: Array = cfg.get("body_x", [1006.0, 1020.0, 580.0])
	var b_rots: Array = cfg.get("body_rot", [0.0, 0.04, -0.16])
	
	if ratio < r_end:
		var raise := smoothstep(0.0, r_end, ratio)
		weapon_pivot.rotation = lerpf(float(w_rots[0]), float(w_rots[1]), raise)
		enemy_sprite.position.x = lerpf(float(b_xs[0]), float(b_xs[1]), raise)
		enemy_sprite.rotation = lerpf(float(b_rots[0]), float(b_rots[1]), raise)
	elif ratio < h_end:
		var hold := (ratio - r_end) / (h_end - r_end)
		weapon_pivot.rotation = float(w_rots[1]) + sin(hold * PI * 8.0) * 0.015
		enemy_sprite.position.x = float(b_xs[1]) + sin(hold * PI * 6.0) * 1.0
		enemy_sprite.rotation = float(b_rots[1]) + sin(hold * PI * 6.0) * 0.003
	else:
		var strike_progress := (ratio - h_end) / (1.0 - h_end)
		var snap := ease(clampf(strike_progress, 0.0, 1.0), 0.25)
		weapon_pivot.rotation = lerpf(float(w_rots[1]), float(w_rots[2]), snap)
		enemy_sprite.position.x = lerpf(float(b_xs[1]), float(b_xs[2]), snap)
		enemy_sprite.rotation = lerpf(float(b_rots[1]), float(b_rots[2]), snap)

	weapon_pivot.position = enemy_sprite.position + Vector2(38, -28)


func _eval_combo_strikes(cfg: Dictionary, _ratio: float) -> void:
	var s := sim()
	var strikes: Array = s.current_intent.strikes
	var idx: int = clampi(s.strike_index, 0, strikes.size() - 1)
	var strike_time := float(strikes[idx])
	var start_time := 0.0 if idx == 0 else float(strikes[idx - 1])
	var phase := clampf((s.attack_elapsed - start_time) / maxf(0.01, strike_time - start_time), 0.0, 1.0)
	
	var r_end: float = float(cfg.get("raise_end", 0.70))
	var w_rots: Array = cfg.get("weapon_rot", [-0.45, -1.75, 1.25])
	var b_xs: Array = cfg.get("body_x", [1006.0, 1015.0, 560.0])
	var b_rots: Array = cfg.get("body_rot", [0.0, 0.02, -0.12])
	
	if phase < r_end:
		var raise := smoothstep(0.0, r_end, phase)
		weapon_pivot.rotation = lerpf(0.35 if s.strike_index > 0 else float(w_rots[0]), float(w_rots[1]), raise)
		enemy_sprite.position.x = lerpf(float(b_xs[0]), float(b_xs[1]), raise)
		enemy_sprite.rotation = float(b_rots[1])
	else:
		var snap := ease((phase - r_end) / (1.0 - r_end), 0.3)
		weapon_pivot.rotation = lerpf(float(w_rots[1]), float(w_rots[2]), snap)
		enemy_sprite.position.x = lerpf(float(b_xs[1]), float(b_xs[2]), snap)
		enemy_sprite.rotation = lerpf(float(b_rots[1]), float(b_rots[2]), snap)
		
	weapon_pivot.position = enemy_sprite.position + Vector2(38, -28)


func _eval_grab_reach(cfg: Dictionary, ratio: float) -> void:
	var c_point: float = float(cfg.get("cancel_point", 0.60))
	var w_rots: Array = cfg.get("weapon_rot", [-0.45, -2.02, -0.20])
	var b_xs: Array = cfg.get("body_x", [1006.0, 760.0])
	var reach_vec: Vector2 = cfg.get("hand_reach", Vector2(-540, -18))
	
	if ratio < c_point * 0.7:
		var fake_raise := smoothstep(0.0, c_point * 0.7, ratio)
		weapon_pivot.rotation = lerpf(float(w_rots[0]), float(w_rots[1]), fake_raise)
		enemy_sprite.rotation = fake_raise * 0.04
		ghost_hand.visible = false
	elif ratio < c_point:
		var cancel := smoothstep(c_point * 0.7, c_point, ratio)
		weapon_pivot.rotation = lerpf(float(w_rots[1]), float(w_rots[2]), cancel)
		enemy_sprite.rotation = lerpf(0.04, -0.02, cancel)
		ghost_hand.visible = cancel > 0.62
		ghost_hand.position = enemy_sprite.position + Vector2(-6, -8)
		ghost_hand.scale = Vector2(0.55, 0.8)
	else:
		var reach_prog := (ratio - c_point) / (1.0 - c_point)
		var snap := ease(reach_prog, 0.4)
		weapon_pivot.rotation = float(w_rots[2])
		enemy_sprite.position.x = lerpf(float(b_xs[0]), float(b_xs[1]), snap)
		enemy_sprite.rotation = lerpf(-0.02, -0.09, snap)
		ghost_hand.visible = true
		ghost_hand.position = enemy_sprite.position.lerp(enemy_sprite.position + reach_vec, snap)
		ghost_hand.scale = Vector2(lerpf(0.55, 1.3, snap), lerpf(0.8, 1.0, snap))
	weapon_pivot.position = enemy_sprite.position + Vector2(38, -28)
