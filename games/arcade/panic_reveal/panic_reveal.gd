extends Control
## Estilo Qix / Gals Panic: trazas líneas desde el borde seguro hacia
## el área sin revelar para encerrar territorio; al volver al borde,
## esa zona se captura (a menos que un enemigo esté adentro) y revela
## el paisaje procedural de abajo. Si un enemigo toca tu traza antes
## de cerrarla, pierdes una vida.
##
## El "arte a revelar" es configurable por diseño (por ahora paisajes
## procedurales: cielo con degradado, sol y montañas) en vez de fotos,
## para que la mecánica sea reutilizable con cualquier tema de imagen.

const GAME_ID := "panic_reveal"
const GRID_W := 20
const GRID_H := 27
const CELL := 32.0
const MOVE_INTERVAL := 0.09
const CAPTURE_TARGET := 75.0
const MAX_LEVEL := 10
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

const HELP_TEXT := "Tu marcador empieza en el borde (zona segura). Usa las flechas para moverte.

- Mientras estés en el borde o en zona ya capturada, estás a salvo.
- Al entrar a la zona sin revelar, vas dejando una traza. Si un enemigo (rojo) toca tu traza antes de que regreses al borde, pierdes una vida y la traza se borra.
- Al volver a tocar zona segura, el área que encerraste se captura y revela el paisaje de abajo — a menos que haya un enemigo adentro, ese pedazo se queda sin capturar.

Captura el 75% del área para pasar de nivel. Hay 10 niveles, cada uno con más enemigos y más rápidos. Pierdes si se acaban tus 3 vidas."

var grid_state: Array = []
var target_colors: Array = []
var cell_views: Array = []

var player_cell: Vector2i = Vector2i.ZERO
var current_dir: Vector2i = Vector2i.ZERO
var move_timer: float = 0.0
var trail: Array = []

var enemies: Array = []

var score: int = 0
var lives: int = 3
var level: int = 1
var state: String = "playing"

var play_area: Control
var player_view: GamePiece
var score_label: Label
var lives_label: Label
var status_label: Label
var percent_label: Label


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

	UIKit.build_toolbar(vbox, self, "Revela el Paisaje", HELP_TEXT)

	var hud := HBoxContainer.new()
	hud.alignment = BoxContainer.ALIGNMENT_CENTER
	hud.add_theme_constant_override("separation", 22)
	vbox.add_child(hud)
	score_label = UIKit.title_label("Puntos: 0", 14, UIKit.COLOR_TEXT)
	hud.add_child(score_label)
	lives_label = UIKit.title_label("Vidas: 3", 14, UIKit.COLOR_ACCENT)
	hud.add_child(lives_label)
	percent_label = UIKit.title_label("0%", 14, UIKit.COLOR_ACCENT_2)
	hud.add_child(percent_label)

	status_label = UIKit.title_label("Nivel 1", 14, UIKit.COLOR_TEXT_DIM)
	vbox.add_child(status_label)

	var play_panel := PanelContainer.new()
	play_panel.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_PANEL, UIKit.COLOR_ACCENT_3, 10, 2))
	vbox.add_child(play_panel)

	play_area = Control.new()
	play_area.custom_minimum_size = Vector2(GRID_W * CELL, GRID_H * CELL)
	play_area.clip_contents = true
	play_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_panel.add_child(play_area)

	for y in range(GRID_H):
		var row: Array = []
		for x in range(GRID_W):
			var cell := Panel.new()
			cell.position = Vector2(x * CELL, y * CELL)
			cell.size = Vector2(CELL, CELL)
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			play_area.add_child(cell)
			row.append(cell)
		cell_views.append(row)

	player_view = GamePiece.new()
	player_view.size = Vector2(CELL * 0.85, CELL * 0.85)
	player_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_view.set_piece(UIKit.COLOR_TEXT)
	play_area.add_child(player_view)

	var dpad_row1 := HBoxContainer.new()
	dpad_row1.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(dpad_row1)
	var up_btn := _make_dir_button("▲")
	up_btn.button_down.connect(func() -> void: _set_dir(Vector2i(0, -1)))
	up_btn.button_up.connect(func() -> void: _clear_dir(Vector2i(0, -1)))
	dpad_row1.add_child(up_btn)

	var dpad_row2 := HBoxContainer.new()
	dpad_row2.alignment = BoxContainer.ALIGNMENT_CENTER
	dpad_row2.add_theme_constant_override("separation", 60)
	vbox.add_child(dpad_row2)
	var left_btn := _make_dir_button("◀")
	left_btn.button_down.connect(func() -> void: _set_dir(Vector2i(-1, 0)))
	left_btn.button_up.connect(func() -> void: _clear_dir(Vector2i(-1, 0)))
	dpad_row2.add_child(left_btn)
	var right_btn := _make_dir_button("▶")
	right_btn.button_down.connect(func() -> void: _set_dir(Vector2i(1, 0)))
	right_btn.button_up.connect(func() -> void: _clear_dir(Vector2i(1, 0)))
	dpad_row2.add_child(right_btn)

	var dpad_row3 := HBoxContainer.new()
	dpad_row3.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(dpad_row3)
	var down_btn := _make_dir_button("▼")
	down_btn.button_down.connect(func() -> void: _set_dir(Vector2i(0, 1)))
	down_btn.button_up.connect(func() -> void: _clear_dir(Vector2i(0, 1)))
	dpad_row3.add_child(down_btn)

	var restart_btn := Button.new()
	restart_btn.text = "↻  Nueva partida"
	restart_btn.custom_minimum_size = Vector2(200, 48)
	UIKit.style_button(restart_btn, UIKit.COLOR_ACCENT_3)
	restart_btn.pressed.connect(_new_game)
	vbox.add_child(restart_btn)


