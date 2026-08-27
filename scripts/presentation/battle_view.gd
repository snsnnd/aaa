extends Node2D

## 战斗世界视图：场景搭建、敌招动画、玩家姿态、特效与音频。
## 只读模拟层状态做表现，不修改任何规则数据。

const VIEW_SIZE := Vector2(1280.0, 720.0)
const ASSET_FOLDER := "demo"
const BattleSimulationScript := preload("res://scripts/battle/battle_simulation.gd")

var sim: BattleSimulationScript
var camera: Camera2D
var background: Sprite2D
var player_sprite: Sprite2D
var enemy_sprite: Sprite2D
var weapon_pivot: Node2D
var weapon_sprite: Sprite2D
var ghost_hand: Node2D
var attack_trail: Line2D
var parry_audio: AudioStreamPlayer
var hurt_audio: AudioStreamPlayer
var card_audio: AudioStreamPlayer
var warning_audio: AudioStreamPlayer
var lantern_glow: Sprite2D
var enemy_aura: Sprite2D
var fog_back: Line2D
var fog_front: Line2D
var rain_drops: Array[Line2D] = []
var noise := FastNoiseLite.new()
var trauma := 0.0
var shake_time := 0.0
var animation_time := 0.0
var hitstop_running := false
var player_pivot: Node2D
var pose_x := 0.0
var pose_rot := 0.0
var impulse_x := 0.0
var impulse_rot := 0.0
var glow_boost := 0.0
var enemy_push := 0.0
var talismans: Array[Node2D] = []
var shake_enabled := true


func setup(s: BattleSimulationScript) -> void:
	sim = s
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.seed = 4271
	_build_world()
	_load_style()


func tick(delta: float) -> void:
	_update_ambient_animation(delta)
	_update_player_combat_pose(delta)
	glow_boost = lerpf(glow_boost, 0.0, minf(1.0, delta * 3.0))
	var flicker := sin(animation_time * 9.7) * 0.08 + sin(animation_time * 15.1) * 0.04
	background.position.x = 640.0 + sin(animation_time * 0.10) * 2.5
	lantern_glow.position = player_pivot.position + Vector2(118, 112)
	lantern_glow.scale = Vector2.ONE * (2.35 * (1.0 + 0.38 * glow_boost))
	lantern_glow.modulate.a = clampf((0.76 + flicker) * (1.0 + 0.5 * glow_boost), 0.18, 1.0)
	enemy_aura.position = enemy_sprite.position + Vector2(-12, -30)
	enemy_aura.modulate.a = 0.50 + sin(animation_time * 1.8) * 0.12
	fog_back.position.x = fmod(animation_time * 7.0, 420.0) - 210.0
	fog_front.position.x = 210.0 - fmod(animation_time * 10.0, 420.0)
	for drop in rain_drops:
		var speed: float = drop.get_meta("speed")
		drop.position += Vector2(-72.0, 520.0) * speed * delta
		if drop.position.y > 760.0:
			drop.position = Vector2(randf_range(0.0, 1340.0), randf_range(-180.0, -20.0))
	_update_talisman_trails()
	_update_camera_shake(delta)


