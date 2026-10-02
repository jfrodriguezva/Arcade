extends Control
## Damas clásicas contra la máquina, con "bobas" (soplar): si en tu turno
## podías comer y no comiste (con ninguna ficha), pierdes la ficha que
## podía comer. Si empiezas una captura y puedes encadenar otra con la
## misma ficha, puedes seguir de inmediato. Empate si la misma posición se
## repite 3 veces o si pasan 40 jugadas por bando sin comer ni mover peones.

const GAME_ID := "checkers"
const SIZE := 8
const DIRS := [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]

const HELP_TEXT := "Juegas con las fichas rosas (abajo) contra la máquina (fichas teal, arriba).

- Toca una de tus fichas para seleccionarla.
- Toca una casilla oscura vacía en diagonal para moverte ahí.
- Si hay una ficha rival justo en diagonal y la casilla siguiente está vacía, salta sobre ella para comerla.
- Si después de comer puedes volver a comer con la MISMA ficha, puedes seguir saltando; toca cualquier otra casilla para terminar tu turno.
- Si llegas al otro extremo del tablero, tu ficha se corona Reina (♛) y se mueve en diagonal hacia ambos lados.
- BOBAS: si en tu turno podías comer y no comiste con ninguna ficha, te \"soplan\": pierdes la ficha que podía comer (si moviste esa misma ficha, se pierde donde quedó). Lo mismo aplica a la máquina.

Gana quien deje al rival sin fichas o sin movimientos posibles. Es empate si la misma posición se repite 3 veces, o si pasan 40 jugadas de cada lado sin comer ni mover un peón."

var board: Array = [] # board[y][x] = null o {"owner":"player"/"bot", "king":bool}
var cell_buttons: Array = []
var piece_views: Array = []
var selected: Vector2i = Vector2i(-1, -1)
var current_turn: String = "player"
var game_over: bool = false
var mode: String = "pve"
var difficulty: String = "medium"
## true mientras el jugador está a media cadena de capturas (ver
## _on_cell_pressed).
var chain_active: bool = false
## Se incrementa en cada partida nueva; el turno de la máquina (que espera
## con timers) lo revisa para no jugar sobre una partida que ya se reinició.
var game_session: int = 0
## Bobas: fichas que podían comer al empezar el turno, y si ya comió.
var turn_capturers: Array = []
var turn_made_capture: bool = false
var turn_from: Vector2i = Vector2i(-1, -1)
var turn_to: Vector2i = Vector2i(-1, -1)
var turn_moved_man: bool = false
## Empates: cuántas veces se ha visto cada posición (con el turno), y
## medias jugadas seguidas sin comer ni mover un peón.
var position_history: Dictionary = {}
var quiet_plies: int = 0
const DRAW_REPETITIONS := 3
const DRAW_QUIET_PLIES := 80

var status_label: Label


func _ready() -> void:
	_build_ui()
	UIKit.show_setup_overlay(self, "Damas", true, true, _on_setup_confirmed)


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
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	UIKit.build_toolbar(vbox, self, "Damas", HELP_TEXT)

	status_label = UIKit.title_label("", 22, UIKit.COLOR_TEXT)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(560, 0)
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
			if (x + y) % 2 == 1:
				cell.pressed.connect(_on_cell_pressed.bind(x, y))
			else:
				cell.disabled = true
				cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			grid.add_child(cell)
			row.append(cell)

			var piece := GamePiece.new()
			piece.set_anchors_preset(Control.PRESET_FULL_RECT)
			cell.add_child(piece)
			piece_row.append(piece)
		cell_buttons.append(row)
		piece_views.append(piece_row)

	var restart_btn := Button.new()
	restart_btn.text = "🔁  Nueva partida / Modo"
	restart_btn.custom_minimum_size = Vector2(220, 48)
	UIKit.style_button(restart_btn, UIKit.COLOR_ACCENT_3)
	restart_btn.pressed.connect(func() -> void: UIKit.show_setup_overlay(self, "Damas", true, true, _on_setup_confirmed))
	vbox.add_child(restart_btn)


