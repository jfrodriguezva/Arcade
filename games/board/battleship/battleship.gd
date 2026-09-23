extends Control
## Batalla Naval: Vs Máquina (flotas al azar, IA de "caza" tras un
## acierto) o 2 Jugadores en el mismo dispositivo (turnos alternados,
## con pantalla de "pasa el dispositivo" entre turnos para que nadie
## vea la flota del otro).

const GAME_ID := "battleship"
const GRID_SIZE := 8
const FLEET := [4, 3, 2, 2] # tamaños de barco

const HELP_TEXT := "Tu flota (arriba) se coloca al azar y siempre está visible para ti. La flota enemiga (abajo) está oculta.

Toca una celda de la grilla enemiga para disparar ahí:
- 'X' rojo = impacto
- '·' = agua (fallaste)

En Vs Máquina, después de cada disparo tuyo la máquina dispara una vez a tu flota (con IA de 'caza' tras un acierto). En 2 Jugadores, los turnos se alternan y verás una pantalla para pasar el dispositivo entre cada uno, así nadie ve la flota del otro.

Gana quien hunda primero las 4 naves del rival (tamaños 4, 3, 2 y 2)."

var boards: Dictionary = {}
var ship_cells_left: Dictionary = {}
var my_cells: Array = []
var enemy_cells: Array = []
var current_turn: String = "player"
var mode: String = "pve"
var game_over: bool = false
var bot_target_queue: Array = []

var status_label: Label
var my_fleet_label: Label


func _ready() -> void:
	_build_ui()
	UIKit.show_setup_overlay(self, "Batalla Naval", true, false, _on_setup_confirmed)


func _on_setup_confirmed(config: Dictionary) -> void:
	mode = config["mode"]
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

	my_fleet_label = UIKit.title_label("Tu flota", 18, UIKit.COLOR_ACCENT_2)
	vbox.add_child(my_fleet_label)
	var my_grid := _build_grid(false)
	vbox.add_child(_wrap_panel(my_grid, UIKit.COLOR_ACCENT_2))

	vbox.add_child(UIKit.title_label("Flota enemiga", 18, UIKit.COLOR_ACCENT))
	var enemy_grid := _build_grid(true)
	vbox.add_child(_wrap_panel(enemy_grid, UIKit.COLOR_ACCENT))

	var restart_btn := Button.new()
	restart_btn.text = "↻  Nueva partida / Modo"
	restart_btn.custom_minimum_size = Vector2(220, 48)
	UIKit.style_button(restart_btn, UIKit.COLOR_ACCENT_3)
	restart_btn.pressed.connect(func() -> void: UIKit.show_setup_overlay(self, "Batalla Naval", true, false, _on_setup_confirmed))
	vbox.add_child(restart_btn)


func _wrap_panel(grid: GridContainer, accent: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_PANEL, accent, 16, 2))
	var m := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
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
			cell.custom_minimum_size = Vector2(58, 58)
			cell.add_theme_font_size_override("font_size", 20)
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
		my_cells = cells
	return grid


func _opponent(owner: String) -> String:
	return "bot" if owner == "player" else "player"


func _new_game() -> void:
	game_over = false
	bot_target_queue.clear()
	current_turn = "player"
	boards = {"player": _make_empty_board(), "bot": _make_empty_board()}
	ship_cells_left = {"player": _place_fleet(boards["player"]), "bot": _place_fleet(boards["bot"])}
	_redraw_all()
	_update_turn_status()


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


func _update_turn_status() -> void:
	if mode == "pve":
		my_fleet_label.text = "Tu flota"
		status_label.text = "Tu turno: dispara en la flota enemiga" if current_turn == "player" else "Turno de la máquina..."
		status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT if current_turn == "player" else UIKit.COLOR_ACCENT_2)
	else:
		var label: String = "Jugador 1 (rosa)" if current_turn == "player" else "Jugador 2 (teal)"
		my_fleet_label.text = "Flota de %s" % label
		status_label.text = "Turno: %s - dispara en la flota enemiga" % label
		status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT if current_turn == "player" else UIKit.COLOR_ACCENT_2)


