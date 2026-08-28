extends Control

## VFX Preview Gallery / 特效交互式预览器
## 方便在 Godot 编辑器内直接按 F6 运行，可视化查看并测试所有特效

const VFX_SCENES := {
	"完美弹反 (★ 满配)": "res://assets/game/vfx/scenes/vfx_perfect_parry.tscn",
	"防范金弧护盾": "res://assets/game/vfx/scenes/vfx_guard_arc.tscn",
	"斩纸 / 断念": "res://assets/game/vfx/scenes/vfx_paper_burst.tscn",
	"还刃 / 乘势重斩": "res://assets/game/vfx/scenes/vfx_counter_slash.tscn",
	"镇煞 / 缚魂八卦": "res://assets/game/vfx/scenes/vfx_seal_ring.tscn",
	"撞钟 / 听更声波": "res://assets/game/vfx/scenes/vfx_bell_wave.tscn",
	"续灯 / 命火余烬": "res://assets/game/vfx/scenes/vfx_soul_embers.tscn",
	"幽冥鬼火预兆": "res://assets/game/vfx/scenes/vfx_ghost_flame_burst.tscn",
	"通用受击火花": "res://assets/game/vfx/scenes/vfx_hit_sparks.tscn",
	"超度解脱消散": "res://assets/game/vfx/scenes/vfx_death_dissolve.tscn",
}

@onready var vfx_container: Node2D = $VFXContainer
@onready var info_label: Label = $UI/Panel/VBox/InfoLabel
@onready var btn_container: VBoxContainer = $UI/Panel/VBox/ButtonScroll/ButtonList
@onready var loop_check: CheckBox = $UI/Panel/VBox/LoopCheck
@onready var bg_texture: TextureRect = $Background
@onready var crosshair: Node2D = $Crosshair

var current_scene_path: String = ""
var current_vfx_node: Node2D = null
var current_tint: Color = Color.WHITE
var current_scale: float = 1.0
var loop_timer: float = 0.0


func _ready() -> void:
	_setup_buttons()
	# Play first VFX by default
	_play_vfx(VFX_SCENES["完美弹反 (★ 满配)"], "完美弹反 (★ 满配)")


func _setup_buttons() -> void:
	for name in VFX_SCENES:
		var btn := Button.new()
		btn.text = name
		btn.custom_minimum_size.y = 36
		var path: String = VFX_SCENES[name]
		btn.pressed.connect(func(): _play_vfx(path, name))
		btn_container.add_child(btn)


func _play_vfx(path: String, vfx_name: String) -> void:
	current_scene_path = path
	info_label.text = "当前特效: %s\n路径: %s\n提示: 在右侧空白区域【鼠标左键点击】可任意位置生成" % [vfx_name, path.get_file()]
	
	_spawn_at(Vector2(760, 360))


func _spawn_at(pos: Vector2) -> void:
	if current_scene_path.is_empty():
		return
		
	var packed: PackedScene = load(current_scene_path)
	if packed == null:
		return
		
	var node: Node2D = packed.instantiate()
	node.position = pos
	node.scale = Vector2.ONE * current_scale
	node.modulate = current_tint
	vfx_container.add_child(node)
	if node.has_method("play"):
		node.play()
	current_vfx_node = node


func _process(delta: float) -> void:
	if loop_check.button_pressed and not current_scene_path.is_empty():
		loop_timer += delta
		if loop_timer >= 1.0:
			loop_timer = 0.0
			_spawn_at(Vector2(760, 360))


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if event.position.x > 320: # Outside control panel
			_spawn_at(event.position)


func _on_bg_toggle_toggled(button_pressed: bool) -> void:
	bg_texture.visible = button_pressed


func _on_scale_slider_value_changed(value: float) -> void:
	current_scale = value
	$UI/Panel/VBox/ScaleRow/ScaleVal.text = "%.1fx" % value


func _on_color_selected(color_type: int) -> void:
	match color_type:
		0: current_tint = Color.WHITE
		1: current_tint = Color("bd3d45") # 赤·嗔
		2: current_tint = Color("43a9b2") # 碧·痴
		3: current_tint = Color("6d9663") # 青·疑
		4: current_tint = Color("f2d487") # 金·煞