func _new_game() -> void:
	board = []
	for y in range(SIZE):
		var row: Array = []
		for x in range(SIZE):
			row.append(null)
		board.append(row)

	for y in range(3):
		for x in range(SIZE):
			if (x + y) % 2 == 1:
				board[y][x] = {"owner": "bot", "king": false}
	for y in range(5, SIZE):
		for x in range(SIZE):
			if (x + y) % 2 == 1:
				board[y][x] = {"owner": "player", "king": false}

	selected = Vector2i(-1, -1)
	chain_active = false
	game_session += 1
	current_turn = "player"
	game_over = false
	position_history.clear()
	quiet_plies = 0
	_begin_turn_tracking("player")
	_update_turn_status()
	_redraw_all()


# --- Bobas y empates --------------------------------------------------------
func _begin_turn_tracking(owner: String) -> void:
	turn_capturers.clear()
	turn_made_capture = false
	turn_from = Vector2i(-1, -1)
	turn_to = Vector2i(-1, -1)
	for y in range(SIZE):
		for x in range(SIZE):
			var p: Variant = board[y][x]
			if p != null and p["owner"] == owner and _has_capture_from(x, y, owner):
				turn_capturers.append(Vector2i(x, y))
	var key: String = _position_key(owner)
	position_history[key] = position_history.get(key, 0) + 1


func _position_key(side_to_move: String) -> String:
	return str(Array(_board_to_packed())) + side_to_move


## Al terminar el turno de `owner`: si podía comer y no comió, lo soplan.
## Devuelve true si hubo boba.
func _apply_huff(owner: String) -> bool:
	if turn_made_capture or turn_capturers.is_empty():
		return false
	var victim: Vector2i = turn_to if turn_capturers.has(turn_from) else turn_capturers[0]
	var p: Variant = board[victim.y][victim.x]
	if p == null or p["owner"] != owner:
		return false
	board[victim.y][victim.x] = null
	UIKit.pulse(cell_buttons[victim.y][victim.x])
	AudioManager.play_alert()
	var who: String = "Te soplaron" if (mode == "pve" and owner == "player") else ("Soplaste a la máquina" if mode == "pve" else "¡Soplada!")
	status_label.text = "%s: había que comer. Se pierde la ficha en %s" % [who, _square_name(victim)]
	status_label.add_theme_color_override("font_color", UIKit.COLOR_DANGER)
	return true


func _square_name(c: Vector2i) -> String:
	return "%s%d" % ["abcdefgh"[c.x], SIZE - c.y]


## Actualiza el contador de jugadas "tranquilas" después de un turno.
func _track_progress(moved_piece_was_man: bool) -> void:
	if turn_made_capture or moved_piece_was_man:
		quiet_plies = 0
	else:
		quiet_plies += 1


## Empate por repetición (3 veces) o por 40 jugadas por bando sin comer
## ni mover peones. Se revisa con el turno ya cambiado.
func _check_draw() -> bool:
	var reason := ""
	if position_history.get(_position_key(current_turn), 0) >= DRAW_REPETITIONS:
		reason = "la misma posición se repitió 3 veces"
	elif quiet_plies >= DRAW_QUIET_PLIES:
		reason = "40 jugadas por bando sin comer ni mover peones"
	if reason == "":
		return false
	game_over = true
	status_label.text = "Empate: %s" % reason
	status_label.add_theme_color_override("font_color", UIKit.COLOR_TEXT_DIM)
	if mode == "pve":
		var stats: Dictionary = SaveManager.get_game_data(GAME_ID)
		stats["draws"] = stats.get("draws", 0) + 1
		SaveManager.set_game_data(GAME_ID, stats)
	return true


func _update_turn_status(keep_message: bool = false) -> void:
	var prefix: String = (status_label.text + "
") if keep_message else ""
	_set_turn_text()
	if keep_message:
		status_label.text = prefix + status_label.text
		status_label.add_theme_color_override("font_color", UIKit.COLOR_DANGER)


func _set_turn_text() -> void:
	if mode == "pve":
		if current_turn == "player":
			status_label.text = "Tu turno"
			status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT)
		else:
			status_label.text = "Turno de la máquina..."
			status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT_2)
	else:
		if current_turn == "player":
			status_label.text = "Turno: Jugador 1 (rosa)"
			status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT)
		else:
			status_label.text = "Turno: Jugador 2 (teal)"
			status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT_2)


