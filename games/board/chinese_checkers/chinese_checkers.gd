extends Control
## Damas Chinas para 2 jugadores. En vez del tablero clásico en
## estrella de 6 puntas (121 celdas, complejo de generar bien sin
## arte de referencia), se usa una cuadrícula rómbica de 11x11 en
## coordenadas hexagonales axiales — mismo movimiento real de 6
## direcciones y saltos encadenados, solo con la forma del tablero
## simplificada a un rombo en vez de una estrella.

const GAME_ID := "chinese_checkers"
const N := 10 # tablero de (N+1) x (N+1) = 121 celdas, coords (q,r) de 0..N
const CELL_W := 30
const CELL_H := 26
const DIRS := [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]

const HELP_TEXT := "Cada jugador tiene 10 fichas en un triángulo, en esquinas opuestas del tablero.

- Toca una ficha tuya para seleccionarla.
- Toca una celda vecina vacía para moverte un paso (termina tu turno).
- Toca una celda vacía justo detrás de una ficha (tuya o rival) en línea recta para saltarla — el salto NO la elimina, solo te deja pasar. Puedes encadenar varios saltos seguidos con la misma ficha; toca 'Terminar turno' cuando quieras parar.

Gana quien mueva sus 10 fichas al triángulo del lado opuesto (donde empezó el rival) primero."

var positions: Dictionary = {"player": [], "bot": []}
var home_cells: Dictionary = {"player": [], "bot": []}
var current_turn: String = "player"
var mode: String = "pve"
var difficulty: String = "medium"
var game_over: bool = false
var selected: Vector2i = Vector2i(-1, -1)
var moved_this_turn: bool = false

var status_label: Label
var canvas: Control
var end_chain_btn: Button
var cell_buttons: Dictionary = {}


func _ready() -> void:
	_build_ui()
	UIKit.show_setup_overlay(self, "Damas Chinas", true, true, _on_setup_confirmed)


func _on_setup_confirmed(config: Dictionary) -> void:
	mode = config["mode"]
	difficulty = config["difficulty"]
	_new_game()


func _build_ui() -> void:
	UIKit.apply_background(self)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)

	var margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 20)
	scroll.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	UIKit.build_toolbar(vbox, self, "Damas Chinas", HELP_TEXT)

	status_label = UIKit.title_label("", 18, UIKit.COLOR_TEXT)
	vbox.add_child(status_label)

	end_chain_btn = Button.new()
	end_chain_btn.text = "✓  Terminar turno"
	end_chain_btn.custom_minimum_size = Vector2(200, 44)
	UIKit.style_button(end_chain_btn, UIKit.COLOR_ACCENT_3)
	end_chain_btn.pressed.connect(_on_end_chain_pressed)
	vbox.add_child(end_chain_btn)

	var board_panel := PanelContainer.new()
	board_panel.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_PANEL, UIKit.COLOR_ACCENT_3, 16, 2))
	var board_margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		board_margin.add_theme_constant_override(side, 10)
	board_panel.add_child(board_margin)

	var center := CenterContainer.new()
	vbox.add_child(center)
	center.add_child(board_panel)

	canvas = Control.new()
	canvas.custom_minimum_size = Vector2(N * CELL_W + N * CELL_W * 0.5 + 24, N * CELL_H + 24)
	board_margin.add_child(canvas)

	for q in range(N + 1):
		for r in range(N + 1):
			var cell := Button.new()
			cell.custom_minimum_size = Vector2(24, 22)
			cell.add_theme_font_size_override("font_size", 12)
			cell.position = Vector2(q * CELL_W + r * CELL_W * 0.5, r * CELL_H)
			cell.pressed.connect(_on_cell_pressed.bind(Vector2i(q, r)))
			canvas.add_child(cell)
			cell_buttons[Vector2i(q, r)] = cell

	var restart_btn := Button.new()
	restart_btn.text = "↻  Nueva partida / Modo"
	restart_btn.custom_minimum_size = Vector2(220, 48)
	UIKit.style_button(restart_btn, UIKit.COLOR_ACCENT_3)
	restart_btn.pressed.connect(func() -> void: UIKit.show_setup_overlay(self, "Damas Chinas", true, true, _on_setup_confirmed))
	vbox.add_child(restart_btn)


func _new_game() -> void:
	home_cells["player"] = []
	home_cells["bot"] = []
	for i in range(4):
		for j in range(4 - i):
			home_cells["player"].append(Vector2i(i, j))
			home_cells["bot"].append(Vector2i(N - i, N - j))

	positions["player"] = home_cells["player"].duplicate()
	positions["bot"] = home_cells["bot"].duplicate()

	current_turn = "player"
	game_over = false
	selected = Vector2i(-1, -1)
	moved_this_turn = false
	_start_turn()


