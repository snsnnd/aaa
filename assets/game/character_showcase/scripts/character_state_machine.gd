@tool
class_name CharacterStateMachine
extends Node

## 角色表现层时间线与状态机 (Timeline-Driven Finite State Machine)
## 深度融合游戏核心机制：敌招阶段时间线 (raise/hold/commit/recover)、快慢刀停顿、假释放与凝滞 (Stagger)

signal state_changed(old_state: State, new_state: State)
signal phase_changed(phase_name: String)

enum State {
	IDLE,             # 待机态：持续呼吸与环境物理摆动
	PHASE_RAISE,      # 阶段-起手蓄力：抬刀/重心后移/蓄势
	PHASE_HOLD,       # 阶段-慢刀停顿：快慢刀关键停顿点，伴随假释放 (Fake Cue)
	PHASE_COMMIT,     # 阶段-出手承诺：真实落刀白芯/鬼手抓取/弹反判定点
	PHASE_RECOVER,    # 阶段-收招回落：敌招结束回位缓冲
	HIT,              # 受击硬直：受到伤害后仰
	STAGGER,          # 凝滞/破防：被镇煞卡牌时空凝滞或弹反后的大破绽（时间冻结）
	DEATH,            # 死亡消散：超度与升华
}

@export var initial_state: State = State.IDLE
@export var current_state: State = State.IDLE

# 时间线与阶段控制
var current_phase_name: String = "idle"
var state_time: float = 0.0
var is_time_frozen: bool = false # 是否处于凝滞/时空停顿中
var _character_view: Node = null


func setup(view_node: Node) -> void:
	_character_view = view_node
	transition_to(initial_state)


func transition_to(new_state: State, phase_name: String = "") -> void:
	if current_state == new_state and current_phase_name == phase_name and state_time > 0.0:
		return
		
	var old_state := current_state
	_exit_state(old_state)
	current_state = new_state
	current_phase_name = phase_name if not phase_name.is_empty() else State.keys()[new_state].to_lower()
	state_time = 0.0
	_enter_state(new_state, old_state)
	state_changed.emit(old_state, new_state)
	phase_changed.emit(current_phase_name)


## 阶段时间线驱动入口：由战斗模拟器 (BattleSimulation) 每帧传入当前阶段与进度
func sync_move_phase(phase: String, progress: float, is_staggered: bool) -> void:
	is_time_frozen = is_staggered
	
	if is_staggered:
		if current_state != State.STAGGER:
			transition_to(State.STAGGER, "stagger")
		return

	match phase:
		"raise":
			if current_state != State.PHASE_RAISE:
				transition_to(State.PHASE_RAISE, "raise")
		"hold":
			if current_state != State.PHASE_HOLD:
				transition_to(State.PHASE_HOLD, "hold")
		"commit", "strike":
			if current_state != State.PHASE_COMMIT:
				transition_to(State.PHASE_COMMIT, "commit")
		"feint":
			if current_state != State.PHASE_RAISE:
				transition_to(State.PHASE_RAISE, "feint")
		"reveal", "reach":
			if current_state != State.PHASE_COMMIT:
				transition_to(State.PHASE_COMMIT, "reveal")
		"recover", "reset":
			if current_state != State.PHASE_RECOVER:
				transition_to(State.PHASE_RECOVER, "recover")
		"idle", "":
			if current_state != State.IDLE and current_state != State.HIT and current_state != State.DEATH:
				transition_to(State.IDLE, "idle")
				
	if _character_view and _character_view.has_method("on_phase_progress"):
		_character_view.on_phase_progress(phase, progress)


func update(delta: float) -> void:
	if is_time_frozen:
		# 处于镇煞凝滞时，暂停内部时钟推进
		return
		
	state_time += delta
	_update_state(current_state, delta)


func _enter_state(state: State, _from: State) -> void:
	if _character_view == null:
		return
	match state:
		State.IDLE:
			_character_view.on_enter_idle()
		State.PHASE_RAISE:
			_character_view.on_enter_raise()
		State.PHASE_HOLD:
			_character_view.on_enter_hold()
		State.PHASE_COMMIT:
			_character_view.on_enter_commit()
		State.PHASE_RECOVER:
			_character_view.on_enter_recover()
		State.HIT:
			_character_view.on_enter_hit()
		State.STAGGER:
			_character_view.on_enter_stagger()
		State.DEATH:
			_character_view.on_enter_death()


func _exit_state(state: State) -> void:
	if _character_view == null:
		return
	match state:
		State.PHASE_RAISE, State.PHASE_HOLD, State.PHASE_COMMIT, State.HIT, State.STAGGER:
			_character_view.on_exit_action()


func _update_state(state: State, delta: float) -> void:
	if _character_view == null:
		return
	if state == State.IDLE or state == State.STAGGER or state == State.PHASE_HOLD:
		_character_view.update_idle_physics(delta, state == State.STAGGER or state == State.PHASE_HOLD)