func _redraw_all() -> void:
	for y in range(SIZE):
		for x in range(SIZE):
			_style_square(x, y)


func _style_square(x: int, y: int) -> void:
	var cell: Button = cell_buttons[y][x]
	var dark: bool = (x + y) % 2 == 1

	if not dark:
		cell.text = ""
		var flat: StyleBoxFlat = UIKit.stylebox(UIKit.COLOR_BG, Color(0, 0, 0, 0), 4)
		cell.add_theme_stylebox_override("normal", flat)
		cell.add_theme_stylebox_override("disabled", flat)
		return

	var piece: Variant = board[y][x]
	var is_selected: bool = selected == Vector2i(x, y)
	var border: Color = UIKit.COLOR_ACCENT_3 if is_selected else Color(0, 0, 0, 0)
	var bw: int = 3 if is_selected else 0
	var sb: StyleBoxFlat = UIKit.stylebox(UIKit.COLOR_PANEL, border, 6, bw)
	cell.add_theme_stylebox_override("normal", sb)
	cell.add_theme_stylebox_override("hover", sb)
	cell.add_theme_stylebox_override("disabled", sb)

	var piece_view: GamePiece = piece_views[y][x]
	if piece == null:
		piece_view.hide_piece()
	else:
		var color: Color = UIKit.COLOR_ACCENT if piece["owner"] == "player" else UIKit.COLOR_ACCENT_2
		piece_view.set_piece(color, piece["king"])


func _direction_ok(owner: String, king: bool, dy: int) -> bool:
	if king:
		return true
	if owner == "player":
		return dy < 0
	return dy > 0


func _try_move(fx: int, fy: int, tx: int, ty: int, owner: String) -> String:
	if tx < 0 or tx >= SIZE or ty < 0 or ty >= SIZE:
		return "invalid"
	if board[ty][tx] != null or (tx + ty) % 2 == 0:
		return "invalid"

	var piece: Variant = board[fy][fx]
	if piece == null or piece["owner"] != owner:
		return "invalid"

	var dx: int = tx - fx
	var dy: int = ty - fy

	if abs(dx) == 1 and abs(dy) == 1:
		if not _direction_ok(owner, piece["king"], dy):
			return "invalid"
		_apply_move(fx, fy, tx, ty)
		return "move"

	if abs(dx) == 2 and abs(dy) == 2:
		if not _direction_ok(owner, piece["king"], dy):
			return "invalid"
		var mx: int = fx + dx / 2
		var my: int = fy + dy / 2
		var mid: Variant = board[my][mx]
		if mid == null or mid["owner"] == owner:
			return "invalid"
		_apply_move(fx, fy, tx, ty)
		board[my][mx] = null
		return "capture"

	return "invalid"


func _apply_move(fx: int, fy: int, tx: int, ty: int) -> void:
	var piece: Dictionary = board[fy][fx]
	board[fy][fx] = null
	if (piece["owner"] == "player" and ty == 0) or (piece["owner"] == "bot" and ty == SIZE - 1):
		piece["king"] = true
	board[ty][tx] = piece


func _has_capture_from(x: int, y: int, owner: String) -> bool:
	var piece: Variant = board[y][x]
	if piece == null:
		return false
	for dir: Vector2i in DIRS:
		if not _direction_ok(owner, piece["king"], dir.y):
			continue
		var mx: int = x + dir.x
		var my: int = y + dir.y
		var tx: int = x + dir.x * 2
		var ty: int = y + dir.y * 2
		if tx < 0 or tx >= SIZE or ty < 0 or ty >= SIZE:
			continue
		if board[ty][tx] != null:
			continue
		if mx < 0 or mx >= SIZE or my < 0 or my >= SIZE:
			continue
		var mid: Variant = board[my][mx]
		if mid != null and mid["owner"] != owner:
			return true
	return false


