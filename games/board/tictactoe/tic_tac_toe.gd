extends Control
## Gato (Tic-Tac-Toe). 2 jugadores en el mismo dispositivo, o 1 jugador
## contra la máquina con 3 niveles de dificultad.

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

const HELP_TEXT := "Puedes jugar contra la máquina (con 3 niveles de dificultad) o pasando el dispositivo entre 2 personas.

Empieza el jugador X. Toca una celda vacía para marcarla con tu símbolo.

Gana quien logre alinear 3 símbolos iguales en fila, columna o diagonal. Si el tablero se llena sin ganador, es empate."

var board: Array[String] = []
var current_player: String = "X"
var game_over: bool = false
var cell_buttons: Array[Button] = []
var winning_line: Array = []

var mode: String = "pvp"
var difficulty: String = "medium"
const BOT_SYMBOL := "O"
const HUMAN_SYMBOL := "X"

var status_label: Label


func _ready() -> void:
	_build_ui()
	UIKit.show_setup_overlay(self, "Gato", true, true, _on_setup_confirmed)


func _on_setup_confirmed(config: Dictionary) -> void:
	mode = config["mode"]
	difficulty = config["difficulty"]
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
		cell.custom_minimum_size = Vector2(130, 130)
		cell.add_theme_font_size_override("font_size", 64)
		UIKit.style_button(cell, UIKit.COLOR_BG_LIGHT, 12)
		cell.pressed.connect(_on_cell_pressed.bind(i))
		grid.add_child(cell)
		cell_buttons.append(cell)

	var restart_btn := Button.new()
	restart_btn.text = "↻  Cambiar modo"
	restart_btn.custom_minimum_size = Vector2(200, 48)
	UIKit.style_button(restart_btn, UIKit.COLOR_ACCENT_3)
	restart_btn.pressed.connect(func() -> void: UIKit.show_setup_overlay(self, "Gato", true, true, _on_setup_confirmed))
	vbox.add_child(restart_btn)


func _new_game() -> void:
	board.clear()
	for i in range(9):
		board.append("")
	current_player = "X"
	game_over = false
	winning_line = []
	for cell: Button in cell_buttons:
		cell.text = ""
		cell.disabled = false
		UIKit.style_button(cell, UIKit.COLOR_BG_LIGHT, 12)
	_update_status()


func _update_status() -> void:
	if mode == "pve" and current_player == BOT_SYMBOL:
		status_label.text = "Turno de la máquina..."
	else:
		status_label.text = "Turno: %s" % current_player
	status_label.add_theme_color_override("font_color", PLAYER_COLORS[current_player])


func _on_cell_pressed(index: int) -> void:
	if game_over or board[index] != "":
		return
	if mode == "pve" and current_player != HUMAN_SYMBOL:
		return
	_place(index)


func _place(index: int) -> void:
	board[index] = current_player
	var cell := cell_buttons[index]
	cell.text = current_player
	cell.disabled = true
	cell.add_theme_color_override("font_disabled_color", PLAYER_COLORS[current_player])
	UIKit.pulse(cell)

	var winner := _check_winner(board)
	if winner != "":
		game_over = true
		if mode == "pve":
			status_label.text = "¡Ganaste!" if winner == HUMAN_SYMBOL else "Ganó la máquina"
			_record_result("wins" if winner == HUMAN_SYMBOL else "losses")
		else:
			status_label.text = "¡Gana %s!" % winner
			_record_result("wins")
		status_label.add_theme_color_override("font_color", PLAYER_COLORS[winner])
		_highlight_win(winning_line)
		return

	if not board.has(""):
		game_over = true
		status_label.text = "Empate"
		status_label.add_theme_color_override("font_color", UIKit.COLOR_TEXT_DIM)
		_record_result("draws")
		return

	current_player = "O" if current_player == "X" else "X"
	_update_status()

	if mode == "pve" and current_player == BOT_SYMBOL and not game_over:
		await get_tree().create_timer(0.4).timeout
		_bot_move()


func _check_winner(b: Array) -> String:
	for line: Array in WIN_LINES:
		var a: String = b[line[0]]
		var b2: String = b[line[1]]
		var c: String = b[line[2]]
		if a != "" and a == b2 and b2 == c:
			winning_line = line
			return a
	return ""


func _highlight_win(line: Array) -> void:
	for i: int in line:
		UIKit.style_button(cell_buttons[i], UIKit.COLOR_ACCENT_3, 12)
		cell_buttons[i].add_theme_color_override("font_disabled_color", UIKit.COLOR_BG)


func _record_result(key: String) -> void:
	var stats: Dictionary = SaveManager.get_game_data(GAME_ID)
	stats[key] = stats.get(key, 0) + 1
	SaveManager.set_game_data(GAME_ID, stats)


# --- IA ---

func _bot_move() -> void:
	if game_over:
		return
	var index: int
	match difficulty:
		"easy":
			index = _pick_random()
		"medium":
			index = _pick_medium()
		_:
			index = _pick_best()
	_place(index)


func _pick_random() -> int:
	var options: Array = []
	for i in range(9):
		if board[i] == "":
			options.append(i)
	return options[randi() % options.size()]


func _pick_medium() -> int:
	# Gana si puede, bloquea si es necesario, si no juega al azar.
	var win_move := _find_winning_move(BOT_SYMBOL)
	if win_move != -1:
		return win_move
	var block_move := _find_winning_move(HUMAN_SYMBOL)
	if block_move != -1:
		return block_move
	return _pick_random()


func _find_winning_move(symbol: String) -> int:
	for i in range(9):
		if board[i] != "":
			continue
		var copy: Array = board.duplicate()
		copy[i] = symbol
		if _check_winner(copy) == symbol:
			return i
	return -1


func _pick_best() -> int:
	var result := _minimax(board.duplicate(), BOT_SYMBOL)
	return result["index"]


func _minimax(b: Array, player: String) -> Dictionary:
	var winner := _check_winner(b)
	if winner == BOT_SYMBOL:
		return {"score": 1, "index": -1}
	if winner == HUMAN_SYMBOL:
		return {"score": -1, "index": -1}
	if not b.has(""):
		return {"score": 0, "index": -1}

	var best_index := -1
	var best_score: int = -999 if player == BOT_SYMBOL else 999

	for i in range(9):
		if b[i] != "":
			continue
		var copy: Array = b.duplicate()
		copy[i] = player
		var result: Dictionary = _minimax(copy, HUMAN_SYMBOL if player == BOT_SYMBOL else BOT_SYMBOL)
		var score: int = result["score"]

		if player == BOT_SYMBOL and score > best_score:
			best_score = score
			best_index = i
		elif player == HUMAN_SYMBOL and score < best_score:
			best_score = score
			best_index = i

	return {"score": best_score, "index": best_index}
