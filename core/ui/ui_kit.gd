class_name UIKit
extends RefCounted
## Paleta y helpers de estilo compartidos por el Hub y todos los juegos,
## para que la plataforma se sienta consistente sin depender de assets de arte.

const COLOR_BG := Color(0.114, 0.122, 0.169)        # #1d1f2b fondo
const COLOR_BG_LIGHT := Color(0.180, 0.196, 0.271)   # panel/hover
const COLOR_PANEL := Color(0.145, 0.157, 0.216)      # panel base
const COLOR_ACCENT := Color(1.0, 0.365, 0.451)       # #ff5d73 rosa/rojo
const COLOR_ACCENT_2 := Color(0.306, 0.804, 0.769)   # #4ecdc4 teal
const COLOR_ACCENT_3 := Color(1.0, 0.820, 0.400)     # #ffd166 amarillo
const COLOR_DANGER := Color(0.937, 0.325, 0.314)     # rojo miss/error
const COLOR_TEXT := Color(0.94, 0.94, 0.96)
const COLOR_TEXT_DIM := Color(0.62, 0.64, 0.70)


static func stylebox(bg: Color, border: Color = Color(0, 0, 0, 0), radius: int = 14, border_width: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	if border_width > 0:
		sb.set_border_width_all(border_width)
		sb.border_color = border
	return sb


static func apply_background(control: Control, color: Color = COLOR_BG) -> void:
	var bg := ColorRect.new()
	bg.color = color
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	control.add_child(bg)
	control.move_child(bg, 0)


static func style_button(btn: Button, accent: Color = COLOR_ACCENT, radius: int = 14) -> void:
	btn.add_theme_stylebox_override("normal", stylebox(COLOR_PANEL, accent, radius, 2))
	btn.add_theme_stylebox_override("hover", stylebox(COLOR_BG_LIGHT, accent, radius, 3))
	btn.add_theme_stylebox_override("pressed", stylebox(accent, accent, radius, 2))
	btn.add_theme_stylebox_override("disabled", stylebox(COLOR_PANEL, COLOR_TEXT_DIM, radius, 1))
	btn.add_theme_color_override("font_color", COLOR_TEXT)
	btn.add_theme_color_override("font_hover_color", COLOR_TEXT)
	btn.add_theme_color_override("font_pressed_color", COLOR_BG)
	btn.add_theme_color_override("font_disabled_color", COLOR_TEXT_DIM)


static func title_label(text: String, size: int = 36, color: Color = COLOR_TEXT) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	return lbl


static func pulse(node: Control) -> void:
	node.pivot_offset = node.size / 2.0
	var tween := node.create_tween()
	node.scale = Vector2(0.7, 0.7)
	tween.tween_property(node, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