func _has_any_capture(owner: String) -> bool:
	for y in range(SIZE):
		for x in range(SIZE):
			var piece: Variant = board[y][x]
			if piece != null and piece["owner"] == owner and _has_capture_from(x, y, owner):
				return true
	return false


func _has_any_move(owner: String) -> bool:
	if _has_any_capture(owner):
		return true
	for y in range(SIZE):
		for x in range(SIZE):
			var piece: Variant = board[y][x]
			if piece == null or piece["owner"] != owner:
				continue
			for dir: Vector2i in DIRS:
				if not _direction_ok(owner, piece["king"], dir.y):
					continue
				var tx: int = x + dir.x
				var ty: int = y + dir.y
				if tx >= 0 and tx < SIZE and ty >= 0 and ty < SIZE and board[ty][tx] == null:
					return true
	return false


func _count_pieces(owner: String) -> int:
	var n := 0
	for row: Array in board:
		for cell: Variant in row:
			if cell != null and cell["owner"] == owner:
				n += 1
	return n


func _check_win() -> bool:
	if _count_pieces("bot") == 0 or not _has_any_move("bot"):
		_end_game("player")
		return true
	if _count_pieces("player") == 0 or not _has_any_move("player"):
		_end_game("bot")
		return true
	return false


func _end_game(winner_owner: String) -> void:
	game_over = true
	if mode == "pve":
		if winner_owner == "player":
			status_label.text = "¡Ganaste!"
			status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT_3)
			_record_result(true)
		else:
			status_label.text = "Ganó la máquina"
			status_label.add_theme_color_override("font_color", UIKit.COLOR_DANGER)
			_record_result(false)
	else:
		var winner_label: String = "Jugador 1 (rosa)" if winner_owner == "player" else "Jugador 2 (teal)"
		status_label.text = "¡Ganó %s!" % winner_label
		status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT_3)


func _record_result(won: bool) -> void:
	AudioManager.play_win() if won else AudioManager.play_lose()
	var stats: Dictionary = SaveManager.get_game_data(GAME_ID)
	var key: String = "wins" if won else "losses"
	stats[key] = stats.get(key, 0) + 1
	SaveManager.set_game_data(GAME_ID, stats)


func _on_cell_pressed(x: int, y: int) -> void:
	if game_over:
		return
	if mode == "pve" and current_turn != "player":
		return

	var owner: String = current_turn
	var piece: Variant = board[y][x]

	# A media cadena de capturas solo se puede seguir comiendo con la MISMA
	# ficha; cualquier otro toque termina el turno. Antes, tocar otra ficha
	# propia la seleccionaba y se podía mover también: dos jugadas en un
	# turno, un regalo enorme contra la máquina.
	if chain_active:
		if _try_move(selected.x, selected.y, x, y, owner) == "capture":
			turn_to = Vector2i(x, y)
			if _has_capture_from(x, y, owner):
				selected = Vector2i(x, y)
				_redraw_all()
				return
		chain_active = false
		_end_player_turn(owner)
		return

	if selected == Vector2i(-1, -1):
		if piece != null and piece["owner"] == owner:
			selected = Vector2i(x, y)
			_redraw_all()
		return

	if piece != null and piece["owner"] == owner:
		selected = Vector2i(x, y)
		_redraw_all()
		return

	var was_man: bool = not board[selected.y][selected.x]["king"]
	var from: Vector2i = selected
	var result: String = _try_move(selected.x, selected.y, x, y, owner)
	if result == "invalid":
		selected = Vector2i(-1, -1)
		_redraw_all()
		return
	turn_from = from
	turn_to = Vector2i(x, y)
	turn_moved_man = was_man
	if result == "capture":
		turn_made_capture = true

	if result == "capture" and _has_capture_from(x, y, owner):
		selected = Vector2i(x, y)
		chain_active = true
		status_label.text = "Puedes seguir comiendo con la misma ficha (toca otra casilla para terminar)"
		_redraw_all()
		return

	_end_player_turn(owner)


