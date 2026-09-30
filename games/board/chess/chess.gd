extends Control
## Ajedrez con reglas estándar: movimientos de cada pieza, enroque corto y
## largo, jaque, jaque mate, ahogado y promoción automática a Dama.
## Simplificación consciente: no incluye captura al paso (en passant),
## por ser una regla poco usada y de alto riesgo de bugs sutiles.
## 1 jugador contra la máquina (3 niveles) o 2 jugadores en el mismo
## dispositivo.

const GAME_ID := "chess"
const SIZE := 8

const PIECE_GLYPHS := {"P": "♙", "N": "♘", "B": "♗", "R": "♖", "Q": "♕", "K": "♔"}
const PIECE_VALUES := {"P": 100.0, "N": 320.0, "B": 330.0, "R": 500.0, "Q": 900.0, "K": 20000.0}
const BACK_RANK_ORDER := ["R", "N", "B", "Q", "K", "B", "N", "R"]

const KNIGHT_OFFSETS := [
	Vector2i(1, 2), Vector2i(2, 1), Vector2i(2, -1), Vector2i(1, -2),
	Vector2i(-1, -2), Vector2i(-2, -1), Vector2i(-2, 1), Vector2i(-1, 2),
]
const BISHOP_DIRS := [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
const ROOK_DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const KING_OFFSETS := [
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
]

const PAWN_TABLE := [
	[0, 0, 0, 0, 0, 0, 0, 0],
	[50, 50, 50, 50, 50, 50, 50, 50],
	[10, 10, 20, 30, 30, 20, 10, 10],
	[5, 5, 10, 25, 25, 10, 5, 5],
	[0, 0, 0, 20, 20, 0, 0, 0],
	[5, -5, -10, 0, 0, -10, -5, 5],
	[5, 10, 10, -20, -20, 10, 10, 5],
	[0, 0, 0, 0, 0, 0, 0, 0],
]
const KNIGHT_TABLE := [
	[-50, -40, -30, -30, -30, -30, -40, -50],
	[-40, -20, 0, 0, 0, 0, -20, -40],
	[-30, 0, 10, 15, 15, 10, 0, -30],
	[-30, 5, 15, 20, 20, 15, 5, -30],
	[-30, 0, 15, 20, 20, 15, 0, -30],
	[-30, 5, 10, 15, 15, 10, 5, -30],
	[-40, -20, 0, 5, 5, 0, -20, -40],
	[-50, -40, -30, -30, -30, -30, -40, -50],
]

const HELP_TEXT := "Puedes jugar contra la máquina (3 niveles de dificultad) o pasando el dispositivo entre 2 personas.

- Toca una pieza tuya para ver sus movimientos posibles (celdas con borde teal).
- Toca una celda marcada para mover ahí.
- El rey puede enrocar con una torre que no se haya movido, si no hay piezas entre ellos y el rey no pasa por jaque.
- Los peones que llegan al otro extremo se convierten automáticamente en Dama.

Gana quien dé jaque mate. Si el jugador en turno no tiene movimientos legales y no está en jaque, es tablas por ahogado.

(Simplificación: esta versión no incluye la captura al paso)."

var board: Array = []
var cell_buttons: Array = []
var current_turn: String = "player"
var game_over: bool = false
var mode: String = "pve"
var difficulty: String = "medium"
var selected: Vector2i = Vector2i(-1, -1)
var legal_targets: Array = []

var status_label: Label


func _ready() -> void:
	_build_ui()
	UIKit.show_setup_overlay(self, "Ajedrez", true, true, _on_setup_confirmed)


func _on_setup_confirmed(config: Dictionary) -> void:
	mode = config["mode"]
	difficulty = config["difficulty"]
	_new_game()


func _build_ui() -> void:
	UIKit.apply_background(self)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 20)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	UIKit.build_toolbar(vbox, self, "Ajedrez", HELP_TEXT)

	status_label = UIKit.title_label("", 20, UIKit.COLOR_TEXT)
	vbox.add_child(status_label)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_PANEL, UIKit.COLOR_ACCENT_3, 16, 3))
	var panel_margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		panel_margin.add_theme_constant_override(side, 8)
	panel.add_child(panel_margin)

	var center := CenterContainer.new()
	vbox.add_child(center)
	center.add_child(panel)

	var grid := GridContainer.new()
	grid.columns = SIZE
	grid.add_theme_constant_override("h_separation", 1)
	grid.add_theme_constant_override("v_separation", 1)
	panel_margin.add_child(grid)

	for y in range(SIZE):
		var row: Array = []
		for x in range(SIZE):
			var cell := Button.new()
			cell.custom_minimum_size = Vector2(72, 72)
			cell.add_theme_font_size_override("font_size", 40)
			cell.pressed.connect(_on_cell_pressed.bind(x, y))
			grid.add_child(cell)
			row.append(cell)
		cell_buttons.append(row)

	var restart_btn := Button.new()
	restart_btn.text = "🔁  Nueva partida / Modo"
	restart_btn.custom_minimum_size = Vector2(220, 48)
	UIKit.style_button(restart_btn, UIKit.COLOR_ACCENT_3)
	restart_btn.pressed.connect(func() -> void: UIKit.show_setup_overlay(self, "Ajedrez", true, true, _on_setup_confirmed))
	vbox.add_child(restart_btn)


