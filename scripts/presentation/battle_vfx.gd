extends Node

## VFX 服务：所有战斗特效通过场景资产实例化（VFXStandaloneEmitter 自管理回收）。
## 调用方只提供位置和（可选）色调，不关心内部粒子/动画结构。
## 场景列表见 assets/game/vfx/scenes/。

const FxState := preload("res://scripts/presentation/fx_state.gd")
const PresentationCatalog := preload("res://scripts/presentation/presentation_catalog.gd")

const FX := {
	"guard_arc": preload("res://assets/game/vfx/scenes/vfx_guard_arc.tscn"),
	"perfect_parry": preload("res://assets/game/vfx/scenes/vfx_perfect_parry.tscn"),
	"paper_burst": preload("res://assets/game/vfx/scenes/vfx_paper_burst.tscn"),
	"counter_slash": preload("res://assets/game/vfx/scenes/vfx_counter_slash.tscn"),
	"seal_ring": preload("res://assets/game/vfx/scenes/vfx_seal_ring.tscn"),
	"hit_sparks": preload("res://assets/game/vfx/scenes/vfx_hit_sparks.tscn"),
	"bell_wave": preload("res://assets/game/vfx/scenes/vfx_bell_wave.tscn"),
	"soul_embers": preload("res://assets/game/vfx/scenes/vfx_soul_embers.tscn"),
	"death_dissolve": preload("res://assets/game/vfx/scenes/vfx_death_dissolve.tscn"),
	"ghost_flame": preload("res://assets/game/vfx/scenes/vfx_ghost_flame_burst.tscn"),
}

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


## 统一入口：实例化场景 → 位置/色调/z_index → add_child（emitter 自回收）。
func _spawn(id: String, pos: Vector2, tint := Color.WHITE) -> void:
	if not FX.has(id):
		return
	var inst: Node2D = FX[id].instantiate()
	inst.position = pos
	inst.z_index = 15
	if "effect_tint" in inst:
		inst.effect_tint = tint
	add_child(inst)


func guard_arc(color := Color("f2d487")) -> void:
	_spawn("guard_arc", player_anim.guard_arc_position(), color)


func paper_burst(tint := Color("e8d9a8")) -> void:
	_spawn("paper_burst", enemy_pos(Vector2(-30, -20)), tint)


func counter_slash(charged: bool) -> void:
	var tint := Color("ff9d5c") if charged else Color("e0b45c")
	_spawn("counter_slash", enemy_pos(Vector2(-20, -30)), tint)
	fx.trauma = minf(1.0, fx.trauma + (0.3 if charged else 0.18))


func seal_ring() -> void:
	_spawn("seal_ring", enemy_pos(Vector2(-10, -10)))
	enemy_anim.enemy_sprite.modulate = Color("9fd8de")
	create_tween().tween_property(enemy_anim.enemy_sprite, "modulate", Color.WHITE, 0.5)


func hit_sparks() -> void:
	_spawn("hit_sparks", enemy_pos(Vector2(-46, -34)))


func bell_wave() -> void:
	_spawn("bell_wave", enemy_pos(Vector2(-40, -30)))
	fx.trauma = minf(1.0, fx.trauma + 0.22)


func embers() -> void:
	_spawn("soul_embers", player_anim.lantern_glow.position)


func summon_vfx(color: Color) -> void:
	_spawn("ghost_flame", player_anim.player_pivot.position + Vector2(24, -50), color)


func parry_burst(pos: Vector2, color: Color, count: int) -> void:
	if count >= 15:
		_spawn("perfect_parry", pos, color)
	else:
		_spawn("hit_sparks", pos, color)


func death_dissolve(pos: Vector2) -> void:
	_spawn("death_dissolve", pos + Vector2(-20, -30))


## 敌人出招提示特效（每个敌人独有视觉语言）
func enemy_cue_fx(origin: Vector2, enemy_id: String, move_id: String, color: Color) -> void:
	match enemy_id:
		"lantern_imp":
			_spawn("ghost_flame", origin + Vector2(-30, -40), Color("f2a03c"))
		"paper_apprentice":
			_spawn("paper_burst", origin + Vector2(-20, -40), Color("d8ceb0"))
		"patrol_corpse":
			_spawn("bell_wave", origin + Vector2(20, -30), Color("8f7a3f"))
		"barber_ghost":
			_spawn("counter_slash", origin + Vector2(-10, -20), Color("e8edf0"))
		"well_sisters":
			_spawn("soul_embers", origin + Vector2(-20, -40), Color("5a9ab0"))
		"gambler_ghost":
			_spawn("ghost_flame", origin + Vector2(0, -40), Color("e0b45c"))
		"mortuary_warden":
			_spawn("seal_ring", origin + Vector2(-10, -10), Color("57493a"))
		"lantern_keeper":
			_spawn("bell_wave", origin + Vector2(-20, -30), Color("f2d487"))
		_:
			pass


## 残血怒气视觉
func rage_flare(origin: Vector2) -> void:
	_spawn("ghost_flame", origin + Vector2(-12, -30), Color(0.85, 0.2, 0.16))


func death_dissolve_enemy(pos: Vector2) -> void:
	_spawn("death_dissolve", pos + Vector2(-30, -40), Color("9fdce2"))
