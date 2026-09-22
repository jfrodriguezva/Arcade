extends Control
## Gato (Tic-Tac-Toe) local, 2 jugadores en el mismo dispositivo.

const GAME_ID := "tictactoe"
const WIN_LINES := [
	[0, 1, 2], [3, 4, 5], [6, 7, 8],
	[0, 3, 6], [1, 4, 7], [2, 5, 8],
	[0, 4, 8], [2, 4, 6],
]

const PLAYER_COLORS := {
	"X": Color(1.0, 0.365, 0.451),   # rosa/rojo (UIKit.COLOR_ACCENT)
	"O": Color(0.306, 0.804, 0.769), # teal (UIKit.COLOR_ACCENT_2)
}

const HELP_TEXT := "Se juega por turnos entre 2 personas en el mismo dispositivo.

Empieza el jugador X. Toca una celda vacía para marcarla con tu símbolo.

Gana quien logre alinear 3 símbolos iguales en fila, columna o diagonal. Si el tablero se llena sin ganador, es empate."

var board: Array[String] = []
var current_player: String = "X"
var game_over: bool = false
var cell_buttons: Array[Button] = []

var status_label: Label


func _ready() -> void:
	_build_ui()
	_new_game()


func _build_ui() -> void:
	UIKit.apply_background(self)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 48)
	margin.add_theme_constant_override("margin_bottom", 32)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	UIKit.build_toolbar(vbox, self, "Gato", HELP_TEXT)

	status_label = UIKit.title_label("", 26, UIKit.COLOR_TEXT)
	vbox.add_child(status_label)

	var board_panel := PanelContainer.new()
	board_panel.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_PANEL, UIKit.COLOR_ACCENT_3, 20, 3))
	var board_margin := MarginContainer.new()
	board_margin.add_theme_constant_override("margin_left", 16)
	board_margin.add_theme_constant_override("margin_right", 16)
	board_margin.add_theme_constant_override("margin_top", 16)
	board_margin.add_theme_constant_override("margin_bottom", 16)
	board_panel.add_child(board_margin)

	var grid_center := CenterContainer.new()
	grid_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(grid_center)
	grid_center.add_child(board_panel)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	board_margin.add_child(grid)

	for i in range(9):
		var cell := Button.new()
		cell.custom_minimum_size = Vector2(96, 96)
		cell.add_theme_font_size_override("font_size", 48)
		UIKit.style_button(cell, UIKit.COLOR_BG_LIGHT, 12)
		cell.pressed.connect(_on_cell_pressed.bind(i))
		grid.add_child(cell)
		cell_buttons.append(cell)

	var restart_btn := Button.new()
	restart_btn.text = "↻  Reiniciar"
	restart_btn.custom_minimum_size = Vector2(160, 48)
	UIKit.style_button(restart_btn, UIKit.COLOR_ACCENT_3)
	restart_btn.pressed.connect(_new_game)
	vbox.add_child(restart_btn)


func _new_game() -> void:
	board.clear()
	for i in range(9):
		board.append("")
	current_player = "X"
	game_over = false
	for cell: Button in cell_buttons:
		cell.text = ""
		cell.disabled = false
		UIKit.style_button(cell, UIKit.COLOR_BG_LIGHT, 12)
	_update_status()


func _update_status() -> void:
	status_label.text = "Turno: %s" % current_player
	status_label.add_theme_color_override("font_color", PLAYER_COLORS[current_player])


func _on_cell_pressed(index: int) -> void:
	if game_over or board[index] != "":
		return

	board[index] = current_player
	var cell := cell_buttons[index]
	cell.text = current_player
	cell.disabled = true
	cell.add_theme_color_override("font_disabled_color", PLAYER_COLORS[current_player])
	UIKit.pulse(cell)

	var winner := _check_winner()
	if winner != "":
		game_over = true
		status_label.text = "¡Gana %s!" % winner
		status_label.add_theme_color_override("font_color", PLAYER_COLORS[winner])
		_highlight_win(_winning_line)
		_record_result(winner)
		return

	if not board.has(""):
		game_over = true
		status_label.text = "Empate"
		status_label.add_theme_color_override("font_color", UIKit.COLOR_TEXT_DIM)
		_record_result("draw")
		return

	current_player = "O" if current_player == "X" else "X"
	_update_status()


var _winning_line: Array = []


func _check_winner() -> String:
	for line: Array in WIN_LINES:
		var a: String = board[line[0]]
		var b: String = board[line[1]]
		var c: String = board[line[2]]
		if a != "" and a == b and b == c:
			_winning_line = line
			return a
	return ""


func _highlight_win(line: Array) -> void:
	for i: int in line:
		UIKit.style_button(cell_buttons[i], UIKit.COLOR_ACCENT_3, 12)
		cell_buttons[i].add_theme_color_override("font_disabled_color", UIKit.COLOR_BG)


func _record_result(result: String) -> void:
	var stats: Dictionary = SaveManager.get_game_data(GAME_ID)
	stats[result] = stats.get(result, 0) + 1
	SaveManager.set_game_data(GAME_ID, stats)