func _new_game() -> void:
	board = []
	for y in range(SIZE):
		var row: Array = []
		for x in range(SIZE):
			row.append(null)
		board.append(row)

	for x in range(SIZE):
		board[0][x] = {"type": BACK_RANK_ORDER[x], "owner": "bot", "moved": false}
		board[1][x] = {"type": "P", "owner": "bot", "moved": false}
		board[6][x] = {"type": "P", "owner": "player", "moved": false}
		board[7][x] = {"type": BACK_RANK_ORDER[x], "owner": "player", "moved": false}

	current_turn = "player"
	game_over = false
	selected = Vector2i(-1, -1)
	legal_targets = []
	_update_turn_status()
	_redraw_all()


# --- Generación de movimientos ---

func _in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < SIZE and y >= 0 and y < SIZE


func _pseudo_moves(b: Array, x: int, y: int) -> Array:
	var piece: Dictionary = b[y][x]
	var owner: String = piece["owner"]
	var moves: Array = []

	match piece["type"]:
		"P":
			var dir: int = -1 if owner == "player" else 1
			var start_row: int = 6 if owner == "player" else 1
			var ny: int = y + dir
			if _in_bounds(x, ny) and b[ny][x] == null:
				moves.append(Vector2i(x, ny))
				var ny2: int = y + dir * 2
				if y == start_row and b[ny2][x] == null:
					moves.append(Vector2i(x, ny2))
			for dx in [-1, 1]:
				var nx: int = x + dx
				if _in_bounds(nx, ny) and b[ny][nx] != null and b[ny][nx]["owner"] != owner:
					moves.append(Vector2i(nx, ny))
		"N":
			for off: Vector2i in KNIGHT_OFFSETS:
				var nx: int = x + off.x
				var ny2: int = y + off.y
				if _in_bounds(nx, ny2) and (b[ny2][nx] == null or b[ny2][nx]["owner"] != owner):
					moves.append(Vector2i(nx, ny2))
		"B":
			_add_sliding(b, x, y, owner, BISHOP_DIRS, moves)
		"R":
			_add_sliding(b, x, y, owner, ROOK_DIRS, moves)
		"Q":
			_add_sliding(b, x, y, owner, BISHOP_DIRS, moves)
			_add_sliding(b, x, y, owner, ROOK_DIRS, moves)
		"K":
			for off: Vector2i in KING_OFFSETS:
				var nx: int = x + off.x
				var ny2: int = y + off.y
				if _in_bounds(nx, ny2) and (b[ny2][nx] == null or b[ny2][nx]["owner"] != owner):
					moves.append(Vector2i(nx, ny2))
			_add_castle_moves(b, x, y, owner, moves)

	return moves


func _add_sliding(b: Array, x: int, y: int, owner: String, dirs: Array, moves: Array) -> void:
	for dir: Vector2i in dirs:
		var nx: int = x + dir.x
		var ny: int = y + dir.y
		while _in_bounds(nx, ny):
			if b[ny][nx] == null:
				moves.append(Vector2i(nx, ny))
			else:
				if b[ny][nx]["owner"] != owner:
					moves.append(Vector2i(nx, ny))
				break
			nx += dir.x
			ny += dir.y


func _add_castle_moves(b: Array, x: int, y: int, owner: String, moves: Array) -> void:
	var king: Dictionary = b[y][x]
	if king["moved"] or _is_square_attacked(b, x, y, owner):
		return

	var rook_k: Variant = b[y][7]
	if rook_k != null and rook_k["type"] == "R" and rook_k["owner"] == owner and not rook_k["moved"]:
		if b[y][5] == null and b[y][6] == null:
			if not _is_square_attacked(b, 5, y, owner) and not _is_square_attacked(b, 6, y, owner):
				moves.append(Vector2i(6, y))

	var rook_q: Variant = b[y][0]
	if rook_q != null and rook_q["type"] == "R" and rook_q["owner"] == owner and not rook_q["moved"]:
		if b[y][1] == null and b[y][2] == null and b[y][3] == null:
			if not _is_square_attacked(b, 3, y, owner) and not _is_square_attacked(b, 2, y, owner):
				moves.append(Vector2i(2, y))


