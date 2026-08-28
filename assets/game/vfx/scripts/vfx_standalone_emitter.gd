@tool
class_name VFXStandaloneEmitter
extends Node2D

## Standalone VFX Emitter controller
## Allows visual effects to be self-contained, previewed in editor, or triggered dynamically.

@export var auto_start: bool = true
@export var auto_free: bool = true
@export var duration: float = 1.2
@export var preview_trigger: bool = false:
	set(val):
		if val and Engine.is_editor_hint():
			play()

@export_group("Visual Overrides")
@export var effect_tint: Color = Color.WHITE
@export var effect_scale: Vector2 = Vector2.ONE

var _elapsed: float = 0.0
var _playing: bool = false
var _is_standalone_run: bool = false
var _loop_delay: float = 0.0


func _ready() -> void:
	if scale == Vector2.ONE and effect_scale != Vector2.ONE:
		scale = effect_scale

	# 如果玩家在 Godot 中直接对此场景按 F6 运行（作为顶层独立场景）
	if not Engine.is_editor_hint():
		if get_parent() == get_tree().root or get_tree().current_scene == self:
			_is_standalone_run = true
			auto_free = false
			position = get_viewport_rect().size * 0.5
			_setup_standalone_env()

	if auto_start:
		play()


func _setup_standalone_env() -> void:
	# 独立运行时提供深色背景与十字准心，方便看清高光粒子
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -10
	add_child(bg_layer)
	
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.07, 0.09)
	bg_layer.add_child(bg)
	
	# 绘制中心准心
	var ch := Node2D.new()
	ch.position = get_viewport_rect().size * 0.5
	bg_layer.add_child(ch)
	
	var lh := Line2D.new()
	lh.points = PackedVector2Array([Vector2(-30, 0), Vector2(30, 0)])
	lh.width = 1.0
	lh.default_color = Color(0.4, 0.45, 0.5, 0.35)
	ch.add_child(lh)
	
	var lv := Line2D.new()
	lv.points = PackedVector2Array([Vector2(0, -30), Vector2(0, 30)])
	lv.width = 1.0
	lv.default_color = Color(0.4, 0.45, 0.5, 0.35)
	ch.add_child(lv)


func play() -> void:
	_playing = true
	_elapsed = 0.0
	visible = true
	
	# Restart all CPUParticles2D and GPUParticles2D children
	for child in find_children("*", "CPUParticles2D", true, false):
		var p := child as CPUParticles2D
		p.restart()
		p.emitting = true
		
	for child in find_children("*", "GPUParticles2D", true, false):
		var p := child as GPUParticles2D
		p.restart()
		p.emitting = true
		
	# Trigger any AnimationPlayer
	for child in find_children("*", "AnimationPlayer", true, false):
		var ap := child as AnimationPlayer
		if ap.has_animation("play"):
			ap.play("play")


func _process(delta: float) -> void:
	if not _playing:
		if _is_standalone_run:
			_loop_delay += delta
			if _loop_delay >= 1.2:
				_loop_delay = 0.0
				play()
		return
		
	_elapsed += delta
	if _elapsed >= duration:
		_playing = false
		if auto_free and not Engine.is_editor_hint() and not _is_standalone_run:
			queue_free()
