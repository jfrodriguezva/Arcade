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


static func build_toolbar(vbox: BoxContainer, root: Control, help_title: String, help_body: String) -> void:
	## Fila estándar de "< Volver" + "? Cómo jugar" para el encabezado de cada juego.
	var toolbar := HBoxContainer.new()
	toolbar.alignment = BoxContainer.ALIGNMENT_CENTER
	toolbar.add_theme_constant_override("separation", 10)
	vbox.add_child(toolbar)

	var back_btn := Button.new()
	back_btn.text = "<  Volver"
	back_btn.custom_minimum_size = Vector2(120, 44)
	style_button(back_btn, COLOR_TEXT_DIM)
	back_btn.pressed.connect(func() -> void: GameManager.go_to_hub())
	toolbar.add_child(back_btn)

	add_help_button(toolbar, root, help_title, help_body)


static func add_help_button(toolbar: Control, root: Control, title: String, body: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = title
	dialog.dialog_text = body
	dialog.dialog_autowrap = true
	dialog.size = Vector2i(440, 380)
	root.add_child(dialog)

	var btn := Button.new()
	btn.text = "?  Cómo jugar"
	btn.custom_minimum_size = Vector2(140, 44)
	style_button(btn, COLOR_ACCENT_3)
	btn.pressed.connect(func() -> void: dialog.popup_centered())
	toolbar.add_child(btn)
