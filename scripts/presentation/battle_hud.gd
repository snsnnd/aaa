extends CanvasLayer

## HUD 门面：状态栏、消息、闪光，并装配手牌区与菜单浮层。
## main.gd 只与本文件对话。

const BattleSimulationScript := preload("res://scripts/battle/battle_simulation.gd")
const HandViewScript := preload("res://scripts/presentation/hand_view.gd")
const MenuOverlayScript := preload("res://scripts/presentation/menu_overlay.gd")

var sim: BattleSimulationScript
var command: Callable
var root: Control
var player_status: Label
var enemy_status: Label
var resource_status: Label
var style_status: Label
var message_label: Label
var flash_rect: ColorRect
var hand_view: HandViewScript
var menu_overlay: MenuOverlayScript
var menu_open: bool:
	get:
		return menu_overlay.menu_open
var card_buttons: Dictionary:
	get:
		return hand_view.card_buttons
var instruction_label: Label:
	get:
		return hand_view.instruction_label
var message_serial := 0


func setup(s: BattleSimulationScript, command_cb: Callable, restart_cb: Callable, abandon_cb: Callable) -> void:
	sim = s
	command = command_cb
	_build_status()
	hand_view = HandViewScript.new()
	hand_view.position = Vector2(0, 540)
	hand_view.size = Vector2(1280, 180)
	add_child(hand_view)
	hand_view.setup(s, command_cb)
	menu_overlay = MenuOverlayScript.new()
	add_child(menu_overlay)
	menu_overlay.setup(s, restart_cb, abandon_cb, func(on: bool): _set_shake(on), hand_view.instruction_label)
	refresh()


func _set_shake(on: bool) -> void:
	var parent := get_parent()
	if parent and "shake_enabled" in parent:
		parent.shake_enabled = on


func _build_status() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var top_shade := ColorRect.new()
	top_shade.position = Vector2.ZERO
	top_shade.size = Vector2(1280, 96)
	top_shade.color = Color(0.025, 0.025, 0.035, 0.82)
	top_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top_shade)

	player_status = _label(Vector2(34, 18), Vector2(300, 34), 24, Color("e8d7a1"), true)
	root.add_child(player_status)
	enemy_status = _label(Vector2(936, 18), Vector2(310, 34), 24, Color("e8d7a1"), true)
	enemy_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(enemy_status)
	resource_status = _label(Vector2(34, 54), Vector2(390, 28), 18, Color("c8aa64"), false)
	root.add_child(resource_status)
	style_status = _label(Vector2(470, 25), Vector2(340, 42), 19, Color("9caaa9"), true)
	style_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(style_status)
	style_status.text = "第一夜·雨巷老街"

	message_label = _label(Vector2(220, 456), Vector2(840, 65), 30, Color("f3deb1"), true)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	message_label.add_theme_constant_override("shadow_offset_x", 3)
	message_label.add_theme_constant_override("shadow_offset_y", 3)
	root.add_child(message_label)

	var bottom := Panel.new()
	bottom.position = Vector2(0, 540)
	bottom.size = Vector2(1280, 180)
	bottom.add_theme_stylebox_override("panel", _style_box(Color(0.025, 0.026, 0.035, 0.96), Color("4e3f34"), 0, 2))
	root.add_child(bottom)

	flash_rect = ColorRect.new()
	flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash_rect.color = Color(1.0, 0.86, 0.57, 0.0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash_rect)


func refresh() -> void:
	player_status.text = "执灯人｜灯油 %d / %d" % [sim.player_hp, sim.player_max_hp]
	var rage_tag := ""
	if sim.rage >= 3:
		rage_tag = "  ⚡躁%d" % sim.rage
	enemy_status.text = "%s｜怨气 %d / %d%s" % [sim.enemy_name, maxi(0, sim.enemy_hp), sim.enemy_max_hp, rage_tag]
	resource_status.text = "还愿 %d / %d    第 %d 招" % [sim.points, sim._max_points(), sim.attack_index + 1]
	hand_view.refresh_slots()


func refresh_defense_button() -> void:
	hand_view.refresh_defense()


func rebuild_hand() -> void:
	hand_view.rebuild_hand()


func rebuild_pile_view() -> void:
	hand_view.rebuild_pile_view()


func show_message(text: String, color: Color, duration: float) -> void:
	message_serial += 1
	var serial := message_serial
	message_label.text = text
	message_label.modulate = color
	message_label.modulate.a = 1.0
	message_label.scale = Vector2(1.08, 0.92)
	message_label.pivot_offset = message_label.size * 0.5
	var tween := create_tween().set_ignore_time_scale(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(message_label, "scale", Vector2.ONE, 0.14)
	tween.tween_interval(duration)
	tween.tween_property(message_label, "modulate:a", 0.0, 0.22)
	tween.tween_callback(func():
		if serial == message_serial:
			message_label.text = ""
	)


func flash(color: Color, alpha: float, duration: float) -> void:
	if GameSettings.flash_reduction:
		alpha *= 0.35
	flash_rect.color = color
	flash_rect.color.a = alpha
	var tween := create_tween().set_ignore_time_scale(true)
	tween.tween_property(flash_rect, "color:a", 0.0, duration)


func toggle_menu() -> void:
	menu_overlay.toggle_menu()


func close_menu() -> void:
	menu_overlay.close_menu()


func hide_settlement() -> void:
	menu_overlay.hide_settlement()


func show_settlement(victory: bool) -> void:
	menu_overlay.show_settlement(victory)


func _label(pos: Vector2, size: Vector2, font_size: int, color: Color, bold: bool) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = size
	label.add_theme_font_size_override("font_size", font_size + (1 if bold else 0))
	label.add_theme_color_override("font_color", color)
	return label


func _style_box(bg: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	return box