func _load_style() -> void:
	var folder := ASSET_FOLDER
	background.texture = load("res://assets/%s/background_old_street.png" % folder)
	player_sprite.texture = load("res://assets/%s/player_keeper.png" % folder)
	enemy_sprite.texture = load("res://assets/%s/enemy_watchman.png" % folder)
	weapon_sprite.texture = load("res://assets/%s/enemy_blade.png" % folder)
	background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	player_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	enemy_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	weapon_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func _build_world() -> void:
	camera = Camera2D.new()
	camera.position = VIEW_SIZE * 0.5
	camera.enabled = true
	add_child(camera)

	background = Sprite2D.new()
	background.position = VIEW_SIZE * 0.5
	background.scale = Vector2(2.0 / 3.0, 2.0 / 3.0)
	background.z_index = -10
	add_child(background)

	var ground_tint := Polygon2D.new()
	ground_tint.polygon = PackedVector2Array([Vector2(0, 430), Vector2(1280, 430), Vector2(1280, 555), Vector2(0, 555)])
	ground_tint.color = Color(0.03, 0.04, 0.055, 0.18)
	ground_tint.z_index = -2
	add_child(ground_tint)

	fog_back = Line2D.new()
	fog_back.points = PackedVector2Array([Vector2(-220, 315), Vector2(420, 298), Vector2(980, 330), Vector2(1510, 306)])
	fog_back.width = 72.0
	fog_back.default_color = Color(0.38, 0.55, 0.56, 0.045)
	fog_back.antialiased = true
	fog_back.z_index = -4
	add_child(fog_back)
	fog_front = Line2D.new()
	fog_front.points = PackedVector2Array([Vector2(-260, 465), Vector2(350, 442), Vector2(940, 478), Vector2(1540, 449)])
	fog_front.width = 54.0
	fog_front.default_color = Color(0.55, 0.58, 0.55, 0.032)
	fog_front.antialiased = true
	fog_front.z_index = 2
	add_child(fog_front)

	player_pivot = Node2D.new()
	player_pivot.position = Vector2(264, 355)
	player_pivot.z_index = 1
	add_child(player_pivot)
	player_sprite = Sprite2D.new()
	player_sprite.position = Vector2.ZERO
	player_sprite.scale = Vector2(0.49, 0.49)
	player_pivot.add_child(player_sprite)

	enemy_sprite = Sprite2D.new()
	enemy_sprite.position = Vector2(1006, 350)
	enemy_sprite.scale = Vector2(0.49, 0.49)
	enemy_sprite.z_index = 1
	add_child(enemy_sprite)

	weapon_pivot = Node2D.new()
	weapon_pivot.position = enemy_sprite.position + Vector2(38, -28)
	weapon_pivot.rotation = -0.45
	weapon_pivot.z_index = 3
	add_child(weapon_pivot)
	weapon_sprite = Sprite2D.new()
	weapon_sprite.position = Vector2(0, 98)
	weapon_sprite.scale = Vector2(0.49, 0.49)
	weapon_pivot.add_child(weapon_sprite)

	ghost_hand = _create_ghost_hand()
	ghost_hand.position = enemy_sprite.position + Vector2(-6, -8)
	ghost_hand.visible = false
	ghost_hand.z_index = 3
	add_child(ghost_hand)

	lantern_glow = Sprite2D.new()
	lantern_glow.texture = _make_glow_texture(Color(1.0, 0.42, 0.08, 0.48))
	lantern_glow.position = player_pivot.position + Vector2(118, 112)
	lantern_glow.scale = Vector2(2.35, 2.35)
	var lantern_material := CanvasItemMaterial.new()
	lantern_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	lantern_glow.material = lantern_material
	lantern_glow.z_index = 0
	add_child(lantern_glow)
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
	attack_trail.z_index = 3
	add_child(attack_trail)
	_create_rain()

	parry_audio = _audio_player("res://assets/demo/audio/parry.wav")
	hurt_audio = _audio_player("res://assets/demo/audio/hurt.wav")
	card_audio = _audio_player("res://assets/demo/audio/card.wav")
	warning_audio = _audio_player("res://assets/demo/audio/warning.wav")


func _make_glow_texture(color: Color) -> ImageTexture:
	var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in 128:
		for x in 128:
			var distance := Vector2(x - 63.5, y - 63.5).length() / 63.5
			var alpha := pow(maxf(0.0, 1.0 - distance), 2.4) * color.a
			image.set_pixel(x, y, Color(color.r, color.g, color.b, alpha))
	return ImageTexture.create_from_image(image)


func _create_rain() -> void:
	for i in 74:
		var drop := Line2D.new()
		drop.points = PackedVector2Array([Vector2.ZERO, Vector2(-5, randf_range(18.0, 34.0))])
		drop.width = randf_range(1.0, 2.2)
		drop.default_color = Color(0.48, 0.64, 0.68, randf_range(0.12, 0.32))
		drop.position = Vector2(randf_range(-40.0, 1320.0), randf_range(-720.0, 720.0))
		drop.set_meta("speed", randf_range(0.72, 1.28))
		drop.z_index = 4
		add_child(drop)
		rain_drops.append(drop)


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


