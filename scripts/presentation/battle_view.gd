extends Node2D

## 视图层门面：装配舞台/玩家/敌人/特效四个子模块并转发调用。
## main.gd 只与本文件对话。

const ASSET_FOLDER := "demo"
const BattleSimulationScript := preload("res://scripts/battle/battle_simulation.gd")
const PresentationCatalog := preload("res://scripts/presentation/presentation_catalog.gd")
const FxStateScript := preload("res://scripts/presentation/fx_state.gd")
const BattleStageScript := preload("res://scripts/presentation/battle_stage.gd")
const PlayerAnimScript := preload("res://scripts/presentation/player_anim.gd")
const EnemyAnimScript := preload("res://scripts/presentation/enemy_anim.gd")
const BattleVfxScript := preload("res://scripts/presentation/battle_vfx.gd")

var sim: BattleSimulationScript
var fx: FxStateScript
var stage: BattleStageScript
var player_anim: PlayerAnimScript
var enemy_anim: EnemyAnimScript
var vfx: BattleVfxScript
var parry_audio: AudioStreamPlayer
var hurt_audio: AudioStreamPlayer
var card_audio: AudioStreamPlayer
var warning_audio: AudioStreamPlayer
var animation_time := 0.0
var hitstop_running := false
var loaded_enemy := ""

var shake_enabled: bool:
	get:
		return fx.shake_enabled
	set(value):
		fx.shake_enabled = value
var enemy_sprite: Sprite2D:
	get:
		return enemy_anim.enemy_sprite
var weapon_pivot: Node2D:
	get:
		return enemy_anim.weapon_pivot
var weapon_sprite: Sprite2D:
	get:
		return enemy_anim.weapon_sprite
var ghost_hand: Node2D:
	get:
		return enemy_anim.ghost_hand
var lantern_sprite: Sprite2D:
	get:
		return player_anim.lantern_sprite
var player_sprite: Sprite2D:
	get:
		return player_anim.player_sprite
var background: Sprite2D:
	get:
		return stage.background
var rain_drops: Array[Line2D]:
	get:
		return stage.rain_drops


func setup(s: BattleSimulationScript) -> void:
	sim = s
	fx = FxStateScript.new()
	stage = BattleStageScript.new()
	add_child(stage)
	stage.setup(fx)
	player_anim = PlayerAnimScript.new()
	add_child(player_anim)
	player_anim.setup(fx)
	enemy_anim = EnemyAnimScript.new()
	add_child(enemy_anim)
	enemy_anim.setup(fx)
	vfx = BattleVfxScript.new()
	add_child(vfx)
	vfx.setup(fx, stage, player_anim, enemy_anim)

	stage.load_style(ASSET_FOLDER)
	player_anim.load_style(ASSET_FOLDER)
	enemy_anim.load_style(ASSET_FOLDER)

	parry_audio = _audio_player(PresentationCatalog.AUDIO.parry)
	hurt_audio = _audio_player(PresentationCatalog.AUDIO.hurt)
	card_audio = _audio_player(PresentationCatalog.AUDIO.card)
	warning_audio = _audio_player(PresentationCatalog.AUDIO.warning)