func _end_player_turn(owner: String) -> void:
	selected = Vector2i(-1, -1)
	var huffed: bool = _apply_huff(owner)
	_track_progress(turn_moved_man)
	_redraw_all()

	if _check_win():
		return

	current_turn = "bot" if owner == "player" else "player"
	_begin_turn_tracking(current_turn)
	if _check_draw():
		return
	_update_turn_status(huffed)

	if mode == "pve" and current_turn == "bot":
		var session: int = game_session
		await get_tree().create_timer(0.5).timeout
		if session == game_session:
			_bot_turn()




## Devuelve {"path": [Vector2i...]} -- la jugada completa, incluida toda
## la cadena de capturas si la hay -- o null si la máquina no tiene jugada.
func _pick_bot_move() -> Variant:
	var b: PackedInt32Array = _board_to_packed()
	var moves: Array = _eng_moves(b, BOT)
	if moves.is_empty():
		return null
	var chosen: Array
	match difficulty:
		"easy":
			chosen = _pick_easy(moves)
		"medium":
			chosen = _eng_search(b, moves, MEDIUM_MAX_DEPTH, MEDIUM_TIME_MS, false)
		_:
			chosen = _eng_search(b, moves, HARD_MAX_DEPTH, HARD_TIME_MS, true)
	var path: Array = []
	for idx: int in chosen[0]:
		path.append(Vector2i(idx % SIZE, idx / SIZE))
	return {"path": path}


## Fácil: come si puede (cualquier captura al azar), si no, mueve al azar.
func _pick_easy(moves: Array) -> Array:
	var captures: Array = moves.filter(func(m: Array) -> bool: return m[1].size() > 0)
	var pool: Array = captures if not captures.is_empty() else moves
	return pool[randi() % pool.size()]


func _bot_turn() -> void:
	var session: int = game_session
	status_label.text = "La máquina está pensando..."
	status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT_2)
	# Dos frames para que el texto se pinte antes de que la búsqueda (que
	# bloquea el hilo hasta ~1 s en Difícil) empiece.
	await get_tree().process_frame
	await get_tree().process_frame
	if session != game_session or game_over:
		return
	var move: Variant = _pick_bot_move()
	if move == null:
		_check_win()
		return

	# Se ejecuta la jugada completa elegida paso a paso, con la MISMA ficha
	# -- antes, tras cada salto se volvía a elegir jugada entre todas las
	# fichas y podía "continuar la cadena" moviendo otra distinta.
	var path: Array = move["path"]
	turn_from = path[0]
	turn_to = path[path.size() - 1]
	turn_moved_man = not board[path[0].y][path[0].x]["king"]
	for i in range(1, path.size()):
		if i > 1:
			await get_tree().create_timer(0.4).timeout
			if session != game_session:
				return
		var a: Vector2i = path[i - 1]
		var c: Vector2i = path[i]
		if _try_move(a.x, a.y, c.x, c.y, "bot") == "capture":
			turn_made_capture = true
		_redraw_all()

	var huffed: bool = _apply_huff("bot")
	_track_progress(turn_moved_man)
	_redraw_all()
	if _check_win():
		return

	current_turn = "player"
	_begin_turn_tracking("player")
	if _check_draw():
		return
	_update_turn_status(huffed)


# --- Motor de IA (Medio/Difícil) ------------------------------------------
# Tablero compacto de 64 enteros (índice = y * 8 + x): 0 vacío, 1 peón de la
# máquina, 2 reina de la máquina, -1 / -2 lo mismo del jugador. La máquina
# avanza hacia y creciente, el jugador hacia y decreciente. Se hace/deshace
# sobre el mismo arreglo en vez de clonar diccionarios en cada nodo, que era
# lo que limitaba la búsqueda anterior a 4 jugadas.
#
# Una jugada es [path: PackedInt32Array, caps: PackedInt32Array]: la
# secuencia de casillas que recorre la ficha y las fichas que come. Las
# capturas múltiples son UNA sola jugada (antes cada salto contaba como
# turno, así que la IA no veía ni sus cadenas ni las tuyas). Como en las
# reglas de este juego comer es opcional, también se generan las jugadas
# simples aunque haya captura disponible.