func _audio_player(path: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = load(path)
	add_child(player)
	return player


func intent_color() -> Color:
	return sim.current_intent.color


func play_warning() -> void:
	warning_audio.play()


func play_card_sfx() -> void:
	card_audio.play()


func add_trauma(amount: float) -> void:
	trauma = minf(1.0, trauma + amount)


func pulse_glow(value: float) -> void:
	glow_boost = maxf(glow_boost, value)


func set_glow(value: float) -> void:
	glow_boost = value


func apply_attack_presentation() -> void:
	attack_trail.visible = false
	attack_trail.points = PackedVector2Array([Vector2.ZERO, Vector2(-205, 0)])
	attack_trail.modulate = Color.WHITE
	attack_trail.default_color = intent_color()
	weapon_sprite.modulate = Color.WHITE
	ghost_hand.visible = false
	_reset_enemy_pose()


func finish_action_fx() -> void:
	attack_trail.visible = false
	ghost_hand.visible = false


func commit_flash(color: Color) -> void:
	warning_audio.play()
	weapon_sprite.modulate = Color("fff1bd")
	var tween := create_tween().set_ignore_time_scale(true).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(weapon_sprite, "modulate", Color.WHITE, 0.16)
	if sim.current_intent.id == "green" and ghost_hand.visible:
		ghost_hand.modulate = color.lightened(0.35)
		create_tween().set_ignore_time_scale(true).tween_property(ghost_hand, "modulate", Color.WHITE, 0.18)


func fake_release() -> void:
	add_trauma(0.035)
	warning_audio.play()
	weapon_sprite.modulate = Color("cf4b4f")
	create_tween().set_ignore_time_scale(true).tween_property(weapon_sprite, "modulate", Color.WHITE, 0.20).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func take_hit(damage: int) -> void:
	hurt_audio.play()
	add_trauma(0.58)
	impulse_x = -34.0
	impulse_rot = -0.13
	glow_boost = -0.7
	player_sprite.modulate = Color(1.0, 0.35, 0.35)
	create_tween().tween_property(player_sprite, "modulate", Color.WHITE, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return


func small_enemy_hit(strength: float) -> void:
	add_trauma(strength)
	enemy_sprite.modulate = Color("ffd59a")
	create_tween().tween_property(enemy_sprite, "modulate", Color.WHITE, 0.18).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	var original_scale := enemy_sprite.scale
	enemy_sprite.scale = original_scale * Vector2(1.07, 0.93)
	create_tween().tween_property(enemy_sprite, "scale", original_scale, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hit_sparks()


func _hit_sparks() -> void:
	var sparks := Node2D.new()
	sparks.position = enemy_sprite.position + Vector2(-46, -34)
	sparks.z_index = 13
	add_child(sparks)
	for i in 7:
		var spark := Line2D.new()
		var a := randf_range(-PI * 0.85, -PI * 0.15)
		var length := randf_range(26.0, 64.0)
		spark.points = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT.rotated(a) * length])
		spark.width = randf_range(2.0, 4.0)
		spark.default_color = Color("fff1bd") if i % 2 == 0 else Color("ffd59a")
		sparks.add_child(spark)
	var tw := create_tween().set_parallel(true).set_ignore_time_scale(true)
	tw.tween_property(sparks, "modulate:a", 0.0, 0.18)
	tw.tween_property(sparks, "scale", Vector2(1.3, 1.3), 0.18)
	tw.chain().tween_callback(sparks.queue_free)


func parry_feedback(pos: Vector2, major: bool) -> void:
	parry_audio.play()
	add_trauma(0.82 if major else 0.48)
	_spawn_parry_burst(pos, intent_color(), 22 if major else 11)
	var original_scale := enemy_sprite.scale
	enemy_sprite.scale = original_scale * Vector2(1.08, 0.92)
	create_tween().tween_property(enemy_sprite, "scale", original_scale, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _spawn_parry_burst(pos: Vector2, color: Color, count: int) -> void:
	var burst := Node2D.new()
	burst.position = pos
	burst.z_index = 20
	add_child(burst)
	for i in count:
		var shard := Line2D.new()
		var angle := TAU * float(i) / float(count) + randf_range(-0.10, 0.10)
		var length := randf_range(44.0, 132.0)
		shard.points = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT.rotated(angle) * length])
		shard.width = randf_range(2.0, 7.0)
		shard.default_color = color.lightened(randf_range(0.15, 0.65))
		burst.add_child(shard)
	var ring := Line2D.new()
	var ring_points := PackedVector2Array()
	for i in 33:
		var angle := TAU * float(i) / 32.0
		ring_points.append(Vector2.RIGHT.rotated(angle) * 72.0)
	ring.points = ring_points
	ring.width = 5.0
	ring.default_color = Color("ffe7a3")
	burst.add_child(ring)
	for angle in [-0.55, 0.55]:
		var slash := Line2D.new()
		slash.points = PackedVector2Array([Vector2.RIGHT.rotated(angle) * -108.0, Vector2.RIGHT.rotated(angle) * 108.0])
		slash.width = 7.0
		slash.default_color = Color("fff4ca")
		burst.add_child(slash)
	burst.scale = Vector2(0.26, 0.26)
	var tween := create_tween().set_parallel(true).set_ignore_time_scale(true)
	tween.tween_property(burst, "scale", Vector2(1.45, 1.45), 0.30).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(burst, "modulate:a", 0.0, 0.28).set_delay(0.12)
	tween.chain().tween_callback(burst.queue_free)


