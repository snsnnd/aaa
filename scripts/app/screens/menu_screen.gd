extends CanvasLayer

## 标题菜单：继续夜巡 / 新的夜巡（难度+Seed）/ 设置 / 退出。
## 之前"标题菜单还很薄"，现在承担存档管理与局外解锁入口。

signal start_new(difficulty: int, seed_value: int)
signal continue_run
signal open_settings
signal start_demo

const SaveManagerScript := preload("res://scripts/app/save_manager.gd")
const ContentCatalog := preload("res://scripts/battle/content_catalog.gd")

var diff_index := 0
var diff_label: Label
var seed_input: LineEdit
var continue_btn: Button
var diff_left: Button
var diff_right: Button


func _ready() -> void:
	layer = 5
	visible = false
	add_child(UIKit.dim(Color(0.02, 0.02, 0.03)))
	var title := UIKit.label(Vector2(340, 170), Vector2(600, 90), 64, Color("f1d185"), true)
	title.text = "了  断"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	var sub := UIKit.label(Vector2(340, 268), Vector2(600, 40), 20, Color("9caaa9"))
	sub.text = "灯照本相，怨还其身"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)

	continue_btn = UIKit.button(Vector2(490, 336), Vector2(300, 56), "继续夜巡")
	continue_btn.pressed.connect(func(): continue_run.emit())
	add_child(continue_btn)

	var new_btn := UIKit.button(Vector2(490, 404), Vector2(300, 56), "新的夜巡")
	new_btn.pressed.connect(func(): start_new.emit(diff_index, _parse_seed()))
	add_child(new_btn)

	diff_left = UIKit.button(Vector2(490, 472), Vector2(52, 44), "<", 20)
	diff_left.pressed.connect(func(): _shift_diff(-1))
	add_child(diff_left)
	diff_right = UIKit.button(Vector2(738, 472), Vector2(52, 44), ">", 20)
	diff_right.pressed.connect(func(): _shift_diff(1))
	add_child(diff_right)
	diff_label = UIKit.label(Vector2(542, 472), Vector2(196, 44), 18, Color("c8bb9d"), true)
	diff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diff_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(diff_label)

	seed_input = LineEdit.new()
	seed_input.position = Vector2(560, 524)
	seed_input.size = Vector2(160, 36)
	seed_input.placeholder_text = "Seed（可留空）"
	seed_input.add_theme_font_size_override("font_size", 15)
	add_child(seed_input)

	var settings_btn := UIKit.button(Vector2(490, 572), Vector2(300, 44), "设  置")
	settings_btn.pressed.connect(func(): open_settings.emit())
	add_child(settings_btn)

	var quit_btn := UIKit.button(Vector2(490, 624), Vector2(140, 44), "退  出")
	quit_btn.pressed.connect(func(): get_tree().quit())
	add_child(quit_btn)
	var demo_btn := UIKit.button(Vector2(650, 624), Vector2(140, 44), "旧日试炼", 16)
	demo_btn.pressed.connect(func(): start_demo.emit())
	add_child(demo_btn)

	var controls := UIKit.label(Vector2(340, 682), Vector2(600, 26), 14, Color("7a7264"))
	controls.text = "Space 防范 · 1-4 符牌 · 5 召符 · Esc 暂停"
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(controls)


func refresh() -> void:
	var meta: Dictionary = SaveManagerScript.load_meta()
	continue_btn.visible = SaveManagerScript.has_run()
	diff_index = clampi(diff_index, 0, int(meta.get("difficulty_unlocked", 0)))
	var diff: Dictionary = ContentCatalog.DIFFICULTIES[diff_index]
	diff_label.text = String(diff["name"])
	diff_left.disabled = diff_index <= 0
	diff_right.disabled = diff_index >= int(meta.get("difficulty_unlocked", 0))
	diff_label.tooltip_text = String(diff.get("desc", ""))


func _shift_diff(dir: int) -> void:
	var meta: Dictionary = SaveManagerScript.load_meta()
	diff_index = clampi(diff_index + dir, 0, int(meta.get("difficulty_unlocked", 0)))
	refresh()


func _parse_seed() -> int:
	var text := seed_input.text.strip_edges()
	if text.is_empty():
		return 0
	if text.is_valid_int():
		return int(text)
	return int(hash(text))
