@tool
class_name ProceduralCharacterAnim
extends Node2D

## Procedural 2D Character Animation Controller
## 为不同怪谈角色提供高度差异化的个性动态（呼吸、摆动、浮空、机械顿挫、纸片颤动等）

enum Personality {
	KEEPER_HUMAN,      # 执灯人：沉稳呼吸、灯笼物理摆动、披肩微动
	IMP_FLOATING,      # 灯笼小鬼：高频浮空上下浮沉、神经质抖动、灯笼弹跳
	CORPSE_RIGID,      # 更练尸：机械僵硬巡更步态、顿挫卡点、突发击锣
	PAPER_CREAKY,      # 纸扎学徒：纸张风吹颤动、轻盈失重感、关节咔嗒折痕
	BOSS_MAJESTIC,     # 守灯人：威严慢速悬浮、宏大命火领域呼吸、衣袍流转
}

@export var character_personality: Personality = Personality.KEEPER_HUMAN
@export var is_active: bool = true
@export var preview_in_editor: bool = true

@export_group("State & Triggers")
@export var trigger_attack: bool = false:
	set(val):
		if val:
			play_action("attack")
@export var trigger_hit: bool = false:
	set(val):
		if val:
			play_action("hit")
@export var trigger_telegraph: bool = false:
	set(val):
		if val:
			play_action("telegraph")

# Sub-node references (optional based on scene setup)
@onready var body_sprite: Sprite2D = get_node_or_null("Body")
@onready var weapon_pivot: Node2D = get_node_or_null("WeaponPivot")
@onready var lantern_pivot: Node2D = get_node_or_null("LanternPivot")
@onready var aura_sprite: Sprite2D = get_node_or_null("Aura")
@onready var shadow_sprite: Sprite2D = get_node_or_null("Shadow")

var _time: float = 0.0
var _base_body_pos: Vector2 = Vector2.ZERO
var _base_body_rot: float = 0.0
var _action_tween: Tween = null
var _is_performing_action: bool = false


func _ready() -> void:
	if body_sprite:
		_base_body_pos = body_sprite.position
		_base_body_rot = body_sprite.rotation


func _process(delta: float) -> void:
	if not is_active:
		return
	if Engine.is_editor_hint() and not preview_in_editor:
		return
		
	_time += delta
	if not _is_performing_action:
		_update_idle_motion(delta)


