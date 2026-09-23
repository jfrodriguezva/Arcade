extends Control
## Estilo Pac-Man: laberinto generado proceduralmente (algoritmo de
## backtracking, siempre 100% conectado — evita bugs de un laberinto
## armado a mano con puntos inalcanzables) con caza de fantasmas.
## Come todos los puntos para pasar de nivel; las bolitas grandes
## vuelven vulnerables a los fantasmas por unos segundos.

const GAME_ID := "maze_muncher"
const ROOMS_W := 9
const ROOMS_H := 11
const MAZE_W := ROOMS_W * 2 + 1
const MAZE_H := ROOMS_H * 2 + 1
const CELL := 30.0
const MOVE_INTERVAL := 0.11
const VULNERABLE_DURATION := 6.0
const MAX_LEVEL := 10
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

const HELP_TEXT := "Muévete por el laberinto con las flechas y come todos los puntos.

- Las bolitas grandes (amarillas) vuelven vulnerables a los fantasmas por unos segundos: tócalos en ese estado para comerlos y ganar puntos extra.
- Si un fantasma te toca cuando NO está vulnerable, pierdes una vida.

Limpia todos los puntos del laberinto para pasar de nivel (se genera uno nuevo, con más fantasmas y más rápidos). Hay 10 niveles. Pierdes si se acaban tus 3 vidas."

var walls: Array = []
var has_dot: Array = []
var has_power: Array = []
var cell_views: Array = []

var player_cell: Vector2i = Vector2i.ZERO
var current_dir: Vector2i = Vector2i.ZERO
var move_timer: float = 0.0
var vulnerable_timer: float = 0.0

var ghosts: Array = []

var score: int = 0
var lives: int = 3
var level: int = 1
var state: String = "playing"

var play_area: Control
var player_view: GamePiece
var score_label: Label
var lives_label: Label
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

	UIKit.build_toolbar(vbox, self, "Caza en el Laberinto", HELP_TEXT)

	var hud := HBoxContainer.new()
	hud.alignment = BoxContainer.ALIGNMENT_CENTER
	hud.add_theme_constant_override("separation", 24)
	vbox.add_child(hud)
	score_label = UIKit.title_label("Puntos: 0", 14, UIKit.COLOR_TEXT)
	hud.add_child(score_label)
	lives_label = UIKit.title_label("Vidas: 3", 14, UIKit.COLOR_ACCENT)
	hud.add_child(lives_label)

	status_label = UIKit.title_label("Nivel 1", 14, UIKit.COLOR_TEXT_DIM)
	vbox.add_child(status_label)

	var play_panel := PanelContainer.new()
	play_panel.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.COLOR_PANEL, UIKit.COLOR_ACCENT_3, 10, 2))
	vbox.add_child(play_panel)

	play_area = Control.new()
	play_area.custom_minimum_size = Vector2(MAZE_W * CELL, MAZE_H * CELL)
	play_area.clip_contents = true
	play_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_panel.add_child(play_area)

	for y in range(MAZE_H):
		var row: Array = []
		for x in range(MAZE_W):
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
	player_view.set_piece(UIKit.COLOR_ACCENT_3)
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


func _new_game() -> void:
	score = 0
	lives = 3
	level = 1
	state = "playing"
	_setup_level()


