extends Control
## Cuatro en Línea (Connect Four). 1 jugador contra la máquina (3 niveles
## de dificultad) o 2 jugadores pasando el dispositivo.

const GAME_ID := "connect_four"
const COLS := 7
const ROWS := 6

const HELP_TEXT := "Puedes jugar contra la máquina (3 niveles de dificultad) o pasando el dispositivo entre 2 personas.

- Toca una de las flechas de arriba para dejar caer tu ficha en esa columna.
- La ficha cae hasta el fondo o hasta la primera ficha que encuentre.
- Gana quien primero forme una línea de 4 fichas propias: horizontal, vertical o diagonal.
- Si el tablero se llena sin que nadie forme línea, es empate."

var board: Array = []
var column_buttons: Array = []
var cell_views: Array = []
var current_turn: String = "player"
var game_over: bool = false
var mode: String = "pve"
var difficulty: String = "medium"
var session_id: int = 0

var status_label: Label


func _ready() -> void:
	_build_ui()
	UIKit.show_setup_overlay(self, "Cuatro en Línea", true, true, _on_setup_confirmed)


func _on_setup_confirmed(config: Dictionary) -> void:
	mode = config["mode"]
	difficulty = config["difficulty"]
	_new_game()


func _build_ui() -> void:
	UIKit.apply_background(self)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	UIKit.build_toolbar(vbox, self, "Cuatro en Línea", HELP_TEXT)

	status_label = UIKit.title_label("", 22, UIKit.COLOR_TEXT)
	vbox.add_child(status_label)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_PANEL, UIKit.COLOR_ACCENT_3, 16, 3))
	var panel_margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		panel_margin.add_theme_constant_override(side, 10)
	panel.add_child(panel_margin)

	var center := CenterContainer.new()
	vbox.add_child(center)
	center.add_child(panel)

	var board_vbox := VBoxContainer.new()
	board_vbox.add_theme_constant_override("separation", 4)
	panel_margin.add_child(board_vbox)

	var drop_row := HBoxContainer.new()
	drop_row.add_theme_constant_override("separation", 2)
	board_vbox.add_child(drop_row)

	for x in range(COLS):
		var drop_btn := Button.new()
		drop_btn.text = "▼"
		drop_btn.custom_minimum_size = Vector2(60, 40)
		UIKit.style_button(drop_btn, UIKit.COLOR_ACCENT_2, 6)
		drop_btn.pressed.connect(_on_column_pressed.bind(x))
		drop_row.add_child(drop_btn)
		column_buttons.append(drop_btn)

	var grid := GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	board_vbox.add_child(grid)

	for y in range(ROWS):
		var row: Array = []
		for x in range(COLS):
			var cell := PanelContainer.new()
			cell.custom_minimum_size = Vector2(60, 60)
			cell.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_BG_LIGHT, Color(0, 0, 0, 0), 6))
			grid.add_child(cell)

			var piece := GamePiece.new()
			piece.set_anchors_preset(Control.PRESET_FULL_RECT)
			cell.add_child(piece)
			row.append(piece)
		cell_views.append(row)

	var restart_btn := Button.new()
	restart_btn.text = "↻  Nueva partida / Modo"
	restart_btn.custom_minimum_size = Vector2(220, 48)
	UIKit.style_button(restart_btn, UIKit.COLOR_ACCENT_3)
	restart_btn.pressed.connect(func() -> void: UIKit.show_setup_overlay(self, "Cuatro en Línea", true, true, _on_setup_confirmed))
	vbox.add_child(restart_btn)


func _new_game() -> void:
	board = []
	for y in range(ROWS):
		var row: Array = []
		for x in range(COLS):
			row.append(null)
		board.append(row)

	session_id += 1
	game_over = false
	current_turn = "player"
	_redraw_all()
	_update_turn_status("player")


func _valid_columns(b: Array) -> Array:
	var moves: Array = []
	for x in range(COLS):
		if b[0][x] == null:
			moves.append(x)
	return moves


func _drop(b: Array, col: int, owner: String) -> int:
	for y in range(ROWS - 1, -1, -1):
		if b[y][col] == null:
			b[y][col] = owner
			return y
	return -1


func _clone_board(b: Array) -> Array:
	var copy: Array = []
	for row: Array in b:
		copy.append(row.duplicate())
	return copy


func _check_dir(b: Array, y: int, x: int, dy: int, dx: int, owner: String) -> bool:
	for i in range(4):
		var yy: int = y + dy * i
		var xx: int = x + dx * i
		if yy < 0 or yy >= ROWS or xx < 0 or xx >= COLS or b[yy][xx] != owner:
			return false
	return true


