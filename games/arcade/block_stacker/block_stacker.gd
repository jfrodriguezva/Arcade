extends Control
## Bloques que caen (estilo Tetris clásico): 7 piezas, rotación con
## pequeño "wall kick", líneas completas se limpian, la velocidad de
## caída sube por nivel. 10 niveles, cada 10 líneas se sube de nivel;
## se gana al llegar a 100 líneas.

const GAME_ID := "block_stacker"
const COLS := 10
const ROWS := 20
const CELL := 32.0
const MAX_LEVEL := 10
const LINES_PER_LEVEL := 10
const LINES_TO_WIN := 100

const BASE_SHAPES := {
	"I": [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)],
	"O": [Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2), Vector2i(2, 2)],
	"T": [Vector2i(1, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)],
	"S": [Vector2i(1, 1), Vector2i(2, 1), Vector2i(0, 2), Vector2i(1, 2)],
	"Z": [Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 2)],
	"J": [Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)],
	"L": [Vector2i(2, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)],
}
const PIECE_COLORS := {
	"I": Color(0.2, 0.8, 0.9), "O": Color(0.95, 0.85, 0.2), "T": Color(0.65, 0.3, 0.85),
	"S": Color(0.35, 0.75, 0.35), "Z": Color(0.9, 0.3, 0.3), "J": Color(0.3, 0.45, 0.9), "L": Color(0.95, 0.55, 0.2),
}
const LINE_SCORE := [0, 100, 300, 500, 800]

const HELP_TEXT := "Las piezas caen solas; acomódalas para completar filas horizontales sin dejar huecos.

- ◀ / ▶ mueven la pieza.
- 🔄 la rota.
- ⬇ (mantén presionado) la hace caer más rápido.
- ⏬ la deja caer al fondo de una vez.

Cada línea completa desaparece y suma puntos (más líneas de una vez = más puntos). Cada 10 líneas subes de nivel y la caída se acelera, hasta el nivel 10. Ganas al llegar a 100 líneas; pierdes si las piezas llegan hasta arriba."

var grid: Array = []
var cell_views: Array = []

var piece_type: String = ""
var piece_rot: int = 0
var piece_pos: Vector2i = Vector2i.ZERO
var piece_color: Color = Color.WHITE
var next_type: String = ""

var fall_timer: float = 0.0
var fall_interval: float = 1.0
var soft_dropping: bool = false
var score: int = 0
var lines_cleared: int = 0
var level: int = 1
var state: String = "playing"

var score_label: Label
var level_label: Label
var next_label: Label
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
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 20)
	scroll.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	UIKit.build_toolbar(vbox, self, "Bloques", HELP_TEXT)

	var hud := HBoxContainer.new()
	hud.alignment = BoxContainer.ALIGNMENT_CENTER
	hud.add_theme_constant_override("separation", 24)
	vbox.add_child(hud)
	score_label = UIKit.title_label("Puntos: 0", 15, UIKit.COLOR_TEXT)
	hud.add_child(score_label)
	level_label = UIKit.title_label("Nivel: 1/10", 15, UIKit.COLOR_ACCENT)
	hud.add_child(level_label)
	next_label = UIKit.title_label("Siguiente: -", 15, UIKit.COLOR_ACCENT_2)
	hud.add_child(next_label)

	status_label = UIKit.title_label("", 14, UIKit.COLOR_TEXT_DIM)
	vbox.add_child(status_label)

	var board_panel := PanelContainer.new()
	board_panel.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_PANEL, UIKit.COLOR_ACCENT_3, 12, 2))
	vbox.add_child(board_panel)
	var board_margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		board_margin.add_theme_constant_override(side, 6)
	board_panel.add_child(board_margin)

	var grid_container := GridContainer.new()
	grid_container.columns = COLS
	grid_container.add_theme_constant_override("h_separation", 1)
	grid_container.add_theme_constant_override("v_separation", 1)
	board_margin.add_child(grid_container)

	for y in range(ROWS):
		var row: Array = []
		for x in range(COLS):
			var cell := Panel.new()
			cell.custom_minimum_size = Vector2(CELL, CELL)
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			grid_container.add_child(cell)
			row.append(cell)
		cell_views.append(row)

	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 8)
	vbox.add_child(controls)

	var left_btn := _make_control_button("◀")
	left_btn.pressed.connect(_on_left_pressed)
	controls.add_child(left_btn)

	var rotate_btn := _make_control_button("🔄")
	rotate_btn.pressed.connect(_try_rotate)
	controls.add_child(rotate_btn)

	var right_btn := _make_control_button("▶")
	right_btn.pressed.connect(_on_right_pressed)
	controls.add_child(right_btn)

	var soft_btn := _make_control_button("⬇")
	soft_btn.button_down.connect(func() -> void: soft_dropping = true)
	soft_btn.button_up.connect(func() -> void: soft_dropping = false)
	controls.add_child(soft_btn)

	var hard_btn := _make_control_button("⏬")
	hard_btn.pressed.connect(_hard_drop)
	controls.add_child(hard_btn)

	var restart_btn := Button.new()
	restart_btn.text = "↻  Nueva partida"
	restart_btn.custom_minimum_size = Vector2(200, 48)
	UIKit.style_button(restart_btn, UIKit.COLOR_ACCENT_3)
	restart_btn.pressed.connect(_new_game)
	vbox.add_child(restart_btn)


func _make_control_button(label: String) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(64, 64)
	btn.add_theme_font_size_override("font_size", 22)
	UIKit.style_button(btn, UIKit.COLOR_ACCENT_2)
	return btn


func _empty_row() -> Array:
	var row: Array = []
	for x in range(COLS):
		row.append(null)
	return row


