extends Control
## Serpientes y Escaleras. 1 jugador contra la máquina o 2 jugadores
## pasando el dispositivo (es puro azar, no hay niveles de dificultad).

const GAME_ID := "snakes_ladders"

const LADDERS := {2: 38, 7: 14, 8: 31, 15: 26, 21: 42, 28: 84, 36: 44, 51: 67, 71: 91, 78: 98}
const SNAKES := {16: 6, 46: 25, 49: 11, 62: 19, 64: 60, 74: 53, 89: 68, 92: 88, 95: 75, 99: 80}

const HELP_TEXT := "Por turnos, tira el dado y avanza tu ficha esa cantidad de casillas.

- Si caes en la base de una escalera ▲, subes directo a la casilla de arriba.
- Si caes en la cabeza de una serpiente ▼, bajas directo a la casilla de abajo.
- Si tu tiro te pasaría de la casilla 100, igual llegas a 100 y ganas (no hace falta caer exacto).

Gana quien llegue primero a la casilla 100."

var player_pos: int = 0
var bot_pos: int = 0
var current_turn: String = "player"
var mode: String = "pve"
var game_over: bool = false

var status_label: Label
var dice_label: Label
var roll_btn: Button
var cell_buttons: Dictionary = {}


func _ready() -> void:
	_build_ui()
	UIKit.show_setup_overlay(self, "Serpientes y Escaleras", true, false, _on_setup_confirmed)


func _on_setup_confirmed(config: Dictionary) -> void:
	mode = config["mode"]
	_new_game()


func _build_ui() -> void:
	UIKit.apply_background(self)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)

	var margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 16)
	scroll.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	UIKit.build_toolbar(vbox, self, "Serpientes y Escaleras", HELP_TEXT)

	status_label = UIKit.title_label("", 18, UIKit.COLOR_TEXT)
	vbox.add_child(status_label)

	dice_label = UIKit.title_label("🎲", 36, UIKit.COLOR_ACCENT_3)
	vbox.add_child(dice_label)

	roll_btn = Button.new()
	roll_btn.text = "Tirar dado"
	roll_btn.custom_minimum_size = Vector2(200, 52)
	UIKit.style_button(roll_btn, UIKit.COLOR_ACCENT)
	roll_btn.pressed.connect(_on_roll_pressed)
	vbox.add_child(roll_btn)

	var board_panel := PanelContainer.new()
	board_panel.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_PANEL, UIKit.COLOR_ACCENT_3, 16, 2))
	var board_margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		board_margin.add_theme_constant_override(side, 8)
	board_panel.add_child(board_margin)
	vbox.add_child(board_panel)

	var grid := GridContainer.new()
	grid.columns = 10
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	board_margin.add_child(grid)

	for r in range(10):
		var row_from_bottom: int = 9 - r
		var base: int = row_from_bottom * 10
		for c in range(10):
			var number: int
			if row_from_bottom % 2 == 0:
				number = base + c + 1
			else:
				number = base + (10 - c)
			var cell := Button.new()
			cell.custom_minimum_size = Vector2(34, 34)
			cell.add_theme_font_size_override("font_size", 10)
			cell.disabled = true
			cell.focus_mode = Control.FOCUS_NONE
			grid.add_child(cell)
			cell_buttons[number] = cell

	var restart_btn := Button.new()
	restart_btn.text = "↻  Nueva partida / Modo"
	restart_btn.custom_minimum_size = Vector2(220, 48)
	UIKit.style_button(restart_btn, UIKit.COLOR_ACCENT_3)
	restart_btn.pressed.connect(func() -> void: UIKit.show_setup_overlay(self, "Serpientes y Escaleras", true, false, _on_setup_confirmed))
	vbox.add_child(restart_btn)


func _new_game() -> void:
	player_pos = 0
	bot_pos = 0
	current_turn = "player"
	game_over = false
	dice_label.text = "🎲"
	roll_btn.disabled = false
	_update_turn_status()
	_redraw_all()


func _redraw_all() -> void:
	for number in range(1, 101):
		var cell: Button = cell_buttons[number]
		var base_color: Color = UIKit.COLOR_BG_LIGHT
		var label: String = str(number)
		if LADDERS.has(number):
			base_color = UIKit.COLOR_ACCENT_2.lerp(UIKit.COLOR_BG_LIGHT, 0.55)
			label = "%d▲" % number
		elif SNAKES.has(number):
			base_color = UIKit.COLOR_DANGER.lerp(UIKit.COLOR_BG_LIGHT, 0.55)
			label = "%d▼" % number

		var border: Color = Color(0, 0, 0, 0)
		var bw: int = 0
		var has_player: bool = player_pos == number
		var has_bot: bool = bot_pos == number
		if has_player and has_bot:
			border = UIKit.COLOR_ACCENT_3
			bw = 3
		elif has_player:
			border = UIKit.COLOR_ACCENT
			bw = 3
		elif has_bot:
			border = UIKit.COLOR_ACCENT_2
			bw = 3

		cell.text = label
		var sb: StyleBoxFlat = UIKit.stylebox(base_color, border, 4, bw)
		cell.add_theme_stylebox_override("normal", sb)
		cell.add_theme_stylebox_override("disabled", sb)


func _on_roll_pressed() -> void:
	if game_over:
		return
	if mode == "pve" and current_turn != "player":
		return
	_do_turn(current_turn)


func _do_turn(owner: String) -> void:
	roll_btn.disabled = true
	var roll: int = randi() % 6 + 1
	dice_label.text = "🎲 %d" % roll

	var pos: int = player_pos if owner == "player" else bot_pos
	pos = min(pos + roll, 100)
	if LADDERS.has(pos):
		pos = LADDERS[pos]
	elif SNAKES.has(pos):
		pos = SNAKES[pos]

	if owner == "player":
		player_pos = pos
	else:
		bot_pos = pos

	_redraw_all()

	if pos == 100:
		_end_game(owner)
		return

	current_turn = "bot" if owner == "player" else "player"
	_update_turn_status()
	roll_btn.disabled = mode == "pve" and current_turn == "bot"

	if mode == "pve" and current_turn == "bot":
		await get_tree().create_timer(0.7).timeout
		_do_turn("bot")


func _update_turn_status() -> void:
	if mode == "pve":
		status_label.text = "Tu turno" if current_turn == "player" else "Turno de la máquina..."
		status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT if current_turn == "player" else UIKit.COLOR_ACCENT_2)
	else:
		var label: String = "Jugador 1 (rosa)" if current_turn == "player" else "Jugador 2 (teal)"
		status_label.text = "Turno: %s" % label
		status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT if current_turn == "player" else UIKit.COLOR_ACCENT_2)


func _end_game(owner: String) -> void:
	game_over = true
	roll_btn.disabled = true
	if mode == "pve":
		if owner == "player":
			status_label.text = "¡Ganaste! Llegaste a la casilla 100"
			status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT_3)
			_record_result("wins")
		else:
			status_label.text = "Ganó la máquina"
			status_label.add_theme_color_override("font_color", UIKit.COLOR_DANGER)
			_record_result("losses")
	else:
		var label: String = "Jugador 1 (rosa)" if owner == "player" else "Jugador 2 (teal)"
		status_label.text = "¡Ganó %s!" % label
		status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT_3)


func _record_result(key: String) -> void:
	var stats: Dictionary = SaveManager.get_game_data(GAME_ID)
	stats[key] = stats.get(key, 0) + 1
	SaveManager.set_game_data(GAME_ID, stats)
