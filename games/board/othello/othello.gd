extends Control
## Otelo / Reversi. 1 jugador contra la máquina (3 niveles de dificultad)
## o 2 jugadores pasando el dispositivo.

const GAME_ID := "othello"
const SIZE := 8
const DIRS := [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]

const POSITION_WEIGHTS := [
	[100, -20, 10, 5, 5, 10, -20, 100],
	[-20, -50, -2, -2, -2, -2, -50, -20],
	[10, -2, 1, 1, 1, 1, -2, 10],
	[5, -2, 1, 1, 1, 1, -2, 5],
	[5, -2, 1, 1, 1, 1, -2, 5],
	[10, -2, 1, 1, 1, 1, -2, 10],
	[-20, -50, -2, -2, -2, -2, -50, -20],
	[100, -20, 10, 5, 5, 10, -20, 100],
]

const HELP_TEXT := "Puedes jugar contra la máquina (3 niveles de dificultad) o pasando el dispositivo entre 2 personas.

Toca una casilla vacía: si tu ficha 'encierra' una o más fichas rivales en línea recta (horizontal, vertical o diagonal) contra otra ficha tuya, esas fichas rivales se voltean a tu color.

Si no tienes ningún movimiento válido, se pasa el turno automáticamente. El juego termina cuando nadie puede mover; gana quien tenga más fichas en el tablero."

var board: Array = []
var cell_buttons: Array = []
var piece_views: Array = []
var current_turn: String = "player"
var game_over: bool = false
var mode: String = "pve"
var difficulty: String = "medium"

var status_label: Label
var score_label: Label


func _ready() -> void:
	_build_ui()
	UIKit.show_setup_overlay(self, "Otelo", true, true, _on_setup_confirmed)


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

	UIKit.build_toolbar(vbox, self, "Otelo", HELP_TEXT)

	status_label = UIKit.title_label("", 22, UIKit.COLOR_TEXT)
	vbox.add_child(status_label)

	score_label = UIKit.title_label("", 18, UIKit.COLOR_TEXT_DIM)
	vbox.add_child(score_label)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_PANEL, UIKit.COLOR_ACCENT_3, 16, 3))
	var panel_margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		panel_margin.add_theme_constant_override(side, 10)
	panel.add_child(panel_margin)

	var center := CenterContainer.new()
	vbox.add_child(center)
	center.add_child(panel)

	var grid := GridContainer.new()
	grid.columns = SIZE
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	panel_margin.add_child(grid)

	for y in range(SIZE):
		var row: Array = []
		var piece_row: Array = []
		for x in range(SIZE):
			var cell := Button.new()
			cell.custom_minimum_size = Vector2(72, 72)
			UIKit.style_button(cell, UIKit.COLOR_BG_LIGHT, 6)
			cell.pressed.connect(_on_cell_pressed.bind(x, y))
			grid.add_child(cell)
			row.append(cell)

			var piece := GamePiece.new()
			piece.set_anchors_preset(Control.PRESET_FULL_RECT)
			cell.add_child(piece)
			piece_row.append(piece)
		cell_buttons.append(row)
		piece_views.append(piece_row)

	var restart_btn := Button.new()
	restart_btn.text = "↻  Nueva partida / Modo"
	restart_btn.custom_minimum_size = Vector2(220, 48)
	UIKit.style_button(restart_btn, UIKit.COLOR_ACCENT_3)
	restart_btn.pressed.connect(func() -> void: UIKit.show_setup_overlay(self, "Otelo", true, true, _on_setup_confirmed))
	vbox.add_child(restart_btn)


func _new_game() -> void:
	board = []
	for y in range(SIZE):
		var row: Array = []
		for x in range(SIZE):
			row.append(null)
		board.append(row)

	board[3][3] = "bot"
	board[4][4] = "bot"
	board[3][4] = "player"
	board[4][3] = "player"

	game_over = false
	_redraw_all()
	_begin_turn("player")


func _flips_for(x: int, y: int, owner: String) -> Array:
	return _flips_for_on(board, x, y, owner)


