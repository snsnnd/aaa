@tool
class_name ModularCardView
extends Control

## Modular 2D Card View Component / 模块化中式怪谈卡牌组件
## 集成中式黑漆木符纸卡框、2.5D 视差悬停、还愿点消耗槽、乘势高光与状态响应

signal card_clicked(card_id: String)
signal card_hovered(card_id: String)
signal card_unhovered(card_id: String)

@export var card_id: String = "attack":
	set(val):
		card_id = val
		if is_node_ready():
			_update_card_display()

@export var card_title: String = "斩纸"
@export var card_class: String = "斩" # 斩 / 御 / 佑
@export var card_cost: int = 1
@export var card_description: String = "散去 [color=#bd3d45]5[/color] 怨气"
@export var icon_texture: Texture2D

@export_group("State & Visuals")
@export var is_affordable: bool = true:
	set(val):
		is_affordable = val
		_update_affordability_visuals()
@export var is_stagger_bonus_active: bool = false:
	set(val):
		is_stagger_bonus_active = val
		_update_stagger_glow()

# Card Framing Textures
const FRAMES := {
	"斩": preload("res://assets/game/ui/card_frame_zhan.png"),
	"御": preload("res://assets/game/ui/card_frame_yu.png"),
	"佑": preload("res://assets/game/ui/card_frame_you.png"),
}

const CLASS_COLORS := {
	"斩": Color("bd3d45"),
	"御": Color("43a9b2"),
	"佑": Color("6d9663"),
}

# Node references
@onready var card_root: Control = $CardPivot
@onready var frame_sprite: TextureRect = $CardPivot/FrameTexture
@onready var icon_sprite: TextureRect = $CardPivot/IconTexture
@onready var cost_label: Label = $CardPivot/CostBadge/CostLabel
@onready var cost_badge: Control = $CardPivot/CostBadge
@onready var class_label: Label = $CardPivot/ClassBadge/ClassLabel
@onready var title_label: Label = $CardPivot/TitleLabel
@onready var desc_label: RichTextLabel = $CardPivot/DescLabel
@onready var stagger_glow: TextureRect = $CardPivot/StaggerGlow
@onready var dark_overlay: ColorRect = $CardPivot/DarkOverlay

var _is_hovered: bool = false
var _base_scale: Vector2 = Vector2.ONE
var _target_tilt: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
	_update_card_display()


func setup_card_data(data: Dictionary, pres: Dictionary) -> void:
	card_id = String(data.get("id", "attack"))
	card_title = String(data.get("title", pres.get("title", "斩纸")))
	card_class = String(data.get("class", "斩"))
	card_cost = int(data.get("cost", 1))
	card_description = _format_description(data)
	
	if pres.has("icon") and ResourceLoader.exists(pres["icon"]):
		icon_texture = load(pres["icon"])
	else:
		var custom_icon := "res://assets/game/cards/card_%s.png" % card_id
		if ResourceLoader.exists(custom_icon):
			icon_texture = load(custom_icon)
			
	_update_card_display()


func _format_description(data: Dictionary) -> String:
	var id: String = String(data.get("id", ""))
	match id:
		"attack":
			return "散去 [color=#bd3d45]%d[/color] 怨气" % data.get("damage", 5)
		"shatter":
			return "散去 [color=#bd3d45]%d[/color] 怨气\n[color=#f2a03c]乘势加成: 僵直内 +%d[/color]" % [data.get("damage", 12), data.get("bonus", 6)]
		"guard":
			return "散去 [color=#43a9b2]%d[/color] 怨气\n[color=#43a9b2]凝滞敌人 0.35s[/color]" % data.get("damage", 6)
		"shift":
			return "回复 [color=#ffd460]%d[/color] 命火灯油" % data.get("heal", 7)
		"duannian":
			return "散去 [color=#bd3d45]%d[/color] 怨气\n弃置 1 张随机手牌" % data.get("damage", 8)
		"dengxin":
			return "回复 [color=#ffd460]%d[/color] 命火灯油" % data.get("heal", 4)
		"zhuangzhong":
			return "散去 [color=#bd3d45]%d[/color] 怨气\n[color=#43a9b2]凝滞 0.20s[/color]" % data.get("damage", 5)
		"anhun":
			return "安魂咒：消除下一敌招的不可防范标记"
		"duanxiang":
			return "识破假象：压制敌方慢刀假动作"
		"tinggeng":
			return "听更：洞察下一敌招类型"
		"jieshi":
			return "借势：下一次防范必定按[color=#ffd460]完美[/color]计"
		"tongjing":
			return "铜镜反光：防范成功时反击 [color=#43a9b2]3[/color] 怨气"
		"podan":
			return "破胆：敌下一招伤害 [color=#43a9b2]-40%%[/color]"
		"jinshen":
			return "金身符：下一次受击固定承受 5 点"
		_:
			if data.has("damage"):
				return "散去 [color=#bd3d45]%d[/color] 怨气" % data["damage"]
			elif data.has("heal"):
				return "回复 [color=#ffd460]%d[/color] 命火" % data["heal"]
			return "符咒秘法"


func _update_card_display() -> void:
	if not is_inside_tree() or frame_sprite == null:
		return
		
	# 1. Update Frame Texture
	if FRAMES.has(card_class):
		frame_sprite.texture = FRAMES[card_class]
		
	# 2. Update Icon
	if icon_texture and icon_sprite:
		icon_sprite.texture = icon_texture
		
	# 3. Update Labels
	if title_label:
		title_label.text = card_title
	if class_label:
		class_label.text = card_class
		var col: Color = CLASS_COLORS.get(card_class, Color.WHITE)
		class_label.modulate = col
	if cost_label:
		cost_label.text = str(card_cost)
	if desc_label:
		desc_label.text = card_description
		
	_update_affordability_visuals()
	_update_stagger_glow()


func _update_affordability_visuals() -> void:
	if not is_inside_tree() or dark_overlay == null:
		return
	if is_affordable:
		dark_overlay.visible = false
		cost_badge.modulate = Color.WHITE
	else:
		dark_overlay.visible = true
		cost_badge.modulate = Color("ff6b6b")


func _update_stagger_glow() -> void:
	if not is_inside_tree() or stagger_glow == null:
		return
	stagger_glow.visible = (card_id == "shatter" and is_stagger_bonus_active)


func _process(delta: float) -> void:
	if _is_hovered:
		# 2.5D Tilt based on mouse relative to center
		var mouse_pos := get_local_mouse_position()
		var center := size * 0.5
		var norm := (mouse_pos - center) / center
		_target_tilt = Vector2(norm.y * -0.12, norm.x * 0.12)
	else:
		_target_tilt = Vector2.ZERO
		
	card_root.rotation = lerpf(card_root.rotation, _target_tilt.y, minf(1.0, delta * 15.0))


func _on_mouse_entered() -> void:
	_is_hovered = true
	z_index = 20
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(card_root, "scale", Vector2(1.14, 1.14), 0.18)
	tw.tween_property(card_root, "position:y", -28.0, 0.18)
	card_hovered.emit(card_id)


func _on_mouse_exited() -> void:
	_is_hovered = false
	z_index = 0
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(card_root, "scale", Vector2.ONE, 0.22)
	tw.tween_property(card_root, "position:y", 0.0, 0.22)
	tw.tween_property(card_root, "rotation", 0.0, 0.22)
	card_unhovered.emit(card_id)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_affordable:
			# Play click bounce animation
			var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(card_root, "scale", Vector2(1.24, 1.24), 0.08)
			tw.tween_property(card_root, "scale", Vector2(1.14, 1.14), 0.12)
			card_clicked.emit(card_id)