const BOT := 1
const PLAYER := -1
const WIN_SCORE := 100000.0
const MAN_VALUE := 100.0
const KING_VALUE := 165.0
const MEDIUM_MAX_DEPTH := 3
const MEDIUM_TIME_MS := 250
const HARD_MAX_DEPTH := 14
const HARD_TIME_MS := 1100
const QUIESCENCE_MAX := 8  # capturas extra que se siguen al final de la búsqueda

var _deadline: int = 0
var _aborted: bool = false
var _use_quiescence: bool = true
var _nodes: int = 0


func _board_to_packed() -> PackedInt32Array:
	var b := PackedInt32Array()
	b.resize(SIZE * SIZE)
	for y in range(SIZE):
		for x in range(SIZE):
			var cell: Variant = board[y][x]
			if cell == null:
				continue
			var v: int = 2 if cell["king"] else 1
			b[y * SIZE + x] = v if cell["owner"] == "bot" else -v
	return b


func _eng_moves(b: PackedInt32Array, side: int) -> Array:
	var captures: Array = []
	var simple: Array = []
	for idx in range(SIZE * SIZE):
		var v: int = b[idx]
		if v == 0 or signi(v) != side:
			continue
		var x: int = idx % SIZE
		var y: int = idx / SIZE
		var king: bool = abs(v) == 2
		var jumps: Array = []
		b[idx] = 0  # la ficha "se levanta" mientras explora saltos
		_eng_jumps(b, x, y, v, king, PackedInt32Array([idx]), PackedInt32Array(), jumps)
		b[idx] = v
		captures.append_array(jumps)
		for d: Vector2i in DIRS:
			if not king and d.y != side:
				continue
			var nx: int = x + d.x
			var ny: int = y + d.y
			if nx >= 0 and nx < SIZE and ny >= 0 and ny < SIZE and b[ny * SIZE + nx] == 0:
				simple.append([PackedInt32Array([idx, ny * SIZE + nx]), PackedInt32Array()])
	# Bobas: si había captura y se juega una jugada simple, se pierde la
	# ficha que podía comer (la que se movió, donde quedó; si no, la
	# primera que podía comer). Así la IA sabe que no comer le cuesta.
	if not captures.is_empty():
		var capturers := {}
		for c: Array in captures:
			capturers[c[0][0]] = true
		var first_capturer: int = captures[0][0][0]
		for m: Array in simple:
			var from: int = m[0][0]
			m.append(m[0][1] if capturers.has(from) else first_capturer)
	# Capturas primero y las más largas antes: mejora mucho la poda alfa-beta.
	captures.sort_custom(func(a: Array, c: Array) -> bool: return a[1].size() > c[1].size())
	captures.append_array(simple)
	return captures


## Explora en profundidad todas las cadenas de salto desde (x, y). Solo se
## registran las cadenas completas (no se puede seguir saltando), y una
## ficha que se corona a media cadena termina ahí, como en las damas
## inglesas.
func _eng_jumps(b: PackedInt32Array, x: int, y: int, v: int, king: bool, path: PackedInt32Array, caps: PackedInt32Array, out: Array) -> void:
	var side: int = signi(v)
	var extended := false
	for d: Vector2i in DIRS:
		if not king and d.y != side:
			continue
		var mx: int = x + d.x
		var my: int = y + d.y
		var tx: int = x + d.x * 2
		var ty: int = y + d.y * 2
		if tx < 0 or tx >= SIZE or ty < 0 or ty >= SIZE:
			continue
		var mid: int = my * SIZE + mx
		var to: int = ty * SIZE + tx
		if b[to] != 0 or b[mid] == 0 or signi(b[mid]) == side or caps.has(mid):
			continue
		extended = true
		var np := path.duplicate()
		np.append(to)
		var nc := caps.duplicate()
		nc.append(mid)
		var crowns: bool = not king and ((side == BOT and ty == SIZE - 1) or (side == PLAYER and ty == 0))
		if crowns:
			out.append([np, nc])
		else:
			_eng_jumps(b, tx, ty, v, king, np, nc, out)
	if not extended and caps.size() > 0:
		out.append([path, caps])


