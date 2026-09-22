extends Control
## Otelo / Reversi contra la máquina. La IA es voraz: siempre elige el
## movimiento que voltea más fichas en ese turno (sin planear a futuro).

const GAME_ID := "othello"
const SIZE := 8
const DIRS := [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]

const HELP_TEXT := "Tú juegas con fichas rosas, la máquina con fichas teal.

Toca una casilla vacía: si tu ficha 'encierra' una o más fichas rivales en línea recta (horizontal, vertical o diagonal) contra otra ficha tuya, esas fichas rivales se voltean a tu color.

Si no tienes ningún movimiento válido, se pasa el turno automáticamente. El juego termina cuando nadie puede mover; gana quien tenga más fichas en el tablero."

var board: Array = []
var cell_buttons: Array = []
var current_turn: String = "player"
var game_over: bool = false

var status_label: Label
var score_label: Label


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
		for x in range(SIZE):
			var cell := Button.new()
			cell.custom_minimum_size = Vector2(38, 38)
			cell.add_theme_font_size_override("font_size", 20)
			UIKit.style_button(cell, UIKit.COLOR_BG_LIGHT, 6)
			cell.pressed.connect(_on_cell_pressed.bind(x, y))
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

	board[3][3] = "bot"
	board[4][4] = "bot"
	board[3][4] = "player"
	board[4][3] = "player"

	game_over = false
	_redraw_all()
	_begin_turn("player")


func _flips_for(x: int, y: int, owner: String) -> Array:
	if board[y][x] != null:
		return []
	var opponent: String = "bot" if owner == "player" else "player"
	var all_flips: Array = []
	for dir: Vector2i in DIRS:
		var line: Array = []
		var cx: int = x + dir.x
		var cy: int = y + dir.y
		while cx >= 0 and cx < SIZE and cy >= 0 and cy < SIZE and board[cy][cx] == opponent:
			line.append(Vector2i(cx, cy))
			cx += dir.x
			cy += dir.y
		if not line.is_empty() and cx >= 0 and cx < SIZE and cy >= 0 and cy < SIZE and board[cy][cx] == owner:
			all_flips.append_array(line)
	return all_flips


func _legal_moves(owner: String) -> Array:
	var moves: Array = []
	for y in range(SIZE):
		for x in range(SIZE):
			if not _flips_for(x, y, owner).is_empty():
				moves.append(Vector2i(x, y))
	return moves


func _place(x: int, y: int, owner: String) -> void:
	var flips: Array = _flips_for(x, y, owner)
	board[y][x] = owner
	for p: Vector2i in flips:
		board[p.y][p.x] = owner


func _count(owner: String) -> int:
	var n := 0
	for row: Array in board:
		for cell: Variant in row:
			if cell == owner:
				n += 1
	return n


func _redraw_all() -> void:
	for y in range(SIZE):
		for x in range(SIZE):
			var cell: Button = cell_buttons[y][x]
			var v: Variant = board[y][x]
			if v == null:
				cell.text = ""
			else:
				cell.text = "●"
				var color: Color = UIKit.COLOR_ACCENT if v == "player" else UIKit.COLOR_ACCENT_2
				cell.add_theme_color_override("font_color", color)
				cell.add_theme_color_override("font_disabled_color", color)
	score_label.text = "Tú: %d      Máquina: %d" % [_count("player"), _count("bot")]


func _on_cell_pressed(x: int, y: int) -> void:
	if game_over or current_turn != "player":
		return
	if _flips_for(x, y, "player").is_empty():
		return
	_place(x, y, "player")
	_redraw_all()
	_begin_turn("bot")


func _begin_turn(owner: String) -> void:
	current_turn = owner
	var moves: Array = _legal_moves(owner)

	if moves.is_empty():
		var other: String = "bot" if owner == "player" else "player"
		if _legal_moves(other).is_empty():
			_end_game()
			return
		status_label.text = ("Tú" if owner == "player" else "La máquina") + " no tienes movimientos, se pasa el turno"
		status_label.add_theme_color_override("font_color", UIKit.COLOR_TEXT_DIM)
		_begin_turn(other)
		return

	if owner == "player":
		status_label.text = "Tu turno"
		status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT)
	else:
		status_label.text = "Turno de la máquina..."
		status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT_2)
		await get_tree().create_timer(0.5).timeout
		_bot_move(moves)


func _bot_move(moves: Array) -> void:
	var best: Vector2i = moves[0]
	var best_count := -1
	for m: Vector2i in moves:
		var count: int = _flips_for(m.x, m.y, "bot").size()
		if count > best_count:
			best_count = count
			best = m
	_place(best.x, best.y, "bot")
	_redraw_all()
	_begin_turn("player")


func _end_game() -> void:
	game_over = true
	var player_count: int = _count("player")
	var bot_count: int = _count("bot")
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


func _record_result(key: String) -> void:
	var stats: Dictionary = SaveManager.get_game_data(GAME_ID)
	stats[key] = stats.get(key, 0) + 1
	SaveManager.set_game_data(GAME_ID, stats)
