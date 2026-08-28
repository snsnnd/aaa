extends Node

## 通用特效库：与具体角色无关的爆发、符纸、光环类效果。

const FxState := preload("res://scripts/presentation/fx_state.gd")

var fx: FxState
var stage: Node
var player_anim: Node
var enemy_anim: Node


func setup(state: FxState, stage_ref: Node, player_ref: Node, enemy_ref: Node) -> void:
	fx = state
	stage = stage_ref
	player_anim = player_ref
	enemy_anim = enemy_ref


func enemy_pos(offset := Vector2.ZERO) -> Vector2:
	return enemy_anim.enemy_sprite.position + offset


func player_pivot_pos() -> Vector2:
	return player_anim.player_pivot.position


func guard_arc(color := Color("f2d487")) -> void:
	var arc := Line2D.new()
	var pts := PackedVector2Array()
	for i in 13:
		var a := -1.1 + 2.2 * float(i) / 12.0
		pts.append(Vector2.RIGHT.rotated(a) * 86.0)
	arc.points = pts
	arc.width = 6.0
	arc.default_color = color
	arc.position = player_anim.guard_arc_position()
	arc.z_index = 12
	add_child(arc)
	var tw := create_tween().set_parallel(true).set_ignore_time_scale(true)
	tw.tween_property(arc, "scale", Vector2(1.25, 1.25), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(arc, "modulate:a", 0.0, 0.28).set_delay(0.05)
	tw.chain().tween_callback(arc.queue_free)


func paper_burst(tint := Color("e8d9a8")) -> void:
	var burst := Node2D.new()
	burst.position = enemy_pos(Vector2(-30, -20))
	burst.z_index = 12
	add_child(burst)
	for i in 6:
		var shard := Polygon2D.new()
		shard.polygon = PackedVector2Array([Vector2(-5, -8), Vector2(6, -6), Vector2(3, 9), Vector2(-7, 6)])
		shard.color = tint
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


func bell_wave() -> void:
	var wave := Node2D.new()
	wave.position = enemy_pos(Vector2(-40, -30))
	wave.z_index = 13
	add_child(wave)
	for i in 2:
		var arc := Line2D.new()
		var pts := PackedVector2Array()
		for p in 17:
			var a := -1.2 + 2.4 * float(p) / 16.0
			pts.append(Vector2.RIGHT.rotated(a) * (70.0 + i * 34.0))
		arc.points = pts
		arc.width = 7.0 - i * 2.0
		arc.default_color = Color("e0b45c") if i == 0 else Color("fff1bd")
		wave.add_child(arc)
	wave.scale = Vector2(0.4, 0.4)
	var tw := create_tween().set_parallel(true).set_ignore_time_scale(true)
	tw.tween_property(wave, "scale", Vector2(1.6, 1.6), 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(wave, "modulate:a", 0.0, 0.30)
	tw.chain().tween_callback(wave.queue_free)
	fx.trauma = minf(1.0, fx.trauma + 0.22)


func counter_slash(charged: bool) -> void:
	var slashes := Node2D.new()
	slashes.position = enemy_pos(Vector2(-20, -30))
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
	fx.trauma = minf(1.0, fx.trauma + (0.3 if charged else 0.18))


func seal_ring() -> void:
	var ring := Line2D.new()
	var pts := PackedVector2Array()
	for i in 33:
		pts.append(Vector2.RIGHT.rotated(TAU * float(i) / 32.0) * 112.0)
	ring.points = pts
	ring.width = 5.0
	ring.default_color = Color("7fd4dc")
	ring.position = enemy_pos(Vector2(-10, -10))
	ring.z_index = 12
	add_child(ring)
	enemy_anim.enemy_sprite.modulate = Color("9fd8de")
	create_tween().tween_property(enemy_anim.enemy_sprite, "modulate", Color.WHITE, 0.5)
	var tw := create_tween().set_parallel(true).set_ignore_time_scale(true)
	tw.tween_property(ring, "scale", Vector2(0.45, 0.45), 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(ring, "modulate:a", 0.0, 0.42)
	tw.chain().tween_callback(ring.queue_free)


func hit_sparks() -> void:
	var sparks := Node2D.new()
	sparks.position = enemy_pos(Vector2(-46, -34))
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


func parry_burst(pos: Vector2, color: Color, count: int) -> void:
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


func enemy_cue_fx(origin: Vector2, enemy_id: String, move_id: String, color: Color) -> void:
	match enemy_id:
		"lantern_imp":
			for i in 5:
				var spark := Polygon2D.new()
				spark.polygon = PackedVector2Array([Vector2(0, -4), Vector2(3, 0), Vector2(0, 4), Vector2(-3, 0)])
				spark.color = Color("f2a03c")
				spark.position = origin + Vector2(randf_range(-50.0, 30.0), randf_range(-40.0, 10.0))
				spark.z_index = 12
				add_child(spark)
				var tw := create_tween().set_parallel(true)
				tw.tween_property(spark, "position:y", spark.position.y - randf_range(30.0, 70.0), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				tw.tween_property(spark, "modulate:a", 0.0, 0.5)
				tw.chain().tween_callback(spark.queue_free)
		"paper_apprentice":
			for i in 4:
				var sheet := Polygon2D.new()
				sheet.polygon = PackedVector2Array([Vector2(-8, -11), Vector2(9, -8), Vector2(5, 11), Vector2(-9, 7)])
				sheet.color = Color("d8ceb0")
				sheet.position = origin + Vector2(-20, -40)
				sheet.z_index = 12
				add_child(sheet)
				var a := float(i) * 1.6
				var tw := create_tween().set_parallel(true).set_ignore_time_scale(true)
				tw.tween_property(sheet, "position", sheet.position + Vector2(cos(a) * 70.0, sin(a) * 46.0), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tw.tween_property(sheet, "rotation", a + 3.0, 0.5)
				tw.tween_property(sheet, "modulate:a", 0.0, 0.5)
				tw.chain().tween_callback(sheet.queue_free)
		"patrol_corpse":
			var gong := Line2D.new()
			var gpts := PackedVector2Array()
			for i in 25:
				gpts.append(Vector2.RIGHT.rotated(TAU * float(i) / 24.0) * (80.0 + i * 2.0))
			gong.points = gpts
			gong.width = 4.0
			gong.default_color = Color("8f7a3f", 0.7)
			gong.position = origin + Vector2(40, -40)
			gong.z_index = 12
			add_child(gong)
			var gtw := create_tween().set_parallel(true).set_ignore_time_scale(true)
			gtw.tween_property(gong, "scale", Vector2(1.7, 1.7), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			gtw.tween_property(gong, "modulate:a", 0.0, 0.35)
			gtw.chain().tween_callback(gong.queue_free)
		"barber_ghost":
			for a in [-0.35, 0.3]:
				var blade := Line2D.new()
				blade.points = PackedVector2Array([Vector2.RIGHT.rotated(a) * -70.0, Vector2.RIGHT.rotated(a) * 70.0])
				blade.width = 5.0
				blade.default_color = Color("e8edf0")
				blade.position = origin + Vector2(-10, -20)
				blade.z_index = 12
				add_child(blade)
				var btw := create_tween().set_parallel(true).set_ignore_time_scale(true)
				btw.tween_property(blade, "modulate:a", 0.0, 0.22).set_delay(0.04)
				btw.tween_property(blade, "rotation", blade.rotation + 0.5, 0.22)
				btw.chain().tween_callback(blade.queue_free)
		"well_sisters":
			for i in 3:
				var water := Line2D.new()
				water.points = PackedVector2Array([Vector2(0, 0), Vector2(-14, 46), Vector2(-6, 92)])
				water.width = 5.0
				water.default_color = Color("5a9ab0", 0.8)
				water.position = origin + Vector2(-60 + i * 44.0, -70.0)
				water.z_index = 12
				add_child(water)
				var wtw := create_tween().set_parallel(true).set_ignore_time_scale(true)
				wtw.tween_property(water, "modulate:a", 0.0, 0.4).set_delay(0.06 * i)
				wtw.chain().tween_callback(water.queue_free)
		"gambler_ghost":
			for i in 4:
				var die := Polygon2D.new()
				die.polygon = PackedVector2Array([Vector2(-7, -7), Vector2(7, -7), Vector2(7, 7), Vector2(-7, 7)])
				die.color = Color("e8dfc8")
				die.position = origin + Vector2(randf_range(-40.0, 40.0), randf_range(-60.0, -20.0))
				die.z_index = 12
				add_child(die)
				var dtw := create_tween().set_parallel(true).set_ignore_time_scale(true)
				dtw.tween_property(die, "position", die.position + Vector2(randf_range(-50.0, 50.0), randf_range(20.0, 60.0)), 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
				dtw.tween_property(die, "rotation", randf_range(-4.0, 4.0), 0.45)
				dtw.tween_property(die, "modulate:a", 0.0, 0.45)
				dtw.chain().tween_callback(die.queue_free)
		"mortuary_warden":
			for i in 3:
				var link := Line2D.new()
				link.points = PackedVector2Array([Vector2(0, 0), Vector2(-60 - i * 30.0, -6.0), Vector2(-120 - i * 34.0, 8.0)])
				link.width = 6.0 - i
				link.default_color = Color("57493a")
				link.position = origin + Vector2(20, -60 + i * 26.0)
				link.z_index = 12
				add_child(link)
				var ltw := create_tween().set_parallel(true).set_ignore_time_scale(true)
				ltw.tween_property(link, "modulate:a", 0.0, 0.32).set_delay(0.05 * i)
				ltw.chain().tween_callback(link.queue_free)
			fx.trauma = minf(1.0, fx.trauma + 0.18)
		"lantern_keeper":
			var dome := Line2D.new()
			var dpts := PackedVector2Array()
			for i in 33:
				dpts.append(Vector2.RIGHT.rotated(TAU * float(i) / 32.0) * 150.0)
			dome.points = dpts
			dome.width = 6.0
			dome.default_color = Color("f2d487", 0.75)
			dome.position = origin + Vector2(-20, -20)
			dome.z_index = 12
			add_child(dome)
			var dtw := create_tween().set_parallel(true).set_ignore_time_scale(true)
			dtw.tween_property(dome, "scale", Vector2(1.35, 1.35), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			dtw.tween_property(dome, "modulate:a", 0.0, 0.5)
			dtw.chain().tween_callback(dome.queue_free)
			fx.glow_boost = -0.4


func rage_flare(origin: Vector2) -> void:
	var flare := Sprite2D.new()
	flare.texture = _make_rage_texture()
	flare.position = origin + Vector2(-12, -30)
	flare.scale = Vector2(2.8, 3.4)
	flare.z_index = 2
	flare.modulate.a = 0.0
	add_child(flare)
	var tw := create_tween().set_parallel(true).set_ignore_time_scale(true)
	tw.tween_property(flare, "modulate:a", 0.55, 0.35)
	tw.chain().tween_property(flare, "modulate:a", 0.0, 0.7)
	tw.chain().tween_callback(flare.queue_free)


func _make_rage_texture() -> ImageTexture:
	var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in 128:
		for x in 128:
			var distance := Vector2(x - 63.5, y - 63.5).length() / 63.5
			var alpha := pow(maxf(0.0, 1.0 - distance), 2.2) * 0.5
			image.set_pixel(x, y, Color(0.85, 0.2, 0.16, alpha))
	return ImageTexture.create_from_image(image)


func soul_motes(origin: Vector2, color: Color, rising: bool) -> void:
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