func _redraw_all() -> void:
	var mine: Array = boards[current_turn]
	var theirs: Array = boards[_opponent(current_turn)]
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			_style_my_cell(x, y, mine[y][x])
			_style_enemy_cell(x, y, theirs[y][x])


func _style_my_cell(x: int, y: int, data: Dictionary) -> void:
	var cell: Button = my_cells[y][x]
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


func _style_enemy_cell(x: int, y: int, data: Dictionary) -> void:
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
		cell.text = ""
		UIKit.style_button(cell, UIKit.COLOR_BG_LIGHT, 8)
		cell.disabled = game_over


func _on_enemy_cell_pressed(x: int, y: int) -> void:
	if game_over:
		return

	var attacker: String = current_turn
	var target_key: String = _opponent(attacker)
	var data: Dictionary = boards[target_key][y][x]
	if data["shot"]:
		return

	data["shot"] = true
	if data["ship"]:
		ship_cells_left[target_key] -= 1
	_redraw_all()
	UIKit.pulse(enemy_cells[y][x])

	if ship_cells_left[target_key] <= 0:
		_end_game(attacker)
		return

	_advance_turn(attacker)


func _advance_turn(attacker: String) -> void:
	current_turn = _opponent(attacker)

	if mode == "pve":
		if current_turn == "bot":
			_update_turn_status()
			await get_tree().create_timer(0.5).timeout
			_bot_turn()
		else:
			_update_turn_status()
		return

	var next_label: String = "Jugador 1 (rosa)" if current_turn == "player" else "Jugador 2 (teal)"
	UIKit.show_pass_cover(self, "Pásale el dispositivo a %s" % next_label, _on_pass_confirmed)


func _on_pass_confirmed() -> void:
	_redraw_all()
	_update_turn_status()


func _bot_turn() -> void:
	var pos := _pick_bot_target()
	if pos == Vector2i(-1, -1):
		return

	var data: Dictionary = boards["player"][pos.y][pos.x]
	data["shot"] = true
	if data["ship"]:
		ship_cells_left["player"] -= 1
		for n: Vector2i in _neighbors(pos):
			if not boards["player"][n.y][n.x]["shot"] and not bot_target_queue.has(n):
				bot_target_queue.append(n)
	_redraw_all()

	if ship_cells_left["player"] <= 0:
		_end_game("bot")
		return

	current_turn = "player"
	_update_turn_status()


func _pick_bot_target() -> Vector2i:
	while not bot_target_queue.is_empty():
		var pos: Vector2i = bot_target_queue.pop_front()
		if not boards["player"][pos.y][pos.x]["shot"]:
			return pos

	var candidates: Array = []
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			if not boards["player"][y][x]["shot"]:
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


func _end_game(winner: String) -> void:
	game_over = true
	if mode == "pve":
		if winner == "player":
			status_label.text = "¡Hundiste toda la flota enemiga!"
			status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT_3)
		else:
			status_label.text = "La máquina hundió tu flota..."
			status_label.add_theme_color_override("font_color", UIKit.COLOR_DANGER)
		_record_result(winner == "player")
	else:
		var label: String = "Jugador 1 (rosa)" if winner == "player" else "Jugador 2 (teal)"
		status_label.text = "¡%s hundió la flota rival!" % label
		status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT_3)
		AudioManager.play_win()

	for row: Array in enemy_cells:
		for cell: Button in row:
			cell.disabled = true


func _record_result(player_won: bool) -> void:
	AudioManager.play_win() if player_won else AudioManager.play_lose()
	var stats: Dictionary = SaveManager.get_game_data(GAME_ID)
	var key := "wins" if player_won else "losses"
	stats[key] = stats.get(key, 0) + 1
	SaveManager.set_game_data(GAME_ID, stats)