func _is_square_attacked(b: Array, tx: int, ty: int, owner: String) -> bool:
	var attacker: String = "bot" if owner == "player" else "player"

	var pawn_dir: int = 1 if attacker == "player" else -1
	for dx in [-1, 1]:
		var px: int = tx + dx
		var py: int = ty + pawn_dir
		if _in_bounds(px, py) and b[py][px] != null and b[py][px]["owner"] == attacker and b[py][px]["type"] == "P":
			return true

	for off: Vector2i in KNIGHT_OFFSETS:
		var nx: int = tx + off.x
		var ny: int = ty + off.y
		if _in_bounds(nx, ny) and b[ny][nx] != null and b[ny][nx]["owner"] == attacker and b[ny][nx]["type"] == "N":
			return true

	for dir: Vector2i in BISHOP_DIRS:
		var nx: int = tx + dir.x
		var ny: int = ty + dir.y
		while _in_bounds(nx, ny):
			var cell: Variant = b[ny][nx]
			if cell != null:
				if cell["owner"] == attacker and (cell["type"] == "B" or cell["type"] == "Q"):
					return true
				break
			nx += dir.x
			ny += dir.y

	for dir: Vector2i in ROOK_DIRS:
		var nx: int = tx + dir.x
		var ny: int = ty + dir.y
		while _in_bounds(nx, ny):
			var cell: Variant = b[ny][nx]
			if cell != null:
				if cell["owner"] == attacker and (cell["type"] == "R" or cell["type"] == "Q"):
					return true
				break
			nx += dir.x
			ny += dir.y

	for off: Vector2i in KING_OFFSETS:
		var nx: int = tx + off.x
		var ny: int = ty + off.y
		if _in_bounds(nx, ny) and b[ny][nx] != null and b[ny][nx]["owner"] == attacker and b[ny][nx]["type"] == "K":
			return true

	return false


func _find_king(b: Array, owner: String) -> Vector2i:
	for y in range(SIZE):
		for x in range(SIZE):
			var cell: Variant = b[y][x]
			if cell != null and cell["owner"] == owner and cell["type"] == "K":
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _is_in_check(b: Array, owner: String) -> bool:
	var k: Vector2i = _find_king(b, owner)
	if k.x == -1:
		return false
	return _is_square_attacked(b, k.x, k.y, owner)


func _clone_board(b: Array) -> Array:
	var copy: Array = []
	for row: Array in b:
		var new_row: Array = []
		for cell: Variant in row:
			new_row.append(null if cell == null else {"type": cell["type"], "owner": cell["owner"], "moved": cell["moved"]})
		copy.append(new_row)
	return copy


func _apply_move(b: Array, from: Vector2i, to: Vector2i) -> void:
	var piece: Dictionary = b[from.y][from.x]
	b[from.y][from.x] = null

	if piece["type"] == "K" and abs(to.x - from.x) == 2:
		var rook_from_x: int = 7 if to.x > from.x else 0
		var rook_to_x: int = 5 if to.x > from.x else 3
		var rook: Dictionary = b[from.y][rook_from_x]
		b[from.y][rook_from_x] = null
		rook["moved"] = true
		b[from.y][rook_to_x] = rook

	piece["moved"] = true
	b[to.y][to.x] = piece

	if piece["type"] == "P" and (to.y == 0 or to.y == SIZE - 1):
		piece["type"] = "Q"


func _legal_moves_for(b: Array, x: int, y: int) -> Array:
	var piece: Variant = b[y][x]
	if piece == null:
		return []
	var owner: String = piece["owner"]
	var legal: Array = []
	for to: Vector2i in _pseudo_moves(b, x, y):
		var nb: Array = _clone_board(b)
		_apply_move(nb, Vector2i(x, y), to)
		if not _is_in_check(nb, owner):
			legal.append(to)
	return legal


func _all_legal_moves(b: Array, owner: String) -> Array:
	var moves: Array = []
	for y in range(SIZE):
		for x in range(SIZE):
			var piece: Variant = b[y][x]
			if piece != null and piece["owner"] == owner:
				for to: Vector2i in _legal_moves_for(b, x, y):
					moves.append({"from": Vector2i(x, y), "to": to})
	return moves


func _game_status(b: Array, owner: String) -> String:
	if not _all_legal_moves(b, owner).is_empty():
		return "ongoing"
	return "checkmate" if _is_in_check(b, owner) else "stalemate"


# --- UI ---

func _redraw_all() -> void:
	for y in range(SIZE):
		for x in range(SIZE):
			_style_square(x, y)


func _style_square(x: int, y: int) -> void:
	var cell: Button = cell_buttons[y][x]
	var light: bool = (x + y) % 2 == 0
	var base_color: Color = UIKit.COLOR_BG_LIGHT if light else UIKit.COLOR_PANEL

	var is_selected: bool = selected == Vector2i(x, y)
	var is_target: bool = legal_targets.has(Vector2i(x, y))

	var border: Color = Color(0, 0, 0, 0)
	var bw := 0
	if is_selected:
		border = UIKit.COLOR_ACCENT_3
		bw = 3
	elif is_target:
		border = UIKit.COLOR_ACCENT_2
		bw = 3

	var sb: StyleBoxFlat = UIKit.stylebox(base_color, border, 4, bw)
	cell.add_theme_stylebox_override("normal", sb)
	cell.add_theme_stylebox_override("hover", sb)
	cell.add_theme_stylebox_override("disabled", sb)

	var piece: Variant = board[y][x]
	if piece == null:
		cell.text = "·" if is_target else ""
		cell.add_theme_color_override("font_color", UIKit.COLOR_TEXT_DIM)
		cell.add_theme_color_override("font_disabled_color", UIKit.COLOR_TEXT_DIM)
	else:
		cell.text = PIECE_GLYPHS[piece["type"]]
		var color: Color = UIKit.COLOR_ACCENT if piece["owner"] == "player" else UIKit.COLOR_ACCENT_2
		cell.add_theme_color_override("font_color", color)
		cell.add_theme_color_override("font_disabled_color", color)


