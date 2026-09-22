extends Control
## Batalla Naval: tú vs la máquina. Flotas se colocan al azar al iniciar.
## Tocas la grilla enemiga para disparar; la máquina responde con una IA
## simple de "caza" (si acierta, prueba las celdas vecinas primero).

const GAME_ID := "battleship"
const GRID_SIZE := 8
const FLEET := [4, 3, 2, 2] # tamaños de barco

const HELP_TEXT := "Tu flota (arriba) se coloca al azar y siempre está visible. La flota enemiga (abajo) está oculta.

Toca una celda de la grilla enemiga para disparar ahí:
- 'X' rojo = impacto
- '·' = agua (fallaste)

Después de cada disparo tuyo, la máquina dispara una vez a tu flota. Si acierta, seguirá probando las celdas vecinas.

Gana quien hunda primero las 4 naves del rival (tamaños 4, 3, 2 y 2)."

var player_board: Array = [] # Array[Array[Dictionary{ship:bool, shot:bool}]]
var enemy_board: Array = []
var player_cells: Array = [] # Array[Array[Button]]
var enemy_cells: Array = []

var player_ship_cells_left: int = 0
var enemy_ship_cells_left: int = 0
var game_over: bool = false
var bot_target_queue: Array = []
var bot_tried: Array = [] # Array[Vector2i] ya disparadas por el bot

var status_label: Label


func _ready() -> void:
	_build_ui()
	_new_game()


func _build_ui() -> void:
	UIKit.apply_background(self)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 24)
	scroll.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	UIKit.build_toolbar(vbox, self, "Batalla Naval", HELP_TEXT)

	status_label = UIKit.title_label("", 24, UIKit.COLOR_TEXT)
	vbox.add_child(status_label)

	vbox.add_child(UIKit.title_label("Tu flota", 18, UIKit.COLOR_ACCENT_2))
	var player_grid := _build_grid(false)
	vbox.add_child(_wrap_panel(player_grid, UIKit.COLOR_ACCENT_2))

	vbox.add_child(UIKit.title_label("Flota enemiga", 18, UIKit.COLOR_ACCENT))
	var enemy_grid := _build_grid(true)
	vbox.add_child(_wrap_panel(enemy_grid, UIKit.COLOR_ACCENT))

	var restart_btn := Button.new()
	restart_btn.text = "↻  Nueva partida"
	restart_btn.custom_minimum_size = Vector2(200, 48)
	UIKit.style_button(restart_btn, UIKit.COLOR_ACCENT_3)
	restart_btn.pressed.connect(_new_game)
	vbox.add_child(restart_btn)


func _wrap_panel(grid: GridContainer, accent: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_PANEL, accent, 16, 2))
	var m := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		m.add_theme_constant_override(side, 10)
	panel.add_child(m)
	m.add_child(grid)
	return panel


func _build_grid(is_enemy: bool) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = GRID_SIZE
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)

	var cells: Array = []
	for y in range(GRID_SIZE):
		var row: Array = []
		for x in range(GRID_SIZE):
			var cell := Button.new()
			cell.custom_minimum_size = Vector2(36, 36)
			cell.add_theme_font_size_override("font_size", 16)
			UIKit.style_button(cell, UIKit.COLOR_BG_LIGHT, 8)
			if is_enemy:
				cell.pressed.connect(_on_enemy_cell_pressed.bind(x, y))
			else:
				cell.disabled = true
			grid.add_child(cell)
			row.append(cell)
		cells.append(row)

	if is_enemy:
		enemy_cells = cells
	else:
		player_cells = cells
	return grid


func _new_game() -> void:
	game_over = false
	bot_target_queue.clear()
	bot_tried.clear()
	player_board = _make_empty_board()
	enemy_board = _make_empty_board()
	player_ship_cells_left = _place_fleet(player_board)
	enemy_ship_cells_left = _place_fleet(enemy_board)
	_redraw_all()
	status_label.text = "Tu turno: dispara en la flota enemiga"
	status_label.add_theme_color_override("font_color", UIKit.COLOR_TEXT)


func _make_empty_board() -> Array:
	var b: Array = []
	for y in range(GRID_SIZE):
		var row: Array = []
		for x in range(GRID_SIZE):
			row.append({"ship": false, "shot": false})
		b.append(row)
	return b


func _place_fleet(board: Array) -> int:
	var total_cells := 0
	for size: int in FLEET:
		var placed := false
		var attempts := 0
		while not placed and attempts < 200:
			attempts += 1
			var horizontal := randi() % 2 == 0
			var max_x := GRID_SIZE - (size if horizontal else 1) + 1
			var max_y := GRID_SIZE - (1 if horizontal else size) + 1
			var start_x := randi() % max_x
			var start_y := randi() % max_y

			var coords: Array = []
			for i in range(size):
				var cx := start_x + (i if horizontal else 0)
				var cy := start_y + (0 if horizontal else i)
				coords.append(Vector2i(cx, cy))

			if _fits(board, coords):
				for c: Vector2i in coords:
					board[c.y][c.x]["ship"] = true
				total_cells += size
				placed = true
	return total_cells