func _generate_maze() -> void:
	walls = []
	for y in range(MAZE_H):
		var row: Array = []
		for x in range(MAZE_W):
			row.append(true)
		walls.append(row)

	var visited: Array = []
	for ry in range(ROOMS_H):
		var vrow: Array = []
		for rx in range(ROOMS_W):
			vrow.append(false)
		visited.append(vrow)

	visited[0][0] = true
	walls[1][1] = false
	var stack: Array = [Vector2i(0, 0)]

	while not stack.is_empty():
		var cur: Vector2i = stack.back()
		var neighbors: Array = []
		for d: Vector2i in DIRS:
			var n: Vector2i = cur + d
			if n.x >= 0 and n.x < ROOMS_W and n.y >= 0 and n.y < ROOMS_H and not visited[n.y][n.x]:
				neighbors.append(n)
		if neighbors.is_empty():
			stack.pop_back()
			continue
		var next: Vector2i = neighbors[randi() % neighbors.size()]
		visited[next.y][next.x] = true
		var wall_x: int = cur.x * 2 + 1 + (next.x - cur.x)
		var wall_y: int = cur.y * 2 + 1 + (next.y - cur.y)
		walls[wall_y][wall_x] = false
		walls[next.y * 2 + 1][next.x * 2 + 1] = false
		stack.append(next)

	for y in range(1, MAZE_H - 1):
		for x in range(1, MAZE_W - 1):
			var is_edge_slot: bool = (x % 2 == 0 and y % 2 == 1) or (x % 2 == 1 and y % 2 == 0)
			if walls[y][x] and is_edge_slot and randf() < 0.07:
				walls[y][x] = false


func _room_to_grid(r: Vector2i) -> Vector2i:
	return Vector2i(r.x * 2 + 1, r.y * 2 + 1)


func _setup_level() -> void:
	_generate_maze()

	has_dot = []
	has_power = []
	for y in range(MAZE_H):
		var dot_row: Array = []
		var power_row: Array = []
		for x in range(MAZE_W):
			dot_row.append(not walls[y][x])
			power_row.append(false)
		has_dot.append(dot_row)
		has_power.append(power_row)

	player_cell = _room_to_grid(Vector2i(0, 0))
	has_dot[player_cell.y][player_cell.x] = false
	current_dir = Vector2i.ZERO
	vulnerable_timer = 0.0

	var power_spots: Array = [
		Vector2i(ROOMS_W - 1, 0), Vector2i(0, ROOMS_H - 1),
		Vector2i(ROOMS_W - 1, ROOMS_H - 1), Vector2i(ROOMS_W / 2, ROOMS_H / 2),
	]
	for spot: Vector2i in power_spots:
		var g: Vector2i = _room_to_grid(spot)
		has_dot[g.y][g.x] = false
		has_power[g.y][g.x] = true

	for g: Dictionary in ghosts:
		g["view"].queue_free()
	ghosts.clear()

	var spawn_rooms: Array = [
		Vector2i(ROOMS_W - 1, 0), Vector2i(0, ROOMS_H - 1), Vector2i(ROOMS_W - 1, ROOMS_H - 1),
		Vector2i(ROOMS_W / 2, 0), Vector2i(0, 0),
	]
	var ghost_count: int = min(1 + level / 2, 5)
	var ghost_interval: float = max(0.11, 0.26 - level * 0.014)
	for i in range(ghost_count):
		var spawn: Vector2i = _room_to_grid(spawn_rooms[i % spawn_rooms.size()])
		has_dot[spawn.y][spawn.x] = false
		var view := GamePiece.new()
		view.size = Vector2(CELL * 0.85, CELL * 0.85)
		view.position = Vector2(spawn.x * CELL, spawn.y * CELL)
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.set_piece(UIKit.COLOR_DANGER)
		play_area.add_child(view)
		ghosts.append({"pos": spawn, "spawn": spawn, "last_pos": Vector2i(-99, -99), "view": view, "interval": ghost_interval, "timer": 0.0})

	status_label.text = "Nivel %d / %d" % [level, MAX_LEVEL]
	_redraw_maze()
	_update_hud()


func _redraw_maze() -> void:
	for y in range(MAZE_H):
		for x in range(MAZE_W):
			_style_cell(y, x)


func _style_cell(y: int, x: int) -> void:
	var view: Panel = cell_views[y][x]
	var color: Color
	if walls[y][x]:
		color = UIKit.COLOR_BG
	elif has_power[y][x]:
		color = UIKit.COLOR_ACCENT_3
	elif has_dot[y][x]:
		color = UIKit.COLOR_BG_LIGHT.lightened(0.18)
	else:
		color = UIKit.COLOR_BG_LIGHT
	view.add_theme_stylebox_override("panel", UIKit.stylebox(color, Color(0, 0, 0, 0), 2))