func _flips_for_on(b: Array, x: int, y: int, owner: String) -> Array:
	if b[y][x] != null:
		return []
	var opponent: String = "bot" if owner == "player" else "player"
	var all_flips: Array = []
	for dir: Vector2i in DIRS:
		var line: Array = []
		var cx: int = x + dir.x
		var cy: int = y + dir.y
		while cx >= 0 and cx < SIZE and cy >= 0 and cy < SIZE and b[cy][cx] == opponent:
			line.append(Vector2i(cx, cy))
			cx += dir.x
			cy += dir.y
		if not line.is_empty() and cx >= 0 and cx < SIZE and cy >= 0 and cy < SIZE and b[cy][cx] == owner:
			all_flips.append_array(line)
	return all_flips


func _legal_moves(owner: String) -> Array:
	return _legal_moves_on(board, owner)


func _legal_moves_on(b: Array, owner: String) -> Array:
	var moves: Array = []
	for y in range(SIZE):
		for x in range(SIZE):
			if not _flips_for_on(b, x, y, owner).is_empty():
				moves.append(Vector2i(x, y))
	return moves


func _place(x: int, y: int, owner: String) -> void:
	_place_on(board, x, y, owner)


func _place_on(b: Array, x: int, y: int, owner: String) -> void:
	var flips: Array = _flips_for_on(b, x, y, owner)
	b[y][x] = owner
	for p: Vector2i in flips:
		b[p.y][p.x] = owner


func _clone_board(b: Array) -> Array:
	var copy: Array = []
	for row: Array in b:
		copy.append(row.duplicate())
	return copy


func _count(owner: String) -> int:
	var n := 0
	for row: Array in board:
		for cell: Variant in row:
			if cell == owner:
				n += 1
	return n


func _redraw_all() -> void:
	var can_act: bool = mode == "pvp" or current_turn == "player"
	var legal: Array = _legal_moves(current_turn) if (not game_over and can_act) else []

	for y in range(SIZE):
		for x in range(SIZE):
			var cell: Button = cell_buttons[y][x]
			var piece: GamePiece = piece_views[y][x]
			var v: Variant = board[y][x]

			if v == null:
				piece.hide_piece()
			else:
				var color: Color = UIKit.COLOR_ACCENT if v == "player" else UIKit.COLOR_ACCENT_2
				piece.set_piece(color)

			var is_legal: bool = legal.has(Vector2i(x, y))
			var bg: Color = UIKit.COLOR_ACCENT_3.lerp(UIKit.COLOR_BG_LIGHT, 0.6) if is_legal else UIKit.COLOR_BG_LIGHT
			var border: Color = UIKit.COLOR_ACCENT_3 if is_legal else Color(0, 0, 0, 0)
			var bw: int = 2 if is_legal else 0
			var sb: StyleBoxFlat = UIKit.stylebox(bg, border, 6, bw)
			cell.add_theme_stylebox_override("normal", sb)
			cell.add_theme_stylebox_override("hover", sb)
			cell.add_theme_stylebox_override("disabled", sb)

	score_label.text = "Tú: %d      Máquina: %d" % [_count("player"), _count("bot")]


func _on_cell_pressed(x: int, y: int) -> void:
	if game_over:
		return
	if mode == "pve" and current_turn != "player":
		return

	var owner: String = current_turn
	if _flips_for(x, y, owner).is_empty():
		return
	_place(x, y, owner)
	_redraw_all()
	_begin_turn("bot" if owner == "player" else "player")


func _begin_turn(owner: String) -> void:
	current_turn = owner
	var moves: Array = _legal_moves(owner)

	if moves.is_empty():
		var other: String = "bot" if owner == "player" else "player"
		if _legal_moves(other).is_empty():
			_end_game()
			return
		var who: String = _turn_label(owner)
		status_label.text = "%s no tiene movimientos, se pasa el turno" % who
		status_label.add_theme_color_override("font_color", UIKit.COLOR_TEXT_DIM)
		_begin_turn(other)
		return

	_update_turn_status(owner)

	if mode == "pve" and owner == "bot":
		await get_tree().create_timer(0.5).timeout
		_bot_move(moves)


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