func _make_dir_button(label: String) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(64, 56)
	btn.add_theme_font_size_override("font_size", 20)
	UIKit.style_button(btn, UIKit.COLOR_ACCENT_2)
	return btn


func _set_dir(d: Vector2i) -> void:
	current_dir = d


func _clear_dir(d: Vector2i) -> void:
	if current_dir == d:
		current_dir = Vector2i.ZERO


func _landscape_color(gx: int, gy: int, lvl: int) -> Color:
	var u: float = float(gx) / float(GRID_W)
	var v: float = float(gy) / float(GRID_H)

	var sun_center := Vector2(0.72, 0.26)
	if Vector2(u, v).distance_to(sun_center) < 0.09:
		return Color(1.0, 0.9, 0.55)

	var mountain_height: float = 0.55 + 0.12 * sin(u * 8.0 + float(lvl))
	if v > mountain_height:
		var shade: float = clamp((v - mountain_height) * 2.0, 0.0, 1.0)
		return Color(0.16, 0.19, 0.29).lerp(Color(0.05, 0.07, 0.14), shade)

	var sky_top := Color(0.2, 0.25, 0.55)
	var sky_bottom := Color(0.95, 0.55, 0.35)
	return sky_top.lerp(sky_bottom, v)


func _new_game() -> void:
	score = 0
	lives = 3
	level = 1
	state = "playing"
	_setup_level()


func _setup_level() -> void:
	grid_state = []
	target_colors = []
	for y in range(GRID_H):
		var row: Array = []
		var color_row: Array = []
		for x in range(GRID_W):
			var is_border: bool = x == 0 or y == 0 or x == GRID_W - 1 or y == GRID_H - 1
			row.append("captured" if is_border else "open")
			color_row.append(_landscape_color(x, y, level))
		grid_state.append(row)
		target_colors.append(color_row)

	player_cell = Vector2i(0, 0)
	current_dir = Vector2i.ZERO
	trail.clear()

	for e: Dictionary in enemies:
		e["view"].queue_free()
	enemies.clear()
	var enemy_count: int = min(1 + level / 2, 6)
	var enemy_interval: float = max(0.10, 0.30 - level * 0.018)
	for i in range(enemy_count):
		var pos := Vector2i(1 + randi() % (GRID_W - 2), 1 + randi() % (GRID_H - 2))
		var view := GamePiece.new()
		view.size = Vector2(CELL * 0.8, CELL * 0.8)
		view.position = Vector2(pos.x * CELL, pos.y * CELL)
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.set_piece(UIKit.COLOR_DANGER)
		play_area.add_child(view)
		enemies.append({"pos": pos, "dir": _random_dir(), "view": view, "interval": enemy_interval, "timer": 0.0})

	status_label.text = "Nivel %d / %d" % [level, MAX_LEVEL]
	_redraw_grid()
	_update_hud()


func _random_dir() -> Vector2i:
	return DIRS[randi() % DIRS.size()]


func _update_hud() -> void:
	score_label.text = "Puntos: %d" % score
	lives_label.text = "Vidas: %d" % lives
	percent_label.text = "%.0f%%" % _capture_percent()


func _capture_percent() -> float:
	var captured := 0
	for y in range(GRID_H):
		for x in range(GRID_W):
			if grid_state[y][x] == "captured":
				captured += 1
	return float(captured) / float(GRID_W * GRID_H) * 100.0


func _process(delta: float) -> void:
	if state != "playing":
		return

	move_timer += delta
	if move_timer >= MOVE_INTERVAL and current_dir != Vector2i.ZERO:
		move_timer = 0.0
		_try_move_player()

	for e: Dictionary in enemies:
		e["timer"] += delta
		if e["timer"] >= e["interval"]:
			e["timer"] = 0.0
			_move_enemy(e)

	_check_enemy_collisions()