func _new_game() -> void:
	grid = []
	for y in range(ROWS):
		grid.append(_empty_row())

	score = 0
	lines_cleared = 0
	level = 1
	fall_interval = 1.0
	fall_timer = 0.0
	state = "playing"
	next_type = _random_type()
	status_label.text = ""
	_update_hud()
	_spawn_piece()


func _update_hud() -> void:
	score_label.text = "Puntos: %d" % score
	level_label.text = "Nivel: %d/%d (%d líneas)" % [level, MAX_LEVEL, lines_cleared]
	next_label.text = "Siguiente: %s" % next_type


func _random_type() -> String:
	var keys: Array = BASE_SHAPES.keys()
	return keys[randi() % keys.size()]


func _shape_for(type: String, rot: int) -> Array:
	var shape: Array = BASE_SHAPES[type].duplicate()
	for i in range(((rot % 4) + 4) % 4):
		var rotated: Array = []
		for cell: Vector2i in shape:
			rotated.append(Vector2i(3 - cell.y, cell.x))
		shape = rotated
	return shape


func _can_place(type: String, rot: int, pos: Vector2i) -> bool:
	for cell: Vector2i in _shape_for(type, rot):
		var gx: int = pos.x + cell.x
		var gy: int = pos.y + cell.y
		if gx < 0 or gx >= COLS or gy >= ROWS:
			return false
		if gy >= 0 and grid[gy][gx] != null:
			return false
	return true


func _spawn_piece() -> void:
	piece_type = next_type
	next_type = _random_type()
	piece_rot = 0
	piece_pos = Vector2i(3, -1)
	piece_color = PIECE_COLORS[piece_type]
	_update_hud()

	if not _can_place(piece_type, piece_rot, piece_pos):
		_game_over()
		return
	_redraw_grid()


func _on_left_pressed() -> void:
	if _try_move(-1, 0):
		_redraw_grid()


func _on_right_pressed() -> void:
	if _try_move(1, 0):
		_redraw_grid()


func _try_move(dx: int, dy: int) -> bool:
	if state != "playing":
		return false
	var new_pos: Vector2i = piece_pos + Vector2i(dx, dy)
	if _can_place(piece_type, piece_rot, new_pos):
		piece_pos = new_pos
		return true
	return false


func _try_rotate() -> void:
	if state != "playing":
		return
	var new_rot: int = (piece_rot + 1) % 4
	for kick in [0, -1, 1, -2, 2]:
		var new_pos: Vector2i = piece_pos + Vector2i(kick, 0)
		if _can_place(piece_type, new_rot, new_pos):
			piece_rot = new_rot
			piece_pos = new_pos
			_redraw_grid()
			return


func _hard_drop() -> void:
	if state != "playing":
		return
	while _try_move(0, 1):
		pass
	_lock_piece()


func _lock_piece() -> void:
	for cell: Vector2i in _shape_for(piece_type, piece_rot):
		var gy: int = piece_pos.y + cell.y
		var gx: int = piece_pos.x + cell.x
		if gy >= 0:
			grid[gy][gx] = piece_color
	_clear_lines()
	if state == "playing":
		_spawn_piece()
	else:
		_redraw_grid()


func _clear_lines() -> void:
	var cleared := 0
	var y := ROWS - 1
	while y >= 0:
		var full := true
		for x in range(COLS):
			if grid[y][x] == null:
				full = false
				break
		if full:
			grid.remove_at(y)
			grid.insert(0, _empty_row())
			cleared += 1
		else:
			y -= 1

	if cleared > 0:
		lines_cleared += cleared
		score += LINE_SCORE[cleared] * level
		level = min(1 + int(lines_cleared / LINES_PER_LEVEL), MAX_LEVEL)
		fall_interval = max(0.12, 1.0 - (level - 1) * 0.085)
		_update_hud()
		if lines_cleared >= LINES_TO_WIN:
			_win()


func _process(delta: float) -> void:
	if state != "playing":
		return

	var interval: float = fall_interval * (0.12 if soft_dropping else 1.0)
	fall_timer += delta
	if fall_timer >= interval:
		fall_timer = 0.0
		if _try_move(0, 1):
			_redraw_grid()
		else:
			_lock_piece()


func _redraw_grid() -> void:
	for y in range(ROWS):
		for x in range(COLS):
			_style_cell(cell_views[y][x], grid[y][x])

	for cell: Vector2i in _shape_for(piece_type, piece_rot):
		var gy: int = piece_pos.y + cell.y
		var gx: int = piece_pos.x + cell.x
		if gy >= 0 and gy < ROWS and gx >= 0 and gx < COLS:
			_style_cell(cell_views[gy][gx], piece_color)


func _style_cell(view: Panel, color: Variant) -> void:
	if color == null:
		view.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_BG_LIGHT, Color(0, 0, 0, 0), 2))
	else:
		view.add_theme_stylebox_override("panel", UIKit.stylebox(color, Color(0, 0, 0, 0), 2))


func _game_over() -> void:
	state = "game_over"
	status_label.text = "Game Over. Puntos: %d" % score
	status_label.add_theme_color_override("font_color", UIKit.COLOR_DANGER)
	_record_result(false)


func _win() -> void:
	state = "won"
	status_label.text = "¡Llegaste a %d líneas! Puntos: %d" % [LINES_TO_WIN, score]
	status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT_3)
	_record_result(true)


func _record_result(won: bool) -> void:
	AudioManager.play_win() if won else AudioManager.play_lose()
	var stats: Dictionary = SaveManager.get_game_data(GAME_ID)
	var key: String = "wins" if won else "losses"
	stats[key] = stats.get(key, 0) + 1
	stats["best_score"] = max(stats.get("best_score", 0), score)
	SaveManager.set_game_data(GAME_ID, stats)