func _update_idle_motion(_delta: float) -> void:
	match character_personality:
		Personality.KEEPER_HUMAN:
			# 执灯人：沉稳呼吸，周期约 2.8s，灯笼链条滞后摆动
			var breath_cycle = sin(_time * 2.2)
			if body_sprite:
				body_sprite.position.y = _base_body_pos.y + breath_cycle * 2.8
				body_sprite.scale.y = 1.0 + breath_cycle * 0.015
				body_sprite.scale.x = 1.0 - breath_cycle * 0.01
				body_sprite.rotation = _base_body_rot + sin(_time * 1.5) * 0.008
			if lantern_pivot:
				# 灯笼受呼吸和重力摆动，滞后 0.4s
				lantern_pivot.rotation = sin(_time * 2.2 - 0.4) * 0.06 + sin(_time * 4.8) * 0.015
				lantern_pivot.position.y = breath_cycle * 1.8
			if shadow_sprite:
				shadow_sprite.scale = Vector2.ONE * (1.0 - breath_cycle * 0.03)

		Personality.IMP_FLOATING:
			# 灯笼小鬼：急促浮空上下漂浮，快速高频微颤
			var float_cycle = sin(_time * 3.6) * 14.0
			var jitter_x = sin(_time * 18.0) * 1.2
			if body_sprite:
				body_sprite.position.y = _base_body_pos.y + float_cycle
				body_sprite.position.x = _base_body_pos.x + jitter_x
				body_sprite.rotation = _base_body_rot + sin(_time * 2.4) * 0.05
			if lantern_pivot:
				lantern_pivot.rotation = sin(_time * 3.6 + 0.6) * 0.22 + sin(_time * 14.0) * 0.04
			if shadow_sprite:
				shadow_sprite.scale = Vector2.ONE * clampf(1.0 - (float_cycle / 60.0), 0.6, 1.2)
				shadow_sprite.modulate.a = clampf(0.5 - (float_cycle / 50.0), 0.2, 0.7)

		Personality.CORPSE_RIGID:
			# 更练尸：僵硬机械的 4 拍巡更步态，带顿挫停歇
			var cycle = fmod(_time * 1.2, 1.0)
			var step_h = 0.0
			var step_rot = 0.0
			if cycle < 0.25:
				# 提步
				step_h = -sin(cycle * 4.0 * PI) * 6.0
				step_rot = 0.02
			elif cycle < 0.5:
				# 落步顿挫
				step_h = 0.0
				step_rot = -0.015
			elif cycle < 0.75:
				step_h = -sin((cycle - 0.5) * 4.0 * PI) * 6.0
				step_rot = -0.02
			else:
				step_h = 0.0
				step_rot = 0.01
				
			if body_sprite:
				body_sprite.position.y = _base_body_pos.y + step_h
				body_sprite.rotation = _base_body_rot + step_rot
			if weapon_pivot:
				# 铜锣/巡更木棒保持机械式僵持
				weapon_pivot.rotation = -0.1 + sin(_time * 2.4) * 0.02

		Personality.PAPER_CREAKY:
			# 纸扎学徒：像薄纸张般受风吹拂的扭曲折叠感
			var wind = sin(_time * 4.0) * 0.035 + sin(_time * 8.5) * 0.015
			if body_sprite:
				body_sprite.rotation = _base_body_rot + wind
				body_sprite.scale.x = 1.0 + sin(_time * 3.0) * 0.025
				body_sprite.position.y = _base_body_pos.y + sin(_time * 2.0) * 3.5
			if weapon_pivot:
				# 纸刀在风中摇曳
				weapon_pivot.rotation = sin(_time * 4.5) * 0.08

		Personality.BOSS_MAJESTIC:
			# 守灯人 Boss：缓慢宏大的悬浮律动
			var slow_float = sin(_time * 1.4) * 8.0
			if body_sprite:
				body_sprite.position.y = _base_body_pos.y + slow_float
				body_sprite.rotation = _base_body_rot + sin(_time * 0.9) * 0.012
			if aura_sprite:
				aura_sprite.scale = Vector2.ONE * (2.8 + sin(_time * 2.5) * 0.25)
				aura_sprite.modulate.a = 0.35 + sin(_time * 3.0) * 0.12


func play_action(action_name: String) -> void:
	if _action_tween and _action_tween.is_valid():
		_action_tween.kill()
		
	_is_performing_action = true
	_action_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	match action_name:
		"attack":
			# 前摇蓄势 -> 爆发前冲 -> 收招复位
			_action_tween.tween_property(self, "position:x", position.x - 35.0, 0.25).set_ease(Tween.EASE_IN)
			_action_tween.tween_property(self, "position:x", position.x + 55.0, 0.10).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
			_action_tween.tween_property(self, "position:x", position.x, 0.35).set_ease(Tween.EASE_IN_OUT)
			_action_tween.tween_callback(func(): _is_performing_action = false)
			
		"hit":
			# 受击后仰冲量与闪烁
			_action_tween.tween_property(self, "position:x", position.x - 28.0, 0.06).set_trans(Tween.TRANS_EXPO)
			_action_tween.parallel().tween_property(self, "rotation", -0.08, 0.06)
			_action_tween.tween_property(self, "position:x", position.x, 0.25)
			_action_tween.parallel().tween_property(self, "rotation", 0.0, 0.25)
			_action_tween.tween_callback(func(): _is_performing_action = false)
			
		"telegraph":
			# 蓄势预兆：重心下沉 + 剧烈微颤
			_action_tween.tween_property(self, "position:y", position.y + 12.0, 0.2)
			_action_tween.tween_property(self, "scale", Vector2(1.08, 0.92), 0.2)
			_action_tween.tween_property(self, "position:y", position.y, 0.2)
			_action_tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.2)
			_action_tween.tween_callback(func(): _is_performing_action = false)
