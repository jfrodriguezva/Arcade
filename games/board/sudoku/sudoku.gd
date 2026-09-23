extends Control
## Sudoku clásico 9x9 con generador aleatorio y 3 niveles de dificultad
## (controlan cuántas celdas se dan como pista). Retroalimentación
## instantánea: lo que escribes se compara contra la solución interna.

const GAME_ID := "sudoku"

const HELP_TEXT := "Completa la cuadrícula 9x9 con números del 1 al 9, sin repetir número en ninguna fila, columna, ni bloque de 3x3.

- Toca una celda vacía para seleccionarla.
- Toca un número del teclado de abajo para escribirlo (o ⌫ para borrar).
- Los números correctos se muestran en blanco; si te equivocas se muestran en rojo como pista.
- Tienes hasta 5 errores; al llegar al quinto, pierdes esa partida.

La dificultad controla cuántas celdas vienen ya llenas al empezar: más pistas = más fácil."

const MAX_MISTAKES := 5

var solution: Array = []
var puzzle: Array = []
var given: Array = []
var selected_index: int = -1
var difficulty: String = "medium"
var game_over: bool = false
var mistakes: int = 0

var status_label: Label
var mistakes_label: Label
var cell_buttons: Array = []


func _ready() -> void:
	_build_ui()
	UIKit.show_setup_overlay(self, "Sudoku", false, true, _on_setup_confirmed)


func _on_setup_confirmed(config: Dictionary) -> void:
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
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	UIKit.build_toolbar(vbox, self, "Sudoku", HELP_TEXT)

	status_label = UIKit.title_label("", 18, UIKit.COLOR_TEXT)
	vbox.add_child(status_label)

	mistakes_label = UIKit.title_label("", 15, UIKit.COLOR_TEXT_DIM)
	vbox.add_child(mistakes_label)

	var board_panel := PanelContainer.new()
	board_panel.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_PANEL, UIKit.COLOR_ACCENT_3, 16, 3))
	var board_margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		board_margin.add_theme_constant_override(side, 10)
	board_panel.add_child(board_margin)

	var center := CenterContainer.new()
	vbox.add_child(center)
	center.add_child(board_panel)

	var outer_grid := GridContainer.new()
	outer_grid.columns = 3
	outer_grid.add_theme_constant_override("h_separation", 4)
	outer_grid.add_theme_constant_override("v_separation", 4)
	board_margin.add_child(outer_grid)

	cell_buttons.resize(81)
	for box_index in range(9):
		var box_row: int = (box_index / 3) * 3
		var box_col: int = (box_index % 3) * 3

		var box_panel := PanelContainer.new()
		box_panel.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_BG, Color(0, 0, 0, 0), 4))
		outer_grid.add_child(box_panel)

		var box_grid := GridContainer.new()
		box_grid.columns = 3
		box_grid.add_theme_constant_override("h_separation", 2)
		box_grid.add_theme_constant_override("v_separation", 2)
		box_panel.add_child(box_grid)

		for local_r in range(3):
			for local_c in range(3):
				var row: int = box_row + local_r
				var col: int = box_col + local_c
				var index: int = row * 9 + col
				var cell := Button.new()
				cell.custom_minimum_size = Vector2(58, 58)
				cell.add_theme_font_size_override("font_size", 26)
				UIKit.style_button(cell, UIKit.COLOR_BG_LIGHT, 4)
				cell.pressed.connect(_on_cell_pressed.bind(index))
				box_grid.add_child(cell)
				cell_buttons[index] = cell

	var numpad := HBoxContainer.new()
	numpad.alignment = BoxContainer.ALIGNMENT_CENTER
	numpad.add_theme_constant_override("separation", 4)
	vbox.add_child(numpad)

	for n in range(1, 10):
		var btn := Button.new()
		btn.text = str(n)
		btn.custom_minimum_size = Vector2(48, 48)
		UIKit.style_button(btn, UIKit.COLOR_ACCENT_2, 8)
		btn.pressed.connect(_on_number_pressed.bind(n))
		numpad.add_child(btn)

	var erase_btn := Button.new()
	erase_btn.text = "⌫"
	erase_btn.custom_minimum_size = Vector2(48, 48)
	UIKit.style_button(erase_btn, UIKit.COLOR_TEXT_DIM, 8)
	erase_btn.pressed.connect(_on_number_pressed.bind(0))
	numpad.add_child(erase_btn)

	var restart_btn := Button.new()
	restart_btn.text = "↻  Nuevo Sudoku / Dificultad"
	restart_btn.custom_minimum_size = Vector2(260, 48)
	UIKit.style_button(restart_btn, UIKit.COLOR_ACCENT_3)
	restart_btn.pressed.connect(func() -> void: UIKit.show_setup_overlay(self, "Sudoku", false, true, _on_setup_confirmed))
	vbox.add_child(restart_btn)


