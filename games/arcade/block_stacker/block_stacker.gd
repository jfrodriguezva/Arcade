extends Control
## Bloques que caen (estilo Tetris clásico): 7 piezas, rotación con
## pequeño "wall kick", líneas completas se limpian, la velocidad de
## caída sube por nivel. 10 niveles, cada 10 líneas se sube de nivel;
## se gana al llegar a 100 líneas.

const GAME_ID := "block_stacker"
const COLS := 10
const ROWS := 20
const CELL := 44.0
const NEXT_CELL := 20.0
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
- 🔀 la guarda para usarla después (una vez por pieza): la primera vez saca la siguiente, luego intercambia.

El contorno tenue debajo de la pieza muestra dónde caerá si usas ⏬. El panel \"Siguiente\" te enseña la próxima pieza con anticipación, y \"Guardada\" la que dejaste en reserva. Las piezas salen en \"bolsas\" de las 7 formas sin repetir, como en el Tetris moderno — nunca hay una sequía larga de una pieza.

Cada línea completa desaparece y suma puntos (más líneas de una vez = más puntos). Cada 10 líneas subes de nivel y la caída se acelera, hasta el nivel 10. Ganas al llegar a 100 líneas; pierdes si las piezas llegan hasta arriba."

var grid: Array = []
var cell_views: Array = []
var next_preview_views: Array = []
var hold_preview_views: Array = []

var piece_type: String = ""
var piece_rot: int = 0
var piece_pos: Vector2i = Vector2i.ZERO
var piece_color: Color = Color.WHITE
var next_type: String = ""
var held_type: String = ""
var can_hold: bool = true
var bag: Array = []

var fall_timer: float = 0.0
var fall_interval: float = 1.0
var soft_dropping: bool = false
var score: int = 0
var lines_cleared: int = 0
var level: int = 1
var state: String = "playing"