func _on_cell_pressed(x: int, y: int) -> void:
	if game_over:
		return
	if mode == "pve" and current_turn != "player":
		return

	var owner: String = current_turn
	var piece: Variant = board[y][x]

	if selected == Vector2i(-1, -1):
		if piece != null and piece["owner"] == owner:
			selected = Vector2i(x, y)
			legal_targets = _legal_moves_for(board, x, y)
			_redraw_all()
		return

	if piece != null and piece["owner"] == owner:
		selected = Vector2i(x, y)
		legal_targets = _legal_moves_for(board, x, y)
		_redraw_all()
		return

	var target := Vector2i(x, y)
	if not legal_targets.has(target):
		selected = Vector2i(-1, -1)
		legal_targets = []
		_redraw_all()
		return

	_apply_move(board, selected, target)
	selected = Vector2i(-1, -1)
	legal_targets = []
	_redraw_all()
	_advance_turn(owner)


func _advance_turn(mover: String) -> void:
	var next_owner: String = "bot" if mover == "player" else "player"
	var status: String = _game_status(board, next_owner)

	if status == "checkmate":
		_end_game(mover, false)
		return
	if status == "stalemate":
		_end_game("", true)
		return

	current_turn = next_owner
	_update_turn_status()

	if mode == "pve" and current_turn == "bot":
		await get_tree().create_timer(0.3).timeout
		_bot_move()


func _turn_label(owner: String) -> String:
	if mode == "pve":
		return "Tú" if owner == "player" else "La máquina"
	return "Jugador 1 (rosa)" if owner == "player" else "Jugador 2 (teal)"


func _update_turn_status() -> void:
	var check_suffix: String = " · ¡Jaque!" if _is_in_check(board, current_turn) else ""
	if mode == "pve":
		if current_turn == "player":
			status_label.text = "Tu turno" + check_suffix
			status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT)
		else:
			status_label.text = "Turno de la máquina..." + check_suffix
			status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT_2)
	else:
		status_label.text = ("Turno: %s" % _turn_label(current_turn)) + check_suffix
		status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT if current_turn == "player" else UIKit.COLOR_ACCENT_2)


func _end_game(winner_owner: String, is_stalemate: bool) -> void:
	game_over = true
	if is_stalemate:
		status_label.text = "Tablas por ahogado (sin movimientos legales)"
		status_label.add_theme_color_override("font_color", UIKit.COLOR_TEXT_DIM)
		return

	if mode == "pve":
		if winner_owner == "player":
			status_label.text = "¡Jaque mate! Ganaste"
			status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT_3)
			_record_result("wins")
		else:
			status_label.text = "Jaque mate. Ganó la máquina"
			status_label.add_theme_color_override("font_color", UIKit.COLOR_DANGER)
			_record_result("losses")
	else:
		status_label.text = "¡Jaque mate! Ganó %s" % _turn_label(winner_owner)
		status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT_3)


func _record_result(key: String) -> void:
	if key.begins_with("win") or key.begins_with("completed"):
		AudioManager.play_win()
	elif key.begins_with("loss") or key.begins_with("fail"):
		AudioManager.play_lose()
	var stats: Dictionary = SaveManager.get_game_data(GAME_ID)
	stats[key] = stats.get(key, 0) + 1
	SaveManager.set_game_data(GAME_ID, stats)


# --- IA (minimax con poda alfa-beta) ---

func _piece_square_bonus(piece_type: String, x: int, y: int, owner: String) -> float:
	# Las tablas están escritas desde el lado del jugador (fila 0 = el
	# extremo al que avanzan sus peones). Antes esto estaba al revés para
	# ambos bandos: los peones "valían" más sin moverse y la IA evitaba
	# avanzarlos.
	var row: int = y if owner == "player" else 7 - y
	match piece_type:
		"P": return PAWN_TABLE[row][x]
		"N": return KNIGHT_TABLE[row][x]
		_: return 0.0


func _evaluate_board(b: Array) -> float:
	var score := 0.0
	for y in range(SIZE):
		for x in range(SIZE):
			var cell: Variant = b[y][x]
			if cell == null:
				continue
			var value: float = PIECE_VALUES[cell["type"]] + _piece_square_bonus(cell["type"], x, y, cell["owner"])
			score += value if cell["owner"] == "bot" else -value
	return score


func _order_moves(b: Array, moves: Array) -> Array:
	moves.sort_custom(func(m1: Dictionary, m2: Dictionary) -> bool:
		var cap1: bool = b[m1["to"].y][m1["to"].x] != null
		var cap2: bool = b[m2["to"].y][m2["to"].x] != null
		return cap1 and not cap2
	)
	return moves