func _new_game() -> void:
	solution = _generate_solution()
	var keep: int = 40
	match difficulty:
		"easy": keep = 42
		"medium": keep = 32
		"hard": keep = 26
	puzzle = _make_puzzle(solution, keep)
	given = []
	for v: int in puzzle:
		given.append(v != 0)

	selected_index = -1
	game_over = false
	mistakes = 0
	status_label.text = "Completa la cuadrícula"
	status_label.add_theme_color_override("font_color", UIKit.COLOR_TEXT)
	_update_mistakes_label()
	_redraw_all()


func _generate_solution() -> Array:
	var grid: Array = []
	for i in range(81):
		grid.append(0)
	_fill_grid(grid, 0)
	return grid


func _fill_grid(grid: Array, pos: int) -> bool:
	if pos == 81:
		return true
	var row: int = pos / 9
	var col: int = pos % 9
	var nums: Array = [1, 2, 3, 4, 5, 6, 7, 8, 9]
	nums.shuffle()
	for n: int in nums:
		if _is_valid_placement(grid, row, col, n):
			grid[pos] = n
			if _fill_grid(grid, pos + 1):
				return true
			grid[pos] = 0
	return false


func _is_valid_placement(grid: Array, row: int, col: int, n: int) -> bool:
	for c in range(9):
		if grid[row * 9 + c] == n:
			return false
	for r in range(9):
		if grid[r * 9 + col] == n:
			return false
	var box_row: int = (row / 3) * 3
	var box_col: int = (col / 3) * 3
	for r in range(box_row, box_row + 3):
		for c in range(box_col, box_col + 3):
			if grid[r * 9 + c] == n:
				return false
	return true


func _make_puzzle(sol: Array, keep: int) -> Array:
	var p: Array = sol.duplicate()
	var indices: Array = []
	for i in range(81):
		indices.append(i)
	indices.shuffle()
	var remove_count: int = 81 - keep
	for i in range(remove_count):
		p[indices[i]] = 0
	return p


func _redraw_all() -> void:
	for i in range(81):
		_redraw_cell(i)


func _redraw_cell(i: int) -> void:
	var cell: Button = cell_buttons[i]
	var value: int = puzzle[i]
	var is_given: bool = given[i]
	var is_selected: bool = i == selected_index

	cell.text = str(value) if value != 0 else ""
	cell.disabled = is_given

	var border: Color = UIKit.COLOR_ACCENT_3 if is_selected else Color(0, 0, 0, 0)
	var bw: int = 3 if is_selected else 0
	var bg: Color = UIKit.COLOR_PANEL if is_given else UIKit.COLOR_BG_LIGHT
	var sb: StyleBoxFlat = UIKit.stylebox(bg, border, 4, bw)
	cell.add_theme_stylebox_override("normal", sb)
	cell.add_theme_stylebox_override("hover", sb)
	cell.add_theme_stylebox_override("disabled", sb)

	if is_given:
		cell.add_theme_color_override("font_disabled_color", UIKit.COLOR_TEXT_DIM)
	elif value != 0 and value != solution[i]:
		cell.add_theme_color_override("font_color", UIKit.COLOR_DANGER)
	else:
		cell.add_theme_color_override("font_color", UIKit.COLOR_TEXT)


func _update_mistakes_label() -> void:
	mistakes_label.text = "Errores: %d/%d" % [mistakes, MAX_MISTAKES]
	mistakes_label.add_theme_color_override("font_color", UIKit.COLOR_DANGER if mistakes > 0 else UIKit.COLOR_TEXT_DIM)


func _on_cell_pressed(index: int) -> void:
	if game_over or given[index]:
		return
	var previous: int = selected_index
	selected_index = -1 if selected_index == index else index
	if previous != -1:
		_redraw_cell(previous)
	_redraw_cell(index)


func _on_number_pressed(n: int) -> void:
	if game_over or selected_index == -1 or given[selected_index]:
		return
	puzzle[selected_index] = n
	if n != 0 and n != solution[selected_index]:
		mistakes += 1
		_update_mistakes_label()

	var i: int = selected_index
	_redraw_cell(i)

	if mistakes >= MAX_MISTAKES:
		_end_game_loss()
		return
	_check_win()


func _check_win() -> void:
	for i in range(81):
		if puzzle[i] != solution[i]:
			return
	game_over = true
	status_label.text = "¡Sudoku completo!"
	status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT_3)
	_record_result("completed_%s" % difficulty)


func _end_game_loss() -> void:
	game_over = true
	status_label.text = "Llegaste a %d errores. ¡Inténtalo de nuevo!" % MAX_MISTAKES
	status_label.add_theme_color_override("font_color", UIKit.COLOR_DANGER)
	_record_result("failed_%s" % difficulty)


func _record_result(key: String) -> void:
	if key.begins_with("win") or key.begins_with("completed"):
		AudioManager.play_win()
	elif key.begins_with("loss") or key.begins_with("fail"):
		AudioManager.play_lose()
	var stats: Dictionary = SaveManager.get_game_data(GAME_ID)
	stats[key] = stats.get(key, 0) + 1
	SaveManager.set_game_data(GAME_ID, stats)