func _fits(board: Array, coords: Array) -> bool:
	for c: Vector2i in coords:
		if c.x < 0 or c.x >= GRID_SIZE or c.y < 0 or c.y >= GRID_SIZE:
			return false
		if board[c.y][c.x]["ship"]:
			return false
	return true


func _redraw_all() -> void:
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			_redraw_player_cell(x, y)
			_redraw_enemy_cell(x, y)


func _redraw_player_cell(x: int, y: int) -> void:
	var data: Dictionary = player_board[y][x]
	var cell: Button = player_cells[y][x]
	if data["shot"] and data["ship"]:
		cell.text = "X"
		UIKit.style_button(cell, UIKit.COLOR_DANGER, 8)
	elif data["shot"]:
		cell.text = "·"
		UIKit.style_button(cell, UIKit.COLOR_BG, 8)
	elif data["ship"]:
		UIKit.style_button(cell, UIKit.COLOR_ACCENT_2, 8)
	else:
		UIKit.style_button(cell, UIKit.COLOR_BG_LIGHT, 8)


func _redraw_enemy_cell(x: int, y: int) -> void:
	var data: Dictionary = enemy_board[y][x]
	var cell: Button = enemy_cells[y][x]
	if data["shot"] and data["ship"]:
		cell.text = "X"
		UIKit.style_button(cell, UIKit.COLOR_ACCENT, 8)
		cell.disabled = true
	elif data["shot"]:
		cell.text = "·"
		UIKit.style_button(cell, UIKit.COLOR_BG, 8)
		cell.disabled = true
	else:
		UIKit.style_button(cell, UIKit.COLOR_BG_LIGHT, 8)
		cell.disabled = false


func _on_enemy_cell_pressed(x: int, y: int) -> void:
	if game_over:
		return
	var data: Dictionary = enemy_board[y][x]
	if data["shot"]:
		return

	data["shot"] = true
	if data["ship"]:
		enemy_ship_cells_left -= 1
	_redraw_enemy_cell(x, y)
	UIKit.pulse(enemy_cells[y][x])

	if enemy_ship_cells_left <= 0:
		_end_game(true)
		return

	_bot_turn()


func _bot_turn() -> void:
	var pos := _pick_bot_target()
	if pos == Vector2i(-1, -1):
		return

	var data: Dictionary = player_board[pos.y][pos.x]
	data["shot"] = true
	if data["ship"]:
		player_ship_cells_left -= 1
		for n: Vector2i in _neighbors(pos):
			if not player_board[n.y][n.x]["shot"] and not bot_target_queue.has(n):
				bot_target_queue.append(n)
	_redraw_player_cell(pos.x, pos.y)

	if player_ship_cells_left <= 0:
		_end_game(false)
		return

	status_label.text = "Tu turno: dispara en la flota enemiga"
	status_label.add_theme_color_override("font_color", UIKit.COLOR_TEXT)


func _pick_bot_target() -> Vector2i:
	while not bot_target_queue.is_empty():
		var pos: Vector2i = bot_target_queue.pop_front()
		if not player_board[pos.y][pos.x]["shot"]:
			return pos

	var candidates: Array = []
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			if not player_board[y][x]["shot"]:
				candidates.append(Vector2i(x, y))
	if candidates.is_empty():
		return Vector2i(-1, -1)
	return candidates[randi() % candidates.size()]


func _neighbors(pos: Vector2i) -> Array:
	var result: Array = []
	for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n := pos + offset
		if n.x >= 0 and n.x < GRID_SIZE and n.y >= 0 and n.y < GRID_SIZE:
			result.append(n)
	return result


func _end_game(player_won: bool) -> void:
	game_over = true
	if player_won:
		status_label.text = "¡Hundiste toda la flota enemiga!"
		status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT_3)
	else:
		status_label.text = "La máquina hundió tu flota..."
		status_label.add_theme_color_override("font_color", UIKit.COLOR_DANGER)
	for row: Array in enemy_cells:
		for cell: Button in row:
			cell.disabled = true
	_record_result(player_won)


func _record_result(player_won: bool) -> void:
	var stats: Dictionary = SaveManager.get_game_data(GAME_ID)
	var key := "wins" if player_won else "losses"
	stats[key] = stats.get(key, 0) + 1
	SaveManager.set_game_data(GAME_ID, stats)