func _winner_on(b: Array) -> String:
	for y in range(ROWS):
		for x in range(COLS):
			var owner: Variant = b[y][x]
			if owner == null:
				continue
			if _check_dir(b, y, x, 0, 1, owner) or _check_dir(b, y, x, 1, 0, owner) or _check_dir(b, y, x, 1, 1, owner) or _check_dir(b, y, x, 1, -1, owner):
				return owner
	return ""


func _winning_cells(b: Array) -> Array:
	for y in range(ROWS):
		for x in range(COLS):
			var owner: Variant = b[y][x]
			if owner == null:
				continue
			for dir: Vector2i in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, -1)]:
				if _check_dir(b, y, x, dir.x, dir.y, owner):
					var cells: Array = []
					for i in range(4):
						cells.append(Vector2i(x + dir.y * i, y + dir.x * i))
					return cells
	return []


func _redraw_all() -> void:
	for y in range(ROWS):
		for x in range(COLS):
			var piece: GamePiece = cell_views[y][x]
			var v: Variant = board[y][x]
			if v == null:
				piece.hide_piece()
			else:
				var color: Color = UIKit.COLOR_ACCENT if v == "player" else UIKit.COLOR_ACCENT_2
				piece.set_piece(color)
			piece.set_ring(Color(0, 0, 0, 0))

	var can_act: bool = not game_over and (mode == "pvp" or current_turn == "player")
	var moves: Array = _valid_columns(board)
	for x in range(COLS):
		column_buttons[x].disabled = not can_act or not moves.has(x)


func _on_column_pressed(col: int) -> void:
	if game_over:
		return
	if mode == "pve" and current_turn != "player":
		return
	if board[0][col] != null:
		return

	var my_session: int = session_id
	var owner: String = current_turn
	var row: int = _drop(board, col, owner)

	var winner: String = _winner_on(board)
	if winner != "":
		_redraw_all()
		UIKit.pulse(cell_views[row][col])
		_end_game(winner)
		return
	if _valid_columns(board).is_empty():
		_redraw_all()
		UIKit.pulse(cell_views[row][col])
		_end_game_draw()
		return

	# Importante: cambiar el turno ANTES de redibujar. _redraw_all() decide
	# si los botones de columna quedan habilitados según current_turn; si
	# se llamaba antes de este cambio, los botones quedaban reflejando el
	# turno VIEJO (deshabilitados para siempre después de que la máquina
	# respondía, porque nunca se volvían a redibujar tras el segundo
	# cambio de turno) — eso es lo que hacía que "ya no se hiciera nada"
	# después de la primera jugada.
	var next_turn: String = "bot" if owner == "player" else "player"
	current_turn = next_turn
	_redraw_all()
	UIKit.pulse(cell_views[row][col])
	_update_turn_status(next_turn)
	if mode == "pve" and next_turn == "bot":
		await get_tree().create_timer(0.8).timeout
		if my_session != session_id:
			return
		_bot_move()


func _bot_move() -> void:
	var moves: Array = _valid_columns(board)
	if moves.is_empty():
		_end_game_draw()
		return
	var chosen: int
	match difficulty:
		"easy":
			chosen = moves[randi() % moves.size()]
		"medium":
			chosen = _pick_greedy_move(moves)
		_:
			chosen = _pick_minimax_move(moves, 4)

	var row: int = _drop(board, chosen, "bot")

	var winner: String = _winner_on(board)
	if winner != "":
		_redraw_all()
		UIKit.pulse(cell_views[row][chosen])
		_end_game(winner)
		return
	if _valid_columns(board).is_empty():
		_redraw_all()
		UIKit.pulse(cell_views[row][chosen])
		_end_game_draw()
		return

	current_turn = "player"
	_redraw_all()
	UIKit.pulse(cell_views[row][chosen])
	_update_turn_status("player")


func _pick_greedy_move(moves: Array) -> int:
	for m: int in moves:
		var nb: Array = _clone_board(board)
		_drop(nb, m, "bot")
		if _winner_on(nb) == "bot":
			return m
	for m: int in moves:
		var nb: Array = _clone_board(board)
		_drop(nb, m, "player")
		if _winner_on(nb) == "player":
			return m
	var best: int = moves[0]
	var best_score := -INF
	for m: int in moves:
		var nb: Array = _clone_board(board)
		_drop(nb, m, "bot")
		var score: float = _evaluate_board(nb)
		if score > best_score:
			best_score = score
			best = m
	return best


func _score_window(window: Array, owner: String) -> int:
	var opp: String = "player" if owner == "bot" else "bot"
	var owner_count: int = window.count(owner)
	var opp_count: int = window.count(opp)
	var empty_count: int = window.count(null)
	if owner_count == 4:
		return 100
	elif owner_count == 3 and empty_count == 1:
		return 6
	elif owner_count == 2 and empty_count == 2:
		return 2
	elif opp_count == 3 and empty_count == 1:
		return -8
	return 0


