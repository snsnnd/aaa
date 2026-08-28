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
var attack_trail: Line2D
var enemy_aura: Sprite2D
var fx: FxState
var state_machine: CharacterStateMachine
var anim_profile: CharacterAnimProfile


func setup(state: FxState) -> void:
	fx = state
	state_machine = CharacterStateMachineScript.new()
	add_child(state_machine)
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
	enemy_aura.texture = _make_glow_texture(Color(0.15, 0.62, 0.66, 0.25))
	enemy_aura.position = enemy_sprite.position + Vector2(-12, -30)
	enemy_aura.scale = Vector2(2.8, 3.4)
	var aura_material := CanvasItemMaterial.new()
	aura_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	enemy_aura.material = aura_material
	enemy_aura.z_index = 0
	add_child(enemy_aura)

	attack_trail = Line2D.new()
	attack_trail.position = Vector2(1008, 310)
	attack_trail.points = PackedVector2Array([Vector2.ZERO, Vector2(-205, 0)])
	attack_trail.width = 18.0
	attack_trail.default_color = Color("bd3d45")
	attack_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	attack_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	attack_trail.visible = false
	attack_trail.z_index = 11
	add_child(attack_trail)


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
	var color: Color = PresentationCatalog.MOVE_PRESENTATION[String(sim().current_intent.id)].color
	attack_trail.visible = false
	attack_trail.points = PackedVector2Array([Vector2.ZERO, Vector2(-205, 0)])
	attack_trail.modulate = Color.WHITE
	attack_trail.default_color = color
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
	attack_trail.visible = false
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
	create_tween().tween_property(enemy_aura, "modulate:a", 0.0, 1.1)


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
	enemy_aura.position = enemy_sprite.position + Vector2(-12, -30)
	enemy_aura.modulate.a = 0.50 + sin(get_parent().view_time() * 1.8) * 0.12


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
	var duration: float = s.current_intent.duration
	var ratio := clampf(s.attack_elapsed / duration, 0.0, 1.0)
	match String(s.current_intent.id):
		"red":
			_red_slow_blade(ratio)
		"blue", "quick":
			_strike_combo(ratio)
		"green":
			_green_grab(ratio)


func _red_slow_blade(ratio: float) -> void:
	if ratio < 0.36:
		var raise := smoothstep(0.0, 0.36, ratio)
		var windup: float = anim_profile.attack_windup_px if anim_profile else 10.0
		weapon_pivot.rotation = lerpf(-0.45, -2.22, raise)
		enemy_sprite.position.x = lerpf(1006.0, 1006.0 + windup, raise)
		enemy_sprite.rotation = lerpf(0.0, 0.045, raise)
	elif ratio < 0.68:
		var hold := (ratio - 0.36) / 0.32
		weapon_pivot.rotation = -2.22 + sin(hold * PI * 7.0) * 0.018
		enemy_sprite.position.x = 1016.0 + sin(hold * PI * 5.0) * 1.5
		enemy_sprite.rotation = 0.045 + sin(hold * PI * 5.0) * 0.004
	else:
		# 真实落刀承诺帧：身体深度前冲至 610px，刀刃切入玩家身前接触点 (x=474)！
		var commit := smoothstep(0.68, 1.0, ratio)
		weapon_pivot.rotation = lerpf(-2.22, 1.45, commit)
		enemy_sprite.position.x = lerpf(1016.0, 610.0, commit)
		enemy_sprite.rotation = lerpf(0.045, -0.18, commit)
	attack_trail.visible = (ratio > 0.74 and ratio < 0.96)
	attack_trail.points = PackedVector2Array([Vector2.ZERO, Vector2(-180, 50)])
	attack_trail.position = enemy_sprite.position + Vector2(-40, -10)
	attack_trail.rotation = -0.25 # 向左前下方斩切，消除右侧竖直异常光柱
	attack_trail.width = 14.0
	attack_trail.default_color = Color("fff1bd")
	attack_trail.modulate.a = clampf((ratio - 0.74) / 0.12, 0.0, 0.85)
	weapon_pivot.position = enemy_sprite.position + Vector2(38, -28)


func _strike_combo(ratio: float) -> void:
	var s := sim()
	var strikes: Array = s.current_intent.strikes
	var idx: int = clampi(s.strike_index, 0, strikes.size() - 1)
	var strike_time := float(strikes[idx])
	var start_time := 0.0 if idx == 0 else float(strikes[idx - 1])
	var reach := 430.0 + 30.0 * float(idx) # 冲刺至 x=576，刀刃切入接触点
	var phase := clampf((s.attack_elapsed - start_time) / (strike_time - start_time), 0.0, 1.0)
	var commit := clampf((phase - 0.56) / 0.44, 0.0, 1.0)
	if phase < 0.56:
		weapon_pivot.rotation = lerpf(0.35 if s.strike_index > 0 else -0.45, -1.62, smoothstep(0.0, 0.56, phase))
	else:
		weapon_pivot.rotation = lerpf(-1.62, 1.15, smoothstep(0.0, 1.0, commit))
	enemy_sprite.position.x = 1006.0 - sin(commit * PI) * reach
	enemy_sprite.rotation = -sin(commit * PI) * 0.085
	var time_to_hit := strike_time - s.attack_elapsed
	attack_trail.visible = time_to_hit <= 0.13 and time_to_hit >= -0.05
	attack_trail.points = PackedVector2Array([Vector2.ZERO, Vector2(-160, 40)])
	attack_trail.position = enemy_sprite.position + Vector2(-30, -10)
	attack_trail.rotation = -0.2
	attack_trail.width = 12.0
	attack_trail.default_color = PresentationCatalog.MOVE_PRESENTATION[String(s.current_intent.id)].color.lightened(0.35)
	attack_trail.modulate.a = 0.75
	weapon_pivot.position = enemy_sprite.position + Vector2(38, -28)


func _green_grab(ratio: float) -> void:
	attack_trail.visible = false
	if ratio < 0.42:
		var fake_raise := smoothstep(0.0, 0.42, ratio)
		weapon_pivot.rotation = lerpf(-0.45, -2.02, fake_raise)
		enemy_sprite.rotation = fake_raise * 0.04
		ghost_hand.visible = false
	elif ratio < 0.60:
		var cancel := smoothstep(0.42, 0.60, ratio)
		weapon_pivot.rotation = lerpf(-2.02, -0.20, cancel)
		enemy_sprite.rotation = lerpf(0.04, -0.02, cancel)
		ghost_hand.visible = cancel > 0.62
		ghost_hand.position = enemy_sprite.position + Vector2(-6, -8)
		ghost_hand.scale = Vector2(0.55, 0.8)
	else:
		# 鬼手探出直达玩家胸膛！
		var reach := smoothstep(0.60, 1.0, ratio)
		weapon_pivot.rotation = -0.20
		enemy_sprite.position.x = lerpf(1006.0, 780.0, reach)
		enemy_sprite.rotation = lerpf(-0.02, -0.09, reach)
		ghost_hand.visible = true
		ghost_hand.position = enemy_sprite.position.lerp(enemy_sprite.position + Vector2(-540, -18), reach)
		ghost_hand.scale = Vector2(lerpf(0.55, 1.3, reach), lerpf(0.8, 1.0, reach))
	weapon_pivot.position = enemy_sprite.position + Vector2(38, -28)
