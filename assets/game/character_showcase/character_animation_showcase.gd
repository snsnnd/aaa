extends Control

## Character Animation Showcase Gallery
## 角色动效状态机与阶段时间线展厅

const CharacterAnimProfileScript := preload("res://assets/game/character_showcase/scripts/character_anim_profile.gd")
const ModularCharacterViewScript := preload("res://assets/game/character_showcase/scripts/modular_character_view.gd")
const CharacterStateMachineScript := preload("res://assets/game/character_showcase/scripts/character_state_machine.gd")

const ROSTER := [
	{
		"name": "执灯人 (玩家/人型呼吸)",
		"profile": "res://assets/game/character_showcase/profiles/profile_keeper.tres",
		"texture": "res://assets/demo/player_keeper.png",
		"weapon": "",
		"aura": ""
	},
	{
		"name": "灯笼小鬼 (浮空漂移/微颤)",
		"profile": "res://assets/game/character_showcase/profiles/profile_lantern_imp.tres",
		"texture": "res://assets/game/enemies/lantern_imp.png",
		"weapon": "",
		"aura": ""
	},
	{
		"name": "更练尸 (机械巡更顿挫)",
		"profile": "res://assets/game/character_showcase/profiles/profile_patrol_corpse.tres",
		"texture": "res://assets/game/enemies/patrol_corpse.png",
		"weapon": "res://assets/demo/enemy_blade.png",
		"aura": ""
	},
	{
		"name": "纸扎学徒 (折纸风吹微颤)",
		"profile": "res://assets/game/character_showcase/profiles/profile_paper_apprentice.tres",
		"texture": "res://assets/game/enemies/paper_apprentice.png",
		"weapon": "",
		"aura": ""
	},
	{
		"name": "赌鬼 (神经质高频抽搐)",
		"profile": "res://assets/game/character_showcase/profiles/profile_gambler_ghost.tres",
		"texture": "res://assets/game/enemies/gambler_ghost.png",
		"weapon": "",
		"aura": ""
	},
	{
		"name": "守灯人 (Boss/领域脉冲)",
		"profile": "res://assets/game/character_showcase/profiles/profile_lantern_keeper_boss.tres",
		"texture": "res://assets/game/enemies/lantern_keeper.png",
		"weapon": "",
		"aura": "res://assets/game/vfx/textures/tex_shockwave_ring.png"
	}
]

@onready var char_container: Node2D = $Stage/CharacterContainer
@onready var info_label: Label = $UI/Panel/VBox/InfoLabel
@onready var desc_label: Label = $UI/Panel/VBox/DescLabel
@onready var state_label: Label = $UI/Panel/VBox/StateLabel
@onready var char_list: VBoxContainer = $UI/Panel/VBox/Scroll/CharList
@onready var bg_texture: TextureRect = $Stage/OldStreetBG

var current_char_view: ModularCharacterView = null
var current_entry: Dictionary = {}


func _ready() -> void:
	_setup_roster_buttons()
	_load_character(0)


func _setup_roster_buttons() -> void:
	for i in ROSTER.size():
		var entry: Dictionary = ROSTER[i]
		var btn := Button.new()
		btn.text = entry["name"]
		btn.custom_minimum_size.y = 36
		btn.pressed.connect(func(): _load_character(i))
		char_list.add_child(btn)


func _load_character(index: int) -> void:
	current_entry = ROSTER[index]
	if current_char_view:
		current_char_view.queue_free()
		
	var base_scene: PackedScene = load("res://assets/game/character_showcase/scenes/modular_character_view.tscn")
	current_char_view = base_scene.instantiate()
	
	var prof: CharacterAnimProfileScript = load(current_entry["profile"])
	current_char_view.profile = prof
	current_char_view.texture_body = load(current_entry["texture"])
	if not current_entry["weapon"].is_empty():
		current_char_view.texture_weapon = load(current_entry["weapon"])
	if not current_entry["aura"].is_empty():
		current_char_view.texture_aura = load(current_entry["aura"])
		
	char_container.add_child(current_char_view)
	
	info_label.text = "【当前角色】: %s" % prof.display_name
	desc_label.text = "【动效特征】: %s" % prof.motion_notes


func _process(_delta: float) -> void:
	if current_char_view and current_char_view.state_machine:
		var st = current_char_view.state_machine.current_state
		var ph = current_char_view.state_machine.current_phase_name
		state_label.text = "当前状态: [%s] (阶段: %s)" % [CharacterStateMachine.State.keys()[st], ph]


func trigger_state(state: CharacterStateMachine.State, phase_name: String = "") -> void:
	if current_char_view and current_char_view.state_machine:
		current_char_view.state_machine.transition_to(state, phase_name)


func _on_idle_pressed() -> void:
	trigger_state(CharacterStateMachine.State.IDLE, "idle")

func _on_raise_pressed() -> void:
	trigger_state(CharacterStateMachine.State.PHASE_RAISE, "raise")

func _on_hold_pressed() -> void:
	trigger_state(CharacterStateMachine.State.PHASE_HOLD, "hold")

func _on_commit_pressed() -> void:
	trigger_state(CharacterStateMachine.State.PHASE_COMMIT, "commit")

func _on_recover_pressed() -> void:
	trigger_state(CharacterStateMachine.State.PHASE_RECOVER, "recover")

func _on_hit_pressed() -> void:
	trigger_state(CharacterStateMachine.State.HIT, "hit")

func _on_stagger_pressed() -> void:
	trigger_state(CharacterStateMachine.State.STAGGER, "stagger")

func _on_death_pressed() -> void:
	trigger_state(CharacterStateMachine.State.DEATH, "death")

func _on_bg_toggle_toggled(button_pressed: bool) -> void:
	bg_texture.visible = button_pressed

func _on_speed_slider_value_changed(value: float) -> void:
	Engine.time_scale = value
	$UI/Panel/VBox/SpeedRow/SpeedVal.text = "%.1fx" % value
