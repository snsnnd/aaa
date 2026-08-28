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


func _ready() -> void:
	if scale == Vector2.ONE and effect_scale != Vector2.ONE:
		scale = effect_scale
	if auto_start:
		play()


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
		return
		
	_elapsed += delta
	if _elapsed >= duration:
		_playing = false
		if auto_free and not Engine.is_editor_hint():
			queue_free()