func _evaluate_board(b: Array) -> float:
	var score := 0.0
	for y in range(ROWS):
		var center_col := COLS / 2
		if b[y][center_col] == "bot":
			score += 3
		elif b[y][center_col] == "player":
			score -= 3

	for y in range(ROWS):
		for x in range(COLS - 3):
			var window: Array = [b[y][x], b[y][x + 1], b[y][x + 2], b[y][x + 3]]
			score += _score_window(window, "bot")

	for x in range(COLS):
		for y in range(ROWS - 3):
			var window: Array = [b[y][x], b[y + 1][x], b[y + 2][x], b[y + 3][x]]
			score += _score_window(window, "bot")

	for y in range(ROWS - 3):
		for x in range(COLS - 3):
			var window1: Array = [b[y][x], b[y + 1][x + 1], b[y + 2][x + 2], b[y + 3][x + 3]]
			score += _score_window(window1, "bot")
			var window2: Array = [b[y + 3][x], b[y + 2][x + 1], b[y + 1][x + 2], b[y][x + 3]]
			score += _score_window(window2, "bot")

	return score


func _minimax_c4(b: Array, depth: int, alpha: float, beta: float, owner: String) -> float:
	var winner: String = _winner_on(b)
	if winner == "bot":
		return 100000.0 + depth
	if winner == "player":
		return -100000.0 - depth
	var moves: Array = _valid_columns(b)
	if moves.is_empty():
		return 0.0
	if depth == 0:
		return _evaluate_board(b)

	if owner == "bot":
		var best := -INF
		for m: int in moves:
			var nb: Array = _clone_board(b)
			_drop(nb, m, "bot")
			best = max(best, _minimax_c4(nb, depth - 1, alpha, beta, "player"))
			alpha = max(alpha, best)
			if beta <= alpha:
				break
		return best
	else:
		var best := INF
		for m: int in moves:
			var nb: Array = _clone_board(b)
			_drop(nb, m, "player")
			best = min(best, _minimax_c4(nb, depth - 1, alpha, beta, "bot"))
			beta = min(beta, best)
			if beta <= alpha:
				break
		return best


func _pick_minimax_move(moves: Array, depth: int) -> int:
	var best_move: int = moves[0]
	var best_score := -INF
	for m: int in moves:
		var nb: Array = _clone_board(board)
		_drop(nb, m, "bot")
		var score: float = _minimax_c4(nb, depth - 1, -INF, INF, "player")
		if score > best_score:
			best_score = score
			best_move = m
	return best_move


func _turn_label(owner: String) -> String:
	if mode == "pve":
		return "Tú" if owner == "player" else "La máquina"
	return "Jugador 1 (rosa)" if owner == "player" else "Jugador 2 (teal)"


func _update_turn_status(owner: String) -> void:
	if mode == "pve":
		if owner == "player":
			status_label.text = "Tu turno"
			status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT)
		else:
			status_label.text = "Turno de la máquina..."
			status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT_2)
	else:
		status_label.text = "Turno: %s" % _turn_label(owner)
		status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT if owner == "player" else UIKit.COLOR_ACCENT_2)


func _end_game(winner: String) -> void:
	game_over = true
	for cell: Vector2i in _winning_cells(board):
		cell_views[cell.y][cell.x].set_ring(UIKit.COLOR_ACCENT_3)
	for x in range(COLS):
		column_buttons[x].disabled = true

	if mode == "pve":
		if winner == "player":
			status_label.text = "¡Ganaste! Formaste 4 en línea"
			status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT_3)
			_record_result("wins")
		else:
			status_label.text = "Ganó la máquina"
			status_label.add_theme_color_override("font_color", UIKit.COLOR_DANGER)
			_record_result("losses")
	else:
		var label: String = "Jugador 1 (rosa)" if winner == "player" else "Jugador 2 (teal)"
		status_label.text = "¡Ganó %s!" % label
		status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT_3)
		AudioManager.play_win()


func _end_game_draw() -> void:
	game_over = true
	for x in range(COLS):
		column_buttons[x].disabled = true
	status_label.text = "Empate, el tablero se llenó"
	status_label.add_theme_color_override("font_color", UIKit.COLOR_TEXT_DIM)
	if mode == "pve":
		_record_result("draws")


func _record_result(key: String) -> void:
	if key.begins_with("win") or key.begins_with("completed"):
		AudioManager.play_win()
	elif key.begins_with("loss") or key.begins_with("fail"):
		AudioManager.play_lose()
	var stats: Dictionary = SaveManager.get_game_data(GAME_ID)
	stats[key] = stats.get(key, 0) + 1
	SaveManager.set_game_data(GAME_ID, stats)
