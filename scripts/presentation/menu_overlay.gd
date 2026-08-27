extends CanvasLayer

## 菜单与结算浮层：歇脚菜单、设置项、胜负结算面板。

const BattleSimulationScript := preload("res://scripts/battle/battle_simulation.gd")

var sim: BattleSimulationScript
var restart_cb: Callable
var root: Control
var menu_root: Control
var settle_root: Control
var settle_title: Label
var settle_sub: Label
var menu_open := false


func setup(s: BattleSimulationScript, restart_callback: Callable, shake_setter: Callable, hint_label: Label) -> void:
	sim = s
	restart_cb = restart_callback
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_menu(shake_setter, hint_label)
	_build_settlement()


func _build_menu(shake_setter: Callable, hint_label: Label) -> void:
	menu_root = Control.new()
	menu_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_root.visible = false
	add_child(menu_root)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.74)
	menu_root.add_child(dim)

	var panel := Panel.new()
	panel.position = Vector2(440, 150)
	panel.size = Vector2(400, 420)
	panel.add_theme_stylebox_override("panel", _style_box(Color(0.03, 0.03, 0.045, 0.97), Color("8a6a3a"), 16, 2))
	menu_root.add_child(panel)

	var title := _label(Vector2(20, 24), Vector2(360, 40), 26, Color("f1d185"), true)
	title.text = "歇  脚"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)

	var resume := Button.new()
	resume.position = Vector2(60, 92)
	resume.size = Vector2(280, 52)
	resume.focus_mode = Control.FOCUS_NONE
	resume.text = "继续  [Esc]"
	resume.add_theme_font_size_override("font_size", 20)
	resume.add_theme_stylebox_override("normal", _style_box(Color("2c211d"), Color("bd8b45"), 12, 2))
	resume.add_theme_stylebox_override("hover", _style_box(Color("493126"), Color("e0ad58"), 12, 3))
	resume.pressed.connect(toggle_menu)
	panel.add_child(resume)

	var restart := Button.new()
	restart.position = Vector2(60, 154)
	restart.size = Vector2(280, 52)
	restart.focus_mode = Control.FOCUS_NONE
	restart.text = "重新开始  [R]"
	restart.add_theme_font_size_override("font_size", 20)
	restart.add_theme_stylebox_override("normal", _style_box(Color("2c211d"), Color("bd8b45"), 12, 2))
	restart.add_theme_stylebox_override("hover", _style_box(Color("493126"), Color("e0ad58"), 12, 3))
	restart.pressed.connect(func():
		close_menu()
		restart_cb.call()
	)
	panel.add_child(restart)

	var vol_label := _label(Vector2(60, 228), Vector2(280, 26), 16, Color("a9a49b"), false)
	vol_label.text = "音效音量"
	panel.add_child(vol_label)
	var volume := HSlider.new()
	volume.position = Vector2(60, 258)
	volume.size = Vector2(280, 24)
	volume.min_value = 0.0
	volume.max_value = 1.0
	volume.step = 0.05
	volume.value = 0.8
	volume.focus_mode = Control.FOCUS_NONE
	volume.value_changed.connect(func(v: float): AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.0001))))
	panel.add_child(volume)

	var shake_toggle := CheckButton.new()
	shake_toggle.position = Vector2(60, 296)
	shake_toggle.size = Vector2(280, 34)
	shake_toggle.text = "画面震动"
	shake_toggle.button_pressed = true
	shake_toggle.focus_mode = Control.FOCUS_NONE
	shake_toggle.toggled.connect(func(on: bool): shake_setter.call(on))
	panel.add_child(shake_toggle)

	var hint_toggle := CheckButton.new()
	hint_toggle.position = Vector2(60, 340)
	hint_toggle.size = Vector2(280, 34)
	hint_toggle.text = "操作提示"
	hint_toggle.button_pressed = false
	hint_toggle.focus_mode = Control.FOCUS_NONE
	hint_toggle.toggled.connect(func(on: bool): hint_label.visible = on)
	panel.add_child(hint_toggle)


func _build_settlement() -> void:
	settle_root = Control.new()
	settle_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settle_root.visible = false
	settle_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(settle_root)
	var settle_dim := ColorRect.new()
	settle_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settle_dim.color = Color(0.0, 0.0, 0.0, 0.6)
	settle_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	settle_root.add_child(settle_dim)
	var settle_panel := Panel.new()
	settle_panel.position = Vector2(440, 200)
	settle_panel.size = Vector2(400, 300)
	settle_panel.add_theme_stylebox_override("panel", _style_box(Color(0.03, 0.03, 0.045, 0.97), Color("8a6a3a"), 16, 2))
	settle_root.add_child(settle_panel)
	settle_title = _label(Vector2(20, 44), Vector2(360, 48), 34, Color("f1d185"), true)
	settle_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settle_panel.add_child(settle_title)
	settle_sub = _label(Vector2(20, 116), Vector2(360, 60), 17, Color("c8bb9d"), false)
	settle_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settle_panel.add_child(settle_sub)
	var again := Button.new()
	again.position = Vector2(60, 206)
	again.size = Vector2(280, 52)
	again.focus_mode = Control.FOCUS_NONE
	again.text = "再入夜  [R]"
	again.add_theme_font_size_override("font_size", 20)
	again.add_theme_stylebox_override("normal", _style_box(Color("2c211d"), Color("bd8b45"), 12, 2))
	again.add_theme_stylebox_override("hover", _style_box(Color("493126"), Color("e0ad58"), 12, 3))
	again.pressed.connect(func():
		close_menu()
		restart_cb.call()
	)
	settle_panel.add_child(again)


func toggle_menu() -> void:
	menu_open = not menu_open
	menu_root.visible = menu_open
	get_tree().paused = menu_open


func close_menu() -> void:
	menu_open = false
	menu_root.visible = false
	get_tree().paused = false


func hide_settlement() -> void:
	settle_root.visible = false


func show_settlement(victory: bool) -> void:
	if victory:
		settle_title.text = "怨 已 归 还"
		settle_title.add_theme_color_override("font_color", Color("f1d185"))
		settle_sub.text = "灯油余 %d/%d · 历经 %d 招 · 完美接刀 x %d" % [sim.player_hp, BattleSimulationScript.PLAYER_MAX_HP, sim.attack_index + 1, sim.perfects]
	else:
		settle_title.text = "灯 灭 了"
		settle_title.add_theme_color_override("font_color", Color("cf5555"))
		settle_sub.text = "夜止于第 %d 招 · 完美接刀 x %d" % [sim.attack_index + 1, sim.perfects]
	settle_root.visible = true


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
