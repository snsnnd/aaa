@tool
class_name ModularCharacterView
extends Node2D

## 通用可复用角色视觉组件 (Universal Reusable Character View)
## 结合 CharacterAnimProfile 动效配置与时间线阶段状态机，支持快慢刀、凝滞与阶段同步。

const CharacterAnimProfileScript := preload("res://assets/game/character_showcase/scripts/character_anim_profile.gd")
const CharacterStateMachineScript := preload("res://assets/game/character_showcase/scripts/character_state_machine.gd")

@export var profile: CharacterAnimProfileScript:
	set(new_profile):
		profile = new_profile
		if Engine.is_editor_hint():
			_apply_profile_defaults()

@export_group("Slot Textures (可选插槽贴图)")
@export var texture_body: Texture2D:
	set(tex):
		texture_body = tex
		if body_sprite:
			body_sprite.texture = tex
@export var texture_weapon: Texture2D:
	set(tex):
		texture_weapon = tex
		if weapon_sprite:
			weapon_sprite.texture = tex
			weapon_pivot.visible = (tex != null)
@export var texture_aura: Texture2D:
	set(tex):
		texture_aura = tex
		if aura_sprite:
			aura_sprite.texture = tex
			aura_sprite.visible = (tex != null)

@export_group("State & Timeline Info")
@export var current_state_name: String = "IDLE"
@export var current_phase: String = "idle"

# Child Nodes
@onready var state_machine: CharacterStateMachine = $StateMachine
@onready var body_sprite: Sprite2D = $Body
@onready var shadow_node: Polygon2D = $Shadow
@onready var weapon_pivot: Node2D = $WeaponPivot
@onready var weapon_sprite: Sprite2D = $WeaponPivot/WeaponSprite
@onready var lantern_pivot: Node2D = $LanternPivot
@onready var aura_sprite: Sprite2D = $Aura
@onready var vfx_mount: Marker2D = $VFXMountPoint

var _time: float = 0.0
var _base_pos: Vector2 = Vector2.ZERO
var _base_rot: float = 0.0
var _action_tween: Tween = null


func _ready() -> void:
	_base_pos = position
	_base_rot = rotation
	if texture_body and body_sprite:
		body_sprite.texture = texture_body
	if texture_weapon and weapon_sprite:
		weapon_sprite.texture = texture_weapon
		weapon_pivot.visible = true
	if texture_aura and aura_sprite:
		aura_sprite.texture = texture_aura
		aura_sprite.visible = true
		
	if not Engine.is_editor_hint():
		if state_machine:
			state_machine.setup(self)


func _process(delta: float) -> void:
	if profile == null:
		return
	_time += delta
	if state_machine:
		state_machine.update(delta)
		current_state_name = CharacterStateMachine.State.keys()[state_machine.current_state]
		current_phase = state_machine.current_phase_name


func _apply_profile_defaults() -> void:
	if profile == null:
		return
	if shadow_node:
		shadow_node.visible = profile.shadow_sync


# -------------------------------------------------------------
# 阶段时间线状态机回调 (Timeline Phase Handlers)
# -------------------------------------------------------------

func on_enter_idle() -> void:
	_kill_action_tween()
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position", _base_pos, 0.25)
	tw.tween_property(self, "rotation", _base_rot, 0.25)
	tw.tween_property(self, "scale", Vector2.ONE, 0.25)
	tw.tween_property(body_sprite, "modulate", Color.WHITE, 0.2)
	if weapon_pivot and weapon_pivot.visible:
		tw.tween_property(weapon_pivot, "rotation", 0.0, 0.25)


## 阶段一：抬刀蓄势 (Raise)
func on_enter_raise() -> void:
	_kill_action_tween()
	_action_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# 身体蓄力后撤、重心下沉
	_action_tween.tween_property(self, "position", _base_pos + Vector2(-profile.attack_windup_px, 8.0), 0.4)
	_action_tween.tween_property(self, "scale", Vector2(1.05, 0.95), 0.4)
	_action_tween.tween_property(body_sprite, "modulate", Color("ffe8e8"), 0.3)
	if weapon_pivot and weapon_pivot.visible:
		_action_tween.tween_property(weapon_pivot, "rotation", -0.85, 0.4)


