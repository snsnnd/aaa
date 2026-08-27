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
