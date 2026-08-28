class_name UIKit
extends RefCounted

## 共享 UI 构件：流程界面统一风格与文字缩放（无障碍）。
## 所有 screens 与 run_flow 的界面构建都经此处，避免样式散落。

static func dim(color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.color = color
	return rect


static func label(pos: Vector2, size: Vector2, font_size: int, color: Color, bold := false) -> Label:
	var node := Label.new()
	node.position = pos
	node.size = size
	node.add_theme_font_size_override("font_size", GameSettings.font(font_size) + (1 if bold else 0))
	node.add_theme_color_override("font_color", color)
	return node


static func title(text: String, y := 130.0) -> Label:
	var node := label(Vector2(240, y), Vector2(800, 50), 34, Color("f2d487"), true)
	node.text = text
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return node


static func button(pos: Vector2, size: Vector2, text: String, font_size := 22) -> Button:
	var node := Button.new()
	node.position = pos
	node.size = size
	node.text = text
	node.focus_mode = Control.FOCUS_NONE
	node.add_theme_font_size_override("font_size", GameSettings.font(font_size))
	node.add_theme_stylebox_override("normal", style_box(Color("2c211d"), Color("bd8b45"), 12, 2))
	node.add_theme_stylebox_override("hover", style_box(Color("493126"), Color("e0ad58"), 12, 3))
	node.add_theme_stylebox_override("disabled", style_box(Color("17171d"), Color("47434a"), 12, 2))
	return node


static func panel(pos: Vector2, size: Vector2, border := Color("8a6a3a")) -> Panel:
	var node := Panel.new()
	node.position = pos
	node.size = size
	node.add_theme_stylebox_override("panel", style_box(Color(0.03, 0.03, 0.045, 0.97), border, 16, 2))
	return node


static func style_box(bg: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	return box