## 阶段二：快慢刀停顿与假释放 (Hold / Fake Cue)
func on_enter_hold() -> void:
	_kill_action_tween()
	_action_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# 悬空停顿、假释放闪光预警
	_action_tween.tween_property(self, "position", _base_pos + Vector2(-profile.attack_windup_px * 1.1, 4.0), 0.2)
	if weapon_pivot and weapon_pivot.visible:
		_action_tween.tween_property(weapon_sprite, "modulate", Color("ff7a80"), 0.15)
		_action_tween.chain().tween_property(weapon_sprite, "modulate", Color.WHITE, 0.25)


## 阶段三：真实落刀承诺帧 (Commit / Strike)
func on_enter_commit() -> void:
	_kill_action_tween()
	_action_tween = create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	# 极速前冲突刺，白芯闪耀
	_action_tween.tween_property(self, "position:x", _base_pos.x + profile.attack_lunge_px, 0.09)
	_action_tween.parallel().tween_property(self, "scale", Vector2(1.18, 0.88), 0.08)
	_action_tween.parallel().tween_property(body_sprite, "modulate", Color.WHITE, 0.08)
	if weapon_pivot and weapon_pivot.visible:
		_action_tween.parallel().tween_property(weapon_pivot, "rotation", 0.75, 0.09)
		_action_tween.parallel().tween_property(weapon_sprite, "modulate", Color("ffffff"), 0.08)


## 阶段四：收招回位 (Recover)
func on_enter_recover() -> void:
	_kill_action_tween()
	_action_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_action_tween.tween_property(self, "position", _base_pos, 0.45)
	_action_tween.tween_property(self, "scale", Vector2.ONE, 0.45)
	if weapon_pivot and weapon_pivot.visible:
		_action_tween.tween_property(weapon_pivot, "rotation", 0.0, 0.45)
	_action_tween.chain().tween_callback(func():
		if state_machine:
			state_machine.transition_to(CharacterStateMachine.State.IDLE)
	)


## 阶段五：受击硬直 (Hit)
func on_enter_hit() -> void:
	_kill_action_tween()
	_action_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(self, "position:x", _base_pos.x - profile.hit_recoil_px, 0.06)
	_action_tween.tween_property(self, "rotation", -profile.hit_tilt_rad, 0.06)
	_action_tween.tween_property(body_sprite, "modulate", Color(1.0, 0.35, 0.35), 0.06)
	
	_action_tween.chain().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(self, "position", _base_pos, 0.3)
	_action_tween.tween_property(self, "rotation", _base_rot, 0.3)
	_action_tween.tween_property(body_sprite, "modulate", Color.WHITE, 0.25)
	_action_tween.chain().tween_callback(func():
		if state_machine:
			state_machine.transition_to(CharacterStateMachine.State.IDLE)
	)


## 阶段六：镇煞凝滞 / 弹反破防僵直 (Stagger / Time Freeze)
func on_enter_stagger() -> void:
	_kill_action_tween()
	# 受到时空凝滞，定格并泛起冷青色符咒光晕
	_action_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(self, "position:y", _base_pos.y + 18.0, 0.2)
	_action_tween.tween_property(self, "rotation", 0.05, 0.2)
	_action_tween.tween_property(body_sprite, "modulate", Color("86d6df"), 0.15)


## 阶段七：死亡消散 (Death)
func on_enter_death() -> void:
	_kill_action_tween()
	_action_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_action_tween.tween_property(self, "position:y", _base_pos.y + 40.0, 1.2)
	_action_tween.tween_property(body_sprite, "modulate:a", 0.0, 1.2)
	_action_tween.tween_property(shadow_node, "modulate:a", 0.0, 1.0)


func on_exit_action() -> void:
	_kill_action_tween()


func _kill_action_tween() -> void:
	if _action_tween and _action_tween.is_valid():
		_action_tween.kill()


# -------------------------------------------------------------
# 待机物理模拟 (Idle Procedural Physics)
# -------------------------------------------------------------