var score_label: Label
var level_label: Label
var lines_label: Label
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
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	UIKit.build_toolbar(vbox, self, "Bloques", HELP_TEXT)

	var main_row := HBoxContainer.new()
	main_row.alignment = BoxContainer.ALIGNMENT_CENTER
	main_row.add_theme_constant_override("separation", 14)
	vbox.add_child(main_row)

	# --- Tablero ---
	var board_panel := PanelContainer.new()
	board_panel.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_PANEL, UIKit.COLOR_ACCENT_3, 12, 2))
	main_row.add_child(board_panel)
	var board_margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		board_margin.add_theme_constant_override(side, 6)
	board_panel.add_child(board_margin)

	var grid_container := GridContainer.new()
	grid_container.columns = COLS
	grid_container.add_theme_constant_override("h_separation", 2)
	grid_container.add_theme_constant_override("v_separation", 2)
	board_margin.add_child(grid_container)

	var bevel: float = max(2.0, CELL * 0.14)
	for y in range(ROWS):
		var row: Array = []
		for x in range(COLS):
			row.append(_make_grid_cell(grid_container, bevel))
		cell_views.append(row)

	# --- Columna lateral: puntuación + siguiente pieza ---
	var side_col := VBoxContainer.new()
	side_col.add_theme_constant_override("separation", 10)
	side_col.custom_minimum_size = Vector2(150, 0)
	main_row.add_child(side_col)

	score_label = _make_stat_chip(side_col, "Puntos: 0", UIKit.COLOR_TEXT)
	level_label = _make_stat_chip(side_col, "Nivel 1/10", UIKit.COLOR_ACCENT)
	lines_label = _make_stat_chip(side_col, "0 líneas", UIKit.COLOR_ACCENT_2)

	var next_panel := PanelContainer.new()
	next_panel.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_PANEL, UIKit.COLOR_ACCENT_2, 10, 2))
	side_col.add_child(next_panel)
	var next_margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		next_margin.add_theme_constant_override(side, 8)
	next_panel.add_child(next_margin)
	var next_vbox := VBoxContainer.new()
	next_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	next_vbox.add_theme_constant_override("separation", 6)
	next_margin.add_child(next_vbox)
	next_vbox.add_child(UIKit.title_label("SIGUIENTE", 11, UIKit.COLOR_TEXT_DIM))

	var next_grid := GridContainer.new()
	next_grid.columns = 4
	next_grid.add_theme_constant_override("h_separation", 1)
	next_grid.add_theme_constant_override("v_separation", 1)
	next_vbox.add_child(next_grid)
	for y in range(4):
		var nrow: Array = []
		for x in range(4):
			var c := Panel.new()
			c.custom_minimum_size = Vector2(NEXT_CELL, NEXT_CELL)
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
			next_grid.add_child(c)
			nrow.append(c)
		next_preview_views.append(nrow)

	var hold_panel := PanelContainer.new()
	hold_panel.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_PANEL, UIKit.COLOR_ACCENT, 10, 2))
	side_col.add_child(hold_panel)
	var hold_margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		hold_margin.add_theme_constant_override(side, 8)
	hold_panel.add_child(hold_margin)
	var hold_vbox := VBoxContainer.new()
	hold_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hold_vbox.add_theme_constant_override("separation", 6)
	hold_margin.add_child(hold_vbox)
	hold_vbox.add_child(UIKit.title_label("GUARDADA", 11, UIKit.COLOR_TEXT_DIM))

	var hold_grid := GridContainer.new()
	hold_grid.columns = 4
	hold_grid.add_theme_constant_override("h_separation", 1)
	hold_grid.add_theme_constant_override("v_separation", 1)
	hold_vbox.add_child(hold_grid)
	for y in range(4):
		var hrow: Array = []
		for x in range(4):
			var c := Panel.new()
			c.custom_minimum_size = Vector2(NEXT_CELL, NEXT_CELL)
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hold_grid.add_child(c)
			hrow.append(c)
		hold_preview_views.append(hrow)

	status_label = UIKit.title_label("", 14, UIKit.COLOR_TEXT_DIM)
	vbox.add_child(status_label)

	# --- Controles: cluster de movimiento + cluster de acción ---
	var controls_row := HBoxContainer.new()
	controls_row.alignment = BoxContainer.ALIGNMENT_CENTER
	controls_row.add_theme_constant_override("separation", 18)
	vbox.add_child(controls_row)

	var left_btn := _make_control_button("◀", UIKit.COLOR_ACCENT_2, Vector2(64, 64), 22)
	left_btn.pressed.connect(_on_left_pressed)

	var rotate_btn := _make_control_button("🔄", UIKit.COLOR_ACCENT_2, Vector2(64, 64), 22)
	rotate_btn.pressed.connect(_try_rotate)

	var right_btn := _make_control_button("▶", UIKit.COLOR_ACCENT_2, Vector2(64, 64), 22)
	right_btn.pressed.connect(_on_right_pressed)

	controls_row.add_child(_build_cluster("MOVER", [left_btn, rotate_btn, right_btn]))

	var soft_btn := _make_control_button("⬇", UIKit.COLOR_ACCENT_2, Vector2(64, 64), 22)
	soft_btn.button_down.connect(func() -> void: soft_dropping = true)
	soft_btn.button_up.connect(func() -> void: soft_dropping = false)

	var hard_btn := _make_control_button("⏬", UIKit.COLOR_ACCENT, Vector2(92, 72), 28)
	hard_btn.pressed.connect(_hard_drop)

	controls_row.add_child(_build_cluster("ACCIÓN", [soft_btn, hard_btn]))

	var hold_btn := _make_control_button("🔀", UIKit.COLOR_TEXT_DIM, Vector2(64, 64), 24)
	hold_btn.pressed.connect(_on_hold_pressed)
	controls_row.add_child(_build_cluster("GUARDAR", [hold_btn]))

	var restart_btn := Button.new()
	restart_btn.text = "🔁  Nueva partida"
	restart_btn.custom_minimum_size = Vector2(200, 48)
	UIKit.style_button(restart_btn, UIKit.COLOR_ACCENT_3)
	restart_btn.pressed.connect(_new_game)
	vbox.add_child(restart_btn)


func _make_grid_cell(grid_container: GridContainer, bevel: float) -> Dictionary:
	var cell := Panel.new()
	cell.custom_minimum_size = Vector2(CELL, CELL)
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.clip_contents = true
	grid_container.add_child(cell)

	var top := ColorRect.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.anchor_left = 0.0; top.anchor_right = 1.0; top.anchor_top = 0.0; top.anchor_bottom = 0.0
	top.offset_bottom = bevel
	cell.add_child(top)

	var left := ColorRect.new()
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.anchor_left = 0.0; left.anchor_right = 0.0; left.anchor_top = 0.0; left.anchor_bottom = 1.0
	left.offset_right = bevel
	cell.add_child(left)

	var bottom := ColorRect.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.anchor_left = 0.0; bottom.anchor_right = 1.0; bottom.anchor_top = 1.0; bottom.anchor_bottom = 1.0
	bottom.offset_top = -bevel
	cell.add_child(bottom)

	var right := ColorRect.new()
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.anchor_left = 1.0; right.anchor_right = 1.0; right.anchor_top = 0.0; right.anchor_bottom = 1.0
	right.offset_left = -bevel
	cell.add_child(right)

	var view: Dictionary = {"panel": cell, "top": top, "left": left, "bottom": bottom, "right": right}
	_style_cell(view, null)
	return view


