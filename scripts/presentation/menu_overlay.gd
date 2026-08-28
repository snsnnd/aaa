extends CanvasLayer

## 暂停菜单与结算浮层：继续 / 重开 / 设置 / 离开夜巡，胜负结算面板。

const BattleSimulationScript := preload("res://scripts/battle/battle_simulation.gd")
const SettingsScreenScript := preload("res://scripts/app/screens/settings_screen.gd")

var sim: BattleSimulationScript
var restart_cb: Callable
var abandon_cb: Callable
var root: Control
var menu_root: Control
var settle_root: Control
var settle_title: Label
var settle_sub: Label
var menu_open := false
var settings_screen: SettingsScreenScript


func setup(s: BattleSimulationScript, restart_callback: Callable, abandon_callback: Callable, shake_setter: Callable, hint_label: Label) -> void:
	sim = s
	restart_cb = restart_callback
	abandon_cb = abandon_callback
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_menu(shake_setter, hint_label)
	_build_settlement()


func _menu_button(text: String, y: float, cb: Callable) -> Button:
	var btn := Button.new()
	btn.position = Vector2(60, y)
	btn.size = Vector2(280, 46)
	btn.focus_mode = Control.FOCUS_NONE
	btn.text = text
	btn.add_theme_font_size_override("font_size", 19)
	btn.add_theme_stylebox_override("normal", _style_box(Color("2c211d"), Color("bd8b45"), 12, 2))
	btn.add_theme_stylebox_override("hover", _style_box(Color("493126"), Color("e0ad58"), 12, 3))
	btn.pressed.connect(cb)
	menu_panel().add_child(btn)
	return btn


func menu_panel() -> Panel:
	for child in menu_root.get_children():
		if child is Panel:
			return child
	return null


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
	panel.position = Vector2(440, 110)
	panel.size = Vector2(400, 500)
	panel.add_theme_stylebox_override("panel", _style_box(Color(0.03, 0.03, 0.045, 0.97), Color("8a6a3a"), 16, 2))
	menu_root.add_child(panel)

	var title := _label(Vector2(20, 24), Vector2(360, 40), 26, Color("f1d185"), true)
	title.text = "歇  脚"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)

	_menu_button("继续  [Esc]", 92, toggle_menu)
	_menu_button("重新开始本战  [R]", 148, func():
		close_menu()
		restart_cb.call())
	_menu_button("设  置", 204, func():
		settings_screen.open())
	_menu_button("离开夜巡（保存进度）", 260, func():
		close_menu()
		abandon_cb.call())

	var hint_toggle := CheckButton.new()
	hint_toggle.position = Vector2(60, 322)
	hint_toggle.size = Vector2(280, 34)
	hint_toggle.text = "操作提示"
	hint_toggle.button_pressed = false
	hint_toggle.focus_mode = Control.FOCUS_NONE
	hint_toggle.toggled.connect(func(on: bool): hint_label.visible = on)
	panel.add_child(hint_toggle)

	var glossary := _label(Vector2(30, 372), Vector2(340, 120), 13, Color("9caaa9"), false)
	glossary.text = "—— 更夫手册 ——\n防范：敌招落下前 Space；越近越接近完美\n还愿：防范所得，出符牌或召符\n乘势：完美接刀后的余韵，还刃加成\n鬼手：不可防范，用安魂或 2 点消解\n躁动：还愿囤 7 点，鬼会发狂"
	panel.add_child(glossary)

	settings_screen = SettingsScreenScript.new()
	add_child(settings_screen)


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
		settle_sub.text = "灯油余 %d/%d · 历经 %d 招 · 完美接刀 x %d" % [sim.player_hp, sim.player_max_hp, sim.attack_index + 1, sim.perfects]
	else:
		settle_title.text = "灯 灭 了"
		settle_title.add_theme_color_override("font_color", Color("cf5555"))
		settle_sub.text = "夜止于第 %d 招 · 完美接刀 x %d" % [sim.attack_index + 1, sim.perfects]
	settle_root.visible = true


func _label(pos: Vector2, size: Vector2, font_size: int, color: Color, bold: bool) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = size
	label.add_theme_font_size_override("font_size", GameSettings.font(font_size) + (1 if bold else 0))
	label.add_theme_color_override("font_color", color)
	return label


func _style_box(bg: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	return box
