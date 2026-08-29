extends Node2D

## 玩家动画：呼吸、战斗姿态、受击冲量、灯晕与掷符轨迹。

const BattleSimulationScript := preload("res://scripts/battle/battle_simulation.gd")
const FxState := preload("res://scripts/presentation/fx_state.gd")
const CharacterAnimProfileScript := preload("res://assets/game/character_showcase/scripts/character_anim_profile.gd")
const PresentationCatalog := preload("res://scripts/presentation/presentation_catalog.gd")

var player_pivot: Node2D
var player_sprite: Sprite2D
var lantern_pivot: Node2D
var lantern_sprite: Sprite2D
var lantern_glow: Sprite2D
var fx: FxState
var anim_profile: CharacterAnimProfile
var pose_x := 0.0
var pose_rot := 0.0
var animation_time := 0.0
var talismans: Array[Node2D] = []
# 姿态语言通道（由 PlayerActionController 逐帧下发）
var action_pose: Dictionary = {}
var action_weight := 0.0
# 灯笼二级物理：身体位移速度驱动摆动惯性
var _lantern_spring := 0.0
var _prev_pivot_x := 0.0
var _pose_ln := 0.0  # 动作灯笼通道（_update_combat_pose 计算，tick 内叠加）


func setup(state: FxState) -> void:
	fx = state
	var prof_path := "res://assets/game/character_showcase/profiles/profile_keeper.tres"
	if ResourceLoader.exists(prof_path):
		anim_profile = load(prof_path)
	player_pivot = Node2D.new()
	player_pivot.position = Vector2(264, 355)
	player_pivot.z_index = 10
	add_child(player_pivot)
	player_sprite = Sprite2D.new()
	player_sprite.position = Vector2.ZERO
	player_sprite.scale = Vector2(0.49, 0.49)
	player_pivot.add_child(player_sprite)

	lantern_pivot = Node2D.new()
	lantern_pivot.position = Vector2(64, 40) # Hand grip anchor
	player_pivot.add_child(lantern_pivot)

	lantern_sprite = Sprite2D.new()
	lantern_sprite.position = Vector2(0, 84) # Offset from hook to lantern center
	lantern_sprite.scale = Vector2(0.49, 0.49)
	lantern_sprite.visible = false
	lantern_pivot.add_child(lantern_sprite)

	lantern_glow = Sprite2D.new()
	lantern_glow.texture = _make_glow_texture(Color(1.0, 0.42, 0.08, 0.48))
	lantern_glow.position = player_pivot.position + Vector2(64, 114)
	lantern_glow.scale = Vector2(2.35, 2.35)
	var lantern_material := CanvasItemMaterial.new()
	lantern_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	lantern_glow.material = lantern_material
	lantern_glow.z_index = 0
	add_child(lantern_glow)


func load_style(folder: String) -> void:
	var clean_body := "res://assets/game/characters_sliced/keeper_body_clean.png"
	var lantern_prop := "res://assets/game/characters_sliced/keeper_lantern_prop.png"
	if ResourceLoader.exists(clean_body) and ResourceLoader.exists(lantern_prop):
		player_sprite.texture = load(clean_body)
		lantern_sprite.texture = load(lantern_prop)
		lantern_sprite.visible = true
	else:
		player_sprite.texture = load("res://assets/%s/player_keeper.png" % folder)
		lantern_sprite.visible = false
	player_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	lantern_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func _make_glow_texture(color: Color) -> ImageTexture:
	var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in 128:
		for x in 128:
			var distance := Vector2(x - 63.5, y - 63.5).length() / 63.5
			var alpha := pow(maxf(0.0, 1.0 - distance), 2.4) * color.a
			image.set_pixel(x, y, Color(color.r, color.g, color.b, alpha))
	return ImageTexture.create_from_image(image)


func contact_point() -> Vector2:
	return player_pivot.position + Vector2(210.0, -14.0)


func guard_arc_position() -> Vector2:
	return player_pivot.position + Vector2(96, -4)