func _make_stat_chip(parent: Control, text: String, color: Color) -> Label:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_PANEL, color, 10, 2))
	parent.add_child(panel)
	var m := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		m.add_theme_constant_override(side, 8)
	panel.add_child(m)
	var lbl := UIKit.title_label(text, 13, color)
	m.add_child(lbl)
	return lbl


func _build_cluster(caption: String, buttons: Array) -> Control:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 6)
	col.add_child(UIKit.title_label(caption, 10, UIKit.COLOR_TEXT_DIM))

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_PANEL, Color(1, 1, 1, 0.08), 16, 1))
	col.add_child(panel)

	var pad := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		pad.add_theme_constant_override(side, 8)
	panel.add_child(pad)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	pad.add_child(row)
	for b: Button in buttons:
		row.add_child(b)

	return col


func _make_control_button(label: String, color: Color, size: Vector2, font_size: int) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = size
	btn.add_theme_font_size_override("font_size", font_size)
	UIKit.style_button(btn, color)
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
	bag = []
	held_type = ""
	can_hold = true
	next_type = _draw_from_bag()
	status_label.text = ""
	_update_hud()
	_spawn_piece()


func _update_hud() -> void:
	score_label.text = "Puntos: %d" % score
	level_label.text = "Nivel %d/%d" % [level, MAX_LEVEL]
	lines_label.text = "%d líneas" % lines_cleared
	_update_next_preview()


func _update_next_preview() -> void:
	_draw_preview(next_preview_views, next_type)
	_draw_preview(hold_preview_views, held_type)


func _draw_preview(views: Array, type: String) -> void:
	if views.is_empty():
		return
	var filled: Dictionary = {}
	if type != "":
		for cell: Vector2i in BASE_SHAPES[type]:
			filled[cell] = true
	var color: Color = PIECE_COLORS.get(type, Color.WHITE)
	for y in range(4):
		for x in range(4):
			var view: Panel = views[y][x]
			if filled.has(Vector2i(x, y)):
				view.add_theme_stylebox_override("panel", UIKit.stylebox(color, color.darkened(0.45), 3, 1))
			else:
				view.add_theme_stylebox_override("panel", UIKit.stylebox(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 3))


func _refill_bag() -> void:
	## Bolsa de 7: cada una de las 7 piezas sale exactamente una vez por
	## bolsa (barajada), como el Tetris moderno — evita las sequías largas
	## de una pieza que un random puro sí puede producir.
	bag = BASE_SHAPES.keys()
	bag.shuffle()


func _draw_from_bag() -> String:
	if bag.is_empty():
		_refill_bag()
	return bag.pop_front()


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


func _ghost_landing_pos() -> Vector2i:
	## Reutiliza la misma regla de colisión que usan el movimiento y el hard drop:
	## baja la pieza hasta el último punto donde todavía es válida.
	var pos: Vector2i = piece_pos
	while _can_place(piece_type, piece_rot, pos + Vector2i(0, 1)):
		pos += Vector2i(0, 1)
	return pos


func _spawn_piece() -> void:
	piece_type = next_type
	next_type = _draw_from_bag()
	piece_rot = 0
	piece_pos = Vector2i(3, -1)
	piece_color = PIECE_COLORS[piece_type]
	can_hold = true
	_update_hud()

	if not _can_place(piece_type, piece_rot, piece_pos):
		_game_over()
		return
	_redraw_grid()