func update_idle_physics(_delta: float, is_staggered: bool = false) -> void:
	if profile == null:
		return
		
	var mult: float = 0.2 if is_staggered else 1.0
	var breath_t: float = _time * profile.breath_speed * mult
	var breath_cycle: float = sin(breath_t)
	
	match profile.motion_type:
		CharacterAnimProfile.MotionType.HUMAN_GROUND:
			body_sprite.position.y = breath_cycle * profile.breath_height
			body_sprite.scale.y = 1.0 + breath_cycle * profile.squash_stretch
			body_sprite.scale.x = 1.0 - breath_cycle * (profile.squash_stretch * 0.7)
			body_sprite.rotation = sin(_time * 1.5) * profile.idle_tilt_angle
			if lantern_pivot:
				lantern_pivot.rotation = sin(_time * profile.prop_sway_freq - profile.prop_lag_phase) * profile.prop_sway_angle
				lantern_pivot.position.y = breath_cycle * (profile.breath_height * 0.6)

		CharacterAnimProfile.MotionType.FLOAT_SPIRIT:
			var float_offset: float = breath_cycle * profile.breath_height
			var jitter_x: float = sin(_time * profile.jitter_speed) * profile.jitter_amount_x if profile.jitter_speed > 0.0 else 0.0
			body_sprite.position.y = float_offset
			body_sprite.position.x = jitter_x
			body_sprite.rotation = sin(_time * 2.0) * profile.idle_tilt_angle
			if shadow_node and profile.shadow_sync:
				var shadow_k: float = clampf(1.0 - (float_offset / 60.0), 0.5, 1.3)
				shadow_node.scale = Vector2(shadow_k, shadow_k * 0.35)
				shadow_node.modulate.a = clampf(0.5 - (float_offset / 80.0), 0.15, 0.65)
			if lantern_pivot:
				lantern_pivot.rotation = sin(_time * profile.prop_sway_freq + 0.5) * profile.prop_sway_angle

		CharacterAnimProfile.MotionType.RIGID_MECHANICAL:
			var cycle: float = fmod(_time * (profile.breath_speed * 0.5), 1.0)
			var step_h: float = 0.0
			var step_rot: float = 0.0
			if cycle < 0.25:
				step_h = -sin(cycle * 4.0 * PI) * profile.step_lift_height
				step_rot = 0.02
			elif cycle < 0.75 and cycle > 0.5:
				step_h = -sin((cycle - 0.5) * 4.0 * PI) * profile.step_lift_height
				step_rot = -0.02
			body_sprite.position.y = step_h
			body_sprite.rotation = step_rot

		CharacterAnimProfile.MotionType.PAPER_FLUTTER:
			var wind: float = sin(_time * 4.0) * 0.035 + sin(_time * 8.5) * 0.015
			body_sprite.rotation = wind
			body_sprite.scale.x = 1.0 + sin(_time * 3.0) * 0.03
			body_sprite.position.y = breath_cycle * profile.breath_height

		CharacterAnimProfile.MotionType.MAJESTIC_BOSS:
			body_sprite.position.y = breath_cycle * profile.breath_height
			body_sprite.rotation = sin(_time * 0.8) * profile.idle_tilt_angle
			if aura_sprite and aura_sprite.visible:
				var pulse: float = sin(_time * profile.aura_pulse_speed) * 0.5 + 0.5
				var a_scale: float = lerpf(profile.aura_scale_range.x, profile.aura_scale_range.y, pulse)
				aura_sprite.scale = Vector2.ONE * a_scale
				aura_sprite.modulate.a = lerpf(0.25, 0.55, pulse)

		CharacterAnimProfile.MotionType.NERVOUS_JITTER:
			body_sprite.position.y = breath_cycle * profile.breath_height
			body_sprite.position.x = sin(_time * 26.0) * profile.jitter_amount_x
			body_sprite.rotation = sin(_time * 18.0) * profile.idle_tilt_angle
			
		CharacterAnimProfile.MotionType.SLITHER_CREEP:
			body_sprite.position.y = sin(_time * 2.8) * profile.breath_height
			body_sprite.rotation = sin(_time * 3.2) * 0.04
			body_sprite.scale.x = 1.0 + sin(_time * 4.0) * 0.04
			body_sprite.scale.y = 1.0 - sin(_time * 4.0) * 0.04