func hit_stop(duration: float, time_scale: float) -> void:
	if hitstop_running:
		return
	hitstop_running = true
	Engine.time_scale = time_scale
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	hitstop_running = false


func contact_point() -> Vector2:
	return player_pivot.position + Vector2(210.0, -14.0)


func snap_ghost_hand_back() -> void:
	if not ghost_hand.visible:
		return
	var back := enemy_sprite.position + Vector2(-6, -8)
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(ghost_hand, "position", back, 0.16)
	tw.tween_property(ghost_hand, "scale", Vector2(0.3, 0.6), 0.16)
	tw.chain().tween_callback(func(): ghost_hand.visible = false)


func guard_arc(color := Color("f2d487")) -> void:
	var arc := Line2D.new()
	var pts := PackedVector2Array()
	for i in 13:
		var a := -1.1 + 2.2 * float(i) / 12.0
		pts.append(Vector2.RIGHT.rotated(a) * 86.0)
	arc.points = pts
	arc.width = 6.0
	arc.default_color = color
	arc.position = player_pivot.position + Vector2(96, -4)
	arc.z_index = 12
	add_child(arc)
	var tw := create_tween().set_parallel(true).set_ignore_time_scale(true)
	tw.tween_property(arc, "scale", Vector2(1.25, 1.25), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(arc, "modulate:a", 0.0, 0.28).set_delay(0.05)
	tw.chain().tween_callback(arc.queue_free)


func paper_burst() -> void:
	var burst := Node2D.new()
	burst.position = enemy_sprite.position + Vector2(-30, -20)
	burst.z_index = 12
	add_child(burst)
	for i in 6:
		var shard := Polygon2D.new()
		shard.polygon = PackedVector2Array([Vector2(-5, -8), Vector2(6, -6), Vector2(3, 9), Vector2(-7, 6)])
		shard.color = Color("e8d9a8")
		shard.rotation = randf_range(0.0, TAU)
		burst.add_child(shard)
		var drift := Vector2(randf_range(-110.0, -30.0), randf_range(-95.0, -20.0))
		create_tween().tween_property(shard, "position", drift, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var slash := Line2D.new()
	slash.points = PackedVector2Array([Vector2(-70, -52), Vector2(64, 42)])
	slash.width = 6.0
	slash.default_color = Color("fff4ca")
	burst.add_child(slash)
	var fade := create_tween().set_ignore_time_scale(true)
	fade.tween_interval(0.08)
	fade.tween_property(burst, "modulate:a", 0.0, 0.28)
	fade.tween_callback(burst.queue_free)


func counter_slash(charged: bool) -> void:
	var slashes := Node2D.new()
	slashes.position = enemy_sprite.position + Vector2(-20, -30)
	slashes.z_index = 13
	add_child(slashes)
	var color := Color("ff9d5c") if charged else Color("e0b45c")
	for a in [-0.5, 0.45]:
		var s := Line2D.new()
		s.points = PackedVector2Array([Vector2.RIGHT.rotated(a) * -132.0, Vector2.RIGHT.rotated(a) * 132.0])
		s.width = 9.0 if charged else 6.5
		s.default_color = color
		slashes.add_child(s)
	slashes.scale = Vector2(0.5, 0.5)
	var tw := create_tween().set_parallel(true).set_ignore_time_scale(true)
	tw.tween_property(slashes, "scale", Vector2(1.5, 1.5), 0.24).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(slashes, "modulate:a", 0.0, 0.26).set_delay(0.08)
	tw.chain().tween_callback(slashes.queue_free)
	add_trauma(0.3 if charged else 0.18)


func seal_ring() -> void:
	var ring := Line2D.new()
	var pts := PackedVector2Array()
	for i in 33:
		pts.append(Vector2.RIGHT.rotated(TAU * float(i) / 32.0) * 112.0)
	ring.points = pts
	ring.width = 5.0
	ring.default_color = Color("7fd4dc")
	ring.position = enemy_sprite.position + Vector2(-10, -10)
	ring.z_index = 12
	add_child(ring)
	enemy_sprite.modulate = Color("9fd8de")
	create_tween().tween_property(enemy_sprite, "modulate", Color.WHITE, 0.5)
	var tw := create_tween().set_parallel(true).set_ignore_time_scale(true)
	tw.tween_property(ring, "scale", Vector2(0.45, 0.45), 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(ring, "modulate:a", 0.0, 0.42)
	tw.chain().tween_callback(ring.queue_free)


func summon_vfx(id: String) -> void:
	var color: Color = BattleSimulationScript.CARD_DATA[id].color
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


func spawn_talisman(id: String) -> void:
	var color: Color = BattleSimulationScript.CARD_DATA[id].color
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
			set_glow(0.85)
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


func success_impact_fx() -> void:
	parry_feedback(contact_point(), false)
	impulse_x = -18.0
	pulse_glow(0.45)
	enemy_push = 26.0
	snap_ghost_hand_back()


func perfect_impact_fx() -> void:
	parry_feedback(contact_point(), true)
	hit_stop(0.11, 0.06)
	impulse_x = -10.0
	set_glow(1.0)
	player_sprite.modulate = Color("fff2c4")
	create_tween().tween_property(player_sprite, "modulate", Color.WHITE, 0.24).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	enemy_push = 55.0
	snap_ghost_hand_back()


func defense_miss_fx(unblockable: bool) -> void:
	impulse_x = -20.0
	impulse_rot = -0.07
	guard_arc(Color("c14b4b") if unblockable else Color("a8564f"))


func enemy_staggered_fx() -> void:
	enemy_sprite.modulate = Color("ffe9b0")
	create_tween().tween_property(enemy_sprite, "modulate", Color.WHITE, 0.5)
	add_trauma(0.2)


func present_death(victory: bool) -> void:
	if victory:
		hit_stop(0.3, 0.25)
		enemy_sprite.modulate = Color("cfeef0")
		create_tween().tween_property(enemy_sprite, "modulate:a", 0.0, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		create_tween().tween_property(enemy_aura, "modulate:a", 0.0, 1.1)
		_soul_motes(enemy_sprite.position + Vector2(-30, -40), Color("9fdce2"), true)
	else:
		impulse_x = -26.0
		impulse_rot = -0.12
		create_tween().tween_property(player_sprite, "modulate", Color(0.6, 0.2, 0.2, 0.4), 1.0)
		create_tween().tween_property(lantern_glow, "modulate:a", 0.08, 1.0)
		_soul_motes(player_pivot.position + Vector2(118, 40), Color("d86a5a"), false)


func _soul_motes(origin: Vector2, color: Color, rising: bool) -> void:
	for i in 14:
		var mote := Polygon2D.new()
		mote.polygon = PackedVector2Array([Vector2(0, -5), Vector2(4, 0), Vector2(0, 5), Vector2(-4, 0)])
		mote.color = color
		mote.position = origin + Vector2(randf_range(-70.0, 70.0), randf_range(-60.0, 60.0))
		mote.z_index = 14
		add_child(mote)
		var drift := Vector2(randf_range(-40.0, 40.0), randf_range(-160.0, -70.0) if rising else randf_range(50.0, 130.0))
		var tw := create_tween().set_parallel(true).set_ignore_time_scale(true)
		tw.tween_property(mote, "position", mote.position + drift, randf_range(0.8, 1.4)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(mote, "modulate:a", 0.0, randf_range(0.8, 1.4))
		tw.chain().tween_callback(mote.queue_free)


func _update_ambient_animation(delta: float) -> void:
	animation_time += delta
	player_sprite.position = Vector2(0.0, sin(animation_time * 1.65) * 3.0)
	player_sprite.rotation = sin(animation_time * 1.25) * 0.006
	if sim.state == BattleSimulationScript.BattleState.WINDUP:
		_update_enemy_attack_visuals()
		if sim.stagger_remaining > 0.0:
			weapon_pivot.rotation = lerpf(weapon_pivot.rotation, 0.62, minf(1.0, delta * 6.0))
			enemy_sprite.rotation = lerpf(enemy_sprite.rotation, 0.06, minf(1.0, delta * 6.0))
	else:
		var settle := minf(1.0, delta * 8.0)
		enemy_sprite.position.x = lerpf(enemy_sprite.position.x, 1006.0 + enemy_push, settle)
		enemy_sprite.rotation = lerpf(enemy_sprite.rotation, 0.0, settle)
		weapon_pivot.position = weapon_pivot.position.lerp(enemy_sprite.position + Vector2(38, -28), settle)
		weapon_pivot.rotation = lerpf(weapon_pivot.rotation, -0.45, settle)
		if sim.state != BattleSimulationScript.BattleState.RESOLVING:
			enemy_sprite.position.y = 350.0 + sin(animation_time * 1.22 + 1.7) * 5.0
			weapon_pivot.rotation += sin(animation_time * 0.88 + 0.7) * -0.006


func _update_player_combat_pose(delta: float) -> void:
	var guard := sim.queued_defense != BattleSimulationScript.DefenseGrade.NONE
	var brace := false
	if sim.state == BattleSimulationScript.BattleState.WINDUP and not guard:
		var ratio := clampf(sim.attack_elapsed / float(sim.current_intent.duration), 0.0, 1.0)
		match String(sim.current_intent.id):
			"red", "green":
				brace = ratio > 0.60
			"blue":
				brace = sim.attack_elapsed > 0.45
	var target_x := 26.0 if guard else (12.0 if brace else 0.0)
	var target_rot := 0.05 if guard else (0.022 if brace else 0.0)
	pose_x = lerpf(pose_x, target_x, minf(1.0, delta * 12.0))
	pose_rot = lerpf(pose_rot, target_rot, minf(1.0, delta * 12.0))
	impulse_x = lerpf(impulse_x, 0.0, minf(1.0, delta * 6.5))
	impulse_rot = lerpf(impulse_rot, 0.0, minf(1.0, delta * 8.0))
	player_pivot.position = Vector2(264.0 + pose_x + impulse_x, 355.0)
	player_pivot.rotation = pose_rot + impulse_rot


func _update_talisman_trails() -> void:
	for tal in talismans.duplicate():
		if not is_instance_valid(tal):
			talismans.erase(tal)
			continue
		var trail: Line2D = tal.get_meta("trail")
		trail.add_point(tal.position)
		if trail.get_point_count() > 14:
			trail.remove_point(0)


func _update_camera_shake(delta: float) -> void:
	if not shake_enabled or trauma <= 0.0:
		camera.offset = Vector2.ZERO
		camera.rotation = 0.0
		return
	trauma = maxf(0.0, trauma - delta * 1.55)
	shake_time += delta * 46.0
	var amount := trauma * trauma
	camera.offset = Vector2(
		noise.get_noise_2d(shake_time, 0.0) * 17.0 * amount,
		noise.get_noise_2d(0.0, shake_time) * 11.0 * amount
	)
	camera.rotation = noise.get_noise_2d(shake_time, shake_time) * 0.018 * amount


func restart_fx() -> void:
	Engine.time_scale = 1.0
	trauma = 0.0
	pose_x = 0.0
	pose_rot = 0.0
	impulse_x = 0.0
	impulse_rot = 0.0
	glow_boost = 0.0
	enemy_push = 0.0
	player_sprite.modulate = Color.WHITE
	enemy_sprite.modulate = Color.WHITE
	enemy_aura.modulate.a = 0.5
	_reset_enemy_pose()


func _reset_enemy_pose() -> void:
	enemy_sprite.position = Vector2(1006, 350)
	enemy_sprite.rotation = 0.0
	weapon_pivot.position = enemy_sprite.position + Vector2(38, -28)
	weapon_pivot.rotation = -0.45
	weapon_sprite.modulate = Color.WHITE
	ghost_hand.position = enemy_sprite.position + Vector2(-6, -8)
	ghost_hand.scale = Vector2.ONE
	ghost_hand.modulate = Color.WHITE
	ghost_hand.visible = false


func _update_enemy_attack_visuals() -> void:
	var duration: float = sim.current_intent.duration
	var ratio := clampf(sim.attack_elapsed / duration, 0.0, 1.0)
	match String(sim.current_intent.id):
		"red":
			_update_red_slow_blade(ratio)
		"blue":
			_update_blue_combo(ratio)
		"green":
			_update_green_grab(ratio)


func _update_red_slow_blade(ratio: float) -> void:
	if ratio < 0.36:
		var raise := smoothstep(0.0, 0.36, ratio)
		weapon_pivot.rotation = lerpf(-0.45, -2.22, raise)
		enemy_sprite.position.x = lerpf(1006.0, 1016.0, raise)
		enemy_sprite.rotation = lerpf(0.0, 0.045, raise)
	elif ratio < 0.68:
		var hold := (ratio - 0.36) / 0.32
		weapon_pivot.rotation = -2.22 + sin(hold * PI * 7.0) * 0.018
		enemy_sprite.position.x = 1016.0 + sin(hold * PI * 5.0) * 1.5
		enemy_sprite.rotation = 0.045 + sin(hold * PI * 5.0) * 0.004
	else:
		var commit := smoothstep(0.68, 1.0, ratio)
		weapon_pivot.rotation = lerpf(-2.22, 1.45, commit)
		enemy_sprite.position.x = lerpf(1016.0, 530.0, commit)
		enemy_sprite.rotation = lerpf(0.045, -0.18, commit)
	attack_trail.visible = ratio > 0.74
	attack_trail.points = PackedVector2Array([Vector2.ZERO, Vector2(-300, 0)])
	attack_trail.position = enemy_sprite.position + Vector2(8, -30)
	attack_trail.rotation = weapon_pivot.rotation + PI * 0.5
	attack_trail.width = 8.0 + 20.0 * maxf(0.0, (ratio - 0.74) / 0.26)
	attack_trail.default_color = Color("ead79c")
	attack_trail.modulate.a = clampf((ratio - 0.74) / 0.12, 0.0, 0.8)
	weapon_pivot.position = enemy_sprite.position + Vector2(38, -28)


func _update_blue_combo(ratio: float) -> void:
	var strike_time := 0.82 if sim.strike_index == 0 else 1.56
	var start_time := 0.0 if sim.strike_index == 0 else 0.82
	var reach := 380.0 if sim.strike_index == 0 else 420.0
	var phase := clampf((sim.attack_elapsed - start_time) / (strike_time - start_time), 0.0, 1.0)
	var commit := clampf((phase - 0.56) / 0.44, 0.0, 1.0)
	if phase < 0.56:
		weapon_pivot.rotation = lerpf(0.35 if sim.strike_index > 0 else -0.45, -1.62, smoothstep(0.0, 0.56, phase))
	else:
		weapon_pivot.rotation = lerpf(-1.62, 1.15, smoothstep(0.0, 1.0, commit))
	enemy_sprite.position.x = 1006.0 - sin(commit * PI) * reach
	enemy_sprite.rotation = -sin(commit * PI) * 0.085
	var time_to_hit := strike_time - sim.attack_elapsed
	attack_trail.visible = time_to_hit <= 0.13 and time_to_hit >= -0.05
	attack_trail.points = PackedVector2Array([Vector2.ZERO, Vector2(-290, 0)])
	attack_trail.position = enemy_sprite.position + Vector2(18, -26)
	attack_trail.rotation = weapon_pivot.rotation + PI * 0.5
	attack_trail.width = 12.0
	attack_trail.default_color = intent_color().lightened(0.35)
	attack_trail.modulate.a = 0.68
	weapon_pivot.position = enemy_sprite.position + Vector2(38, -28)


func _update_green_grab(ratio: float) -> void:
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
		var reach := smoothstep(0.60, 1.0, ratio)
		weapon_pivot.rotation = -0.20
		enemy_sprite.position.x = lerpf(1006.0, 940.0, reach)
		enemy_sprite.rotation = lerpf(-0.02, -0.09, reach)
		ghost_hand.visible = true
		ghost_hand.position = enemy_sprite.position.lerp(enemy_sprite.position + Vector2(-505, -18), reach)
		ghost_hand.scale = Vector2(lerpf(0.55, 1.3, reach), lerpf(0.8, 1.0, reach))
	weapon_pivot.position = enemy_sprite.position + Vector2(38, -28)
