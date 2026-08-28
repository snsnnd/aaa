extends CanvasLayer

## 设置界面：键位重映射、无障碍（震屏/闪光/文字/色觉/反应辅助）、存档管理。
## 从标题菜单与战斗暂停菜单共用。

signal closed

const SaveManagerScript := preload("res://scripts/app/save_manager.gd")

var _listening_action := ""
var _rows: Dictionary = {}


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_child(UIKit.dim(Color(0, 0, 0, 0.85)))
	var panel := UIKit.panel(Vector2(190, 60), Vector2(900, 600), Color("6a5a3a"))
	add_child(panel)
	var title := UIKit.label(Vector2(20, 20), Vector2(860, 40), 26, Color("f1d185"), true)
	title.text = "设  置"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)

	# —— 无障碍 ——
	_add_slider(panel, 90, "震屏强度", 0.0, 1.5, 0.05,
		func(): return GameSettings.shake_scale,
		func(v: float): GameSettings.shake_scale = v)
	_add_check(panel, 134, "减弱闪光", func(): return GameSettings.flash_reduction,
		func(on: bool): GameSettings.flash_reduction = on)
	_add_slider(panel, 178, "文字缩放", 0.8, 1.6, 0.05,
		func(): return GameSettings.text_scale,
		func(v: float): GameSettings.text_scale = v)
	_add_option(panel, 222, "色觉辅助", ["关闭", "红色盲", "绿色盲", "蓝色盲"],
		func(): return GameSettings.colorblind_mode, func(v: int): GameSettings.colorblind_mode = v)
	_add_option(panel, 266, "反应窗口辅助", ["标准", "放宽 25%", "放宽 50%"],
		func(): return int(GameSettings.reaction_assist * 100.0) - 100,
		func(v: int): GameSettings.reaction_assist = 1.0 + 0.25 * float(v))

	# —— 键位 ——
	var keys_title := UIKit.label(Vector2(30, 316), Vector2(300, 28), 19, Color("e8d7a1"), true)
	keys_title.text = "键位（手柄默认已支持）"
	panel.add_child(keys_title)
	var y := 350.0
	for action in GameSettings.ACTIONS:
		var name_label := UIKit.label(Vector2(30, y), Vector2(180, 26), 15, Color("c8bb9d"))
		name_label.text = String(GameSettings.ACTION_LABELS[action])
		panel.add_child(name_label)
		var bind_btn := UIKit.button(Vector2(220, y - 2), Vector2(150, 30), GameSettings.binding_label(action), 14)
		bind_btn.pressed.connect(_on_rebind.bind(action, bind_btn))
		panel.add_child(bind_btn)
		_rows[action] = bind_btn
		y += 36.0

	# —— 存档管理 ——
	var save_title := UIKit.label(Vector2(520, 316), Vector2(300, 28), 19, Color("e8d7a1"), true)
	save_title.text = "存档管理"
	panel.add_child(save_title)
	var del_run := UIKit.button(Vector2(520, 350), Vector2(300, 40), "删除当前夜巡存档", 15)
	del_run.pressed.connect(func():
		SaveManagerScript.clear_run()
		del_run.text = "已删除")
	panel.add_child(del_run)
	var del_meta := UIKit.button(Vector2(520, 398), Vector2(300, 40), "清空局外进度与统计", 15)
	del_meta.pressed.connect(func():
		SaveManagerScript.save_meta(SaveManagerScript.default_meta())
		del_meta.text = "已清空")
	panel.add_child(del_meta)

	var back := UIKit.button(Vector2(330, 540), Vector2(240, 44), "返回")
	back.pressed.connect(_close)
	panel.add_child(back)


func open() -> void:
	refresh_bindings()
	visible = true


func _close() -> void:
	if _listening_action != "":
		_listening_action = ""
		refresh_bindings()
	GameSettings.save_settings()
	closed.emit()
	visible = false


func refresh_bindings() -> void:
	for action in _rows:
		var btn: Button = _rows[action]
		btn.text = "按新键…" if action == _listening_action else GameSettings.binding_label(action)


func _on_rebind(action: String, btn: Button) -> void:
	_listening_action = action
	btn.text = "按新键…"


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _listening_action != "":
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode != KEY_ESCAPE:
				GameSettings.set_binding(_listening_action, event.keycode)
			_listening_action = ""
			refresh_bindings()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close()
		get_viewport().set_input_as_handled()


func _add_slider(panel: Panel, y: float, text: String, min_v: float, max_v: float, step: float, getter: Callable, setter: Callable) -> void:
	var name_label := UIKit.label(Vector2(30, y), Vector2(150, 26), 15, Color("c8bb9d"))
	name_label.text = text
	panel.add_child(name_label)
	var slider := HSlider.new()
	slider.position = Vector2(190, y + 2)
	slider.size = Vector2(220, 22)
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.value = float(getter.call())
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(func(v: float): setter.call(v))
	panel.add_child(slider)


func _add_check(panel: Panel, y: float, text: String, getter: Callable, setter: Callable) -> void:
	var check := CheckButton.new()
	check.position = Vector2(30, y)
	check.size = Vector2(300, 26)
	check.text = text
	check.button_pressed = bool(getter.call())
	check.focus_mode = Control.FOCUS_NONE
	check.add_theme_font_size_override("font_size", 15)
	check.toggled.connect(func(on: bool): setter.call(on))
	panel.add_child(check)


func _add_option(panel: Panel, y: float, text: String, options: Array, getter: Callable, setter: Callable) -> void:
	var name_label := UIKit.label(Vector2(30, y), Vector2(150, 26), 15, Color("c8bb9d"))
	name_label.text = text
	panel.add_child(name_label)
	var option := OptionButton.new()
	option.position = Vector2(190, y)
	option.size = Vector2(220, 28)
	for opt in options:
		option.add_item(String(opt))
	option.selected = int(getter.call())
	option.focus_mode = Control.FOCUS_NONE
	option.add_theme_font_size_override("font_size", 14)
	option.item_selected.connect(func(idx: int): setter.call(idx))
	panel.add_child(option)