func _update_hud() -> void:
	score_label.text = "Puntos: %d" % score
	lives_label.text = "Vidas: %d" % lives


func _is_open(p: Vector2i) -> bool:
	if p.x < 0 or p.x >= MAZE_W or p.y < 0 or p.y >= MAZE_H:
		return false
	return not walls[p.y][p.x]


func _process(delta: float) -> void:
	if state != "playing":
		return

	if vulnerable_timer > 0.0:
		vulnerable_timer -= delta
		if vulnerable_timer <= 0.0:
			for g: Dictionary in ghosts:
				g["view"].set_piece(UIKit.COLOR_DANGER)

	move_timer += delta
	if move_timer >= MOVE_INTERVAL:
		move_timer = 0.0
		if current_dir != Vector2i.ZERO:
			_try_move_player()
		for g: Dictionary in ghosts:
			g["timer"] += delta
		for g: Dictionary in ghosts:
			if g["timer"] >= g["interval"]:
				g["timer"] = 0.0
				_move_ghost(g)
		_check_ghost_collision()


func _try_move_player() -> void:
	var next: Vector2i = player_cell + current_dir
	if not _is_open(next):
		return
	player_cell = next
	player_view.position = Vector2(next.x * CELL, next.y * CELL)

	if has_dot[next.y][next.x]:
		has_dot[next.y][next.x] = false
		score += 10
		_style_cell(next.y, next.x)
		_update_hud()
	if has_power[next.y][next.x]:
		has_power[next.y][next.x] = false
		score += 50
		vulnerable_timer = VULNERABLE_DURATION
		for g: Dictionary in ghosts:
			g["view"].set_piece(UIKit.COLOR_ACCENT_2)
		_style_cell(next.y, next.x)
		_update_hud()

	if _all_dots_eaten():
		_advance_level()


func _move_ghost(g: Dictionary) -> void:
	var options: Array = []
	for d: Vector2i in DIRS:
		var n: Vector2i = g["pos"] + d
		if _is_open(n) and n != g["last_pos"]:
			options.append(n)
	if options.is_empty():
		for d: Vector2i in DIRS:
			var n: Vector2i = g["pos"] + d
			if _is_open(n):
				options.append(n)
		if options.is_empty():
			return

	var chosen: Vector2i = options[0]
	if vulnerable_timer > 0.0:
		var best_dist := -1.0
		for o: Vector2i in options:
			var dist: float = Vector2(o).distance_to(Vector2(player_cell))
			if dist > best_dist:
				best_dist = dist
				chosen = o
	else:
		var chase_chance: float = min(0.5 + level * 0.05, 0.9)
		if randf() < chase_chance:
			var best_dist2 := INF
			for o: Vector2i in options:
				var dist2: float = Vector2(o).distance_to(Vector2(player_cell))
				if dist2 < best_dist2:
					best_dist2 = dist2
					chosen = o
		else:
			chosen = options[randi() % options.size()]

	g["last_pos"] = g["pos"]
	g["pos"] = chosen
	g["view"].position = Vector2(chosen.x * CELL, chosen.y * CELL)


func _check_ghost_collision() -> void:
	for g: Dictionary in ghosts:
		if g["pos"] == player_cell:
			if vulnerable_timer > 0.0:
				score += 200
				_update_hud()
				g["pos"] = g["spawn"]
				g["view"].position = Vector2(g["spawn"].x * CELL, g["spawn"].y * CELL)
			else:
				_lose_life()
			return


func _all_dots_eaten() -> bool:
	for y in range(MAZE_H):
		for x in range(MAZE_W):
			if has_dot[y][x] or has_power[y][x]:
				return false
	return true


func _lose_life() -> void:
	lives -= 1
	_update_hud()
	current_dir = Vector2i.ZERO
	player_cell = _room_to_grid(Vector2i(0, 0))
	player_view.position = Vector2(player_cell.x * CELL, player_cell.y * CELL)
	for g: Dictionary in ghosts:
		g["pos"] = g["spawn"]
		g["view"].position = Vector2(g["spawn"].x * CELL, g["spawn"].y * CELL)

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