func _minimax_chess(b: Array, depth: int, alpha: float, beta: float, owner: String) -> float:
	if depth == 0:
		return _evaluate_board(b)

	var moves: Array = _order_moves(b, _all_legal_moves(b, owner))
	if moves.is_empty():
		if _is_in_check(b, owner):
			return -100000.0 if owner == "bot" else 100000.0
		return 0.0

	if owner == "bot":
		var best := -INF
		for m: Dictionary in moves:
			var nb: Array = _clone_board(b)
			_apply_move(nb, m["from"], m["to"])
			best = max(best, _minimax_chess(nb, depth - 1, alpha, beta, "player"))
			alpha = max(alpha, best)
			if beta <= alpha:
				break
		return best
	else:
		var best := INF
		for m: Dictionary in moves:
			var nb: Array = _clone_board(b)
			_apply_move(nb, m["from"], m["to"])
			best = min(best, _minimax_chess(nb, depth - 1, alpha, beta, "bot"))
			beta = min(beta, best)
			if beta <= alpha:
				break
		return best


func _bot_move() -> void:
	if game_over:
		return
	if difficulty == "hard":
		status_label.text = "La máquina está pensando..."
		await get_tree().process_frame
		await get_tree().process_frame
		if game_over:
			return
		var best: Dictionary = _engine_best_move()
		if best.is_empty():
			return
		_apply_move(board, best["from"], best["to"])
		_redraw_all()
		_advance_turn("bot")
		return

	var depth: int = 2
	match difficulty:
		"easy": depth = 1
		"medium": depth = 2
		_: depth = 3

	var moves: Array = _order_moves(board, _all_legal_moves(board, "bot"))
	if moves.is_empty():
		return

	var candidates: Array = []
	var best_score := -INF
	for m: Dictionary in moves:
		var nb: Array = _clone_board(board)
		_apply_move(nb, m["from"], m["to"])
		var score: float = _minimax_chess(nb, depth - 1, -INF, INF, "player")
		if difficulty == "easy":
			score += randf_range(-80.0, 80.0)
		if score > best_score:
			best_score = score
			candidates = [m]
		elif score == best_score:
			candidates.append(m)

	var chosen: Dictionary = candidates[randi() % candidates.size()]
	_apply_move(board, chosen["from"], chosen["to"])
	_redraw_all()
	_advance_turn("bot")


# --- Motor de IA para Difícil ---------------------------------------------
# Tablero compacto de 64 enteros (índice = y * 8 + x): 0 vacío; pieza de la
# máquina positiva y del jugador negativa (1 peón, 2 caballo, 3 alfil,
# 4 torre, 5 dama, 6 rey). La máquina avanza hacia y creciente. Se
# hace/deshace sobre el mismo arreglo en vez de clonar diccionarios.
#
# Búsqueda: profundización iterativa con alfa-beta hasta agotar el tiempo,
# quiescencia de capturas (no se detiene a media secuencia de cambios, que
# era lo que hacía que la IA "ganara" un peón y perdiera la dama),
# ordenamiento MVV-LVA y evaluación con tablas de posición para todas las
# piezas y rey de medio juego/final.
#
# Jugada = entero: desde | hasta << 6 | banderas << 12 (4096 = corona a
# dama, 8192 = enroque).