func _audio_player(path: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = load(path)
	add_child(player)
	return player


func view_time() -> float:
	return animation_time


func intent_color() -> Color:
	return GameSettings.adjust_color(PresentationCatalog.MOVE_PRESENTATION[String(sim.current_intent.id)].color)


func add_trauma(amount: float) -> void:
	fx.trauma = minf(1.0, fx.trauma + amount * GameSettings.shake_scale)


func pulse_glow(value: float) -> void:
	fx.glow_boost = maxf(fx.glow_boost, value)


func set_glow(value: float) -> void:
	fx.glow_boost = value


func tick(delta: float) -> void:
	animation_time += delta
	stage.tick(delta, animation_time)
	player_anim.tick(delta)
	enemy_anim.tick(delta)


func play_warning() -> void:
	warning_audio.play()


func play_card_sfx(card_id: String = "") -> void:
	card_audio.play()
	player_anim.cast_card_action(card_id)


func hit_stop(duration: float, time_scale: float) -> void:
	if hitstop_running:
		return
	hitstop_running = true
	GameTime.hitstop(duration, time_scale)
	await get_tree().create_timer(duration, true, false, true).timeout
	hitstop_running = false


func apply_attack_presentation() -> void:
	if sim.enemy_id != loaded_enemy:
		loaded_enemy = sim.enemy_id
		enemy_anim.load_enemy_texture(loaded_enemy)
	enemy_anim.apply_presentation()


func finish_action_fx() -> void:
	enemy_anim.finish_action_fx()


func commit_flash(color: Color) -> void:
	warning_audio.play()
	enemy_anim.commit_flash(color)


func fake_release() -> void:
	add_trauma(0.035)
	warning_audio.play()
	enemy_anim.fake_release()


func take_hit(damage: int) -> void:
	hurt_audio.play()
	add_trauma(0.58)
	player_anim.take_hit_visual()


func small_enemy_hit(strength: float) -> void:
	add_trauma(strength)
	enemy_anim.small_hit()
	vfx.hit_sparks()


func parry_feedback(pos: Vector2, major: bool) -> void:
	parry_audio.play()
	add_trauma(0.82 if major else 0.48)
	vfx.parry_burst(pos, intent_color(), 22 if major else 11)
	enemy_anim.parry_squash()


func contact_point() -> Vector2:
	return player_anim.contact_point()


func snap_ghost_hand_back() -> void:
	enemy_anim.snap_ghost_hand_back()


func guard_arc(color := Color("f2d487")) -> void:
	vfx.guard_arc(color)


func paper_burst(tint := Color("e8d9a8")) -> void:
	vfx.paper_burst(tint)


func bell_wave() -> void:
	vfx.bell_wave()


func enemy_cue_fx(enemy_id: String, move_id: String) -> void:
	vfx.enemy_cue_fx(enemy_anim.enemy_sprite.position, enemy_id, move_id, intent_color())


func counter_slash(charged: bool) -> void:
	vfx.counter_slash(charged)


func seal_ring() -> void:
	vfx.seal_ring()


func summon_vfx(id: String) -> void:
	player_anim.summon_vfx(PresentationCatalog.CARD_PRESENTATION[id].color)


func embers() -> void:
	player_anim.embers()


func spawn_talisman(id: String) -> void:
	player_anim.spawn_talisman(id, PresentationCatalog.CARD_PRESENTATION[id])


func success_impact_fx() -> void:
	parry_feedback(contact_point(), false)
	fx.impulse_x = -18.0
	pulse_glow(0.45)
	fx.enemy_push = 26.0
	enemy_anim.snap_ghost_hand_back()


func perfect_impact_fx() -> void:
	parry_feedback(contact_point(), true)
	hit_stop(0.11, 0.06)
	fx.impulse_x = -10.0
	set_glow(1.0)
	player_anim.perfect_flash()
	fx.enemy_push = 55.0
	enemy_anim.snap_ghost_hand_back()


func defense_miss_fx(unblockable: bool) -> void:
	fx.impulse_x = -20.0
	fx.impulse_rot = -0.07
	vfx.guard_arc(Color("c14b4b") if unblockable else Color("a8564f"))


func enemy_staggered_fx() -> void:
	enemy_anim.staggered_fx()
	add_trauma(0.2)


func rage_flare(origin: Vector2) -> void:
	vfx.rage_flare(origin)


func present_death(victory: bool) -> void:
	if victory:
		hit_stop(0.3, 0.25)
		enemy_anim.death_dissolve()
		vfx.death_dissolve(enemy_anim.enemy_sprite.position)
	else:
		player_anim.death_dim()
		vfx.death_dissolve(player_anim.player_pivot.position + Vector2(118, 40))


func restart_fx() -> void:
	GameTime.release("hitstop")
	GameTime.release("slowmo")
	fx.reset()
	player_anim.player_sprite.modulate = Color.WHITE
	enemy_anim.enemy_aura.modulate.a = 0.5
	enemy_anim.reset_pose()
