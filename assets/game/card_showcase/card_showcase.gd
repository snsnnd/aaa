extends Control

## Card Showcase & Hand Simulator Controller
## 卡牌全景鉴赏与手牌扇形交互模拟器

const ContentCatalog := preload("res://scripts/battle/content_catalog.gd")
const PresentationCatalog := preload("res://scripts/presentation/presentation_catalog.gd")
const ModularCardViewScript := preload("res://assets/game/card_showcase/scripts/modular_card_view.gd")
const HandFanContainerScript := preload("res://assets/game/card_showcase/scripts/hand_fan_container.gd")

const ALL_CARDS := [
	# 斩类
	{"id": "attack", "title": "斩纸", "class": "斩", "cost": 1, "damage": 5},
	{"id": "shatter", "title": "还刃", "class": "斩", "cost": 2, "damage": 12, "bonus": 6},
	{"id": "duannian", "title": "断念", "class": "斩", "cost": 2, "damage": 8},
	{"id": "zhuangzhong", "title": "撞钟", "class": "斩", "cost": 2, "damage": 5},
	{"id": "zhuying", "title": "逐影", "class": "斩", "cost": 1, "damage": 4},
	{"id": "liebo", "title": "裂帛", "class": "斩", "cost": 1, "damage": 6},
	{"id": "xuezhang", "title": "血账", "class": "斩", "cost": 2, "damage": 6},
	{"id": "baiguyin", "title": "白骨引", "class": "斩", "cost": 2, "damage": 0},
	{"id": "shoulian", "title": "收殓", "class": "斩", "cost": 3, "damage": 10},
	{"id": "shuangdeng", "title": "双灯照", "class": "斩", "cost": 3, "damage": 7},
	{"id": "yuangui", "title": "怨归", "class": "斩", "cost": 3, "damage": 14},
	{"id": "tianping", "title": "极·天平倒悬", "class": "斩", "cost": 5, "damage": 30},
	# 御类
	{"id": "guard", "title": "镇煞", "class": "御", "cost": 2, "damage": 6},
	{"id": "difan", "title": "低幡", "class": "御", "cost": 1, "stagger": 0.25},
	{"id": "jieshi", "title": "借势", "class": "御", "cost": 1, "force_perfect": true},
	{"id": "tongjing", "title": "铜镜", "class": "御", "cost": 1, "mirror": 1},
	{"id": "fuhunsuo", "title": "缚魂索", "class": "御", "cost": 2, "stagger": 0.5},
	{"id": "jiedao", "title": "借刀", "class": "御", "cost": 2, "interrupt": true},
	{"id": "jinshen", "title": "金身", "class": "御", "cost": 2, "golden": 1},
	{"id": "podan", "title": "破胆", "class": "御", "cost": 2, "fear_mul": 0.6},
	{"id": "duanxiang", "title": "断香", "class": "御", "cost": 1, "suppress_fake": true},
	# 佑类
	{"id": "shift", "title": "续灯", "class": "佑", "cost": 2, "heal": 7},
	{"id": "dengxin", "title": "灯芯", "class": "佑", "cost": 1, "heal": 4},
	{"id": "tianyou", "title": "添油", "class": "佑", "cost": 2, "heal": 6},
	{"id": "wenlu", "title": "问路", "class": "佑", "cost": 1, "draw": 1},
	{"id": "zhima", "title": "纸马", "class": "佑", "cost": 2, "summon": 2},
	{"id": "changming", "title": "长明", "class": "佑", "cost": 2, "max_hp": 6},
	{"id": "jieshou", "title": "借寿", "class": "佑", "cost": 1, "heal": 10},
	{"id": "anhun", "title": "安魂", "class": "佑", "cost": 1, "cleanse": true},
	{"id": "tinggeng", "title": "听更", "class": "佑", "cost": 1, "reveal_next": true},
]

@onready var hand_container: HandFanContainer = $Stage/HandArea/HandFanContainer
@onready var inspector_card: ModularCardView = $Stage/InspectorArea/InspectCardView
@onready var inspect_desc: RichTextLabel = $Stage/InspectorArea/InspectDesc
@onready var points_label: Label = $UI/Panel/VBox/PointsRow/PointsVal
@onready var points_slider: HSlider = $UI/Panel/VBox/PointsRow/PointsSlider
@onready var stagger_check: CheckBox = $UI/Panel/VBox/StaggerCheck
@onready var card_scroll_list: VBoxContainer = $UI/Panel/VBox/Scroll/CardList
@onready var feedback_label: Label = $Stage/FeedbackLabel

var current_points: int = 4
var is_stagger_active: bool = false
var hand_cards: Array[ModularCardView] = []