func _on_hold_pressed() -> void:
	## Guarda la pieza actual para usarla después, o la intercambia con la
	## que ya tenías guardada — solo una vez por pieza (se rehabilita en
	## _spawn_piece) para evitar el truco de alternar infinitamente.
	if state != "playing" or not can_hold:
		return
	can_hold = false
	if held_type == "":
		held_type = piece_type
		piece_type = next_type
		next_type = _draw_from_bag()
	else:
		var tmp: String = held_type
		held_type = piece_type
		piece_type = tmp
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

	# Bloqueamos brevemente la entrada mientras se ve la pieza fijada y,
	# si corresponde, el flash de líneas completas antes de colapsarlas.
	state = "locking"
	_redraw_grid()
	await _clear_lines()
	if state == "locking":
		state = "playing"

	if state == "playing":
		_spawn_piece()
	else:
		_redraw_grid()


func _clear_lines() -> void:
	var full_rows: Array = []
	for y in range(ROWS):
		var full := true
		for x in range(COLS):
			if grid[y][x] == null:
				full = false
				break
		if full:
			full_rows.append(y)

	if full_rows.is_empty():
		return

	await _flash_rows(full_rows)

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

	lines_cleared += cleared
	score += LINE_SCORE[cleared] * level
	level = min(1 + int(lines_cleared / LINES_PER_LEVEL), MAX_LEVEL)
	fall_interval = max(0.12, 1.0 - (level - 1) * 0.085)
	_update_hud()
	_redraw_grid()
	if lines_cleared >= LINES_TO_WIN:
		_win()


func _flash_rows(rows: Array) -> void:
	## Destello blanco rápido (~180ms) sobre las filas completas antes de
	## colapsarlas, para que el jugador note claramente qué se limpió.
	var flash_boxes: Array = []
	for row_y in rows:
		for x in range(COLS):
			var view: Dictionary = cell_views[row_y][x]
			var panel: Panel = view["panel"]
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(1, 1, 1, 1)
			sb.set_corner_radius_all(3)
			panel.add_theme_stylebox_override("panel", sb)
			_set_bevel_visible(view, false)
			flash_boxes.append(sb)

	var tween := create_tween()
	tween.set_parallel(true)
	for sb: StyleBoxFlat in flash_boxes:
		tween.tween_property(sb, "bg_color", Color(1, 1, 1, 0.0), 0.18).set_ease(Tween.EASE_OUT)
	await tween.finished


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

	if state != "playing":
		return

	var piece_cells: Array = _shape_for(piece_type, piece_rot)

	var ghost_pos: Vector2i = _ghost_landing_pos()
	if ghost_pos != piece_pos:
		for cell: Vector2i in piece_cells:
			var gy: int = ghost_pos.y + cell.y
			var gx: int = ghost_pos.x + cell.x
			if gy >= 0 and gy < ROWS and gx >= 0 and gx < COLS and grid[gy][gx] == null:
				_style_ghost_cell(cell_views[gy][gx], piece_color)

	for cell: Vector2i in piece_cells:
		var gy: int = piece_pos.y + cell.y
		var gx: int = piece_pos.x + cell.x
		if gy >= 0 and gy < ROWS and gx >= 0 and gx < COLS:
			_style_cell(cell_views[gy][gx], piece_color)


func _set_bevel_visible(view: Dictionary, vis: bool) -> void:
	view["top"].visible = vis
	view["left"].visible = vis
	view["bottom"].visible = vis
	view["right"].visible = vis


func _style_cell(view: Dictionary, color: Variant) -> void:
	var panel: Panel = view["panel"]
	if color == null:
		panel.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_BG_LIGHT.darkened(0.3), Color(1, 1, 1, 0.05), 3, 1))
		_set_bevel_visible(view, false)
		return

	var c: Color = color
	panel.add_theme_stylebox_override("panel", UIKit.stylebox(c.darkened(0.1), c.darkened(0.55), 3, 1))
	view["top"].color = c.lightened(0.45)
	view["left"].color = c.lightened(0.22)
	view["bottom"].color = c.darkened(0.42)
	view["right"].color = c.darkened(0.42)
	_set_bevel_visible(view, true)


func _style_ghost_cell(view: Dictionary, color: Color) -> void:
	var panel: Panel = view["panel"]
	panel.add_theme_stylebox_override("panel", UIKit.stylebox(Color(color.r, color.g, color.b, 0.14), Color(color.r, color.g, color.b, 0.7), 3, 2))
	_set_bevel_visible(view, false)


func _game_over() -> void:
	state = "game_over"
	status_label.text = "Game Over. Puntos: %d" % score
	status_label.add_theme_color_override("font_color", UIKit.COLOR_DANGER)
	_redraw_grid()
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