const E_VALUES := [0, 100, 320, 330, 500, 900, 20000]
const E_MATE := 1000000
const E_TIME_MS := 1200
const E_MAX_DEPTH := 12
const E_KNIGHT := [Vector2i(1, 2), Vector2i(2, 1), Vector2i(2, -1), Vector2i(1, -2), Vector2i(-1, -2), Vector2i(-2, -1), Vector2i(-2, 1), Vector2i(-1, 2)]
const E_KING := [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const E_DIAG := [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
const E_ORTHO := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
# Tablas desde el lado del jugador (fila 0 = extremo al que avanza).
const E_PST := {
	1: [0, 0, 0, 0, 0, 0, 0, 0, 50, 50, 50, 50, 50, 50, 50, 50, 10, 10, 20, 30, 30, 20, 10, 10, 5, 5, 10, 25, 25, 10, 5, 5, 0, 0, 0, 20, 20, 0, 0, 0, 5, -5, -10, 0, 0, -10, -5, 5, 5, 10, 10, -20, -20, 10, 10, 5, 0, 0, 0, 0, 0, 0, 0, 0],
	2: [-50, -40, -30, -30, -30, -30, -40, -50, -40, -20, 0, 0, 0, 0, -20, -40, -30, 0, 10, 15, 15, 10, 0, -30, -30, 5, 15, 20, 20, 15, 5, -30, -30, 0, 15, 20, 20, 15, 0, -30, -30, 5, 10, 15, 15, 10, 5, -30, -40, -20, 0, 5, 5, 0, -20, -40, -50, -40, -30, -30, -30, -30, -40, -50],
	3: [-20, -10, -10, -10, -10, -10, -10, -20, -10, 0, 0, 0, 0, 0, 0, -10, -10, 0, 5, 10, 10, 5, 0, -10, -10, 5, 5, 10, 10, 5, 5, -10, -10, 0, 10, 10, 10, 10, 0, -10, -10, 10, 10, 10, 10, 10, 10, -10, -10, 5, 0, 0, 0, 0, 5, -10, -20, -10, -10, -10, -10, -10, -10, -20],
	4: [0, 0, 0, 0, 0, 0, 0, 0, 5, 10, 10, 10, 10, 10, 10, 5, -5, 0, 0, 0, 0, 0, 0, -5, -5, 0, 0, 0, 0, 0, 0, -5, -5, 0, 0, 0, 0, 0, 0, -5, -5, 0, 0, 0, 0, 0, 0, -5, -5, 0, 0, 0, 0, 0, 0, -5, 0, 0, 0, 5, 5, 0, 0, 0],
	5: [-20, -10, -10, -5, -5, -10, -10, -20, -10, 0, 0, 0, 0, 0, 0, -10, -10, 0, 5, 5, 5, 5, 0, -10, -5, 0, 5, 5, 5, 5, 0, -5, 0, 0, 5, 5, 5, 5, 0, -5, -10, 5, 5, 5, 5, 5, 0, -10, -10, 0, 5, 0, 0, 0, 0, -10, -20, -10, -10, -5, -5, -10, -10, -20],
	6: [-30, -40, -40, -50, -50, -40, -40, -30, -30, -40, -40, -50, -50, -40, -40, -30, -30, -40, -40, -50, -50, -40, -40, -30, -30, -40, -40, -50, -50, -40, -40, -30, -20, -30, -30, -40, -40, -30, -30, -20, -10, -20, -20, -20, -20, -20, -20, -10, 20, 20, 0, 0, 0, 0, 20, 20, 20, 30, 10, 0, 0, 10, 30, 20],
}
const E_KING_END := [-50, -40, -30, -20, -20, -30, -40, -50, -30, -20, -10, 0, 0, -10, -20, -30, -30, -10, 20, 30, 30, 20, -10, -30, -30, -10, 30, 40, 40, 30, -10, -30, -30, -10, 30, 40, 40, 30, -10, -30, -30, -10, 20, 30, 30, 20, -10, -30, -30, -30, 0, 0, 0, 0, -30, -30, -50, -30, -30, -30, -30, -30, -30, -50]
const E_TYPE_CODE := {"P": 1, "N": 2, "B": 3, "R": 4, "Q": 5, "K": 6}

var _e_rights: int = 0  # 1 máquina corto, 2 máquina largo, 4 jugador corto, 8 jugador largo
var _e_king: Array = [0, 0]  # [casilla rey máquina, casilla rey jugador]
var _e_deadline: int = 0
var _e_nodes: int = 0
var _e_aborted: bool = false


func _engine_best_move() -> Dictionary:
	var b := PackedInt32Array()
	b.resize(64)
	for y in range(SIZE):
		for x in range(SIZE):
			var c: Variant = board[y][x]
			if c == null:
				continue
			var v: int = E_TYPE_CODE[c["type"]]
			b[y * 8 + x] = v if c["owner"] == "bot" else -v
			if c["type"] == "K":
				_e_king[0 if c["owner"] == "bot" else 1] = y * 8 + x
	_e_rights = 0
	for info: Array in [["bot", 0, 1, 2], ["player", 7, 4, 8]]:
		var k: Variant = board[info[1]][4]
		if k == null or k["type"] != "K" or k["owner"] != info[0] or k["moved"]:
			continue
		var rk: Variant = board[info[1]][7]
		if rk != null and rk["type"] == "R" and rk["owner"] == info[0] and not rk["moved"]:
			_e_rights |= info[2]
		var rq: Variant = board[info[1]][0]
		if rq != null and rq["type"] == "R" and rq["owner"] == info[0] and not rq["moved"]:
			_e_rights |= info[3]

	var moves: Array = _e_legal(b, 1)
	if moves.is_empty():
		return {}
	moves.shuffle()
	_e_order(b, moves)
	_e_deadline = Time.get_ticks_msec() + E_TIME_MS
	_e_aborted = false
	_e_nodes = 0
	var best: int = moves[0]
	for depth in range(1, E_MAX_DEPTH + 1):
		var alpha: float = -INF
		var depth_best: int = moves[0]
		var scores: Dictionary = {}
		for m: int in moves:
			var undo: Array = _e_make(b, m)
			var sc: float = -_e_search(b, depth - 1, -INF, -alpha, -1, 1)
			_e_unmake(b, m, undo)
			if _e_aborted:
				break
			scores[m] = sc
			if sc > alpha:
				alpha = sc
				depth_best = m
		if _e_aborted:
			break
		best = depth_best
		if alpha >= E_MATE - 100:
			break
		moves.sort_custom(func(a: int, c: int) -> bool: return scores.get(a, -INF) > scores.get(c, -INF))
	return {"from": Vector2i((best & 63) % 8, (best & 63) / 8), "to": Vector2i(((best >> 6) & 63) % 8, ((best >> 6) & 63) / 8)}


func _e_search(b: PackedInt32Array, depth: int, alpha: float, beta: float, side: int, ply: int) -> float:
	_e_nodes += 1
	if (_e_nodes & 511) == 0 and Time.get_ticks_msec() > _e_deadline:
		_e_aborted = true
	if _e_aborted:
		return 0.0
	if depth <= 0:
		return _e_quiesce(b, alpha, beta, side, 0)
	var moves: Array = _e_legal(b, side)
	if moves.is_empty():
		return -(E_MATE - ply) if _e_attacked(b, _e_king[0 if side == 1 else 1], -side) else 0.0
	_e_order(b, moves)
	var best: float = -INF
	for m: int in moves:
		var undo: Array = _e_make(b, m)
		var sc: float = -_e_search(b, depth - 1, -beta, -alpha, -side, ply + 1)
		_e_unmake(b, m, undo)
		if _e_aborted:
			return 0.0
		if sc > best:
			best = sc
		if sc > alpha:
			alpha = sc
		if alpha >= beta:
			break
	return best


## Solo capturas, hasta que la posición quede "quieta".
func _e_quiesce(b: PackedInt32Array, alpha: float, beta: float, side: int, qply: int) -> float:
	var stand: float = side * _e_eval(b)
	if stand >= beta or qply >= 6:
		return stand
	alpha = maxf(alpha, stand)
	var caps: Array = _e_legal(b, side, true)
	_e_order(b, caps)
	for m: int in caps:
		var undo: Array = _e_make(b, m)
		var sc: float = -_e_quiesce(b, -beta, -alpha, -side, qply + 1)
		_e_unmake(b, m, undo)
		if sc >= beta:
			return sc
		alpha = maxf(alpha, sc)
	return alpha


## MVV-LVA: primero capturar la pieza más valiosa con la menos valiosa.
func _e_order(b: PackedInt32Array, moves: Array) -> void:
	moves.sort_custom(func(m1: int, m2: int) -> bool:
		return _e_move_key(b, m1) > _e_move_key(b, m2))


func _e_move_key(b: PackedInt32Array, m: int) -> int:
	var cap: int = absi(b[(m >> 6) & 63])
	var key: int = 0
	if cap > 0:
		key = 1000 + E_VALUES[cap] - absi(b[m & 63]) * 10
	if (m >> 12) & 1:
		key += 800
	return key


func _e_eval(b: PackedInt32Array) -> float:
	var score := 0.0
	var non_pawn := 0
	var queens := 0
	for sq in range(64):
		var p: int = absi(b[sq])
		if p >= 2 and p <= 5:
			non_pawn += E_VALUES[p]
		if p == 5:
			queens += 1
	var endgame: bool = queens == 0 or non_pawn <= 2600
	for sq in range(64):
		var v: int = b[sq]
		if v == 0:
			continue
		var p: int = absi(v)
		var x: int = sq % 8
		var y: int = sq / 8
		var idx: int = (y if v < 0 else 7 - y) * 8 + x
		var pst: int = E_KING_END[idx] if (p == 6 and endgame) else E_PST[p][idx]
		var s: float = E_VALUES[p] + pst
		score += s if v > 0 else -s
	return score


func _e_legal(b: PackedInt32Array, side: int, captures_only: bool = false) -> Array:
	var out: Array = []
	for m: int in _e_pseudo(b, side, captures_only):
		var undo: Array = _e_make(b, m)
		if not _e_attacked(b, _e_king[0 if side == 1 else 1], -side):
			out.append(m)
		_e_unmake(b, m, undo)
	return out


func _e_pseudo(b: PackedInt32Array, side: int, captures_only: bool) -> Array:
	var moves: Array = []
	for sq in range(64):
		var v: int = b[sq]
		if v == 0 or signi(v) != side:
			continue
		var x: int = sq % 8
		var y: int = sq / 8
		match absi(v):
			1:
				var ny: int = y + side
				var promo_row: int = 7 if side == 1 else 0
				if ny >= 0 and ny < 8:
					var fwd: int = ny * 8 + x
					if b[fwd] == 0 and (not captures_only or ny == promo_row):
						moves.append(sq | fwd << 6 | (4096 if ny == promo_row else 0))
						var start_row: int = 1 if side == 1 else 6
						if y == start_row and not captures_only and b[(y + 2 * side) * 8 + x] == 0:
							moves.append(sq | ((y + 2 * side) * 8 + x) << 6)
					for dx in [-1, 1]:
						var nx: int = x + dx
						if nx >= 0 and nx < 8:
							var t: int = ny * 8 + nx
							if b[t] != 0 and signi(b[t]) != side:
								moves.append(sq | t << 6 | (4096 if ny == promo_row else 0))
			2:
				_e_steps(b, sq, side, E_KNIGHT, captures_only, moves)
			3:
				_e_slides(b, sq, side, E_DIAG, captures_only, moves)
			4:
				_e_slides(b, sq, side, E_ORTHO, captures_only, moves)
			5:
				_e_slides(b, sq, side, E_DIAG, captures_only, moves)
				_e_slides(b, sq, side, E_ORTHO, captures_only, moves)
			6:
				_e_steps(b, sq, side, E_KING, captures_only, moves)
				if not captures_only:
					_e_castles(b, sq, side, moves)
	return moves


func _e_steps(b: PackedInt32Array, sq: int, side: int, offs: Array, captures_only: bool, moves: Array) -> void:
	var x: int = sq % 8
	var y: int = sq / 8
	for o: Vector2i in offs:
		var nx: int = x + o.x
		var ny: int = y + o.y
		if nx < 0 or nx > 7 or ny < 0 or ny > 7:
			continue
		var t: int = ny * 8 + nx
		if b[t] == 0:
			if not captures_only:
				moves.append(sq | t << 6)
		elif signi(b[t]) != side:
			moves.append(sq | t << 6)


func _e_slides(b: PackedInt32Array, sq: int, side: int, dirs: Array, captures_only: bool, moves: Array) -> void:
	var x: int = sq % 8
	var y: int = sq / 8
	for d: Vector2i in dirs:
		var nx: int = x + d.x
		var ny: int = y + d.y
		while nx >= 0 and nx < 8 and ny >= 0 and ny < 8:
			var t: int = ny * 8 + nx
			if b[t] == 0:
				if not captures_only:
					moves.append(sq | t << 6)
			else:
				if signi(b[t]) != side:
					moves.append(sq | t << 6)
				break
			nx += d.x
			ny += d.y


func _e_castles(b: PackedInt32Array, sq: int, side: int, moves: Array) -> void:
	var row: int = 0 if side == 1 else 7
	if sq != row * 8 + 4 or _e_attacked(b, sq, -side):
		return
	var k_bit: int = 1 if side == 1 else 4
	var q_bit: int = 2 if side == 1 else 8
	if (_e_rights & k_bit) and b[row * 8 + 5] == 0 and b[row * 8 + 6] == 0 \
			and not _e_attacked(b, row * 8 + 5, -side) and not _e_attacked(b, row * 8 + 6, -side):
		moves.append(sq | (row * 8 + 6) << 6 | 8192)
	if (_e_rights & q_bit) and b[row * 8 + 1] == 0 and b[row * 8 + 2] == 0 and b[row * 8 + 3] == 0 \
			and not _e_attacked(b, row * 8 + 3, -side) and not _e_attacked(b, row * 8 + 2, -side):
		moves.append(sq | (row * 8 + 2) << 6 | 8192)


## ¿La casilla está atacada por el bando `by`?
func _e_attacked(b: PackedInt32Array, sq: int, by: int) -> bool:
	var x: int = sq % 8
	var y: int = sq / 8
	# Los peones de `by` atacan en diagonal hacia su avance.
	var py: int = y - by
	if py >= 0 and py < 8:
		for dx in [-1, 1]:
			var px: int = x + dx
			if px >= 0 and px < 8 and b[py * 8 + px] == by:
				return true
	for o: Vector2i in E_KNIGHT:
		var nx: int = x + o.x
		var ny: int = y + o.y
		if nx >= 0 and nx < 8 and ny >= 0 and ny < 8 and b[ny * 8 + nx] == 2 * by:
			return true
	for o: Vector2i in E_KING:
		var nx: int = x + o.x
		var ny: int = y + o.y
		if nx >= 0 and nx < 8 and ny >= 0 and ny < 8 and b[ny * 8 + nx] == 6 * by:
			return true
	for d: Vector2i in E_DIAG:
		var nx: int = x + d.x
		var ny: int = y + d.y
		while nx >= 0 and nx < 8 and ny >= 0 and ny < 8:
			var v: int = b[ny * 8 + nx]
			if v != 0:
				if v == 3 * by or v == 5 * by:
					return true
				break
			nx += d.x
			ny += d.y
	for d: Vector2i in E_ORTHO:
		var nx: int = x + d.x
		var ny: int = y + d.y
		while nx >= 0 and nx < 8 and ny >= 0 and ny < 8:
			var v: int = b[ny * 8 + nx]
			if v != 0:
				if v == 4 * by or v == 5 * by:
					return true
				break
			nx += d.x
			ny += d.y
	return false


func _e_make(b: PackedInt32Array, m: int) -> Array:
	var from: int = m & 63
	var to: int = (m >> 6) & 63
	var v: int = b[from]
	var side: int = signi(v)
	var undo: Array = [b[to], _e_rights, _e_king[0], _e_king[1]]
	b[to] = v
	b[from] = 0
	if (m >> 12) & 1:
		b[to] = 5 * side
	if (m >> 13) & 1:
		var row: int = from / 8
		if to % 8 == 6:
			b[row * 8 + 5] = b[row * 8 + 7]
			b[row * 8 + 7] = 0
		else:
			b[row * 8 + 3] = b[row * 8 + 0]
			b[row * 8 + 0] = 0
	if absi(v) == 6:
		_e_king[0 if side == 1 else 1] = to
		_e_rights &= ~(3 if side == 1 else 12)
	# Mover o capturar una torre en su esquina quita ese enroque.
	for info: Array in [[7, 1], [0, 2], [63, 4], [56, 8]]:
		if from == info[0] or to == info[0]:
			_e_rights &= ~int(info[1])
	return undo


func _e_unmake(b: PackedInt32Array, m: int, undo: Array) -> void:
	var from: int = m & 63
	var to: int = (m >> 6) & 63
	var v: int = b[to]
	if (m >> 12) & 1:
		v = signi(v)  # vuelve a ser peón
	b[from] = v
	b[to] = undo[0]
	if (m >> 13) & 1:
		var row: int = from / 8
		if to % 8 == 6:
			b[row * 8 + 7] = b[row * 8 + 5]
			b[row * 8 + 5] = 0
		else:
			b[row * 8 + 0] = b[row * 8 + 3]
			b[row * 8 + 3] = 0
	_e_rights = undo[1]
	_e_king[0] = undo[2]
	_e_king[1] = undo[3]