func _ready() -> void:
	_setup_card_list()
	_init_hand(["attack", "shatter", "guard", "shift"])
	_inspect_card(ALL_CARDS[1]) # Default to 《还刃》


func _setup_card_list() -> void:
	for cdata in ALL_CARDS:
		var btn := Button.new()
		var clr_code := "#bd3d45" if cdata["class"] == "斩" else ("#43a9b2" if cdata["class"] == "御" else "#6d9663")
		btn.text = "【%s】%s (费:%d)" % [cdata["class"], cdata["title"], cdata["cost"]]
		btn.custom_minimum_size.y = 32
		btn.pressed.connect(func(): _inspect_card(cdata))
		card_scroll_list.add_child(btn)


func _init_hand(card_ids: Array[String]) -> void:
	for c in hand_cards:
		if is_instance_valid(c):
			c.queue_free()
	hand_cards.clear()
	
	var base_scene: PackedScene = load("res://assets/game/card_showcase/scenes/modular_card_view.tscn")
	
	for cid in card_ids:
		var cdata: Dictionary = {}
		for card in ALL_CARDS:
			if card["id"] == cid:
				cdata = card
				break
		if cdata.is_empty():
			cdata = {"id": cid, "title": cid, "class": "斩", "cost": 1}
			
		var pres: Dictionary = PresentationCatalog.CARD_PRESENTATION.get(cid, {})
		var card_inst: ModularCardView = base_scene.instantiate()
		hand_container.add_child(card_inst)
		card_inst.setup_card_data(cdata, pres)
		card_inst.card_clicked.connect(_on_hand_card_played.bind(card_inst))
		hand_cards.append(card_inst)
		
	hand_container.set_cards(hand_cards)
	_update_hand_affordability()


func _inspect_card(cdata: Dictionary) -> void:
	var cid: String = cdata["id"]
	var pres: Dictionary = PresentationCatalog.CARD_PRESENTATION.get(cid, {})
	inspector_card.setup_card_data(cdata, pres)
	inspector_card.is_stagger_bonus_active = is_stagger_active
	inspect_desc.text = "【卡牌名】: %s\n【类别】: %s\n【还愿消耗】: %d 点\n【规则效果】: %s" % [
		cdata["title"], cdata["class"], cdata["cost"], inspector_card.card_description
	]


func _update_hand_affordability() -> void:
	for card in hand_cards:
		if is_instance_valid(card):
			card.is_affordable = (current_points >= card.card_cost)
			card.is_stagger_bonus_active = is_stagger_active
	if inspector_card:
		inspector_card.is_stagger_bonus_active = is_stagger_active


func _on_hand_card_played(card_node: ModularCardView) -> void:
	if current_points < card_node.card_cost:
		_show_feedback("还愿点不足！需要 %d 点（当前 %d 点）" % [card_node.card_cost, current_points], Color("ff6b6b"))
		return
		
	current_points -= card_node.card_cost
	points_slider.value = current_points
	points_label.text = "%d 点" % current_points
	
	_show_feedback("打出《%s》！消耗 %d 点还愿" % [card_node.card_title, card_node.card_cost], Color("ffd460"))
	
	# Discard animation: fly up & fade
	hand_cards.erase(card_node)
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(card_node, "position:y", card_node.position.y - 180.0, 0.35)
	tw.tween_property(card_node, "modulate:a", 0.0, 0.35)
	tw.tween_property(card_node, "scale", Vector2(0.5, 0.5), 0.35)
	tw.chain().tween_callback(func():
		card_node.queue_free()
		hand_container.set_cards(hand_cards)
	)
	_update_hand_affordability()


func _show_feedback(msg: String, col: Color) -> void:
	feedback_label.text = msg
	feedback_label.modulate = col
	feedback_label.visible = true
	var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(feedback_label, "position:y", 260.0, 0.4)
	tw.chain().tween_property(feedback_label, "modulate:a", 0.0, 0.6)
	tw.chain().tween_callback(func():
		feedback_label.position.y = 280.0
		feedback_label.modulate.a = 1.0
		feedback_label.visible = false
	)


func _on_draw_btn_pressed() -> void:
	_init_hand(["attack", "shatter", "guard", "shift"])
	current_points = 5
	points_slider.value = 5
	points_label.text = "5 点"
	_show_feedback("重新抽取起手 4 张符牌", Color.WHITE)


func _on_points_slider_value_changed(value: float) -> void:
	current_points = int(value)
	points_label.text = "%d 点" % current_points
	_update_hand_affordability()


func _on_stagger_check_toggled(button_pressed: bool) -> void:
	is_stagger_active = button_pressed
	_update_hand_affordability()
	if is_stagger_active:
		_show_feedback("【僵直乘势窗口开启】《还刃》已点亮乘势加成！", Color("f2a03c"))