func _try_move_player() -> void:
	var next: Vector2i = player_cell + current_dir
	if next.x < 0 or next.x >= GRID_W or next.y < 0 or next.y >= GRID_H:
		return

	var next_state: String = grid_state[next.y][next.x]

	if next_state == "trail":
		_lose_life()
		return

	if next_state == "captured":
		player_cell = next
		player_view.position = Vector2(next.x * CELL, next.y * CELL)
		if not trail.is_empty():
			_complete_capture()
		return

	for e: Dictionary in enemies:
		if e["pos"] == next:
			_lose_life()
			return

	grid_state[next.y][next.x] = "trail"
	trail.append(next)
	player_cell = next
	player_view.position = Vector2(next.x * CELL, next.y * CELL)
	_style_cell(next.y, next.x)


func _complete_capture() -> void:
	var reachable: Dictionary = {}
	for e: Dictionary in enemies:
		_flood_fill_from(e["pos"], reachable)

	for y in range(GRID_H):
		for x in range(GRID_W):
			var key := Vector2i(x, y)
			if grid_state[y][x] == "trail":
				grid_state[y][x] = "captured"
			elif grid_state[y][x] == "open" and not reachable.has(key):
				grid_state[y][x] = "captured"

	trail.clear()
	_redraw_grid()
	score += 50
	_update_hud()

	if _capture_percent() >= CAPTURE_TARGET:
		_advance_level()


func _flood_fill_from(start: Vector2i, reachable: Dictionary) -> void:
	if grid_state[start.y][start.x] != "open":
		return
	var stack: Array = [start]
	reachable[start] = true
	while not stack.is_empty():
		var cur: Vector2i = stack.pop_back()
		for d: Vector2i in DIRS:
			var n: Vector2i = cur + d
			if n.x < 0 or n.x >= GRID_W or n.y < 0 or n.y >= GRID_H:
				continue
			if reachable.has(n):
				continue
			if grid_state[n.y][n.x] != "open":
				continue
			reachable[n] = true
			stack.append(n)


func _move_enemy(e: Dictionary) -> void:
	var next: Vector2i = e["pos"] + e["dir"]
	if not _enemy_can_enter(next):
		e["dir"] = _random_dir()
		next = e["pos"] + e["dir"]
		if not _enemy_can_enter(next):
			return
	e["pos"] = next
	e["view"].position = Vector2(next.x * CELL, next.y * CELL)


func _enemy_can_enter(p: Vector2i) -> bool:
	if p.x <= 0 or p.x >= GRID_W - 1 or p.y <= 0 or p.y >= GRID_H - 1:
		return false
	return grid_state[p.y][p.x] == "open"


func _check_enemy_collisions() -> void:
	for e: Dictionary in enemies:
		if e["pos"] == player_cell and not trail.is_empty():
			_lose_life()
			return
		if grid_state[e["pos"].y][e["pos"].x] == "trail":
			_lose_life()
			return


func _lose_life() -> void:
	lives -= 1
	for c: Vector2i in trail:
		grid_state[c.y][c.x] = "open"
	trail.clear()
	player_cell = Vector2i(0, 0)
	current_dir = Vector2i.ZERO
	player_view.position = Vector2.ZERO
	_redraw_grid()
	_update_hud()

	if lives <= 0:
		state = "game_over"
		status_label.text = "Game Over. Puntos: %d" % score
		status_label.add_theme_color_override("font_color", UIKit.COLOR_DANGER)
		_record_result(false)


func _advance_level() -> void:
	if level >= MAX_LEVEL:
		_win()
		return
	level += 1
	_setup_level()


func _win() -> void:
	state = "won"
	status_label.text = "¡Completaste los %d niveles! Puntos: %d" % [MAX_LEVEL, score]
	status_label.add_theme_color_override("font_color", UIKit.COLOR_ACCENT_3)
	_record_result(true)


func _record_result(won: bool) -> void:
	AudioManager.play_win() if won else AudioManager.play_lose()
	var stats: Dictionary = SaveManager.get_game_data(GAME_ID)
	var key: String = "wins" if won else "losses"
	stats[key] = stats.get(key, 0) + 1
	stats["best_score"] = max(stats.get("best_score", 0), score)
	SaveManager.set_game_data(GAME_ID, stats)


func _redraw_grid() -> void:
	for y in range(GRID_H):
		for x in range(GRID_W):
			_style_cell(y, x)


func _style_cell(y: int, x: int) -> void:
	var view: Panel = cell_views[y][x]
	var s: String = grid_state[y][x]
	var color: Color
	match s:
		"captured":
			color = target_colors[y][x]
		"trail":
			color = UIKit.COLOR_ACCENT_3
		_:
			color = UIKit.COLOR_BG.lerp(UIKit.COLOR_BG_LIGHT, 0.3)
	view.add_theme_stylebox_override("panel", UIKit.stylebox(color, Color(0, 0, 0, 0), 1))