func _in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.x <= N and c.y >= 0 and c.y <= N


func _neighbor_in_dir(cell: Vector2i, dir: Vector2i) -> Vector2i:
	return Vector2i(cell.x + dir.x, cell.y + dir.y)


func _marble_at(cell: Vector2i) -> String:
	if positions["player"].has(cell):
		return "player"
	if positions["bot"].has(cell):
		return "bot"
	return ""


func _is_adjacent_empty(from: Vector2i, to: Vector2i) -> bool:
	if not _in_bounds(to) or _marble_at(to) != "":
		return false
	for d: Vector2i in DIRS:
		if _neighbor_in_dir(from, d) == to:
			return true
	return false


func _is_valid_jump(from: Vector2i, to: Vector2i) -> bool:
	if not _in_bounds(to) or _marble_at(to) != "":
		return false
	for d: Vector2i in DIRS:
		var mid: Vector2i = _neighbor_in_dir(from, d)
		var land: Vector2i = Vector2i(mid.x + d.x, mid.y + d.y)
		if land == to and _marble_at(mid) != "":
			return true
	return false


func _has_any_jump_from(cell: Vector2i) -> bool:
	for d: Vector2i in DIRS:
		var mid: Vector2i = _neighbor_in_dir(cell, d)
		var land: Vector2i = Vector2i(mid.x + d.x, mid.y + d.y)
		if _in_bounds(land) and _marble_at(land) == "" and _marble_at(mid) != "":
			return true
	return false


func _progress(cell: Vector2i, owner: String) -> int:
	return cell.x + cell.y if owner == "player" else -(cell.x + cell.y)


func _has_won(owner: String) -> bool:
	var goal: Array = home_cells["bot"] if owner == "player" else home_cells["player"]
	for p: Vector2i in positions[owner]:
		if not goal.has(p):
			return false
	return true


func _apply_single_move(owner: String, idx: int, to: Vector2i) -> void:
	positions[owner][idx] = to


func _index_of(owner: String, cell: Vector2i) -> int:
	for i in range(positions[owner].size()):
		if positions[owner][i] == cell:
			return i
	return -1


func _on_cell_pressed(cell: Vector2i) -> void:
	if game_over:
		return
	if mode == "pve" and current_turn != "player":
		return

	var owner: String = current_turn
	var occupant: String = _marble_at(cell)

	if selected == Vector2i(-1, -1):
		if occupant == owner:
			selected = cell
			_redraw_all()
		return

	if not moved_this_turn and occupant == owner and cell != selected:
		selected = cell
		_redraw_all()
		return

	if not moved_this_turn and _is_adjacent_empty(selected, cell):
		var idx: int = _index_of(owner, selected)
		_apply_single_move(owner, idx, cell)
		_after_move(owner)
		return

	if _is_valid_jump(selected, cell):
		var idx: int = _index_of(owner, selected)
		_apply_single_move(owner, idx, cell)
		selected = cell
		moved_this_turn = true
		_redraw_all()
		if not _has_any_jump_from(cell):
			_after_move(owner)
		return

	selected = Vector2i(-1, -1)
	moved_this_turn = false
	_redraw_all()


func _on_end_chain_pressed() -> void:
	if not moved_this_turn or game_over:
		return
	if mode == "pve" and current_turn != "player":
		return
	_after_move(current_turn)


func _after_move(owner: String) -> void:
	selected = Vector2i(-1, -1)
	moved_this_turn = false
	_redraw_all()

	if _has_won(owner):
		_end_game(owner)
		return

	current_turn = "bot" if owner == "player" else "player"
	_start_turn()


func _start_turn() -> void:
	_update_turn_status()
	_redraw_all()
	if mode == "pve" and current_turn == "bot":
		await get_tree().create_timer(0.4).timeout
		_bot_take_turn()


func _update_turn_status() -> void:
	if mode == "pve":
		status_label.text = "Tu turno" if current_turn == "player" else "Turno de la máquina..."
		status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT if current_turn == "player" else UIKit.COLOR_ACCENT_2)
	else:
		var label: String = "Jugador 1 (rosa)" if current_turn == "player" else "Jugador 2 (teal)"
		status_label.text = "Turno: %s" % label
		status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT if current_turn == "player" else UIKit.COLOR_ACCENT_2)


