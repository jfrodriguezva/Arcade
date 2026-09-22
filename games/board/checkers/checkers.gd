extends Control
## Damas clásicas contra la máquina. Captura opcional (no es obligatorio
## comer si puedes), pero si empiezas una captura y puedes encadenar otra
## con la misma ficha, se te permite seguir de inmediato.

const GAME_ID := "checkers"
const SIZE := 8
const DIRS := [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]

const HELP_TEXT := "Juegas con las fichas rosas (abajo) contra la máquina (fichas teal, arriba).

- Toca una de tus fichas para seleccionarla.
- Toca una casilla oscura vacía en diagonal para moverte ahí.
- Si hay una ficha rival justo en diagonal y la casilla siguiente está vacía, salta sobre ella para comerla.
- Si llegas al otro extremo del tablero, tu ficha se corona Reina (♛) y se mueve en diagonal hacia ambos lados.

Gana quien deje al rival sin fichas o sin movimientos posibles."

var board: Array = [] # board[y][x] = null o {"owner":"player"/"bot", "king":bool}
var cell_buttons: Array = []
var selected: Vector2i = Vector2i(-1, -1)
var current_turn: String = "player"
var game_over: bool = false

var status_label: Label


func _ready() -> void:
	_build_ui()
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
		for x in range(SIZE):
			var cell := Button.new()
			cell.custom_minimum_size = Vector2(38, 38)
			cell.add_theme_font_size_override("font_size", 20)
			if (x + y) % 2 == 1:
				cell.pressed.connect(_on_cell_pressed.bind(x, y))
			else:
				cell.disabled = true
				cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			grid.add_child(cell)
			row.append(cell)
		cell_buttons.append(row)

	var restart_btn := Button.new()
	restart_btn.text = "↻  Nueva partida"
	restart_btn.custom_minimum_size = Vector2(200, 48)
	UIKit.style_button(restart_btn, UIKit.COLOR_ACCENT_3)
	restart_btn.pressed.connect(_new_game)
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
	current_turn = "player"
	game_over = false
	status_label.text = "Tu turno"
	status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT)
	_redraw_all()


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

	if piece == null:
		cell.text = ""
	else:
		cell.text = "♛" if piece["king"] else "●"
		var color: Color = UIKit.COLOR_ACCENT if piece["owner"] == "player" else UIKit.COLOR_ACCENT_2
		cell.add_theme_color_override("font_color", color)
		cell.add_theme_color_override("font_disabled_color", color)


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
		_end_game(true)
		return true
	if _count_pieces("player") == 0 or not _has_any_move("player"):
		_end_game(false)
		return true
	return false


func _end_game(player_won: bool) -> void:
	game_over = true
	if player_won:
		status_label.text = "¡Ganaste!"
		status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT_3)
	else:
		status_label.text = "Ganó la máquina"
		status_label.add_theme_color_override("font_color", UIKit.COLOR_DANGER)
	_record_result(player_won)


func _record_result(won: bool) -> void:
	var stats: Dictionary = SaveManager.get_game_data(GAME_ID)
	var key: String = "wins" if won else "losses"
	stats[key] = stats.get(key, 0) + 1
	SaveManager.set_game_data(GAME_ID, stats)


func _on_cell_pressed(x: int, y: int) -> void:
	if game_over or current_turn != "player":
		return

	var piece: Variant = board[y][x]

	if selected == Vector2i(-1, -1):
		if piece != null and piece["owner"] == "player":
			selected = Vector2i(x, y)
			_redraw_all()
		return

	if piece != null and piece["owner"] == "player":
		selected = Vector2i(x, y)
		_redraw_all()
		return

	var result: String = _try_move(selected.x, selected.y, x, y, "player")
	if result == "invalid":
		selected = Vector2i(-1, -1)
		_redraw_all()
		return

	if result == "capture" and _has_capture_from(x, y, "player"):
		selected = Vector2i(x, y)
		_redraw_all()
		return

	selected = Vector2i(-1, -1)
	_redraw_all()

	if _check_win():
		return

	current_turn = "bot"
	status_label.text = "Turno de la máquina..."
	status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT_2)
	await get_tree().create_timer(0.5).timeout
	_bot_turn()


func _pick_bot_move() -> Variant:
	var captures: Array = []
	var moves: Array = []

	for y in range(SIZE):
		for x in range(SIZE):
			var piece: Variant = board[y][x]
			if piece == null or piece["owner"] != "bot":
				continue
			for dir: Vector2i in DIRS:
				if not _direction_ok("bot", piece["king"], dir.y):
					continue
				var sx: int = x + dir.x
				var sy: int = y + dir.y
				if sx >= 0 and sx < SIZE and sy >= 0 and sy < SIZE and board[sy][sx] == null:
					moves.append({"from": Vector2i(x, y), "to": Vector2i(sx, sy)})

				var tx: int = x + dir.x * 2
				var ty: int = y + dir.y * 2
				if tx >= 0 and tx < SIZE and ty >= 0 and ty < SIZE and board[ty][tx] == null:
					var mid: Variant = board[sy][sx]
					if mid != null and mid["owner"] == "player":
						captures.append({"from": Vector2i(x, y), "to": Vector2i(tx, ty)})

	if not captures.is_empty():
		return captures[randi() % captures.size()]
	if not moves.is_empty():
		return moves[randi() % moves.size()]
	return null


func _bot_turn() -> void:
	var move: Variant = _pick_bot_move()
	if move == null:
		_check_win()
		return

	var from: Vector2i = move["from"]
	var to: Vector2i = move["to"]
	var result: String = _try_move(from.x, from.y, to.x, to.y, "bot")
	_redraw_all()

	if result == "capture" and _has_capture_from(to.x, to.y, "bot"):
		await get_tree().create_timer(0.4).timeout
		_bot_turn()
		return

	if _check_win():
		return

	current_turn = "player"
	status_label.text = "Tu turno"
	status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT)