## Aplica la jugada y devuelve lo necesario para deshacerla.
func _eng_make(b: PackedInt32Array, m: Array) -> PackedInt32Array:
	var path: PackedInt32Array = m[0]
	var caps: PackedInt32Array = m[1]
	var from: int = path[0]
	var to: int = path[path.size() - 1]
	var v: int = b[from]
	var undo := PackedInt32Array([v])
	b[from] = 0
	for c in caps:
		undo.append(b[c])
		b[c] = 0
	var ty: int = to / SIZE
	if v == 1 and ty == SIZE - 1:
		v = 2
	elif v == -1 and ty == 0:
		v = -2
	b[to] = v
	if m.size() > 2:
		var pen: int = m[2]
		undo.append(b[pen])
		b[pen] = 0  # boba: se pierde la ficha que podía comer
	return undo


func _eng_unmake(b: PackedInt32Array, m: Array, undo: PackedInt32Array) -> void:
	var path: PackedInt32Array = m[0]
	var caps: PackedInt32Array = m[1]
	b[path[path.size() - 1]] = 0
	b[path[0]] = undo[0]
	for i in range(caps.size()):
		b[caps[i]] = undo[i + 1]
	if m.size() > 2 and m[2] != path[path.size() - 1]:
		b[m[2]] = undo[undo.size() - 1]


## Evaluación desde el punto de vista de la máquina (positivo = le conviene).
func _eng_eval(b: PackedInt32Array) -> float:
	var score := 0.0
	var bot_mat := 0.0
	var pl_mat := 0.0
	var bot_n := 0
	var pl_n := 0
	var bot_kings: Array = []
	var pl_kings: Array = []
	var bot_all: Array = []
	var pl_all: Array = []
	for idx in range(SIZE * SIZE):
		var v: int = b[idx]
		if v == 0:
			continue
		var x: int = idx % SIZE
		var y: int = idx / SIZE
		var s := 0.0
		if abs(v) == 1:
			s = MAN_VALUE
			# Avanzar hacia la coronación vale, más aún cerca de ella.
			var adv: int = y if v > 0 else (SIZE - 1 - y)
			s += adv * 3.0 + (8.0 if adv >= 5 else 0.0)
			# Fila de atrás intacta: impide que el rival corone.
			if adv == 0:
				s += 9.0
			if x >= 2 and x <= 5 and y >= 2 and y <= 5:
				s += 5.0
			# Peón protegido por detrás (no se lo pueden comer desde enfrente).
			var back_y: int = y - signi(v)
			if back_y >= 0 and back_y < SIZE:
				for dx in [-1, 1]:
					var bx: int = x + dx
					if bx >= 0 and bx < SIZE and signi(b[back_y * SIZE + bx]) == signi(v):
						s += 2.0
		else:
			s = KING_VALUE
			s += (3.5 - absf(x - 3.5)) * 2.0 + (3.5 - absf(y - 3.5)) * 2.0
		if v > 0:
			score += s
			bot_mat += MAN_VALUE if v == 1 else KING_VALUE
			bot_n += 1
			bot_all.append(Vector2i(x, y))
			if v == 2:
				bot_kings.append(Vector2i(x, y))
		else:
			score -= s
			pl_mat += MAN_VALUE if v == -1 else KING_VALUE
			pl_n += 1
			pl_all.append(Vector2i(x, y))
			if v == -2:
				pl_kings.append(Vector2i(x, y))
	# Con ventaja conviene cambiar fichas (3 vs 2 es más ganado que 12 vs 11).
	var total: int = bot_n + pl_n
	if total > 0:
		score += (bot_mat - pl_mat) * 6.0 / float(total)
	# En el final, las reinas del que va ganando persiguen a las fichas
	# rivales en vez de pasearse -- sin esto la IA no sabe rematar.
	if total <= 10:
		if bot_mat > pl_mat:
			score -= _chase_distance(bot_kings, pl_all) * 3.0
		elif pl_mat > bot_mat:
			score += _chase_distance(pl_kings, bot_all) * 3.0
	return score


