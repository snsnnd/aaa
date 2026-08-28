extends Node2D

## 舞台：相机、背景、雨雾等环境层与镜头震动。

const FxState := preload("res://scripts/presentation/fx_state.gd")
const PresentationCatalog := preload("res://scripts/presentation/presentation_catalog.gd")

var camera: Camera2D
var background: Sprite2D
var parallax_layers: Array[Sprite2D] = []
var parallax_drifts: Array[float] = []
var fog_back: Line2D
var fog_front: Line2D
var rain_drops: Array[Line2D] = []
var noise := FastNoiseLite.new()
var shake_time := 0.0
var fx: FxState


func setup(state: FxState) -> void:
	fx = state
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.seed = 4271
	camera = Camera2D.new()
	camera.position = Vector2(1280.0, 720.0) * 0.5
	camera.enabled = true
	add_child(camera)

	for layer_cfg in PresentationCatalog.PARALLAX_LAYERS:
		var layer := Sprite2D.new()
		layer.texture = load(layer_cfg.texture)
		layer.position = Vector2(1280.0, 720.0) * 0.5
		layer.scale = Vector2(2.0 / 3.0, 2.0 / 3.0)
		layer.z_index = int(layer_cfg.z)
		layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(layer)
		parallax_layers.append(layer)
		parallax_drifts.append(float(layer_cfg.drift))
	background = parallax_layers[2]

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
	_create_rain()


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


func load_style(folder: String) -> void:
	for layer in parallax_layers:
		layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func tick(delta: float, animation_time: float) -> void:
	for i in parallax_layers.size():
		var drift_speed: float = parallax_drifts[i]
		parallax_layers[i].position.x = 640.0 + sin(animation_time * 0.10 * drift_speed) * (3.0 * drift_speed)
	fog_back.position.x = fmod(animation_time * 7.0, 420.0) - 210.0
	fog_front.position.x = 210.0 - fmod(animation_time * 10.0, 420.0)
	for drop in rain_drops:
		var speed: float = drop.get_meta("speed")
		drop.position += Vector2(-72.0, 520.0) * speed * delta
		if drop.position.y > 760.0:
			drop.position = Vector2(randf_range(0.0, 1340.0), randf_range(-180.0, -20.0))
	_update_camera_shake(delta)


func _update_camera_shake(delta: float) -> void:
	if not fx.shake_enabled or fx.trauma <= 0.0:
		camera.offset = Vector2.ZERO
		camera.rotation = 0.0
		return
	fx.trauma = maxf(0.0, fx.trauma - delta * 1.55)
	shake_time += delta * 46.0
	var amount := fx.trauma * fx.trauma
	camera.offset = Vector2(
		noise.get_noise_2d(shake_time, 0.0) * 17.0 * amount,
		noise.get_noise_2d(0.0, shake_time) * 11.0 * amount
	)
	camera.rotation = noise.get_noise_2d(shake_time, shake_time) * 0.018 * amount