func take_hit_visual() -> void:
	fx.impulse_x = -34.0
	fx.impulse_rot = -0.13
	fx.glow_boost = -0.7
	player_sprite.modulate = Color(1.0, 0.35, 0.35)
	create_tween().tween_property(player_sprite, "modulate", Color.WHITE, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func perfect_flash() -> void:
	player_sprite.modulate = Color("fff2c4")
	create_tween().tween_property(player_sprite, "modulate", Color.WHITE, 0.24).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func death_dim() -> void:
	fx.impulse_x = -26.0
	fx.impulse_rot = -0.12
	create_tween().tween_property(player_sprite, "modulate", Color(0.6, 0.2, 0.2, 0.4), 1.0)
	create_tween().tween_property(lantern_glow, "modulate:a", 0.08, 1.0)


func cast_card_action(card_id: String) -> void:
	fx.impulse_x = 22.0
	fx.impulse_rot = 0.04
	fx.glow_boost = 0.65
	if lantern_pivot:
		lantern_pivot.rotation = -0.18
	var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(player_sprite, "scale", Vector2(0.53, 0.46), 0.08)
	tw.tween_property(player_sprite, "scale", Vector2(0.49, 0.49), 0.16)


## 动作控制器下发当前姿态通道与混合权重。
func set_action_pose(pose: Dictionary, weight: float) -> void:
	action_pose = pose
	action_weight = clampf(weight, 0.0, 1.0)


func tick(delta: float) -> void:
	animation_time += delta
	var s := sim_ref()
	var is_low_hp := s != null and s.player_hp < 25
	var bs: float = (anim_profile.breath_speed if anim_profile else 1.65) * (1.5 if is_low_hp else 1.0)
	var bh: float = (anim_profile.breath_height if anim_profile else 3.0) * (1.4 if is_low_hp else 1.0)
	var idle_tilt: float = (anim_profile.idle_tilt_angle if anim_profile else 0.006) * (2.2 if is_low_hp else 1.0)
	player_sprite.position = Vector2(0.0, sin(animation_time * bs) * bh)
	player_sprite.rotation = sin(animation_time * bs * 0.75) * idle_tilt
	_update_combat_pose(delta)
	fx.glow_boost = lerpf(fx.glow_boost, 0.0, minf(1.0, delta * 3.0))
	var flicker := sin(animation_time * 9.7) * 0.08 + sin(animation_time * 15.1) * 0.04
	if lantern_pivot and lantern_sprite.visible:
		var sway := 0.0
		if anim_profile and anim_profile.prop_sway_angle > 0.0:
			sway = sin(animation_time * anim_profile.prop_sway_freq - anim_profile.prop_lag_phase) * anim_profile.prop_sway_angle
		# 二级物理：身体水平速度驱动灯笼惯性摆动（弹簧收敛）
		var body_vel := (player_pivot.position.x - _prev_pivot_x) / maxf(0.0001, delta)
		var target := clampf(-body_vel * 0.0016, -0.55, 0.55)
		_lantern_spring = lerpf(_lantern_spring, target, minf(1.0, delta * 6.0))
		lantern_pivot.rotation = sway + _lantern_spring + _pose_ln
	_prev_pivot_x = player_pivot.position.x
	lantern_glow.position = player_pivot.position + Vector2(64, 114) + (Vector2(sin(lantern_pivot.rotation) * 45.0, 0.0) if lantern_pivot else Vector2.ZERO)
	lantern_glow.scale = Vector2.ONE * (2.35 * (1.0 + 0.38 * fx.glow_boost))
	lantern_glow.modulate.a = clampf((0.76 + flicker) * (1.0 + 0.5 * fx.glow_boost), 0.18, 1.0)
	_update_talisman_trails()


func sim_ref() -> BattleSimulationScript:
	return get_parent().sim if get_parent() and get_parent().get("sim") else null


func _update_combat_pose(delta: float) -> void:
	var guard := sim_queued() 
	var brace := false
	if sim_in_windup() and not guard:
		var ratio := clampf(sim_elapsed() / float(sim_duration()), 0.0, 1.0)
		match String(sim_intent_id()):
			"red", "green":
				brace = ratio > 0.60
			"blue":
				brace = sim_elapsed() > 0.45
	var target_x := 26.0 if guard else (12.0 if brace else 0.0)
	var target_rot := 0.05 if guard else (0.022 if brace else 0.0)
	pose_x = lerpf(pose_x, target_x, minf(1.0, delta * 12.0))
	pose_rot = lerpf(pose_rot, target_rot, minf(1.0, delta * 12.0))
	fx.impulse_x = lerpf(fx.impulse_x, 0.0, minf(1.0, delta * 6.5))
	fx.impulse_rot = lerpf(fx.impulse_rot, 0.0, minf(1.0, delta * 8.0))
	# 姿态语言通道混合（动作权重 w：起手淡入，收招淡出）
	var w := action_weight
	var rx := float(action_pose.get("rx", 0.0)) * w
	var ry := float(action_pose.get("ry", 0.0)) * w
	var rr := float(action_pose.get("rr", 0.0)) * w
	var br := float(action_pose.get("br", 0.0)) * w
	var sx := lerpf(1.0, float(action_pose.get("sx", 1.0)), w)
	var sy := lerpf(1.0, float(action_pose.get("sy", 1.0)), w)
	var ln := float(action_pose.get("ln", 0.0)) * w
	_pose_ln = ln
	player_pivot.position = Vector2(264.0 + pose_x + fx.impulse_x + rx, 355.0 + ry)
	player_pivot.rotation = pose_rot + fx.impulse_rot + rr
	player_sprite.rotation += br  # 叠加在呼吸摆动之上
	player_sprite.scale = Vector2(0.49, 0.49) * Vector2(sx, sy)


func _update_talisman_trails() -> void:
	for tal in talismans.duplicate():
		if not is_instance_valid(tal):
			talismans.erase(tal)
			continue
		var trail: Line2D = tal.get_meta("trail")
		trail.add_point(tal.position)
		if trail.get_point_count() > 14:
			trail.remove_point(0)


func spawn_talisman(id: String, card_pres: Dictionary) -> void:
	var color: Color = card_pres.color
	var tal := Node2D.new()
	tal.position = player_pivot.position + Vector2(74, 4)
	tal.z_index = 15
	var paper := Polygon2D.new()
	paper.polygon = PackedVector2Array([Vector2(-7, -11), Vector2(7, -11), Vector2(7, 11), Vector2(-7, 11)])
	paper.color = Color("efe3bd")
	tal.add_child(paper)
	var stripe := Line2D.new()
	stripe.points = PackedVector2Array([Vector2(0, -8), Vector2(0, 8)])
	stripe.width = 3.5
	stripe.default_color = color
	tal.add_child(stripe)
	var trail := Line2D.new()
	trail.width = 5.0
	trail.default_color = Color(color, 0.5)
	trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(trail)
	add_child(tal)
	tal.set_meta("trail", trail)
	talismans.append(tal)
	if id == "shift":
		var tw := create_tween()
		tw.tween_property(tal, "position", tal.position + Vector2(34, -130), 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(tal, "position", lantern_glow.position, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func():
			fx.glow_boost = 0.85
			_finish_talisman(tal)
		)
	else:
		var target := Vector2(randf_range(830.0, 890.0), randf_range(270.0, 330.0))
		var tw := create_tween()
		tw.tween_property(tal, "position", target, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(tal, "rotation", randf_range(-1.2, 1.2), 0.26)
		tw.tween_callback(func(): _finish_talisman(tal))


func _finish_talisman(tal: Node2D) -> void:
	talismans.erase(tal)
	if not is_instance_valid(tal):
		return
	var trail: Line2D = tal.get_meta("trail")
	var fade := create_tween().set_parallel(true)
	fade.tween_property(trail, "modulate:a", 0.0, 0.22)
	fade.tween_property(tal, "modulate:a", 0.0, 0.12)
	fade.chain().tween_callback(func():
		trail.queue_free()
		tal.queue_free()
	)


func embers() -> void:
	for i in 7:
		var mote := Polygon2D.new()
		mote.polygon = PackedVector2Array([Vector2(0, -4), Vector2(3, 0), Vector2(0, 4), Vector2(-3, 0)])
		mote.color = Color("ffca7a")
		mote.position = lantern_glow.position + Vector2(randf_range(-30.0, 30.0), randf_range(-10.0, 20.0))
		mote.z_index = 12
		add_child(mote)
		var rise := randf_range(50.0, 115.0)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(mote, "position:y", mote.position.y - rise, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(mote, "modulate:a", 0.0, 0.6)
		tw.chain().tween_callback(mote.queue_free)


func summon_vfx(color: Color) -> void:
	var ring := Line2D.new()
	var pts := PackedVector2Array()
	for i in 25:
		pts.append(Vector2.RIGHT.rotated(TAU * float(i) / 24.0) * 42.0)
	ring.points = pts
	ring.width = 5.0
	ring.default_color = color
	ring.position = player_pivot.position + Vector2(44, -168)
	ring.z_index = 14
	add_child(ring)
	var tw := create_tween().set_parallel(true).set_ignore_time_scale(true)
	tw.tween_property(ring, "position", player_pivot.position + Vector2(24, -36), 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(ring, "scale", Vector2(0.3, 0.3), 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(ring, "rotation", randf_range(4.0, 7.0), 0.32)
	tw.tween_property(ring, "modulate:a", 0.0, 0.14).set_delay(0.2)
	tw.chain().tween_callback(ring.queue_free)


# 模拟层访问的薄封装，便于将来替换为视图快照。
func sim_queued() -> bool:
	return get_parent().sim.queued_defense != BattleSimulationScript.DefenseGrade.NONE


func sim_in_windup() -> bool:
	return get_parent().sim.state == BattleSimulationScript.BattleState.WINDUP


func sim_elapsed() -> float:
	return get_parent().sim.attack_elapsed


func sim_duration() -> float:
	return get_parent().sim.current_intent.duration


func sim_intent_id() -> String:
	return get_parent().sim.current_intent.id
