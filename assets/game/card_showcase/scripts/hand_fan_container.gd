@tool
class_name HandFanContainer
extends Control

## Curved Hand Fan Container / 手牌扇形弧线排列容器
## 自动根据手牌数量计算扇形圆弧坐标与倾角，提供平滑悬停拾取与展开动画

@export var curve_radius: float = 650.0      # 扇形虚拟圆半径
@export var max_fan_angle_deg: float = 18.0  # 最大扇形张角
@export var card_spacing_px: float = 140.0   # 基础手牌间距

var _cards: Array[ModularCardView] = []


func set_cards(card_nodes: Array[ModularCardView]) -> void:
	_cards = card_nodes
	layout_hand()


func layout_hand() -> void:
	var count := _cards.size()
	if count == 0:
		return
		
	var center_x := size.x * 0.5
	var base_y := size.y - 140.0
	
	for i in count:
		var card: ModularCardView = _cards[i]
		if not is_instance_valid(card):
			continue
			
		# Normalized position from -1.0 to 1.0
		var t := 0.0
		if count > 1:
			t = (float(i) / float(count - 1)) * 2.0 - 1.0
			
		var angle_rad := deg_to_rad(t * (max_fan_angle_deg * 0.5))
		var offset_x := t * (float(count - 1) * card_spacing_px * 0.5)
		var offset_y := (1.0 - cos(angle_rad)) * curve_radius
		
		var target_pos := Vector2(center_x + offset_x - card.size.x * 0.5, base_y + offset_y)
		var target_rot := angle_rad * 0.85
		
		var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "position", target_pos, 0.3)
		tw.tween_property(card, "rotation", target_rot, 0.3)