func _gather_candidate_moves(owner: String) -> Array:
	var moves: Array = []
	for idx in range(positions[owner].size()):
		var cell: Vector2i = positions[owner][idx]
		for d: Vector2i in DIRS:
			var step: Vector2i = _neighbor_in_dir(cell, d)
			if _in_bounds(step) and _marble_at(step) == "":
				moves.append({"marble": idx, "to": step, "is_jump": false})
			var land: Vector2i = Vector2i(step.x + d.x, step.y + d.y)
			if _in_bounds(land) and _marble_at(land) == "" and _marble_at(step) != "":
				moves.append({"marble": idx, "to": land, "is_jump": true})
	return moves


func _best_jump_from(cell: Vector2i, owner: String) -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var best_progress: int = -999999
	for d: Vector2i in DIRS:
		var mid: Vector2i = _neighbor_in_dir(cell, d)
		var land: Vector2i = Vector2i(mid.x + d.x, mid.y + d.y)
		if _in_bounds(land) and _marble_at(land) == "" and _marble_at(mid) != "":
			var p: int = _progress(land, owner)
			if p > best_progress:
				best_progress = p
				best = land
	return best


func _bot_take_turn() -> void:
	var moves: Array = _gather_candidate_moves("bot")
	if moves.is_empty():
		_after_move("bot")
		return

	var chosen: Dictionary = moves[0]
	if difficulty == "easy":
		chosen = moves[randi() % moves.size()]
	else:
		var best_progress: int = -999999
		for m: Dictionary in moves:
			var p: int = _progress(m["to"], "bot")
			if p > best_progress:
				best_progress = p
				chosen = m

	var idx: int = chosen["marble"]
	_apply_single_move("bot", idx, chosen["to"])
	_redraw_all()
	await get_tree().create_timer(0.3).timeout

	if chosen["is_jump"] and difficulty != "easy":
		var current: Vector2i = chosen["to"]
		var hops := 0
		while hops < 6:
			var next: Vector2i = _best_jump_from(current, "bot")
			if next == Vector2i(-1, -1):
				break
			var gain: int = _progress(next, "bot") - _progress(current, "bot")
			if difficulty == "medium" and gain <= 0:
				break
			_apply_single_move("bot", idx, next)
			_redraw_all()
			await get_tree().create_timer(0.3).timeout
			current = next
			hops += 1

	_after_move("bot")


func _end_game(owner: String) -> void:
	game_over = true
	if mode == "pve":
		if owner == "player":
			status_label.text = "¡Ganaste! Llevaste tus 10 fichas al otro lado"
			status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT_3)
			_record_result("wins")
		else:
			status_label.text = "Ganó la máquina"
			status_label.add_theme_color_override("font_color", UIKit.COLOR_DANGER)
			_record_result("losses")
	else:
		var label: String = "Jugador 1 (rosa)" if owner == "player" else "Jugador 2 (teal)"
		status_label.text = "¡Ganó %s!" % label
		status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT_3)
	_redraw_all()


func _record_result(key: String) -> void:
	var stats: Dictionary = SaveManager.get_game_data(GAME_ID)
	stats[key] = stats.get(key, 0) + 1
	SaveManager.set_game_data(GAME_ID, stats)


func _redraw_all() -> void:
	end_chain_btn.disabled = not (moved_this_turn and not game_over and (mode == "pvp" or current_turn == "player"))

	for q in range(N + 1):
		for r in range(N + 1):
			var cell: Vector2i = Vector2i(q, r)
			var btn: Button = cell_buttons[cell]
			var occupant: String = _marble_at(cell)
			var is_selected: bool = cell == selected

			var bg: Color = UIKit.COLOR_BG_LIGHT
			if home_cells["player"].has(cell):
				bg = UIKit.COLOR_ACCENT.lerp(UIKit.COLOR_BG, 0.75)
			elif home_cells["bot"].has(cell):
				bg = UIKit.COLOR_ACCENT_2.lerp(UIKit.COLOR_BG, 0.75)

			var border: Color = UIKit.COLOR_ACCENT_3 if is_selected else Color(0, 0, 0, 0)
			var bw: int = 3 if is_selected else 0
			var sb: StyleBoxFlat = UIKit.stylebox(bg, border, 4, bw)
			btn.add_theme_stylebox_override("normal", sb)
			btn.add_theme_stylebox_override("disabled", sb)
			btn.disabled = false

			if occupant == "":
				btn.text = ""
			else:
				btn.text = "●"
				var color: Color = UIKit.COLOR_ACCENT if occupant == "player" else UIKit.COLOR_ACCENT_2
				btn.add_theme_color_override("font_color", color)
				btn.add_theme_color_override("font_disabled_color", color)