func _bot_move(moves: Array) -> void:
	var chosen: Vector2i
	match difficulty:
		"easy":
			chosen = moves[randi() % moves.size()]
		"medium":
			chosen = _pick_greedy_move(moves)
		_:
			chosen = _pick_minimax_move(moves, 3)
	_place(chosen.x, chosen.y, "bot")
	_redraw_all()
	_begin_turn("player")


func _pick_greedy_move(moves: Array) -> Vector2i:
	var best: Vector2i = moves[0]
	var best_count := -1
	for m: Vector2i in moves:
		var count: int = _flips_for(m.x, m.y, "bot").size()
		if count > best_count:
			best_count = count
			best = m
	return best


func _evaluate_board(b: Array) -> float:
	var score := 0.0
	for y in range(SIZE):
		for x in range(SIZE):
			var v: Variant = b[y][x]
			if v == "bot":
				score += POSITION_WEIGHTS[y][x]
			elif v == "player":
				score -= POSITION_WEIGHTS[y][x]
	return score


func _minimax_othello(b: Array, depth: int, alpha: float, beta: float, owner: String) -> float:
	if depth == 0:
		return _evaluate_board(b)

	var moves: Array = _legal_moves_on(b, owner)
	if moves.is_empty():
		var other: String = "bot" if owner == "player" else "player"
		if _legal_moves_on(b, other).is_empty():
			return _evaluate_board(b) * 2.0
		return _minimax_othello(b, depth - 1, alpha, beta, other)

	if owner == "bot":
		var best := -INF
		for m: Vector2i in moves:
			var nb: Array = _clone_board(b)
			_place_on(nb, m.x, m.y, owner)
			best = max(best, _minimax_othello(nb, depth - 1, alpha, beta, "player"))
			alpha = max(alpha, best)
			if beta <= alpha:
				break
		return best
	else:
		var best := INF
		for m: Vector2i in moves:
			var nb: Array = _clone_board(b)
			_place_on(nb, m.x, m.y, owner)
			best = min(best, _minimax_othello(nb, depth - 1, alpha, beta, "bot"))
			beta = min(beta, best)
			if beta <= alpha:
				break
		return best


func _pick_minimax_move(moves: Array, depth: int) -> Vector2i:
	var best_move: Vector2i = moves[0]
	var best_score := -INF
	for m: Vector2i in moves:
		var nb: Array = _clone_board(board)
		_place_on(nb, m.x, m.y, "bot")
		var score: float = _minimax_othello(nb, depth - 1, -INF, INF, "player")
		if score > best_score:
			best_score = score
			best_move = m
	return best_move


func _end_game() -> void:
	game_over = true
	var player_count: int = _count("player")
	var bot_count: int = _count("bot")

	if mode == "pve":
		if player_count > bot_count:
			status_label.text = "¡Ganaste! %d - %d" % [player_count, bot_count]
			status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT_3)
			_record_result("wins")
		elif bot_count > player_count:
			status_label.text = "Ganó la máquina %d - %d" % [bot_count, player_count]
			status_label.add_theme_color_override("font_color", UIKit.COLOR_DANGER)
			_record_result("losses")
		else:
			status_label.text = "Empate %d - %d" % [player_count, bot_count]
			status_label.add_theme_color_override("font_color", UIKit.COLOR_TEXT_DIM)
			_record_result("draws")
	else:
		if player_count == bot_count:
			status_label.text = "Empate %d - %d" % [player_count, bot_count]
			status_label.add_theme_color_override("font_color", UIKit.COLOR_TEXT_DIM)
		else:
			var winner: String = "Jugador 1 (rosa)" if player_count > bot_count else "Jugador 2 (teal)"
			status_label.text = "¡Ganó %s! %d - %d" % [winner, max(player_count, bot_count), min(player_count, bot_count)]
			status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT_3)


func _record_result(key: String) -> void:
	var stats: Dictionary = SaveManager.get_game_data(GAME_ID)
	stats[key] = stats.get(key, 0) + 1
	SaveManager.set_game_data(GAME_ID, stats)