func _chase_distance(kings: Array, targets: Array) -> float:
	var total := 0.0
	for k: Vector2i in kings:
		var best := 99
		for t: Vector2i in targets:
			best = mini(best, maxi(absi(k.x - t.x), absi(k.y - t.y)))
		total += best
	return total


## Búsqueda por profundización iterativa: busca a 1, 2, 3... jugadas hasta
## agotar el tiempo y se queda con la mejor jugada de la última profundidad
## completa. Con poco tiempo la IA sigue siendo sólida, con más ve más lejos.
func _eng_search(b: PackedInt32Array, moves: Array, max_depth: int, time_ms: int, quiescence: bool) -> Array:
	if moves.size() == 1:
		return moves[0]
	_use_quiescence = quiescence
	_deadline = Time.get_ticks_msec() + time_ms
	_aborted = false
	moves.shuffle()  # variedad entre jugadas igual de buenas
	moves.sort_custom(func(a: Array, c: Array) -> bool: return a[1].size() > c[1].size())
	var best: Array = moves[0]
	for depth in range(1, max_depth + 1):
		var alpha := -INF
		var depth_best: Array = moves[0]
		var scores: Dictionary = {}
		for m: Array in moves:
			var undo: PackedInt32Array = _eng_make(b, m)
			var sc: float = -_negamax(b, depth - 1, -INF, -alpha, PLAYER, 1)
			# Volver a una posición que ya se vio en la partida cuenta como
			# empate: si va ganando, la evita (antes podía ir y venir con la
			# misma ficha sin fin); si va perdiendo, la busca.
			if position_history.get(str(Array(b)) + "player", 0) >= 1:
				sc = 0.0
			_eng_unmake(b, m, undo)
			if _aborted:
				break
			scores[m] = sc
			if sc > alpha:
				alpha = sc
				depth_best = m
		if _aborted:
			break
		best = depth_best
		if alpha >= WIN_SCORE - 100.0:
			break  # ya encontró una victoria forzada
		# La mejor jugada de esta profundidad se prueba primero en la
		# siguiente: así la poda corta mucho más.
		moves.sort_custom(func(a: Array, c: Array) -> bool: return scores.get(a, -INF) > scores.get(c, -INF))
	return best


func _negamax(b: PackedInt32Array, depth: int, alpha: float, beta: float, side: int, ply: int) -> float:
	_nodes += 1
	if (_nodes & 255) == 0 and Time.get_ticks_msec() > _deadline:
		_aborted = true
		return 0.0
	var moves: Array = _eng_moves(b, side)
	if moves.is_empty():
		return -WIN_SCORE + ply  # sin jugadas = pierde; mejor perder tarde
	if depth <= 0:
		# Quiescencia: no cortar a media ronda de capturas (efecto
		# horizonte). Como comer es opcional, el que mueve puede "plantarse"
		# con la evaluación actual o seguir con alguna captura.
		var stand: float = side * _eng_eval(b)
		if not _use_quiescence or depth <= -QUIESCENCE_MAX or stand >= beta:
			return stand
		alpha = maxf(alpha, stand)
		for m: Array in moves:
			if m[1].size() == 0:
				break  # las capturas van primero
			var undo: PackedInt32Array = _eng_make(b, m)
			var sc: float = -_negamax(b, depth - 1, -beta, -alpha, -side, ply + 1)
			_eng_unmake(b, m, undo)
			if _aborted:
				return 0.0
			if sc >= beta:
				return sc
			alpha = maxf(alpha, sc)
		return alpha
	var best := -INF
	for m: Array in moves:
		var undo: PackedInt32Array = _eng_make(b, m)
		var sc: float = -_negamax(b, depth - 1, -beta, -alpha, -side, ply + 1)
		_eng_unmake(b, m, undo)
		if _aborted:
			return 0.0
		if sc > best:
			best = sc
		if sc > alpha:
			alpha = sc
		if alpha >= beta:
			break
	return best
