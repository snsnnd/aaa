extends RefCounted

## 玩家动作控制器：驱动姿态语言轨道（PlayerPoseLibrary）。
## 每帧 tick 求值关键帧 → 写入 player_anim.action_pose 通道，
## 由 player_anim 统一与呼吸/战斗姿态/受击冲量混合。
## 逐帧求值（非 Tween）保证动作可被取消/覆盖——FSM 语义与视觉严格同步。
## 轨道时间使用事件携带的"已缩放"时间轴（seamless 更快等），与规则层完全一致。

const BattleViewScript := preload("res://scripts/presentation/battle_view.gd")
const PlayerPoseLibraryScript := preload("res://scripts/presentation/player_pose_library.gd")
const ActionCatalogScript := preload("res://scripts/battle/action_catalog.gd")

var view: BattleViewScript
var track: Dictionary = {}
var track_time := 0.0
var track_playing := false
var blend_weight := 0.0
var _fade_out := false


func setup(v: BattleViewScript) -> void:
	view = v


func tick(delta: float) -> void:
	if view == null or view.player_anim == null:
		return
	if track_playing:
		track_time += delta
		blend_weight = minf(1.0, blend_weight + delta * 14.0)
		if track_time >= float(track.get("total", 0.0)):
			track_playing = false
			_fade_out = true
	else:
		blend_weight = maxf(0.0, blend_weight - delta * 7.0)
	var pose := {}
	if blend_weight > 0.0:
		if track_playing and not track.is_empty():
			pose = PlayerPoseLibraryScript.evaluate(track, track_time)
		else:
			pose = PlayerPoseLibraryScript.POSES["recover"]
	view.player_anim.set_action_pose(pose, blend_weight)
	if not track_playing and blend_weight <= 0.0:
		_fade_out = false


func on_action_started(transition: String, movement: String, vfx_tier: int, startup: float, impact_time: float, recovery: float, action_id: String) -> void:
	if view == null or action_id == "":
		return
	var def: Dictionary = ActionCatalogScript.ACTIONS.get(action_id, {}).duplicate()
	def["startup"] = startup
	def["impact_time"] = impact_time
	def["recovery"] = recovery
	def["movement"] = movement
	track = PlayerPoseLibraryScript.track_for(action_id, def)
	track_time = 0.0
	track_playing = true
	_fade_out = false
	if transition == "seamless":
		_chain_flash(vfx_tier)


## 动作被取消（受击/防反）：切换到对应短轨道。
func on_action_canceled(reason: String) -> void:
	match reason:
		"hit":
			_start_track(PlayerPoseLibraryScript.hurt_track())
		"parry":
			_start_track(PlayerPoseLibraryScript.parry_track(false))
		_:
			pass  # card_cancel：新动作轨道立即接管


## 防反命中：parry_high 余韵轨道（动作执行中不覆盖出招姿态）。
func on_parry(perfect: bool, action_busy: bool) -> void:
	if view == null or action_busy:
		return
	_start_track(PlayerPoseLibraryScript.parry_track(perfect))


func _start_track(t: Dictionary) -> void:
	track = t
	track_time = 0.0
	track_playing = true
	_fade_out = false


## 连势闪光：转场越顺，身位越亮（保留既有轻量反馈）。
func _chain_flash(tier: int) -> void:
	var sprite: Sprite2D = view.player_anim.player_sprite
	var flash := Color(1.0, 0.92, 0.72).lerp(Color(1.0, 0.75, 0.35), clampf(tier / 3.0, 0.0, 1.0))
	view.motion.play("player_flash", func(host: Node) -> Tween:
		sprite.modulate = flash
		var tw := host.create_tween()
		tw.tween_property(sprite, "modulate", Color.WHITE, 0.28)
		return tw)
	if tier >= 2:
		view.pulse_glow(0.25 + 0.2 * tier)
