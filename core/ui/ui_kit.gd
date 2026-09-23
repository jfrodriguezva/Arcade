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
	if not btn.pressed.is_connected(AudioManager.play_click):
		btn.pressed.connect(AudioManager.play_click)


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


const DIFFICULTY_LABELS := {"easy": "Fácil", "medium": "Medio", "hard": "Difícil"}


static func show_setup_overlay(root: Control, title: String, allow_pvp: bool, allow_difficulty: bool, on_confirm: Callable) -> void:
	## Pantalla previa a cada juego con IA: elegir Humano vs Máquina (o 2 jugadores)
	## y el nivel de dificultad. Llama a on_confirm({"mode":"pve"/"pvp","difficulty":"easy"/"medium"/"hard"}).
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(overlay)

	var bg := ColorRect.new()
	bg.color = Color(COLOR_BG.r, COLOR_BG.g, COLOR_BG.b, 0.97)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", stylebox(COLOR_PANEL, COLOR_ACCENT_3, 20, 3))
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 28)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	vbox.add_child(title_label(title, 26, COLOR_ACCENT_3))

	var state := {"mode": "pve", "difficulty": "medium"}

	var mode_label := title_label("Modo de juego", 15, COLOR_TEXT_DIM)
	var mode_row := HBoxContainer.new()
	mode_row.alignment = BoxContainer.ALIGNMENT_CENTER
	mode_row.add_theme_constant_override("separation", 10)

	var pve_btn := Button.new()
	pve_btn.text = "Vs Máquina"
	pve_btn.custom_minimum_size = Vector2(140, 44)
	var pvp_btn := Button.new()
	pvp_btn.text = "2 Jugadores"
	pvp_btn.custom_minimum_size = Vector2(140, 44)

	var diff_label := title_label("Dificultad", 15, COLOR_TEXT_DIM)
	var diff_row := HBoxContainer.new()
	diff_row.alignment = BoxContainer.ALIGNMENT_CENTER
	diff_row.add_theme_constant_override("separation", 8)

	var easy_btn := Button.new()
	easy_btn.text = "Fácil"
	easy_btn.custom_minimum_size = Vector2(88, 40)
	var medium_btn := Button.new()
	medium_btn.text = "Medio"
	medium_btn.custom_minimum_size = Vector2(88, 40)
	var hard_btn := Button.new()
	hard_btn.text = "Difícil"
	hard_btn.custom_minimum_size = Vector2(88, 40)

	var refresh_mode: Callable = func() -> void:
		style_button(pve_btn, COLOR_ACCENT if state["mode"] == "pve" else COLOR_TEXT_DIM)
		style_button(pvp_btn, COLOR_ACCENT if state["mode"] == "pvp" else COLOR_TEXT_DIM)
		var show_diff: bool = allow_difficulty and state["mode"] == "pve"
		diff_row.visible = show_diff
		diff_label.visible = show_diff

	var refresh_diff: Callable = func() -> void:
		style_button(easy_btn, COLOR_ACCENT_2 if state["difficulty"] == "easy" else COLOR_TEXT_DIM)
		style_button(medium_btn, COLOR_ACCENT_2 if state["difficulty"] == "medium" else COLOR_TEXT_DIM)
		style_button(hard_btn, COLOR_ACCENT_2 if state["difficulty"] == "hard" else COLOR_TEXT_DIM)

	pve_btn.pressed.connect(func() -> void: state["mode"] = "pve"; refresh_mode.call())
	pvp_btn.pressed.connect(func() -> void: state["mode"] = "pvp"; refresh_mode.call())
	easy_btn.pressed.connect(func() -> void: state["difficulty"] = "easy"; refresh_diff.call())
	medium_btn.pressed.connect(func() -> void: state["difficulty"] = "medium"; refresh_diff.call())
	hard_btn.pressed.connect(func() -> void: state["difficulty"] = "hard"; refresh_diff.call())

	if allow_pvp:
		vbox.add_child(mode_label)
		mode_row.add_child(pve_btn)
		mode_row.add_child(pvp_btn)
		vbox.add_child(mode_row)

	if allow_difficulty:
		diff_row.add_child(easy_btn)
		diff_row.add_child(medium_btn)
		diff_row.add_child(hard_btn)
		vbox.add_child(diff_label)
		vbox.add_child(diff_row)

	refresh_mode.call()
	refresh_diff.call()

	var start_btn := Button.new()
	start_btn.text = "▶  Comenzar"
	start_btn.custom_minimum_size = Vector2(200, 50)
	style_button(start_btn, COLOR_ACCENT_3)
	start_btn.pressed.connect(func() -> void:
		overlay.queue_free()
		on_confirm.call(state.duplicate())
	)
	vbox.add_child(start_btn)


static func animate_dice_label(node: Node, label: Label, final_value: int, prefix: String = "🎲 ", duration: float = 0.45) -> void:
	## Hace parpadear el dado por valores al azar antes de mostrar el resultado final.
	var ticks := 7
	var interval: float = duration / ticks
	for i in range(ticks):
		label.text = prefix + str(randi() % 6 + 1)
		await node.get_tree().create_timer(interval).timeout
	label.text = prefix + str(final_value)


static func animate_dice_pair(node: Node, label: Label, final_values: Array, prefix: String = "🎲 ", duration: float = 0.45) -> void:
	var ticks := 7
	var interval: float = duration / ticks
	for i in range(ticks):
		var fake: Array = []
		for v in final_values:
			fake.append(randi() % 6 + 1)
		label.text = prefix + str(fake)
		await node.get_tree().create_timer(interval).timeout
	label.text = prefix + str(final_values)


static func animate_dice_buttons(node: Node, buttons: Array, final_values: Array, held: Array, duration: float = 0.45) -> void:
	var ticks := 7
	var interval: float = duration / ticks
	for t in range(ticks):
		for i in range(buttons.size()):
			if i < held.size() and not held[i]:
				buttons[i].text = str(randi() % 6 + 1)
		await node.get_tree().create_timer(interval).timeout
	for i in range(buttons.size()):
		if i < held.size() and not held[i]:
			buttons[i].text = str(final_values[i])
